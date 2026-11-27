#!/bin/sh
# Tests/69-session-changes.test.sh - a session's changes: Changes... and a double-click in the
# Sessions tab's session table, and the Session Changes window. The window opens only when this
# run of the app asked for it, one per session; it compares the project with the session's
# snapshot (the report's rows, what was left out, the state), shows the selected change (a text
# diff, previews of what is not text, a link or a folder in words, never a file read through a
# symlink), keeps the ticks (an entry inside a folder follows the folder), and undoes the ticked
# entries after a question that names a program still running, then compares again; an undone
# session is shown only.
#
# agent-vm is the fake: the report of session-report.json (fixtures/agentvm, part changes), with
# its project and snapshot rewritten to folders made here, which hold what the report says.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.sessions.sh" "$APP_SCRIPTS/lib.agentvm.changes.sh"
[ -n "$SES_CHANGES_ID" ] && [ -n "$SES_TABLE_ID" ] && [ -n "$SES_PROJECTS_ID" ] && [ -n "$MAIN_STATUS_ID" ] \
    && [ -n "$CHG_HEAD_ID" ] && [ -n "$CHG_PATH_ID" ] && [ -n "$CHG_SUMMARY_ID" ] && [ -n "$CHG_TABLE_ID" ] \
    && [ -n "$CHG_TITLE_ID" ] && [ -n "$CHG_WHAT_ID" ] && [ -n "$CHG_DIFF_ID" ] && [ -n "$CHG_DIFF_SCROLL_ID" ] && [ -n "$CHG_PREVIEWS_ID" ] \
    && [ -n "$CHG_OLD_PREVIEW_ID" ] && [ -n "$CHG_NEW_PREVIEW_ID" ] && [ -n "$CHG_OLD_SIDE_ID" ] && [ -n "$CHG_LEFT_OUT_ID" ] \
    && [ -n "$CHG_NOTE_ID" ] && [ -n "$CHG_SHOW_ID" ] && [ -n "$CHG_KEPT_ID" ] && [ -n "$CHG_REFRESH_ID" ] \
    && [ -n "$CHG_TICKED_ID" ] && [ -n "$CHG_UNDO_ID" ] || {
    printf '69-session-changes: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?69-session-changes: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-changes-$$"
OTHER_UUID="OMCTEST-other-changes-$$"
TAB="$(printf '\t')"
MEASURED="$(/usr/bin/jq -r '.sessions.measuredAt' "$FIXTURES_AGENTVM/status-sessions.json")"
MEASURED_SECONDS="$(/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$MEASURED" +%s)"
AGENTVM_APP_NOW=$((MEASURED_SECONDS + 3600))
export AGENTVM_APP_NOW

# The session of the report, and a project and a snapshot made here that hold what it lists.
ID="$(/usr/bin/jq -r '.session' "$FIXTURES_AGENTVM/session-report.json")"
/bin/mkdir -p "$OMCTEST_WORK/changes"
WORK="$(cd "$OMCTEST_WORK/changes" && pwd -P)"
PROJECT="$WORK/myapp"
SESSION_DIR="$WORK/store/Sessions/$ID"
SNAPSHOT="$SESSION_DIR/snapshot"
/bin/mkdir -p "$PROJECT/Sources" "$SNAPSHOT/Sources" "$SNAPSHOT/Old"
printf 'let a = 1\nlet b = 2\nlet c = 3\n' > "$SNAPSHOT/Sources/main.swift"
printf 'let a = 1\nlet b = 20\nlet c = 3\nlet d = 4\n' > "$PROJECT/Sources/main.swift"
printf 'new\n' > "$PROJECT/Sources/added.swift"
printf 'notes\n' > "$SNAPSHOT/Old/notes.txt"
printf 'PNG\0\1\2\3' > "$SNAPSHOT/icon.png"
printf 'PNG\0\1\4\5\6\7' > "$PROJECT/icon.png"
printf 'echo build\n' > "$SNAPSHOT/build.sh"
printf 'echo build\n' > "$PROJECT/build.sh"
/bin/chmod 644 "$SNAPSHOT/build.sh"
/bin/chmod 755 "$PROJECT/build.sh"
printf 'readme\n' > "$SNAPSHOT/README.md"
printf 'readme\n' > "$PROJECT/README.md"
/bin/ln -s README.md "$SNAPSHOT/docs"
/bin/ln -s /etc/hosts "$PROJECT/docs"

