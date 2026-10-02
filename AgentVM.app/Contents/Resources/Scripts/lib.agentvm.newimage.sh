#!/bin/sh
# lib.agentvm.newimage.sh
#
# The New Image window (AgentVM.newimage.json, the views 1001-1248): five steps that end in one
# `agent-vm image create`, started as a job. One window at a time (lib.agentvm.ui.sh, "Box
# windows", with the kind "newimage" and the name "window"), opened by the plus button under the
# main window's image list, or by New Image from This... in the image pane, which hands over the
# selected image as the start. Sources lib.agentvm.main.sh for which agent-vm runs and for telling
# the main window about the job.
#
# THE STEPS. 1 Start from: a ready image, of which the new one starts as a copy, or a macOS
# restore file agent-vm downloaded. 2 Tools: the recipes that come with the agent-vm in use, each
# with a checkbox; they are applied in the order listed, which is an order that satisfies what
# each needs. 3 Options: the input files and parameters the ticked recipes declare (skipped when
# they declare none). 4 Name and size. 5 Check: what will be built, what stands in the way, the
# command line, and Build.
#
# WHAT THE WINDOW KEEPS. Pasteboard values of the window: "newimage" (1 while it is open),
# "step", "start" ("image <name>" or "ipsw <file name>"), "ticks" (recipe names), "name", "cpus",
# "memory", "disk", "auto_name" and "auto_disk" (the last suggestions put into those fields,
# so that a suggestion the user did not change follows a changed start or tool), and "busy" (the
# click being worked on: newimage_enter). The values of
# the options are the cache file values.tsv (kind, name, value). Everything kept is checked again
# when it is read back, and a start is looked up in what agent-vm last listed.
#
# THE FIELDS ARE READ WHEN A BUTTON IS CLICKED, never per keystroke: a handler's view of the
# fields is a snapshot from the moment of its click, and the fields of a step are filled before
# the step is shown, so at Continue, Back or Choose... the snapshot is what the user sees. A
# checkbox click keeps the ticks the same way. Nothing in the window is set by the program while
# the user can edit it, except the one field Choose... fills.
#
# WHAT IT READS: `status` and the restore file list, into its own cache, on opening, on
# activation, when a start is chosen and before Build; the recipes once, on opening. It has no
# poll loop. Build starts the job, opens its progress window, has the main window follow it, and
# closes this window.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_NEWIMAGE_LIB:-}" ] && return 0
__AGENTVM_APP_NEWIMAGE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

NEW_HEADER_ID=1001
# The rail's marks of step n: to do 1010 + n, now 1020 + n, done 1030 + n. Its panel: 1040 + n.
NEW_RAIL_BASE=1010
NEW_PANEL_BASE=1040
NEW_SOURCES_ID=1051
NEW_TOOLS_TEXT_ID=1061
NEW_OPTIONS_TEXT_ID=1062
NEW_NAME_ID=1071
NEW_CPUS_ID=1072
NEW_MEMORY_ID=1073
NEW_DISK_ID=1074
NEW_SIZE_TEXT_ID=1075
NEW_SUMMARY_ID=1081
NEW_COMMAND_ID=1082
NEW_ADVICE_ID=1083
NEW_NOTE_ID=1091
NEW_CANCEL_ID=1092
NEW_BACK_ID=1093
NEW_NEXT_ID=1094
NEW_BUILD_ID=1095
# Recipe slot n: its row 1100 + n, checkbox 1110 + n, name 1120 + n, description 1130 + n, note
# 1140 + n. Option slot n: its rows 1200 + n, label 1210 + n, field 1220 + n, Choose... 1230 + n,
# description 1240 + n.
NEW_RECIPE_ROW_BASE=1100
NEW_RECIPE_TICK_BASE=1110
NEW_RECIPE_NAME_BASE=1120
NEW_RECIPE_TEXT_BASE=1130
NEW_RECIPE_NOTE_BASE=1140
NEW_OPTION_ROW_BASE=1200
NEW_OPTION_LABEL_BASE=1210
NEW_OPTION_FIELD_BASE=1220
NEW_OPTION_CHOOSE_BASE=1230
NEW_OPTION_TEXT_BASE=1240

NEW_STEPS=5
NEW_RECIPE_SLOTS=10
NEW_OPTION_SLOTS=8
# What `image create` gives an image built from a restore file when nothing is said.
NEW_DEFAULT_CPUS=4
NEW_DEFAULT_MEMORY=8
NEW_DEFAULT_DISK=64
# A copy's disk stays as it is or grows by at least this (agent-vm's rule); and what an image with
# Xcode is given when the start allows it.
NEW_DISK_GROWTH=8
NEW_XCODE_DISK=128
# The recipes agent-vm ships, in an order that satisfies what each needs. Any other recipe in its
# folder comes after them, by name.
NEW_RECIPE_ORDER="homebrew node python agent-clis acp-agents xcode xcode-platforms"

# newimage_is <uuid>  ->  0 while that window is an open New Image window.
newimage_is() {
    [ "$(ui_get newimage "$1")" = "1" ]
}

# newimage_step <uuid>  ->  the step shown, 1 to 5.
newimage_step() {
    case "$(ui_get step "$1")" in
        2) echo 2 ;;
        3) echo 3 ;;
        4) echo 4 ;;
        5) echo 5 ;;
        *) echo 1 ;;
    esac
}

# newimage_enter <uuid>  ->  0 when the handler that runs may act on a click: no other click of
# the window is still being worked on. A second click on Continue or Back made while the first
# one's step is being filled carries a snapshot of fields that were half filled, and would keep
# them as the next step's; a second click on Build would start a second job. The mark is
# "click-<the handler's process>", and goes when the handler exits; one whose process is gone (a
# handler that was killed) holds nothing.
newimage_enter() {
    local _holder="$(ui_get busy "$1")"
    case "$_holder" in
        click-|click-0*|click-*[!0123456789]*) ;;
        click-*)
            kill -0 "${_holder#click-}" 2>/dev/null && return 1 ;;
    esac
    ui_set busy "$1" "click-$$"
    newimage_busy_uuid="$1"
    trap 'newimage_leave' EXIT
    return 0
}

