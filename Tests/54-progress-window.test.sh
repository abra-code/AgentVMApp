#!/bin/sh
# Tests/54-progress-window.test.sh - a job's progress window: Progress... in the box and image
# panes, the window's opening (one per job, and only when asked for by this run of the app), what
# it shows of a job that waits, runs, moves on and ends, its poll loop, and Stop.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json; the jobs are the fake's
# own (a box started from the main window) and ones made here with jq, with their logs taken from
# fixtures/agentvm/job-log-variety.json or written here. A job never ends by itself, so the test
# edits it (job_edit, job_log) to move it on. The clock is fixed at 12 seconds after the jobs
# start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.progress.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_PROGRESS_ID" ] && [ -n "$MAIN_IMAGE_PROGRESS_ID" ] && [ -n "$PROGRESS_STATUS_ID" ] \
    && [ -n "$PROGRESS_ELAPSED_ID" ] && [ -n "$PROGRESS_BAR_ID" ] && [ -n "$PROGRESS_STEPS_ID" ] && [ -n "$PROGRESS_LOG_ID" ] \
    && [ -n "$PROGRESS_NOTICE_ID" ] && [ -n "$PROGRESS_FOOTER_ID" ] && [ -n "$PROGRESS_STOP_ID" ] \
    && [ -n "$PROGRESS_LOG_SHOW_ID" ] && [ -n "$PROGRESS_LOG_CONSOLE_ID" ] || {
    printf '54-progress-window: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
# 2026-09-30T12:00:12Z: the jobs start at 12:00:00.
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?54-progress-window: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-progress-window-$$"
OTHER_UUID="OMCTEST-other-progress-window-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
VARIETY="$FIXTURES_AGENTVM/job-log-variety.json"
BUILD="20260930-120000-0000c1"
SETUP="20260930-120000-0000c2"
# The fake's first job.
START="20260930-120001-000001"

# in_window <uuid>  ->  the handlers that follow run in that window.
in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

job_edit() {
    /usr/bin/jq "$1" "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
}

# job_log <id> <jq expression giving {events, lines}>  ->  that job's log, in the fake.
job_log() {
    /usr/bin/jq -n "$2" > "$FAKE_AGENTVM_DIR/job-log-$1.json"
}

# job_state <id> <jq object to add>  ->  that job changed.
job_state() {
    job_edit "map(if .id == \"$1\" then . + $2 else . end)"
}

request() {
    "$PB" agentvm_open_request_progress get
}

# registered <job id>  ->  the pasteboard entry naming that job's progress window.
registered() {
    "$PB" "agentvm_window_progress_$1" get
}

# open_progress <job id> [uuid]  ->  that job's window opened the way Progress... opens it: the
# request, then the window's init handler, in a window of its own.
open_progress() {
    "$PB" agentvm_open_request_progress set "$APP_PID progress:$1"
    in_window "${2:-$UUID}"
    omc_control_defaults AgentVM.progress
    omc_run AgentVM.progress.init
}

poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.progress.poll )
}

select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}
select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

shown() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}
enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# steps  ->  the steps table's rows, "step=progress" joined with "|".
steps() {
    ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/awk -F'\t' '{ printf "%s%s=%s", (NR > 1 ? "|" : ""), $1, $2 }'
}

fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
for id in "$BUILD" "$SETUP" "$START"; do
    "$PB" "agentvm_window_progress_$id" set ""
done
"$PB" agentvm_open_request_progress set ""

# -----------------------------------------------------------------------------------------------
section "Progress... in the box pane"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
select_box cadabra-spike
check "no job holds the box: no Progress..." "0" "$(shown "$MAIN_BOX_PROGRESS_ID")"
chains_reset
omc_run AgentVM.main.box.progress
check "  and the handler opens nothing" "0|" "$(chain_asked AgentVM.progress)|$(request)"
omc_run AgentVM.main.box.start
check "a job started: the button is there" "1" "$(shown "$MAIN_BOX_PROGRESS_ID")"
chains_reset
omc_trigger "$MAIN_BOX_PROGRESS_ID"
omc_run AgentVM.main.box.progress
check "it asks for a progress window" "1" "$(chain_asked AgentVM.progress)"
check "  for the job that holds the box, from this run of the app" "$APP_PID progress:$START" "$(request)"

section "the window opens on a box being started"
job_log "$START" '{events: [{event: "progress", box: "cadabra-spike", step: "starting", message: "starting"}], lines: []}'
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
open_progress "$START"
check_status "the init handler exits cleanly" 0
check "takes the request, once"      "" "$(request)"
check "becomes the job's window"     "$APP_PID $UUID" "$(registered "$START")"
check "one call to agent-vm: the job's log" "job log $START --json" "$(fake_log)"
check "the title says what the job is" "Starting box cadabra-spike" "$(ui_title)"
check "the headline is its step, with a capital" "Starting" "$(ui_value "$PROGRESS_STATUS_ID")"
check "how long so far"              "Elapsed 12 s" "$(ui_value "$PROGRESS_ELAPSED_ID")"
check "the step, which is where it is" "Starting=running" "$(steps)"
check "no fraction: no bar"          "0" "$(shown "$PROGRESS_BAR_ID")"
check "no log, no notice"            "|" "$(ui_value "$PROGRESS_LOG_ID")|$(ui_value "$PROGRESS_NOTICE_ID")"
check "the footer names the job and says the window can go" "Job $START. You can close this window: the job goes on." "$(ui_value "$PROGRESS_FOOTER_ID")"
check "Stop... is on"                "1" "$(enabled "$PROGRESS_STOP_ID")"
check "the poll loop is started"     "1" "$(chain_asked AgentVM.progress.poll)"

section "a second Progress... on the same job, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.box.progress
check "opens no second window"       "0" "$(chain_asked AgentVM.progress)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select" "$UUID")"
open_progress "$START" "$OTHER_UUID"
check "a second window for the same job: the first stays the job's, the second closes" "$APP_PID $UUID|1" \
    "$(registered "$START")|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
