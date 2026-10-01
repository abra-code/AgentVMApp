#!/bin/sh
# lib.agentvm.network.sh
#
# A box's network window (AgentVM.network.json, the views 601-616), in two tabs: Settings, what the
# box may reach, changed in one Apply; and Activity, the connections it made lately. One window per
# box (lib.agentvm.ui.sh, "Box windows"); the box's name is the window's pasteboard value "box",
# set by the init handler from the open request. Sources lib.agentvm.main.sh for reading `status`
# into the window's own cache (main_read_status, main_row) and for main_alert.
#
# WHEN IT READS: on opening, on every activation, on Refresh and after a change; there is no poll
# loop. The box's state decides whether the mode can change, so coming back to the window after
# starting or stopping the box in the main window, in Terminal or in Cadabra reads it again.
#
# DESIRED AND CURRENT RULES. Each box has two files in the window's cache: net-<box>.current, the
# mode and rules agent-vm last reported, and net-<box>.desired, the same with the edits made on
# the window (a pack ticked, a host added, the mode picked). Apply Rules turns the difference into
# one `box network` call; Discard Changes copies current over desired. Reading the rules again
# replays the edits onto what was read (net_replay), so a change made elsewhere meanwhile is kept,
# not queued for undoing. A file is one line for the mode and one per rule.
#
# CLICKS, NOT TOGGLES. A pack, and "Any public host name", is a row whose whole box is one click
# target that flips it (a template row reports its index); nothing in the window is a Toggle whose
# value the app would have to keep in step. The mode picker is the one control the app sets; a
# Picker fires its action only on a change the user makes, and the handler also ignores a value
# equal to the mode wanted.
#
# HOST NAMES COME FROM THE BOX. The connection log records what programs in the box asked for, so
# a host is whatever they wrote: a rule is built only from a plain host name and a port
# (lib.agentvm.network.awk), and the user confirms it before it is added.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_NETWORK_LIB:-}" ] && return 0
__AGENTVM_APP_NETWORK_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

NET_MODE_ID=601
NET_MODE_NOTE_ID=602
NET_PACKS_ID=603
NET_HOSTS_ID=604
NET_HOST_FIELD_ID=605
NET_ADD_ID=606
NET_REMOVE_ID=607
NET_PUBLIC_ID=608
NET_PUBLIC_SYMBOL_ID=609
NET_CHANGES_ID=610
NET_DISCARD_ID=611
NET_APPLY_ID=612
NET_CONNECTIONS_ID=613
NET_ALLOW_ID=614
NET_REFRESH_ID=615
NET_NOTE_ID=616

# How many of the last connections the window reads: the whole log can hold a hundred thousand.
NET_NETLOG_LAST=200

net_awk="$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.awk"

# The modes in the picker's order: the picker reports the 1-based index.
net_modes="allowlist off open"

# -- The window ---------------------------------------------------------------------------------

# net_refresh <uuid> [rules]  ->  `status` read into the window's cache, then the box's rules, and
# its last connections unless "rules" is given, and the window painted. Nothing more is read for a
# box `status` does not list, or when `status` failed.
net_refresh() {
    local _box="$(ui_get box "$1")"
    [ -n "$_box" ] && agentvm_valid_name "$_box" || return 0
    main_read_status "$1"
    local _status=$?
    if [ "$_status" -eq 0 ] && [ -n "$(main_row "$1" boxes "$_box")" ]; then
        net_read "$1" "$_box" ${2:-}
    fi
    net_paint "$1"
}

# net_problem <uuid> <box>  ->  why the window cannot show the box now: `status` failed, or it no
# longer lists the box. Nothing when it can.
net_problem() {
    local _error="$(main_status_error "$1")"
    if [ -n "$_error" ]; then
        printf '%s\n' "$_error"
    elif [ -z "$(main_row "$1" boxes "$2")" ]; then
        printf 'Box %s no longer exists.\n' "$2"
    fi
}

# -- Reading ------------------------------------------------------------------------------------

