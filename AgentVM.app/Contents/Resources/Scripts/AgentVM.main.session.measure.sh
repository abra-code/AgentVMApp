#!/bin/sh
# AgentVM.main.session.measure.sh
# Measure Again, under the Sessions tab's cards: `session usage` now, whatever the kept
# measurement's age, then the tab painted again.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
"$dialog" "$window_uuid" "$SES_FOOTER_ID" "Measuring what the sessions hold..."
ui_enable "$window_uuid" "$SES_MEASURE_ID" 0
ses_read "$window_uuid" measure
ui_enable "$window_uuid" "$SES_MEASURE_ID" 1
main_read_status "$window_uuid"
ses_paint "$window_uuid"
exit 0
