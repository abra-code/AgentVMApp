#!/bin/sh
# Tests/68-exclusions.test.sh - snapshot exclusions: the Exclusions row of the Sessions tab's
# project pane, and the Exclusions window. The window opens only when this run of the app asked
# for it, one at a time, from Choose...; it scans the project (rows, sizes, why, ticked as saved
# or as suggested), keeps the ticks, says when a ticked folder may hold work, saves (one
# call with every path, the main window's row follows, the window closes), and shows
# agent-vm's refusal and a failed scan.
#
# agent-vm is the fake: the sessions of status-sessions.json and session-list.json, the scan of
# session-scan.json and the lists of session-exclusions.json (fixtures/agentvm, part exclusions).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.sessions.sh" "$APP_SCRIPTS/lib.agentvm.exclusions.sh"
[ -n "$SES_EXCLUSIONS_ID" ] && [ -n "$SES_EXCLUSIONS_CHOOSE_ID" ] && [ -n "$SES_ADD_ID" ] && [ -n "$SES_PROJECTS_ID" ] \
    && [ -n "$EXCL_HEAD_ID" ] && [ -n "$EXCL_PATH_ID" ] && [ -n "$EXCL_TABLE_ID" ] && [ -n "$EXCL_STATE_ID" ] && [ -n "$EXCL_WARN_ID" ] \
    && [ -n "$EXCL_NOTES_ID" ] && [ -n "$EXCL_SAVE_ID" ] && [ -n "$EXCL_ADD_ID" ] && [ -n "$EXCL_PROJECT_ID" ] && [ -n "$MAIN_STATUS_ID" ] || {
    printf '68-exclusions: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?68-exclusions: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-exclusions-$$"
OTHER_UUID="OMCTEST-other-exclusions-$$"
TAB="$(printf '\t')"
PROJECT="/Users/you/src/myapp"
MEASURED="$(/usr/bin/jq -r '.sessions.measuredAt' "$FIXTURES_AGENTVM/status-sessions.json")"
MEASURED_SECONDS="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" +%s)"
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