# net_file <uuid> <box> <current|desired|connections|error|connections-error>  ->  that file
# of the box's network. The box name is part of a path, so callers pass names agentvm_valid_name
# accepted.
net_file() {
    ui_cache "$1" "net-$2.$3"
}

# net_read_packs <uuid>  ->  0 with the packs in the cache file packs.tsv (name, description),
# read once per window: they come with agent-vm. agent-vm's status otherwise.
net_read_packs() {
    local _file="$(ui_cache "$1" packs.tsv)"
    [ -s "$_file" ] && return 0
    local _json
    _json="$(agentvm_box_packs)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_packs_rows | ui_store "$_file"
}

# net_read <uuid> <box> [rules]  ->  the box's rules read again (and the packs, once), and its
# last connections unless "rules" is given. Desired is replaced with current only when it held
# no edits. A failure leaves agent-vm's message in the box's error file (the rules and packs) or
# connections-error file (the connections), each emptied by its own success.
net_read() {
    agentvm_valid_name "$2" || return 2
    local _uuid="$1"
    local _box="$2"
    local _error=""
    local _status
    net_read_packs "$_uuid"
    _status=$?
    [ "$_status" -eq 0 ] || _error="$(ui_one_line "$(agentvm_last_error "$_status")")"
    local _json
    _json="$(agentvm_box_rules "$_box")"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        _error="$(ui_one_line "$(agentvm_last_error "$_status")")"
    else
        local _current="$(net_file "$_uuid" "$_box" current)"
        # The edits are the difference, not the text (a rule unticked and ticked again comes back
        # at the end of the list), and they are replayed onto the rules just read: a rule added or
        # removed elsewhere meanwhile (Terminal, Cadabra) is not queued for undoing.
        local _edits="$(net_changes "$_uuid" "$_box")"
        printf '%s\n' "$_json" | agentvm_rules_lines | ui_store "$_current"
        net_replay "$_uuid" "$_box" "$_edits"
    fi
    printf '%s' "$_error" | ui_store "$(net_file "$_uuid" "$_box" error)"
    if [ "${3:-}" = "rules" ]; then
        [ -z "$_error" ]
        return
    fi
    local _log_error=""
    _json="$(agentvm_box_netlog "$_box" "$NET_NETLOG_LAST")"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        _log_error="$(ui_one_line "$(agentvm_last_error "$_status")")"
    else
        printf '%s\n' "$_json" | agentvm_netlog_rows \
            | /usr/bin/awk -F'\t' -v mode=rows -f "$net_awk" \
            | /usr/bin/sort -t "$ui_tab" -k1,1n -k2,2r | /usr/bin/cut -f3- \
            | ui_store "$(net_file "$_uuid" "$_box" connections)"
    fi
    printf '%s' "$_log_error" | ui_store "$(net_file "$_uuid" "$_box" connections-error)"
    [ -z "$_error" ] && [ -z "$_log_error" ]
}

# net_mode <file>  ->  the mode in a current or desired file. net_rules <file>  ->  its rules.
net_mode() {
    /usr/bin/sed -n '1p' "$1" 2>/dev/null
}
net_rules() {
    /usr/bin/sed -n '2,$p' "$1" 2>/dev/null
}

# net_changes <uuid> <box>  ->  what Apply would do: "=mode" when the mode changes, "+rule" for each
# rule to add and "-rule" for each to remove, in that order; nothing when there is nothing.
net_changes() {
    local _current="$(net_file "$1" "$2" current)"
    local _desired="$(net_file "$1" "$2" desired)"
    [ -f "$_current" ] && [ -f "$_desired" ] || return 0
    local _mode="$(net_mode "$_desired")"
    [ "$_mode" != "$(net_mode "$_current")" ] && printf '=%s\n' "$_mode"
    /usr/bin/awk 'FNR == 1 { next } NR == FNR { have[$0] = 1; next } !($0 in have) { print "+" $0 }' "$_current" "$_desired"
    /usr/bin/awk 'FNR == 1 { next } NR == FNR { want[$0] = 1; next } !($0 in want) { print "-" $0 }' "$_desired" "$_current"
}

