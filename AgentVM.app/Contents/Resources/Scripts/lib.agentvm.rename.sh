#!/bin/sh
# lib.agentvm.rename.sh
#
# The Rename window (AgentVM.rename.json, the views 5101-5106): another name for a stopped box or
# for an image, in one field. One window at a time (lib.agentvm.ui.sh, "Box windows", with the
# kind "rename" and the name "window"), opened by the Rename button beside the name in the main window's box
# pane or image pane.
#
# WHAT IS RENAMED is the window's value "rename", as "box:<name>" or "image:<name>": handed over
# by the main window in a pasteboard entry of its own, read once by the init handler. It is also
# what says that the window is an open Rename window.
#
# agent-vm is the judge of a rename (`box rename`, `image rename`): the window refuses only what
# cannot be a name, and shows agent-vm's refusal in its words. Both commands return in a moment,
# so neither is a job.
#
# AFTER A RENAME nothing of the app may go on naming the old name: the windows opened for it
# close (a box's network and programs windows, an image's update window and Full Disk Access
# guide), and the main window reads its lists again and selects the new name.
#
# Sources lib.agentvm.main.sh and lib.agentvm.wizard.sh. POSIX sh (bash 3.2 in POSIX mode) only.
# Validate with "sh -n".
[ -n "${__AGENTVM_APP_RENAME_LIB:-}" ] && return 0
__AGENTVM_APP_RENAME_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

RENAME_HEAD_ID=5101
RENAME_WHAT_ID=5102
RENAME_NAME_ID=5103
RENAME_NOTE_ID=5104
RENAME_APPLY_ID=5106

# The box or image a Rename window that opens now is for, as "<app pid> <box|image>:<name>".
AGENTVM_RENAME_OF_KEY="agentvm_rename_of"

# rename_target <uuid>  ->  "box:<name>" or "image:<name>" while that window is an open Rename
# window, or nothing.
rename_target() {
    ui_get rename "$1"
}

# rename_is <uuid>  ->  0 while that window is an open Rename window.
rename_is() {
    [ -n "$(rename_target "$1")" ]
}

# rename_valid_target <box|image>:<name>  ->  0 when it names a kind and a name agent-vm accepts.
rename_valid_target() {
    case "$1" in
        box:*|image:*) agentvm_valid_name "${1#*:}" ;;
        *) return 1 ;;
    esac
}

# rename_ask <box|image> <name> <command guid>  ->  the Rename window for it in front: the open
# one when it is for the same box or image, else a new one, after closing one opened for another.
rename_ask() {
    rename_valid_target "$1:$2" || return 1
    local _window="$(ui_item_window rename window)"
    if [ -n "$_window" ]; then
        if [ "$(rename_target "$_window")" = "$1:$2" ]; then
            "$dialog" "$_window" omc_window omc_select
            return 0
        fi
        # Released first: the new window's init handler may run before the old one's close handler.
        ui_item_release rename window "$_window"
        "$dialog" "$_window" omc_window omc_terminate_cancel
    fi
    "$pasteboard" "$AGENTVM_RENAME_OF_KEY" set "${OMC_APP_PROCESS_ID:-} $1:$2"
    ui_item_open rename window "$3"
}

# rename_take  ->  the target the main window handed over, if this run of the app did, or
# nothing; cleared either way, so it is read once.
rename_take() {
    local _entry="$("$pasteboard" "$AGENTVM_RENAME_OF_KEY" get)"
    "$pasteboard" "$AGENTVM_RENAME_OF_KEY" set ""
    [ -n "$_entry" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_entry%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    rename_valid_target "${_entry#* }" || return 0
    printf '%s\n' "${_entry#* }"
}

# rename_what_text <box|image>  ->  what a rename keeps and what follows it.
rename_what_text() {
    if [ "$1" = "box" ]; then
        printf 'The box keeps what it holds, its network rules and its logs, and avm goes on using it for the folders it was used for. The name inside the box (its host name) stays as it is.\n'
        return 0
    fi
    printf 'The boxes made from the image and the images built from it follow at once: each names its image by the new name. So does what avm remembers per folder.\n'
}

# rename_paint <uuid>  ->  the window's texts, and the field holding the name as it is now.
rename_paint() {
    local _target="$(rename_target "$1")"
    local _kind="${_target%%:*}"
    local _name="${_target#*:}"
    "$dialog" "$1" "$RENAME_HEAD_ID" "Rename $_kind $_name"
    "$dialog" "$1" "$RENAME_WHAT_ID" "$(rename_what_text "$_kind")"
    "$dialog" "$1" "$RENAME_NAME_ID" "$_name"
    "$dialog" "$1" "$RENAME_NOTE_ID" ""
}

# rename_blocker <box|image> <name> <new name>  ->  why the new name cannot be asked of agent-vm,
# or nothing. Whether the name is taken is agent-vm's to say: its lists are the ones that count.
rename_blocker() {
    if [ -z "$3" ]; then
        printf 'Give the %s a name.\n' "$1"
        return 0
    fi
    if [ "$3" = "$2" ]; then
        printf '%s is its name now.\n' "$2"
        return 0
    fi
    if ! agentvm_valid_name "$3"; then
        # The rule itself is the line above this one in the window.
        printf '"%s" cannot be a name.\n' "$(ui_one_line "$3")"
    fi
    return 0
}

# rename_done <box|image> <name> <new name>  ->  the app lets go of the old name: the windows
# opened for it close, and the main window, when one is open, reads its lists again and shows
# the box or image under its new name.
rename_done() {
    if [ "$1" = "box" ]; then
        ui_item_close network "$2"
        ui_item_close programs "$2"
    else
        ui_item_close update "$2"
        ui_item_close access "$2"
    fi
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    [ "$(ui_get "$1" "$_main")" = "$2" ] && ui_set "$1" "$_main" ""
    main_refresh "$_main" status
    main_goto "$_main" "$1 $3"
}
