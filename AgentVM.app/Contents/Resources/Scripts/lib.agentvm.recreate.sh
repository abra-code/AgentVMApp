#!/bin/sh
# lib.agentvm.recreate.sh
#
# The Recreate window (AgentVM.recreate.json, the views 5201-5206): a stopped box made again, from
# its own image or from another one chosen in a table. One window at a time (lib.agentvm.ui.sh,
# "Box windows", with the kind "recreate" and the name "window"), opened by Recreate in the main
# window's box pane.
#
# WHICH BOX is the window's value "recreate": handed over by the main window in a pasteboard entry
# of its own, read once by the init handler. It is also what says that the window is an open
# Recreate window. The image chosen is the value "picked": the box's own image when it is ready,
# else none until a row is selected.
#
# WHY A WINDOW and not a question: the image a box was made from can be deleted, or be one the
# user no longer wants, and `box recreate --image` makes the box from another. The window says
# what goes, as the question did, and lists the images a box can be made from, as New Box does
# (newbox_image_rows), of the box's own system only (recreate_image_rows): a recreate keeps the
# box's memory and network rules, and is not the way to turn a macOS box into a Linux one.
#
# WHAT IT READS: `status`, into its own cache (main_read_status), on opening, on activation and
# before Recreate; the image rows as New Box reads them (build.tsv) come from the same answer.
# agent-vm is the judge of a recreate: it refuses a box that runs, and an image it cannot clone.
# A recreate is a clone, so it returns in a moment and is not a job.
#
# Sources lib.agentvm.newbox.sh (and with it lib.agentvm.main.sh and lib.agentvm.wizard.sh). POSIX
# sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_RECREATE_LIB:-}" ] && return 0
__AGENTVM_APP_RECREATE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

RECREATE_HEAD_ID=5201
RECREATE_WHAT_ID=5202
RECREATE_IMAGES_ID=5203
RECREATE_NOTE_ID=5204
RECREATE_APPLY_ID=5206

# The box a Recreate window that opens now is for, as "<app pid> <name>".
AGENTVM_RECREATE_OF_KEY="agentvm_recreate_of"

# recreate_box <uuid>  ->  the box that window is for while it is an open Recreate window, or
# nothing.
recreate_box() {
    ui_get recreate "$1"
}

# recreate_is <uuid>  ->  0 while that window is an open Recreate window.
recreate_is() {
    [ -n "$(recreate_box "$1")" ]
}

# recreate_ask <box> <command guid>  ->  the Recreate window for that box in front: the open one
# when it is for the same box, else a new one, after closing one opened for another.
recreate_ask() {
    agentvm_valid_name "$1" || return 1
    local _window="$(ui_item_window recreate window)"
    if [ -n "$_window" ]; then
        if [ "$(recreate_box "$_window")" = "$1" ]; then
            "$dialog" "$_window" omc_window omc_select
            return 0
        fi
        # Released first: the new window's init handler may run before the old one's close handler.
        ui_item_release recreate window "$_window"
        "$dialog" "$_window" omc_window omc_terminate_cancel
    fi
    "$pasteboard" "$AGENTVM_RECREATE_OF_KEY" set "${OMC_APP_PROCESS_ID:-} $1"
    ui_item_open recreate window "$2"
}

# recreate_take  ->  the box the main window handed over, if this run of the app did, or nothing;
# cleared either way, so it is read once.
recreate_take() {
    local _entry="$("$pasteboard" "$AGENTVM_RECREATE_OF_KEY" get)"
    "$pasteboard" "$AGENTVM_RECREATE_OF_KEY" set ""
    [ -n "$_entry" ] && [ -n "${OMC_APP_PROCESS_ID:-}" ] || return 0
    [ "${_entry%% *}" = "$OMC_APP_PROCESS_ID" ] || return 0
    agentvm_valid_name "${_entry#* }" || return 0
    printf '%s\n' "${_entry#* }"
}

# recreate_read <uuid>  ->  0 with the window's lists read anew: the rows of `status` as the main
# window keeps them, and the image rows New Box reads (build.tsv) from the same answer. A failed
# `status` keeps the previous rows and leaves its message in the cache file status-error. 1 with
# nothing kept when the window closed while agent-vm was read: callers stop there.
recreate_read() {
    main_read_status "$1"
    local _status=$?
    # The window closed while agent-vm was read: the cache folder the reading made again goes.
    if ! recreate_is "$1"; then
        recreate_tidy "$1"
        return 1
    fi
    [ "$_status" -eq 0 ] || return "$_status"
    agentvm_status_build_rows < "$(ui_cache "$1" status.json)" | ui_store "$(ui_cache "$1" build.tsv)"
    return 0
}

