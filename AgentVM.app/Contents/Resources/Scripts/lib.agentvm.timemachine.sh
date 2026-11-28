#!/bin/sh
# lib.agentvm.timemachine.sh
#
# Settings' Time Machine group: which of the store's large folders (Boxes, Images, Cache) are left
# out of Time Machine backups, a checkbox each, with a button that shows the folder in Finder. A
# running box's Disk.img changes all the time, and Time Machine copies it whole at every backup;
# images and downloaded systems are large and can be made again. Sessions, Logs and connect.json
# are not offered: they are small, and Sessions holds the undo history of agents' changes.
#
# HOW. `tmutil addexclusion <folder>`, with no -p, sets the folder's own exclusion attribute
# (com.apple.metadata:com_apple_backup_excludeItem). It needs no administrator password and no
# Full Disk Access. Time Machine's settings window does not list such exclusions (it lists only
# path exclusions, which need both), so the group says where the setting is seen.
#
# THE CHOICE is kept by the app, per store and folder, in time-machine-left-out in its support
# folder: a line each, the store's path, a tab, the folder's name. The attribute belongs to the
# folder, and agent-vm may delete a folder and make it again, or make it for the first time (Boxes
# with the first box), so on opening and activation (main_refresh full) the app sets it again on
# every chosen folder that lacks it. A folder found left out that is not chosen (left out by hand)
# is taken as chosen, so its checkbox shows what is so and it stays left out when made again.
# Unchecking backs the folder up again.
#
# No sizes: boxes and images share their disk blocks (APFS clones), so a folder's size is not
# what leaving it out saves, and measuring them would need work in the background.
#
# Seam for the tests: AGENTVM_APP_TMUTIL (Tests/helpers/fake_tmutil.sh).
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_TIMEMACHINE_LIB:-}" ] && return 0
__AGENTVM_APP_TIMEMACHINE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

# The store's folders the group offers, in its order (tm_folder). Folder n (1 to 3) has its
# checkbox at TM_BASE_ID + 2n and its Finder button at TM_BASE_ID + 2n + 1.
TM_FOLDERS="Boxes Images Cache"
TM_BASE_ID=539
TM_TEXT_ID=547

tmutil_tool="${AGENTVM_APP_TMUTIL:-/usr/bin/tmutil}"

# tm_folder <n>  ->  the name of folder n (1 to 3), or nothing.
tm_folder() {
    case "$1" in
        1) printf 'Boxes\n' ;;
        2) printf 'Images\n' ;;
        3) printf 'Cache\n' ;;
    esac
}

# tm_toggle_id <n>  and  tm_show_id <n>  ->  the view ids of folder n's checkbox and Finder button.
tm_toggle_id() {
    printf '%s\n' "$(( TM_BASE_ID + 2 * $1 ))"
}
tm_show_id() {
    printf '%s\n' "$(( TM_BASE_ID + 2 * $1 + 1 ))"
}

# tm_number <view id>  ->  the folder (1 to 3) whose checkbox or Finder button that is, or nothing.
tm_number() {
    case "$1" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    [ "$1" -gt "$TM_BASE_ID" ] || return 0
    local _n=$(( ($1 - TM_BASE_ID) / 2 ))
    [ "$_n" -ge 1 ] && [ "$_n" -le 3 ] && printf '%s\n' "$_n"
    return 0
}

# tm_choice_file  ->  the file of the folders left out.
tm_choice_file() {
    printf '%s\n' "$agentvm_support_dir/time-machine-left-out"
}

# tm_chosen <store> <folder>  ->  0 when that folder of that store is to be left out, 1 otherwise.
tm_chosen() {
    local _file="$(tm_choice_file)"
    [ -f "$_file" ] || return 1
    TM_LINE="$1$ui_tab$2" /usr/bin/awk '$0 == ENVIRON["TM_LINE"] { found = 1 } END { exit found ? 0 : 1 }' "$_file"
}

# tm_choose <store> <folder> <1|0>  ->  the folder is chosen, or no longer chosen; the status of
# the write.
tm_choose() {
    local _file="$(tm_choice_file)"
    [ -d "$agentvm_support_dir" ] || /bin/mkdir -p "$agentvm_support_dir"
    {
        [ -f "$_file" ] && TM_LINE="$1$ui_tab$2" /usr/bin/awk '$0 != "" && $0 != ENVIRON["TM_LINE"]' "$_file"
        [ "$3" = "1" ] && printf '%s\t%s\n' "$1" "$2"
    } | ui_store "$_file"
}

# tm_state <store> <folder>  ->  excluded, included, missing (no such folder yet), or unknown
# (tmutil did not say).
tm_state() {
    if [ ! -d "$1/$2" ]; then
        printf 'missing\n'
        return 0
    fi
    local _line="$("$tmutil_tool" isexcluded "$1/$2" 2>/dev/null </dev/null)"
    case "$_line" in
        '[Excluded]'*) printf 'excluded\n' ;;
        '[Included]'*) printf 'included\n' ;;
        *)             printf 'unknown\n' ;;
    esac
}

