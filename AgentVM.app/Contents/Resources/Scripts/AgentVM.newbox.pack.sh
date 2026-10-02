#!/bin/sh
# AgentVM.newbox.pack.sh
# A pack in the network step's grid was clicked: its rule (pack:<name>) is flipped. The grid's
# row reports its 0-based index, the line of packs.tsv it was painted from.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
index="${OMC_ACTIONUI_TRIGGER_VIEW_PART_ID:-}"
case "$index" in
    ''|*[!0123456789]*) exit 0 ;;
esac
pack="$(main_rows "$window_uuid" packs | /usr/bin/sed -n "$((index + 1))p" | /usr/bin/cut -f1)"
[ -n "$pack" ] || exit 0
rule="$(net_check_rule "pack:$pack")"
[ -n "$rule" ] || exit 0
newbox_flip_rule "$window_uuid" "$rule"
newbox_paint_network "$window_uuid"
exit 0
