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
# THE STEPS. 1 Start from: a ready image, of which the new one starts as a copy, a Linux system
# agent-vm builds from its distribution's cloud image, or a macOS restore file agent-vm
# downloaded. 2 Tools: the recipes that come with the agent-vm in use, each with a checkbox; they
# are applied in the order listed, which is an order that satisfies what each needs; a recipe
# file of the user's own, added with Add a Recipe File..., joins the list after them. 3 Options:
# the input files and parameters the ticked recipes declare (skipped when they declare none).
# 4 Name and size. 5 Check: what will be built, what stands in the way, the command line, and
# Build.
#
# MACOS AND LINUX. The new image runs what its start runs (newimage_guest): a copy of a Linux
# image is a Linux image, and so is one built from a Linux system. A recipe is for macOS images,
# for Linux images, or for both, as agent-vm says of each (`recipe check`), and the Tools step
# lists the ones for the start's system and the ones for both. What a recipe needs before it, the
# least a copy's disk may grow by, the places for macOS virtual machines, and everything about
# Full Disk Access follow the start's system too. The Linux systems offered, the sizes a new
# image starts with, the smallest disk and the least a copy's disk grows by are what the
# agent-vm in use says (`version --json`), never names or numbers of this window's own.
#
# WHAT THE WINDOW KEEPS. Pasteboard values of the window: "newimage" (1 while it is open),
# "step", "start" ("image <name>", "linux <a Linux system's id>" or "ipsw <file name>"), "ticks"
# (recipe names), "slots" (the recipes the checkboxes were last laid out for, in the slots'
# order), "name", "cpus", "memory", "disk", "auto_name" and "auto_disk" (the last suggestions
# put into those fields, so that a suggestion the user did not change follows a changed start or
# tool), "busy" (the click being worked on: newimage_enter), "taken" (the image Delete... offers
# to delete, while the button is shown) and "delete" (the image the question now open asks
# about). The values of the options are the cache file values.tsv (kind, name, value), and the
# recipes the user added the cache file own.tsv (a row each, as newimage_recipe_rows gives one).
# Everything kept is checked again when it is read back, and a start is looked up in what
# agent-vm last listed.
#
# THE FIELDS ARE READ WHEN A BUTTON IS CLICKED, never per keystroke: a handler's view of the
# fields is a snapshot from the moment of its click, and the fields of a step are filled before
# the step is shown, so at Continue, Back or Choose... the snapshot is what the user sees. A
# checkbox click keeps the ticks the same way. Nothing in the window is set by the program while
# the user can edit it, except the one field Choose... fills, and the checkbox of a slot whose
# recipe became another one because the start's system changed (newimage_paint_recipes).
#
# WHAT IT READS: `status` and the restore file list, into its own cache, on opening, on
# activation, when a start is chosen and before Build; the recipes, the Linux systems and the
# sizes once, on opening. It has no poll loop. Build starts the job, opens its progress window,
# has the main window follow it, and closes this window.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_NEWIMAGE_LIB:-}" ] && return 0
__AGENTVM_APP_NEWIMAGE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

# The frame's views are this base plus what lib.agentvm.wizard.sh lists.
NEW_BASE=1000
NEW_HEADER_ID=1001
NEW_SOURCES_ID=1051
NEW_GET_MACOS_ID=1052
NEW_TOOLS_TEXT_ID=1061
NEW_OPTIONS_TEXT_ID=1062
NEW_ADD_RECIPE_ID=1063
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
# Beside the note line, while the note is about a name taken by an image that is not ready.
NEW_DELETE_ID=1096
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
# The disk an image with Xcode is given when the start allows it, in GB.
NEW_XCODE_DISK=128
# The recipes agent-vm ships, for macOS images and for Linux images, in an order that satisfies
# what each needs whichever of the two the start is. Any other recipe in its folder comes after
# them, by name.
NEW_RECIPE_ORDER="homebrew node python linux-node linux-python agent-clis acp-agents xcode xcode-platforms linux-sudo"
# The program that lists the recipes from the window's cache files (newimage_recipes).
NEW_RECIPES_AWK="$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.recipes.awk"

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

# newimage_enter <uuid>  ->  0 when the handler that runs may act on a click (wizard_enter): a
# second click on Continue or Back made while the first one's step is being filled would keep
# half-filled fields as the next step's, and a second click on Build would start a second job.
newimage_enter() {
    wizard_enter "$1"
}

# newimage_listed <word> <lines>  ->  0 when the word is one of the lines.
newimage_listed() {
    wizard_listed "$1" "$2"
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

# newimage_recipe_rows  ->  agentvm_recipe_rows with a sixth field, the guest each recipe is for
# (macos, linux, or any for both), in the order the window lists and applies them:
# NEW_RECIPE_ORDER first, then the others as the folder has them. agent-vm is asked about them
# all in one run (`recipe check`), and its answer is matched by path. A recipe it says no guest
# of (it refuses the file, or could not be asked) has "-" there: it is offered for every start,
# and agent-vm refuses it, in its words, when it is ticked.
newimage_recipe_rows() {
    local _rows="$(agentvm_recipe_rows)"
    [ -n "$_rows" ] || return 0
    local _paths="$(printf '%s\n' "$_rows" | /usr/bin/cut -f5)"
    local _path
    set --
    while IFS= read -r _path; do
        [ -n "$_path" ] && set -- "$@" "$_path"
    done <<EOF
$_paths
EOF
    {
        agentvm_recipe_check "$@" | agentvm_recipe_check_rows | /usr/bin/cut -f5,9
        printf '%s\n' "$_rows"
    } | /usr/bin/awk -F'\t' -v order="$NEW_RECIPE_ORDER" '
        BEGIN { n = split(order, names, " "); for (i = 1; i <= n; i++) rank[names[i]] = i }
        NF == 2 { guest[$1] = $2; next }
        NF == 5 { printf "%05d\t%s\t%s\n", (($1 in rank) ? rank[$1] : 1000 + NR), $0, (guest[$5] ~ /^(macos|linux|any)$/) ? guest[$5] : "-" }' \
        | /usr/bin/sort -s -k1,1 | /usr/bin/cut -f2-
}

# newimage_read <uuid> [full]  ->  0 with the cache files build.tsv (agentvm_status_build_rows),
# images.tsv and jobs.tsv (as the main window keeps them: for an image whose name is in the way),
# vm.tsv and ipsw.tsv (agentvm_ipsw_rows) read anew; "full" first checks which agent-vm runs and
# reads its recipes into recipes.tsv (newimage_recipe_rows; on opening). What agent-vm says of
# itself, the Linux systems it builds (linux.tsv, agentvm_linux_release_rows) and a new image's
# sizes (sizes.tsv, agentvm_image_size_rows), is read with "full" too, and again by any reading
# while the sizes are not known. An agent-vm that cannot be used is not run. A failed
# `version` or `status` keeps the previous rows and leaves its message in the cache file
# status-error; a failed restore file list keeps the previous list.
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
    if [ "${2:-}" = "full" ] || [ ! -s "$(ui_cache "$1" sizes.tsv)" ]; then
        _json="$(agentvm_version_info)"
        _status=$?
        if [ "$_status" -ne 0 ]; then
            ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
            return "$_status"
        fi
        printf '%s\n' "$_json" | agentvm_linux_release_rows | ui_store "$(ui_cache "$1" linux.tsv)"
        printf '%s\n' "$_json" | agentvm_image_size_rows | ui_store "$(ui_cache "$1" sizes.tsv)"
    fi
    _json="$(agentvm_status)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_status_build_rows | ui_store "$(ui_cache "$1" build.tsv)"
    printf '%s\n' "$_json" | agentvm_status_image_rows | ui_store "$(ui_cache "$1" images.tsv)"
    printf '%s\n' "$_json" | agentvm_job_rows | ui_store "$(ui_cache "$1" jobs.tsv)"
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
    main_rows "$1" build | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name { print; exit }'
}