# newimage_leave  ->  the mark of newimage_enter goes, if this handler's it still is.
newimage_leave() {
    [ -n "${newimage_busy_uuid:-}" ] || return 0
    [ "$(ui_get busy "$newimage_busy_uuid")" = "click-$$" ] || return 0
    ui_set busy "$newimage_busy_uuid" ""
}

# newimage_listed <word> <lines>  ->  0 when the word is one of the lines.
newimage_listed() {
    case "
$2
" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

# newimage_step_title <n>
newimage_step_title() {
    case "$1" in
        1) echo "Start from" ;;
        2) echo "Tools" ;;
        3) echo "Options" ;;
        4) echo "Name and size" ;;
        *) echo "Check" ;;
    esac
}

# -- Reading -------------------------------------------------------------------------------------

# newimage_recipe_rows  ->  agentvm_recipe_rows in the order the window lists and applies them:
# NEW_RECIPE_ORDER first, then the others as the folder has them.
newimage_recipe_rows() {
    agentvm_recipe_rows | /usr/bin/awk -F'\t' -v order="$NEW_RECIPE_ORDER" '
        BEGIN { n = split(order, names, " "); for (i = 1; i <= n; i++) rank[names[i]] = i }
        { printf "%05d\t%s\n", (($1 in rank) ? rank[$1] : 1000 + NR), $0 }' \
        | /usr/bin/sort -s -k1,1 | /usr/bin/cut -f2-
}

# newimage_read <uuid> [full]  ->  0 with the cache files build.tsv (agentvm_status_build_rows),
# vm.tsv and ipsw.tsv (agentvm_ipsw_rows) read anew; "full" first checks which agent-vm runs and
# reads its recipes into recipes.tsv (on opening). An agent-vm that cannot be used is not run. A
# failed `status` keeps the previous rows and leaves its message in the cache file status-error;
# a failed restore file list keeps the previous list.
newimage_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
        if [ "$(main_agentvm_line "$1" 1)" = "0" ]; then
            newimage_recipe_rows | ui_store "$(ui_cache "$1" recipes.tsv)"
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
    printf '%s\n' "$_json" | agentvm_status_vm_row | ui_store "$(ui_cache "$1" vm.tsv)"
    : | ui_store "$_error"
    _json="$(agentvm_ipsw_list)"
    _status=$?
    if [ "$_status" -eq 0 ]; then
        printf '%s\n' "$_json" | agentvm_ipsw_rows | ui_store "$(ui_cache "$1" ipsw.tsv)"
    fi
    return 0
}

# newimage_unreadable <uuid>  ->  why agent-vm's lists are not known, or nothing.
newimage_unreadable() {
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        main_agentvm_line "$1" 2
        return 0
    fi
    local _error="$(main_status_error "$1")"
    [ -n "$_error" ] && printf 'agent-vm could not be read: %s\n' "$_error"
    return 0
}

# newimage_image_row <uuid> <name>  ->  that image's row of build.tsv, or nothing.
newimage_image_row() {
    main_rows "$1" build | /usr/bin/awk -F'\t' -v name="$2" '$1 == name { print; exit }'
}

# newimage_ipsw_row <uuid> <file name>  ->  that restore file's row of ipsw.tsv, or nothing.
newimage_ipsw_row() {
    main_rows "$1" ipsw | /usr/bin/awk -F'\t' -v name="$2" '$1 == name { print; exit }'
}

# -- The start -----------------------------------------------------------------------------------

# newimage_start <uuid>  ->  "image <name>" or "ipsw <file name>" as kept, or nothing when nothing
# is kept or it has neither form (it comes back from a pasteboard).
newimage_start() {
    local _start="$(ui_get start "$1")"
    newimage_valid_start "$_start" && printf '%s\n' "$_start"
    return 0
}

