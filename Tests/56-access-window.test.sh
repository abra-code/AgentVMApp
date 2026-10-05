#!/bin/sh
# Tests/56-access-window.test.sh - an image's Full Disk Access guide: Set Up... in the image pane,
# one window per image and only when this run of the app asked for it, what the guide says about
# an image that needs the grant and one that has it, Open the Image (the setup job it starts, with
# the command line shown), the four steps following the job, how a setup ended, what stands in
# the way, and the question the main window asks when an update took an image's grant away.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json, where
# dev-node and dev-xcode need Full Disk Access and dev-acp does not. A job never moves by itself:
# the test edits jobs.json for its steps and its end. The clock is fixed at 12 seconds after the
# fake's jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.access.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_ACCESS_ID" ] && [ -n "$MAIN_IMAGE_STATE_ID" ] && [ -n "$MAIN_IMAGE_MAINTENANCE_ID" ] \
    && [ -n "$ACCESS_TITLE_ID" ] && [ -n "$ACCESS_STATE_ID" ] && [ -n "$ACCESS_PENDING_ID" ] && [ -n "$ACCESS_NOW_ID" ] \
    && [ -n "$ACCESS_DONE_ID" ] && [ -n "$ACCESS_STATUS_ID" ] && [ -n "$ACCESS_AFTER_ID" ] && [ -n "$ACCESS_COMMAND_ID" ] \
    && [ -n "$ACCESS_NOTE_ID" ] && [ -n "$ACCESS_PROGRESS_ID" ] && [ -n "$ACCESS_OPEN_ID" ] || {
    printf '56-access-window: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
# 2026-09-30T12:00:12Z: the fake's jobs start at 12:00:00.
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
VERSION="$(lib_value AGENTVM_MIN_VERSION)"
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?56-access-window: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-access-window-$$"
OTHER_UUID="OMCTEST-other-access-window-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
# The fake's first job.
FIRST="20260930-120001-000001"
# A setup someone else started: in Terminal, or before the window opened.
THEIRS="20260930-120000-0000a1"
# dev-node as it is once the grant is made: it still needs its guest update.
GRANTED='(.images[] | select(.name == "dev-node")).needs = [{kind: "guest-update", missing: ["terminal-pixels"]}]'

# in_window <uuid>  ->  the handlers that follow run in that window.
in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

request() {
    "$PB" agentvm_open_request_access get
}

# registered <image>  ->  the pasteboard entry naming that image's guide.
registered() {
    "$PB" "agentvm_window_access_$1" get
}

# open_access <image> [uuid]  ->  that image's guide opened the way Set Up... opens it: the
# request, then the window's init handler, in a window of its own.
open_access() {
    "$PB" agentvm_open_request_access set "$APP_PID access:$1"
    in_window "${2:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.access
    omc_run AgentVM.access.init
}

select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

enabled() {
    [ "$(ui_enabled "$1" "${2:-}")" = "1" ] && echo 1 || echo 0
}

# marks  ->  the four steps' marks as the window shows them: to do, now or done each.
marks() {
    local _step _out=""
    for _step in 1 2 3 4; do
        case "$(ui_visible $((ACCESS_PENDING_ID + _step)))$(ui_visible $((ACCESS_NOW_ID + _step)))$(ui_visible $((ACCESS_DONE_ID + _step)))" in
            100) _out="$_out todo" ;;
            010) _out="$_out now" ;;
            001) _out="$_out done" ;;
            *)   _out="$_out ?" ;;
        esac
    done
    printf '%s\n' "${_out# }"
}

# started  ->  the jobs agent-vm was asked to start.
started() {
    fake_log | /usr/bin/grep '^job start' | /usr/bin/paste -sd '|' -
}

# job_edit <id> <jq object>  ->  that job, changed: its step, or its end.
job_edit() {
    /usr/bin/jq --arg id "$1" "map(if .id == \$id then . + $2 else . end)" "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
}
job_step() {
    job_edit "$1" "{progress: {event: \"progress\", step: \"$2\", message: \"agent-vm's own words, which the guide does not read\"}}"
}
job_end() {
    job_edit "$1" "{state: \"$2\", status: ${3:-0}, endedAt: \"2026-09-30T12:05:00Z\"}"
}

