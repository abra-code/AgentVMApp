#!/bin/sh
# AgentVM.install.start.sh
# Download and Install, in the Install agent-vm window: the newest release's package is
# downloaded, checked and installed, with each step said in the window. The checkbox is read as
# this click saw it. A second click while one is being worked on does nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.install.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
install_is "$window_uuid" || exit 0
install_enter "$window_uuid" || exit 0
with_path=0
eval "ticked=\"\${OMC_ACTIONUI_VIEW_${INSTALL_PATH_ID}_VALUE:-}\""
[ "$ticked" = "true" ] && with_path=1
install_perform "$window_uuid" "$with_path"
exit 0
