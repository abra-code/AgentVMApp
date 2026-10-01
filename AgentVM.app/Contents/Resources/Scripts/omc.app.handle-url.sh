#!/bin/sh
# omc.app.handle-url.sh
# The app was opened with an agentvm:// URL (the engine runs this command with the whole URL as
# $OMC_OBJ_TEXT, whether the app was running or not): agentvm://status, agentvm://box/<name> and
# agentvm://image/<name> bring the main window to the front with that box or image selected. Any
# other URL does nothing. A URL only shows; it changes nothing.
#
# This handler has no window of its own. An open main window is found by the entry it left
# (lib.agentvm.ui.sh); with none, what to show waits for the main window this handler opens. When
# the URL launched the app, a main window may be opening at the same moment, so one is waited for
# briefly before another is opened.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

URL_WAIT_STEPS=5
URL_WAIT_SECONDS=0.2

target="$(ui_url_target "${OMC_OBJ_TEXT:-}")"
[ -n "$target" ] || exit 0
window_uuid="$(ui_item_window main window)"
step=0
while [ -z "$window_uuid" ] && [ "$step" -lt "$URL_WAIT_STEPS" ]; do
    "$sleep_tool" "$URL_WAIT_SECONDS"
    step=$((step + 1))
    window_uuid="$(ui_item_window main window)"
done
if [ -z "$window_uuid" ]; then
    ui_goto_set "$target"
    "$next_command" "$OMC_CURRENT_COMMAND_GUID" "AgentVM.main"
    exit 0
fi
"$dialog" "$window_uuid" omc_window omc_select
# The lists as they are now: a link may name a box made a moment ago.
main_refresh "$window_uuid" status
main_goto "$window_uuid" "$target"
exit 0