# their_setup <image> <state> [step]  ->  the store holds a setup job on that image that this app
# did not start.
their_setup() {
    /usr/bin/jq -n --arg id "$THEIRS" --arg image "$1" --arg state "$2" --arg step "${3:-}" '
        [ { id: $id, command: ["image", "setup", $image, "--json"], targets: ["image:" + $image], state: $state,
            createdAt: "2026-09-30T12:00:00Z" }
          | if $state == "running" then .startedAt = "2026-09-30T12:00:00Z" else .after = "20260930-115900-0000b1" end
          | if $step != "" then .progress = {event: "progress", step: $step, message: "x"} else . end ]' > "$JOBS"
}

# poll_once  ->  one pass of the guide's poll loop.
poll_once() {
    ( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.access.poll )
}

fake_reset
store '.'
for image in dev dev-acp dev-node dev-xcode latest-test; do
    "$PB" "agentvm_window_access_$image" set ""
done
"$PB" agentvm_open_request_access set ""
"$PB" agentvm_open_request_progress set ""
: > "$FAKE_SLEEP_LOG"

# -----------------------------------------------------------------------------------------------
section "Set Up... in the image pane"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
omc_run AgentVM.main.image.access
check "no image selected: the handler opens nothing" "0|" "$(chain_asked AgentVM.access)|$(request)"
select_image latest-test
check "a failed image cannot be set up" "0" "$(enabled "$MAIN_IMAGE_ACCESS_ID")"
select_image dev-node
check "a ready image can"            "1" "$(enabled "$MAIN_IMAGE_ACCESS_ID")"
check "having none is not maintenance: the pane's Full Disk Access row is what says it" \
    "" \
    "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/grep 'Full Disk Access')"
omc_run AgentVM.main.image.access
check "it asks for the image's guide" "1" "$(chain_asked AgentVM.access)"
check "  for the selected image, from this run of the app" "$APP_PID access:dev-node" "$(request)"
"$PB" agentvm_open_request_access set ""
their_setup dev-node running boot
omc_run AgentVM.main.activated
check "an image being set up can still open its guide, which follows the setup" "1" "$(enabled "$MAIN_IMAGE_ACCESS_ID")"
/bin/rm -f "$JOBS"
omc_run AgentVM.main.activated

section "the guide opens on an image that needs the grant"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
open_access dev-node
check_status "the init handler exits cleanly" 0
check "takes the request, once"      "" "$(request)"
check "becomes the image's guide"    "$APP_PID $UUID" "$(registered dev-node)"
check "asks agent-vm which it is, and reads status once" "--version|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the title names the image"    "Full Disk Access for image dev-node|Full Disk Access for image dev-node" "$(ui_title)|$(ui_value "$ACCESS_TITLE_ID")"
check "it does not have the grant"   "agent-vm-guest does not have Full Disk Access in this image yet." "$(ui_value "$ACCESS_STATE_ID")"
check "all four steps are to do"     "todo todo todo todo" "$(marks)"
check "nothing happens yet"          "" "$(ui_value "$ACCESS_STATUS_ID")"
check "afterwards: the images built from it so far are named" \
    "Boxes and images made from it after the grant have it.|Images built from it so far (dev-acp and dev-agents) do not get it: each is set up by itself.|An update that replaces the image's guest daemon may take the grant away; the image then says that it needs it again." \
    "$(ui_value "$ACCESS_AFTER_ID" | /usr/bin/paste -sd '|' -)"
check "the command it would run"     "agent-vm image setup dev-node" "$(ui_value "$ACCESS_COMMAND_ID")"
check "nothing stands in the way: no note, Open the Image is on, and there is no job to show" "|1|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")|$(ui_visible "$ACCESS_PROGRESS_ID")"
check "no setup runs: no poll loop"  "0" "$(chain_asked AgentVM.access.poll)"

section "a second Set Up... on the same image, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.image.access
check "opens no second window"       "0" "$(chain_asked AgentVM.access)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
"$PB" agentvm_open_request_access set "$APP_PID access:dev-node"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.access
omc_run AgentVM.access.init
check "a second window for the same image: the first stays the image's, the second closes" "$APP_PID $UUID|1" \
    "$(registered dev-node)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
for bad in "" "$APP_PID update:dev-node" "1 access:dev-node" "$APP_PID access:../x" "$APP_PID access:Dev" "$APP_PID access:--json"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_access set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.access
    omc_run AgentVM.access.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "|" "$("$PB" "agentvm_image_$OTHER_UUID" get)|$("$PB" "agentvm_job_$OTHER_UUID" get)"
done

