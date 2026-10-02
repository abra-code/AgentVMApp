#!/bin/sh
# AgentVM.newbox.create.sh
# Create, on the last step of the New Box window: agent-vm is read again, and when nothing stands
# in the way, `box create` with what the steps hold makes the box, at once. When the box is to
# be started, a job starts it with no owner, so it runs until it is stopped. The main window then
# shows the box, and this window closes. agent-vm's refusal is shown in its words: of the box,
# and the window stays; of the start, and the window closes with the alert, since the box is
# made.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "4" ] || exit 0
# One click at a time: a second Create clicked while agent-vm is read would make the box twice.
wizard_enter "$window_uuid" || exit 0
newbox_read "$window_uuid"
# The window closed while agent-vm was read: nothing is made, and the cache folder the reading
# made again goes.
if ! newbox_is "$window_uuid"; then
    ui_cache_clear "$window_uuid"
    exit 0
fi
newbox_paint_check "$window_uuid"
[ -z "$(newbox_blocker "$window_uuid")" ] || exit 0
name="$(ui_get name "$window_uuid")"
# Read before the box is made: a window closed in that moment keeps nothing, and the box would
# be made and silently not started.
start=0
newbox_starts "$window_uuid" && start=1
# Off from here: a second click while the box is made must not make it again.
ui_enable "$window_uuid" "$NBOX_CREATE_ID" 0
newbox_args "$window_uuid" | agentvm_box_create
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "Box $name was not made" \
        "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$NBOX_CREATE_ID" 1
    exit 0
fi
job=""
start_error=""
if [ "$start" -eq 1 ]; then
    job="$(agentvm_job_box_start "$name")"
    status=$?
    if [ "$status" -ne 0 ]; then
        job=""
        start_error="$(agentvm_last_error "$status")"
    fi
fi
# The main window, when one is open, shows the new box: its lists are read again (and the start
# is followed from now), the box is selected, and the window comes to the front.
main_window="$(ui_item_window main window)"
if [ -n "$main_window" ]; then
    if [ -n "$job" ]; then
        main_follow_job "$job"
    else
        main_refresh "$main_window" status
    fi
    main_goto "$main_window" "box $name"
fi
if [ -n "$start_error" ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "Box $name was made, but not started" \
        "$start_error" "OK::AgentVM.newbox.cancel"
    exit 0
fi
[ -n "$main_window" ] && "$dialog" "$main_window" omc_window omc_select
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