for bad in "" "$APP_PID programs:$START" "1 progress:$START" "$APP_PID progress:../x" "$APP_PID progress:s3" "$APP_PID progress:--follow"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_progress set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.progress
    omc_run AgentVM.progress.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "" "$("$PB" "agentvm_job_$OTHER_UUID" get)"
done
for handler in AgentVM.progress.activated AgentVM.progress.poll AgentVM.progress.stop AgentVM.progress.stop.confirmed; do
    : > "$FAKE_AGENTVM_DIR/log"
    omc_run "$handler"
    check "$handler in a window with no job: agent-vm is not run" "" "$(fake_log)"
done

section "the poll loop follows the job to its end"
in_window "$UUID"
ui_reset
omc_control_defaults AgentVM.progress
: > "$FAKE_SLEEP_LOG"
: > "$FAKE_AGENTVM_DIR/log"
poll 1
check "it waits 2 seconds, then reads the job" "2|job log $START --json" "$(/bin/cat "$FAKE_SLEEP_LOG")|$(fake_log)"
job_log "$START" '{events: [{event: "progress", box: "cadabra-spike", step: "starting", message: "starting"},
    {event: "progress", box: "cadabra-spike", step: "running", message: "running"}], lines: []}'
job_state "$START" '{state: "done", status: 0, endedAt: "2026-09-30T12:00:26Z"}'
: > "$FAKE_SLEEP_LOG"
: > "$FAKE_AGENTVM_DIR/log"
poll 5
check "the job ended: one more reading, and the loop is over" "1|1" "$(/usr/bin/awk 'END { print NR }' "$FAKE_SLEEP_LOG")|$(fake_log | /usr/bin/grep -c '^job log')"
check "  its token is given up"      "" "$("$PB" "agentvm_poll_$UUID" get)"
check "the headline says how it ended" "Box cadabra-spike is running." "$(ui_value "$PROGRESS_STATUS_ID")"
check "how long it took"             "took 26 s" "$(ui_value "$PROGRESS_ELAPSED_ID")"
check "both steps are done"          "Starting=done|Running=done" "$(steps)"
check "Stop... is off, and the footer is the job's id" "0|Job $START" "$(enabled "$PROGRESS_STOP_ID")|$(ui_value "$PROGRESS_FOOTER_ID")"
: > "$FAKE_SLEEP_LOG"
poll 5
check "a loop started on a job that ended does not wait" "" "$(/bin/cat "$FAKE_SLEEP_LOG")"
chains_reset
omc_run AgentVM.progress.activated
check "coming back to the window reads it, and starts no loop" "0" "$(chain_asked AgentVM.progress.poll)"
omc_run AgentVM.progress.close
check "closing gives the job's window up" "|" "$(registered "$START")|$("$PB" "agentvm_job_$UUID" get)"
check "  and ends any loop"          "closed" "$("$PB" "agentvm_poll_$UUID" get)"