# newimage_ipsw_row <uuid> <file name>  ->  that restore file's row of ipsw.tsv, or nothing.
newimage_ipsw_row() {
    main_rows "$1" ipsw | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name { print; exit }'
}

# newimage_release_row <uuid> <id>  ->  that Linux system's row of linux.tsv, or nothing.
newimage_release_row() {
    main_rows "$1" linux | /usr/bin/awk -F'\t' -v id="$2" '$1 "" == id { print; exit }'
}

# newimage_size <uuid> <macos|linux> <n>  ->  field n of what agent-vm says of a new image of that
# system (agentvm_image_size_rows: 2 CPUs, 3 memory, 4 disk, 5 the smallest disk, 6 the least a
# copy's disk grows by; the last four in GB), or "-" when it did not say.
newimage_size() {
    local _value="$(main_rows "$1" sizes | /usr/bin/awk -F'\t' -v guest="$2" -v n="$3" '$1 == guest { print $n; exit }')"
    printf '%s\n' "${_value:--}"
}

# -- The start -----------------------------------------------------------------------------------

# newimage_start <uuid>  ->  "image <name>", "linux <id>" or "ipsw <file name>" as kept, or nothing
# when nothing is kept or it has none of the three forms (it comes back from a pasteboard).
newimage_start() {
    local _start="$(ui_get start "$1")"
    newimage_valid_start "$_start" && printf '%s\n' "$_start"
    return 0
}

