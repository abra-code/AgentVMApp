#!/bin/sh
# Tests/32-box-network.test.sh - a box's network window: how it opens (Details... on the box pane's
# Network row), one window per box, the Settings tab (the rules read and edited: packs, public,
# other hosts, the mode; applied in one call; Discard), the Activity tab (the connections grouped
# per host, Allow Selected Host with its question), and when the window reads.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (s3 running,
# cadabra-spike stopped), the rules from fixtures/agentvm/box-network.json for any box (a change
# is kept per box in the fake's state folder), the packs from packs.json, and the connections from
# the hand-made box-netlog.json.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.network.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_NETWORK_DETAILS_ID" ] && [ -n "$NET_PACKS_ID" ] \
    && [ -n "$NET_CONNECTIONS_ID" ] && [ -n "$NET_APPLY_ID" ] && [ -n "$NET_MODE_ID" ] || {
    printf '32-box-network: no view ids imported from lib.agentvm.main.sh and lib.agentvm.network.sh\n' >&2
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
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
# The app's pid, as the engine exports it: every window entry and open request carries it.
APP_PID="${OMC_APP_PROCESS_ID:?32-box-network: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-network-window-$$"
OTHER_UUID="OMCTEST-other-network-window-$$"

# in_window <uuid>  ->  the handlers that follow run in that window.
in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# request  ->  the open request a Details... left for the window it chained.
request() {
    "$PB" agentvm_open_request_network get
}

# registered <box>  ->  the pasteboard entry naming that box's network window: "<app pid> <uuid>".
registered() {
    "$PB" "agentvm_window_network_$1" get
}

# open_main  ->  the main window, freshly opened.
open_main() {
    in_window "$MAIN_UUID"
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

# open_network <box> [uuid]  ->  that box's network window opened the way Details... opens it: the
# request, then the window's init handler, in a window of its own.
open_network() {
    "$PB" agentvm_open_request_network set "$APP_PID network:$1"
    in_window "${2:-$UUID}"
    omc_control_defaults AgentVM.network
    omc_run AgentVM.network.init
}

# pack <name>  ->  a click on that pack's cell: the grid reports the row's 0-based index.
pack() {
    omc_trigger "$NET_PACKS_ID" "$(/usr/bin/jq --arg n "$1" 'map(.name) | index($n)' "$FIXTURES_AGENTVM/packs.json")"
    omc_run AgentVM.network.pack
}

# mode <index>  ->  the mode picker set (1 allowlist, 2 off, 3 open).
mode() {
    omc_control "$NET_MODE_ID" "$1"
    omc_trigger "$NET_MODE_ID"
    omc_run AgentVM.network.mode
}

# connection <host>  ->  the connections table's row of that host selected, its columns exported.
connection() {
    local _row="$(ui_rows "$NET_CONNECTIONS_ID" | row_named "$1" | /usr/bin/sed -n '1p')"
    local _c
    for _c in 1 2 3 4 5 6 7; do
        omc_table_cell "$NET_CONNECTIONS_ID" "$_c" "$(printf '%s\n' "$_row" | /usr/bin/cut -f"$_c")"
    done
    omc_trigger "$NET_CONNECTIONS_ID"
    omc_run AgentVM.network.connection.selected
}

# cell <name>  ->  the pack's cell: its symbol and color.
cell() {
    ui_rows "$NET_PACKS_ID" | /usr/bin/awk -F'\t' -v n="$1" '$2 == n { print $1 " " $4 }'
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

clear_alerts() {
    alerts_reset
    ui_reset
}

ALLOWLIST_TEXT="Only what the packs and hosts below allow."
RUNNING_TEXT="The mode changes only while the box is stopped."

fake_reset
store '.'
"$PB" agentvm_window_network_s3 set ""
"$PB" agentvm_window_network_cadabra-spike set ""
"$PB" agentvm_open_request_network set ""

# -----------------------------------------------------------------------------------------------
section "Details... on the box pane's Network row"
open_main
select_box s3
check "selecting a box reads no network" "0" "$(fake_log | /usr/bin/grep -c -e '^box network' -e '^box netlog' -e '^box packs')"
chains_reset
omc_trigger "$MAIN_BOX_NETWORK_DETAILS_ID"
omc_run AgentVM.main.box.network
check "asks for a network window" "1" "$(chain_asked AgentVM.network)"
check "  for the selected box, from this run of the app" "$APP_PID network:s3" "$(request)"
"$PB" agentvm_open_request_network set ""
chains_reset
( OMC_ACTIONUI_TABLE_311_COLUMN_1_VALUE=""; export OMC_ACTIONUI_TABLE_311_COLUMN_1_VALUE; omc_run AgentVM.main.box.selected )
omc_run AgentVM.main.box.network
check "no box selected: opens nothing" "0|" "$(chain_asked AgentVM.network)|$(request)"
select_box s3

section "the window opens: the Settings tab"
: > "$FAKE_AGENTVM_DIR/log"
open_network s3
check_status "the init handler exits cleanly" 0
check "takes the request, once"  "" "$(request)"
check "becomes the box's network window" "$APP_PID $UUID" "$(registered s3)"
check "the title names the box"  "Network of box s3" "$(ui_title)"
check "reads the box's state, the packs, the rules and the last connections" \
    "status --json|box packs --json|box network s3 --json|box netlog s3 --last 200 --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "a cell per pack"          "$(/usr/bin/jq length "$FIXTURES_AGENTVM/packs.json")" "$(ui_row_count "$NET_PACKS_ID")"
check "  the box's packs ticked" "checkmark.square.fill primary|checkmark.square.fill primary" "$(cell npm)|$(cell anthropic)"
check "  the others not"         "square primary" "$(cell github)"
check "  each with its description as help" \
    "$(/usr/bin/jq -r '.[] | select(.name == "github") | .description' "$FIXTURES_AGENTVM/packs.json")" \
    "$(ui_rows "$NET_PACKS_ID" | /usr/bin/awk -F'\t' '$2 == "github" { print $3 }')"
check "public not allowed"       "square" "$(ui_prop "$NET_PUBLIC_SYMBOL_ID" systemName)"
check "the other hosts, in agent-vm's order" "opencode.ai|models.opencode.ai|html.duckduckgo.com" \
    "$(ui_rows "$NET_HOSTS_ID" | col 1 | /usr/bin/paste -sd '|' -)"
check "nothing to apply"         "|0 0" "$(ui_value "$NET_CHANGES_ID")|$(enabled "$NET_APPLY_ID") $(enabled "$NET_DISCARD_ID")"
check "the mode: allowlist"      "1" "$(ui_value "$NET_MODE_ID")"
check "  what it lets through, and not changeable while the box runs" "0|$ALLOWLIST_TEXT $RUNNING_TEXT" \
    "$(enabled "$NET_MODE_ID")|$(ui_value "$NET_MODE_NOTE_ID")"

section "the Activity tab"
check "the connections, one row per host, port and result, refused first" \
    "registry.yarnpkg.com 443 refused 3|raw.example.org 80 refused 1|plain.example.org 80 refused 1|203.0.113.9 443 refused 1|models.example.dev 443 failed 1|api.anthropic.com 443 reached 2|registry.npmjs.org 443 reached 1" \
    "$(ui_rows "$NET_CONNECTIONS_ID" | /usr/bin/awk -F'\t' '{ print $1 " " $2 " " $3 " " $4 }' | /usr/bin/paste -sd '|' -)"
check "  with what the tab says about them" "The last 200 connections, one row per host, port and result." \
    "$(ui_value "$NET_NOTE_ID")"
check "Allow Selected Host is off until a row is selected" "0" "$(enabled "$NET_ALLOW_ID")"

# -----------------------------------------------------------------------------------------------
section "a second Details... on the same box"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.box.network
check "opens no second window"   "0" "$(chain_asked AgentVM.network)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
check "  leaving no request"     "" "$(request)"

section "an entry an earlier run of the app left (it quit without closing the window)"
"$PB" agentvm_window_network_s3 set "1 $UUID"
chains_reset
omc_run AgentVM.main.box.network
check "is not a window: a new one is asked for" "1" "$(chain_asked AgentVM.network)"
"$PB" agentvm_window_network_s3 set "$APP_PID $UUID"
"$PB" agentvm_open_request_network set ""

section "two windows asked for the same box before either opened"
fronted="$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select" "$UUID")"
open_network s3 "$OTHER_UUID"
check_status "the second init exits cleanly" 0
check "the first stays the box's window" "$APP_PID $UUID" "$(registered s3)"
check "  and comes to the front" "$((fronted + 1))" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select" "$UUID")"
check "  and the second closes"  "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"

section "a window opened with no request of this run (a URL naming the command)"
ui_reset
omc_control_defaults AgentVM.network
omc_run AgentVM.network.init
check "closes"                   "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  saying why, in case it stays" "No box was named for this window." "$(ui_value "$NET_MODE_NOTE_ID")"
ui_reset
# For a box with no window yet: the box's open window would close the new one whatever the request.
"$PB" agentvm_open_request_network set "1 network:cadabra-spike"
omc_run AgentVM.network.init
check "a request another run left: closes too, and takes no box" "1|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(registered cadabra-spike)"
check "  and the request is gone" "" "$(request)"
ui_reset
"$PB" agentvm_open_request_network set "$APP_PID programs:s3"
omc_run AgentVM.network.init
check "a request for another kind of window is not this one's" "1|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$("$PB" "agentvm_box_$OTHER_UUID" get)"
ui_reset
"$PB" agentvm_open_request_network set "$APP_PID network:-rf"
omc_run AgentVM.network.init
check "  nor one whose name agent-vm would refuse" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
ui_reset
"$PB" agentvm_open_request_network set " network:cadabra-spike"
( OMC_APP_PROCESS_ID=""; export OMC_APP_PROCESS_ID; omc_run AgentVM.network.init )
check "  nor any request, to a handler without the app's pid" "1|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(registered cadabra-spike)"
"$PB" agentvm_open_request_programs set "$APP_PID programs:s3"
"$PB" agentvm_open_request_network set "$APP_PID network:cadabra-spike"
omc_run AgentVM.network.init
check "a request for a programs window, waiting: a network window opening leaves it" "$APP_PID programs:s3" "$("$PB" agentvm_open_request_programs get)"
omc_run AgentVM.network.close
"$PB" agentvm_open_request_programs set ""
in_window "$UUID"

# -----------------------------------------------------------------------------------------------
section "editing: a pack, public, a host added and one removed"
: > "$FAKE_AGENTVM_DIR/log"
pack github
check "a click ticks the pack, in orange: not applied yet" "checkmark.square.fill orange" "$(cell github)"
check "  says so"                "Not applied yet: allow pack:github." "$(ui_value "$NET_CHANGES_ID")"
check "  Apply and Discard on"   "1 1" "$(enabled "$NET_APPLY_ID") $(enabled "$NET_DISCARD_ID")"
pack github
check "a second click puts it back" "square primary|" "$(cell github)|$(ui_value "$NET_CHANGES_ID")"
pack npm
check "a ticked pack unticked"   "square orange" "$(cell npm)"
pack github
omc_run AgentVM.network.public
check "public ticked, in orange" "checkmark.square.fill orange" \
    "$(ui_prop "$NET_PUBLIC_SYMBOL_ID" systemName) $(ui_prop "$NET_PUBLIC_SYMBOL_ID" foregroundStyle)"
omc_control "$NET_HOST_FIELD_ID" "  Example.COM. "
omc_run AgentVM.network.add
check "a host typed (pasted with spaces): added as agent-vm reads it, marked" "example.com${TAB}not applied yet" \
    "$(ui_rows "$NET_HOSTS_ID" | row_named example.com)"
check "  and the field emptied"  "" "$(ui_value "$NET_HOST_FIELD_ID")"
clear_alerts
omc_control "$NET_HOST_FIELD_ID" "-rf"
omc_run AgentVM.network.add
check "text that is not a rule: refused, saying what is" "\"-rf\" is not a network rule" "$(ui_alert_title)"
check "  nothing added"          "" "$(ui_rows "$NET_HOSTS_ID" | row_named -rf)"
omc_table_cell "$NET_HOSTS_ID" 1 opencode.ai
omc_trigger "$NET_HOSTS_ID"
omc_run AgentVM.network.host.selected
check "a host selected: Remove on" "1" "$(enabled "$NET_REMOVE_ID")"
omc_run AgentVM.network.remove
check "  removed from the list"  "" "$(ui_rows "$NET_HOSTS_ID" | row_named opencode.ai)"
check "  Remove off again"       "0" "$(enabled "$NET_REMOVE_ID")"
check "what is not applied, in one line" \
    "Not applied yet: allow pack:github, public and example.com; remove pack:npm and opencode.ai." "$(ui_value "$NET_CHANGES_ID")"
check "no edit reached agent-vm" "" "$(fake_log)"

section "edits survive Refresh, and each box has a window of its own"
omc_run AgentVM.network.refresh
check "Refresh reads again"      "status --json|box network s3 --json|box netlog s3 --last 200 --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the edits stay"         "checkmark.square.fill orange" "$(cell github)"
open_network cadabra-spike "$OTHER_UUID"
check "another box: its own window" "$APP_PID $OTHER_UUID|Network of box cadabra-spike" "$(registered cadabra-spike)|$(ui_title)"
check "  its own rules, no edits" "square primary|" "$(cell github)|$(ui_value "$NET_CHANGES_ID")"
in_window "$UUID"
omc_run AgentVM.network.activated
check "back in the first: the edits are still there" "checkmark.square.fill orange" "$(cell github)"

section "Apply Rules: one call"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.apply
check_status "exits cleanly" 0
check "the box's state read, the additions and removals in one call, then the rules read again" \
    "status --json|box network s3 --allow pack:github --allow public --allow example.com --disallow pack:npm --disallow opencode.ai --json|box network s3 --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "nothing left to apply"    "|0" "$(ui_value "$NET_CHANGES_ID")|$(enabled "$NET_APPLY_ID")"
check "  github applies now"     "checkmark.square.fill primary" "$(cell github)"
check "  example.com too, no longer marked" "example.com${TAB}" "$(ui_rows "$NET_HOSTS_ID" | row_named example.com)"

section "Apply Rules: agent-vm refuses"
pack homebrew
printf 'no such pack: homebrew\n' > "$FAKE_AGENTVM_DIR/fail-box-network"
clear_alerts
omc_run AgentVM.network.apply
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-network"
check "the reason is shown"      "The rules of box s3 were not changed|no such pack: homebrew" "$(ui_alert_title)|$(ui_alert_message)"
omc_run AgentVM.network.refresh
check "  the edit stays, to fix or discard" "Not applied yet: allow pack:homebrew." "$(ui_value "$NET_CHANGES_ID")"
omc_run AgentVM.network.discard
check "Discard Changes: back to what applies" "square primary|" "$(cell homebrew)|$(ui_value "$NET_CHANGES_ID")"

section "an edit undone by hand is no edit: a change made elsewhere shows up"
pack anthropic
pack anthropic
check "a ticked pack unticked and ticked again: nothing to apply" "checkmark.square.fill primary|" \
    "$(cell anthropic)|$(ui_value "$NET_CHANGES_ID")"
rules="$FAKE_AGENTVM_DIR/box-network-s3.json"
/usr/bin/jq '.allow += ["terminal.example.com"]' "$rules" > "$rules.new" && /bin/mv "$rules.new" "$rules"
omc_run AgentVM.network.refresh
check "  a rule added in Terminal meanwhile: listed, applied" "terminal.example.com${TAB}" \
    "$(ui_rows "$NET_HOSTS_ID" | row_named terminal.example.com)"
check "  and not offered for removal" "" "$(ui_value "$NET_CHANGES_ID")"
pack pypi
/usr/bin/jq '.allow += ["other.example.com"]' "$rules" > "$rules.new" && /bin/mv "$rules.new" "$rules"
omc_run AgentVM.network.refresh
check "with an edit of its own: the edit replayed onto the new rules, the other change kept" \
    "Not applied yet: allow pack:pypi.|other.example.com${TAB}" "$(ui_value "$NET_CHANGES_ID")|$(ui_rows "$NET_HOSTS_ID" | row_named other.example.com)"
omc_run AgentVM.network.discard
/usr/bin/jq '.allow -= ["other.example.com"]' "$rules" > "$rules.new" && /bin/mv "$rules.new" "$rules"
/usr/bin/jq '.allow -= ["terminal.example.com"]' "$rules" > "$rules.new" && /bin/mv "$rules.new" "$rules"
omc_run AgentVM.network.refresh

# -----------------------------------------------------------------------------------------------
section "the mode, while the box runs and while it is stopped"
: > "$FAKE_AGENTVM_DIR/log"
mode 2
check "a running box: the change is put back" "1|" "$(ui_value "$NET_MODE_ID")|$(ui_value "$NET_CHANGES_ID")"
in_window "$OTHER_UUID"
omc_run AgentVM.network.activated
check "a stopped box: the picker on, and what the mode lets through" "1|$ALLOWLIST_TEXT" "$(enabled "$NET_MODE_ID")|$(ui_value "$NET_MODE_NOTE_ID")"
mode 2
check "  off wanted"             "Not applied yet: mode off." "$(ui_value "$NET_CHANGES_ID")"
check "  and what off means"     "No network: every connection is refused, whatever the rules say." "$(ui_value "$NET_MODE_NOTE_ID")"
ui_reset
mode 2
check "the app's own setting of the picker (the value wanted): nothing painted" "0" "$(ui_calls "$NET_CHANGES_ID")"
omc_run AgentVM.network.apply
check "Apply: --net"             "1" "$(fake_log | /usr/bin/grep -c -x 'box network cadabra-spike --net off --json')"
check "  the picker on Off"      "2" "$(ui_value "$NET_MODE_ID")"
store '(.boxes[] | select(.box.name == "cadabra-spike")).state = "running"'
omc_run AgentVM.network.activated
check "the box started meanwhile: coming back to the window turns the picker off" \
    "0|No network: every connection is refused, whatever the rules say. $RUNNING_TEXT" \
    "$(enabled "$NET_MODE_ID")|$(ui_value "$NET_MODE_NOTE_ID")"
store '.'
omc_run AgentVM.network.activated
mode 3
check "open wanted, and what open means" \
    "Not applied yet: mode open.|Any host but this Mac and your local network; the rules are kept for later." \
    "$(ui_value "$NET_CHANGES_ID")|$(ui_value "$NET_MODE_NOTE_ID")"
pack homebrew
# The box starts, and the window is not told: Apply reads the box's state itself.
store '(.boxes[] | select(.box.name == "cadabra-spike")).state = "running"'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.apply
check "a mode picked, then the box started: Apply sends the rule, not the mode" "box network cadabra-spike --allow pack:homebrew --json" \
    "$(fake_log | /usr/bin/grep -e --allow -e --net)"
check "  the mode still waits, with nothing Apply can send" "Not applied yet: mode open.|0" \
    "$(ui_value "$NET_CHANGES_ID")|$(enabled "$NET_APPLY_ID")"
check "  and the picker is off"  "0" "$(enabled "$NET_MODE_ID")"
omc_run AgentVM.network.discard
store '.'
omc_run AgentVM.network.activated
in_window "$UUID"

# -----------------------------------------------------------------------------------------------
section "the connections: which rows can be allowed"
omc_run AgentVM.network.activated
connection registry.yarnpkg.com
check "a refused host: Allow on" "1" "$(enabled "$NET_ALLOW_ID")"
connection raw.example.org
check "a raw tunnel to port 80: no rule, Allow off" "0" "$(enabled "$NET_ALLOW_ID")"
connection 203.0.113.9
check "an address: off"          "0" "$(enabled "$NET_ALLOW_ID")"
connection api.anthropic.com
check "a host reached: off"      "0" "$(enabled "$NET_ALLOW_ID")"
connection plain.example.org
omc_table_cell "$NET_CONNECTIONS_ID" 6 "evil.example.net"
omc_trigger "$NET_CONNECTIONS_ID"
omc_run AgentVM.network.connection.selected
check "a rule that is not the row's host: off" "0" "$(enabled "$NET_ALLOW_ID")"
for m in open off; do
    /usr/bin/jq --arg m "$m" '.mode = $m' "$FIXTURES_AGENTVM/box-network.json" > "$FAKE_AGENTVM_DIR/box-network-s3.json"
    omc_run AgentVM.network.refresh
    connection registry.yarnpkg.com
    check "mode $m: no rule lets a refused host through, Allow off" "0" "$(enabled "$NET_ALLOW_ID")"
done
/bin/rm -f "$FAKE_AGENTVM_DIR/box-network-s3.json"
omc_run AgentVM.network.refresh

section "Allow Selected Host: the question, then at once"
connection registry.yarnpkg.com
clear_alerts
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.allow
check "asks"                     "Allow registry.yarnpkg.com in box s3?" "$(ui_alert_title)"
check "  Allow confirms"         "AgentVM.network.allow.confirmed" "$(ui_alert_action Allow)"
check "  nothing allowed yet"    "" "$(fake_log)"
pack swiftpm
omc_run AgentVM.network.allow.confirmed
check "the rule added at once, then read again" "box network s3 --allow registry.yarnpkg.com --json|box network s3 --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  listed, applied"        "registry.yarnpkg.com${TAB}" "$(ui_rows "$NET_HOSTS_ID" | row_named registry.yarnpkg.com)"
check "  the other edit stays"   "Not applied yet: allow pack:swiftpm." "$(ui_value "$NET_CHANGES_ID")"
check "  and the note says what it did" \
    "Allowed registry.yarnpkg.com. Its next connection gets through; earlier refusals stay listed until Refresh." "$(ui_value "$NET_NOTE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.allow.confirmed
check "a second confirmation allows nothing" "" "$(fake_log)"
omc_run AgentVM.network.discard
connection plain.example.org
omc_run AgentVM.network.allow
printf 'the box s3 is gone\n' > "$FAKE_AGENTVM_DIR/fail-box-network"
clear_alerts
omc_run AgentVM.network.allow.confirmed
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-network"
check "a refusal is shown"       "plain.example.org was not allowed in box s3|the box s3 is gone" "$(ui_alert_title)|$(ui_alert_message)"
"$PB" "agentvm_net_allow_$UUID" set "-rf github.com"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.allow.confirmed
check "a pending box name agent-vm would refuse is not passed on" "" "$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "a wildcard rule reaches agent-vm as typed, whatever files are around"
# Handlers run in $OMCTEST_WORK; a file there that the pattern matches would replace a rule
# word-split unquoted (the change is the word "+*.example.com").
: > "$OMCTEST_WORK/+a.example.com"
omc_control "$NET_HOST_FIELD_ID" "*.example.com"
omc_run AgentVM.network.add
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.apply
/bin/rm -f "$OMCTEST_WORK/+a.example.com"
check "--allow *.example.com, not the file +a.example.com" "1" "$(fake_log | /usr/bin/grep -c -x 'box network s3 --allow \*.example.com --json')"

section "a log agent-vm cannot read, and rules it cannot read"
printf 'the log is unreadable\n' > "$FAKE_AGENTVM_DIR/fail-box-netlog"
omc_run AgentVM.network.refresh
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-netlog"
check "the Activity tab says why" "the log is unreadable" "$(ui_value "$NET_NOTE_ID")"
check "  the Settings tab does not: the rules are still shown" "$ALLOWLIST_TEXT $RUNNING_TEXT|checkmark.square.fill primary" \
    "$(ui_value "$NET_MODE_NOTE_ID")|$(cell anthropic)"
printf '[]\n' > "$FAKE_AGENTVM_DIR/box-netlog-s3.json"
omc_run AgentVM.network.refresh
check "an empty log says so"     "No connections logged yet. A connection is logged when it ends, so one still open shows up when it closes." \
    "$(ui_value "$NET_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/box-netlog-s3.json"
printf 'the rules are unreadable\n' > "$FAKE_AGENTVM_DIR/fail-box-network"
omc_run AgentVM.network.refresh
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-network"
check "rules that cannot be read: the Settings tab says why, the Activity tab does not" \
    "the rules are unreadable|The last 200 connections, one row per host, port and result." \
    "$(ui_value "$NET_MODE_NOTE_ID")|$(ui_value "$NET_NOTE_ID")"
check "  the rules last read stay" "checkmark.square.fill primary" "$(cell anthropic)"

section "activation reads the window again"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.activated
check "the box's state, its rules and its connections" "status --json|box network s3 --json|box netlog s3 --last 200 --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the error is gone"      "$ALLOWLIST_TEXT $RUNNING_TEXT" "$(ui_value "$NET_MODE_NOTE_ID")"

section "status fails while the window is open"
pack github
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.activated
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
check_status "exits cleanly" 0
check "both tabs say why"        "the store is locked|the store is locked" "$(ui_value "$NET_MODE_NOTE_ID")|$(ui_value "$NET_NOTE_ID")"
check "  nothing more is read"   "0" "$(fake_log | /usr/bin/grep -c '^box ')"
check "  nothing can be changed" "0000000" \
    "$(enabled "$NET_MODE_ID")$(enabled "$NET_PUBLIC_ID")$(enabled "$NET_ADD_ID")$(enabled "$NET_REMOVE_ID")$(enabled "$NET_DISCARD_ID")$(enabled "$NET_APPLY_ID")$(enabled "$NET_ALLOW_ID")"
omc_run AgentVM.network.activated
check "status answers again: the edit made before is still there" "Not applied yet: allow pack:github." "$(ui_value "$NET_CHANGES_ID")"
omc_run AgentVM.network.discard

section "the box deleted elsewhere while its window is open"
# An edit is waiting: without one Apply has nothing to send whatever the box's fate.
pack github
store 'del(.boxes[] | select(.box.name == "s3"))'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.network.activated
check "both tabs say so"         "Box s3 no longer exists.|Box s3 no longer exists." "$(ui_value "$NET_MODE_NOTE_ID")|$(ui_value "$NET_NOTE_ID")"
check "  nothing of it is shown" "0 0 0" "$(ui_row_count "$NET_PACKS_ID") $(ui_row_count "$NET_HOSTS_ID") $(ui_row_count "$NET_CONNECTIONS_ID")"
check "  and nothing of it is read" "0" "$(fake_log | /usr/bin/grep -c '^box ')"
omc_run AgentVM.network.apply
check "Apply sends nothing"      "0" "$(fake_log | /usr/bin/grep -c -e --allow -e --disallow -e --net)"
store '.'
omc_run AgentVM.network.activated
check "the box is back: the edit is still there" "Not applied yet: allow pack:github." "$(ui_value "$NET_CHANGES_ID")"
omc_run AgentVM.network.discard

section "deleting a box in the main window closes its network window"
in_window "$MAIN_UUID"
select_box cadabra-spike
"$PB" "agentvm_box_delete_$MAIN_UUID" set cadabra-spike
omc_run AgentVM.main.box.delete.confirmed
check "the deleted box's window is closed" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel" "$OTHER_UUID")"
check "  the other box's is not" "0" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel" "$UUID")"
in_window "$OTHER_UUID"
omc_run AgentVM.network.close
check "  its close handler leaves the box without a window" "" "$(registered cadabra-spike)"
in_window "$UUID"

section "closing"
"$PB" "agentvm_net_allow_$UUID" set "s3 github.com"
cache="$TMPDIR/AgentVM/$UUID"
check "the window has a cache"   "yes" "$([ -d "$cache" ] && echo yes)"
omc_run AgentVM.network.close
check "the box has no network window" "" "$(registered s3)"
check "  the window forgets its box and its pending allow" "|" "$("$PB" "agentvm_box_$UUID" get)|$("$PB" "agentvm_net_allow_$UUID" get)"
check "  and its cache is gone"  "no" "$([ -d "$cache" ] && echo yes || echo no)"
"$PB" agentvm_window_network_s3 set "$APP_PID $OTHER_UUID"
"$PB" "agentvm_box_$UUID" set s3
omc_run AgentVM.network.close
check "a window that was not the box's leaves the entry alone" "$APP_PID $OTHER_UUID" "$(registered s3)"
"$PB" agentvm_window_network_s3 set ""

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
