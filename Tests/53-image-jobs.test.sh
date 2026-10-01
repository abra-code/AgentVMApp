#!/bin/sh
# Tests/53-image-jobs.test.sh - an image a job holds, in the main window: what its card and its
# detail pane say while it is being built, updated or set up, or waits to be; that it cannot be
# deleted meanwhile; and what the window says when the job ends.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, and jobs made here with
# jq, as a build or an update started in Terminal or by another application would appear (the app
# starts none itself yet). A job never ends by itself, so the test edits it (job_edit) to move it
# on. The clock is fixed at 12 seconds after the jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_STATE_ID" ] && [ -n "$MAIN_IMAGE_DELETE_ID" ] || {
    printf '53-image-jobs: no view ids imported from lib.agentvm.main.sh\n' >&2
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
UUID="$OMC_ACTIONUI_WINDOW_UUID"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
UPDATE="20260930-120000-0000b1"
SETUP="20260930-120000-0000b2"
BUILD="20260930-120000-0000b3"

# job_edit <jq filter over the fake's jobs>  ->  the jobs moved on, as agent-vm would record it.
job_edit() {
    /usr/bin/jq "$1" "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
}

# job_log <id> <jq expression giving the events>  ->  that job's log, in the fake.
job_log() {
    /usr/bin/jq -n "{events: $2, lines: []}" > "$FAKE_AGENTVM_DIR/job-log-$1.json"
}

open_window() {
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# card <name>  ->  that image's card: its symbol and its caption.
card() {
    ui_rows "$MAIN_IMAGES_ID" | row_named "$1" | /usr/bin/cut -f2,3
}

fake_reset
# The store, with an image being built in it: dev-new, made from dev-node, setting up its tools.
/usr/bin/jq '.images += [(.images[] | select(.name == "dev-node") | . + {name: "dev-new", state: "provisioning", needs: [], derivedFrom: {image: "dev-node"}})]' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
/usr/bin/jq -n --arg update "$UPDATE" --arg setup "$SETUP" --arg build "$BUILD" '
    def job(id; cmd; target; state):
        { id: id, command: (cmd + ["--json"]), targets: [target], state: state, createdAt: "2026-09-30T12:00:00Z",
          path: ("/Users/you/Library/Application Support/agent-vm/Jobs/" + id) }
        + (if state == "running" then {startedAt: "2026-09-30T12:00:00Z"} else {} end);
    [ job($update; ["image", "update", "dev"]; "image:dev"; "running"),
      job($setup; ["image", "setup", "dev-node"]; "image:dev-node"; "queued") + {after: $update},
      job($build; ["image", "create", "dev-new", "--from", "dev-node"]; "image:dev-new"; "running") ]' > "$JOBS"
job_log "$UPDATE" '[{event: "progress", image: "dev", step: "boot", message: "Booting"}]'
job_log "$BUILD" '[{event: "progress", image: "dev-new", step: "recipe-step", message: "[2/3] Node", index: 2, count: 3, fraction: 0.33}]'

# -----------------------------------------------------------------------------------------------
section "the cards of images a job holds"
open_window
check_status "the init handler exits cleanly" 0
check "an image being updated: drawn as one being built, and its caption says so" \
    "hammer.fill${TAB}Updating - macOS 27.0 - from a restore file" "$(card dev)"
check "one that waits for another job" "hammer.fill${TAB}Waiting - macOS 27.0 - from dev" "$(card dev-node)"
check "one being built says Building once" "hammer.fill${TAB}Building - macOS 27.0" "$(card dev-new)"
check "one no job holds is as it was" "square.stack.3d.up.fill${TAB}macOS 27.0 - from dev-node" "$(card dev-acp)"
check "no alert and no toast for jobs that run" "|0" "$(ui_alert_title)|$(ui_calls omc_present_toast)"

section "the pane of an image a job holds"
select_image dev
check "being updated: what the job does, for how long, and its step" "Updating, 12 s so far: Booting" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  Delete is off"              "0" "$(enabled "$MAIN_IMAGE_DELETE_ID")"
select_image dev-node
check "waiting"                      "Waiting to be set up" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  Delete is off"              "0" "$(enabled "$MAIN_IMAGE_DELETE_ID")"
select_image dev-new
check "being built: the job's step in place of the image's state" "Building, 12 s so far: [2/3] Node" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  Delete is off"              "0" "$(enabled "$MAIN_IMAGE_DELETE_ID")"
select_image dev-acp
check "an image no job holds"        "Ready|1" "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(enabled "$MAIN_IMAGE_DELETE_ID")"

section "Delete... on an image a job took meanwhile"
# The pane showed dev-acp free; a job on it started before the click.
job_edit '. + [.[0] + {id: "20260930-120005-0000b4", command: ["image", "update", "dev-acp", "--json"], targets: ["image:dev-acp"]}]'
omc_run AgentVM.main.image.delete
check "no question"                  "" "$(ui_alert_title)"
check "  nothing is pending"         "" "$("$PB" "agentvm_image_delete_$UUID" get)"
check "  and the pane says why"      "Updating, 12 s so far|0" "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(enabled "$MAIN_IMAGE_DELETE_ID")"
job_edit 'map(select(.id != "20260930-120005-0000b4"))'

section "the poll loop looks often while an image's job runs"
: > "$FAKE_SLEEP_LOG"
poll 1
check "every 2 seconds"              "2" "$(/bin/cat "$FAKE_SLEEP_LOG")"

section "the job moves on"
job_log "$UPDATE" '[{event: "progress", image: "dev", step: "boot", message: "Booting"},
    {event: "progress", image: "dev", step: "macos-download", message: "Downloading macOS 27.1", fraction: 0.4}]'
