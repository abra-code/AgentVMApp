#!/bin/sh
# AgentVM.main.init.sh
# The main window opens (INIT_SUBCOMMAND_ID): reads agent-vm, doctor and status, paints the face
# that fits, and starts the poll loop that keeps it current. It names itself as the main window,
# so that an agentvm:// URL finds it, and shows what a URL that opened it asked for.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
# A new window has no loop and no selections yet.
ui_set poll "$window_uuid" ""
ui_set box "$window_uuid" ""
ui_set image "$window_uuid" ""
# The newest main window is the one a URL goes to.
ui_item_claim main window "$window_uuid"
main_refresh "$window_uuid" full
target="$(ui_goto_take)"
[ -n "$target" ] && main_goto "$window_uuid" "$target"
"$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.main.poll"