section "Open the Image: the setup job"
open_access dev-node
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
alerts_reset
shown_command="$(ui_value "$ACCESS_COMMAND_ID")"
"$PB" "agentvm_busy_$UUID" set "click-$$"
omc_run AgentVM.access.open
check "Open the Image while another click is worked on: agent-vm is not run" "" "$(fake_log)"
"$PB" "agentvm_busy_$UUID" set ""
omc_run AgentVM.access.open
check_status "exits cleanly" 0
check "status is read first, then the setup is started as a job" \
    "status --json|job start --json -- image setup dev-node" "$(fake_log | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$shown_command" "agent-vm $(started | /usr/bin/sed 's/^job start --json -- //')"
check "the guide follows the job"    "$FIRST" "$("$PB" "agentvm_job_$UUID" get)"
check "step 1 is being done"         "now todo todo todo" "$(marks)"
check "  and the guide says what to expect" "Starting the image. Its window opens in about a minute." "$(ui_value "$ACCESS_STATUS_ID")"
check "Open the Image is off, and Progress... is there" "0|1" "$(enabled "$ACCESS_OPEN_ID")|$(ui_visible "$ACCESS_PROGRESS_ID")"
check "the poll loop is chained"     "1" "$(chain_asked AgentVM.access.poll)"
check "no alert, and the guide stays open" "|0" "$(ui_alert_title)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "the main window read the lists again, and follows the job" "Setting up, elapsed 12 s" "$(ui_value "$MAIN_IMAGE_STATE_ID" "$MAIN_UUID")"
check "  it watches the job, so its end is said" "$FIRST" "$(/usr/bin/grep -x "$FIRST" "$TMPDIR/AgentVM/$MAIN_UUID/jobs-watched")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check "Open the Image, clicked again, starts no second setup" "" "$(started)"

section "Progress..."
chains_reset
omc_run AgentVM.access.progress
check "asks for the job's progress window" "1|$APP_PID progress:$FIRST" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
"$PB" agentvm_open_request_progress set ""

section "the steps follow the job"
job_step "$FIRST" full-disk-access
: > "$FAKE_AGENTVM_DIR/log"
: > "$FAKE_SLEEP_LOG"
poll_once
check "the loop waits 2 seconds, then reads status" "2|status --json" "$(/bin/cat "$FAKE_SLEEP_LOG")|$(fake_log)"
check "the image's window is open: step 1 is done, the other three are the person's" "done now now now" "$(marks)"
check "  and the guide says where to do them" \
    "The image's window is open. Do steps 2 to 4 in it: a note at its top says when the grant is seen." "$(ui_value "$ACCESS_STATUS_ID")"
check "  the image's record does not have the grant yet" "agent-vm-guest does not have Full Disk Access in this image yet." "$(ui_value "$ACCESS_STATE_ID")"
job_step "$FIRST" shutdown
poll_once
check "the window was closed: only the last step is known to be happening" "done todo todo now" "$(marks)"
check "  and the guide says so"      "The image is shutting down, and agent-vm records whether the grant was made." "$(ui_value "$ACCESS_STATUS_ID")"
check "Open the Image stays off while the setup runs" "0" "$(enabled "$ACCESS_OPEN_ID")"

section "the grant was made"
job_end "$FIRST" done
store "$GRANTED"
poll_once
check "all four steps are done"      "done done done done" "$(marks)"
check "the guide says so, and for whom" "Granted. Boxes made from dev-node from now on have it." "$(ui_value "$ACCESS_STATUS_ID")"
check "  the image's record has it"  "agent-vm-guest has Full Disk Access in this image." "$(ui_value "$ACCESS_STATE_ID")"
check "afterwards: which of its boxes and images were made before is not known now" \
    "Boxes made from it since the grant have it. A box made earlier gets it when it is recreated.|Images built from it since the grant have it too. An image built earlier is set up by itself." \
    "$(ui_value "$ACCESS_AFTER_ID" | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "Open the Image is on again, and Progress... stays, for the job's log" "1|1" "$(enabled "$ACCESS_OPEN_ID")|$(ui_visible "$ACCESS_PROGRESS_ID")"
: > "$FAKE_SLEEP_LOG"
# Three passes at most, so that a loop that does not end by itself fails the check and ends.
( AGENTVM_APP_POLL_PASSES=3; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.access.poll )
check "with no setup on the image the loop ends without waiting, and gives up its token" "|" "$(/bin/cat "$FAKE_SLEEP_LOG")|$("$PB" "agentvm_poll_$UUID" get)"
in_window "$MAIN_UUID"
alerts_reset
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "the main window says the setup ended, and its pane no longer asks for the grant" "1|0" \
    "$(ui_calls 'omc_present_toast The setup of image dev-node is done. 5')|$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/grep -c 'Full Disk Access')"