# newimage_valid_start <start>  ->  0 when it is "image <a name agent-vm accepts>" or "ipsw <a
# file name ending in .ipsw, with no folder in it>".
newimage_valid_start() {
    case "$1" in
        "image "*)
            agentvm_valid_name "${1#image }"
            return $? ;;
        "ipsw "*)
            case "${1#ipsw }" in
                ''|-*|*/*|*"$ui_tab"*) return 1 ;;
                *.ipsw) return 0 ;;
            esac ;;
    esac
    return 1
}

# newimage_start_name <uuid>  ->  the start's name: the image's, or the restore file's.
newimage_start_name() {
    local _start="$(newimage_start "$1")"
    [ -n "$_start" ] && printf '%s\n' "${_start#* }"
    return 0
}

# newimage_start_kind <uuid>  ->  image, ipsw, or nothing.
newimage_start_kind() {
    local _start="$(newimage_start "$1")"
    [ -n "$_start" ] && printf '%s\n' "${_start%% *}"
    return 0
}

# newimage_set_start <uuid> <start>  ->  keeps it. A start that changed makes the name and sizes
# the user had follow it again: they were about another image.
newimage_set_start() {
    [ "$(ui_get start "$1")" = "$2" ] && return 0
    ui_set start "$1" "$2"
    local _key
    for _key in name cpus memory disk auto_name auto_disk; do
        ui_set "$_key" "$1" ""
    done
}

# newimage_start_key <uuid> <the table's hidden key> <its first column>  ->  the start a selected
# row of the table stands for, or nothing. The key is "image <name>" or "ipsw <file name>"; when
# it did not arrive, the row is found by its name among what the table was filled from. A key of
# either form that does not hold a name is nothing.
newimage_start_key() {
    case "$2" in
        "image "*|"ipsw "*)
            newimage_valid_start "$2" && printf '%s\n' "$2"
            return 0 ;;
    esac
    [ -n "$3" ] || return 0
    if [ -n "$(newimage_image_row "$1" "$3")" ]; then
        printf 'image %s\n' "$3"
    elif [ -n "$(newimage_ipsw_row "$1" "$3")" ]; then
        printf 'ipsw %s\n' "$3"
    fi
    return 0
}

# newimage_base <uuid> <n>  ->  field n of the start image's row (agentvm_status_build_rows); for
# a restore file, the same fields as far as they apply: 4 its macOS, 5 to 7 agent-vm's defaults,
# anything else "-". Nothing chosen: "-".
newimage_base() {
    local _name="$(newimage_start_name "$1")"
    local _value=""
    case "$(newimage_start_kind "$1")" in
        image)
            _value="$(newimage_image_row "$1" "$_name" | /usr/bin/cut -f"$2")" ;;
        ipsw)
            case "$2" in
                4) _value="$(newimage_ipsw_row "$1" "$_name" | /usr/bin/cut -f2)" ;;
                5) _value="$NEW_DEFAULT_CPUS" ;;
                6) _value="$NEW_DEFAULT_MEMORY" ;;
                7) _value="$NEW_DEFAULT_DISK" ;;
            esac ;;
    esac
    printf '%s\n' "${_value:--}"
}

# newimage_start_text <uuid>  ->  the start in words: "image dev (macOS 27.0.1)", or "the restore
# file UniversalMac_27.0_26A428_Restore.ipsw (macOS 27.0)".
newimage_start_text() {
    local _name="$(newimage_start_name "$1")"
    local _macos="$(newimage_base "$1" 4)"
    local _suffix=""
    [ "$_macos" != "-" ] && _suffix=" (macOS $_macos)"
    case "$(newimage_start_kind "$1")" in
        image) printf 'image %s%s\n' "$_name" "$_suffix" ;;
        ipsw)  printf 'the restore file %s%s\n' "$_name" "$_suffix" ;;
    esac
}

# newimage_start_blocker <uuid>  ->  why the build cannot start from what is chosen, or nothing.
newimage_start_blocker() {
    local _name="$(newimage_start_name "$1")"
    local _row
    case "$(newimage_start_kind "$1")" in
        image)
            _row="$(newimage_image_row "$1" "$_name")"
            if [ -z "$_row" ]; then
                printf 'Image %s is not there any more. Choose another start.\n' "$_name"
            elif [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" != "ready" ]; then
                printf 'Image %s is not ready, so nothing can be built from it.\n' "$_name"
            elif [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)" = "true" ]; then
                printf 'Another command is changing image %s. A build can start from it when that has ended.\n' "$_name"
            fi ;;
        ipsw)
            [ -n "$(newimage_ipsw_row "$1" "$_name")" ] || printf 'The restore file %s is not there any more. Choose another start.\n' "$_name" ;;
        *)
            printf 'Choose what the new image starts from.\n' ;;
    esac
}

# newimage_source_rows <uuid>  ->  the rows of the start table: name, macOS, what it holds, its
# state, and (not shown) the key the row stands for. Ready images first, then the restore files.
# An image that is not ready is not listed: nothing can be built from it. What an image holds is
# the names of the recipes it keeps, else its recipe's description (as newimage_recipe_text
# shows one), else macOS.
newimage_source_rows() {
    main_rows "$1" build | /usr/bin/awk -F'\t' '
        $2 == "ready" {
            holds = ($8 != "-") ? $8 : (($9 != "-") ? $9 : "macOS")
            if ($8 != "-") gsub(/,/, ", ", holds)
            else sub(/ \([^()]*\)$/, "", holds)
            if ($10 != "-" && $8 == "-" && $9 == "-") holds = "macOS and the Command Line Tools"
            state = "ready"
            if ($11 ~ /full-disk-access/) state = "no Full Disk Access"
            if ($3 == "true") state = "being changed"
            printf "%s\t%s\t%s\t%s\timage %s\n", $1, $4, holds, state, $1
        }'
    main_rows "$1" ipsw | /usr/bin/awk -F'\t' '
        {
            size = ($4 ~ /^[0-9]+$/) ? sprintf("%.1f GB", $4 / 1000000000) : "-"
            printf "%s\t%s\ta restore file: macOS is installed from it\t%s\tipsw %s\n", $1, $2, size, $1
        }'
}

# -- The tools -----------------------------------------------------------------------------------

# newimage_recipe_names <uuid>  ->  the recipes the window has a slot for, one per line.
newimage_recipe_names() {
    main_rows "$1" recipes | /usr/bin/sed -n "1,${NEW_RECIPE_SLOTS}p" | /usr/bin/cut -f1
}

# newimage_recipe_field <uuid> <name> <n>  ->  field n of that recipe's row (agentvm_recipe_rows).
newimage_recipe_field() {
    main_rows "$1" recipes | /usr/bin/awk -F'\t' -v name="$2" -v n="$3" '$1 == name { print $n; exit }'
}

# newimage_recipe_text <description>  ->  agent-vm's description of a recipe without its closing
# parenthesis, which says where to put the recipe on a command line ("needs Homebrew: put
# Recipes/homebrew before it"): the window orders the recipes itself, and says what is missing.
newimage_recipe_text() {
    printf '%s\n' "$1" | /usr/bin/sed 's/ ([^()]*)$//'
}

# newimage_recipe_need <name>  ->  the recipe that one of agent-vm's own recipes needs before it,
# or nothing. agent-vm's recipes say this in words only (their descriptions, and a first step
# that fails at once); this table is those words.
newimage_recipe_need() {
    case "$1" in
        node|python)           echo "homebrew" ;;
        agent-clis|acp-agents) echo "node" ;;
        xcode-platforms)       echo "xcode" ;;
    esac
}

# newimage_ticks <uuid>  ->  the recipes ticked, one per line, in the order they are applied: what
# is kept, as far as it names a recipe the window lists.
newimage_ticks() {
    local _kept=" $(ui_get ticks "$1") "
    newimage_recipe_names "$1" | /usr/bin/awk -v kept="$_kept" 'index(kept, " " $1 " ") > 0'
}

# newimage_take_ticks <uuid>  ->  keeps the checkboxes as the handler that runs saw them (a
# checkbox's value is "true" or "false"; anything else is not ticked).
newimage_take_ticks() {
    local _ticks="" _name _value _slot=0
    for _name in $(newimage_recipe_names "$1"); do
        _slot=$((_slot + 1))
        eval "_value=\"\${OMC_ACTIONUI_VIEW_$((NEW_RECIPE_TICK_BASE + _slot))_VALUE:-}\""
        [ "$_value" = "true" ] && _ticks="${_ticks:+$_ticks }$_name"
    done
    ui_set ticks "$1" "$_ticks"
}

# newimage_held <uuid>  ->  the recipes the start image keeps, one per line (none for a restore file).
newimage_held() {
    local _names="$(newimage_base "$1" 8)"
    [ "$_names" = "-" ] && return 0
    printf '%s\n' "$_names" | /usr/bin/tr ',' '\n'
}

# newimage_holds_nothing <uuid>  ->  0 when the start is known to hold no recipe's tools: a
# restore file, or an image with no recipe at all. An image built before agent-vm listed the
# recipes kept has a description and no list, and what it holds is then not known here.
newimage_holds_nothing() {
    case "$(newimage_start_kind "$1")" in
        ipsw)  return 0 ;;
        image) [ "$(newimage_base "$1" 8)" = "-" ] && [ "$(newimage_base "$1" 9)" = "-" ] ;;
        *)     return 1 ;;
    esac
}

# newimage_missing <uuid>  ->  one line per ticked recipe that needs a recipe which is neither
# ticked nor kept by the start image: the recipe, a tab, what it needs.
newimage_missing() {
    local _ticks="$(newimage_ticks "$1")"
    local _held="$(newimage_held "$1")"
    local _name _need
    for _name in $_ticks; do
        _need="$(newimage_recipe_need "$_name")"
        [ -n "$_need" ] || continue
        newimage_listed "$_need" "$_ticks" && continue
        newimage_listed "$_need" "$_held" && continue
        printf '%s\t%s\n' "$_name" "$_need"
    done
}

# newimage_tools_blocker <uuid>  ->  why the tools ticked cannot be built on this start, or
# nothing: a recipe needs another, and the start is known not to hold it.
newimage_tools_blocker() {
    newimage_holds_nothing "$1" || return 0
    local _first="$(newimage_missing "$1" | /usr/bin/sed -n '1p')"
    [ -n "$_first" ] || return 0
    printf '%s needs %s: tick %s too.\n' "${_first%%"$ui_tab"*}" "${_first#*"$ui_tab"}" "${_first#*"$ui_tab"}"
}

# newimage_tools_warning <uuid>  ->  what may be missing, when it is not known what the start
# image holds, or nothing.
newimage_tools_warning() {
    newimage_holds_nothing "$1" && return 0
    local _first="$(newimage_missing "$1" | /usr/bin/sed -n '1p')"
    [ -n "$_first" ] || return 0
    printf '%s needs %s. Tick %s too, unless image %s already has it: the build stops at its first step when it does not.\n' \
        "${_first%%"$ui_tab"*}" "${_first#*"$ui_tab"}" "${_first#*"$ui_tab"}" "$(newimage_start_name "$1")"
}

# newimage_tools_text <uuid>  ->  the line above the recipes.
newimage_tools_text() {
    if [ -z "$(newimage_recipe_names "$1")" ]; then
        printf 'No recipes were found beside this agent-vm, so the new image is %s as it is.\n' "$(newimage_start_text "$1")"
        return 0
    fi
    printf 'Tick the tools to install on top of %s. They are installed in the order listed. With nothing ticked, the new image is the start as it is.\n' \
        "$(newimage_start_text "$1")"
}

# newimage_recipe_note <uuid> <name>  ->  the note beside a recipe: that the start image has it,
# or what it needs that is neither ticked nor in the start image.
newimage_recipe_note() {
    local _need="$(newimage_missing "$1" | /usr/bin/awk -F'\t' -v name="$2" '$1 == name { print $2; exit }')"
    if [ -n "$_need" ]; then
        printf 'needs %s\n' "$_need"
        return 0
    fi
    newimage_listed "$2" "$(newimage_held "$1")" && printf '%s has it\n' "$(newimage_start_name "$1")"
    return 0
}

# -- The options ---------------------------------------------------------------------------------

# newimage_option_rows <uuid>  ->  what the ticked recipes ask for (agentvm_recipe_option_rows):
# the input files first, then the parameters, each name once, as agent-vm gives one value to
# every recipe that declares the name.
newimage_option_rows() {
    local _name
    for _name in $(newimage_ticks "$1"); do
        agentvm_recipe_option_rows "$(newimage_recipe_field "$1" "$_name" 5)"
    done | /usr/bin/awk -F'\t' '!seen[$1 FS $2]++ { printf "%s\t%s\n", ($1 == "input") ? 1 : 2, $0 }' \
        | /usr/bin/sort -s -k1,1 | /usr/bin/cut -f2-
}

# newimage_value <uuid> <kind> <name> <default>  ->  the value kept for that option, else its
# default ("-" is none).
newimage_value() {
    local _file="$(ui_cache "$1" values.tsv)"
    local _kept=""
    if [ -f "$_file" ]; then
        _kept="$(/usr/bin/awk -F'\t' -v kind="$2" -v name="$3" '$1 == kind && $2 == name { print "=" $3; exit }' "$_file")"
    fi
    if [ -n "$_kept" ]; then
        printf '%s\n' "${_kept#=}"
        return 0
    fi
    [ "$4" = "-" ] || printf '%s\n' "$4"
    return 0
}

# newimage_keep_value <uuid> <kind> <name> <value>  ->  keeps one option's value.
newimage_keep_value() {
    local _file="$(ui_cache "$1" values.tsv)"
    [ -f "$_file" ] || : > "$_file"
    {
        /usr/bin/awk -F'\t' -v kind="$2" -v name="$3" '!($1 == kind && $2 == name)' "$_file"
        printf '%s\t%s\t%s\n' "$2" "$3" "$4"
    } | ui_store "$_file"
}

# newimage_take_options <uuid>  ->  keeps the option fields as the handler that runs saw them: the
# first NEW_OPTION_SLOTS options, in newimage_option_rows's order, are the fields. A value is one
# line; a path that begins with "~/" is in the home folder.
newimage_take_options() {
    local _rows="$(newimage_option_rows "$1" | /usr/bin/sed -n "1,${NEW_OPTION_SLOTS}p")"
    [ -n "$_rows" ] || return 0
    local _slot=0 _kind _name _rest _value
    while IFS="$ui_tab" read -r _kind _name _rest; do
        [ -n "$_name" ] || continue
        _slot=$((_slot + 1))
        eval "_value=\"\${OMC_ACTIONUI_VIEW_$((NEW_OPTION_FIELD_BASE + _slot))_VALUE:-}\""
        _value="$(ui_one_line "$_value")"
        if [ "$_kind" = "input" ]; then
            case "$_value" in
                "~/"*) _value="$HOME/${_value#"~/"}" ;;
            esac
        fi
        newimage_keep_value "$1" "$_kind" "$_name" "$_value"
    done <<EOF
$_rows
EOF
}

# newimage_options_blocker <uuid>  ->  why the options are not complete, or nothing: an input
# file is not named, or is not a file on this Mac.
newimage_options_blocker() {
    local _rows="$(newimage_option_rows "$1")"
    [ -n "$_rows" ] || return 0
    local _slot=0 _kind _name _default _text _value
    while IFS="$ui_tab" read -r _kind _name _default _text; do
        _slot=$((_slot + 1))
        [ "$_kind" = "input" ] || continue
        if [ "$_slot" -gt "$NEW_OPTION_SLOTS" ]; then
            printf 'This window has room for %s options, and %s is a file one of the recipes needs. Build this image with agent-vm image create in Terminal.\n' "$NEW_OPTION_SLOTS" "$_name"
            return 0
        fi
        _value="$(newimage_value "$1" input "$_name" -)"
        if [ -z "$_value" ]; then
            if [ "$_text" = "-" ]; then
                printf 'Choose the file for %s.\n' "$_name"
            else
                printf 'Choose the file for %s: %s.\n' "$_name" "$_text"
            fi
            return 0
        fi
        case "$_value" in
            /*) ;;
            *)  printf 'The file for %s must be a full path, starting with "/" or "~/".\n' "$_name"
                return 0 ;;
        esac
        if [ ! -f "$_value" ]; then
            printf '%s is not a file on this Mac.\n' "$_value"
            return 0
        fi
    done <<EOF
$_rows
EOF
}

# newimage_options_text <uuid>  ->  the line above the option fields.
newimage_options_text() {
    local _count="$(newimage_option_rows "$1" | /usr/bin/awk 'END { print NR }')"
    if [ "$_count" -gt "$NEW_OPTION_SLOTS" ]; then
        printf 'What the tools you ticked ask for. The first %s are here; the other %s keep their defaults.\n' "$NEW_OPTION_SLOTS" "$((_count - NEW_OPTION_SLOTS))"
    else
        printf 'What the tools you ticked ask for. A parameter left as it is keeps its default.\n'
    fi
}

# -- Name and size -------------------------------------------------------------------------------

# newimage_name_taken <uuid> <name>  ->  0 when an image of that name is listed.
newimage_name_taken() {
    [ -n "$(newimage_image_row "$1" "$2")" ]
}

# newimage_suggested_name <uuid>  ->  a free name for the new image: for a copy, the start's name
# and the tool ticked ("dev-node"), "-tools" for several, "-copy" for none; "dev" for a build from
# a restore file; with a number when that is taken.
newimage_suggested_name() {
    local _base="dev"
    local _ticks _count
    if [ "$(newimage_start_kind "$1")" = "image" ]; then
        _ticks="$(newimage_ticks "$1")"
        _count="$(printf '%s\n' "$_ticks" | /usr/bin/awk 'NF { n++ } END { print n + 0 }')"
        case "$_count" in
            0) _base="$(newimage_start_name "$1")-copy" ;;
            1) _base="$(newimage_start_name "$1")-$_ticks" ;;
            *) _base="$(newimage_start_name "$1")-tools" ;;
        esac
    fi
    local _name="$_base"
    local _n=2
    while newimage_name_taken "$1" "$_name" && [ "$_n" -lt 100 ]; do
        _name="$_base$_n"
        _n=$((_n + 1))
    done
    printf '%s\n' "$_name"
}

# newimage_suggested_disk <uuid>  ->  the disk the fields start with, in GB: the start's, or
# NEW_XCODE_DISK when xcode is ticked and the start's disk can grow to it.
newimage_suggested_disk() {
    local _disk="$(newimage_base "$1" 7)"
    case "$_disk" in
        ''|*[!0123456789]*) _disk="$NEW_DEFAULT_DISK" ;;
    esac
    if newimage_listed xcode "$(newimage_ticks "$1")" && [ $((_disk + NEW_DISK_GROWTH)) -le "$NEW_XCODE_DISK" ]; then
        _disk="$NEW_XCODE_DISK"
    fi
    printf '%s\n' "$_disk"
}

# newimage_prepare_sizes <uuid>  ->  the name and sizes kept made ready for their fields: a name or
# disk that is empty, or is still the suggestion last made, becomes the suggestion for the start
# and tools as they are now; empty processors and memory become the start's.
newimage_prepare_sizes() {
    local _suggestion="$(newimage_suggested_name "$1")"
    local _kept="$(ui_get name "$1")"
    if [ -z "$_kept" ] || [ "$_kept" = "$(ui_get auto_name "$1")" ]; then
        ui_set name "$1" "$_suggestion"
        ui_set auto_name "$1" "$_suggestion"
    fi
    _suggestion="$(newimage_suggested_disk "$1")"
    _kept="$(ui_get disk "$1")"
    if [ -z "$_kept" ] || [ "$_kept" = "$(ui_get auto_disk "$1")" ]; then
        ui_set disk "$1" "$_suggestion"
        ui_set auto_disk "$1" "$_suggestion"
    fi
    [ -n "$(ui_get cpus "$1")" ] || ui_set cpus "$1" "$(newimage_base "$1" 5)"
    [ -n "$(ui_get memory "$1")" ] || ui_set memory "$1" "$(newimage_base "$1" 6)"
}

# newimage_take_sizes <uuid>  ->  keeps the name and size fields as the handler that runs saw
# them, each on one line and without the spaces around it.
newimage_take_sizes() {
    local _key _id _value
    for _key in name cpus memory disk; do
        case "$_key" in
            name)   _id="$NEW_NAME_ID" ;;
            cpus)   _id="$NEW_CPUS_ID" ;;
            memory) _id="$NEW_MEMORY_ID" ;;
            *)      _id="$NEW_DISK_ID" ;;
        esac
        eval "_value=\"\${OMC_ACTIONUI_VIEW_${_id}_VALUE:-}\""
        _value="$(ui_one_line "$_value" | /usr/bin/sed 's/^ *//; s/ *$//')"
        ui_set "$_key" "$1" "$_value"
    done
}

