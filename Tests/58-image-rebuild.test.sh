#!/bin/sh
# Tests/58-image-rebuild.test.sh - Build Again... in the image detail pane, for an image whose base
# changed since it was made from it (agent-vm 0.7.59's rebuild need): the rows the library reads,
# which images show the button and when it is on, the question it asks, the job it starts (`image
# rebuild`), what the card and the pane show while the job holds the image, and what the window
# says when the job ends or agent-vm refuses it.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json, in which
# dev-acp (built from dev-node) needs a rebuild. The fake keeps the jobs it is asked to start and
# carries them in `status`; a job never ends by itself, so the test edits it (job_end). The clock
# is fixed at 12 seconds after the fake's jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_REBUILD_ID" ] && [ -n "$MAIN_IMAGE_UPDATE_ID" ] && [ -n "$MAIN_IMAGE_STATE_ID" ] \
    && [ -n "$MAIN_IMAGE_DELETE_ID" ] && [ -n "$MAIN_IMAGE_MAINTENANCE_ID" ] || {
    printf '58-image-rebuild: no view ids imported from lib.agentvm.main.sh\n' >&2
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
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
# dev-acp's base was built again; dev-agents's base has other tools.
NEEDS='(.images[] | select(.name == "dev-acp")).needs = [{kind: "rebuild", reason: "base-rebuilt", base: "dev-node"}]
    | (.images[] | select(.name == "dev-agents")).needs = [{kind: "full-disk-access", reason: "not-granted"}, {kind: "rebuild", reason: "base-recipes-changed", base: "dev-node"}]'

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# job_end <state> [error]  ->  the newest job ended that way.
job_end() {
    /usr/bin/jq "(.[-1]) |= (. + {state: \"$1\", endedAt: \"2026-09-30T12:00:20Z\"} | if \"$1\" == \"done\" then .status = 0 elif \"$1\" == \"failed\" then .status = 1 else . end | if \"${2:-}\" != \"\" then .error = \"${2:-}\" else . end)" \
        "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
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

shown() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}

# button  ->  Build Again..., shown and on (1) or not.
button() {
    printf '%s %s\n' "$(shown "$MAIN_IMAGE_REBUILD_ID")" "$(enabled "$MAIN_IMAGE_REBUILD_ID")"
}

# started  ->  the jobs the fake was asked to start, as agent-vm was called.
started() {
    fake_log | /usr/bin/grep '^job start' | /usr/bin/paste -sd '|' -
}

clear_alerts() {
    alerts_reset
    ui_reset
}

pending() {
    "$PB" "agentvm_image_rebuild_$OMC_ACTIONUI_WINDOW_UUID" get
}

fake_reset
store "$NEEDS"
: > "$FAKE_SLEEP_LOG"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init

# -----------------------------------------------------------------------------------------------
section "the library"
rows="$(lib agentvm_status_rebuild_rows < "$FAKE_AGENTVM_DIR/status.json")"
check "one row per image that needs a rebuild: the reason and the base" \
    "dev-acp${TAB}base-rebuilt${TAB}dev-node|dev-agents${TAB}base-recipes-changed${TAB}dev-node" "$(printf '%s\n' "$rows" | /usr/bin/paste -sd '|' -)"
check "none in the captures, made before agent-vm recorded a base" "||" \
    "$(lib agentvm_status_rebuild_rows < "$FIXTURES_AGENTVM/status.json")|$(lib agentvm_status_rebuild_rows < "$FIXTURES_AGENTVM/status-mixed.json")|$(lib agentvm_status_rebuild_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "a need without a reason: -"   "one${TAB}-${TAB}base" \
    "$(printf '%s\n' '{"images": [{"name": "one", "needs": [{"kind": "rebuild", "base": "base"}, {"kind": "rebuild", "reason": "base-rebuilt", "base": "x"}]}]}' | lib agentvm_status_rebuild_rows)"
with_fake agentvm_job_image_rebuild dev-acp >/dev/null
check "the job is image rebuild, with --json before the --" "job start --json -- image rebuild dev-acp" "$(fake_log | /usr/bin/tail -1)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_job_image_rebuild "--from" >/dev/null 2>&1
check "a name agent-vm would refuse starts nothing" "2|" "$?|$(started)"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

# -----------------------------------------------------------------------------------------------
section "which images show Build Again..."
select_image dev
check "an image whose base did not change: not shown" "0 0" "$(button)"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild
check "  and the handler, which reads status itself, asks nothing" "|" "$(ui_alert_title)|$(pending)"
select_image dev-acp
check "an image whose base was built again: shown and on" "1 1" "$(button)"
check "  the pane says why"          \
    "Needs maintenance|Its base image dev-node was built again since it was made from it. Build Again... makes it again from it." \
    "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -)"
select_image dev-agents
check "one whose base has other tools, beside Full Disk Access it lacks: shown and on" "1 1" "$(button)"
store "$NEEDS"' | (.images[] | select(.name == "dev-acp")).updating = true'
omc_run AgentVM.main.activated
select_image dev-acp
check "one another command is changing: shown, and off" "1 0" "$(button)"
clear_alerts
omc_run AgentVM.main.image.rebuild
check "  and the handler asks nothing" "|" "$(ui_alert_title)|$(pending)"
store "$NEEDS"' | (.images[] | select(.name == "dev-acp")).state = "provisioning"'
omc_run AgentVM.main.activated
check "one that is not ready: shown, and off" "1 0" "$(button)"
store "$NEEDS"
omc_run AgentVM.main.activated
check "ready again: on"              "1 1" "$(button)"

# -----------------------------------------------------------------------------------------------
section "the question"
clear_alerts
omc_run AgentVM.main.image.rebuild
check_status "exits cleanly" 0
check "it asks, about the image selected" "Build image dev-acp again?|dev-acp" "$(ui_alert_title)|$(pending)"
check "  what a rebuild does"        "yes" \
    "$(ui_alert_message | /usr/bin/grep -q '^A fresh copy of image dev-node is made, and the recipes dev-acp added run on it again, as when it was built. dev-acp stays as it is, and can be used, until the new one is ready; a failure or Stop leaves it as it was.' && echo yes)"
check "  Build Again confirms, Cancel does nothing" "AgentVM.main.image.rebuild.confirmed|" \
    "$(ui_alert_action 'Build Again')|$(ui_alert_action Cancel)"
check "  nothing is started yet"     "" "$(started)"
store "$NEEDS"' | .boxes |= map(.box.image = "dev-acp" | .image = "dev-acp")'
clear_alerts
omc_run AgentVM.main.image.rebuild
check "the boxes made from it keep what they have; a disposable one is not named" "yes|no" \
    "$(ui_alert_message | /usr/bin/grep -q 'Boxes made from it (s3 and try1) keep what they have until they are recreated\.' && echo yes || echo no)|$(ui_alert_message | /usr/bin/grep -q 'cadabra-spike' && echo yes || echo no)"
check "  one machine of two runs: no word of a slot" "no" "$(ui_alert_message | /usr/bin/grep -q 'slot' && echo yes || echo no)"
store "$NEEDS"' | .runningVMs.count = 2'
clear_alerts
omc_run AgentVM.main.image.rebuild
check "both places taken: the question says so, and still asks" "Build image dev-acp again?|yes" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -q 'No virtual machine slot is free now (2 of 2 macOS virtual machines running), and the rebuild needs one: it fails at once until a macOS box or build stops\.$' && echo yes)"
store "$NEEDS"
omc_run AgentVM.main.activated
select_image dev-node
store "$NEEDS"' | (.images[] | select(.name == "dev-node")).needs = [{kind: "rebuild", reason: "base-rebuilt", base: "dev"}]'
omc_run AgentVM.main.activated
clear_alerts
omc_run AgentVM.main.image.rebuild
check "an image with images built from it: they are not built again with it" "yes" \
    "$(ui_alert_message | /usr/bin/grep -q 'Images built from it (dev-acp and dev-agents) are not built again with it\.' && echo yes)"