check "  with no question: nothing was lost" "0|" "$(ui_calls omc_present_alert)|$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
in_window "$UUID"
omc_run AgentVM.access.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "the image's window was closed without the grant"
store '.'
open_access dev-node
omc_run AgentVM.access.open
job_end "$FIRST" done
omc_run AgentVM.access.activated
check "the steps are to do again, and the guide says so" "todo todo todo todo|Not granted yet. Open the Image starts again.|1" \
    "$(marks)|$(ui_value "$ACCESS_STATUS_ID")|$(enabled "$ACCESS_OPEN_ID")"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"
omc_run AgentVM.access.open
job_end "$FIRST" canceled 143
omc_run AgentVM.access.activated
check "a setup stopped from its progress window: the same, by the image's record" "Not granted yet. Open the Image starts again.|1" \
    "$(ui_value "$ACCESS_STATUS_ID")|$(enabled "$ACCESS_OPEN_ID")"
omc_run AgentVM.access.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "a setup that fails within the moment"
# The job has failed by the time status is read: the guide follows it from its start, so how it
# ended is said though no reading ever found it on the image.
printf 'failed\n' > "$FAKE_AGENTVM_DIR/job-start-state"
printf 'no virtual machine slot is free\n' > "$FAKE_AGENTVM_DIR/job-start-error"
open_access dev-node
chains_reset
in_window "$MAIN_UUID"
alerts_reset
in_window "$UUID"
omc_run AgentVM.access.open
/bin/rm -f "$FAKE_AGENTVM_DIR/job-start-state" "$FAKE_AGENTVM_DIR/job-start-error"
check "the job was started"          "job start --json -- image setup dev-node" "$(started | /usr/bin/sed 's/.*|//')"
check "the guide says that it did not finish, and why" "The setup did not finish: no virtual machine slot is free" "$(ui_value "$ACCESS_STATUS_ID")"
check "  the steps are to do, Open the Image is on again, and no loop is chained" "todo todo todo todo|1|0" \
    "$(marks)|$(enabled "$ACCESS_OPEN_ID")|$(chain_asked AgentVM.access.poll)"
check "the main window says it too"  "The setup of image dev-node did not finish|no virtual machine slot is free" \
    "$(ui_alert_title "$MAIN_UUID")|$(ui_alert_message "$MAIN_UUID")"
omc_run AgentVM.access.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "an image that has the grant"
open_access dev-acp
check "its record says so"           "agent-vm-guest has Full Disk Access in this image." "$(ui_value "$ACCESS_STATE_ID")"
check "all four steps are done, and nothing is left" \
    "done done done done|Nothing is left to do. Open the Image still shows its screen, for any other one-time step." \
    "$(marks)|$(ui_value "$ACCESS_STATUS_ID")"
check "Open the Image is on all the same, with no job to show" "1|0" "$(enabled "$ACCESS_OPEN_ID")|$(ui_visible "$ACCESS_PROGRESS_ID")"
chains_reset
omc_run AgentVM.access.progress
check "Progress..., with no job followed, opens nothing" "0|" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
omc_run AgentVM.access.close

section "a setup that was started elsewhere"
their_setup dev-xcode running full-disk-access
chains_reset
open_access dev-xcode
check "the guide finds it on the image, and follows it" "$THEIRS|done now now now" "$("$PB" "agentvm_job_$UUID" get)|$(marks)"
check "  with the poll loop, Progress..., and Open the Image off" "1|1|0" \
    "$(chain_asked AgentVM.access.poll)|$(ui_visible "$ACCESS_PROGRESS_ID")|$(enabled "$ACCESS_OPEN_ID")"
check "  and no note: the steps say what holds the image" "" "$(ui_value "$ACCESS_NOTE_ID")"
check "afterwards: the image built from it so far" \
    "Images built from it so far (dev-xcode-ios) do not get it: each is set up by itself." "$(ui_value "$ACCESS_AFTER_ID" | /usr/bin/sed -n '2p')"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check "Open the Image, clicked anyway, starts nothing" "" "$(started)"
