#!/bin/sh
# AgentVM.main.close.sh
# The main window closed (END_CANCEL_SUBCOMMAND_ID): the poll loop ends at its next wake, and the
# window's selection and cache files go.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set poll "$window_uuid" "closed"
ui_set selected "$window_uuid" ""
ui_cache_clear "$window_uuid"