# newimage_number <text>  ->  0 when it is a whole number, 1 or more, of at most 5 digits.
newimage_number() {
    case "$1" in
        ''|*[!0123456789]*|0*) return 1 ;;
    esac
    [ "${#1}" -le 5 ]
}

# newimage_sizes_blocker <uuid>  ->  why the name or a size cannot be used, or nothing.
newimage_sizes_blocker() {
    local _name="$(ui_get name "$1")"
    if [ -z "$_name" ]; then
        printf 'Give the new image a name.\n'
        return 0
    fi
    if ! agentvm_valid_name "$_name"; then
        printf '"%s" cannot be a name: lower-case letters, digits, ".", "_" and "-", starting with a letter or a digit, at most 63 characters.\n' "$_name"
        return 0
    fi
    if newimage_name_taken "$1" "$_name"; then
        printf 'An image named %s is there already.\n' "$_name"
        return 0
    fi
    if ! newimage_number "$(ui_get cpus "$1")"; then
        printf 'Processors: a whole number, 1 or more.\n'
        return 0
    fi
    if ! newimage_number "$(ui_get memory "$1")"; then
        printf 'Memory: a whole number of GB.\n'
        return 0
    fi
    local _disk="$(ui_get disk "$1")"
    if ! newimage_number "$_disk"; then
        printf 'Disk: a whole number of GB.\n'
        return 0
    fi
    [ "$(newimage_start_kind "$1")" = "image" ] || return 0
    local _base="$(newimage_base "$1" 7)"
    newimage_number "$_base" || return 0
    if [ "$_disk" -ne "$_base" ] && [ "$_disk" -lt $((_base + NEW_DISK_GROWTH)) ]; then
        printf 'The disk can stay at %s GB, as in image %s, or grow to %s GB or more. It cannot shrink.\n' \
            "$_base" "$(newimage_start_name "$1")" "$((_base + NEW_DISK_GROWTH))"
    fi
    return 0
}