# report [jq filter]  ->  the fake's report of the session: the fixture with its folders those made
# here, changed by the filter.
report() {
    /usr/bin/jq --arg project "$PROJECT" --arg snapshot "$SNAPSHOT" \
        '.project = $project | .snapshotPath = $snapshot | '"${1:-.}" \
        "$FIXTURES_AGENTVM/session-report.json" > "$FAKE_AGENTVM_DIR/session-report.json"
}

# session_state <state>  ->  the fake's session list: this session, in that state, on the project.
session_state() {
    /usr/bin/jq -n --arg id "$ID" --arg project "$PROJECT" --arg snapshot "$SNAPSHOT" --arg state "$1" \
        '[{id: $id, project: $project, snapshotPath: $snapshot, state: $state, startSeconds: 1795728835, formatVersion: 3, projectDevice: 1}
          + (if $state != "active" then {endedAt: "2026-11-26T17:00:00Z"} else {} end)
          + (if $state == "undone" then {undoneAt: "2026-11-26T17:10:00Z"} else {} end)]' > "$FAKE_AGENTVM_DIR/session-list.json"
}

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

request()    { "$PB" agentvm_open_request_changes get; }
registered() { "$PB" "agentvm_window_changes_$ID" get; }
closed()     { ui_calls "${1}${TAB}omc_window${TAB}omc_terminate_cancel"; }
reports()    { fake_log | /usr/bin/grep -c "^session report $ID "; }
undos()      { fake_log | /usr/bin/grep "^session undo " | /usr/bin/paste -sd '|' -; }
rows()       { ui_rows "$CHG_TABLE_ID" | col 1-5 | /usr/bin/tr '\t' ' ' | /usr/bin/paste -sd '|' -; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}
shown() {
    [ "$(ui_visible "$1")" = "0" ] && echo 0 || echo 1
}

# open_window [uuid]  ->  the window opened the way Changes... opens it: the request, then the
# window's init handler, in a window of its own.
open_window() {
    in_window "${1:-$UUID}"
    # The window of an earlier check closes first, as its close button closes it.
    omc_run AgentVM.changes.close
    "$PB" agentvm_open_request_changes set "$APP_PID changes:$ID"
    ui_reset
    alerts_reset
    omc_control_defaults AgentVM.changes
    omc_run AgentVM.changes.init
}

# select_row <n>  ->  the n-th row selected (its hidden sixth column is its number).
select_row() {
    omc_table_cell "$CHG_TABLE_ID" 6 "$1"
    omc_trigger "$CHG_TABLE_ID"
    omc_run AgentVM.changes.selected
}

# tick <row index>  ->  that row's checkbox clicked.
tick() {
    omc_trigger "$CHG_TABLE_ID" 0 "$1"
    omc_run AgentVM.changes.tick
}

fake_reset
"$PB" "agentvm_window_changes_$ID" set ""
"$PB" agentvm_open_request_changes set ""
report
session_state ended