# net_sendable <uuid> <box>  ->  the changes Apply can send now: net_changes, less the mode while the
# box is not stopped (agent-vm changes it only then, and refuses the whole call otherwise). A mode
# picked while the box was stopped waits, listed as not applied, until it is stopped again.
net_sendable() {
    local _state="$(main_row "$1" boxes "$2" | /usr/bin/cut -f2)"
    if [ "$_state" = "stopped" ]; then
        net_changes "$1" "$2"
    else
        net_changes "$1" "$2" | /usr/bin/grep -v '^='
    fi
    return 0
}

# net_changes_text <uuid> <box>  ->  the line beside Apply Rules: what is not applied yet.
net_changes_text() {
    local _changes="$(net_changes "$1" "$2")"
    [ -n "$_changes" ] || return 0
    local _text="Not applied yet:"
    local _mode="$(printf '%s\n' "$_changes" | /usr/bin/sed -n 's/^=//p')"
    local _sep=""
    if [ -n "$_mode" ]; then
        _text="$_text mode $_mode"
        _sep=";"
    fi
    local _added="$(printf '%s\n' "$_changes" | /usr/bin/sed -n 's/^+//p')"
    if [ -n "$_added" ]; then
        _text="$_text$_sep allow $(ui_lines_text "$_added")"
        _sep=";"
    fi
    local _removed="$(printf '%s\n' "$_changes" | /usr/bin/sed -n 's/^-//p')"
    [ -n "$_removed" ] && _text="$_text$_sep remove $(ui_lines_text "$_removed")"
    printf '%s.\n' "$_text"
}

# -- Editing the desired rules ------------------------------------------------------------------

# net_desired_write <uuid> <box> <mode> <rules>  ->  the desired file: the mode, then the rules
# with each one once, in their order.
net_desired_write() {
    {
        printf '%s\n' "$3"
        printf '%s\n' "$4" | /usr/bin/awk 'NF && !seen[$0]++'
    } | ui_store "$(net_file "$1" "$2" desired)"
}

# net_replay <uuid> <box> <edits, as net_changes prints them>  ->  the desired file: the rules just
# read, with the edits made on them again. An addition already there and a removal already gone
# change nothing, so with no edits it is the rules just read.
net_replay() {
    local _current="$(net_file "$1" "$2" current)"
    local _mode="$(net_mode "$_current")"
    local _wanted="$(printf '%s\n' "$3" | /usr/bin/sed -n 's/^=//p')"
    [ -n "$_wanted" ] && _mode="$_wanted"
    local _rules="$(printf '%s\n' "$3" | /usr/bin/awk -v current="$_current" '
        BEGIN { while ((getline line < current) > 0) if (++c > 1) { order[++n] = line; keep[line] = 1 } }
        /^-/  { keep[substr($0, 2)] = 0 }
        /^\+/ { added[++a] = substr($0, 2) }
        END {
            for (i = 1; i <= n; i++) if (keep[order[i]]) print order[i]
            for (i = 1; i <= a; i++) print added[i]
        }')"
    net_desired_write "$1" "$2" "$_mode" "$_rules"
}

# net_set_mode <uuid> <box> <mode>  ->  the mode wanted. 1 when there are no rules read yet.
net_set_mode() {
    local _desired="$(net_file "$1" "$2" desired)"
    [ -f "$_desired" ] || return 1
    net_desired_write "$1" "$2" "$3" "$(net_rules "$_desired")"
}

# net_rule_wanted <uuid> <box> <rule>  ->  0 when the rule is in the desired rules.
net_rule_wanted() {
    net_rules "$(net_file "$1" "$2" desired)" | /usr/bin/grep -qxF -- "$3"
}

