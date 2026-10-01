#!/bin/sh
# AgentVM.main.box.agent.sh
# Run an Agent in Terminal..., in the box detail pane. Its command in Command.json has a
# CHOOSE_FOLDER_DIALOG, so the engine asks for a folder before this runs; Cancel leaves the
# chosen folder empty. Terminal then runs avm on the box from that folder: avm
# starts the box when it is stopped, shares the folder at the same path, snapshots it, asks which
# agent to run (or a shell), and afterwards reports what changed. When an agent's key is missing,
# avm offers to set it.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
folder="$OMC_DLG_CHOOSE_FOLDER_PATH"
[ -n "$folder" ] || exit 0
name="$(ui_get box "$window_uuid")"
[ -n "$name" ] || exit 0
file="$(agentvm_avm_file "$name" "$folder")"
status=$?
main_open_terminal "$window_uuid" "$name" "$file" "$status"