# -----------------------------------------------------------------------------------------------
section "Changes... and a double-click in the Sessions tab"
in_window "$MAIN_UUID"
omc_run AgentVM.main.close
/usr/bin/jq --slurpfile s "$FIXTURES_AGENTVM/status-sessions.json" '.sessions = $s[0].sessions' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
/bin/cp "$FIXTURES_AGENTVM/session-list.json" "$FAKE_AGENTVM_DIR/session-list.json"
FIRST="$(lib agentvm_session_rows < "$FIXTURES_AGENTVM/session-list.json" | /usr/bin/awk -F'\t' 'NR == 1 { print $1 }')"
alerts_reset
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
omc_trigger "$MAIN_STATUS_ID" "" 2
omc_run AgentVM.main.tab
omc_table_cell "$SES_PROJECTS_ID" 1 "/Users/you/src/myapp"
omc_trigger "$SES_PROJECTS_ID"
omc_run AgentVM.main.session.project.selected
check "the button is off with no session selected" "0" "$(enabled "$SES_CHANGES_ID")"
omc_table_cell "$SES_TABLE_ID" 8 "$FIRST"
omc_trigger "$SES_TABLE_ID"
omc_run AgentVM.main.session.selected
check "  a session selected: on" "1" "$(enabled "$SES_CHANGES_ID")"
omc_trigger "$SES_CHANGES_ID"
omc_run AgentVM.main.session.changes
check "  Changes...: the request names that session" "$APP_PID changes:$FIRST" "$(request)"
"$PB" agentvm_open_request_changes set ""
SECOND="$(lib agentvm_session_rows < "$FIXTURES_AGENTVM/session-list.json" | /usr/bin/awk -F'\t' 'NR == 2 { print $1 }')"
omc_trigger "$SES_TABLE_ID" "" 1
omc_run AgentVM.main.session.changes
check "  a double-click on the second row: that session" "$APP_PID changes:$SECOND" "$(request)"
"$PB" agentvm_open_request_changes set ""
omc_table_cell "$SES_TABLE_ID" 8 ""
omc_trigger "$SES_TABLE_ID"
omc_run AgentVM.main.session.selected
check "  none selected: off again" "0" "$(enabled "$SES_CHANGES_ID")"
omc_trigger "$SES_TABLE_ID" "" 99
omc_run AgentVM.main.session.changes
check "  a row the table does not have opens nothing" "" "$(request)"
omc_run AgentVM.main.close
"$PB" agentvm_open_request_changes set ""
session_state ended

# -----------------------------------------------------------------------------------------------
section "the window opens only when asked, one per session"
in_window "$UUID"
ui_reset
omc_control_defaults AgentVM.changes
omc_run AgentVM.changes.init
check "a window opened without a request closes, and compares nothing" "1|0" "$(closed "$UUID")|$(reports)"
open_window
check "opened for the session: it is the session's window, titled" "$APP_PID $UUID|Session Changes" "$(registered)|$(ui_title)"
check "  the request is read once" "" "$(request)"
check "  it compared the project with the snapshot once" "1" "$(reports)"
open_window "$OTHER_UUID"
check "a second window for the same session brings the first to the front and closes" "1|1|$APP_PID $UUID" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")|$(closed "$OTHER_UUID")|$(registered)"

# -----------------------------------------------------------------------------------------------
section "what the window shows"
open_window
check "the head: the project's name, its folder, when the session started and ended" \
    "Changes in myapp|$(lib agentvm_display_path "$PROJECT") - session started $(/bin/date -r 1795728835 '+%b %e %H:%M' | /usr/bin/sed 's/  / /'), ended Nov 26 17:00" \
    "$(ui_value "$CHG_HEAD_ID")|$(ui_value "$CHG_PATH_ID")"
check "  the summary, with what to review first" "6 changes: 1 added, 1 deleted, 3 modified, 1 permission change. Flagged: 1 high, 1 medium." \
    "$(ui_value "$CHG_SUMMARY_ID")"
check "  a row per change, by path: what changed, the size, the flag" \
    "false deleted folder Old 1 item |false added Sources/added.swift 4 bytes |false modified Sources/main.swift 30 bytes -> 41 bytes |false permissions build.sh 11 bytes medium|false modified link docs 9 bytes -> 10 bytes high|false modified icon.png 7 bytes -> 9 bytes " \
    "$(rows)"
check "  every tick on: the session ended, and each entry is its own" "false false false false false false" \
    "$(ui_rows "$CHG_TABLE_ID" | col 7 | /usr/bin/paste -sd ' ' -)"
check "  what was left out, with the flagged entry" "Can't be undone: 3 changes in .build, left out of the snapshot. Flagged: .build/debug/tool (medium)." \
    "$(ui_value "$CHG_LEFT_OUT_ID")"
check "  no note: the question before an undo says what it does" "" "$(ui_value "$CHG_NOTE_ID")"
check "  nothing ticked: Undo off; Compare Again on; no kept versions yet" "|0|1|0" \
    "$(ui_value "$CHG_TICKED_ID")|$(enabled "$CHG_UNDO_ID")|$(enabled "$CHG_REFRESH_ID")|$(enabled "$CHG_KEPT_ID")"
check "  nothing selected: nothing compared on the right, Show in Finder off" "No selection|0|0|0" \
    "$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")|$(enabled "$CHG_SHOW_ID")"