# net_add_rule, net_remove_rule, net_flip_rule <uuid> <box> <rule>  ->  the desired rules with the
# rule added, removed, or flipped. 1 when there are no rules read yet.
net_add_rule() {
    local _desired="$(net_file "$1" "$2" desired)"
    [ -f "$_desired" ] || return 1
    net_desired_write "$1" "$2" "$(net_mode "$_desired")" "$(net_rules "$_desired")
$3"
}
net_remove_rule() {
    local _desired="$(net_file "$1" "$2" desired)"
    [ -f "$_desired" ] || return 1
    net_desired_write "$1" "$2" "$(net_mode "$_desired")" "$(net_rules "$_desired" | /usr/bin/grep -vxF -- "$3")"
}
net_flip_rule() {
    net_rule_wanted "$1" "$2" "$3"
    local _wanted=$?
    if [ "$_wanted" -eq 0 ]; then
        net_remove_rule "$1" "$2" "$3"
    else
        net_add_rule "$1" "$2" "$3"
    fi
}

# net_check_rule <text>  ->  the rule typed by hand as agent-vm reads it, or nothing when it is
# not one (lib.agentvm.network.awk, check).
net_check_rule() {
    local _rule="$(printf '%s\n' "$1" | /usr/bin/awk -v mode=check -f "$net_awk" | /usr/bin/sed -n '1p')"
    [ "$_rule" = "-" ] && return 0
    printf '%s\n' "$_rule"
}

# net_connection_rule <host> <port> <rule shown> <decision>  ->  the rule to allow for a row of the
# connections table, or nothing: only for a refusal, and only a rule lib.agentvm.network.awk builds
# from the row's host and port, for a tunnel or for plain HTTP, which also checks that the host is
# a plain host name.
net_connection_rule() {
    [ "$4" = "denied" ] || return 0
    case "$3" in ''|-) return 0 ;; esac
    local _tunnel="$(printf '%s\t%s\tCONNECT\n' "$1" "$2" | /usr/bin/awk -F'\t' -v mode=rule -f "$net_awk")"
    local _http="$(printf '%s\t%s\tGET\n' "$1" "$2" | /usr/bin/awk -F'\t' -v mode=rule -f "$net_awk")"
    if [ "$3" = "$_tunnel" ] || [ "$3" = "$_http" ]; then
        printf '%s\n' "$3"
    fi
}

# net_allowable <uuid> <host> <port> <rule shown> <decision>  ->  net_connection_rule for the window's
# box, and only while its mode is allowlist: with the network off every host is refused whatever
# the rules say, and in open mode a refusal is for this Mac or the local network, which no rule
# opens.
net_allowable() {
    local _box="$(ui_get box "$1")"
    [ -n "$_box" ] && agentvm_valid_name "$_box" || return 0
    local _mode="$(net_mode "$(net_file "$1" "$_box" current)")"
    [ "$_mode" = "allowlist" ] || return 0
    net_connection_rule "$2" "$3" "$4" "$5"
}

# -- Painting -----------------------------------------------------------------------------------

# net_pack_rows <uuid> <box>  ->  the packs grid's rows: the box symbol (ticked when the pack is
# wanted), name, description (the help), and orange when wanted differs from what applies now.
net_pack_rows() {
    local _packs="$(ui_cache "$1" packs.tsv)"
    [ -f "$_packs" ] || return 0
    /usr/bin/awk -F'\t' -v current="$(net_file "$1" "$2" current)" -v desired="$(net_file "$1" "$2" desired)" '
        BEGIN {
            while ((getline line < current) > 0) if (++c > 1) now[line] = 1
            while ((getline line < desired) > 0) if (++d > 1) want[line] = 1
        }
        NF {
            rule = "pack:" $1
            printf "%s\t%s\t%s\t%s\n", ((rule in want) ? "checkmark.square.fill" : "square"), $1, $2,
                (((rule in want) != (rule in now)) ? "orange" : "primary")
        }' "$_packs"
}

# net_host_rows <uuid> <box>  ->  the other hosts table's rows: each wanted rule that is neither a
# pack nor "public", with "not applied yet" for one that does not apply now.
net_host_rows() {
    /usr/bin/awk -v current="$(net_file "$1" "$2" current)" '
        BEGIN { while ((getline line < current) > 0) if (++c > 1) now[line] = 1 }
        FNR == 1 || $0 ~ /^pack:/ || $0 == "public" || $0 == "" { next }
        { printf "%s\t%s\n", $0, (($0 in now) ? "" : "not applied yet") }' "$(net_file "$1" "$2" desired)"
}

