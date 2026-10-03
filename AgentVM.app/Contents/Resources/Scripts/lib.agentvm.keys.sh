#!/bin/sh
# lib.agentvm.keys.sh
#
# The Agent Keys window (AgentVM.keys.json, the views 4001-4007): the agents avm can run and
# the keys each can use (`agent-vm connect agents`), whether each key is stored, a field to
# store one, and Remove.... One window at a time (lib.agentvm.ui.sh, "Box windows", with the
# kind "keys" and the name "window"), opened by Agent Keys... in the main window's Settings.
#
# THE VALUE OF A KEY. The field is a SecureField, and the engine exports what it holds to every
# handler of the window as OMC_ACTIONUI_VIEW_<id>_VALUE, which every program a handler starts
# would inherit. So this library, before it sources anything or runs any program, moves the
# value to a shell variable that is not exported and unsets the exported one; every handler of
# the window sources this library first. The field has no action of its own (a field's action
# also runs when the field loses the focus): Store is a button. The value reaches agent-vm on
# its stdin, written by the shell's own printf, and never as an argument. It is never written
# to a file, a pasteboard or the window, and the field is emptied once it is stored.
#
# The key a button works on is the one the selection handler recorded (the name and the agent),
# which is also what the line above the field names, and it is looked up again in what agent-vm
# listed before it reaches agent-vm's arguments.
#
# WHAT IT READS: `connect agents` on opening, when the window comes to the front, and after
# Store and Remove. It has no poll loop. The rows are the cache file keys.tsv
# (agentvm_agent_secret_rows), or keys-error with agent-vm's words.
#
# Sources lib.agentvm.main.sh, and lib.agentvm.wizard.sh for the one-click-at-a-time mark of
# Store. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_KEYS_LIB:-}" ] && return 0
__AGENTVM_APP_KEYS_LIB=1

KEYS_TABLE_ID=4001
KEYS_TITLE_ID=4002
KEYS_FIELD_ID=4003
KEYS_STORE_ID=4004
KEYS_REMOVE_ID=4005
KEYS_NOTE_ID=4006
KEYS_HINT_ID=4007

# Before anything else: see THE VALUE OF A KEY above.
keys_typed="${OMC_ACTIONUI_VIEW_4003_VALUE:-}"
unset OMC_ACTIONUI_VIEW_4003_VALUE

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

# keys_is <uuid>  ->  0 while that window is an open Agent Keys window.
keys_is() {
    [ "$(ui_get keys "$1")" = "1" ]
}

# -- Reading -------------------------------------------------------------------------------------

# keys_read <uuid> [full]  ->  0 with the agents and their keys read anew (keys.tsv); "full"
# first checks which agent-vm runs (on opening). An agent-vm that cannot be used is not run. A
# failed read leaves agent-vm's words in keys-error and no rows: old rows beside a new error
# would say two things.
keys_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    local _json _status
    _json="$(agentvm_agents_list)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$(ui_cache "$1" keys-error)"
        : | ui_store "$(ui_cache "$1" keys.tsv)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_agent_secret_rows | ui_store "$(ui_cache "$1" keys.tsv)"
    : | ui_store "$(ui_cache "$1" keys-error)"
    return 0
}

# keys_row <uuid> <key name> <agent id>  ->  that key's row (agentvm_agent_secret_rows), or
# nothing. Names are compared as text.
keys_row() {
    [ -n "$2" ] && [ -n "$3" ] || return 0
    main_rows "$1" keys | /usr/bin/awk -F'\t' -v name="$2" -v agent="$3" '$1 "" == name && $4 "" == agent' | /usr/bin/sed -n '1p'
}

# keys_selected_row <uuid>  ->  the row of the key the window works on, or nothing.
keys_selected_row() {
    keys_row "$1" "$(ui_get key "$1")" "$(ui_get keyagent "$1")"
}

# keys_selection_settled <uuid>  ->  0 when the table's selected row, as the engine handed it to
# this handler, is the key the window works on. A button clicked in the moment after another row
# was selected runs before the selection's own handler has recorded it: the table then shows one
# key and the window still works on the other.
keys_selection_settled() {
    [ "${OMC_ACTIONUI_TABLE_4001_COLUMN_2_VALUE:-}" = "$(ui_get key "$1")" ] \
        && [ "${OMC_ACTIONUI_TABLE_4001_COLUMN_5_VALUE:-}" = "$(ui_get keyagent "$1")" ]
}

# keys_say <uuid> <text>  ->  the text in the note, unless the note says why nothing is listed.
keys_say() {
    [ -z "$(keys_blocker "$1")" ] || return 0
    "$dialog" "$1" "$KEYS_NOTE_ID" "$2"
}

# -- What the window says ------------------------------------------------------------------------

# keys_blocker <uuid>  ->  why the keys cannot be listed, or nothing.
keys_blocker() {
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        main_agentvm_line "$1" 2
        return 0
    fi
    local _error="$(/bin/cat "$(ui_cache "$1" keys-error)" 2>/dev/null)"
    [ -n "$_error" ] && printf 'agent-vm could not list the agents: %s\n' "$_error"
    return 0
}

