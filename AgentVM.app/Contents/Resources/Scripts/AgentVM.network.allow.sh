#!/bin/sh
# AgentVM.network.allow.sh
# Allow Selected Host..., in the Activity tab: asks first, then AgentVM.network.allow.confirmed
# adds the refused host's rule to the box at once. The rule is rebuilt from the row's host and port
# (net_connection_rule), since the host name came from a program in the box. The box and the rule
# asked about are the window's pending allow, read once by the confirmation.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
ui_set net_allow "$window_uuid" ""
rule="$(net_allowable "$window_uuid" "$OMC_ACTIONUI_TABLE_613_COLUMN_1_VALUE" "$OMC_ACTIONUI_TABLE_613_COLUMN_2_VALUE" \
    "$OMC_ACTIONUI_TABLE_613_COLUMN_6_VALUE" "$OMC_ACTIONUI_TABLE_613_COLUMN_7_VALUE")"
[ -n "$rule" ] || exit 0
ui_set net_allow "$window_uuid" "$box $rule"
"$dialog" "$window_uuid" omc_window omc_present_alert "Allow $rule in box $box?" \
    "Programs in the box can then connect to $rule, unless it resolves to an address on this Mac or your local network, which stays refused. The rule applies at once, even while the box runs, and stays with the box until it is removed." \
    "Cancel:cancel:" "Allow::AgentVM.network.allow.confirmed"