# newimage_size_text <uuid>  ->  the line under the size fields.
newimage_size_text() {
    if [ "$(newimage_start_kind "$1")" = "image" ]; then
        printf "These start as image %s has them. The disk is a sparse file, which takes only what is written to it; the disk of a copy stays as it is or grows by at least %s GB.\n" \
            "$(newimage_start_name "$1")" "$NEW_DISK_GROWTH"
    else
        printf "These start as the defaults of agent-vm. The disk is a sparse file, which takes only what is written to it.\n"
    fi
    newimage_listed xcode "$(newimage_ticks "$1")" && printf 'Xcode takes about 4 GB and each simulator runtime about 8 GB: %s GB or more is a good disk for it.\n' "$NEW_XCODE_DISK"
    return 0
}

# -- The build -----------------------------------------------------------------------------------

# newimage_args <uuid>  ->  the arguments of `image create`, one per line, as
# agentvm_job_image_create takes them: the name, the start, the recipes ticked in their order,
# every input file, the parameters that are not at their defaults, and the sizes that are not the
# start's; for a build from a restore file all three sizes, so that what Check says is what is
# built whatever agent-vm's defaults are. Nothing when no start is known, or when the name or a
# size kept is not a name or a number: each is one argument, and comes back from a pasteboard.
newimage_args() {
    agentvm_valid_name "$(ui_get name "$1")" || return 0
    newimage_number "$(ui_get cpus "$1")" || return 0
    newimage_number "$(ui_get memory "$1")" || return 0
    newimage_number "$(ui_get disk "$1")" || return 0
    local _from="$(newimage_start_kind "$1")"
    local _name="$(newimage_start_name "$1")"
    local _path
    case "$(newimage_start_kind "$1")" in
        image)
            printf '%s\n--from\n%s\n' "$(ui_get name "$1")" "$_name" ;;
        ipsw)
            _path="$(newimage_ipsw_row "$1" "$_name" | /usr/bin/cut -f6)"
            [ -n "$_path" ] || return 0
            printf '%s\n--ipsw\n%s\n' "$(ui_get name "$1")" "$_path" ;;
        *)  return 0 ;;
    esac
    local _recipe
    for _recipe in $(newimage_ticks "$1"); do
        printf -- '--recipe\n%s\n' "$(newimage_recipe_field "$1" "$_recipe" 5)"
    done
    local _rows="$(newimage_option_rows "$1")"
    local _kind _option _default _text _value
    if [ -n "$_rows" ]; then
        while IFS="$ui_tab" read -r _kind _option _default _text; do
            _value="$(newimage_value "$1" "$_kind" "$_option" "$_default")"
            if [ "$_kind" = "input" ]; then
                printf -- '--input\n%s=%s\n' "$_option" "$_value"
            else
                [ "$_default" = "-" ] && _default=""
                [ "$_value" = "$_default" ] || printf -- '--set\n%s=%s\n' "$_option" "$_value"
            fi
        done <<EOF
