#!/bin/sh
# Tests/90-url-scheme.test.sh - the agentvm:// URL scheme: which URLs are routed, what they show
# in an open main window, how a main window is opened for one when none is, and that a URL never
# changes anything.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (boxes s3, cadabra-spike
# and try1; images dev-acp, dev-node and others). The handler's brief wait for a main window is
# fake_sleep.sh.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_STATUS_ID" ] && [ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_BOX_NAME_ID" ] \
    && [ -n "$MAIN_IMAGE_NAME_ID" ] || {
    printf '90-url-scheme: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
UUID="$OMC_ACTIONUI_WINDOW_UUID"
# The app's pid, as the engine exports it: the main window's entry and a waiting target carry it.
APP_PID="${OMC_APP_PROCESS_ID:?90-url-scheme: OMC_APP_PROCESS_ID is not set}"

store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# ui <function> [args...]  ->  a function of lib.agentvm.ui.sh, run in a subshell.
ui() {
    ( . "$APP_SCRIPTS/lib.agentvm.ui.sh" >/dev/null 2>&1
      "$@" )
}

# url <text>  ->  the app opened with that URL: the engine's command, with the URL as its text and
# no window of its own.
url() {
    ( OMC_OBJ_TEXT="$1"; OMC_ACTIONUI_WINDOW_UUID=""; ACTIONUI_WINDOW_UUID=""
      export OMC_OBJ_TEXT OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
      omc_run omc.app.handle-url )
}

# main_entry  ->  the pasteboard entry naming the main window: "<app pid> <uuid>".
main_entry() {
    "$PB" agentvm_window_main_window get
}

# waiting  ->  the target waiting for the next main window.
waiting() {
    "$PB" agentvm_goto get
}

# changes  ->  what the fake was asked that is not a plain read.
changes() {
    fake_log | /usr/bin/grep -v -e '^status ' -e '^doctor' -e '^--version' -e '^version' -e '^box info ' -e '^image info '
}

fake_reset
store '.'
"$PB" agentvm_window_main_window set ""
"$PB" agentvm_goto set ""
: > "$FAKE_SLEEP_LOG"

# -----------------------------------------------------------------------------------------------
section "which URLs are routed"
check "status"                   "status" "$(ui ui_url_target agentvm://status)"
check "  with a trailing slash, a query or a fragment" "status|status|status" \
    "$(ui ui_url_target agentvm://status/)|$(ui ui_url_target 'agentvm://status?from=cadabra')|$(ui ui_url_target 'agentvm://status#top')"
check "a box"                    "box s3" "$(ui ui_url_target agentvm://box/s3)"
check "an image"                 "image dev-acp" "$(ui ui_url_target agentvm://image/dev-acp)"
check "the scheme and the first part in any case; the name as written" "box s3" "$(ui ui_url_target AgentVM://Box/s3)"
check "  a name in upper case is not agent-vm's" "" "$(ui ui_url_target agentvm://box/S3)"
check "a name agent-vm would read as an option" "" "$(ui ui_url_target agentvm://box/-rf)"
check "  one with a path in it"  "" "$(ui ui_url_target agentvm://box/a/b)"
check "  one percent-encoded"    "" "$(ui ui_url_target 'agentvm://box/s3%20x')"
check "  one with a space or a line break" "|" "$(ui ui_url_target 'agentvm://box/s3 x')|$(ui ui_url_target "agentvm://box/s3
x")"
check "a box with no name"       "|" "$(ui ui_url_target agentvm://box)|$(ui ui_url_target agentvm://box/)"
check "status with something after it" "" "$(ui ui_url_target agentvm://status/extra)"
check "a form the app does not route" "|" "$(ui ui_url_target 'agentvm://new-image?for=cadabra')|$(ui ui_url_target agentvm://delete/s3)"
check "another scheme, and text that is no URL" "||" "$(ui ui_url_target https://box/s3)|$(ui ui_url_target box/s3)|$(ui ui_url_target '')"

# -----------------------------------------------------------------------------------------------
section "the main window names itself"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
check "on opening"               "$APP_PID $UUID" "$(main_entry)"

section "a URL with the main window open: a box"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
url agentvm://box/s3
check_status "the handler exits cleanly" 0
check "the window comes to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
check "  no second window is opened, and nothing waits" "0|" "$(chain_asked AgentVM.main)|$(waiting)"
check "  without waiting for one" "" "$(/bin/cat "$FAKE_SLEEP_LOG")"
check "the Boxes tab is shown"   "0" "$(ui_value "$MAIN_STATUS_ID")"
check "the box is the selection, and its pane is painted" "s3|s3" "$("$PB" "agentvm_box_$UUID" get)|$(ui_value "$MAIN_BOX_NAME_ID")"
check "  its card is highlighted" "$(ui_rows "$MAIN_BOXES_ID" | /usr/bin/awk -F'\t' '$1 == "s3" { print NR - 1 }')" "$(ui_selection "$MAIN_BOXES_ID")"
check "    (the fixture lists it)" "yes" "$([ -n "$(ui_selection "$MAIN_BOXES_ID")" ] && echo yes)"
check "the lists are read again, and the box is measured" "1 1" \
    "$(fake_log | /usr/bin/grep -c '^status ') $(fake_log | /usr/bin/grep -c '^box info s3 ')"
check "nothing is changed"       "" "$(changes)"

section "an image"
: > "$FAKE_AGENTVM_DIR/log"
url agentvm://image/dev-acp
check "the Images tab is shown"  "1" "$(ui_value "$MAIN_STATUS_ID")"
check "the image is the selection, and its pane is painted" "dev-acp|dev-acp" \
    "$("$PB" "agentvm_image_$UUID" get)|$(ui_value "$MAIN_IMAGE_NAME_ID")"
check "  the box selected before stays selected in its own list" "s3" "$("$PB" "agentvm_box_$UUID" get)"
check "the image is measured"    "1" "$(fake_log | /usr/bin/grep -c '^image info dev-acp ')"
check "nothing is changed"       "" "$(changes)"

section "status"
ui_reset
url agentvm://status
check "the window comes to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
check "  the tab is left as it is" "" "$(ui_value "$MAIN_STATUS_ID")"
check "  and so are the selections" "s3|dev-acp" "$("$PB" "agentvm_box_$UUID" get)|$("$PB" "agentvm_image_$UUID" get)"

section "a box made a moment ago"
store '.boxes += [.boxes[] | select(.box.name == "try1") | .box.name = "fresh"]'
url agentvm://box/fresh
check "is found: the lists are read first" "fresh" "$("$PB" "agentvm_box_$UUID" get)"
store '.'
url agentvm://box/s3

section "a name the lists do not hold"
alerts_reset
ui_reset
url agentvm://box/gone
check "says so"                  "There is no box named gone" "$(ui_alert_title)"
check "  shows the Boxes tab"    "0" "$(ui_value "$MAIN_STATUS_ID")"
check "  and keeps the selection" "s3" "$("$PB" "agentvm_box_$UUID" get)"
alerts_reset
url agentvm://image/gone
check "an image the same"        "There is no image named gone" "$(ui_alert_title)"

section "status fails: a name not found is not said to be missing"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
alerts_reset
ui_reset
url agentvm://box/fresh
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
check "no alert: the window's note says what failed" "|the store is locked" "$(ui_alert_title)|$(ui_value "$MAIN_BOXES_NOTE_ID")"
url agentvm://status

section "a URL the app does not route"
alerts_reset
ui_reset
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
url 'agentvm://box/-rf'
url 'agentvm://new-image?for=cadabra'
url 'agentvm://delete/s3'
url 'https://example.com/box/s3'
url ''
check "does nothing: no window, no alert, no agent-vm" "0|0||" \
    "$(ui_calls "omc_window")|$(chain_asked AgentVM.main)|$(ui_alert_title)|$(fake_log)"

section "Get started has no lists to select in"
store '.boxes = [] | .images = []'
omc_run AgentVM.main.activated
alerts_reset
ui_reset
url agentvm://box/s3
check "the window comes to the front, and that is all" "1||" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")|$(ui_value "$MAIN_STATUS_ID")|$(ui_alert_title)"
store '.'
omc_run AgentVM.main.activated

# -----------------------------------------------------------------------------------------------
section "the main window closed: a URL opens one"
omc_run AgentVM.main.close
check "the closed window is no longer the main window" "" "$(main_entry)"
chains_reset
ui_reset
: > "$FAKE_SLEEP_LOG"
: > "$FAKE_AGENTVM_DIR/log"
url agentvm://box/cadabra-spike
check "waits briefly for one that may be opening" "5" "$(/usr/bin/awk 'END { print NR }' "$FAKE_SLEEP_LOG")"
check "then asks for the main window" "1" "$(chain_asked AgentVM.main)"
check "  with what to show waiting" "$APP_PID box cadabra-spike" "$(waiting)"
check "  and reads nothing itself" "" "$(fake_log)"
omc_control_defaults AgentVM
omc_run AgentVM.main.init
check "the new window takes it, once" "" "$(waiting)"
check "  and shows the box"      "0|cadabra-spike|cadabra-spike" \
    "$(ui_value "$MAIN_STATUS_ID")|$("$PB" "agentvm_box_$UUID" get)|$(ui_value "$MAIN_BOX_NAME_ID")"

section "a main window that appears while the handler waits"
omc_run AgentVM.main.close
chains_reset
# The wait, here, is the moment the window opening at launch names itself.
/bin/cat > "$OMCTEST_WORK/sleep_then_window.sh" <<EOF
#!/bin/sh
"$PB" agentvm_window_main_window set "$APP_PID $UUID"
"$PB" "agentvm_poll_$UUID" set ""
exit 0
EOF
/bin/chmod +x "$OMCTEST_WORK/sleep_then_window.sh"
( AGENTVM_APP_SLEEP="$OMCTEST_WORK/sleep_then_window.sh"; export AGENTVM_APP_SLEEP; url agentvm://image/dev-node )
check "is used: no second window" "0|" "$(chain_asked AgentVM.main)|$(waiting)"
check "  and it shows the image" "dev-node" "$("$PB" "agentvm_image_$UUID" get)"

section "what another run of the app left"
omc_run AgentVM.main.close
"$PB" agentvm_window_main_window set "1 $UUID"
chains_reset
url agentvm://status
check "an entry of another run is not a window: one is opened" "1" "$(chain_asked AgentVM.main)"
"$PB" agentvm_window_main_window set ""
"$PB" agentvm_goto set "1 box s3"
omc_control_defaults AgentVM
omc_run AgentVM.main.init
check "a target another run left is not shown" "|" "$("$PB" "agentvm_box_$UUID" get)|$(waiting)"
omc_run AgentVM.main.close
"$PB" agentvm_goto set "$APP_PID box -rf"
omc_control_defaults AgentVM
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.init
check "nor one whose name agent-vm would refuse" "|0" "$("$PB" "agentvm_box_$UUID" get)|$(fake_log | /usr/bin/grep -c -e '-rf')"

"$PB" agentvm_goto set "$APP_PID box -rf"
check "  the target is refused as it is read" "" "$(ui ui_goto_take)"
"$PB" agentvm_goto set "$APP_PID image dev-acp"
check "  a good one is read, once" "image dev-acp|" "$(ui ui_goto_take)|$(ui ui_goto_take)"

section "the newest main window is the one a URL goes to"
OTHER_UUID="OMCTEST-other-main-window-$$"
( OMC_ACTIONUI_WINDOW_UUID="$OTHER_UUID"; ACTIONUI_WINDOW_UUID="$OTHER_UUID"; export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
  omc_control_defaults AgentVM
  omc_run AgentVM.main.init )
check "a second main window takes the entry" "$APP_PID $OTHER_UUID" "$(main_entry)"
omc_run AgentVM.main.close
check "closing the first leaves the second the main window" "$APP_PID $OTHER_UUID" "$(main_entry)"
( OMC_ACTIONUI_WINDOW_UUID="$OTHER_UUID"; ACTIONUI_WINDOW_UUID="$OTHER_UUID"; export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
  omc_run AgentVM.main.close )
check "closing the second leaves none" "" "$(main_entry)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
