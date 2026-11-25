#!/bin/sh
# AgentVM.exclusions.save.sh
# Save, in the Exclusions window: the ticked folders become the project's saved list
# (`session exclusions --set`, or --clear when none is ticked), the main window shows it on the
# project's Exclusions row, and this window closes. agent-vm's refusal is shown whole, in its
# words, and the window stays, with the saved list as it was.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
project="$(excl_project "$window_uuid")"
[ -n "$project" ] || exit 0
[ -f "$(excl_file "$window_uuid" rows.tsv)" ] || exit 0
# One click at a time: a second Save clicked while agent-vm works would ask it twice.
wizard_enter "$window_uuid" || exit 0
ui_enable "$window_uuid" "$EXCL_SAVE_ID" 0
# The paths become arguments, one each, read line by line into the positional parameters.
set --
ticked="$(excl_ticked "$window_uuid")"
if [ -n "$ticked" ]; then
    while IFS= read -r path; do
        [ -n "$path" ] && set -- "$@" "$path"
    done <<END
$ticked
END
fi
agentvm_session_exclusions_set "$project" "$@" > /dev/null
status=$?
if [ "$status" -ne 0 ]; then
    "$dialog" "$window_uuid" omc_window omc_present_alert "The list was not saved" "$(agentvm_last_error "$status")" "OK::"
    ui_enable "$window_uuid" "$EXCL_SAVE_ID" 1
    exit 0
fi
excl_saved
"$dialog" "$window_uuid" omc_window omc_terminate_cancel
exit 0