# recreate_tidy <uuid>  ->  when the window closed while a handler painted it, what the painting
# left after the close handler ran goes: the cache folder (every cache read makes it again) and
# the image chosen. The last step of a handler that reads or paints.
recreate_tidy() {
    recreate_is "$1" && return 0
    ui_set picked "$1" ""
    ui_cache_clear "$1"
}

# recreate_own_image <uuid>  ->  the image the box was made from, as the last reading says, or
# nothing.
recreate_own_image() {
    local _image="$(main_row "$1" boxes "$(recreate_box "$1")" | /usr/bin/cut -f3)"
    [ "$_image" != "-" ] && agentvm_valid_name "$_image" && printf '%s\n' "$_image"
    return 0
}

# recreate_picked <uuid>  ->  the image chosen, as kept, or nothing.
recreate_picked() {
    local _picked="$(ui_get picked "$1")"
    agentvm_valid_name "$_picked" && printf '%s\n' "$_picked"
    return 0
}

# recreate_what_text <uuid>  ->  what a recreate keeps and what it deletes, as the question before
# the window said it, with the sentence on the logs agent-vm keeps.
recreate_what_text() {
    local _kept="$(main_box_logs_kept_text "$1" "$(recreate_box "$1")")"
    printf 'The box is made again from the image chosen below, as the image is now, with the same name, processors, memory and network rules. Everything installed or saved in the box, logins included, is deleted.%s This cannot be undone.\n' "${_kept:+ $_kept}"
}

# recreate_image_rows <uuid>  ->  the rows of the image table: New Box's rows (newbox_image_rows)
# for the images that run the box's system, macOS or Linux (column 23 of the box's row, column 13
# of an image's build row).
recreate_image_rows() {
    local _linux=0
    [ "$(main_row "$1" boxes "$(recreate_box "$1")" | /usr/bin/cut -f23)" = "linux" ] && _linux=1
    newbox_image_rows "$1" | /usr/bin/awk -F'\t' -v linux="$_linux" -v build="$(ui_cache "$1" build.tsv)" '
        BEGIN { while ((getline line < build) > 0) { split(line, cell, "\t"); guest[cell[1] ""] = cell[13] } }
        ((guest[$1 ""] == "linux") ? 1 : 0) == linux + 0'
}

# recreate_own_text <uuid>  ->  why nothing is chosen when nothing is: what became of the box's own
# image when it is not listed (deleted, an image of the other system now that another was built
# under its name, or not ready), then what to do (choose another, wait, or build one when no image
# of the box's system is listed).
recreate_own_text() {
    local _own="$(recreate_own_image "$1")"
    local _rows="$(recreate_image_rows "$1")"
    local _system="macOS"
    [ "$(main_row "$1" boxes "$(recreate_box "$1")" | /usr/bin/cut -f23)" = "linux" ] && _system="Linux"
    local _fact=""
    local _advice="Choose another image."
    if [ -n "$_own" ] && [ -z "$(printf '%s\n' "$_rows" | /usr/bin/awk -F'\t' -v name="$_own" '$1 "" == name { print "yes"; exit }')" ]; then
        local _row="$(newbox_image_row "$1" "$_own")"
        local _image_system="macOS"
        [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f13)" = "linux" ] && _image_system="Linux"
        if [ -z "$_row" ]; then
            _fact="Image $_own, which the box was made from, was deleted."
        elif [ "$_image_system" != "$_system" ]; then
            _fact="Image $_own, which the box was made from, is a $_image_system image now."
        else
            _fact="Image $_own, which the box was made from, is not ready."
            _advice="Choose another image, or wait until it is ready."
        fi
    fi
    if [ -z "$(printf '%s\n' "$_rows" | /usr/bin/awk 'NF')" ]; then
        # Its own image is only not ready (being built, most likely): waiting for it comes first.
        if [ "$_advice" != "Choose another image." ]; then
            printf '%s There is no other ready %s image, so wait until it is ready, or use New Image... to build another.\n' "$_fact" "$_system"
            return 0
        fi
        printf '%sThere is no other ready %s image to make the box from. New Image... builds one.\n' "${_fact:+$_fact }" "$_system"
    elif [ -z "$_fact" ]; then
        printf 'Choose the image the box is made from.\n'
    else
        printf '%s %s\n' "$_fact" "$_advice"
    fi
}