$_rows
EOF
    fi
    local _key _field
    for _key in cpus memory disk; do
        case "$_key" in
            cpus)   _field=5 ;;
            memory) _field=6 ;;
            *)      _field=7 ;;
        esac
        _value="$(ui_get "$_key" "$1")"
        [ "$_from" = "image" ] && [ "$_value" = "$(newimage_base "$1" "$_field")" ] && continue
        case "$_key" in
            cpus)   printf -- '--cpus\n%s\n' "$_value" ;;
            memory) printf -- '--memory-gb\n%s\n' "$_value" ;;
            *)      printf -- '--disk-gb\n%s\n' "$_value" ;;
        esac
    done
}

# newimage_command_text <uuid>  ->  the command Build runs, as it would be typed in Terminal.
newimage_command_text() {
    printf 'agent-vm image create %s\n' "$(newimage_args "$1" | agentvm_args_text)"
}

# newimage_blocker <uuid>  ->  why the build cannot be started now, or nothing: agent-vm cannot be
# read, something about the start, the tools, the options or the name changed since its step, or
# every virtual machine slot is taken, since a build runs the image in one.
newimage_blocker() {
    local _why="$(newimage_unreadable "$1")"
    [ -n "$_why" ] || _why="$(newimage_start_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_tools_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_options_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_sizes_blocker "$1")"
    if [ -n "$_why" ]; then
        printf '%s\n' "$_why"
        return 0
    fi
    main_rows "$1" vm | /usr/bin/awk -F'\t' '
        NR == 1 && $1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ && $1 + 0 >= $2 + 0 {
            printf "%s of %s virtual machines are running, and a build needs one. Stop a box first.\n", $1, $2 }'
}