select_image dev
poll 1
check "the pane follows its step"    "Updating, 12 s so far: Downloading macOS 27.1" "$(ui_value "$MAIN_IMAGE_STATE_ID")"

section "the update ends well"
job_edit "map(if .id == \"$UPDATE\" then . + {state: \"done\", status: 0, endedAt: \"2026-09-30T12:00:20Z\"} else . end)"
poll 1
check "a toast"                      "1" "$(ui_calls 'omc_present_toast Image dev is up to date. 5')"
check "the card and the pane are the image's again" "square.stack.3d.up.fill${TAB}macOS 27.0 - from a restore file|Ready|1" \
    "$(card dev)|$(ui_value "$MAIN_IMAGE_STATE_ID")|$(enabled "$MAIN_IMAGE_DELETE_ID")"

section "the build fails"
job_edit "map(if .id == \"$BUILD\" then . + {state: \"failed\", status: 1, endedAt: \"2026-09-30T12:00:25Z\", error: \"step 2 (Node) failed with status 1\"} else . end)"
/usr/bin/jq '(.images[] | select(.name == "dev-new")) |= . + {state: "failed", failure: "step 2 (Node) failed with status 1"}' \
    "$FAKE_AGENTVM_DIR/status.json" > "$FAKE_AGENTVM_DIR/status.json.new" && /bin/mv "$FAKE_AGENTVM_DIR/status.json.new" "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "an alert, in agent-vm's words" "Image dev-new was not built|step 2 (Node) failed with status 1" "$(ui_alert_title)|$(ui_alert_message)"
check "the card says Failed"         "xmark.octagon.fill${TAB}Failed - macOS 27.0" "$(card dev-new)"
select_image dev-new
check "the failed image can be deleted" "1" "$(enabled "$MAIN_IMAGE_DELETE_ID")"

section "the words for a job"
words() { ( . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1; main_job_verb "$@" ); }
check "running" "Starting|Stopping|Building|Updating|Updating|Setting up|Busy: image fetch-ipsw" \
    "$(words "box start" running)|$(words "box stop" running)|$(words "image create" running)|$(words "image update" running)|$(words "image update-guest" running)|$(words "image setup" running)|$(words "image fetch-ipsw" running)"
check "waiting" "Waiting to start|Waiting to stop|Waiting to be built|Waiting to be updated|Waiting to be set up|Waiting: image fetch-ipsw" \
    "$(words "box start" queued)|$(words "box stop" queued)|$(words "image create" queued)|$(words "image update" queued)|$(words "image setup" queued)|$(words "image fetch-ipsw" queued)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
