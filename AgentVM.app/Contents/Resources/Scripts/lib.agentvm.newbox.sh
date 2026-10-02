#!/bin/sh
# lib.agentvm.newbox.sh
#
# The New Box window (AgentVM.newbox.json, the views 2001-2095): four steps that end in one
# `agent-vm box create`, and, when asked, a job that starts the box. One window at a time
# (lib.agentvm.ui.sh, "Box windows", with the kind "newbox" and the name "window"), opened by the
# plus button under the main window's box list, or by New Box from It... in the image pane, which
# hands over the selected image. The frame of steps is lib.agentvm.wizard.sh; the rules of a
# network are checked as the network window checks them (lib.agentvm.network.sh).
#
# THE STEPS. 1 Image: a ready image, of which the box is a copy. 2 Network: the mode, the packs
# and the other hosts the box may reach, with the hosts of the agents the image holds already
# there. 3 Name and size, and whether the box is started. 4 Check: what is made, the command
# line, what stands in the way, and Create.
#
# WHAT THE WINDOW KEEPS. Pasteboard values of the window: "newbox" (1 while it is open), "step",
# "picked" (the row selected in the image table, kept as it is selected), "image" (the image the
# steps after the first are about), "mode", "name", "cpus", "memory", "auto_name" (the last name
# suggested, so that a suggestion the user did not change can follow), "start" (true when the box
# is started once made) and "busy" (the click being worked on: wizard_enter). The rules are the
# cache file "rules", one per line, and "seeded" holds the ones put there for the image's
# agents. Everything kept is checked again when it is read back, and the image is looked up in
# what agent-vm last listed.
#
# THE RULES ARE THE APP'S, NOT A CONTROL'S: a pack, and "Any public host name", is a cell whose
# whole box is one click target that flips it, as in the network window, so the hosts of the
# image's agents can be ticked before the user sees the step. The name and size fields are read
# when a button is clicked, never per keystroke.
#
# WHICH AGENTS AN IMAGE HOLDS is read from words: an agent of agent-vm's own list (agents.json)
# counts as held when its id is a word of a description of a recipe the image keeps ("Claude
# Code, Codex and opencode"). agent-vm does not say it any other way. A wrong guess costs a rule
# ticked or not ticked, which the step shows and the user can change; avm asks about an agent's
# hosts again when it runs one.
#
# WHAT IT READS: `status`, into its own cache, on opening, on activation, when an image is
# chosen and before Create; the packs and the agents once, on opening. It has no poll loop.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_NEWBOX_LIB:-}" ] && return 0
__AGENTVM_APP_NEWBOX_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

# The frame's views are this base plus what lib.agentvm.wizard.sh lists.
NBOX_BASE=2000
NBOX_HEADER_ID=2001
NBOX_IMAGES_ID=2051
NBOX_IMAGE_NOTE_ID=2052
NBOX_ACCESS_ID=2053
NBOX_AGENTS_TEXT_ID=2060
NBOX_MODE_ID=2061
NBOX_MODE_NOTE_ID=2062
NBOX_PACKS_ID=2063
NBOX_PUBLIC_ID=2064
NBOX_PUBLIC_SYMBOL_ID=2065
NBOX_HOSTS_ID=2066
NBOX_HOST_FIELD_ID=2067
NBOX_ADD_ID=2068
NBOX_REMOVE_ID=2069
NBOX_NAME_ID=2071
NBOX_CPUS_ID=2072
NBOX_MEMORY_ID=2073
NBOX_START_ID=2074
NBOX_SIZE_TEXT_ID=2075
NBOX_SUMMARY_ID=2081
NBOX_COMMAND_ID=2082
NBOX_ADVICE_ID=2083
NBOX_NOTE_ID=2091
NBOX_CANCEL_ID=2092
NBOX_BACK_ID=2093
NBOX_NEXT_ID=2094
NBOX_CREATE_ID=2095

NBOX_STEPS=4
# What agent-vm accepts for a box.
NBOX_MAX_CPUS=256
NBOX_MAX_MEMORY=4096
# The name a first box is offered.
NBOX_NAME="work"
# Every value the window keeps on the pasteboard: emptied on opening and on closing.
NBOX_KEYS="newbox step picked image mode name cpus memory auto_name start busy"