request()    { "$PB" agentvm_open_request_exclusions get; }
handed()     { "$PB" agentvm_exclusions_of get; }
registered() { "$PB" agentvm_window_exclusions_window get; }
project_of() { "$PB" "agentvm_exclusions_$1" get; }
closed()     { ui_calls "${1}${TAB}omc_window${TAB}omc_terminate_cancel"; }
scans()      { fake_log | /usr/bin/grep -c '^session scan '; }
saves()      { fake_log | /usr/bin/grep '^session exclusions --project=' | /usr/bin/paste -sd '|' -; }
rows()       { ui_rows "$EXCL_TABLE_ID" | col 1-4 | /usr/bin/paste -sd '|' -; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# open_main  ->  a fresh main window, the Sessions tab opened, the project selected; the fake
# answers the sessions fixtures and, unless the test left one, no saved list.
open_main() {
    in_window "$MAIN_UUID"
    omc_run AgentVM.main.close
    /usr/bin/jq --slurpfile s "$FIXTURES_AGENTVM/status-sessions.json" '.sessions = $s[0].sessions' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
    omc_trigger "$MAIN_STATUS_ID" "" 2
    omc_run AgentVM.main.tab
    omc_table_cell "$SES_PROJECTS_ID" 1 "$PROJECT"
    omc_trigger "$SES_PROJECTS_ID"
    omc_run AgentVM.main.session.project.selected
}

# open_window <project> [uuid]  ->  the window opened the way Choose... opens it: the request and
# the project, then the window's init handler, in a window of its own.
open_window() {
    "$PB" agentvm_open_request_exclusions set "$APP_PID exclusions:window"
    "$PB" agentvm_exclusions_of set "$APP_PID $1"
    in_window "${2:-$UUID}"
    ui_reset
    alerts_reset
    omc_control_defaults AgentVM.exclusions
    omc_run AgentVM.exclusions.init
}

tick() {
    omc_trigger "$EXCL_TABLE_ID" 0 "$1"
    omc_run AgentVM.exclusions.tick
}

no_saved_list() {
    printf '{"projects": []}\n' > "$FAKE_AGENTVM_DIR/session-exclusions.json"
}

fake_reset
no_saved_list
"$PB" agentvm_window_exclusions_window set ""
"$PB" agentvm_open_request_exclusions set ""
"$PB" agentvm_exclusions_of set ""

# -----------------------------------------------------------------------------------------------
section "the project pane's Exclusions row"
open_main
check "the tab reads every project's list with the sessions" "1" "$(fake_log | /usr/bin/grep -c '^session exclusions --json$')"
check "nothing saved: the snapshots take the whole project" "none" "$(ui_value "$SES_EXCLUSIONS_ID")"
check "the row is in the pane's form, with Choose... beside it, which runs its handler" "AgentVM.main.session.exclusions|Choose..." \
    "$(/usr/bin/jq -r --argjson id "$SES_EXCLUSIONS_CHOOSE_ID" '.. | objects | select(.id? == $id) | .properties | "\(.actionID)|\(.title)"' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
check "the project list's toolbar: Add Project... (with its folder panel), then Discard Sessions..." "745,742|AgentVM.main.session.project.add" \
    "$(/usr/bin/jq -r '[.. | objects | select(.id? == 711) | .toolbar[].content | .id] | map(tostring) | join(",")' "$APP_RESOURCES/Base.lproj/AgentVM.json")|$(/usr/bin/jq -r '.. | objects | select(.id? == 745) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
check "  Add Project... asks for a folder first" "1" \
    "$(/usr/bin/jq '[.COMMAND_LIST[]? // .[]? | objects | select(.COMMAND_ID? == "AgentVM.main.session.project.add") | select(.CHOOSE_FOLDER_DIALOG)] | length' "$APP_RESOURCES/Command.json")"
check "the bar under the project list: the folder and Remove at its left; the sort menu and Measure Again at its right" "746,748,Spacer,Menu,741|AgentVM.main.session.reveal|AgentVM.main.session.remove|Toggle:Sort by Date:AgentVM.main.session.sort.date,Toggle:Sort by Size:AgentVM.main.session.sort.size" \
    "$(/usr/bin/jq -r '[.. | objects | select(.type? == "HStack") | select([.children[]?.id?] | index(748)) | [.children[] | (.id // .type) | tostring] | join(",")][0]' "$APP_RESOURCES/Base.lproj/AgentVM.json")|$(/usr/bin/jq -r '.. | objects | select(.id? == 746) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.json")|$(/usr/bin/jq -r '.. | objects | select(.id? == 748) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.json")|$(/usr/bin/jq -r '[.. | objects | select(.type? == "HStack") | select([.children[]?.id?] | index(748)) | .children[] | select(.type == "Menu") | .children[] | "\(.type):\(.properties.title):\(.properties.actionID)"] | join(",")' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
fake_reset
open_main
check "a saved list: its paths" ".build, .swiftpm" "$(ui_value "$SES_EXCLUSIONS_ID")"
printf '{"projects": [{"project": "%s", "paths": ["a", "b", "c", "d", "e"]}]}\n' "$PROJECT" > "$FAKE_AGENTVM_DIR/session-exclusions.json"
open_main
check "  the first three of a long one, and how many more" "a, b, c and 2 more" "$(ui_value "$SES_EXCLUSIONS_ID")"
printf 'cannot read the list\n' > "$FAKE_AGENTVM_DIR/fail-session-exclusions"
open_main
check "  a list agent-vm cannot read: said, and the sessions are still shown" "could not be read|$PROJECT" \
    "$(ui_value "$SES_EXCLUSIONS_ID")|$(ui_rows "$SES_PROJECTS_ID" | col 1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-session-exclusions"
no_saved_list

# -----------------------------------------------------------------------------------------------
section "Choose... asks for the window"
open_main
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.session.exclusions
check "Choose...: the window, with a request of this run and the selected project, and agent-vm asked nothing" \
    "1|$APP_PID exclusions:window|$APP_PID $PROJECT|" "$(chain_asked AgentVM.exclusions)|$(request)|$(handed)|$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "the window opens and looks through the project"
fake_reset
no_saved_list
open_window "$PROJECT"
check_status "the init handler exits cleanly" 0
check "takes the request and the project, once" "|" "$(request)|$(handed)"
check "becomes the Exclusions window, for that project" "$APP_PID $UUID|$PROJECT" "$(registered)|$(project_of "$UUID")"
check "its title and head" "Snapshot Exclusions|Snapshot exclusions for myapp|$PROJECT" \
    "$(ui_title)|$(ui_value "$EXCL_HEAD_ID")|$(ui_value "$EXCL_PATH_ID")"
check "it scanned the project, once" "1|session scan --project=$PROJECT --json" "$(scans)|$(fake_log | /usr/bin/grep '^session scan')"
check "a row per folder, ticked as agent-vm suggests when nothing is saved: its size and why" \
    "true${TAB}.build${TAB}under 1 MB${TAB}build output (Package.swift beside it)|true${TAB}.swiftpm${TAB}under 1 MB${TAB}build output (Package.swift beside it)|false${TAB}node_modules${TAB}under 1 MB${TAB}build output" \
    "$(rows)"
check "the line under it; no warning, no notes; Save on" "2 folders checked.||" \
    "$(ui_value "$EXCL_STATE_ID")|$(ui_value "$EXCL_WARN_ID")|$(ui_value "$EXCL_NOTES_ID")"
check "  Save on" "1" "$(enabled "$EXCL_SAVE_ID")"
check "the window says what leaving out gives up" "1" \
    "$(/usr/bin/jq -r '.. | objects | select(.id? == 5303) | .properties.text' "$APP_RESOURCES/Base.lproj/AgentVM.exclusions.json" | /usr/bin/grep -c 'Changes in left-out folders cannot be undone')"

"$PB" agentvm_open_request_exclusions set "$APP_PID exclusions:window"
"$PB" agentvm_exclusions_of set "$APP_PID /Users/you/src/other"
in_window "$OTHER_UUID"
ui_reset
omc_run AgentVM.exclusions.init
check "a second window while one is open closes, and the first stays the Exclusions window" "$APP_PID $UUID|1|" \
    "$(registered)|$(closed "$OTHER_UUID")|$(project_of "$OTHER_UUID")"
ui_reset
omc_run AgentVM.exclusions.init
check "a window nobody of this run asked for closes" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_exclusions set "$APP_PID exclusions:window"
ui_reset
omc_run AgentVM.exclusions.init
check "  and so does one with no project" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_exclusions set "$APP_PID exclusions:window"
"$PB" agentvm_exclusions_of set "$APP_PID src/myapp"
ui_reset
omc_run AgentVM.exclusions.init
check "  or with a path that is not a full one" "1|" "$(closed "$OTHER_UUID")|$(project_of "$OTHER_UUID")"
"$PB" agentvm_open_request_exclusions set "$APP_PID exclusions:window"
"$PB" agentvm_exclusions_of set "1 $PROJECT"
ui_reset
omc_run AgentVM.exclusions.init
check "  or one another run of the app handed over" "1" "$(closed "$OTHER_UUID")"
"$PB" agentvm_open_request_exclusions set ""
"$PB" agentvm_exclusions_of set ""

section "Choose... while the window is open"
in_window "$MAIN_UUID"
chains_reset
ui_reset
omc_run AgentVM.main.session.exclusions
check "for the same project: the open window comes to the front, and no other is asked for" "0|1" \
    "$(chain_asked AgentVM.exclusions)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select" | /usr/bin/awk 'NF' | /usr/bin/wc -l | /usr/bin/tr -d ' ')"
