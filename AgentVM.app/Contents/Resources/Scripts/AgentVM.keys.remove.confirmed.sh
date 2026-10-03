#!/bin/sh
# AgentVM.keys.remove.confirmed.sh
# Remove, in the question AgentVM.keys.remove asked: agent-vm deletes the key asked about from
# the login Keychain, and the keys are read again. When agent-vm refuses, its reason is shown.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
keys_is "$window_uuid" || exit 0
name="$(ui_get key_remove "$window_uuid")"
# Read once: a second confirmation, or one without a question, removes nothing.
ui_set key_remove "$window_uuid" ""
[ -n "$name" ] && agentvm_valid_secret_name "$name" || exit 0
# The pasteboard is not a trusted place: only a key agent-vm listed is removed.
[ -n "$(main_row "$window_uuid" keys "$name")" ] || exit 0
agentvm_secret_delete "$name"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "$name was not removed" "$(agentvm_last_error "$status")"
    keys_refresh "$window_uuid"
    exit 0
fi
keys_refresh "$window_uuid"
keys_is "$window_uuid" || exit 0
keys_say "$window_uuid" "Removed $name from your login Keychain."
exit 0
