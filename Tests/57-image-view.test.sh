#!/bin/sh
# Tests/57-image-view.test.sh - View in the image detail pane: the job it starts (`image view`,
# which boots the image and shows its screen in a window of agent-vm's), which images offer it,
# what the card, the pane and its buttons show while the job holds the image, and what the window
# says when the job ends.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json (six ready images and
# latest-test, failed). The fake keeps the jobs it is asked to start and carries them in `status`;
# a job never ends by itself, so the test edits it (job_end). The clock is fixed at 12 seconds
# after the fake's jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_VIEW_ID" ] && [ -n "$MAIN_IMAGE_UPDATE_ID" ] && [ -n "$MAIN_IMAGE_STATE_ID" ] \
    && [ -n "$MAIN_IMAGE_DELETE_ID" ] || {
    printf '57-image-view: no view ids imported from lib.agentvm.main.sh\n' >&2
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

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# job_end <state> [error]  ->  the newest job ended that way.
job_end() {
    /usr/bin/jq "(.[-1]) |= (. + {state: \"$1\", endedAt: \"2026-09-30T12:00:20Z\"} | if \"$1\" == \"done\" then .status = 0 elif \"$1\" == \"failed\" then .status = 75 else . end | if \"${2:-}\" != \"\" then .error = \"${2:-}\" else . end)" \
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

# held  ->  View, Update and Delete of the selected image, enabled (1) or not.
held() {
    printf '%s %s %s\n' "$(enabled "$MAIN_IMAGE_VIEW_ID")" "$(enabled "$MAIN_IMAGE_UPDATE_ID")" "$(enabled "$MAIN_IMAGE_DELETE_ID")"
}

# started  ->  the jobs the fake was asked to start, as agent-vm was called.
started() {
    fake_log | /usr/bin/grep '^job start' | /usr/bin/paste -sd '|' -
}

clear_alerts() {
    alerts_reset
    ui_reset
}

fake_reset
store '.'
: > "$FAKE_SLEEP_LOG"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init

# -----------------------------------------------------------------------------------------------
section "the library"
with_fake agentvm_job_image_view dev-acp >/dev/null
check "the job is image view, with --json before the --" "job start --json -- image view dev-acp" "$(fake_log | /usr/bin/tail -1)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_job_image_view "../x" >/dev/null 2>&1
check "a name agent-vm would refuse starts nothing" "2|" "$?|$(started)"
/bin/rm -f "$JOBS"

# -----------------------------------------------------------------------------------------------
section "which images offer View"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.view
check "no image selected: nothing is started" "" "$(started)"
select_image latest-test
check "a failed image cannot be opened" "0" "$(enabled "$MAIN_IMAGE_VIEW_ID")"
omc_run AgentVM.main.image.view
check "  and the handler starts nothing for it" "" "$(started)"
select_image dev-acp
check "a ready image can"            "1" "$(enabled "$MAIN_IMAGE_VIEW_ID")"
store '(.images[] | select(.name == "dev-acp")).updating = true'
omc_run AgentVM.main.activated
check "an image another command is changing cannot" "0" "$(enabled "$MAIN_IMAGE_VIEW_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.view
check "  and the handler, which reads status itself, starts nothing" "" "$(started)"
store '.'
omc_run AgentVM.main.activated

# -----------------------------------------------------------------------------------------------
section "View"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.view
check_status "the handler exits cleanly" 0
check "status is read, the job started, and status read again" \
    "status --json|job start --json -- image view dev-acp|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the poll loop is begun anew" "1" "$(chain_asked AgentVM.main.poll)"
check "the pane says where the image is, and for how long" "Open in its window, elapsed 12 s" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "the card says Open" "yes" "$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-acp | /usr/bin/grep -q 'Open' && echo yes)"
check "View, Update and Delete are off while the job holds the image" "0 0 0" "$(held)"
select_image dev
check "another image is as it was" "1 1 1" "$(held)"
select_image dev-acp

section "a second View while the job holds the image"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.view
check "starts nothing"           "" "$(started)"

section "a second View while the first is worked on"
job_end done
clear_alerts
poll 1
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
"$PB" "agentvm_busy_$OMC_ACTIONUI_WINDOW_UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.view
check "a second click: agent-vm is not run, nothing is started" "|" "$(fake_log)|$(started)"
check "  the other click's mark is not taken away" "click-$$" "$("$PB" "agentvm_busy_$OMC_ACTIONUI_WINDOW_UUID" get)"
"$PB" "agentvm_busy_$OMC_ACTIONUI_WINDOW_UUID" set "click-"
omc_run AgentVM.main.image.view
check "a mark that names no running handler holds nothing: the job starts, and its own mark goes" "job start --json -- image view dev-acp|" \
    "$(started)|$("$PB" "agentvm_busy_$OMC_ACTIONUI_WINDOW_UUID" get)"

section "the window is closed: the job ends well"
job_end done
clear_alerts
poll 1
check "the pane shows the image ready" "Ready" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  with its buttons back"  "1 1 1" "$(held)"
check "a toast says the image is shut down and what was done is kept" "1" \
    "$(ui_calls 'omc_present_toast.*Image dev-acp is shut down; what was done in its window is kept\.')"
check "  no alert"               "" "$(ui_alert_title)"

# -----------------------------------------------------------------------------------------------
section "a view that fails"
omc_run AgentVM.main.image.view
job_end failed "image view shows the image's screen, so it needs a login session on this Mac (not SSH)"
clear_alerts
poll 1
check "is said when the job ends, in agent-vm's words" \
    "Image dev-acp was not opened|image view shows the image's screen, so it needs a login session on this Mac (not SSH)" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "  the image is ready, with View again" "Ready|1" "$(ui_value "$MAIN_IMAGE_STATE_ID")|$(enabled "$MAIN_IMAGE_VIEW_ID")"

section "agent-vm refuses the job"
clear_alerts
printf 'image dev-acp is in use by another agent-vm process\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
omc_run AgentVM.main.image.view
check "the refusal is shown in agent-vm's words" "Image dev-acp was not opened|yes" \
    "$(ui_alert_title)|$(ui_alert_message | /usr/bin/grep -q 'in use by another agent-vm process' && echo yes)"
check "  and View is back on"    "1" "$(enabled "$MAIN_IMAGE_VIEW_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"

check "no harness errors" "" "$(ui_errors)"

omctest_end
