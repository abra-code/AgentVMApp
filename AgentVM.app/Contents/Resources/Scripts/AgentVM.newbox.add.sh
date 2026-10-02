#!/bin/sh
# AgentVM.newbox.add.sh
# Add, beside the network step's host field: the rule typed there joins the rules, as agent-vm
# will read it (lower case, no trailing dots), and the field is emptied. Text that is not a rule
# is refused with an alert that says what is.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newbox.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newbox_is "$window_uuid" || exit 0
[ "$(newbox_step "$window_uuid")" = "2" ] || exit 0
# Spaces around the rule, as a paste brings them, are not part of it; agent-vm drops them too.
text="$(ui_one_line "${OMC_ACTIONUI_VIEW_2067_VALUE:-}" | /usr/bin/sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
[ -n "$text" ] || exit 0
rule="$(net_check_rule "$text")"
if [ -z "$rule" ]; then
    main_alert "$window_uuid" "\"$text\" is not a network rule" \
        "A rule is a host (github.com), its subdomains (*.example.com), a host and port (example.com:8443), a pack (pack:github), or public."
    exit 0
fi
newbox_add_rule "$window_uuid" "$rule"
"$dialog" "$window_uuid" "$NBOX_HOST_FIELD_ID" ""
newbox_paint_network "$window_uuid"
exit 0