omc_run AgentVM.access.close
their_setup dev-xcode queued
chains_reset
open_access dev-xcode
check "one that waits for another job: the steps are to do, and the guide says what it waits for" \
    "todo todo todo todo|Waiting for an earlier job to finish. The image opens after it.|0|1" \
    "$(marks)|$(ui_value "$ACCESS_STATUS_ID")|$(enabled "$ACCESS_OPEN_ID")|$(chain_asked AgentVM.access.poll)"
omc_run AgentVM.access.close
/bin/rm -f "$JOBS"

section "coming back to the window"
store '.'
open_access dev-node
store "$GRANTED"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_run AgentVM.access.activated
check "status is read again"         "status --json" "$(fake_log)"
check "a grant made meanwhile, in Terminal, is shown, with no setup of this window's to speak of" \
    "done done done done|Nothing is left to do. Open the Image still shows its screen, for any other one-time step." \
    "$(marks)|$(ui_value "$ACCESS_STATUS_ID")"
check "no setup runs: no poll loop"  "0" "$(chain_asked AgentVM.access.poll)"
store '.'
their_setup dev-node running boot
omc_run AgentVM.access.activated
check "a setup started meanwhile is followed, with a poll loop" "$THEIRS|now todo todo todo|1" \
    "$("$PB" "agentvm_job_$UUID" get)|$(marks)|$(chain_asked AgentVM.access.poll)"
"$PB" "agentvm_poll_$UUID" set "poll-$$"
chains_reset
omc_run AgentVM.access.activated
check "a loop that still runs is not doubled" "0" "$(chain_asked AgentVM.access.poll)"
# A loop that was killed leaves its token behind: the process it names is gone.
/usr/bin/true &
dead_pid=$!
wait "$dead_pid"
"$PB" "agentvm_poll_$UUID" set "poll-$dead_pid"
chains_reset
omc_run AgentVM.access.activated
check "a loop that was killed is replaced" "1" "$(chain_asked AgentVM.access.poll)"
"$PB" "agentvm_poll_$UUID" set ""
: > "$FAKE_AGENTVM_DIR/log"
: > "$FAKE_SLEEP_LOG"
( FAKE_SLEEP_TAKE_TOKEN="poll-newer"; AGENTVM_APP_POLL_PASSES=3; export FAKE_SLEEP_TAKE_TOKEN AGENTVM_APP_POLL_PASSES; omc_run AgentVM.access.poll )
check "a newer loop takes over: the old one waits once, reads nothing more, and leaves the newer token" "2||poll-newer" \
    "$(/bin/cat "$FAKE_SLEEP_LOG")|$(fake_log)|$("$PB" "agentvm_poll_$UUID" get)"
"$PB" "agentvm_poll_$UUID" set ""
/bin/rm -f "$JOBS"

section "what stands in the way"
store '.runningVMs.count = 2'
omc_run AgentVM.access.activated
check "no virtual machine slot is free" \
    "2 of 2 virtual machines are running, and the image needs one to start: stop a box, or wait for a build to end.|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check "  Open the Image, clicked anyway, starts nothing" "" "$(started)"
store '(.images[] | select(.name == "dev-node")).updating = true'
omc_run AgentVM.access.activated
check "another command is changing the image" "Another agent-vm command is changing this image now. It can be opened when that ends.|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")"
store '.'
/usr/bin/jq -n '[{id: "20260930-120000-0000e1", command: ["image", "update", "dev-node", "--guest", "--json"], targets: ["image:dev-node"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
chains_reset
omc_run AgentVM.access.activated
check "a job of another kind holds the image" "A job holds this image now (Updating, elapsed 12 s). It can be opened when the job ends.|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")"
check "  the steps are to do, it is not followed, and no loop runs for it" "todo todo todo todo|0|0" \
    "$(marks)|$(ui_visible "$ACCESS_PROGRESS_ID")|$(chain_asked AgentVM.access.poll)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check "  Open the Image starts nothing" "" "$(started)"
/bin/rm -f "$JOBS"
store '(.images[] | select(.name == "dev-node")) |= . + {state: "failed", failure: "the build was canceled", needs: []}'
omc_run AgentVM.access.activated
check "the image is not ready"       "Only a ready image can be opened, and this one is not: Failed: the build was canceled.|Failed: the build was canceled.|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(ui_value "$ACCESS_STATE_ID")|$(enabled "$ACCESS_OPEN_ID")"
store '.images |= map(select(.name != "dev-node"))'
omc_run AgentVM.access.activated
check "the image is gone"            "There is no image named dev-node any more.|||0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(ui_value "$ACCESS_STATE_ID")|$(ui_value "$ACCESS_AFTER_ID")|$(enabled "$ACCESS_OPEN_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check "  Open the Image starts nothing" "" "$(started)"
store '.'
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.access.activated
check "agent-vm cannot be read"      "agent-vm could not list the images: the store is locked by another agent-vm|0" \
    "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.access.activated