"$PB" agentvm_open_request_exclusions set ""
"$PB" agentvm_exclusions_of set ""

# -----------------------------------------------------------------------------------------------
section "ticks"
in_window "$UUID"
tick 2
check "node_modules ticked: three, and the rows keep the tick" "true|3 folders checked." \
    "$(ui_rows "$EXCL_TABLE_ID" | /usr/bin/awk -F'\t' 'NR == 3 { print $1 }')|$(ui_value "$EXCL_STATE_ID")"
tick 0
tick 1
tick 2
check "all off: the whole project" "Nothing checked: the whole project is snapshotted." "$(ui_value "$EXCL_STATE_ID")"
tick 9
tick x
check "  a row that is not there, or no row: nothing changes" "false|false|false" "$(ui_rows "$EXCL_TABLE_ID" | col 1 | /usr/bin/paste -sd '|' -)"
tick 0
tick 1
check "the scan ran only on opening" "1" "$(scans)"

section "saving"
: > "$FAKE_AGENTVM_DIR/log"
in_window "$MAIN_UUID"
ui_reset
in_window "$UUID"
omc_run AgentVM.exclusions.save
check_status "Save exits cleanly" 0
check "one call, with every ticked path" "session exclusions --project=$PROJECT --set=.build --set=.swiftpm --json" "$(saves)"
check "the window closes" "1" "$(closed "$UUID")"
check "the main window reads every list again, and its row says the list" "1|.build, .swiftpm" \
    "$(fake_log | /usr/bin/grep -c '^session exclusions --json$')|$(ui_value "$SES_EXCLUSIONS_ID" "$MAIN_UUID")"
omc_run AgentVM.exclusions.close
check "its close handler lets go of it" "|" "$(registered)|$(project_of "$UUID")"

