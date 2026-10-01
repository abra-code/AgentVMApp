#!/bin/sh
# AgentVM.network.allow.confirmed.sh
# Allow, in the question AgentVM.network.allow asked: the rule is added to the box asked
# about, at once. Edits not applied yet stay, and the new rule is among the rules wanted.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
pending="$(ui_get net_allow "$window_uuid")"
# Read once: a second confirmation, or one without a question, allows nothing.
ui_set net_allow "$window_uuid" ""
box="${pending%% *}"
rule="${pending#* }"
[ -n "$pending" ] && [ "$box" != "$pending" ] && agentvm_valid_name "$box" || exit 0
agentvm_box_network_change "$box" - "+$rule"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "$rule was not allowed in box $box" "$(agentvm_last_error "$status")"
    exit 0
fi
net_read "$window_uuid" "$box" rules
net_add_rule "$window_uuid" "$box" "$rule"
net_paint "$window_uuid"
"$dialog" "$window_uuid" "$NET_NOTE_ID" "Allowed $rule. Its next connection gets through; earlier refusals stay listed until Refresh."
