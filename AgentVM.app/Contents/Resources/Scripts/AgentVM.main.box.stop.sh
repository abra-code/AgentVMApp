#!/bin/sh
# AgentVM.main.box.stop.sh
# Stop, in the box detail pane: stops the selected box as an agent-vm job. Status is read first: a
# box that no longer runs, or that a job holds, is not stopped. When another program started the
# box, or programs run in it, it asks first; the box asked about is kept as the window's pending
# stop, and Stop in the question runs AgentVM.main.box.stop.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
# For the one-click-at-a-time mark (wizard_enter).
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
# One click at a time: a second click while agent-vm is read would start a second job, which
# agent-vm fails (the box is in use), and the window would report a failure that is none.
wizard_enter "$window_uuid" || exit 0
ui_set box_stop "$window_uuid" ""
main_read_status "$window_uuid"
read_status=$?
main_paint "$window_uuid"
[ "$read_status" -eq 0 ] || exit 0
main_box_askable "$window_uuid" "$name" stop || exit 0
question="$(main_box_stop_question "$window_uuid" "$name")"
if [ -z "$question" ]; then
    main_box_job "$window_uuid" "$name" stop "$OMC_CURRENT_COMMAND_GUID"
    exit 0
fi
ui_set box_stop "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Stop box $name?" "$question" \
    "Cancel:cancel:" "Stop:destructive:AgentVM.main.box.stop.confirmed"
