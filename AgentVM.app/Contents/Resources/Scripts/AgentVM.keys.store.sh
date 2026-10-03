#!/bin/sh
# AgentVM.keys.store.sh
# Store, in the Agent Keys window: what the field holds becomes the value of the key the window
# works on, in the login Keychain, replacing an older value. The value goes to agent-vm on its
# stdin (lib.agentvm.keys.sh, THE VALUE OF A KEY); the field is emptied once it is stored.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
keys_is "$window_uuid" || exit 0
# One Store at a time: two at once would both write the same Keychain item.
wizard_enter "$window_uuid" || exit 0
if ! keys_selection_settled "$window_uuid"; then
    "$dialog" "$window_uuid" "$KEYS_NOTE_ID" "The selection was still changing. Nothing was stored: click Store again."
    exit 0
fi
row="$(keys_selected_row "$window_uuid")"
[ -n "$row" ] || exit 0
# The name is the looked-up row's own: a second reading of the pasteboard could differ.
name="$(printf '%s\n' "$row" | /usr/bin/cut -f1)"
agentvm_valid_secret_name "$name" || exit 0
# A pasted key often brings a space or a line end with it. Trimmed with the shell alone.
while :; do
    case "$keys_typed" in
        [[:space:]]*) keys_typed="${keys_typed#?}" ;;
        *[[:space:]]) keys_typed="${keys_typed%?}" ;;
        *) break ;;
    esac
done
if [ -z "$keys_typed" ]; then
    "$dialog" "$window_uuid" "$KEYS_NOTE_ID" "Type or paste the key into the field first."
    exit 0
fi
printf '%s' "$keys_typed" | agentvm_secret_set "$name"
status=$?
keys_typed=""
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "Could not store $name" "$(agentvm_last_error "$status")"
    exit 0
fi
"$dialog" "$window_uuid" "$KEYS_FIELD_ID" ""
keys_refresh "$window_uuid"
keys_is "$window_uuid" || exit 0
keys_say "$window_uuid" "Stored $name in your login Keychain."
exit 0
