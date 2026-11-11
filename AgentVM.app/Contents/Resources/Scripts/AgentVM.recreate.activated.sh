#!/bin/sh
# AgentVM.recreate.activated.sh
# The Recreate window comes to the front (WINDOW_DID_ACTIVATE_SUBCOMMAND_ID): agent-vm's lists are
# read again, since an image may have been made, deleted or changed meanwhile, and the window is
# painted from them, keeping the image chosen while it is listed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.recreate.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
recreate_is "$window_uuid" || exit 0
recreate_read "$window_uuid"
recreate_is "$window_uuid" || exit 0
recreate_paint "$window_uuid"
recreate_tidy "$window_uuid"
exit 0