section "a build: steps, the bar, the log and a notice"
/usr/bin/jq -n --arg build "$BUILD" --arg setup "$SETUP" '
    [ { id: $build, command: ["image", "create", "dev-new", "--from", "dev-node", "--json"], targets: ["image:dev-new"], state: "running",
        createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z" },
      { id: $setup, command: ["image", "setup", "dev-new", "--json"], targets: ["image:dev-new"], state: "queued",
        createdAt: "2026-09-30T12:00:00Z", after: $build } ]' > "$JOBS"
/usr/bin/jq '{events, lines}' "$VARIETY" > "$FAKE_AGENTVM_DIR/job-log-$BUILD.json"
ui_reset
open_progress "$BUILD"
check "the title"                    "Building image dev-new" "$(ui_title)"
check "the headline is the last step, in agent-vm's words" "[3/3] Agents" "$(ui_value "$PROGRESS_STATUS_ID")"
check "the steps, oldest first; the last shows how far it is" \
    "Cloning dev-node (macOS 26A428)=done|Booting=done|Recipe: ACP agents (3 steps, 2 checks)=done|[1/3] Homebrew=done|[2/3] Node=done|[3/3] Agents=67%" "$(steps)"
check "the bar is shown, at the step's fraction" "1|67" "$(shown "$PROGRESS_BAR_ID")|$(ui_value "$PROGRESS_BAR_ID")"
check "the log: agent-vm's lines and the guest's, the notice of a step that is over where it was written, then the other lines" \
    "agent-vm-guest 0.8.7 answers over vsock|==> Downloading and installing Homebrew...|==> Installation successful!|Homebrew is already installed in the base image|==> Pouring node--24.9.0.arm64_tahoe.bottle.tar.gz|a line with a tab in it|added 212 packages in 9s|warning: a line that is neither an event nor the error" \
    "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/paste -sd '|' -)"
check "a notice of a step the job has left is on the notice line too, said to be from an earlier step" \
    "From an earlier step: Homebrew is already installed in the base image" "$(ui_value "$PROGRESS_NOTICE_ID")"

section "a notice is shown while the job is at the step it was written in"
NOTE_TEXT="note: this Mac is not letting agent-vm reach the guest at 192.168.64.3. The build keeps trying."
job_log "$BUILD" "{events: [{event: \"progress\", step: \"first-boot\", message: \"First boot\"},
    {event: \"log\", message: \"address 192.168.64.3\"},
    {event: \"notice\", message: \"$NOTE_TEXT\"}], lines: []}"
poll 1
check "the step it was written in: on the notice line, and not in the log too" "$NOTE_TEXT|address 192.168.64.3" \
    "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/paste -sd '|' -)"
job_log "$BUILD" "{events: [{event: \"progress\", step: \"first-boot\", message: \"First boot\"},
    {event: \"log\", message: \"address 192.168.64.3\"},
    {event: \"notice\", message: \"$NOTE_TEXT\"},
    {event: \"progress\", step: \"first-boot\", message: \"First boot\", fraction: 0.5}], lines: []}"
poll 1
check "the same step moving on keeps it" "$NOTE_TEXT" "$(ui_value "$PROGRESS_NOTICE_ID")"
job_log "$BUILD" "{events: [{event: \"progress\", step: \"first-boot\", message: \"First boot\"},
    {event: \"log\", message: \"address 192.168.64.3\"},
    {event: \"notice\", message: \"$NOTE_TEXT\"},
    {event: \"progress\", step: \"guest\", message: \"Installing the guest daemon\"}], lines: []}"
poll 1
check "the next step: the notice line says it is from an earlier step, and the notice is in the log" "From an earlier step: $NOTE_TEXT|address 192.168.64.3|$NOTE_TEXT" \
    "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/paste -sd '|' -)"
# A job comes to a step of the same name again (an update shuts down twice): the notice of the
# first is not of the second.
OFF_TEXT="note: the guest did not power off (no answer); waiting for it to answer and asking again"
job_log "$BUILD" "{events: [{event: \"progress\", step: \"shutdown\", message: \"Shutting down\"},
    {event: \"notice\", message: \"$OFF_TEXT\"},
    {event: \"progress\", step: \"check-guest-daemon\", message: \"Checking the guest daemon\"},
    {event: \"progress\", step: \"shutdown\", message: \"Shutting down\"}], lines: []}"
poll 1
check "a later step of the same name: from an earlier step, and in the log" "From an earlier step: $OFF_TEXT|$OFF_TEXT" \
    "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/paste -sd '|' -)"

section "a notice said before the step it is about"
# A box's start says its memory warning ("this box has ...") before its first step, and the
# warning is about the boot that follows. The window is the same for every kind of job, so the
# build's window stands in for a box's. The texts are examples, in agent-vm's words: the window
# matches on nothing in them.
MEMORY_TEXT="this box has 14 GB of this Mac's 16 GB of memory; the Mac and the boxes may get slow. \`agent-vm box set <box> --memory-gb N\` changes a stopped box's memory."
job_log "$BUILD" "{events: [{event: \"notice\", message: \"$MEMORY_TEXT\"}], lines: []}"
poll 1
check "before any step: on the notice line" "$MEMORY_TEXT|Started; no step reported yet." "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_STATUS_ID")"
job_log "$BUILD" "{events: [{event: \"notice\", message: \"$MEMORY_TEXT\"},
    {event: \"progress\", step: \"boot\", message: \"Booting a copy of deb\"}], lines: []}"
poll 1
check "the first step is the one it was said for: as it is, and not in the log too" "$MEMORY_TEXT|" \
    "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_LOG_ID")"
job_log "$BUILD" "{events: [{event: \"notice\", message: \"$MEMORY_TEXT\"},
    {event: \"progress\", step: \"boot\", message: \"Booting a copy of deb\"},
    {event: \"progress\", step: \"system-update\", message: \"Installing Debian 13's package updates\"}], lines: []}"
poll 1
check "a later step: it stays, as one from an earlier step, and the log has it" "From an earlier step: $MEMORY_TEXT|1" \
    "$(ui_value "$PROGRESS_NOTICE_ID")|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/grep -c "^this box has 14 GB of this Mac's 16 GB of memory")"
# A notice followed by two steps, the second of them the one it is about.
job_log "$BUILD" "{events: [{event: \"progress\", step: \"base-check\", message: \"Asking cloud.debian.org for the checksum\"},
    {event: \"notice\", message: \"$MEMORY_TEXT\"},
    {event: \"progress\", step: \"unpack\", message: \"Unpacking the disk\"},
    {event: \"progress\", step: \"first-boot\", message: \"First boot: the system installs the guest daemon\"}], lines: []}"
poll 1
check "two steps on, the notice still shows" "From an earlier step: $MEMORY_TEXT" "$(ui_value "$PROGRESS_NOTICE_ID")"
job_state "$BUILD" '{state: "failed", status: 1, endedAt: "2026-09-30T12:04:00Z", error: "the guest stopped"}'
omc_run AgentVM.progress.activated
check "  and after the job failed" "From an earlier step: $MEMORY_TEXT" "$(ui_value "$PROGRESS_NOTICE_ID")"
job_state "$BUILD" '{state: "done", status: 0, error: null}'
omc_run AgentVM.progress.activated
check "  and not after one that ended well" "" "$(ui_value "$PROGRESS_NOTICE_ID")"
# A build agent-vm refused for the Mac's free disk space: no step, and the reason whole, since it
# says what to do.
REFUSAL="cannot build here: 31 GB free on the volume of /Users/you/Library/Application Support/agent-vm; 40 GB free leaves room for the image and for the guest to work"
job_log "$BUILD" '{events: [], lines: []}'
job_state "$BUILD" "{state: \"failed\", status: 1, error: \"$REFUSAL\"}"
omc_run AgentVM.progress.activated
check "a build refused before its first step: the reason whole, and no step" "Image dev-new was not built: $REFUSAL|" "$(ui_value "$PROGRESS_STATUS_ID")|$(steps)"
job_edit "map(if .id == \"$BUILD\" then .state = \"running\" | del(.status) | del(.endedAt) | del(.error) else . end)"
omc_run AgentVM.progress.activated

section "a step that moves on keeps its row"
job_log "$BUILD" '{events: [{event: "progress", step: "install", message: "Installing macOS", fraction: 0.1},
    {event: "progress", step: "install", message: "Installing macOS", fraction: 0.5, expectedSeconds: 185.4}], lines: []}'
poll 1
check "one row, at the newest fraction" "Installing macOS=50%" "$(steps)"
check "the bar follows"              "50" "$(ui_value "$PROGRESS_BAR_ID")"
check "the headline says how long the step took last time" "Installing macOS (it took 3 min last time)" "$(ui_value "$PROGRESS_STATUS_ID")"

section "a long log is cut to its end, and long lines are cut"
/usr/bin/jq -n '{events: ([range(1; 41) | {event: "log", message: ("line " + tostring)}]
    + [{event: "log", message: ("x" * 150), output: true}]), lines: []}' > "$FAKE_AGENTVM_DIR/job-log-$BUILD.json"
poll 1
check "twelve lines"                 "12" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/awk 'END { print NR }')"
check "  the newest ones"            "line 30|line 40" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '1p')|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '11p')"
check "  a line of 150 characters is cut to 100, ending in dots" "100|..." \
    "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '12p' | /usr/bin/awk '{ print length($0) }')|$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '12p' | /usr/bin/sed 's/^x*//')"
check "no progress event yet"        "Started; no step reported yet.|" "$(ui_value "$PROGRESS_STATUS_ID")|$(steps)"

section "text that is not ASCII"
# awk counts bytes, and in a UTF-8 locale it stops at a capital made of part of a character. A line
# cut inside a character is not text any more, and a window given such a value shows nothing new.
E="$(/usr/bin/jq -nr '"\u00e9"')"
job_log "$BUILD" '{events: [{event: "progress", step: "recipe-step", message: "\u00e9crire", index: 1, count: 1},
    {event: "log", message: ("\u00e9" * 120), output: true}], lines: []}'
for locale in C en_US.UTF-8; do
    ui_reset
    omc_control_defaults AgentVM.progress
    ( LC_ALL="$locale"; export LC_ALL; poll 1 )
    check "$locale: a step that begins with such a letter is shown as it is" "${E}crire=running|${E}crire" "$(steps)|$(ui_value "$PROGRESS_STATUS_ID")"
    check "$locale: a long line is cut between characters, to 100 of them" "$(/usr/bin/jq -nr '("\u00e9" * 97) + "..."')" "$(ui_value "$PROGRESS_LOG_ID")"
done

section "agent-vm cannot read the job this time"
/usr/bin/jq '{events, lines}' "$VARIETY" > "$FAKE_AGENTVM_DIR/job-log-$BUILD.json"
poll 1
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-job-log"
poll 1
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-log"
check "what was read before stays"   "[3/3] Agents|6" "$(ui_value "$PROGRESS_STATUS_ID")|$(ui_row_count "$PROGRESS_STEPS_ID")"
check "  and the reason is on the notice line, under the notice" "From an earlier step: Homebrew is already installed in the base image|the store is locked" \
    "$(ui_value "$PROGRESS_NOTICE_ID" | /usr/bin/paste -sd '|' -)"
poll 1
check "the next reading clears it"   "From an earlier step: Homebrew is already installed in the base image" "$(ui_value "$PROGRESS_NOTICE_ID")"

section "Stop..."
alerts_reset
omc_run AgentVM.progress.stop
check "asks first"                   "Stop building image dev-new?" "$(ui_alert_title)"
check "  saying what stopping leaves" "yes" "$(ui_alert_message | /usr/bin/grep -q 'The image is left marked failed' && echo yes)"
check "  Stop in the question confirms" "AgentVM.progress.stop.confirmed" "$(ui_alert_action Stop)"
check "  the job asked about is kept" "$BUILD" "$("$PB" "agentvm_job_stop_$UUID" get)"
check "  nothing is canceled yet"    "0" "$(fake_log | /usr/bin/grep -c '^job cancel')"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_run AgentVM.progress.stop.confirmed
check "confirmed: agent-vm is asked to cancel that job" "job cancel $BUILD --json" "$(fake_log | /usr/bin/sed -n '1p')"
check "  the window says it stopped" "Stopped before it finished." "$(ui_value "$PROGRESS_STATUS_ID")"
check "  the last step is where it stopped" "[3/3] Agents=stopped" "$(steps | /usr/bin/sed 's/.*|//')"
check "  the log ends with why"      "Error: canceled" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '$p')"
check "  Stop... is off, and no loop is started for a job that ended" "0|0" "$(enabled "$PROGRESS_STOP_ID")|$(chain_asked AgentVM.progress.poll)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.progress.stop.confirmed
check "a second confirmation cancels nothing" "0" "$(fake_log | /usr/bin/grep -c '^job cancel')"
asked="$(ui_calls omc_present_alert)"
omc_run AgentVM.progress.stop
check "Stop... on a job that ended asks nothing" "$asked|" "$(ui_calls omc_present_alert)|$("$PB" "agentvm_job_stop_$UUID" get)"

section "a confirmation for another job than the window's"
job_state "$BUILD" '{state: "running"} | del(.endedAt, .error)'
omc_run AgentVM.progress.activated
"$PB" "agentvm_job_stop_$UUID" set "$SETUP"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.progress.stop.confirmed
check "nothing is canceled"          "0" "$(fake_log | /usr/bin/grep -c '^job cancel')"
"$PB" "agentvm_job_stop_$UUID" set '--json'
omc_run AgentVM.progress.stop.confirmed
check "nor for a value that is not a job id" "0" "$(fake_log | /usr/bin/grep -c '^job cancel')"

section "the job ended between the question and the answer"
alerts_reset
omc_run AgentVM.progress.stop
job_state "$BUILD" '{state: "done", status: 0, endedAt: "2026-09-30T12:04:00Z"}'
omc_run AgentVM.progress.stop.confirmed
check "agent-vm's refusal is shown"  "The job was not stopped|job $BUILD is not running" "$(ui_alert_title)|$(ui_alert_message)"
check "  and the window shows how it ended" "Image dev-new is ready.|took 4 min" "$(ui_value "$PROGRESS_STATUS_ID")|$(ui_value "$PROGRESS_ELAPSED_ID")"
omc_run AgentVM.progress.close

section "a job that waits"
# Canceling the build canceled the job queued after it, as agent-vm does: it waits again here.
job_state "$SETUP" '{state: "queued"} | del(.endedAt, .error)'
ui_reset
chains_reset
open_progress "$SETUP"
check "the title"                    "Setting up image dev-new" "$(ui_title)"
check "it says that it waits, with no time" "Waiting for an earlier job to finish.|" "$(ui_value "$PROGRESS_STATUS_ID")|$(ui_value "$PROGRESS_ELAPSED_ID")"
check "it can be stopped, and is followed" "1|1" "$(enabled "$PROGRESS_STOP_ID")|$(chain_asked AgentVM.progress.poll)"
job_state "$SETUP" '{state: "failed", status: 1, startedAt: "2026-09-30T12:04:00Z", endedAt: "2026-09-30T12:04:30Z", error: "the window was closed before Full Disk Access was granted"}'
poll 1
check "it failed: the headline says what did not happen, and why" \
    "The setup of image dev-new did not finish: the window was closed before Full Disk Access was granted" "$(ui_value "$PROGRESS_STATUS_ID")"
check "  the log ends with the error" "Error: the window was closed before Full Disk Access was granted" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/sed -n '$p')"
omc_run AgentVM.progress.close

section "a job agent-vm no longer keeps"
ui_reset
chains_reset
open_progress 20260923-120000-0000ff
check "the window says so"           "yes" "$(ui_value "$PROGRESS_STATUS_ID" | /usr/bin/grep -q 'no job 20260923-120000-0000ff' && echo yes)"
check "  with Stop... off and no loop" "0|0" "$(enabled "$PROGRESS_STOP_ID")|$(chain_asked AgentVM.progress.poll)"
omc_run AgentVM.progress.close

section "the whole log, in Finder and in Console"
# The window shows the end of the log; all of it is the file "log" in the job's folder in the
# store. The fake names a folder that is not on this Mac, so the job is given one made here.
LOGGED="20260930-120000-0000e1"
LOGGED_FOLDER="$OMCTEST_WORK/logs store/Jobs/$LOGGED"
log_buttons() {
    printf '%s %s\n' "$(enabled "$PROGRESS_LOG_SHOW_ID")" "$(enabled "$PROGRESS_LOG_CONSOLE_ID")"
}
opened() {
    /bin/cat "$FAKE_OPEN_LOG"
}
# The jobs the sections around this one work with are put back at its end.
/bin/cp "$JOBS" "$JOBS.kept"
/usr/bin/jq -n --arg id "$LOGGED" '[{id: $id, command: ["image", "create", "dev", "--json"], targets: ["image:dev"], state: "running",
    createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z", path: ("/Users/you/Library/Application Support/agent-vm/Jobs/" + $id)}]' > "$JOBS"
"$PB" "agentvm_window_progress_$LOGGED" set ""
ui_reset
chains_reset
open_progress "$LOGGED"
check "a job whose folder is not on this Mac: both buttons are off" "0 0" "$(log_buttons)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.progress.log.show
omc_run AgentVM.progress.log.console
check "  the handlers, run anyway, open nothing" "" "$(opened)"
/bin/mkdir -p "$LOGGED_FOLDER"
job_edit "map(.path = \"$LOGGED_FOLDER\")"
omc_run AgentVM.progress.activated
check "its folder is on this Mac and holds no log yet: still off" "0 0" "$(log_buttons)"
: > "$LOGGED_FOLDER/log"
omc_run AgentVM.progress.activated
check "its log is there: both are on, while the job runs" "1 1|1" "$(log_buttons)|$(enabled "$PROGRESS_STOP_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.progress.log.show
check "Show Log in Finder selects the job's log" "-R $LOGGED_FOLDER/log" "$(opened)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.progress.log.console
check "Open in Console opens it in Console" "-a Console $LOGGED_FOLDER/log" "$(opened)"
check "  neither asks agent-vm anything" "" "$(fake_log)"
job_edit 'map(. + {state: "failed", status: 1, endedAt: "2026-09-30T12:00:09Z", error: "the build was canceled"})'
omc_run AgentVM.progress.activated
check "the job ended: Stop... is off, and the log's buttons stay on" "0|1 1" "$(enabled "$PROGRESS_STOP_ID")|$(log_buttons)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.progress.log.show
check "  and still show it"          "-R $LOGGED_FOLDER/log" "$(opened)"
job_edit 'map(del(.path))'
omc_run AgentVM.progress.activated
check "a job agent-vm names no folder for: off" "0 0" "$(log_buttons)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.progress.log.show
check "  and nothing opens"          "" "$(opened)"
omc_run AgentVM.progress.close
/bin/mv "$JOBS.kept" "$JOBS"

section "Progress... in the image pane"
job_state "$BUILD" '{state: "running"} | del(.endedAt, .status)'
job_state "$SETUP" '{state: "queued"} | del(.endedAt, .status, .error, .startedAt)'
/usr/bin/jq '.images += [(.images[] | select(.name == "dev-node") | . + {name: "dev-new", state: "provisioning", needs: [], derivedFrom: {image: "dev-node"}})]' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
select_image dev-acp
check "no job holds the image: no Progress..." "0" "$(shown "$MAIN_IMAGE_PROGRESS_ID")"
select_image dev-new
check "a job holds it: the button is there" "1" "$(shown "$MAIN_IMAGE_PROGRESS_ID")"
chains_reset
omc_run AgentVM.main.image.progress
check "a build with a setup waiting after it: the pane and the card show the build" "Building, elapsed 12 s: [3/3] Agents|hammer.fill${TAB}Building - macOS 27.0" \
    "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-new | /usr/bin/cut -f2,3)"
check "it asks for the window of the job that runs, not the one that waits" "1|$APP_PID progress:$BUILD" "$(chain_asked AgentVM.progress)|$(request)"
job_state "$BUILD" '{state: "done", status: 0, endedAt: "2026-09-30T12:05:00Z"}'
/usr/bin/jq '.images += [(.images[] | select(.name == "dev-node") | . + {name: "dev-new", needs: [], derivedFrom: {image: "dev-node"}})]' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
chains_reset
omc_run AgentVM.main.image.progress
check "the build over, the setup still waiting: the pane, the card and the window are the setup's" \
    "Waiting to be set up|Waiting - macOS 27.0 - from dev-node|$APP_PID progress:$SETUP" \
    "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-new | /usr/bin/cut -f3)|$(request)"

# -----------------------------------------------------------------------------------------------
section "a Linux image built from its cloud image (job-log-linux.json, a real build's log)"
# The window has no words of its own for a step: it shows agent-vm's. What a Linux build reports
# that a macOS one does not: a download with its fraction, and setup steps that are numbered.
LINUX_LOG="$FIXTURES_AGENTVM/job-log-linux.json"
LINUX_BUILD="$(/usr/bin/jq -r '.job.id' "$LINUX_LOG")"
"$PB" "agentvm_window_progress_$LINUX_BUILD" set ""
# The job as agent-vm recorded it, set back to when its download was 42% through.
/usr/bin/jq '[.job | del(.endedAt) | del(.status) | .state = "running"]' "$LINUX_LOG" > "$JOBS"
/usr/bin/jq '.events as $all
    | ([$all | to_entries[] | select(.value.step == "download" and (.value.fraction // 0) >= 0.42)][0].key) as $at
    | {events: $all[0:$at + 1], lines: []}' "$LINUX_LOG" > "$FAKE_AGENTVM_DIR/job-log-$LINUX_BUILD.json"
ui_reset
open_progress "$LINUX_BUILD"
check "the title"                    "Building image t" "$(ui_title)"
check "the download is one step, however many times agent-vm reported it, with how far it is" \
    "Asking cloud.debian.org for the checksum of Debian 13's cloud image=done|Downloading debian-13-genericcloud-arm64.tar.xz (217 MB)=42%" "$(steps)"
check "  and the bar follows it"     "1|42" "$(shown "$PROGRESS_BAR_ID")|$(ui_value "$PROGRESS_BAR_ID")"
# The whole log, and the job ended as it did.
/usr/bin/jq '[.job]' "$LINUX_LOG" > "$JOBS"
/usr/bin/jq '{events, lines}' "$LINUX_LOG" > "$FAKE_AGENTVM_DIR/job-log-$LINUX_BUILD.json"
omc_run AgentVM.progress.activated
check "the build over: nineteen steps, each done" "19|19" \
    "$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/awk 'END { print NR }')|$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/awk -F'\t' '$2 == "done"' | /usr/bin/awk 'END { print NR }')"
check "  the numbered setup steps are a row each, in order, with sealing among them where agent-vm began it" \
    "[1/12] wait for the first boot to finish|[2/12] account agent|[3/12] package lists|[4/12] system updates|[5/12] git, jq, unzip, zip|[6/12] the compiler and make (build-essential)|[7/12] git settings|Sealing the image: no ssh server, no background updates, no first-boot setup|[8/12] remove the ssh server, background updates and polkitd|[9/12] no update timers|[10/12] network settings for any card|[11/12] console and boot menu|[12/12] vsock at boot|Shutting down" \
    "$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/cut -f1 | /usr/bin/sed -n '6,19p' | /usr/bin/paste -sd '|' -)"
check "  the end of the log is the end of agent-vm's" "Set up in 68 s" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/tail -1)"
check "  no bar for a job that ended" "0" "$(shown "$PROGRESS_BAR_ID")"
"$PB" "agentvm_window_progress_$LINUX_BUILD" set ""
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-log-$LINUX_BUILD.json"

section "a Debian image built in two boots"
# Since agent-vm 0.7.32 a Debian build installs the kernel with 16 KiB pages first, shuts down and
# boots again on it: a shutdown in the middle, and numbered setup steps on both sides of it. The
# events are made by hand, in the order and the words of a real build's text log (agent-vm 0.7.32).
KERNEL="20260930-120000-0000e1"
"$PB" "agentvm_window_progress_$KERNEL" set ""
/usr/bin/jq -n --arg id "$KERNEL" '[{id: $id, command: ["image", "create", "t17", "--linux", "debian-13", "--json"], targets: ["image:t17"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
# kernel_log <how many events>  ->  the build's log up to that event.
kernel_log() {
    /usr/bin/jq -n --argjson upto "$1" '
        def step(name; text): {event: "progress", image: "t17", step: name, message: text};
        def setup(n; text): step("linux-setup"; "[\(n)/14] \(text)") + {index: n, count: 14, fraction: ((n - 1) / 14)};
        {lines: [], events: ([
            step("base-check"; "Asking cloud.debian.org for the checksum of Debian 13\u0027s cloud image"),
            step("unpack"; "Unpacking the disk"),
            step("first-boot"; "First boot: the system installs the guest daemon"),
            step("guest-daemon"; "The guest daemon answers"),
            setup(1; "wait for the first boot to finish"),
            setup(2; "package lists"),
            setup(3; "kernel with 16 KiB pages (linux-image-arm64-16k)"),
            step("shutdown"; "Shutting down"),
            step("check-boot"; "Booting again on the kernel with 16 KiB pages"),
            {event: "log", image: "t17", message: "kernel 6.12.111+deb13-arm64-16k, 16 KiB pages"},
            setup(4; "wait for the boot on the new kernel"),
            setup(5; "account agent"),
            setup(6; "system updates"),
            setup(7; "git, jq, unzip, zip"),
            setup(8; "git settings"),
            step("seal"; "Sealing the image: no ssh server, no background updates, no first-boot setup"),
            setup(9; "remove the ssh server, background updates and polkitd"),
            setup(10; "no update timers"),
            setup(11; "network settings for any card"),
            setup(12; "console and boot menu"),
            setup(13; "vsock at boot"),
            setup(14; "stop at a kernel fault"),
            step("shutdown"; "Shutting down")
        ][0:$upto])}' > "$FAKE_AGENTVM_DIR/job-log-$KERNEL.json"
}
kernel_log 8
ui_reset
alerts_reset
open_progress "$KERNEL"
check "the shutdown in the middle is a step like another, and the build goes on" \
    "[3/14] kernel with 16 KiB pages (linux-image-arm64-16k)=done|Shutting down=running|Shutting down" \
    "$(steps | /usr/bin/tr '|' '\n' | /usr/bin/tail -2 | /usr/bin/paste -sd '|' -)|$(ui_value "$PROGRESS_STATUS_ID")"
check "  Stop is on, and the window says the job goes on" "1|yes" \
    "$(enabled "$PROGRESS_STOP_ID")|$(ui_value "$PROGRESS_FOOTER_ID" | /usr/bin/grep -q 'the job goes on' && echo yes)"
kernel_log 11
omc_run AgentVM.progress.activated
check "the boot on the new kernel, and the setup steps go on where they stopped" \
    "Shutting down=done|Booting again on the kernel with 16 KiB pages=done|[4/14] wait for the boot on the new kernel=21%" \
    "$(steps | /usr/bin/tr '|' '\n' | /usr/bin/tail -3 | /usr/bin/paste -sd '|' -)"
kernel_log 23
job_state "$KERNEL" '{state: "done", status: 0, endedAt: "2026-09-30T12:37:19Z"}'
omc_run AgentVM.progress.activated
check "the build over: twenty-two steps, the shutdown twice, each done" "22|2|22" \
    "$(ui_row_count "$PROGRESS_STEPS_ID")|$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/grep -c '^Shutting down')|$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/awk -F'\t' '$2 == "done"' | /usr/bin/awk 'END { print NR }')"
"$PB" "agentvm_window_progress_$KERNEL" set ""
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-log-$KERNEL.json"

section "an update that gives a Debian image another kernel first"
# `image update --system` of a Debian image built before agent-vm 0.7.30 installs the kernel with
# 16 KiB pages, shuts down and boots on it before the package updates. Nothing is put in place
# until the end, so it is not an update whose guest daemon went first. The events are made by
# hand, in the order and the words of a real update's text log (agent-vm 0.7.32).
SWITCH="20260930-120000-0000e2"
"$PB" "agentvm_window_progress_$SWITCH" set ""
/usr/bin/jq -n --arg id "$SWITCH" '[{id: $id, command: ["image", "update", "deb", "--system", "--json"], targets: ["image:deb"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
/usr/bin/jq -n '
    def step(name; text): {event: "progress", image: "deb", step: name, message: text};
    def setup(n; of; text): step("linux-setup"; "[\(n)/\(of)] \(text)") + {index: n, count: of};
    {lines: [], events: [
        step("boot"; "Booting a copy of deb"),
        {event: "notice", image: "deb", message: "note: Debian 13\u0027s kernel with 16 KiB pages takes the place of the one with 4 KiB pages"},
        setup(1; 3; "wait for the network"),
        setup(2; 3; "package lists"),
        setup(3; 3; "kernel with 16 KiB pages (linux-image-arm64-16k)"),
        step("shutdown"; "Shutting down"),
        step("check-boot"; "Booting again on the kernel with 16 KiB pages"),
        step("system-update"; "Installing Debian 13\u0027s package updates"),
        setup(1; 4; "wait for the network"),
        setup(2; 4; "package lists")]}' > "$FAKE_AGENTVM_DIR/job-log-$SWITCH.json"
ui_reset
alerts_reset
open_progress "$SWITCH"
check "the steps: the setup steps of the kernel and those of the updates are rows of their own" \
    "Booting a copy of deb=done|[1/3] wait for the network=done|[2/3] package lists=done|[3/3] kernel with 16 KiB pages (linux-image-arm64-16k)=done|Shutting down=done|Booting again on the kernel with 16 KiB pages=done|Installing Debian 13's package updates=done|[1/4] wait for the network=done|[2/4] package lists=running" "$(steps)"
check "  agent-vm's note of the kernel stays in view" "From an earlier step: note: Debian 13's kernel with 16 KiB pages takes the place of the one with 4 KiB pages" "$(ui_value "$PROGRESS_NOTICE_ID")"
omc_run AgentVM.progress.stop
check "  stopping after the boot on the new kernel still leaves the image as it was" "yes" "$(ui_alert_message | /usr/bin/grep -q 'The image stays as it was before the update\.$' && echo yes)"
job_state "$SWITCH" '{state: "failed", status: 1, endedAt: "2026-09-30T12:30:00Z", error: "apt-get failed"}'
omc_run AgentVM.progress.activated
check "  and one that fails there says nothing of a guest daemon" "Image deb was not updated: apt-get failed" "$(ui_value "$PROGRESS_STATUS_ID")"
"$PB" "agentvm_window_progress_$SWITCH" set ""
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-log-$SWITCH.json"

section "an update whose guest daemon goes first"
# agent-vm updates the guest daemon first, as an update of its own, when it was asked for with the
# system or the tools: one job boots and puts a disk in place twice. The events are made by hand,
# in the order and the words of agent-vm 0.7.26.
TWICE="20260930-120000-0000d1"
"$PB" "agentvm_window_progress_$TWICE" set ""
/usr/bin/jq -n --arg id "$TWICE" '[{id: $id, command: ["image", "update", "dev", "--tools", "--guest", "--json"], targets: ["image:dev"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
# twice_log <how many events>  ->  the job's log up to that event.
twice_log() {
    /usr/bin/jq -n --argjson upto "$1" '
        def step(name; text): {event: "progress", image: "dev", step: name, message: text};
        {lines: [], events: ([
            step("boot"; "Booting a copy of dev"),
            step("replace-guest-daemon"; "Replacing agent-vm-guest"),
            step("shutdown"; "Shutting down"),
            step("check-guest-daemon"; "Booting again to check the new agent-vm-guest"),
            step("shutdown"; "Shutting down"),
            step("commit"; "Putting the updated disk in place"),
            {event: "log", image: "dev", message: "Recipe python: this agent-vm has a newer one than dev keeps; it is used, and kept when the update succeeds (--kept-recipes runs the old one)"},
            step("boot"; "Booting a copy of dev"),
            (step("tools-update"; "Updating the tools of python") + {index: 1, count: 1}),
            step("shutdown"; "Shutting down"),
            step("commit"; "Putting the updated disk in place"),
            {event: "log", image: "dev", message: "  dev keeps the new python recipe"}
        ][0:$upto])}' > "$FAKE_AGENTVM_DIR/job-log-$TWICE.json"
}
twice_log 6
ui_reset
alerts_reset
open_progress "$TWICE"
check "the daemon's update is being put in place: its steps, each a row" \
    "Booting a copy of dev=done|Replacing agent-vm-guest=done|Shutting down=done|Booting again to check the new agent-vm-guest=done|Shutting down=done|Putting the updated disk in place=running" "$(steps)"
omc_run AgentVM.progress.stop
check "  stopping now leaves the image as it was" "yes" "$(ui_alert_message | /usr/bin/grep -q 'The image stays as it was before the update\.$' && echo yes)"
twice_log 9
omc_run AgentVM.progress.activated
check "the tools' update has begun: the boot is a row again, after the disk put in place" \
    "Putting the updated disk in place=done|Booting a copy of dev=done|Updating the tools of python=running" \
    "$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/sed -n '6,$p' | /usr/bin/awk -F'\t' '{ printf "%s%s=%s", (NR > 1 ? "|" : ""), $1, $2 }')"
check "  the log names the recipe agent-vm replaced" "1" "$(ui_value "$PROGRESS_LOG_ID" | /usr/bin/grep -c '^Recipe python: this agent-vm has a newer one than dev keeps')"
alerts_reset
omc_run AgentVM.progress.stop
check "  stopping now leaves the new daemon, and the question says so" "yes" \
    "$(ui_alert_message | /usr/bin/grep -q 'The guest daemon is already updated, and stays; the rest of the image stays as it was\.$' && echo yes)"
job_state "$TWICE" '{state: "failed", status: 1, endedAt: "2026-09-30T12:04:00Z", error: "the check of python failed: python3 is 3.9.6"}'
omc_run AgentVM.progress.activated
check "the tools' update failed: the status says what stays" \
    "Image dev was not updated: the check of python failed: python3 is 3.9.6. The guest daemon was updated before that, and stays." "$(ui_value "$PROGRESS_STATUS_ID")"
check "  and the step it failed at" "Updating the tools of python=failed" "$(steps | /usr/bin/tr '|' '\n' | /usr/bin/tail -1)"
job_state "$TWICE" '{state: "canceled", status: 143, error: null}'
omc_run AgentVM.progress.activated
check "stopped there: the same" "Stopped before it finished. The guest daemon was updated before that, and stays." "$(ui_value "$PROGRESS_STATUS_ID")"
twice_log 12
job_state "$TWICE" '{state: "done", status: 0}'
omc_run AgentVM.progress.activated
check "both updates done: ten rows, the boot and the disk put in place twice each" "10|2|2|Image dev is up to date." \
    "$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/awk 'END { print NR }')|$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/grep -c '^Booting a copy of dev')|$(ui_rows "$PROGRESS_STEPS_ID" | /usr/bin/grep -c '^Putting the updated disk in place')|$(ui_value "$PROGRESS_STATUS_ID")"
# One update only, failed after its guest daemon was replaced in the copy: nothing was put in place.
/usr/bin/jq -n '
    def step(name; text): {event: "progress", image: "dev", step: name, message: text};
    {lines: [], events: [step("boot"; "Booting a copy of dev"), step("replace-guest-daemon"; "Replacing agent-vm-guest"), step("shutdown"; "Shutting down")]}' \
    > "$FAKE_AGENTVM_DIR/job-log-$TWICE.json"
job_state "$TWICE" '{state: "failed", status: 1, error: "the guest did not shut down"}'
omc_run AgentVM.progress.activated
check "an update that put nothing in place says nothing of what stays" "Image dev was not updated: the guest did not shut down" "$(ui_value "$PROGRESS_STATUS_ID")"
"$PB" "agentvm_window_progress_$TWICE" set ""
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-log-$TWICE.json"

section "the words"
words() { ( . "$APP_SCRIPTS/lib.agentvm.progress.sh" >/dev/null 2>&1; "$@" ); }
row() { printf 'id\trunning\t%s\t%s\n' "$1" "$2"; }
check "titles" "Stopping box s3|Updating image dev|Updating image dev|Downloading the macOS restore file|agent-vm box send" \
    "$(words progress_title "$(row box:s3 "box stop")")|$(words progress_title "$(row image:dev "image update")")|$(words progress_title "$(row image:dev "image update-guest")")|$(words progress_title "$(row ipsw "image fetch-ipsw")")|$(words progress_title "$(row box:s3 "box send")")"
check "what stopping an update leaves" "yes" "$(words progress_stop_question "$(row image:dev "image update")" | /usr/bin/grep -q 'stays as it was' && echo yes)"
check "what stopping a download leaves" "yes" "$(words progress_stop_question "$(row ipsw "image fetch-ipsw")" | /usr/bin/grep -q 'kept for the next time' && echo yes)"

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