# recreate_blocker <uuid>  ->  why Recreate cannot be asked of agent-vm now, or nothing: agent-vm
# could not be read, the box is gone, runs, is temporary or is held by a job, or the image chosen
# cannot be cloned (newbox_image_blocker).
recreate_blocker() {
    local _error="$(main_status_error "$1")"
    if [ -n "$_error" ]; then
        printf 'agent-vm could not be read: %s\n' "$_error"
        return 0
    fi
    local _box="$(recreate_box "$1")"
    if [ -z "$(main_row "$1" boxes "$_box")" ]; then
        printf 'Box %s is not there any more.\n' "$_box"
        return 0
    fi
    if ! main_box_askable "$1" "$_box" recreate; then
        printf 'Box %s can be recreated once it is stopped and nothing else is changing it.\n' "$_box"
        return 0
    fi
    local _picked="$(recreate_picked "$1")"
    if [ -z "$_picked" ]; then
        recreate_own_text "$1"
        return 0
    fi
    newbox_image_blocker "$1" "$_picked"
}

# recreate_choice_text <uuid>  ->  the line under the table when Recreate can go ahead: the image
# chosen, and whether it is the box's own.
recreate_choice_text() {
    local _picked="$(recreate_picked "$1")"
    local _own="$(recreate_own_image "$1")"
    if [ "$_picked" = "$_own" ]; then
        printf 'Image %s is the one the box was made from.\n' "$_picked"
    elif [ -n "$_own" ]; then
        printf 'The box was made from image %s, and is made from image %s now.\n' "$_own" "$_picked"
    else
        printf 'The box is made from image %s.\n' "$_picked"
    fi
}

# recreate_paint_choice <uuid>  ->  the line under the table and Recreate, from what was read and
# the image chosen. The line is orange when something stands in the way (the window's JSON sets
# no color: it is set here each time).
recreate_paint_choice() {
    local _blocker="$(recreate_blocker "$1")"
    if [ -n "$_blocker" ]; then
        "$dialog" "$1" "$RECREATE_NOTE_ID" omc_set_property foregroundStyle orange
        "$dialog" "$1" "$RECREATE_NOTE_ID" "$_blocker"
        ui_enable "$1" "$RECREATE_APPLY_ID" 0
        return 0
    fi
    "$dialog" "$1" "$RECREATE_NOTE_ID" omc_set_property foregroundStyle secondary
    "$dialog" "$1" "$RECREATE_NOTE_ID" "$(recreate_choice_text "$1")"
    ui_enable "$1" "$RECREATE_APPLY_ID" 1
}

# recreate_paint <uuid>  ->  the window's texts, the image table with the image chosen selected,
# and the line under it. An image chosen that is no longer listed is chosen no more.
recreate_paint() {
    local _box="$(recreate_box "$1")"
    "$dialog" "$1" "$RECREATE_HEAD_ID" "Recreate box $_box"
    "$dialog" "$1" "$RECREATE_WHAT_ID" "$(recreate_what_text "$1")"
    local _rows="$(recreate_image_rows "$1")"
    printf '%s\n' "$_rows" | /usr/bin/awk 'NF' | "$dialog" "$1" "$RECREATE_IMAGES_ID" omc_table_set_rows_from_stdin
    local _picked="$(recreate_picked "$1")"
    if [ -n "$_picked" ] && [ -z "$(printf '%s\n' "$_rows" | /usr/bin/awk -F'\t' -v name="$_picked" '$1 "" == name { print "yes"; exit }')" ]; then
        _picked=""
        ui_set picked "$1" ""
    fi
    # A row stays selected across new rows otherwise, and would show a choice that is not kept.
    if [ -n "$_picked" ]; then
        "$dialog" "$1" "$RECREATE_IMAGES_ID" omc_select_row_with_content "$_picked" 1
    else
        "$dialog" "$1" "$RECREATE_IMAGES_ID" omc_deselect
    fi
    recreate_paint_choice "$1"
}

# recreate_done <box>  ->  the main window, when one is open, reads its lists again, and the box,
# when it is still the one selected, is measured again (a recreated box has another disk).
recreate_done() {
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    main_refresh "$_main" status
    [ "$(ui_get box "$_main")" = "$1" ] || return 0
    [ -n "$(main_row "$_main" boxes "$1")" ] || return 0
    main_read_info "$_main" box "$1"
    main_paint_box_detail "$_main"
}