store "$NEEDS"
omc_run AgentVM.main.activated
select_image dev-acp

# -----------------------------------------------------------------------------------------------
section "Build Again"
clear_alerts
omc_run AgentVM.main.image.rebuild
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild.confirmed
check_status "exits cleanly" 0
check "status is read, the job started, and status read again" \
    "status --json|job start --json -- image rebuild dev-acp|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the question is answered once"  "" "$(pending)"
check "the poll loop is begun anew"  "1" "$(chain_asked AgentVM.main.poll)"
check "the pane and the card follow the job" "yes|yes" \
    "$(ui_value "$MAIN_IMAGE_STATE_ID" | /usr/bin/grep -q '^Building again, elapsed 12 s' && echo yes)|$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-acp | /usr/bin/grep -q 'Building again' && echo yes)"
check "Build Again..., Update and Delete are off while the job holds the image" "0 0 0" \
    "$(enabled "$MAIN_IMAGE_REBUILD_ID") $(enabled "$MAIN_IMAGE_UPDATE_ID") $(enabled "$MAIN_IMAGE_DELETE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild.confirmed
check "a second confirmation starts nothing" "" "$(started)"
"$PB" "agentvm_image_rebuild_$OMC_ACTIONUI_WINDOW_UUID" set dev-acp
omc_run AgentVM.main.image.rebuild.confirmed
check "  nor one while the job holds the image" "" "$(started)"