# newbox_is <uuid>  ->  0 while that window is an open New Box window.
newbox_is() {
    [ "$(ui_get newbox "$1")" = "1" ]
}

# newbox_step <uuid>  ->  the step shown, 1 to 4.
newbox_step() {
    case "$(ui_get step "$1")" in
        2) echo 2 ;;
        3) echo 3 ;;
        4) echo 4 ;;
        *) echo 1 ;;
    esac
}

# newbox_step_title <n>
newbox_step_title() {
    case "$1" in
        1) echo "Image" ;;
        2) echo "Network" ;;
        3) echo "Name and size" ;;
        *) echo "Check" ;;
    esac
}

# -- Reading -------------------------------------------------------------------------------------

# newbox_read <uuid> [full]  ->  0 with the cache files build.tsv (agentvm_status_build_rows),
# boxes.tsv and vm.tsv read anew; "full" first checks which agent-vm runs, and reads its agents
# into agents.tsv and its packs into packs.tsv (on opening). An agent-vm that cannot be used is
# not run. A failed `status` keeps the previous rows and leaves its message in the cache file
# status-error; packs that cannot be read leave their message in packs-error.
newbox_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
        if [ "$(main_agentvm_line "$1" 1)" = "0" ]; then
            agentvm_agent_rows | ui_store "$(ui_cache "$1" agents.tsv)"
            local _packs _packs_status
            _packs="$(agentvm_box_packs)"
            _packs_status=$?
            if [ "$_packs_status" -eq 0 ]; then
                printf '%s\n' "$_packs" | agentvm_packs_rows | ui_store "$(ui_cache "$1" packs.tsv)"
                : | ui_store "$(ui_cache "$1" packs-error)"
            else
                ui_one_line "$(agentvm_last_error "$_packs_status")" | ui_store "$(ui_cache "$1" packs-error)"
            fi
        fi
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    local _error="$(ui_cache "$1" status-error)"
    local _json _status
    _json="$(agentvm_status)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_status_build_rows | ui_store "$(ui_cache "$1" build.tsv)"
    printf '%s\n' "$_json" | agentvm_status_box_rows | ui_store "$(ui_cache "$1" boxes.tsv)"
    printf '%s\n' "$_json" | agentvm_status_vm_row | ui_store "$(ui_cache "$1" vm.tsv)"
    : | ui_store "$_error"
    return 0
}

# newbox_unreadable <uuid>  ->  why agent-vm's lists are not known, or nothing.
newbox_unreadable() {
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        main_agentvm_line "$1" 2
        return 0
    fi
    local _error="$(main_status_error "$1")"
    [ -n "$_error" ] && printf 'agent-vm could not be read: %s\n' "$_error"
    return 0
}

# newbox_image_row <uuid> <name>  ->  that image's row of build.tsv, or nothing.
newbox_image_row() {
    main_rows "$1" build | /usr/bin/awk -F'\t' -v name="$2" '$1 == name { print; exit }'
}

# -- The image -----------------------------------------------------------------------------------

# newbox_image <uuid>  ->  the image the box is made from, as kept, or nothing when nothing is
# kept or it is not a name (it comes back from a pasteboard).
newbox_image() {
    local _image="$(ui_get image "$1")"
    agentvm_valid_name "$_image" && printf '%s\n' "$_image"
    return 0
}

# newbox_field <uuid> <n>  ->  field n of the image's row (agentvm_status_build_rows), or "-".
newbox_field() {
    local _image="$(newbox_image "$1")"
    local _value=""
    [ -n "$_image" ] && _value="$(newbox_image_row "$1" "$_image" | /usr/bin/cut -f"$2")"
    printf '%s\n' "${_value:--}"
}

# newbox_image_text <uuid>  ->  the image in words: "image dev (macOS 27.0.1)".
newbox_image_text() {
    local _macos="$(newbox_field "$1" 4)"
    local _suffix=""
    [ "$_macos" != "-" ] && _suffix=" (macOS $_macos)"
    printf 'image %s%s\n' "$(newbox_image "$1")" "$_suffix"
}

