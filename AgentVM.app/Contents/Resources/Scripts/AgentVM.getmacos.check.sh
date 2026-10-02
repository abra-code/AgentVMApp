#!/bin/sh
# AgentVM.getmacos.check.sh
# Check Again, in the Get macOS window: status, the restore files downloaded and what Apple
# offers are read again, and the window is painted. Nothing is downloaded.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.getmacos.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
getmacos_is "$window_uuid" || exit 0
"$dialog" "$window_uuid" "$GETMACOS_NOTE_ID" "Asking Apple for the newest macOS this Mac can run..."
getmacos_refresh "$window_uuid" check
exit 0
