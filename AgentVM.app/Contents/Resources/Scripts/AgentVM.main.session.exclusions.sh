#!/bin/sh
# AgentVM.main.session.exclusions.sh
# Choose..., on the Exclusions row of the Sessions tab's project pane: the Exclusions window for
# the selected project in front, the open one or a new one.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
project="$(ui_get session-project "$window_uuid")"
[ -n "$project" ] || exit 0
excl_ask "$project" "$OMC_CURRENT_COMMAND_GUID"
exit 0