# newbox_picked <uuid> <the table's hidden key> <its first column>  ->  the image a selected row
# of the table stands for, or nothing: the key when it is a name, else the first column when it
# names an image listed.
newbox_picked() {
    if [ -n "$2" ]; then
        agentvm_valid_name "$2" && printf '%s\n' "$2"
        return 0
    fi
    [ -n "$3" ] && agentvm_valid_name "$3" || return 0
    [ -n "$(newbox_image_row "$1" "$3")" ] && printf '%s\n' "$3"
    return 0
}

# newbox_image_blocker <uuid> [image]  ->  why a box cannot be made from the image kept (or the
# one given), or nothing.
newbox_image_blocker() {
    local _image="${2:-$(newbox_image "$1")}"
    if [ -z "$_image" ]; then
        printf 'Choose the image the box is made from.\n'
        return 0
    fi
    local _row="$(newbox_image_row "$1" "$_image")"
    if [ -z "$_row" ]; then
        printf 'Image %s is not there any more. Choose another.\n' "$_image"
    elif [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" != "ready" ]; then
        printf 'Image %s is not ready, so no box can be made from it.\n' "$_image"
    elif [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)" = "true" ]; then
        printf 'Another command is changing image %s. A box can be made from it when that has ended.\n' "$_image"
    fi
}

# newbox_needs_access <uuid> <image>  ->  0 when that image has no Full Disk Access yet.
newbox_needs_access() {
    case "$(newbox_image_row "$1" "$2" | /usr/bin/cut -f11)" in
        *full-disk-access*) return 0 ;;
    esac
    return 1
}

# newbox_image_rows <uuid>  ->  the rows of the image table: name, macOS, what it holds, its
# state, and (not shown) the name again as the row's key. An image that is not ready is not
# listed: no box can be made from it. What an image holds is the names of the recipes it keeps,
# else its recipe's description without its advice for the command line, else macOS.
newbox_image_rows() {
    main_rows "$1" build | /usr/bin/awk -F'\t' '
        $2 == "ready" {
            holds = ($8 != "-") ? $8 : (($9 != "-") ? $9 : "macOS")
            if ($8 != "-") gsub(/,/, ", ", holds)
            else sub(/ \([^()]*\)$/, "", holds)
            if ($10 != "-" && $8 == "-" && $9 == "-") holds = "macOS and the Command Line Tools"
            state = "ready"
            if ($11 ~ /full-disk-access/) state = "no Full Disk Access"
            if ($3 == "true") state = "being changed"
            printf "%s\t%s\t%s\t%s\t%s\n", $1, $4, holds, state, $1
        }'
}

# newbox_agents <uuid> <image>  ->  the rows of agents.tsv (id, name, rules) for the agents that
# image holds: those whose id is a word of a description of a recipe it keeps.
newbox_agents() {
    local _row="$(newbox_image_row "$1" "$2")"
    [ -n "$_row" ] || return 0
    # Without each description's closing parenthesis, which names other tools ("needs Node").
    local _text="$(printf '%s\n' "$_row" | /usr/bin/cut -f9,12 | /usr/bin/tr '\t' ';' | /usr/bin/sed -E 's/ \([^()]*\)(;|$)/\1/g' \
        | /usr/bin/tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' \
        | /usr/bin/sed 's/[^abcdefghijklmnopqrstuvwxyz0123456789-]/ /g')"
    main_rows "$1" agents | /usr/bin/awk -F'\t' -v text=" $_text " 'index(text, " " $1 " ") > 0'
}

# newbox_agent_names <uuid> <image>  ->  the names of those agents: "Claude Code, Codex and
# opencode", or nothing.
newbox_agent_names() {
    local _names="$(newbox_agents "$1" "$2" | /usr/bin/cut -f2)"
    [ -n "$_names" ] && ui_lines_text "$_names"
    return 0
}

# newbox_selection_text <uuid> <image>  ->  the line under the image table for the row selected.
newbox_selection_text() {
    [ -n "$2" ] || return 0
    local _blocker="$(newbox_image_blocker "$1" "$2")"
    if [ -n "$_blocker" ]; then
        printf '%s\n' "$_blocker"
        return 0
    fi
    if newbox_needs_access "$1" "$2"; then
        printf 'Image %s has no Full Disk Access yet. In a box made from it now, a program that opens Desktop, Documents or Downloads waits on a question nobody sees. Set Up... grants it first, once, on the image.\n' "$2"
        return 0
    fi
    local _row="$(newbox_image_row "$1" "$2")"
    local _agents="$(newbox_agent_names "$1" "$2")"
    printf 'Image %s: %s CPUs, %s GB of memory, Full Disk Access granted.%s\n' "$2" \
        "$(printf '%s\n' "$_row" | /usr/bin/cut -f5)" "$(printf '%s\n' "$_row" | /usr/bin/cut -f6)" \
        "${_agents:+ Agents in it: $_agents.}"
}