# -----------------------------------------------------------------------------------------------
section "the selected change"
select_row 3
check "a modified text file: the two compared line by line, the snapshot's and the project's" \
    "Sources/main.swift|Modified, 30 bytes -> 41 bytes.|1|0|$SNAPSHOT/Sources/main.swift|$PROJECT/Sources/main.swift|1" \
    "$(ui_value "$CHG_TITLE_ID")|$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")|$(ui_prop "$CHG_DIFF_ID" oldFile)|$(ui_prop "$CHG_DIFF_ID" newFile)|$(enabled "$CHG_SHOW_ID")"
omc_run AgentVM.changes.show
check "  Show in Finder selects the project's file" "-R $PROJECT/Sources/main.swift" "$(/usr/bin/tail -n 1 "$FAKE_OPEN_LOG" 2>/dev/null)"
select_row 2
check "an added file: against an empty file" "Added, 4 bytes.|1|$PROJECT/Sources/added.swift|0" \
    "$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")|$(ui_prop "$CHG_DIFF_ID" newFile)|$(/usr/bin/stat -f %z "$(ui_prop "$CHG_DIFF_ID" oldFile)")"
select_row 6
check "a file that is not text: previews of both sides, no diff" "0|1|$SNAPSHOT/icon.png|$PROJECT/icon.png|1" \
    "$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")|$(ui_value "$CHG_OLD_PREVIEW_ID")|$(ui_value "$CHG_NEW_PREVIEW_ID")|$(shown "$CHG_OLD_SIDE_ID")"
check "  and says only what changed" "Modified, 7 bytes -> 9 bytes." "$(ui_value "$CHG_WHAT_ID")"
select_row 5
check "a symlink: where it points now and at the start, in words, with its flag; nothing compared" \
    "Symbolic link to /etc/hosts. At the start: README.md. Flagged high: symlink pointing outside the project (/etc/hosts): host tools that follow it read or write elsewhere.|0|0|" \
    "$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")|$(ui_value "$CHG_NEW_PREVIEW_ID")"
select_row 1
check "a deleted folder: what it held, in words" "Deleted folder, 1 item.|0" \
    "$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")"
omc_run AgentVM.changes.show
check "  Show in Finder selects the snapshot's copy" "-R $SNAPSHOT/Old" "$(/usr/bin/tail -n 1 "$FAKE_OPEN_LOG" 2>/dev/null)"
select_row 4
check "a permission change: the modes before and now" "1" \
    "$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c '^Permissions changed: -rw-r--r-- -> -rwxr-xr-x. Flagged medium')"
/bin/mv "$PROJECT/Sources/main.swift" "$WORK/main.swift.kept"
/bin/ln -s /etc/hosts "$PROJECT/Sources/main.swift"
select_row 3
check "a file the agent turned into a symlink since: never read through it" "0|0|1" \
    "$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")|$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'Not shown: no longer a plain file.')"
/bin/rm "$PROJECT/Sources/main.swift"
/bin/mv "$WORK/main.swift.kept" "$PROJECT/Sources/main.swift"
/bin/mkdir -p "$WORK/outside"
printf 'secret\n' > "$WORK/outside/added.swift"
/bin/mv "$PROJECT/Sources" "$WORK/Sources.kept"
/bin/ln -s "$WORK/outside" "$PROJECT/Sources"
select_row 2
check "  nor through a folder above it that is now a symlink out of the project" "0|1" \
    "$(shown "$CHG_DIFF_SCROLL_ID")|$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'Not shown')"
/bin/rm "$PROJECT/Sources"
/bin/mv "$WORK/Sources.kept" "$PROJECT/Sources"
/bin/mv "$PROJECT/Sources" "$PROJECT/Elsewhere"
/bin/ln -s Elsewhere "$PROJECT/Sources"
select_row 2
check "  nor through one that points elsewhere in the project" "0|1" \
    "$(shown "$CHG_DIFF_SCROLL_ID")|$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'Not shown')"
/bin/rm "$PROJECT/Sources"
/bin/mv "$PROJECT/Elsewhere" "$PROJECT/Sources"
select_row 2
check "  and read again once the folder is back" "1|$PROJECT/Sources/added.swift" "$(shown "$CHG_DIFF_SCROLL_ID")|$(ui_prop "$CHG_DIFF_ID" newFile)"
/bin/rm "$SNAPSHOT/docs"
/bin/ln -s "$(printf 'READ\342\200\256ME')" "$SNAPSHOT/docs"
select_row 5
check "a symlink's target at the start with a direction mark: shown as ?" "1" \
    "$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'At the start: READ?ME.')"