check "  and when it can again, the note goes and Open the Image is back" "|1" "$(ui_value "$ACCESS_NOTE_ID")|$(enabled "$ACCESS_OPEN_ID")"
omc_run AgentVM.access.close
printf '0.1.0\n' > "$FAKE_AGENTVM_DIR/version"
: > "$FAKE_AGENTVM_DIR/log"
open_access dev-node
check "an agent-vm that is too old is not asked for status" "--version" "$(fake_log)"
check "  the window says why, and Open the Image is off" "yes|0" \
    "$(ui_value "$ACCESS_NOTE_ID" | /usr/bin/grep -q "AgentVM needs agent-vm $VERSION or newer" && echo yes)|$(enabled "$ACCESS_OPEN_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/version"
omc_run AgentVM.access.close

section "agent-vm refuses the job"
open_access dev-node
printf 'image setup shows the image'"'"'s screen, so it needs a login session on this Mac (not SSH)\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
chains_reset
alerts_reset
omc_run AgentVM.access.open
check "an alert, in agent-vm's words" "Image dev-node was not opened|image setup shows the image's screen, so it needs a login session on this Mac (not SSH)" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "nothing is followed, no loop is chained, and Open the Image is on again" "|0|1" \
    "$("$PB" "agentvm_job_$UUID" get)|$(chain_asked AgentVM.access.poll)|$(enabled "$ACCESS_OPEN_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"

section "only for its image, and only a job id"
: > "$FAKE_AGENTVM_DIR/log"
"$PB" "agentvm_image_$UUID" set "--json"
omc_run AgentVM.access.open
check "an image name that is not one starts nothing" "" "$(fake_log)"
"$PB" "agentvm_image_$UUID" set dev-node
"$PB" "agentvm_job_$UUID" set "--after x"
chains_reset
omc_run AgentVM.access.progress
check "a job id that is not one opens no progress window" "0|" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
"$PB" "agentvm_job_$UUID" set ""

section "closing"
check "  and starts nothing"         "" "$(started)"
omc_run AgentVM.access.open
check "a setup runs when the window closes" "$FIRST" "$("$PB" "agentvm_job_$UUID" get)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.close
check "closing: the image has no guide, the window keeps nothing, and its loop is told" "|||closed" \
    "$(registered dev-node)|$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_job_$UUID" get)|$("$PB" "agentvm_poll_$UUID" get)"
check "  its cache is gone"          "" "$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)"
check "  the setup is not stopped: the image's own window ends it" "" "$(fake_log)"
: > "$FAKE_SLEEP_LOG"
( AGENTVM_APP_POLL_PASSES=3; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.access.poll )
check "a loop chained before the window closed does nothing" "|closed" "$(/bin/cat "$FAKE_SLEEP_LOG")|$("$PB" "agentvm_poll_$UUID" get)"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "the window closes while agent-vm is read"
# An agent-vm that, asked for status, first does what closing the window does: the close button,
# clicked while Open the Image waits for agent-vm.
CLOSING="$OMCTEST_WORK/closing_agent_vm.sh"
printf '#!/bin/sh\n[ "$1" = "status" ] && /bin/sh "%s/AgentVM.access.close.sh"\nexec "%s" "$@"\n' "$APP_SCRIPTS" "$FAKE_AGENTVM" > "$CLOSING"
/bin/chmod +x "$CLOSING"
open_access dev-node
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
( AGENTVM_APP_AGENT_VM="$CLOSING"; export AGENTVM_APP_AGENT_VM; omc_run AgentVM.access.open )
check "status was being read"        "status --json" "$(fake_log | /usr/bin/sed -n '1p')"
check "  nothing is started, and no loop is chained" "|0" "$(started)|$(chain_asked AgentVM.access.poll)"
check "  the cache the reading made again is gone, and the window keeps nothing" "||" \
    "$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)|$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_job_$UUID" get)"