# -- The rules -----------------------------------------------------------------------------------

# newbox_rules <uuid>  ->  the rules the box is given, one per line.
newbox_rules() {
    local _file="$(ui_cache "$1" rules)"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# newbox_write_rules <uuid> <rules>  ->  keeps them, each one once, in their order.
newbox_write_rules() {
    printf '%s\n' "$2" | /usr/bin/awk 'NF && !seen[$0]++' | ui_store "$(ui_cache "$1" rules)"
}

# newbox_rule_wanted <uuid> <rule>  ->  0 when the rule is one of them.
newbox_rule_wanted() {
    newbox_rules "$1" | /usr/bin/grep -qxF -- "$2"
}

# newbox_add_rule, newbox_remove_rule, newbox_flip_rule <uuid> <rule>
newbox_add_rule() {
    newbox_write_rules "$1" "$(newbox_rules "$1")
$2"
}
newbox_remove_rule() {
    newbox_write_rules "$1" "$(newbox_rules "$1" | /usr/bin/grep -vxF -- "$2")"
}
newbox_flip_rule() {
    newbox_rule_wanted "$1" "$2"
    local _wanted=$?
    if [ "$_wanted" -eq 0 ]; then
        newbox_remove_rule "$1" "$2"
    else
        newbox_add_rule "$1" "$2"
    fi
}

# newbox_agent_rule_rows <uuid> <image>  ->  one row per rule an agent of that image needs: the
# rule as agent-vm reads it, and the agent's name. What is not a rule is left out.
newbox_agent_rule_rows() {
    local _rows="$(newbox_agents "$1" "$2")"
    [ -n "$_rows" ] || return 0
    local _id _name _allow _rule _checked
    while IFS="$ui_tab" read -r _id _name _allow; do
        [ "$_allow" = "-" ] && continue
        # Read line by line: a rule left unquoted for the shell to split ("*.example.com") would
        # also be matched against the files of the folder the handler runs in.
        printf '%s\n' "$_allow" | /usr/bin/tr ',' '\n' | /usr/bin/awk 'NF == 1 { print $1 }' | while IFS= read -r _rule; do
            _checked="$(net_check_rule "$_rule")"
            [ -n "$_checked" ] && printf '%s\t%s\n' "$_checked" "$_name"
        done
    done <<EOF
$_rows
EOF
}

# newbox_agent_rules <uuid> <image>  ->  those rules, one per line, each once.
newbox_agent_rules() {
    newbox_agent_rule_rows "$1" "$2" | /usr/bin/cut -f1 | /usr/bin/awk '!seen[$0]++'
}

# newbox_set_image <uuid> <image>  ->  keeps the image the steps are about. One that changed takes
# the rules put there for the last image's agents with it and brings its own; the other rules
# stay. (A rule the user added that is also one of those agents' goes with them: the window
# does not keep who added a rule.) The name and sizes follow the new image again.
newbox_set_image() {
    [ "$(ui_get image "$1")" = "$2" ] && return 0
    ui_set image "$1" "$2"
    local _seeded="$(ui_cache "$1" seeded)"

    local _new="$(newbox_agent_rules "$1" "$2")"
    # The file is read by awk itself: a value of several lines cannot be given to it with -v.
    local _kept="$(newbox_rules "$1" | /usr/bin/awk -v seeded="$_seeded" '
        BEGIN { while ((getline line < seeded) > 0) if (line != "") gone[line] = 1 }
        !($0 in gone)')"
    newbox_write_rules "$1" "$_new
$_kept"
    printf '%s\n' "$_new" | ui_store "$_seeded"
    local _key
    for _key in name cpus memory auto_name; do
        ui_set "$_key" "$1" ""
    done
}

# newbox_mode <uuid>  ->  the network mode kept: allowlist (also when nothing is kept), off or open.
newbox_mode() {
    case "$(ui_get mode "$1")" in
        off)  echo off ;;
        open) echo open ;;
        *)    echo allowlist ;;
    esac
}

