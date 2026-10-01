#!/bin/sh
# AgentVM.main.box.shell.sh
# Open Shell, in the box detail pane: Terminal opens a login shell in the running box
# (`agent-vm box shell`), through a .command file (lib.agentvm.sh, agentvm_shell_file).

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
file="$(agentvm_shell_file "$name")"
status=$?
main_open_terminal "$window_uuid" "$name" "$file" "$status"
