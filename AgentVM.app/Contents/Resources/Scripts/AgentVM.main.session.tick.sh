#!/bin/sh
# AgentVM.main.session.tick.sh
# A session's checkbox in the Sessions tab's table changed (the row index is the context): what
# the sessions ticked free together follows, summed from the kept measurement.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
row="$(printf '%s' "${OMC_ACTIONUI_TRIGGER_CONTEXT:-}" | /usr/bin/tr -cd '0123456789')"
ses_tick "$window_uuid" "$row"
exit 0