# tm_change <store> <folder> <add|remove>  ->  leaves the folder out, or backs it up again. On a
# refusal, prints the folder's name, ": ", and the first line of tmutil's message without the path
# it starts with (the group names the folder already).
tm_change() {
    local _verb="addexclusion"
    [ "$3" = "remove" ] && _verb="removeexclusion"
    local _out
    _out="$("$tmutil_tool" "$_verb" "$1/$2" 2>&1 </dev/null)"
    local _status=$?
    [ "$_status" -eq 0 ] && return 0
    _out="$(printf '%s\n' "$_out" | /usr/bin/awk 'NF { print; exit }')"
    _out="${_out#"$1/$2: "}"
    [ -n "$_out" ] || _out="tmutil exited with status $_status"
    printf '%s: %s\n' "$2" "$_out"
}

# tm_read <uuid> [errors]  ->  the group's state into the window's cache: tm.tsv holds the store,
# then a line per folder: its name, 1 or 0 (chosen), its state. A chosen folder that is backed up
# is left out first, and a folder found left out is taken as chosen. tm-error holds the folders
# tmutil refused; errors, from an unchecking just made, are kept there as they are.
tm_read() {
    local _uuid="$1"
    local _store="$(main_store "$_uuid")"
    local _errors="${2:-}"
    local _rows=""
    local _name _chosen _state _error _choose_status
    for _name in $TM_FOLDERS; do
        _chosen=0
        tm_chosen "$_store" "$_name" && _chosen=1
        _state="$(tm_state "$_store" "$_name")"
        if [ "$_chosen" = "1" ] && [ "$_state" = "included" ]; then
            _error="$(tm_change "$_store" "$_name" add)"
            if [ -n "$_error" ]; then
                _errors="$_errors$_error
"
            else
                _state="$(tm_state "$_store" "$_name")"
            fi
        elif [ "$_chosen" = "0" ] && [ "$_state" = "excluded" ]; then
            tm_choose "$_store" "$_name" 1
            _choose_status=$?
            [ "$_choose_status" -eq 0 ] && _chosen=1
        fi
        _rows="$_rows$_name$ui_tab$_chosen$ui_tab$_state
"
    done
    printf '%s\n%s' "$_store" "$_rows" | ui_store "$(ui_cache "$_uuid" tm.tsv)"
    printf '%s' "$_errors" | ui_store "$(ui_cache "$_uuid" tm-error)"
}

# tm_text <uuid>  ->  the line under the checkboxes: the first folder tmutil refused, or where the
# setting is seen.
tm_text() {
    local _error="$(/usr/bin/awk 'NF { print; exit }' "$(ui_cache "$1" tm-error)" 2>/dev/null)"
    if [ -n "$_error" ]; then
        printf 'Could not change %s.\n' "${_error%.}"
        return 0
    fi
    printf 'Time Machine settings do not list these folders.\n'
}

# tm_paint <uuid>  ->  the checkboxes, the Finder buttons and the line, from the cache. Before the
# first reading the checkboxes are unchecked and cannot be used.
tm_paint() {
    local _uuid="$1"
    local _cache="$(ui_cache "$_uuid" tm.tsv)"
    local _store="$(/usr/bin/sed -n '1p' "$_cache" 2>/dev/null)"
    local _n _name _chosen _toggle _show
    for _n in 1 2 3; do
        _name="$(tm_folder "$_n")"
        _toggle="$(tm_toggle_id "$_n")"
        _show="$(tm_show_id "$_n")"
        _chosen="$(/usr/bin/awk -F'\t' -v name="$_name" 'NR > 1 && $1 == name { print $2; exit }' "$_cache" 2>/dev/null)"
        if [ "$_chosen" = "1" ]; then
            "$dialog" "$_uuid" "$_toggle" true
        else
            "$dialog" "$_uuid" "$_toggle" false
        fi
        if [ -n "$_store" ]; then
            ui_enable "$_uuid" "$_toggle" 1
        else
            ui_enable "$_uuid" "$_toggle" 0
        fi
        if [ -n "$_store" ] && [ -d "$_store/$_name" ]; then
            ui_enable "$_uuid" "$_show" 1
        else
            ui_enable "$_uuid" "$_show" 0
        fi
    done
    if [ -n "$_store" ]; then
        "$dialog" "$_uuid" "$TM_TEXT_ID" "$(tm_text "$_uuid")"
    else
        "$dialog" "$_uuid" "$TM_TEXT_ID" ""
    fi
}

# tm_set <uuid> <n> <1|0>  ->  folder n's checkbox was checked or unchecked: the choice is kept,
# the folder left out or backed up again, and the group painted. A choice that cannot be kept is
# said in an alert, and nothing is changed.
tm_set() {
    local _uuid="$1"
    local _name="$(tm_folder "$2")"
    [ -n "$_name" ] || return 0
    local _store="$(main_store "$_uuid")"
    tm_choose "$_store" "$_name" "$3"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        main_alert "$_uuid" "Could not save the Time Machine setting" \
            "AgentVM could not write to $(agentvm_display_path "$agentvm_support_dir")."
        tm_paint "$_uuid"
        return 0
    fi
    local _errors=""
    if [ "$3" = "0" ] && [ "$(tm_state "$_store" "$_name")" = "excluded" ]; then
        _errors="$(tm_change "$_store" "$_name" remove)"
    fi
    tm_read "$_uuid" "$_errors"
    tm_paint "$_uuid"
}

# tm_show <uuid> <n>  ->  folder n in Finder, when it is there.
tm_show() {
    local _name="$(tm_folder "$2")"
    [ -n "$_name" ] || return 0
    local _folder="$(main_store "$1")/$_name"
    [ -d "$_folder" ] || return 0
    "$open_tool" "$_folder"
}