section "the job ends well"
job_end done
store "$NEEDS"' | (.images[] | select(.name == "dev-acp")).needs = []'
clear_alerts
poll 1
check "a toast says so"              "1" "$(ui_calls 'omc_present_toast.*Image dev-acp was built again')"
check "  the image is ready, and needs nothing: no button, no line" "Ready|0 0|" \
    "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(button)|$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID")"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "a rebuild that fails"
store "$NEEDS"
omc_run AgentVM.main.activated
omc_run AgentVM.main.image.rebuild
omc_run AgentVM.main.image.rebuild.confirmed
job_end failed "recipe xcode: its input xcode was read from /Users/you/Downloads/Xcode_27.xip, which is gone; give it with --input xcode=PATH"
clear_alerts
poll 1
check "is said when the job ends, in agent-vm's words" \
    "Image dev-acp was not built again, and is as it was|recipe xcode: its input xcode was read from /Users/you/Downloads/Xcode_27.xip, which is gone; give it with --input xcode=PATH" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  the image still needs it, with Build Again... on" "1 1" "$(button)"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "the base changed meanwhile, or the image was taken"
clear_alerts
omc_run AgentVM.main.image.rebuild
store "$NEEDS"' | (.images[] | select(.name == "dev-acp")).needs = []'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild.confirmed
check "a need gone by the confirmation: nothing is started" "" "$(started)"
store "$NEEDS"
omc_run AgentVM.main.activated
clear_alerts
omc_run AgentVM.main.image.rebuild
/usr/bin/jq -n '[{id: "20260930-120000-0000e1", command: ["image", "update", "dev-acp", "--json"], targets: ["image:dev-acp"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild.confirmed
check "a job took the image: nothing is started" "" "$(started)"
/bin/rm -f "$JOBS"
omc_run AgentVM.main.activated

section "agent-vm refuses the job"
clear_alerts
omc_run AgentVM.main.image.rebuild
printf 'image dev-acp is in use by another agent-vm process\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
omc_run AgentVM.main.image.rebuild.confirmed
check "the refusal is shown in agent-vm's words" "Image dev-acp was not built again|yes" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -q 'in use by another agent-vm process' && echo yes)"
check "  and Build Again... is back on" "1 1" "$(button)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"

section "a Linux image"
/usr/bin/jq '(.images[] | select(.name == "deb-agents")).needs = [{kind: "rebuild", reason: "base-rebuilt", base: "deb"}]' \
    "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
select_image deb-agents
check "Build Again... is shown and on, where View is not shown" "1 1|0" "$(button)|$(shown "$MAIN_IMAGE_VIEW_ID")"
clear_alerts
omc_run AgentVM.main.image.rebuild
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.rebuild.confirmed
check "  the same job"                "job start --json -- image rebuild deb-agents" "$(started)"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