# newimage_valid_start <start>  ->  0 when it is "image <a name agent-vm accepts>", "linux <what
# can be a Linux system's id>" or "ipsw <a file name ending in .ipsw, with no folder in it>".
newimage_valid_start() {
    case "$1" in
        "image "*)
            agentvm_valid_name "${1#image }"
            return $? ;;
        "linux "*)
            agentvm_valid_linux_release "${1#linux }"
            return $? ;;
        "ipsw "*)
            case "${1#ipsw }" in
                ''|-*|*/*|*"$ui_tab"*) return 1 ;;
                *.ipsw) return 0 ;;
            esac ;;
    esac
    return 1
}

# newimage_start_name <uuid>  ->  the start's name: the image's, the Linux system's id, or the
# restore file's.
newimage_start_name() {
    local _start="$(newimage_start "$1")"
    [ -n "$_start" ] && printf '%s\n' "${_start#* }"
    return 0
}

# newimage_start_kind <uuid>  ->  image, linux, ipsw, or nothing.
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
# row of the table stands for, or nothing. The key is "image <name>", "linux <id>" or "ipsw <file
# name>"; when it did not arrive, the row is found by its first column among what the table was
# filled from (a Linux system's is its name, "Debian 13", which no image can have: an image's
# name has no capital and no space). A key of one of the forms that does not hold a name is
# nothing.
newimage_start_key() {
    case "$2" in
        "image "*|"linux "*|"ipsw "*)
            newimage_valid_start "$2" && printf '%s\n' "$2"
            return 0 ;;
    esac
    [ -n "$3" ] || return 0
    if [ -n "$(newimage_image_row "$1" "$3")" ]; then
        printf 'image %s\n' "$3"
    elif [ -n "$(newimage_ipsw_row "$1" "$3")" ]; then
        printf 'ipsw %s\n' "$3"
    else
        main_rows "$1" linux | /usr/bin/awk -F'\t' -v name="$3" '$2 "" == name { print "linux " $1; exit }'
    fi
    return 0
}

# newimage_base <uuid> <n>  ->  field n of the start image's row (agentvm_status_build_rows); for
# a Linux system or a restore file, the same fields as far as they apply: 4 a restore file's
# macOS, 5 to 7 the sizes agent-vm gives a new image of that system, anything else "-". Nothing
# chosen: "-".
newimage_base() {
    local _name="$(newimage_start_name "$1")"
    local _value=""
    case "$(newimage_start_kind "$1")" in
        image)
            _value="$(newimage_image_row "$1" "$_name" | /usr/bin/cut -f"$2")" ;;
        linux)
            case "$2" in
                5|6|7) _value="$(newimage_size "$1" linux "$(($2 - 3))")" ;;
            esac ;;
        ipsw)
            case "$2" in
                4)     _value="$(newimage_ipsw_row "$1" "$_name" | /usr/bin/cut -f2)" ;;
                5|6|7) _value="$(newimage_size "$1" macos "$(($2 - 3))")" ;;
            esac ;;
    esac
    printf '%s\n' "${_value:--}"
}

# newimage_guest <uuid>  ->  macos or linux: what the new image will run, which is what its start
# runs. A Linux system is Linux; a restore file is macOS, and so is a start that is not listed.
newimage_guest() {
    local _start="$(newimage_start "$1")"
    local _file="$(ui_cache "$1" build.tsv)"
    local _guest=""
    case "$_start" in
        "linux "*)
            _guest="linux" ;;
        "image "*)
            [ -f "$_file" ] && _guest="$(/usr/bin/awk -F'\t' -v name="${_start#image }" '$1 "" == name { print $13; exit }' "$_file")" ;;
    esac
    if [ "$_guest" = "linux" ]; then
        echo linux
    else
        echo macos
    fi
}

# newimage_system <uuid>  ->  the start's system in short ("macOS 27.0.1", "Debian 13"), or "-"
# when it is not known; of a macOS image it is known when its version is, and of a Linux system
# when agent-vm lists it.
newimage_system() {
    local _name="$(newimage_start_name "$1")"
    local _system=""
    case "$(newimage_start_kind "$1")" in
        image)
            _system="$(newimage_image_row "$1" "$_name" | /usr/bin/awk -F'\t' '{ print (($13 == "linux") ? ($14 != "-") : ($4 != "-")) ? $14 : "-" }')" ;;
        linux)
            _system="$(newimage_release_row "$1" "$_name" | /usr/bin/cut -f2)" ;;
        ipsw)
            _system="$(newimage_ipsw_row "$1" "$_name" | /usr/bin/awk -F'\t' '$2 != "" && $2 != "-" { print "macOS " $2 }')" ;;
    esac
    printf '%s\n' "${_system:--}"
}

# newimage_start_text <uuid>  ->  the start in words: "image dev (macOS 27.0.1)", "image deb
# (Debian 13)", "a new Debian 13 system", or "the restore file
# UniversalMac_27.0_26A428_Restore.ipsw (macOS 27.0)".
newimage_start_text() {
    local _name="$(newimage_start_name "$1")"
    local _system="$(newimage_system "$1")"
    local _suffix=""
    [ "$_system" != "-" ] && _suffix=" ($_system)"
    case "$(newimage_start_kind "$1")" in
        image) printf 'image %s%s\n' "$_name" "$_suffix" ;;
        linux)
            if [ "$_system" != "-" ]; then
                printf 'a new %s system\n' "$_system"
            else
                printf 'a new Linux system (%s)\n' "$_name"
            fi ;;
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
        linux)
            [ -n "$(newimage_release_row "$1" "$_name")" ] || printf 'This agent-vm builds no Linux system named %s. Choose another start.\n' "$_name" ;;
        ipsw)
            [ -n "$(newimage_ipsw_row "$1" "$_name")" ] || printf 'The restore file %s is not there any more. Choose another start.\n' "$_name" ;;
        *)
            printf 'Choose what the new image starts from.\n' ;;
    esac
}

# newimage_source_rows <uuid>  ->  the rows of the start table: name, its system in short ("macOS
# 27.0.1", "Debian 13"), what it holds, its state, and (not shown) the key the row stands for.
# Ready images first, then the Linux systems agent-vm builds, then the restore files. An image
# that is not ready is not listed: nothing can be built from it. What an image holds is the names
# of the recipes it keeps, else its recipe's description (as newimage_recipe_text shows one),
# else macOS or Linux alone, with the Command Line Tools or the compiler when it has them. A
# Linux system is listed under agent-vm's name for it: no file of it is there to name, and
# whether its cloud image was downloaded before is not something agent-vm says.
newimage_source_rows() {
    main_rows "$1" build | /usr/bin/awk -F'\t' '
        $2 == "ready" {
            linux = ($13 == "linux")
            holds = ($8 != "-") ? $8 : (($9 != "-") ? $9 : (linux ? "Linux" : "macOS"))
            if ($8 != "-") gsub(/,/, ", ", holds)
            else sub(/ \([^()]*\)$/, "", holds)
            if ($10 != "-" && $8 == "-" && $9 == "-") holds = linux ? "Linux with the compiler and make" : "macOS and the Command Line Tools"
            state = "ready"
            if ($11 ~ /full-disk-access/) state = "no Full Disk Access"
            if ($3 == "true") state = "being changed"
            # The system in short: for a macOS image only when its version is known.
            runs = (linux ? ($14 != "-") : ($4 != "-")) ? $14 : "-"
            printf "%s\t%s\t%s\t%s\timage %s\n", $1, runs, holds, state, $1
        }'
    main_rows "$1" linux | /usr/bin/awk -F'\t' '
        { printf "%s\tLinux\ta new system, from its cloud image\tdownloaded when needed\tlinux %s\n", $2, $1 }'
    main_rows "$1" ipsw | /usr/bin/awk -F'\t' '
        {
            size = ($4 ~ /^[0-9]+$/) ? sprintf("%.1f GB", $4 / 1000000000) : "-"
            runs = ($2 != "" && $2 != "-") ? "macOS " $2 : "-"
            printf "%s\t%s\ta restore file: macOS is installed from it\t%s\tipsw %s\n", $1, runs, size, $1
        }'
}

# -- The tools -----------------------------------------------------------------------------------

# newimage_recipes <uuid> <own|all|listed>  ->  recipe rows read from the window's cache files by
# lib.agentvm.newimage.recipes.awk, which says what each of the three is: the recipes the user
# added, every recipe the window knows, or the ones the start as it is now is offered. One awk
# run, since the Tools step asks for its list many times in one click.
newimage_recipes() {
    local _uuid="$1"
    local _want="$2"
    local _start=""
    [ "$_want" = "listed" ] && _start="$(newimage_start "$_uuid")"
    local _role _file
    set --
    for _role in build shipped own; do
        case "$_want:$_role" in
            own:build|own:shipped|all:build) continue ;;
        esac
        case "$_role" in
            shipped) _file="$(ui_cache "$_uuid" recipes.tsv)" ;;
            *)       _file="$(ui_cache "$_uuid" "$_role.tsv")" ;;
        esac
        [ -f "$_file" ] && set -- "$@" "role=$_role" "$_file"
    done
    [ "$#" -gt 0 ] || return 0
    NEW_START="$_start" /usr/bin/awk -F'\t' -v want="$_want" -v slots="$NEW_RECIPE_SLOTS" -f "$NEW_RECIPES_AWK" "$@"
}

# newimage_own_rows <uuid>  ->  the recipes the user added, a row each (as newimage_recipe_rows),
# as far as a row has its six fields, a full path, a guest and a name that can be one (the rows
# come back from a file).
newimage_own_rows() {
    newimage_recipes "$1" own
}

# newimage_recipe_all <uuid>  ->  the rows of every recipe the window knows, whichever system it
# is for: the ones that come with agent-vm, in the order they are applied, then the ones the user
# added, in the order added. A name is there once.
newimage_recipe_all() {
    newimage_recipes "$1" all
}

# newimage_recipe_list <uuid>  ->  the rows of the recipes the Tools step lists, each in a slot:
# the ones of newimage_recipe_all that the start as it is now is offered, as far as the window
# has slots.
newimage_recipe_list() {
    newimage_recipes "$1" listed
}

# newimage_recipe_for <guest>  <  recipe rows  ->  the ones a start of that system is offered, as
# far as the window has slots: the rule newimage_recipe_list applies, for a system that is given.
newimage_recipe_for() {
    /usr/bin/awk -F'\t' -v want=listed -v guest="$1" -v slots="$NEW_RECIPE_SLOTS" -v role=shipped -f "$NEW_RECIPES_AWK"
}

# newimage_offered <a recipe's guest> <a start's guest>  ->  0 when a start of that system is
# offered a recipe for that guest: every recipe but one for the other system (the same rule, for
# one recipe).
newimage_offered() {
    case "$2:$1" in
        linux:macos|macos:linux) return 1 ;;
    esac
    return 0
}

# newimage_system_word <guest>  ->  "macOS" or "Linux".
newimage_system_word() {
    case "$1" in
        linux) echo "Linux" ;;
        *)     echo "macOS" ;;
    esac
}

# newimage_images_words <guest>  ->  "macOS images" or "Linux images".
newimage_images_words() {
    case "$1" in
        linux) echo "Linux images" ;;
        *)     echo "macOS images" ;;
    esac
}

# newimage_start_words <guest>  ->  the starts of that system, as a sentence names them.
newimage_start_words() {
    case "$1" in
        linux) echo "a Linux image or a new Linux system" ;;
        *)     echo "a macOS image or a restore file" ;;
    esac
}

# newimage_recipe_names <uuid>  ->  the names of those recipes, one per line.
newimage_recipe_names() {
    newimage_recipe_list "$1" | /usr/bin/cut -f1
}

# newimage_recipe_field <uuid> <name> <n>  ->  field n of that recipe's row (agentvm_recipe_rows).
# A name is compared as text ($1 ""): awk compares two things that look like numbers as numbers,
# and "1" and "1.0" are two names.
newimage_recipe_field() {
    newimage_recipe_list "$1" | /usr/bin/awk -F'\t' -v name="$2" -v n="$3" '$1 "" == name { print $n; exit }'
}

# newimage_is_own <uuid> <name>  ->  0 when that recipe is one the user added.
newimage_is_own() {
    [ -n "$(newimage_own_rows "$1" | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name { print "yes"; exit }')" ]
}

# newimage_add_own <uuid> <path>  ->  adds that recipe file to the recipes the window knows when
# agent-vm accepts it as a recipe (`recipe check`), and prints the line for the note: that it is
# in the list, with what agent-vm warns about in it, or why it cannot be added. A recipe for the
# other system than the start's is kept too, and the note says when it is listed: the start can
# still change. Adding is not ticking: the checkboxes are the user's.
newimage_add_own() {
    case "$2" in
        /*) ;;
        *)  printf 'Choose a recipe file.\n'
            return 0 ;;
    esac
    if [ ! -f "$2" ]; then
        printf '%s is not a file on this Mac.\n' "$(agentvm_display_path "$2")"
        return 0
    fi
    local _answer
    _answer="$(agentvm_recipe_check "$2")"
    local _status=$?
    local _checked="$(printf '%s\n' "$_answer" | agentvm_recipe_check_rows | /usr/bin/head -1)"
    if [ "$_status" -gt 1 ] || [ -z "$_checked" ]; then
        printf 'agent-vm could not check %s: %s\n' "$(agentvm_display_path "$2")" "$(ui_one_line "$(agentvm_last_error "$_status")")"
        return 0
    fi
    local _error="$(printf '%s\n' "$_checked" | /usr/bin/cut -f6)"
    # Status 1 is a refusal wherever agent-vm wrote its reason: never taken for an accepted file.
    if [ "$_error" = "-" ] && [ "$_status" -ne 0 ]; then
        _error="$(printf '%s\n' "$_answer" | agentvm_recipe_check_error)"
        [ -n "$_error" ] || _error="it gave no reason"
    fi
    if [ "$_error" != "-" ]; then
        # The system's reasons end in a full stop of their own.
        printf 'agent-vm does not accept %s as a recipe: %s.\n' "$(agentvm_display_path "$2")" "${_error%.}"
        return 0
    fi
    local _row="$(printf '%s\n' "$_checked" | /usr/bin/cut -f1-5)"
    # The row holds the path as text on one line. A path that does not come back as it went in
    # (a tab or a line break in it) would be looked up later as another path.
    if [ "${_row##*"$ui_tab"}" != "$2" ]; then
        printf 'The path of that file has a tab or a line break in it. Rename the file or its folder to add this recipe.\n'
        return 0
    fi
    # The guest agent-vm read in the file says which starts the recipe is listed for.
    local _guest="$(printf '%s\n' "$_checked" | /usr/bin/cut -f9)"
    case "$_guest" in
        macos|linux|any) ;;
        *) _guest="-" ;;
    esac
    local _now="$(newimage_guest "$1")"
    # A recipe is looked for among all the window knows, the other system's too: one that is
    # not listed now would be in the way when the start changes.
    local _all="$(newimage_recipe_all "$1")"
    # The path goes to awk in the environment: -v would read a backslash in it as an escape.
    local _there="$(printf '%s\n' "$_all" | NEW_RECIPE_PATH="$2" /usr/bin/awk -F'\t' '$5 == ENVIRON["NEW_RECIPE_PATH"] { print $1 "\t" $6; exit }')"
    if [ -n "$_there" ]; then
        if newimage_offered "${_there#*"$ui_tab"}" "$_now"; then
            printf 'That is the recipe %s, which is in the list already.\n' "${_there%%"$ui_tab"*}"
        else
            printf 'That is the recipe %s, which is for %s: it is listed when the start is %s.\n' "${_there%%"$ui_tab"*}" \
                "$(newimage_images_words "${_there#*"$ui_tab"}")" "$(newimage_start_words "${_there#*"$ui_tab"}")"
        fi
        return 0
    fi
    local _name="${_row%%"$ui_tab"*}"
    # The name is written into the window as a text, and the window tool reads a text that
    # begins like one of its instructions as that instruction.
    case "$_name" in
        omc_*)
            printf 'A recipe cannot be listed under the name %s. Rename the file or its folder to add this recipe.\n' "$_name"
            return 0 ;;
    esac
    _there="$(printf '%s\n' "$_all" | /usr/bin/awk -F'\t' -v name="$_name" '$1 "" == name { print "=" $6; exit }')"
    if [ -n "$_there" ]; then
        if newimage_offered "${_there#=}" "$_now"; then
            printf 'A recipe named %s is in the list already. A recipe is named by its folder, or by its file when that is not recipe.json: rename one to add this recipe.\n' "$_name"
        else
            printf 'A recipe named %s is there already, for %s. A recipe is named by its folder, or by its file when that is not recipe.json: rename one to add this recipe.\n' \
                "$_name" "$(newimage_images_words "${_there#=}")"
        fi
        return 0
    fi
    # Room is needed in every list the recipe joins: the one shown now, and the other system's
    # when the recipe is for that one, or for both.
    local _other="linux"
    [ "$_now" = "linux" ] && _other="macos"
    local _kind _count
    for _kind in "$_now" "$_other"; do
        newimage_offered "$_guest" "$_kind" || continue
        _count="$(printf '%s\n' "$_all" | newimage_recipe_for "$_kind" | /usr/bin/awk 'NF { n++ } END { print n + 0 }')"
        [ "$_count" -ge "$NEW_RECIPE_SLOTS" ] || continue
        if [ "$_kind" = "$_now" ]; then
            printf 'This window lists %s recipes. With more, build the image with agent-vm image create in Terminal.\n' "$NEW_RECIPE_SLOTS"
        else
            printf 'This window lists %s recipes for %s already. With more, build the image with agent-vm image create in Terminal.\n' \
                "$NEW_RECIPE_SLOTS" "$(newimage_images_words "$_kind")"
        fi
        return 0
    done
    {
        newimage_own_rows "$1"
        printf '%s\t%s\n' "$_row" "$_guest"
    } | ui_store "$(ui_cache "$1" own.tsv)"
    # Warnings are agent-vm's guesses from the commands' text: they are shown, and stop nothing.
    local _warnings="$(printf '%s\n' "$_checked" | /usr/bin/cut -f7)"
    local _warned=""
    case "$_warnings" in
        0|"") ;;
        1)  _warned=" agent-vm warns about it: $(printf '%s\n' "$_checked" | /usr/bin/cut -f8)." ;;
        *)  _warned=" agent-vm warns about it: $(printf '%s\n' "$_checked" | /usr/bin/cut -f8), and $((_warnings - 1)) more (agent-vm recipe check lists them)." ;;
    esac
    if newimage_offered "$_guest" "$_now"; then
        printf '%s is in the list now. Tick it to install it.%s\n' "$_name" "$_warned"
    else
        printf '%s is a recipe for %s, and the new image starts from %s. It is kept, and listed when the start is %s.%s\n' \
            "$_name" "$(newimage_images_words "$_guest")" "$(newimage_start_text "$1")" "$(newimage_start_words "$_guest")" "$_warned"
    fi
}

# newimage_recipes_blocker <uuid>  ->  why the recipes ticked cannot be built with now, or
# nothing: a file is gone (a file of the user's own can move at any time), or agent-vm, asked
# about them together in the order a build would run them (`recipe check`), refuses one, or
# refuses them together.
newimage_recipes_blocker() {
    local _uuid="$1"
    local _name _path
    set --
    for _name in $(newimage_ticks "$_uuid"); do
        _path="$(newimage_recipe_field "$_uuid" "$_name" 5)"
        if [ ! -f "$_path" ]; then
            printf 'The recipe file %s is not there any more. Untick %s.\n' "$(agentvm_display_path "$_path")" "$_name"
            return 0
        fi
        set -- "$@" "$_path"
    done
    [ "$#" -gt 0 ] || return 0
    local _answer
    _answer="$(agentvm_recipe_check "$@")"
    local _status=$?
    [ "$_status" -ne 0 ] || return 0
    local _rows="$(printf '%s\n' "$_answer" | agentvm_recipe_check_rows)"
    if [ "$_status" -gt 1 ] || [ -z "$_rows" ]; then
        printf 'agent-vm could not check the recipes: %s\n' "$(ui_one_line "$(agentvm_last_error "$_status")")"
        return 0
    fi
    # The one agent-vm refuses, under the name the window lists it by (its path finds it).
    local _refused="$(printf '%s\n' "$_rows" | /usr/bin/awk -F'\t' '$6 != "-" { print $5 "\t" $6; exit }')"
    if [ -n "$_refused" ]; then
        _path="${_refused%%"$ui_tab"*}"
        _name="$(newimage_recipe_list "$_uuid" | NEW_RECIPE_PATH="$_path" /usr/bin/awk -F'\t' '$5 == ENVIRON["NEW_RECIPE_PATH"] { print $1; exit }')"
        _refused="${_refused#*"$ui_tab"}"
        printf 'agent-vm does not accept the recipe file %s now: %s. Untick %s.\n' "$(agentvm_display_path "$_path")" "${_refused%.}" "${_name:-it}"
        return 0
    fi
    local _together="$(printf '%s\n' "$_answer" | agentvm_recipe_check_error)"
    _together="${_together:-it gave no reason}"
    printf 'agent-vm does not accept these recipes together: %s.\n' "${_together%.}"
}

# newimage_recipe_text <description>  ->  agent-vm's description of a recipe without its closing
# parenthesis, which says where to put the recipe on a command line ("needs Homebrew: put
# Recipes/homebrew before it"): the window orders the recipes itself, and says what is missing.
newimage_recipe_text() {
    printf '%s\n' "$1" | /usr/bin/sed 's/ ([^()]*)$//'
}

# newimage_recipe_need <name> <the start's guest>  ->  the recipe that one of agent-vm's own
# recipes needs before it in an image of that system, or nothing. agent-vm's recipes say this in
# words only (their descriptions, and a first step that fails at once); this table is those
# words. The agents need Node in either system, which is another recipe in each.
newimage_recipe_need() {
    case "$2:$1" in
        macos:node|macos:python)           echo "homebrew" ;;
        macos:agent-clis|macos:acp-agents) echo "node" ;;
        linux:agent-clis|linux:acp-agents) echo "linux-node" ;;
        macos:xcode-platforms)             echo "xcode" ;;
    esac
}

# newimage_ticks <uuid>  ->  the recipes ticked, one per line, in the order they are applied: what
# is kept, as far as it names a recipe the window lists.
newimage_ticks() {
    local _kept=" $(ui_get ticks "$1") "
    newimage_recipe_names "$1" | /usr/bin/awk -v kept="$_kept" 'index(kept, " " $1 " ") > 0'
}

# newimage_slots <uuid>  ->  the recipes the checkboxes were last laid out for, in the slots'
# order, on one line; nothing when what is kept is not recipe names (it comes back from a
# pasteboard, and is split into words).
newimage_slots() {
    local _slots="$(ui_get slots "$1")"
    case "$_slots" in
        *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._\ -]*) return 0 ;;
    esac
    printf '%s\n' "$_slots"
}

# newimage_take_ticks <uuid>  ->  keeps the checkboxes as the handler that runs saw them (a
# checkbox's value is "true" or "false"; anything else is not ticked). A checkbox stands for the
# recipe its slot shows, which is the one it was last laid out for: the list as it is now can be
# another when the start left agent-vm's list while the step was shown, and a tick read by it
# would pass to the recipe that has the slot's place there.
newimage_take_ticks() {
    local _ticks="" _name _value _slot=0
    for _name in $(newimage_slots "$1"); do
        _slot=$((_slot + 1))
        eval "_value=\"\${OMC_ACTIONUI_VIEW_$((NEW_RECIPE_TICK_BASE + _slot))_VALUE:-}\""
        [ "$_value" = "true" ] && _ticks="${_ticks:+$_ticks }$_name"
    done
    ui_set ticks "$1" "$_ticks"
}

# newimage_held <uuid>  ->  the recipes the start image keeps, one per line (none for a Linux
# system or a restore file).
newimage_held() {
    local _names="$(newimage_base "$1" 8)"
    [ "$_names" = "-" ] && return 0
    printf '%s\n' "$_names" | /usr/bin/tr ',' '\n'
}

# newimage_holds_nothing <uuid>  ->  0 when the start is known to hold no recipe's tools: a Linux
# system, a restore file, or an image with no recipe at all. An image built before agent-vm
# listed the recipes kept has a description and no list, and what it holds is then not known here.
newimage_holds_nothing() {
    case "$(newimage_start_kind "$1")" in
        linux|ipsw) return 0 ;;
        image) [ "$(newimage_base "$1" 8)" = "-" ] && [ "$(newimage_base "$1" 9)" = "-" ] ;;
        *)     return 1 ;;
    esac
}

# newimage_missing <uuid>  ->  one line per ticked recipe that needs a recipe which is neither
# ticked nor kept by the start image: the recipe, a tab, what it needs.
newimage_missing() {
    local _ticks="$(newimage_ticks "$1")"
    local _held="$(newimage_held "$1")"
    local _guest="$(newimage_guest "$1")"
    local _name _need
    for _name in $_ticks; do
        _need="$(newimage_recipe_need "$_name" "$_guest")"
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
    local _need="$(newimage_missing "$1" | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name { print $2; exit }')"
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
        _kept="$(/usr/bin/awk -F'\t' -v kind="$2" -v name="$3" '$1 == kind && $2 "" == name { print "=" $3; exit }' "$_file")"
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
        /usr/bin/awk -F'\t' -v kind="$2" -v name="$3" '!($1 == kind && $2 "" == name)' "$_file"
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

# newimage_taken_name <uuid> <name>  ->  the listed image that has that name, or one that differs
# from it in case only (agent-vm refuses such a name: main_row_any_case), or nothing.
newimage_taken_name() {
    main_row_any_case "$1" build "$2" | /usr/bin/cut -f1
}

# newimage_name_taken <uuid> <name>  ->  0 when an image of that name is listed, in any case.
newimage_name_taken() {
    [ -n "$(newimage_taken_name "$1" "$2")" ]
}

# newimage_deletable <uuid> <name>  ->  0 when the image of that name is one this window offers to
# delete: it is not ready (its build failed, or did not finish), no job holds it, and no other
# command is changing it. A ready image is deleted in the main window, which says what was made
# from it. agent-vm refuses to delete an image a command outside the app is still building.
newimage_deletable() {
    local _row="$(newimage_image_row "$1" "$2")"
    [ -n "$_row" ] || return 1
    [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" != "ready" ] || return 1
    [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)" != "true" ] || return 1
    [ -z "$(main_job "$1" image "$2")" ]
}

# newimage_taken_text <uuid> <name>  ->  what stands in the way when an image has that name, and
# what to do about it. Nothing when no image has the name. An image that is not ready "appears"
# so: why it is there is not known here (a build that failed, one that was interrupted, or
# something done outside the app), and the question Delete... asks says what agent-vm reports.
# The image named is the one listed, which may differ from the name given in case only.
newimage_taken_text() {
    local _taken="$(newimage_taken_name "$1" "$2")"
    [ -n "$_taken" ] || return 0
    local _case=""
    [ "$_taken" = "$2" ] || _case=" Names that differ in case only cannot both be used."
    local _state="$(newimage_image_row "$1" "$_taken" | /usr/bin/cut -f2)"
    if [ "$_state" = "ready" ]; then
        printf 'An image named %s is there already. Give the new image another name.%s\n' "$_taken" "$_case"
    elif ! newimage_deletable "$1" "$_taken"; then
        printf 'An image named %s is there already, and is being built or changed now. Give the new image another name.%s\n' "$_taken" "$_case"
    else
        printf 'An image named %s is there already, and appears not ready. Delete it to use the name, or give the new image another name.%s\n' "$_taken" "$_case"
    fi
}

# newimage_suggested_name <uuid>  ->  a free name for the new image: for a copy, the start's name
# and the tool ticked ("dev-node"; its case kept, and "-tools" when that cannot be a name, as a
# recipe of the user's own may be called anything; without the "linux-" that agent-vm's recipes
# for Linux images begin with, so "deb-node"), "-tools" for several, "-copy" for none; for a
# build from a Linux system its distribution ("debian"; "linux" when that cannot be a name);
# "dev" for a build from a restore file; with a number when that is taken.
newimage_suggested_name() {
    local _base="dev"
    local _ticks _count
    case "$(newimage_start_kind "$1")" in
        image)
            _ticks="$(newimage_ticks "$1")"
            _count="$(printf '%s\n' "$_ticks" | /usr/bin/awk 'NF { n++ } END { print n + 0 }')"
            case "$_count" in
                0) _base="$(newimage_start_name "$1")-copy" ;;
                1) _base="$(newimage_start_name "$1")-${_ticks#linux-}"
                   agentvm_valid_name "$_base" || _base="$(newimage_start_name "$1")-tools" ;;
                *) _base="$(newimage_start_name "$1")-tools" ;;
            esac ;;
        linux)
            _base="$(newimage_release_row "$1" "$(newimage_start_name "$1")" | /usr/bin/cut -f3)"
            agentvm_valid_name "$_base" || _base="linux" ;;
    esac
    local _name="$_base"
    local _n=2
    while newimage_name_taken "$1" "$_name" && [ "$_n" -lt 100 ]; do
        _name="$_base$_n"
        _n=$((_n + 1))
    done
    printf '%s\n' "$_name"
}

# newimage_disk_growth <uuid>  ->  the least the disk of a copy of the start may grow by, in GB,
# as agent-vm says it for the start's system; "-" when it did not say.
newimage_disk_growth() {
    newimage_size "$1" "$(newimage_guest "$1")" 6
}

# newimage_suggested_disk <uuid>  ->  the disk the fields start with, in GB: the start's (for an
# image whose record names none, what agent-vm gives a new image of its system), or
# NEW_XCODE_DISK when xcode is ticked and the start's disk can grow to it. Nothing when neither
# is known.
newimage_suggested_disk() {
    local _disk="$(newimage_base "$1" 7)"
    newimage_number "$_disk" || _disk="$(newimage_size "$1" "$(newimage_guest "$1")" 4)"
    newimage_number "$_disk" || return 0
    local _growth="$(newimage_disk_growth "$1")"
    newimage_number "$_growth" || _growth=0
    if newimage_listed xcode "$(newimage_ticks "$1")" && [ $((_disk + _growth)) -le "$NEW_XCODE_DISK" ]; then
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
    wizard_number "$1"
}

# newimage_sizes_blocker <uuid>  ->  why the name or a size cannot be used, or nothing.
newimage_sizes_blocker() {
    local _name="$(ui_get name "$1")"
    if [ -z "$_name" ]; then
        printf 'Give the new image a name.\n'
        return 0
    fi
    if ! agentvm_valid_name "$_name"; then
        printf '"%s" cannot be a name: letters, digits, ".", "_" and "-", starting with a letter or a digit, at most 63 characters.\n' "$_name"
        return 0
    fi
    if newimage_name_taken "$1" "$_name"; then
        newimage_taken_text "$1" "$_name"
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
    # A system installed anew has a smallest disk; a copy's disk follows its image's. A number
    # agent-vm did not give is left to agent-vm to judge: any disk for a new system, and any
    # growth for a copy.
    local _least
    if [ "$(newimage_start_kind "$1")" != "image" ]; then
        _least="$(newimage_size "$1" "$(newimage_guest "$1")" 5)"
        if newimage_number "$_least" && [ "$_disk" -lt "$_least" ]; then
            printf 'Disk: %s GB or more for a new %s image.\n' "$_least" "$(newimage_system_word "$(newimage_guest "$1")")"
        fi
        return 0
    fi
    local _base="$(newimage_base "$1" 7)"
    newimage_number "$_base" || return 0
    local _growth="$(newimage_disk_growth "$1")"
    newimage_number "$_growth" || _growth=1
    if [ "$_disk" -ne "$_base" ] && [ "$_disk" -lt $((_base + _growth)) ]; then
        printf 'The disk can stay at %s GB, as in image %s, or grow to %s GB or more. It cannot shrink.\n' \
            "$_base" "$(newimage_start_name "$1")" "$((_base + _growth))"
    fi
    return 0
}

# newimage_size_text <uuid>  ->  the line under the size fields.
newimage_size_text() {
    local _growth="$(newimage_disk_growth "$1")"
    local _least="$(newimage_size "$1" "$(newimage_guest "$1")" 5)"
    if [ "$(newimage_start_kind "$1")" = "image" ]; then
        printf "These start as image %s has them. The disk is a sparse file, which takes only what is written to it" "$(newimage_start_name "$1")"
        if newimage_number "$_growth"; then
            printf "; the disk of a copy stays as it is or grows by at least %s GB.\n" "$_growth"
        else
            printf "; the disk of a copy stays as it is or grows.\n"
        fi
    else
        printf "These start as the defaults of agent-vm for a %s image. The disk is a sparse file, which takes only what is written to it" "$(newimage_system_word "$(newimage_guest "$1")")"
        if newimage_number "$_least"; then
            printf "; it cannot be smaller than %s GB.\n" "$_least"
        else
            printf ".\n"
        fi
    fi
    newimage_listed xcode "$(newimage_ticks "$1")" && printf 'Xcode takes about 4 GB and each simulator runtime about 8 GB: %s GB or more is a good disk for it.\n' "$NEW_XCODE_DISK"
    return 0
}

# -- The build -----------------------------------------------------------------------------------

# newimage_args <uuid>  ->  the arguments of `image create`, one per line, as
# agentvm_job_image_create takes them: the name, the start, the recipes ticked in their order,
# every input file, the parameters that are not at their defaults, and the sizes that are not the
# start's; for a build from a Linux system or a restore file all three sizes, so that what Check
# says is what is built whatever agent-vm's defaults are. Nothing when no start is known, or when
# the name or a size kept is not a name or a number: each is one argument, and comes back from a
# pasteboard.
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
        linux)
            printf '%s\n--linux\n%s\n' "$(ui_get name "$1")" "$_name" ;;
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
# the new image is a macOS one and both places for a macOS virtual machine are taken, since a
# build runs the image in one. A Linux image needs none of them.
newimage_blocker() {
    local _why="$(newimage_unreadable "$1")"
    [ -n "$_why" ] || _why="$(newimage_start_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_tools_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_recipes_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_options_blocker "$1")"
    [ -n "$_why" ] || _why="$(newimage_sizes_blocker "$1")"
    if [ -n "$_why" ]; then
        printf '%s\n' "$_why"
        return 0
    fi
    [ "$(newimage_guest "$1")" = "linux" ] && return 0
    main_macos_vms "$1" | /usr/bin/awk -F'\t' '$1 >= $2 {
        printf "%s of %s macOS virtual machines are running, and the build of a macOS image needs one. Stop a macOS box first.\n", $1, $2 }'
}

# newimage_summary_text <uuid>  ->  what Build makes, in words.
newimage_summary_text() {
    local _name="$(ui_get name "$1")"
    local _ticks="$(newimage_ticks "$1")"
    case "$(newimage_start_kind "$1")" in
        image) printf 'Image %s, built as a copy of %s.\n' "$_name" "$(newimage_start_text "$1")" ;;
        linux) printf 'Image %s, %s, built from its cloud image, which agent-vm downloads and checks.\n' "$_name" "$(newimage_start_text "$1")" ;;
        *)     printf 'Image %s, with macOS installed from %s.\n' "$_name" "$(newimage_start_text "$1")" ;;
    esac
    if [ -n "$_ticks" ]; then
        printf 'Tools, installed in this order: %s.\n' "$(ui_lines_text "$_ticks")"
    else
        printf 'No tools are added.\n'
    fi
    printf '%s CPUs, %s GB of memory, a disk of %s GB.\n' "$(ui_get cpus "$1")" "$(ui_get memory "$1")" "$(ui_get disk "$1")"
}

# newimage_advice_text <uuid>  ->  what to know before the build: a need that may be missing, what
# Full Disk Access will be in the new image when it is a macOS one (a Linux image has no such
# permission), and that the window can go.
newimage_advice_text() {
    newimage_tools_warning "$1"
    local _name="$(newimage_start_name "$1")"
    case "$(newimage_guest "$1"):$(newimage_start_kind "$1"):$(newimage_base "$1" 11)" in
        linux:*) ;;
        *:ipsw:*)
            printf 'An image built from a restore file has no Full Disk Access yet: Set Up... in its pane grants it, once, after the build.\n' ;;
        *full-disk-access*)
            printf 'Image %s has no Full Disk Access, so the new image will have none either. Set Up... in the pane of either grants it.\n' "$_name" ;;
        *)  printf 'The new image keeps the Full Disk Access of image %s.\n' "$_name" ;;
    esac
    printf 'The build runs as a job. Its progress window opens, and the build goes on when the windows, or the app, are closed.\n'
}

# -- Painting ------------------------------------------------------------------------------------

# newimage_paint_sources <uuid>  ->  the start table from the cache, with the start kept selected.
# It is called as the window opens, when the only start kept is an image handed over, whose row
# is found by its name in the first column.
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

# newimage_paint_recipes <uuid>  ->  the recipe slots: one shown per recipe listed, with its name
# and description, and for one the user added, where its file is; a slot that has no recipe any
# more is hidden. Add a Recipe File... is on while a slot is free.
#
# The checkboxes are the user's, and one whose slot keeps its recipe is not set. When the start
# became one of the other system, a slot holds another recipe than its checkbox was last shown
# beside: that checkbox is set to whether its new recipe is ticked, so a tick stays with its
# recipe and never passes to the one that took its slot. A recipe that is not listed any more
# loses its tick. A slot that showed no recipe is not ticked, so one that gets a recipe the
# user never ticked (a recipe file just added) is left alone.
newimage_paint_recipes() {
    "$dialog" "$1" "$NEW_TOOLS_TEXT_ID" "$(newimage_tools_text "$1")"
    # The recipes listed now, and the ones the slots last showed: each list ends in a space, so
    # that a slot's name is taken off its front, and is nothing when the list has run out.
    local _now="$(newimage_recipe_names "$1" | /usr/bin/tr '\n' ' ')"
    local _before="$(newimage_slots "$1") "
    local _laid="${_now% }"
    local _ticks="$(newimage_ticks "$1")"
    local _slot=0 _free=0 _name _was _text _on
    while [ "$_slot" -lt "$NEW_RECIPE_SLOTS" ]; do
        _slot=$((_slot + 1))
        _name="${_now%% *}"
        _now="${_now#* }"
        _was="${_before%% *}"
        _before="${_before#* }"
        if [ "$_was" != "$_name" ]; then
            _on="false"
            [ -n "$_name" ] && newimage_listed "$_name" "$_ticks" && _on="true"
            # A slot that showed no recipe is not ticked: it is set only to tick it.
            if [ -n "$_was" ] || [ "$_on" = "true" ]; then
                "$dialog" "$1" "$((NEW_RECIPE_TICK_BASE + _slot))" "$_on"
            fi
        fi
        if [ -z "$_name" ]; then
            _free=$((_free + 1))
            [ -n "$_was" ] && ui_show "$1" "$((NEW_RECIPE_ROW_BASE + _slot))" 0
            continue
        fi
        _text="$(newimage_recipe_text "$(newimage_recipe_field "$1" "$_name" 2)")"
        if newimage_is_own "$1" "$_name"; then
            [ "$_text" = "-" ] && _text="Your recipe"
            _text="$_text, from $(agentvm_display_path "$(newimage_recipe_field "$1" "$_name" 5)")"
        fi
        "$dialog" "$1" "$((NEW_RECIPE_NAME_BASE + _slot))" "$_name"
        "$dialog" "$1" "$((NEW_RECIPE_TEXT_BASE + _slot))" "$_text"
        ui_show "$1" "$((NEW_RECIPE_ROW_BASE + _slot))" 1
    done
    ui_set slots "$1" "$_laid"
    if [ "$_free" -gt 0 ]; then
        ui_enable "$1" "$NEW_ADD_RECIPE_ID" 1
    else
        ui_enable "$1" "$NEW_ADD_RECIPE_ID" 0
    fi
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

# newimage_offer_delete <uuid> <name or nothing>  ->  Delete... shown beside the note for that
# image, which is kept as the one the button deletes; with no name the button goes.
newimage_offer_delete() {
    ui_set taken "$1" "$2"
    if [ -n "$2" ]; then
        ui_show "$1" "$NEW_DELETE_ID" 1
    else
        ui_show "$1" "$NEW_DELETE_ID" 0
    fi
}

# newimage_paint_note <uuid> <note>  ->  the note line of the last two steps, with Delete...
# beside it when the note is that the name kept belongs to an image this window offers to delete.
newimage_paint_note() {
    "$dialog" "$1" "$NEW_NOTE_ID" "$2"
    local _name="$(ui_get name "$1")"
    local _offer=""
    # The image offered is the one listed, which may differ from the name kept in case only.
    local _taken
    agentvm_valid_name "$_name" && _taken="$(newimage_taken_name "$1" "$_name")"
    if [ -n "$2" ] && [ -n "$_taken" ] && newimage_deletable "$1" "$_taken" \
        && [ "$2" = "$(newimage_taken_text "$1" "$_name")" ]; then
        _offer="$_taken"
    fi
    [ -z "$_offer" ] && [ -z "$(ui_get taken "$1")" ] && return 0
    newimage_offer_delete "$1" "$_offer"
}

# newimage_repaint_note <uuid> [status of the reading before it]  ->  the note of the last two
# steps again, from what is kept and what agent-vm last said, after an image whose name was in
# the way was asked about or deleted: on Name and size the note alone (no field is touched), on
# Check the whole step. After a reading that failed the rows are old ones, so the note says why
# agent-vm could not be read, and the offer goes with the note it stood beside.
newimage_repaint_note() {
    case "$(newimage_step "$1")" in
        4)  if [ "${2:-0}" -ne 0 ]; then
                newimage_paint_note "$1" "$(newimage_unreadable "$1")"
            else
                newimage_paint_note "$1" "$(newimage_sizes_blocker "$1")"
            fi ;;
        5)  newimage_paint_check "$1" ;;
    esac
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
    newimage_paint_note "$1" "$_blocker"
    if [ -z "$_blocker" ]; then
        ui_enable "$1" "$NEW_BUILD_ID" 1
    else
        ui_enable "$1" "$NEW_BUILD_ID" 0
    fi
}

# newimage_paint_frame <uuid> [note]  ->  what every step has: the header, the rail's marks, the
# panel of the step shown, Back, Continue or Build, and the note line. Delete... goes with
# the note it stood beside.
newimage_paint_frame() {
    local _step="$(newimage_step "$1")"
    wizard_paint_frame "$1" "$NEW_BASE" "$NEW_STEPS" "$_step" "$(newimage_step_title "$_step")" "${2:-}"
    [ -z "$(ui_get taken "$1")" ] || newimage_offer_delete "$1" ""
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