/bin/rm "$SNAPSHOT/docs"
/bin/ln -s README.md "$SNAPSHOT/docs"
select_row 99
check "a row the report does not have: nothing shown" "|0" "$(ui_value "$CHG_TITLE_ID")|$(shown "$CHG_DIFF_SCROLL_ID")"

# -----------------------------------------------------------------------------------------------
section "changes said in words"
# select_path <path>  ->  the row of that path selected.
select_path() {
    select_row "$(ui_rows "$CHG_TABLE_ID" | SEL_PATH="$1" /usr/bin/awk -F'\t' '$3 == ENVIRON["SEL_PATH"] { print $6 }')"
}
printf 'abc\n' > "$PROJECT/tool"
/bin/mkdir -p "$SNAPSHOT/tool"
report '.changes += [{"path": ".", "kind": "metadata", "type": "directory", "flags": [], "coveredByAncestor": false},
    {"path": "tool", "kind": "typeChanged", "type": "file", "size": 4, "flags": [], "coveredByAncestor": false},
    {"path": "Gen2", "kind": "typeChanged", "type": "directory", "entriesInside": 2, "flags": [], "coveredByAncestor": false},
    {"path": "Gen3", "kind": "added", "type": "directory", "entriesInside": 1, "flags": [], "coveredByAncestor": false},
    {"path": "Sources", "kind": "metadata", "type": "directory", "flags": [], "coveredByAncestor": false},
    {"path": "lnk", "kind": "typeChanged", "type": "symlink", "symlinkTarget": "x", "flags": [], "coveredByAncestor": false},
    {"path": "fifo", "kind": "added", "type": "other", "flags": [], "coveredByAncestor": false}]'
open_window
select_path tool
check "a file that was something else at the start: in words, nothing compared" \
    "Now a file; was a folder or link.|0|0" \
    "$(ui_value "$CHG_WHAT_ID")|$(shown "$CHG_DIFF_SCROLL_ID")|$(shown "$CHG_PREVIEWS_ID")"
select_path Gen2
check "  a folder that was something else" "Now a folder, 2 items; was a file or link." \
    "$(ui_value "$CHG_WHAT_ID")"
select_path Gen3
check "  an added folder: what it holds, and that only what is flagged in it is listed" \
    "Added folder, 1 item." \
    "$(ui_value "$CHG_WHAT_ID")"
select_path Sources
check "  a folder's permissions: undo takes what is listed under it" \
    "Folder permissions changed." "$(ui_value "$CHG_WHAT_ID")"
select_path .
check "  the project folder's own: only those" "Project folder permissions changed." "$(ui_value "$CHG_WHAT_ID")"
select_path lnk
check "  a link that was something else, in the app's words" "Symbolic link to x." "$(ui_value "$CHG_WHAT_ID")"
select_path fifo
check "  a pipe or a device" "Special file (a pipe or device), not shown." "$(ui_value "$CHG_WHAT_ID")"
/bin/rm -f "$PROJECT/tool"
/bin/rmdir "$SNAPSHOT/tool"
report

# -----------------------------------------------------------------------------------------------
section "ticks"
open_window
tick 2
tick 0
check "two ticked: the count, and Undo on" "true|false|true|2 checked|1" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/sed -n 1p | col 1)|$(ui_rows "$CHG_TABLE_ID" | /usr/bin/sed -n 2p | col 1)|$(ui_rows "$CHG_TABLE_ID" | /usr/bin/sed -n 3p | col 1)|$(ui_value "$CHG_TICKED_ID")|$(enabled "$CHG_UNDO_ID")"
tick 0
check "  one unticked again" "1 checked" "$(ui_value "$CHG_TICKED_ID")"
tick 0
report '.changes += [{"path": "Gen", "kind": "added", "type": "directory", "flags": [], "coveredByAncestor": false},
    {"path": "Gen/a.swift", "kind": "added", "type": "file", "size": 2, "flags": [], "coveredByAncestor": true},
    {"path": "bad\nname", "kind": "added", "type": "file", "size": 1, "flags": [], "coveredByAncestor": false}]'
