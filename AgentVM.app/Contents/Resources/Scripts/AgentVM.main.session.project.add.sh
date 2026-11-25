#!/bin/sh
# AgentVM.main.session.project.add.sh
# The plus button in the Sessions tab's toolbar. Its command in Command.json has a
# CHOOSE_FOLDER_DIALOG, so the engine asks for a folder before this runs; Cancel leaves the
# chosen folder empty. The folder becomes a project card, selected, so a project with no session
# yet can have its exclusions chosen in its pane.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
folder="$OMC_DLG_CHOOSE_FOLDER_PATH"
[ -n "$folder" ] || exit 0
# The panel may hand the folder over with a trailing "/"; agent-vm names projects without one.
case "$folder" in
    /) ;;
    */) folder="${folder%/}" ;;
esac
ses_add_project "$window_uuid" "$folder"
exit 0