# newbox_pack_rows <uuid>  ->  the packs grid's rows: the box symbol (ticked when the pack is one
# of the rules), name, description (the help), color.
newbox_pack_rows() {
    main_rows "$1" packs | /usr/bin/awk -F'\t' -v rules="$(ui_cache "$1" rules)" '
        BEGIN { while ((getline line < rules) > 0) want[line] = 1 }
        { printf "%s\t%s\t%s\tprimary\n", ((("pack:" $1) in want) ? "checkmark.square.fill" : "square"), $1, $2 }'
}

# newbox_host_rows <uuid>  ->  the other hosts table's rows: each rule that is neither a pack nor
# "public", and the agents of the image that need it ("for opencode").
newbox_host_rows() {
    local _needed="$(ui_cache "$1" agent-rules.tsv)"
    newbox_agent_rule_rows "$1" "$(newbox_image "$1")" | ui_store "$_needed"
    newbox_rules "$1" | /usr/bin/awk -F'\t' -v needed="$_needed" '
        BEGIN {
            while ((getline line < needed) > 0) {
                split(line, cell, "\t")
                need[cell[1]] = (cell[1] in need) ? need[cell[1]] ", " cell[2] : cell[2]
            }
        }
        $0 ~ /^pack:/ || $0 == "public" { next }
        { printf "%s\t%s\n", $0, (($0 in need) ? "for " need[$0] : "") }'
}

# newbox_agents_text <uuid>  ->  the line above the network settings: whose hosts are there already.
newbox_agents_text() {
    local _image="$(newbox_image "$1")"
    local _names="$(newbox_agent_names "$1" "$_image")"
    if [ -n "$_names" ]; then
        printf 'What the box may reach. Image %s holds %s: what they need is allowed already.\n' "$_image" "$_names"
    else
        printf 'What the box may reach. No agent is known in image %s, so nothing is allowed yet.\n' "$_image"
    fi
    local _error="$(/bin/cat "$(ui_cache "$1" packs-error)" 2>/dev/null)"
    [ -n "$_error" ] && printf 'The packs could not be read: %s\n' "$_error"
    return 0
}

# newbox_network_text <uuid>  ->  the network the box gets, in words.
newbox_network_text() {
    local _rules="$(newbox_rules "$1")"
    case "$(newbox_mode "$1")" in
        off)  printf 'Network: off. Every connection is refused.\n' ;;
        open) printf 'Network: open. The box reaches the internet and your local network, and its connections are not logged.\n' ;;
        *)    if [ -n "$_rules" ]; then
                  printf 'Network: only %s.\n' "$(ui_lines_text "$_rules")"
              else
                  printf 'Network: nothing is allowed yet. Rules can be added later in the Network window of the box.\n'
              fi ;;
    esac
}

# -- Name and size -------------------------------------------------------------------------------

# newbox_name_taken <uuid> <name>  ->  0 when a box of that name is listed.
newbox_name_taken() {
    [ -n "$(main_row "$1" boxes "$2")" ]
}

# newbox_suggested_name <uuid>  ->  a free name for the box: NBOX_NAME, with a number when taken.
newbox_suggested_name() {
    local _name="$NBOX_NAME"
    local _n=2
    while newbox_name_taken "$1" "$_name" && [ "$_n" -lt 100 ]; do
        _name="$NBOX_NAME$_n"
        _n=$((_n + 1))
    done
    printf '%s\n' "$_name"
}

# newbox_prepare_sizes <uuid>  ->  the name and sizes kept made ready for their fields: a name that
# is empty, or is still the suggestion last made, becomes the suggestion as it is now; empty
# processors and memory become the image's.
newbox_prepare_sizes() {
    local _suggestion="$(newbox_suggested_name "$1")"
    local _kept="$(ui_get name "$1")"
    if [ -z "$_kept" ] || [ "$_kept" = "$(ui_get auto_name "$1")" ]; then
        ui_set name "$1" "$_suggestion"
        ui_set auto_name "$1" "$_suggestion"
    fi
    [ -n "$(ui_get cpus "$1")" ] || ui_set cpus "$1" "$(newbox_field "$1" 5)"
    [ -n "$(ui_get memory "$1")" ] || ui_set memory "$1" "$(newbox_field "$1" 6)"
}