# net_mode_text <mode> <box state>  ->  the line under the mode picker: what the mode wanted lets
# through, and while the box is not stopped, that the mode waits for it.
net_mode_text() {
    local _text=""
    case "$1" in
        allowlist) _text="Only what the packs and hosts below allow." ;;
        off)       _text="No network: every connection is refused, whatever the rules say." ;;
        open)      _text="Any host but this Mac and your local network; the rules are kept for later." ;;
    esac
    [ "$2" = "stopped" ] || _text="${_text:+$_text }The mode changes only while the box is stopped."
    printf '%s\n' "$_text"
}

# net_paint_settings <uuid> <box>  ->  the Settings tab from the caches: the mode, enabled only
# while the box is stopped; the packs; public; the other hosts; what is not applied yet. The hosts
# table loses its selection, and Remove is off until a row is selected again.
net_paint_settings() {
    local _uuid="$1"
    local _box="$2"
    local _desired="$(net_file "$_uuid" "$_box" desired)"
    local _error="$(/bin/cat "$(net_file "$_uuid" "$_box" error)" 2>/dev/null)"
    ui_enable "$_uuid" "$NET_REMOVE_ID" 0
    if [ ! -f "$_desired" ]; then
        : | "$dialog" "$_uuid" "$NET_PACKS_ID" omc_table_set_rows_from_stdin
        : | "$dialog" "$_uuid" "$NET_HOSTS_ID" omc_table_set_rows_from_stdin
        "$dialog" "$_uuid" "$NET_CHANGES_ID" ""
        ui_enable "$_uuid" "$NET_MODE_ID" 0
        ui_enable "$_uuid" "$NET_ADD_ID" 0
        ui_enable "$_uuid" "$NET_PUBLIC_ID" 0
        ui_enable "$_uuid" "$NET_APPLY_ID" 0
        ui_enable "$_uuid" "$NET_DISCARD_ID" 0
        "$dialog" "$_uuid" "$NET_MODE_NOTE_ID" "${_error:-The rules have not been read yet.}"
        return 0
    fi
    local _state="$(main_row "$_uuid" boxes "$_box" | /usr/bin/cut -f2)"
    local _mode="$(net_mode "$_desired")"
    if [ "$_state" = "stopped" ]; then
        ui_enable "$_uuid" "$NET_MODE_ID" 1
    else
        ui_enable "$_uuid" "$NET_MODE_ID" 0
    fi
    if [ -n "$_error" ]; then
        "$dialog" "$_uuid" "$NET_MODE_NOTE_ID" "$_error"
    else
        "$dialog" "$_uuid" "$NET_MODE_NOTE_ID" "$(net_mode_text "$_mode" "$_state")"
    fi
    # The picker's value is the mode's 1-based index. Setting it fires nothing.
    local _index="$(printf '%s\n' $net_modes | /usr/bin/awk -v mode="$_mode" '$0 == mode { print NR }')"
    [ -n "$_index" ] && "$dialog" "$_uuid" "$NET_MODE_ID" "$_index"
    net_pack_rows "$_uuid" "$_box" | "$dialog" "$_uuid" "$NET_PACKS_ID" omc_table_set_rows_from_stdin
    local _public="square"
    net_rule_wanted "$_uuid" "$_box" public && _public="checkmark.square.fill"
    "$dialog" "$_uuid" "$NET_PUBLIC_SYMBOL_ID" omc_set_property systemName "$_public"
    local _color="primary"
    local _public_changed="$(net_changes "$_uuid" "$_box" | /usr/bin/grep -xF -e +public -e -public)"
    if [ -n "$_public_changed" ]; then
        _color="orange"
    fi
    "$dialog" "$_uuid" "$NET_PUBLIC_SYMBOL_ID" omc_set_property foregroundStyle "$_color"
    ui_enable "$_uuid" "$NET_PUBLIC_ID" 1
    ui_enable "$_uuid" "$NET_ADD_ID" 1
    net_host_rows "$_uuid" "$_box" | "$dialog" "$_uuid" "$NET_HOSTS_ID" omc_table_set_rows_from_stdin
    "$dialog" "$_uuid" "$NET_HOSTS_ID" omc_deselect
    local _changes="$(net_changes_text "$_uuid" "$_box")"
    "$dialog" "$_uuid" "$NET_CHANGES_ID" "$_changes"
    local _changed=0
    [ -n "$_changes" ] && _changed=1
    local _sendable="$(net_sendable "$_uuid" "$_box")"
    local _apply=0
    [ -n "$_sendable" ] && _apply=1
    ui_enable "$_uuid" "$NET_APPLY_ID" "$_apply"
    ui_enable "$_uuid" "$NET_DISCARD_ID" "$_changed"
}