# keys_state_text <state>  ->  the Stored column.
keys_state_text() {
    case "$1" in
        set)     echo "Stored" ;;
        asks)    echo "Stored, macOS asks" ;;
        missing) echo "Not stored" ;;
        none)    echo "No key needed" ;;
        *)       printf '%s\n' "$1" ;;
    esac
}

# keys_table_rows <uuid>  ->  the table's rows: agent, key name, Stored, what the key is, and the
# agent's id in a column the table does not show.
keys_table_rows() {
    main_rows "$1" keys | {
        local _name _state _label _agent _agent_name _rest
        while IFS="$ui_tab" read -r _name _state _label _agent _agent_name _rest; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$_agent_name" "$_name" "$(keys_state_text "$_state")" "$_label" "$_agent"
        done
    }
}

# keys_hint_text <row>  ->  what the selected key's state means, how many of its keys the agent
# needs, and the agent's other way in.
keys_hint_text() {
    printf '%s\n' "$1" | {
        local _name _state _label _agent _agent_name _needed _login _note
        IFS="$ui_tab" read -r _name _state _label _agent _agent_name _needed _login _note
        local _text=""
        case "$_state" in
            set)     _text="Stored in your login Keychain. Store replaces it." ;;
            asks)    _text="Stored by another copy of agent-vm, so macOS asks before this one reads it: answer Always Allow then, or store the key again here." ;;
            missing) _text="Not stored." ;;
        esac
        case "$_state:$_needed" in
            none:*)     ;;
            *:one)      _text="$_text $_agent_name needs one of its keys." ;;
            *:optional) _text="$_text $_agent_name can run without it." ;;
        esac
        [ "$_login" != "-" ] && _text="$_text $_login"
        [ "$_note" != "-" ] && _text="$_text $_note"
        printf '%s\n' "${_text# }"
    }
}

# -- Painting ------------------------------------------------------------------------------------

# keys_paint_detail <uuid>  ->  the part under the table, for the key the window works on: its
# name, what its state means, and which of Store and Remove... can be used.
keys_paint_detail() {
    local _row="$(keys_selected_row "$1")"
    if [ -z "$_row" ]; then
        "$dialog" "$1" "$KEYS_TITLE_ID" "Select a key to store or remove it."
        "$dialog" "$1" "$KEYS_HINT_ID" ""
        ui_enable "$1" "$KEYS_STORE_ID" 0
        ui_enable "$1" "$KEYS_REMOVE_ID" 0
        return 0
    fi
    local _name="$(printf '%s\n' "$_row" | /usr/bin/cut -f1)"
    local _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    local _agent_name="$(printf '%s\n' "$_row" | /usr/bin/cut -f5)"
    "$dialog" "$1" "$KEYS_HINT_ID" "$(keys_hint_text "$_row")"
    if [ "$_state" = "none" ]; then
        "$dialog" "$1" "$KEYS_TITLE_ID" "$_agent_name needs no key."
        ui_enable "$1" "$KEYS_STORE_ID" 0
        ui_enable "$1" "$KEYS_REMOVE_ID" 0
        return 0
    fi
    "$dialog" "$1" "$KEYS_TITLE_ID" "$_name, for $_agent_name"
    ui_enable "$1" "$KEYS_STORE_ID" 1
    case "$_state" in
        set|asks) ui_enable "$1" "$KEYS_REMOVE_ID" 1 ;;
        *)        ui_enable "$1" "$KEYS_REMOVE_ID" 0 ;;
    esac
}

# keys_paint <uuid>  ->  the window from its cache: the table, with the key the window works on
# selected again when it is still listed, the part under it, and why nothing is listed.
keys_paint() {
    keys_table_rows "$1" | "$dialog" "$1" "$KEYS_TABLE_ID" omc_table_set_rows_from_stdin
    local _name="$(ui_get key "$1")"
    local _agent="$(ui_get keyagent "$1")"
    if [ -n "$(keys_row "$1" "$_name" "$_agent")" ]; then
        local _index="$(main_rows "$1" keys | /usr/bin/awk -F'\t' -v name="$_name" -v agent="$_agent" \
            '$1 "" == name && $4 "" == agent { print NR - 1; exit }')"
        "$dialog" "$1" "$KEYS_TABLE_ID" omc_select_row "$_index"
    else
        ui_set key "$1" ""
        ui_set keyagent "$1" ""
    fi
    keys_paint_detail "$1"
    "$dialog" "$1" "$KEYS_NOTE_ID" "$(keys_blocker "$1")"
}

# keys_refresh <uuid>  ->  reads the keys and paints. For the window that closed while agent-vm
# was read, or while this painted (painting reads the cache, which makes its folder again), the
# cache folder goes: so whether the window is still there is asked once more, last.
keys_refresh() {
    keys_read "$1"
    if ! keys_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    keys_paint "$1"
    keys_is "$1" || ui_cache_clear "$1"
    return 0
}