# newbox_take_sizes <uuid>  ->  keeps the name and size fields, and the start checkbox, as the
# handler that runs saw them: each field on one line and without the spaces around it.
newbox_take_sizes() {
    local _key _id _value
    for _key in name cpus memory; do
        case "$_key" in
            name) _id="$NBOX_NAME_ID" ;;
            cpus) _id="$NBOX_CPUS_ID" ;;
            *)    _id="$NBOX_MEMORY_ID" ;;
        esac
        eval "_value=\"\${OMC_ACTIONUI_VIEW_${_id}_VALUE:-}\""
        _value="$(ui_one_line "$_value" | /usr/bin/sed 's/^ *//; s/ *$//')"
        ui_set "$_key" "$1" "$_value"
    done
    eval "_value=\"\${OMC_ACTIONUI_VIEW_${NBOX_START_ID}_VALUE:-}\""
    if [ "$_value" = "true" ]; then
        ui_set start "$1" "true"
    else
        ui_set start "$1" "false"
    fi
}

# newbox_starts <uuid>  ->  0 when the box is started once it is made.
newbox_starts() {
    [ "$(ui_get start "$1")" = "true" ]
}

# newbox_sizes_blocker <uuid>  ->  why the name or a size cannot be used, or nothing.
newbox_sizes_blocker() {
    local _name="$(ui_get name "$1")"
    if [ -z "$_name" ]; then
        printf 'Give the box a name.\n'
        return 0
    fi
    if ! agentvm_valid_name "$_name"; then
        printf '"%s" cannot be a name: lower-case letters, digits, ".", "_" and "-", starting with a letter or a digit, at most 63 characters.\n' "$_name"
        return 0
    fi
    if newbox_name_taken "$1" "$_name"; then
        printf 'A box named %s is there already.\n' "$_name"
        return 0
    fi
    local _cpus="$(ui_get cpus "$1")"
    if ! wizard_number "$_cpus" || [ "$_cpus" -gt "$NBOX_MAX_CPUS" ]; then
        printf 'Processors: a whole number from 1 to %s.\n' "$NBOX_MAX_CPUS"
        return 0
    fi
    local _memory="$(ui_get memory "$1")"
    if ! wizard_number "$_memory" || [ "$_memory" -gt "$NBOX_MAX_MEMORY" ]; then
        printf 'Memory: a whole number of GB, from 1 to %s.\n' "$NBOX_MAX_MEMORY"
    fi
    return 0
}

# newbox_size_text <uuid>  ->  the line under the size fields.
newbox_size_text() {
    printf 'These start as image %s has them. The disk of a box is the image'"'"'s, and takes room only for what the box writes.\n' "$(newbox_image "$1")"
}

# -- Making the box ------------------------------------------------------------------------------

# newbox_args <uuid>  ->  the arguments of `box create`, one per line, as agentvm_box_create takes
# them: the name, the image, the processors and memory that are not the image's, the mode when
# it is not agent-vm's default, and every rule. Nothing when no image is kept, or when the name
# or a size kept is not a name or a number: each is one argument, and comes back from a
# pasteboard.
newbox_args() {
    local _image="$(newbox_image "$1")"
    [ -n "$_image" ] || return 0
    agentvm_valid_name "$(ui_get name "$1")" || return 0
    wizard_number "$(ui_get cpus "$1")" || return 0
    wizard_number "$(ui_get memory "$1")" || return 0
    printf '%s\n--image\n%s\n' "$(ui_get name "$1")" "$_image"
    [ "$(ui_get cpus "$1")" = "$(newbox_field "$1" 5)" ] || printf -- '--cpus\n%s\n' "$(ui_get cpus "$1")"
    [ "$(ui_get memory "$1")" = "$(newbox_field "$1" 6)" ] || printf -- '--memory-gb\n%s\n' "$(ui_get memory "$1")"
    local _mode="$(newbox_mode "$1")"
    [ "$_mode" = "allowlist" ] || printf -- '--net\n%s\n' "$_mode"
    # Split into words by awk, not by the shell, which would also match a rule ("*.example.com")
    # against the files of the folder the handler runs in.
    newbox_rules "$1" | /usr/bin/awk '{ for (i = 1; i <= NF; i++) printf "--allow\n%s\n", $i }'
}

