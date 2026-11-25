#!/bin/sh
# AgentVM.main.session.show.sh
# Show, beside the sessions in Settings: the Sessions tab, opened as choosing it does (measured when
# the kept measurement is stale).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
# A TabView's value is the 0-based index of its tab. Setting it fires nothing.
"$dialog" "$window_uuid" "$MAIN_STATUS_ID" "$SES_TAB_INDEX"
ses_open "$window_uuid"
exit 0