# newimage_summary_text <uuid>  ->  what Build makes, in words.
newimage_summary_text() {
    local _name="$(ui_get name "$1")"
    local _ticks="$(newimage_ticks "$1")"
    if [ "$(newimage_start_kind "$1")" = "image" ]; then
        printf 'Image %s, built as a copy of %s.\n' "$_name" "$(newimage_start_text "$1")"
    else
        printf 'Image %s, with macOS installed from %s.\n' "$_name" "$(newimage_start_text "$1")"
    fi
    if [ -n "$_ticks" ]; then
        printf 'Tools, installed in this order: %s.\n' "$(ui_lines_text "$_ticks")"
    else
        printf 'No tools are added.\n'
    fi
    printf '%s CPUs, %s GB of memory, a %s GB disk.\n' "$(ui_get cpus "$1")" "$(ui_get memory "$1")" "$(ui_get disk "$1")"
}

# newimage_advice_text <uuid>  ->  what to know before the build: a need that may be missing, what
# Full Disk Access will be in the new image, and that the window can go.
newimage_advice_text() {
    newimage_tools_warning "$1"
    local _name="$(newimage_start_name "$1")"
    if [ "$(newimage_start_kind "$1")" = "ipsw" ]; then
        printf 'An image built from a restore file has no Full Disk Access yet: Set Up... in its pane grants it, once, after the build.\n'
    else
        case "$(newimage_base "$1" 11)" in
            *full-disk-access*)
                printf 'Image %s has no Full Disk Access, so the new image will have none either. Set Up... in the pane of either grants it.\n' "$_name" ;;
            *)  printf 'The new image keeps the Full Disk Access of image %s.\n' "$_name" ;;
        esac
    fi
    printf 'The build runs as a job. Its progress window opens, and the build goes on when the windows, or the app, are closed.\n'
}

# -- Painting ------------------------------------------------------------------------------------

# newimage_paint_sources <uuid>  ->  the start table from the cache, with the start kept selected.
newimage_paint_sources() {
    newimage_source_rows "$1" | "$dialog" "$1" "$NEW_SOURCES_ID" omc_table_set_rows_from_stdin
    local _name="$(newimage_start_name "$1")"
    [ -n "$_name" ] && "$dialog" "$1" "$NEW_SOURCES_ID" omc_select_row_with_content "$_name" 1
    return 0
}

# newimage_paint_recipe_notes <uuid>  ->  the note beside each recipe, and the line under the step.
newimage_paint_recipe_notes() {
    local _slot=0 _name
    for _name in $(newimage_recipe_names "$1"); do
        _slot=$((_slot + 1))
        "$dialog" "$1" "$((NEW_RECIPE_NOTE_BASE + _slot))" "$(newimage_recipe_note "$1" "$_name")"
    done
    local _note="$(newimage_tools_blocker "$1")"
    [ -n "$_note" ] || _note="$(newimage_tools_warning "$1")"
    "$dialog" "$1" "$NEW_NOTE_ID" "$_note"
}

# newimage_paint_recipes <uuid>  ->  the recipe slots: one shown per recipe, with its name and
# description. The checkboxes are the user's and are not set.
newimage_paint_recipes() {
    "$dialog" "$1" "$NEW_TOOLS_TEXT_ID" "$(newimage_tools_text "$1")"
    local _slot=0 _name
    for _name in $(newimage_recipe_names "$1"); do
        _slot=$((_slot + 1))
        "$dialog" "$1" "$((NEW_RECIPE_NAME_BASE + _slot))" "$_name"
        "$dialog" "$1" "$((NEW_RECIPE_TEXT_BASE + _slot))" "$(newimage_recipe_text "$(newimage_recipe_field "$1" "$_name" 2)")"
        ui_show "$1" "$((NEW_RECIPE_ROW_BASE + _slot))" 1
    done
    newimage_paint_recipe_notes "$1"
}