# newbox_command_text <uuid>  ->  the commands Create runs, as they would be typed in Terminal.
newbox_command_text() {
    printf 'agent-vm box create %s\n' "$(newbox_args "$1" | agentvm_args_text)"
    newbox_starts "$1" && printf 'agent-vm box start %s\n' "$(ui_get name "$1")"
    return 0
}

# newbox_blocker <uuid>  ->  why the box cannot be made now, or nothing: agent-vm cannot be read,
# something about the image or the name changed since its step, or the box is to be started and
# every virtual machine slot is taken.
newbox_blocker() {
    local _why="$(newbox_unreadable "$1")"
    [ -n "$_why" ] || _why="$(newbox_image_blocker "$1")"
    [ -n "$_why" ] || _why="$(newbox_sizes_blocker "$1")"
    if [ -n "$_why" ]; then
        printf '%s\n' "$_why"
        return 0
    fi
    newbox_starts "$1" || return 0
    main_rows "$1" vm | /usr/bin/awk -F'\t' '
        NR == 1 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $1 + 0 >= $2 + 0 {
            printf "%s of %s virtual machines are running, so the box cannot be started now. Stop a box first, or go back and choose not to start it.\n", $1, $2 }'
}

# newbox_summary_text <uuid>  ->  what Create makes, in words.
newbox_summary_text() {
    printf 'Box %s, a copy of %s.\n' "$(ui_get name "$1")" "$(newbox_image_text "$1")"
    printf '%s CPUs, %s GB of memory.\n' "$(ui_get cpus "$1")" "$(ui_get memory "$1")"
    newbox_network_text "$1"
    if [ "$(newbox_mode "$1")" != "allowlist" ] && [ -n "$(newbox_rules "$1")" ]; then
        printf 'Its rules (%s) are kept for when the mode is allowlist.\n' "$(ui_lines_text "$(newbox_rules "$1")")"
    fi
    if newbox_starts "$1"; then
        printf 'It is started once made, and runs until it is stopped.\n'
    else
        printf 'It is not started.\n'
    fi
}

# newbox_advice_text <uuid>  ->  what to know before the box is made.
newbox_advice_text() {
    local _image="$(newbox_image "$1")"
    if newbox_needs_access "$1" "$_image"; then
        printf 'Image %s has no Full Disk Access, so the box has none either: a program in it that opens Desktop, Documents or Downloads waits on a question nobody sees. Set Up... on the first step grants it; a box made before that gets it when it is recreated.\n' "$_image"
    fi
    printf 'The box is kept until it is deleted. What is installed or written in it stays in the box, and its network can be changed later in its Network window.\n'
}

# -- Painting ------------------------------------------------------------------------------------

# newbox_paint_images <uuid>  ->  the image table from the cache with the row picked selected, the
# line under it, and Set Up... on when that image has no Full Disk Access.
newbox_paint_images() {
    newbox_image_rows "$1" | "$dialog" "$1" "$NBOX_IMAGES_ID" omc_table_set_rows_from_stdin
    local _picked="$(ui_get picked "$1")"
    agentvm_valid_name "$_picked" || _picked=""
    [ -n "$_picked" ] && "$dialog" "$1" "$NBOX_IMAGES_ID" omc_select_row_with_content "$_picked" 1
    newbox_paint_selection "$1" "$_picked"
}

# newbox_paint_selection <uuid> <image>  ->  the line under the image table, and Set Up....
newbox_paint_selection() {
    "$dialog" "$1" "$NBOX_IMAGE_NOTE_ID" "$(newbox_selection_text "$1" "$2")"
    if [ -n "$2" ] && [ -z "$(newbox_image_blocker "$1" "$2")" ] && newbox_needs_access "$1" "$2"; then
        ui_enable "$1" "$NBOX_ACCESS_ID" 1
    else
        ui_enable "$1" "$NBOX_ACCESS_ID" 0
    fi
}