section "the window closes after agent-vm was read"
# The window's tools, with one that does what closing the window does before the first call whose
# arguments match CLOSE_BEFORE: the close button, clicked while the guide notes the setup it found,
# or while it paints. Painting reads the cache, which makes the window's cache folder again.
REAL_TOOLS="$OMC_OMC_SUPPORT_PATH"
CLOSING_TOOLS="$OMCTEST_WORK/closing_tools"
CLOSE_MARK="$OMCTEST_WORK/closed-once"
/bin/mkdir -p "$CLOSING_TOOLS"
/bin/cat > "$CLOSING_TOOLS/closing_tool" <<'TOOL'
#!/bin/sh
tool="${0##*/}"
case "$tool $*" in
    $CLOSE_BEFORE)
        if [ ! -e "$CLOSE_MARK" ]; then
            printf '' > "$CLOSE_MARK"
            OMC_OMC_SUPPORT_PATH="$REAL_TOOLS" /bin/sh "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/AgentVM.access.close.sh"
        fi ;;
esac
exec "$REAL_TOOLS/$tool" "$@"
TOOL
/bin/chmod +x "$CLOSING_TOOLS/closing_tool"
for tool in "$REAL_TOOLS"/*; do
    /bin/ln -sf "$tool" "$CLOSING_TOOLS/${tool##*/}"
done
/bin/rm -f "$CLOSING_TOOLS/omc_dialog_control" "$CLOSING_TOOLS/pasteboard"
/bin/cp "$CLOSING_TOOLS/closing_tool" "$CLOSING_TOOLS/omc_dialog_control"
/bin/cp "$CLOSING_TOOLS/closing_tool" "$CLOSING_TOOLS/pasteboard"
# closing_before <pattern> <handler>  ->  the handler run with those tools.
closing_before() {
    /bin/rm -f "$CLOSE_MARK"
    ( CLOSE_BEFORE="$1"; OMC_OMC_SUPPORT_PATH="$CLOSING_TOOLS"
      export CLOSE_BEFORE CLOSE_MARK REAL_TOOLS OMC_OMC_SUPPORT_PATH
      omc_run "$2" )
}
their_setup dev-node running boot
open_access dev-node
"$PB" "agentvm_job_$UUID" set ""
chains_reset
closing_before "pasteboard agentvm_job_$UUID set *" AgentVM.access.activated
check "closed while the setup found is noted: the window was closed" "yes|closed" "$([ -e "$CLOSE_MARK" ] && echo yes)|$("$PB" "agentvm_poll_$UUID" get)"
check "  the window keeps nothing, no cache folder is left, and no loop is chained" "||no|0" \
    "$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_job_$UUID" get)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)|$(chain_asked AgentVM.access.poll)"
open_access dev-node
chains_reset
closing_before "omc_dialog_control $UUID $ACCESS_STATUS_ID *" AgentVM.access.activated
check "closed while it paints: the window was closed" "yes|closed" "$([ -e "$CLOSE_MARK" ] && echo yes)|$("$PB" "agentvm_poll_$UUID" get)"
check "  the window keeps nothing, no cache folder is left, and no loop is chained" "||no|0" \
    "$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_job_$UUID" get)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)|$(chain_asked AgentVM.access.poll)"
/bin/rm -f "$JOBS"

section "Open the Image with no main window open"
in_window "$MAIN_UUID"
omc_run AgentVM.main.close
open_access dev-node
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.access.open
check_status "exits cleanly" 0
check "the setup starts, and only this window reads status: before it, and after" \
    "status --json|job start --json -- image setup dev-node|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  no cache folder is made for a main window that is not there" "" "$(/bin/ls "$TMPDIR/AgentVM/$MAIN_UUID" 2>/dev/null)"
omc_run AgentVM.access.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "an update that took the grant away: the main window asks"
# dev-acp has the grant. Its update replaces the guest daemon, and with it the grant goes.
UPDATE="20260930-120000-0000c1"
update_job() {
    /usr/bin/jq -n --arg id "$UPDATE" --arg image "$1" '[{id: $id, command: ["image", "update", $image, "--guest", "--json"],
        targets: ["image:" + $image], state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
}
LOST='(.images[] | select(.name == "dev-acp")).needs = [{kind: "full-disk-access"}]'
store '.'
update_job dev-acp
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
select_image dev-node
job_end "$UPDATE" done
store "$LOST"
alerts_reset
chains_reset
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "the update's end is said as any job's" "1" "$(ui_calls 'omc_present_toast Image dev-acp is up to date. 5')"
check "and the window asks about the grant it took" "Image dev-acp lost Full Disk Access in its update" "$(ui_alert_title)"
check "  saying what that means" \
    "agent-vm-guest had the grant in this image before the update, and does not have it now: macOS ties the grant to the daemon it was made for. Until it is granted again, programs in boxes made from dev-acp from now on wait, when they open Desktop, Documents or Downloads, on a question macOS asks on the box's screen. The boxes work without it otherwise." \
    "$(ui_alert_message)"
