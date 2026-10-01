#!/bin/sh
# Tests/52-launch-report.test.sh - what ended while the app was closed: the time the app keeps of
# its last reading, and the report a main window makes on opening of the image jobs and downloads
# that ended after it.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, and its jobs made here
# with jq, one of every kind and outcome. The clock is fixed (AGENTVM_APP_NOW). $HOME is the
# harness's own, so the file the app keeps is in the scratch.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_STATUS_ID" ] || {
    printf '52-launch-report: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
# 2026-09-30T12:00:12Z
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
SEEN="$HOME/Library/Application Support/AgentVM/jobs-seen"

open_window() {
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

# seen <time>  ->  the app last read status then.
seen() {
    /bin/mkdir -p "${SEEN%/*}"
    printf '%s\n' "$1" > "$SEEN"
}

# alert_lines  ->  the pending alert's message, every line of it (ui_alert_message gives the first).
alert_lines() {
    /usr/bin/awk -F'\t' '$1 == "message" { found = 1; print $2; next } found && $1 !~ /^(title|button|message)$/ { print }' \
        "$(omctest_win_dir)/pending_alert" 2>/dev/null
}

# The jobs: what ended between 11:00 and 12:00 on 2026-09-30, of every kind, and one still running.
/usr/bin/jq -n '
    def job(id; cmd; target; state; ended; extra):
        { id: ("20260930-11" + id), command: (cmd + ["--json"]), targets: [target], state: state,
          createdAt: "2026-09-30T11:00:00Z", startedAt: "2026-09-30T11:00:00Z",
          path: ("/Users/you/Library/Application Support/agent-vm/Jobs/20260930-11" + id) }
        + (if ended != null then {endedAt: ended} else {} end) + extra;
    [ job("0500-0000a1"; ["image", "create", "dev-new", "--from", "dev-node"]; "image:dev-new"; "done"; "2026-09-30T11:30:00Z"; {status: 0}),
      job("0600-0000a2"; ["image", "update", "dev"]; "image:dev"; "failed"; "2026-09-30T11:35:00Z"; {status: 1, error: "softwareupdate found no update"}),
      job("0700-0000a3"; ["image", "fetch-ipsw"]; "ipsw"; "done"; "2026-09-30T11:36:00Z"; {status: 0}),
      job("0800-0000a4"; ["image", "setup", "dev-node"]; "image:dev-node"; "lost"; "2026-09-30T11:37:00Z"; {error: "the job ended without recording a result: its runner was stopped"}),
      job("0900-0000a5"; ["image", "fetch-ipsw"]; "ipsw"; "canceled"; "2026-09-30T11:38:00Z"; {error: "canceled"}),
      job("1000-0000a6"; ["box", "stop", "s3"]; "box:s3"; "done"; "2026-09-30T11:40:00Z"; {status: 0}),
      job("1100-0000a7"; ["box", "start", "try1"]; "box:try1"; "failed"; "2026-09-30T11:45:00Z"; {status: 75, error: "no free slot"}),
      job("1200-0000a8"; ["image", "update-guest", "dev-acp"]; "image:dev-acp"; "done"; "2026-09-30T11:50:00Z"; {status: 0}),
      job("1300-0000a9"; ["image", "create", "dev-big", "--ipsw", "latest"]; "image:dev-big"; "running"; null; {}) ]' > "$OMCTEST_WORK/jobs.json"

fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
/bin/cp "$OMCTEST_WORK/jobs.json" "$JOBS"
/bin/rm -f "$SEEN"

# -----------------------------------------------------------------------------------------------
section "a first launch reports no history"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check_status "the init handler exits cleanly" 0
check "no alert"                 "" "$(ui_alert_title)"
check "the week's jobs are not even listed" "0" "$(fake_log | /usr/bin/grep -c '^job list')"
check "the time of this reading is kept" "2026-09-30T12:00:12Z" "$(/bin/cat "$SEEN")"
omc_run AgentVM.main.close

section "the report: what ended since the app last looked"
seen "2026-09-30T11:00:00Z"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check "one alert"                "While AgentVM was closed" "$(ui_alert_title)"
check "the week's jobs are listed for it, once" "1" "$(fake_log | /usr/bin/grep -c -x 'job list --json')"
check "an image built, an update that failed with why, a download, a setup whose runner was stopped, an image brought up to date" \
    "Image dev-new is ready.|Image dev was not updated: softwareupdate found no update|The macOS restore file is downloaded.|The setup of image dev-node did not finish: the job ended without recording a result: its runner was stopped|Image dev-acp is up to date." \
    "$(alert_lines | /usr/bin/paste -sd '|' -)"
check "  not the download that was canceled" "0" "$(alert_lines | /usr/bin/grep -c 'not downloaded')"
check "  not the boxes started and stopped meanwhile" "0" "$(alert_lines | /usr/bin/grep -c 'Box ')"
check "  not the build that still runs" "0" "$(alert_lines | /usr/bin/grep -c 'dev-big')"
check "the time moves to this reading" "2026-09-30T12:00:12Z" "$(/bin/cat "$SEEN")"

section "said once"
omc_run AgentVM.main.close
: > "$FAKE_AGENTVM_DIR/log"
open_window
check "the next launch has nothing to report" "" "$(ui_alert_title)"
alerts_reset
ui_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.activated
check "coming back to the window reports nothing" "|0" "$(ui_alert_title)|$(fake_log | /usr/bin/grep -c '^job list')"
omc_run AgentVM.main.close

section "only what ended after the app last looked"
seen "2026-09-30T11:36:30Z"
open_window
check "the jobs that ended later"  "The setup of image dev-node did not finish: the job ended without recording a result: its runner was stopped|Image dev-acp is up to date." \
    "$(alert_lines | /usr/bin/paste -sd '|' -)"
omc_run AgentVM.main.close
seen "2026-09-30T11:50:00Z"
open_window
check "a job that ended at that very second was seen: nothing" "" "$(ui_alert_title)"
omc_run AgentVM.main.close

section "every reading moves the time; a reading that fails does not"
open_window
( AGENTVM_APP_NOW=1790769700; export AGENTVM_APP_NOW; poll 1 )
check "the poll loop's reading"  "2026-09-30T12:01:40Z" "$(/bin/cat "$SEEN")"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
( AGENTVM_APP_NOW=1790769800; export AGENTVM_APP_NOW; poll 1 )
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
check "status failed: the time stays" "2026-09-30T12:01:40Z" "$(/bin/cat "$SEEN")"
omc_run AgentVM.main.close

section "agent-vm cannot list the jobs"
seen "2026-09-30T11:00:00Z"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-job-list"
open_window
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-list"
check_status "the window opens all the same" 0
check "  with no report"         "" "$(ui_alert_title)"
check "  and its lists"          "yes" "$([ -n "$(ui_rows "$MAIN_BOXES_ID")" ] && echo yes)"
omc_run AgentVM.main.close

section "an agent-vm that cannot be used"
seen "2026-09-30T11:00:00Z"
printf '0.4.1\n' > "$FAKE_AGENTVM_DIR/version"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check "too old: no report, and the jobs are not listed" "|0" "$(ui_alert_title)|$(fake_log | /usr/bin/grep -c '^job list')"
check "  the time stays, for the launch after the update" "2026-09-30T11:00:00Z" "$(/bin/cat "$SEEN")"
omc_run AgentVM.main.close
/bin/rm -f "$FAKE_AGENTVM_DIR/version"
open_window
check "updated: the report is made then" "While AgentVM was closed" "$(ui_alert_title)"
omc_run AgentVM.main.close

for junk in "yesterday" "" "2026-09-30" '$(touch x)' "0"; do
    seen "$junk"
    : > "$FAKE_AGENTVM_DIR/log"
    open_window
    check "[$junk]: no report, and the jobs are not listed" "|0" "$(ui_alert_title)|$(fake_log | /usr/bin/grep -c '^job list')"
    check "  the time is put right" "2026-09-30T12:00:12Z" "$(/bin/cat "$SEEN")"
    omc_run AgentVM.main.close
done

section "status fails at launch while the jobs can be listed"
seen "2026-09-30T11:00:00Z"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
open_window
check "the report is made"       "While AgentVM was closed" "$(ui_alert_title)"
check "  and the time moves, though no reading succeeded: it is said once" "2026-09-30T12:00:12Z" "$(/bin/cat "$SEEN")"
omc_run AgentVM.main.close
open_window
check "  the next launch does not repeat it" "" "$(ui_alert_title)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.main.close

section "opened by a link to a box that is gone, with a report to make"
# A window shows one alert, the newest: the report is raised last, since it is said only once.
seen "2026-09-30T11:00:00Z"
"$OMC_OMC_SUPPORT_PATH/pasteboard" agentvm_goto set "$OMC_APP_PROCESS_ID box nosuch"
open_window
check "the alert that stays is the report" "While AgentVM was closed" "$(ui_alert_title)"
omc_run AgentVM.main.close

section "one job only"
seen "2026-09-30T11:00:00Z"
/usr/bin/jq '[.[0]]' "$OMCTEST_WORK/jobs.json" > "$JOBS"
open_window
check "the alert has its one line" "While AgentVM was closed|Image dev-new is ready." "$(ui_alert_title)|$(ui_alert_message)"
omc_run AgentVM.main.close

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