section "a saved list, opened again"
: > "$FAKE_AGENTVM_DIR/log"
/usr/bin/jq '.excluded = [".swiftpm", "dist"] | .candidates |= map(if .path == ".swiftpm" then .excluded = true else . end)' \
    "$FIXTURES_AGENTVM/session-scan.json" > "$FAKE_AGENTVM_DIR/session-scan.json"
open_window "$PROJECT"
check "ticked as saved, not as suggested; a saved path the scan did not find has a row of its own" \
    "false${TAB}.build|true${TAB}.swiftpm|false${TAB}node_modules|true${TAB}dist" \
    "$(ui_rows "$EXCL_TABLE_ID" | col 1-2 | /usr/bin/paste -sd '|' -)"
check "  which says why" "saved; not found in the project now" "$(ui_rows "$EXCL_TABLE_ID" | /usr/bin/awk -F'\t' '$2 == "dist" { print $4 }')"
tick 1
tick 3
omc_run AgentVM.exclusions.save
check "nothing ticked: the list is emptied" "session exclusions --project=$PROJECT --clear --json" "$(saves)"
omc_run AgentVM.exclusions.close

section "Add Folder..."
REAL="$OMCTEST_WORK/projects/realapp"
/bin/mkdir -p "$REAL/Build/Products" "$OMCTEST_WORK/projects/elsewhere"
/bin/rm -f "$FAKE_AGENTVM_DIR/session-scan.json"
no_saved_list
add_folder() {
    omc_dialog_answer choose_folder "$1"
    omc_run AgentVM.exclusions.add
}
row_count() {
    ui_rows "$EXCL_TABLE_ID" | /usr/bin/grep -c .
}
open_window "$REAL"
check "on once the scan answered; the hidden view holds the project's path, where the folder panel starts" \
    "1|$REAL|__ACTIONUI_VIEW_${EXCL_PROJECT_ID}_VALUE__|Select" \
    "$(enabled "$EXCL_ADD_ID")|$(ui_value "$EXCL_PROJECT_ID")|$(/usr/bin/jq -r '.COMMAND_LIST[] | select(.COMMAND_ID? == "AgentVM.exclusions.add") | .CHOOSE_FOLDER_DIALOG | "\(.DEFAULT_LOCATION[0])|\(.BUTTON_PROMPT)"' "$APP_RESOURCES/Command.json")"
add_folder ""
check "Cancel in the panel adds nothing" "3" "$(row_count)"
add_folder "$REAL/Build/Products/"
check "a folder of the project: a ticked row by its path in the project, without the trailing slash" \
    "4|true${TAB}Build/Products${TAB}-${TAB}chosen by you|3 folders checked." \
    "$(row_count)|$(ui_rows "$EXCL_TABLE_ID" | col 1-4 | /usr/bin/sed -n '4p')|$(ui_value "$EXCL_STATE_ID")"
add_folder "$REAL/Build/Products"
check "  added again: still one row" "4" "$(row_count)"
tick 0
add_folder "$REAL/.build"
check "a folder the table has: its row is ticked again, no new row" "true|4" \
    "$(ui_rows "$EXCL_TABLE_ID" | /usr/bin/awk -F'\t' '$2 == ".build" { print $1 }')|$(row_count)"
alerts_reset
add_folder "$OMCTEST_WORK/projects/elsewhere"
check "a folder outside the project: refused with an alert, nothing added" "Choose a folder inside the project|4" "$(ui_alert_title)|$(row_count)"
alerts_reset
add_folder "$REAL"
check "  the project itself too" "Choose a folder inside the project|4" "$(ui_alert_title)|$(row_count)"
alerts_reset
add_folder "${REAL}x/Build"
check "  and a folder whose path only starts with the project's" "Choose a folder inside the project|4" "$(ui_alert_title)|$(row_count)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.exclusions.save
check "Save sends the added folder with the others" "session exclusions --project=$REAL --set=.build --set=.swiftpm --set=Build/Products --json" "$(saves)"
omc_run AgentVM.exclusions.close
/usr/bin/jq '.excluded = [".build", "Build/Products", "gone"]' "$FIXTURES_AGENTVM/session-scan.json" > "$FAKE_AGENTVM_DIR/session-scan.json"
open_window "$REAL"
check "opened again: a saved folder the scan does not list but the project has is saved; one it has not is not found" \
    "saved|saved; not found in the project now" \
    "$(ui_rows "$EXCL_TABLE_ID" | /usr/bin/awk -F'\t' '$2 == "Build/Products" { print $4 }')|$(ui_rows "$EXCL_TABLE_ID" | /usr/bin/awk -F'\t' '$2 == "gone" { print $4 }')"
