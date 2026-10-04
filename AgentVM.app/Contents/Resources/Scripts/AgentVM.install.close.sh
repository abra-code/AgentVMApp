#!/bin/sh
# AgentVM.install.close.sh
# The Install agent-vm window closed (END_CANCEL_SUBCOMMAND_ID): there is no such window any
# more, if this one was it, and the window's values go. A click that is being worked on goes on
# through the download and its checks and stops before installing; an installation that has begun
# runs to its end.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.install.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_item_release install window "$window_uuid"
ui_set install "$window_uuid" ""
ui_set newest "$window_uuid" ""
ui_cache_clear "$window_uuid"
exit 0
