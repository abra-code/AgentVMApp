#!/bin/sh
# AgentVM.main.restore.show.sh
# Show in Finder, beside the macOS restore images in Settings: their folder (<store>/Cache/ipsw).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
folder="$(/usr/bin/cut -f4 "$(ui_cache "$window_uuid" restore.tsv)" 2>/dev/null)"
[ -n "$folder" ] && [ -d "$folder" ] || exit 0
"$open_tool" "$folder"
exit 0