omc_run AgentVM.exclusions.close
/bin/rm -f "$FAKE_AGENTVM_DIR/session-scan.json"

section "a folder that may hold work"
/usr/bin/jq '.candidates += [{path: "Private", bytes: 28000000000, files: 9, kind: "ignored", reasons: ["ignored by .gitignore"], suggested: false, excluded: false},
    {path: "Tests/big", bytes: 6100000000, files: 2, kind: "large", reasons: ["large"], suggested: false, excluded: false}]
    | .notes = ["could not read Private/locked"]' \
    "$FIXTURES_AGENTVM/session-scan.json" > "$FAKE_AGENTVM_DIR/session-scan.json"
no_saved_list
open_window "$PROJECT"
check "ignored and large folders: their size, and why, never ticked at first" \
    "false${TAB}Private${TAB}28.0 GB${TAB}ignored by git; may hold work that exists nowhere else|false${TAB}Tests/big${TAB}6.1 GB${TAB}large; may hold work that exists nowhere else" \
    "$(ui_rows "$EXCL_TABLE_ID" | col 1-4 | /usr/bin/sed -n '4,5p' | /usr/bin/paste -sd '|' -)"
check "agent-vm's notes under the table" "could not read Private/locked" "$(ui_value "$EXCL_NOTES_ID")"
tick 3
tick 4
check "ticked: the warning names them" "Private and Tests/big may hold work that exists nowhere else, and undo will not restore it." "$(ui_value "$EXCL_WARN_ID")"
tick 3
tick 4
check "  and goes when they are not" "" "$(ui_value "$EXCL_WARN_ID")"
omc_run AgentVM.exclusions.close

section "agent-vm refuses"
/usr/bin/jq '.candidates += [{path: "x/../y", bytes: 1, files: 1, kind: "large", reasons: ["large"], suggested: true, excluded: false}]' \
    "$FIXTURES_AGENTVM/session-scan.json" > "$FAKE_AGENTVM_DIR/session-scan.json"
no_saved_list
open_window "$PROJECT"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.exclusions.save
check "the refusal, in agent-vm's words; the window stays, Save on again" \
    "The list was not saved|cannot leave x/../y out of snapshots: use a path without . or .. components|0|1" \
    "$(ui_alert_title)|$(ui_alert_message)|$(closed "$UUID")|$(enabled "$EXCL_SAVE_ID")"
check "  nothing saved" "{\"projects\":[]}" "$(/usr/bin/jq -c . "$FAKE_AGENTVM_DIR/session-exclusions.json")"
omc_run AgentVM.exclusions.close

section "a scan that fails"
/bin/rm -f "$FAKE_AGENTVM_DIR/session-scan.json"
printf 'cannot use /Users/you/src/gone as a project: it does not exist\n' > "$FAKE_AGENTVM_DIR/fail-session-scan"
open_window /Users/you/src/gone
check "no rows, the reason, Save off" "|Could not look through the project: cannot use /Users/you/src/gone as a project: it does not exist|0" \
    "$(ui_rows "$EXCL_TABLE_ID")|$(ui_value "$EXCL_STATE_ID")|$(enabled "$EXCL_SAVE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.exclusions.save
check "  Save, however it came to run, saves nothing" "" "$(saves)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-session-scan"
omc_run AgentVM.exclusions.cancel
check "Cancel closes the window" "1" "$(closed "$UUID")"
omc_run AgentVM.exclusions.close

section "a window that closes while the project is looked through"
fake_reset
no_saved_list
# An agent-vm that, asked for the scan, does what the window's close handler does meanwhile.
CLOSER="$OMCTEST_WORK/closing-agent-vm"
{
    printf '#!/bin/sh\n'
    printf 'if [ "$1 $2" = "session scan" ]; then\n'
    printf '    "%s" "agentvm_exclusions_%s" set ""\n' "$PB" "$UUID"
    printf '    /bin/rm -rf "%s"\n' "$TMPDIR/AgentVM/$UUID"
    printf 'fi\n'
    printf 'exec "%s" "$@"\n' "$FAKE_AGENTVM"
} > "$CLOSER"
/bin/chmod +x "$CLOSER"
AGENTVM_APP_AGENT_VM="$CLOSER"
open_window "$PROJECT"
check "nothing is painted from the scan, and no cache folder is left" "1||no" \
    "$(scans)|$(ui_rows "$EXCL_TABLE_ID")|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
omc_run AgentVM.exclusions.close

in_window "$MAIN_UUID"
omc_run AgentVM.main.close
omctest_end
