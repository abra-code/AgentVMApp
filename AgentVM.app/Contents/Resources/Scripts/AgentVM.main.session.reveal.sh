#!/bin/sh
# AgentVM.main.session.reveal.sh
# The folder button, at the left of the bar under the Sessions tab's project cards: the selected
# project's folder, opened in a Finder window.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ses_reveal "$window_uuid"
exit 0