omc_run AgentVM.changes.refresh
check "Compare Again keeps the ticks of what is still listed" "2 checked" "$(ui_value "$CHG_TICKED_ID")"
check "  an entry inside an added folder follows its folder, disabled; a name with a control character is disabled" \
    "Gen false false|Gen/a.swift false true|bad?name false true" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Gen" || $3 == "Gen/a.swift" || $3 == "bad?name" { print $3, $1, $7 }' | /usr/bin/paste -sd '|' -)"
gen="$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Gen" { print NR - 1 }')"
tick "$gen"
check "  the folder ticked: what is in it shows ticked too, and counts once" "true|3 checked" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Gen/a.swift" { print $1 }')|$(ui_value "$CHG_TICKED_ID")"
inner="$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Gen/a.swift" { print NR - 1 }')"
bad="$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "bad?name" { print NR - 1 }')"
tick "$inner"
tick "$bad"
check "  a disabled tick, were it fired anyway, changes nothing" "3 checked" "$(ui_value "$CHG_TICKED_ID")"
bad_row="$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "bad?name" { print $6 }')"
select_row "$bad_row"
check "  the name with a control character is shown, never opened" "0|0|1" \
    "$(shown "$CHG_DIFF_SCROLL_ID")|$(enabled "$CHG_SHOW_ID")|$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'Not shown: the name has control characters')"
report '.changes += [{"path": "Docs", "kind": "metadata", "type": "directory", "flags": [], "coveredByAncestor": false},
    {"path": "Docs/guide.md", "kind": "modified", "type": "file", "size": 3, "previousSize": 2, "flags": [], "coveredByAncestor": false}]'
open_window
child="$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Docs/guide.md" { print NR - 1 }')"
tick "$child"
check "a change under a folder, ticked on its own" "true false|1 checked" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Docs/guide.md" { print $1, $7 }')|$(ui_value "$CHG_TICKED_ID")"
tick "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Docs" { print NR - 1 }')"
check "  its folder ticked (a permission change): undo takes what is under it, so the change follows the folder, disabled, and counts once" \
    "true true|1 checked" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Docs/guide.md" { print $1, $7 }')|$(ui_value "$CHG_TICKED_ID")"
tick "$child"
check "  its own tick then cannot change" "true|1 checked" \
    "$(ui_rows "$CHG_TABLE_ID" | /usr/bin/awk -F'\t' '$3 == "Docs/guide.md" { print $1 }')|$(ui_value "$CHG_TICKED_ID")"
omc_run AgentVM.changes.undo
check "  and the undo names the folder only" "Undo 1 item in myapp?|Docs will be restored to how it was" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/sed 's/ when the session started.*//')"
report

# -----------------------------------------------------------------------------------------------
section "the selected change follows its path"
open_window
select_row 3
check "Sources/main.swift selected" "Sources/main.swift" "$(ui_value "$CHG_TITLE_ID")"
report '.changes |= map(select(.path != "Old"))'
omc_run AgentVM.changes.refresh
check "  the row before it is gone: Compare Again shows it still, from its new row" "Sources/main.swift|$PROJECT/Sources/main.swift" \
    "$(ui_value "$CHG_TITLE_ID")|$(ui_prop "$CHG_DIFF_ID" newFile)"
report '.changes |= map(select(.path != "Sources/main.swift"))'
omc_run AgentVM.changes.refresh
check "  gone itself: nothing shown" "|0" "$(ui_value "$CHG_TITLE_ID")|$(shown "$CHG_DIFF_SCROLL_ID")"
report

# -----------------------------------------------------------------------------------------------
section "undo"
open_window
tick 2
tick 0
omc_run AgentVM.changes.undo
check "the question: how many, which, and that the agent's versions are kept" \
    "Undo 2 items in myapp?|Old and Sources/main.swift will be restored to how they were when the session started. The agent's versions are moved to the session's folder.|AgentVM.changes.undo.confirmed" \
    "$(ui_alert_title)|$(ui_alert_message)|$(ui_alert_action Undo)"
