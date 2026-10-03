#!/bin/sh
# AgentVM.keys.remove.sh
# Remove..., in the Agent Keys window: asks first. The key asked about is kept as the window's
# pending removal: the confirmation's handler removes that one, whatever the selection is by
# then. Remove in the question runs AgentVM.keys.remove.confirmed.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.keys.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
keys_is "$window_uuid" || exit 0
ui_set key_remove "$window_uuid" ""
keys_selection_settled "$window_uuid" || exit 0
row="$(keys_selected_row "$window_uuid")"
[ -n "$row" ] || exit 0
# The name is the looked-up row's own: a second reading of the pasteboard could differ.
name="$(printf '%s\n' "$row" | /usr/bin/cut -f1)"
agentvm_valid_secret_name "$name" || exit 0
case "$(printf '%s\n' "$row" | /usr/bin/cut -f2)" in
    set|asks) ;;
    *) exit 0 ;;
esac
ui_set key_remove "$window_uuid" "$name"
"$dialog" "$window_uuid" omc_window omc_present_alert "Remove $name?" \
    "The key is deleted from your login Keychain. An agent started with it after that does not get it. The app cannot show a key, so keep a copy elsewhere if you may need it again." \
    "Cancel:cancel:" "Remove:destructive:AgentVM.keys.remove.confirmed"
exit 0
