#!/bin/sh
# AgentVM.main.session.exclusions.folder.sh
# The folder button under the Sessions tab's project list. Its command in Command.json has a
# CHOOSE_FOLDER_DIALOG, so the engine asks for a folder before this runs; Cancel leaves the
# chosen folder empty. The Exclusions window then opens for that folder: a project with no
# session yet has no pane to choose from.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.exclusions.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
folder="$OMC_DLG_CHOOSE_FOLDER_PATH"
[ -n "$folder" ] || exit 0
# The panel may hand the folder over with a trailing "/"; agent-vm names projects without one.
case "$folder" in
    /) ;;
    */) folder="${folder%/}" ;;
esac
excl_ask "$folder" "$OMC_CURRENT_COMMAND_GUID"
exit 0