check "  nothing undone yet" "" "$(undos)"
/bin/mkdir -p "$SESSION_DIR/replaced-20261126-170000"
before="$(reports)"
alerts_reset
omc_run AgentVM.changes.undo.confirmed
check "Undo: one call with both paths, in the table's order" "session undo $ID --path=Old --path=Sources/main.swift --json" "$(undos)"
check "  the window compared again, and says what was put back" "$((before + 1))|1" \
    "$(reports)|$(ui_calls "omc_present_toast.2 items restored.")"
check "  the ticks are gone; the kept versions can be shown" "|0|1" \
    "$(ui_value "$CHG_TICKED_ID")|$(enabled "$CHG_UNDO_ID")|$(enabled "$CHG_KEPT_ID")"
omc_run AgentVM.changes.kept
check "  Show Kept Versions opens the session's folder" "$SESSION_DIR" "$(/usr/bin/tail -n 1 "$FAKE_OPEN_LOG" 2>/dev/null)"
omc_run AgentVM.changes.undo.confirmed
check "a second Undo with no question asked undoes nothing" "session undo $ID --path=Old --path=Sources/main.swift --json" "$(undos)"
fake_reset
report
session_state ended
/usr/bin/jq '.restore.failed = {"icon.png": "it is in use"} | .restore.restored = ["Old"]' \
    "$FIXTURES_AGENTVM/session-undo.json" > "$FAKE_AGENTVM_DIR/session-undo.json"
open_window
tick 0
tick 5
omc_run AgentVM.changes.undo
alerts_reset
omc_run AgentVM.changes.undo.confirmed
check "what could not be put back is said, with agent-vm's reason" "Some items couldn't be restored|1 item restored. Not restored: icon.png (it is in use)." "$(ui_alert_title)|$(ui_alert_message)"
/bin/rm -f "$FAKE_AGENTVM_DIR/session-undo.json"
open_window
tick 1
omc_run AgentVM.changes.undo
report '.changes |= map(select(.path != "Sources/added.swift"))'
alerts_reset
omc_run AgentVM.changes.undo.confirmed
check "a path agent-vm refuses: nothing put back, its reason" "Nothing was restored|cannot undo Sources/added.swift on its own: it did not change in this session (\`agent-vm session report\` lists what did)" \
    "$(ui_alert_title)|$(ui_alert_message)"
report
/usr/bin/jq '.session.state = "undone"' "$FIXTURES_AGENTVM/session-undo.json" > "$FAKE_AGENTVM_DIR/session-undo.json"
open_window
tick 0
omc_run AgentVM.changes.undo
session_state undone
omc_run AgentVM.changes.undo.confirmed
check "the last change put back: the toast says the session is undone" "1" \
    "$(ui_calls "omc_present_toast.2 items restored. The session is undone.")"
/bin/rm -f "$FAKE_AGENTVM_DIR/session-undo.json"
session_state ended

# -----------------------------------------------------------------------------------------------
section "an agent that may still be working"
session_state active
report '.programs = [{"box": "agents", "program": {"argv": ["opencode", "--continue"], "hostPid": '"$$"', "started": "2026-11-26T16:36:27Z"}},
    {"box": "agents", "program": {"argv": ["ls"], "hostPid": '"$$"', "status": 0}},
    {"box": "agents", "program": {"argv": ["gone"], "hostPid": 999999}}]'
open_window
check "an active session says so, and can be undone" "1|false" \
    "$(ui_value "$CHG_PATH_ID" | /usr/bin/grep -c ', active$')|$(ui_rows "$CHG_TABLE_ID" | /usr/bin/sed -n 1p | col 7)"
tick 0
omc_run AgentVM.changes.undo
check "a program of the session that has not ended and whose client runs: named, and the button is Undo Anyway" \
    "An agent may still be working in myapp|opencode --continue in box agents is still running. Stop it first if you can. Old will be restored to how it was|AgentVM.changes.undo.confirmed|" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/sed 's/ when the session started.*//')|$(ui_alert_action 'Undo Anyway')|$(ui_alert_action Undo)"
report '.programs = [{"box": "agents", "program": {"argv": ["opencode"], "hostPid": '"$$"'}},
    {"box": "tools", "program": {"argv": ["sh", "-c", "a and b in box c"], "hostPid": '"$$"'}}]'