# newimage_paint_options <uuid>  ->  the option slots: one shown per option, with its name, the
# value kept or its default in the field, what it is, and Choose... for a file.
newimage_paint_options() {
    "$dialog" "$1" "$NEW_OPTIONS_TEXT_ID" "$(newimage_options_text "$1")"
    local _rows="$(newimage_option_rows "$1" | /usr/bin/sed -n "1,${NEW_OPTION_SLOTS}p")"
    local _slot=0 _kind _name _default _text
    if [ -n "$_rows" ]; then
        while IFS="$ui_tab" read -r _kind _name _default _text; do
            _slot=$((_slot + 1))
            "$dialog" "$1" "$((NEW_OPTION_LABEL_BASE + _slot))" "$_name"
            "$dialog" "$1" "$((NEW_OPTION_FIELD_BASE + _slot))" "$(newimage_value "$1" "$_kind" "$_name" "$_default")"
            [ "$_text" = "-" ] && _text=""
            if [ "$_kind" = "input" ]; then
                "$dialog" "$1" "$((NEW_OPTION_TEXT_BASE + _slot))" "A file: $_text"
                ui_show "$1" "$((NEW_OPTION_CHOOSE_BASE + _slot))" 1
            else
                "$dialog" "$1" "$((NEW_OPTION_TEXT_BASE + _slot))" "$_text"
                ui_show "$1" "$((NEW_OPTION_CHOOSE_BASE + _slot))" 0
            fi
            ui_show "$1" "$((NEW_OPTION_ROW_BASE + _slot))" 1
        done <<EOF
$_rows
EOF
    fi
    while [ "$_slot" -lt "$NEW_OPTION_SLOTS" ]; do
        _slot=$((_slot + 1))
        ui_show "$1" "$((NEW_OPTION_ROW_BASE + _slot))" 0
    done
}

# newimage_paint_sizes <uuid>  ->  the name and size fields from what is kept, and the line under them.
newimage_paint_sizes() {
    newimage_prepare_sizes "$1"
    "$dialog" "$1" "$NEW_NAME_ID" "$(ui_get name "$1")"
    "$dialog" "$1" "$NEW_CPUS_ID" "$(ui_get cpus "$1")"
    "$dialog" "$1" "$NEW_MEMORY_ID" "$(ui_get memory "$1")"
    "$dialog" "$1" "$NEW_DISK_ID" "$(ui_get disk "$1")"
    "$dialog" "$1" "$NEW_SIZE_TEXT_ID" "$(newimage_size_text "$1")"
}

# newimage_paint_check <uuid>  ->  the last step: what is built, the advice, the command line, what
# stands in the way, and Build on when nothing does.
newimage_paint_check() {
    "$dialog" "$1" "$NEW_SUMMARY_ID" "$(newimage_summary_text "$1")"
    "$dialog" "$1" "$NEW_ADVICE_ID" "$(newimage_advice_text "$1")"
    "$dialog" "$1" "$NEW_COMMAND_ID" "$(newimage_command_text "$1")"
    local _blocker="$(newimage_blocker "$1")"
    "$dialog" "$1" "$NEW_NOTE_ID" "$_blocker"
    if [ -z "$_blocker" ]; then
        ui_enable "$1" "$NEW_BUILD_ID" 1
    else
        ui_enable "$1" "$NEW_BUILD_ID" 0
    fi
}

# newimage_paint_frame <uuid> [note]  ->  what every step has: the header, the rail's marks, the
# panel of the step shown, Back, Continue or Build, and the note line.
newimage_paint_frame() {
    local _step="$(newimage_step "$1")"
    "$dialog" "$1" "$NEW_HEADER_ID" "Step $_step of $NEW_STEPS - $(newimage_step_title "$_step")"
    local _n=0 _todo _now _done
    while [ "$_n" -lt "$NEW_STEPS" ]; do
        _n=$((_n + 1))
        _todo=0
        _now=0
        _done=0
        if [ "$_n" -lt "$_step" ]; then
            _done=1
        elif [ "$_n" -eq "$_step" ]; then
            _now=1
        else
            _todo=1
        fi
        ui_show "$1" "$((NEW_RAIL_BASE + _n))" "$_todo"
        ui_show "$1" "$((NEW_RAIL_BASE + 10 + _n))" "$_now"
        ui_show "$1" "$((NEW_RAIL_BASE + 20 + _n))" "$_done"
        if [ "$_n" -eq "$_step" ]; then
            ui_show "$1" "$((NEW_PANEL_BASE + _n))" 1
        else
            ui_show "$1" "$((NEW_PANEL_BASE + _n))" 0
        fi
    done
    if [ "$_step" -gt 1 ]; then
        ui_enable "$1" "$NEW_BACK_ID" 1
    else
        ui_enable "$1" "$NEW_BACK_ID" 0
    fi
    if [ "$_step" -eq "$NEW_STEPS" ]; then
        ui_show "$1" "$NEW_NEXT_ID" 0
        ui_show "$1" "$NEW_BUILD_ID" 1
    else
        ui_show "$1" "$NEW_BUILD_ID" 0
        ui_show "$1" "$NEW_NEXT_ID" 1
    fi
    "$dialog" "$1" "$NEW_NOTE_ID" "${2:-}"
}

# newimage_show <uuid> <step>  ->  that step shown, its fields filled first: the step is kept,
# its panel is painted from what is kept, then the frame changes.
newimage_show() {
    ui_set step "$1" "$2"
    case "$2" in
        1) newimage_paint_frame "$1" "$(newimage_unreadable "$1")" ;;
        2) newimage_paint_frame "$1"
           newimage_paint_recipes "$1" ;;
        3) newimage_paint_options "$1"
           newimage_paint_frame "$1" ;;
        4) newimage_paint_sizes "$1"
           newimage_paint_frame "$1" ;;
        *) newimage_paint_frame "$1"
           newimage_paint_check "$1" ;;
    esac
}

# newimage_refresh <uuid>  ->  reads agent-vm again and repaints what follows it without touching
# a field: the note of step 1, the recipe notes of step 2, the whole of step 5. For the window
# that closed while agent-vm was read, the cache folder the reading made again goes.
newimage_refresh() {
    newimage_read "$1"
    if ! newimage_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    case "$(newimage_step "$1")" in
        1) "$dialog" "$1" "$NEW_NOTE_ID" "$(newimage_unreadable "$1")" ;;
        2) newimage_paint_recipe_notes "$1" ;;
        5) newimage_paint_check "$1" ;;
    esac
    return 0
}
