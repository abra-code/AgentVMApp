#!/bin/sh
# AgentVM.main.image.show.sh
# Show in Finder, in the bar under the image list: the selected image's folder in the store, selected in a
# Finder window.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
main_show_folder "$window_uuid" images