open_window
tick 0
omc_run AgentVM.changes.undo
check "  two of them: both named, and the sentence says they" \
    "opencode in box agents and sh -c a and b in box c in box tools are still running. Stop them first if you can. Old will be restored to how it was" \
    "$(ui_alert_message | /usr/bin/sed 's/ when the session started.*//')"
report '.programs = [{"box": "agents", "program": {"argv": ["gone"], "hostPid": 999999}}]'
open_window
tick 0
omc_run AgentVM.changes.undo
check "  one whose client is gone is not named: the plain question" "Undo 1 item in myapp?" "$(ui_alert_title)"
report
session_state ended

# -----------------------------------------------------------------------------------------------
section "a session that is only shown"
session_state undone
open_window
check "undone: said so, every tick disabled, Undo off, Compare Again on" "1|1|true true true true true true|0|1" \
    "$(ui_value "$CHG_PATH_ID" | /usr/bin/grep -c 'undone Nov 26 17:10$')|$(ui_value "$CHG_NOTE_ID" | /usr/bin/grep -c '^Session undone. These changes were made after the undo.$')|$(ui_rows "$CHG_TABLE_ID" | col 7 | /usr/bin/paste -sd ' ' -)|$(enabled "$CHG_UNDO_ID")|$(enabled "$CHG_REFRESH_ID")"
tick 0
omc_run AgentVM.changes.undo
check "  a tick or Undo fired anyway does nothing" "|" "$(ui_value "$CHG_TICKED_ID")|$(ui_alert_title)"
select_row 3
check "  its changes can still be compared" "1" "$(shown "$CHG_DIFF_SCROLL_ID")"
printf '[]\n' > "$FAKE_AGENTVM_DIR/session-list.json"
report '.saved = true | del(.snapshotPath)'
open_window
check "discarded: the saved report, said so, nothing compared or undone" "1|1|0|0" \
    "$(ui_value "$CHG_PATH_ID" | /usr/bin/grep -c 'session discarded$')|$(ui_value "$CHG_NOTE_ID" | /usr/bin/grep -c '^Snapshot discarded. Showing the report saved when the session ended.$')|$(enabled "$CHG_REFRESH_ID")|$(enabled "$CHG_UNDO_ID")"
select_row 3
check "  a file of it: no snapshot to compare with" "0|1" "$(shown "$CHG_DIFF_SCROLL_ID")|$(ui_value "$CHG_WHAT_ID" | /usr/bin/grep -c 'No snapshot to compare with.')"
report
session_state ended
open_window
tick 0
printf '[]\n' > "$FAKE_AGENTVM_DIR/session-list.json"
report '.saved = true | del(.snapshotPath)'
/bin/mv "$SNAPSHOT" "$WORK/snapshot.kept"
before="$(reports)"
omc_run AgentVM.changes.undo
check "discarded elsewhere while the window was open: Undo Ticked... asks nothing, compares again and shows it discarded" \
    "|$((before + 1))|1|0" \
    "$(ui_alert_title)|$(reports)|$(ui_value "$CHG_PATH_ID" | /usr/bin/grep -c 'session discarded$')|$(enabled "$CHG_UNDO_ID")"
/bin/mv "$WORK/snapshot.kept" "$SNAPSHOT"
report
session_state ended
printf 'the report cannot be made\n' > "$FAKE_AGENTVM_DIR/fail-session-report"
open_window
check "a report that fails: agent-vm's reason, no rows, Compare Again on" "Could not compare the project with the session's snapshot: the report cannot be made||1|0" \
    "$(ui_value "$CHG_SUMMARY_ID")|$(rows)|$(enabled "$CHG_REFRESH_ID")|$(enabled "$CHG_UNDO_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-session-report"

# -----------------------------------------------------------------------------------------------
section "closing"
fake_reset
report
session_state ended
open_window
omc_run AgentVM.changes.cancel
check "Close closes the window" "1" "$(closed "$UUID")"
omc_run AgentVM.changes.close
check "  and it is no longer the session's window; its cache is gone" "||no" \
    "$(registered)|$("$PB" "agentvm_changes_$UUID" get)|$([ -d "${TMPDIR:-/tmp}/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.changes.tick
omc_run AgentVM.changes.undo.confirmed
check "  its handlers then do nothing" "" "$(undos)"

check "no undeclared ids" "" "$(ui_unknown_writes)"
omctest_end
