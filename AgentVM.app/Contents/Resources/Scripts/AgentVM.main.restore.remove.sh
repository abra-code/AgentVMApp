#!/bin/sh
# AgentVM.main.restore.remove.sh
# Remove..., beside the macOS restore images in Settings: the question before removing every
# restore image agent-vm downloaded (`image fetch-ipsw --list` names them; their names are kept
# for AgentVM.main.restore.remove.confirmed).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
ui_set restore-remove "$window_uuid" ""
json="$(agentvm_ipsw_list)"
status=$?
if [ "$status" -ne 0 ]; then
    main_alert "$window_uuid" "The restore images could not be listed" "$(agentvm_last_error "$status")"
    exit 0
fi
rows="$(printf '%s\n' "$json" | agentvm_ipsw_rows)"
names="$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' 'NF { print $1 }' | /usr/bin/paste -sd ' ' -)"
[ -n "$names" ] || exit 0
bytes="$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$4 ~ /^[0123456789]+$/ { total += $4 } END { printf "%.0f\n", total }')"
count="$(printf '%s\n' "$names" | /usr/bin/awk '{ print NF }')"
ui_set restore-remove "$window_uuid" "$names"
"$dialog" "$window_uuid" omc_window omc_present_alert "Remove $(main_count_text "$count" "restore image") ($(ui_size_text "$bytes"))?" \
    "$(ses_restore_question "$window_uuid" "$names")" \
    "Cancel:cancel:" "Remove:destructive:AgentVM.main.restore.remove.confirmed"
exit 0