# newbox_paint_network <uuid>  ->  the network step from what is kept: the mode and what it lets
# through, the packs, public, the other hosts. The hosts table loses its selection, and Remove
# is off until a row is selected again.
newbox_paint_network() {
    local _mode="$(newbox_mode "$1")"
    "$dialog" "$1" "$NBOX_AGENTS_TEXT_ID" "$(newbox_agents_text "$1")"
    # The picker's value is the mode's 1-based index. Setting it fires nothing.
    "$dialog" "$1" "$NBOX_MODE_ID" "$(printf '%s\n' $net_modes | /usr/bin/awk -v mode="$_mode" '$0 == mode { print NR }')"
    "$dialog" "$1" "$NBOX_MODE_NOTE_ID" "$(net_mode_text "$_mode" stopped)"
    newbox_pack_rows "$1" | "$dialog" "$1" "$NBOX_PACKS_ID" omc_table_set_rows_from_stdin
    local _public="square"
    newbox_rule_wanted "$1" public && _public="checkmark.square.fill"
    "$dialog" "$1" "$NBOX_PUBLIC_SYMBOL_ID" omc_set_property systemName "$_public"
    newbox_host_rows "$1" | "$dialog" "$1" "$NBOX_HOSTS_ID" omc_table_set_rows_from_stdin
    "$dialog" "$1" "$NBOX_HOSTS_ID" omc_deselect
    ui_enable "$1" "$NBOX_REMOVE_ID" 0
}

# newbox_paint_sizes <uuid>  ->  the name and size fields from what is kept, and the line under
# them. The start checkbox is the user's and is not set.
newbox_paint_sizes() {
    newbox_prepare_sizes "$1"
    "$dialog" "$1" "$NBOX_NAME_ID" "$(ui_get name "$1")"
    "$dialog" "$1" "$NBOX_CPUS_ID" "$(ui_get cpus "$1")"
    "$dialog" "$1" "$NBOX_MEMORY_ID" "$(ui_get memory "$1")"
    "$dialog" "$1" "$NBOX_SIZE_TEXT_ID" "$(newbox_size_text "$1")"
}

# newbox_paint_check <uuid>  ->  the last step: what is made, the advice, the command line, what
# stands in the way, and Create on when nothing does.
newbox_paint_check() {
    "$dialog" "$1" "$NBOX_SUMMARY_ID" "$(newbox_summary_text "$1")"
    "$dialog" "$1" "$NBOX_ADVICE_ID" "$(newbox_advice_text "$1")"
    "$dialog" "$1" "$NBOX_COMMAND_ID" "$(newbox_command_text "$1")"
    local _blocker="$(newbox_blocker "$1")"
    "$dialog" "$1" "$NBOX_NOTE_ID" "$_blocker"
    if [ -z "$_blocker" ]; then
        ui_enable "$1" "$NBOX_CREATE_ID" 1
    else
        ui_enable "$1" "$NBOX_CREATE_ID" 0
    fi
}

# newbox_paint_frame <uuid> [note]  ->  what every step has (wizard_paint_frame).
newbox_paint_frame() {
    local _step="$(newbox_step "$1")"
    wizard_paint_frame "$1" "$NBOX_BASE" "$NBOX_STEPS" "$_step" "$(newbox_step_title "$_step")" "${2:-}"
}

# newbox_show <uuid> <step>  ->  that step shown, its views filled first: the step is kept, its
# panel is painted from what is kept, then the frame changes.
newbox_show() {
    ui_set step "$1" "$2"
    case "$2" in
        1) newbox_paint_images "$1"
           newbox_paint_frame "$1" "$(newbox_unreadable "$1")" ;;
        2) newbox_paint_network "$1"
           newbox_paint_frame "$1" ;;
        3) newbox_paint_sizes "$1"
           newbox_paint_frame "$1" ;;
        *) newbox_paint_frame "$1"
           newbox_paint_check "$1" ;;
    esac
}

# newbox_refresh <uuid>  ->  reads agent-vm again and repaints what follows it without touching a
# field: the image table of step 1 (an image may have got its Full Disk Access meanwhile), the
# whole of step 4. For the window that closed while agent-vm was read, the cache folder the
# reading made again goes.
newbox_refresh() {
    newbox_read "$1"
    if ! newbox_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    case "$(newbox_step "$1")" in
        1) newbox_paint_images "$1"
           "$dialog" "$1" "$NBOX_NOTE_ID" "$(newbox_unreadable "$1")" ;;
        4) newbox_paint_check "$1" ;;
    esac
    return 0
}