check "  Later does nothing, and Grant It Again... has its handler" "|AgentVM.main.image.access.offered" \
    "$(ui_alert_action Later)|$(ui_alert_action 'Grant It Again...')"
check "  the image asked about is kept" "dev-acp" "$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
omc_run AgentVM.main.image.access.offered
check "Grant It Again... asks for that image's guide, whatever is selected" "1|$APP_PID access:dev-acp" "$(chain_asked AgentVM.access)|$(request)"
check "  once"                       "" "$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
"$PB" agentvm_open_request_access set ""
chains_reset
omc_run AgentVM.main.image.access.offered
check "a second answer opens nothing" "0|" "$(chain_asked AgentVM.access)|$(request)"
"$PB" "agentvm_access_offer_$MAIN_UUID" set "--json"
omc_run AgentVM.main.image.access.offered
check "a name that is not one opens nothing" "0|" "$(chain_asked AgentVM.access)|$(request)"
"$PB" "agentvm_access_offer_$MAIN_UUID" set "no-such-image"
omc_run AgentVM.main.image.access.offered
check "nor does an image that is not there" "0|" "$(chain_asked AgentVM.access)|$(request)"
/bin/rm -f "$JOBS"

section "a reading between the update's last write and its end"
# agent-vm writes the updated image's record a moment before the job ends: a reading in between
# finds the job still running and the image already without the grant.
store '.'
omc_run AgentVM.main.activated
update_job dev-acp
omc_run AgentVM.main.activated
store "$LOST"
asked="$(ui_calls omc_present_alert)"
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "while the update still runs, nothing is asked" "$asked" "$(ui_calls omc_present_alert)"
job_end "$UPDATE" done
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "when it has ended, the question is asked all the same" "$((asked + 1))|dev-acp" \
    "$(ui_calls omc_present_alert)|$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
"$PB" "agentvm_access_offer_$MAIN_UUID" set ""
/bin/rm -f "$JOBS"

section "an update that took nothing away: no question"
# dev-node needed the grant before its update, and needs it after.
store '.'
omc_run AgentVM.main.activated
update_job dev-node
omc_run AgentVM.main.activated
job_end "$UPDATE" done
# The alert of the section before is still the window's last: the calls are counted instead.
asked="$(ui_calls omc_present_alert)"
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "the update's end is said"     "1" "$(ui_calls 'omc_present_toast Image dev-node is up to date. 5')"
check "an image that needed the grant before is not asked about" "$asked|" "$(ui_calls omc_present_alert)|$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
/bin/rm -f "$JOBS"
# An update that failed changed nothing: only its failure is said.
store '.'
omc_run AgentVM.main.activated
update_job dev-acp
omc_run AgentVM.main.activated
job_edit "$UPDATE" '{state: "failed", status: 1, endedAt: "2026-09-30T12:05:00Z", error: "the guest did not answer"}'
store "$LOST"
alerts_reset
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "a failed update: its failure, and no question" "Image dev-acp was not updated|" "$(ui_alert_title)|$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
/bin/rm -f "$JOBS"
# A job of another kind that ended well on an image that needs the grant now: no update took it.
store '.'
omc_run AgentVM.main.activated
their_setup dev-acp running full-disk-access
omc_run AgentVM.main.activated
job_end "$THEIRS" done
store "$LOST"
asked="$(ui_calls omc_present_alert)"
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "a setup that ended is said, with no question" "1|$asked|" \
    "$(ui_calls 'omc_present_toast The setup of image dev-acp is done. 5')|$(ui_calls omc_present_alert)|$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"
/bin/rm -f "$JOBS"
"$PB" "agentvm_access_offer_$MAIN_UUID" set dev-acp
omc_run AgentVM.main.close
check "closing the main window forgets a question not answered" "" "$("$PB" "agentvm_access_offer_$MAIN_UUID" get)"

section "the library: the setup job"
fake_reset
id="$(with_fake agentvm_job_image_setup dev-node)"
check "the job is started, and its id returned" "0|$FIRST|job start --json -- image setup dev-node" "$?|$id|$(fake_log)"
fake_reset
with_fake agentvm_job_image_setup "--json" >/dev/null
check "a name agent-vm would refuse is refused first" "2|" "$?|$(fake_log)"

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
