#!/bin/sh
# AgentVM.network.pack.sh
# A pack in the Settings tab's grid was clicked: its rule (pack:<name>) is flipped in the rules
# wanted. The grid's row reports its 0-based index, the line of packs.tsv it was painted from.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
index="$OMC_ACTIONUI_TRIGGER_VIEW_PART_ID"
case "$index" in
    ''|*[!0123456789]*) exit 0 ;;
esac
pack="$(/usr/bin/sed -n "$((index + 1))p" "$(ui_cache "$window_uuid" packs.tsv)" | /usr/bin/cut -f1)"
[ -n "$pack" ] || exit 0
net_flip_rule "$window_uuid" "$box" "pack:$pack"
net_paint "$window_uuid"
