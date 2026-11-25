#!/bin/sh
# AgentVM.main.session.project.selected.sh
# A project card was selected in the Sessions tab: its sessions are shown, from the caches.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
project="$OMC_ACTIONUI_TABLE_711_COLUMN_1_VALUE"
# Only a project the cards hold: the value comes back from the window.
known=""
cards="$(ui_cache "$window_uuid" session-cards.tsv)"
if [ -n "$project" ] && [ -f "$cards" ]; then
    known="$(SES_PROJECT="$project" /usr/bin/awk -F'\t' '$1 == ENVIRON["SES_PROJECT"] { print "yes"; exit }' "$cards")"
fi
if [ "$known" = "yes" ]; then
    ui_set session-project "$window_uuid" "$project"
else
    ui_set session-project "$window_uuid" ""
fi
ses_paint_detail "$window_uuid"
exit 0