# net_paint_activity <uuid> <box>  ->  the Activity tab from the caches: the last connections. The
# table loses its selection, and Allow Selected Host... is off until a row is selected again.
net_paint_activity() {
    local _uuid="$1"
    local _box="$2"
    local _connections="$(net_file "$_uuid" "$_box" connections)"
    local _error="$(/bin/cat "$(net_file "$_uuid" "$_box" connections-error)" 2>/dev/null)"
    ui_enable "$_uuid" "$NET_ALLOW_ID" 0
    if [ -f "$_connections" ]; then
        /bin/cat "$_connections" | "$dialog" "$_uuid" "$NET_CONNECTIONS_ID" omc_table_set_rows_from_stdin
    else
        : | "$dialog" "$_uuid" "$NET_CONNECTIONS_ID" omc_table_set_rows_from_stdin
    fi
    "$dialog" "$_uuid" "$NET_CONNECTIONS_ID" omc_deselect
    if [ -n "$_error" ]; then
        "$dialog" "$_uuid" "$NET_NOTE_ID" "$_error"
    elif [ ! -f "$_connections" ]; then
        "$dialog" "$_uuid" "$NET_NOTE_ID" "The connections have not been read yet."
    elif [ ! -s "$_connections" ]; then
        "$dialog" "$_uuid" "$NET_NOTE_ID" "No connections logged yet. A connection is logged when it ends, so one still open shows up when it closes."
    else
        "$dialog" "$_uuid" "$NET_NOTE_ID" "The last $NET_NETLOG_LAST connections, one row per host, port and result."
    fi
}

# net_paint <uuid>  ->  both tabs from the caches, for the window's box. When the box cannot be
# shown (net_problem), the lists are empty, every control but Refresh is off, and both tabs say why.
net_paint() {
    local _uuid="$1"
    local _box="$(ui_get box "$_uuid")"
    [ -n "$_box" ] && agentvm_valid_name "$_box" || return 0
    local _problem="$(net_problem "$_uuid" "$_box")"
    if [ -z "$_problem" ]; then
        net_paint_settings "$_uuid" "$_box"
        net_paint_activity "$_uuid" "$_box"
        return 0
    fi
    : | "$dialog" "$_uuid" "$NET_PACKS_ID" omc_table_set_rows_from_stdin
    : | "$dialog" "$_uuid" "$NET_HOSTS_ID" omc_table_set_rows_from_stdin
    : | "$dialog" "$_uuid" "$NET_CONNECTIONS_ID" omc_table_set_rows_from_stdin
    "$dialog" "$_uuid" "$NET_CHANGES_ID" ""
    local _id
    for _id in "$NET_MODE_ID" "$NET_PUBLIC_ID" "$NET_ADD_ID" "$NET_REMOVE_ID" "$NET_DISCARD_ID" "$NET_APPLY_ID" "$NET_ALLOW_ID"; do
        ui_enable "$_uuid" "$_id" 0
    done
    "$dialog" "$_uuid" "$NET_MODE_NOTE_ID" "$_problem"
    "$dialog" "$_uuid" "$NET_NOTE_ID" "$_problem"
}
