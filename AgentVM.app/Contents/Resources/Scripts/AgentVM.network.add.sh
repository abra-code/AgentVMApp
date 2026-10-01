#!/bin/sh
# AgentVM.network.add.sh
# Add, beside the Settings tab's host field: the rule typed there joins the rules wanted, as
# agent-vm will read it (lower case, no trailing dots), and the field is emptied. Text that is not
# a rule is refused with an alert that says what is.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.network.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
box="$(ui_get box "$window_uuid")"
[ -n "$box" ] && agentvm_valid_name "$box" || exit 0
# Spaces around the rule, as a paste brings them, are not part of it; agent-vm drops them too.
text="$(printf '%s\n' "$OMC_ACTIONUI_VIEW_605_VALUE" | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$text" ] || exit 0
rule="$(net_check_rule "$text")"
if [ -z "$rule" ]; then
    main_alert "$window_uuid" "\"$text\" is not a network rule" \
        "A rule is a host (github.com), its subdomains (*.example.com), a host and port (example.com:8443), a pack (pack:github), or public."
    exit 0
fi
net_add_rule "$window_uuid" "$box" "$rule" || exit 0
"$dialog" "$window_uuid" "$NET_HOST_FIELD_ID" ""
net_paint "$window_uuid"
