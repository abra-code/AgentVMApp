#!/bin/sh
# Tests/55-update-window.test.sh - an image's update window: Update... in the image pane, one
# window per image and only when this run of the app asked for it, what the window says about
# each part (macOS, the tools, the guest daemon) and which parts it ticks, Check Now, what stands
# in the way of an update, and Update: the job it starts, with the command line shown, the
# progress window, and the main window following the job at once.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json, in which
# Apple was never asked for the newest macOS; BEHIND adds what `status --check-updates` would have
# learned. The clock is fixed at 12 seconds after the fake's jobs start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.update.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_UPDATE_ID" ] && [ -n "$MAIN_IMAGE_STATE_ID" ] && [ -n "$UPDATE_TITLE_ID" ] \
    && [ -n "$UPDATE_STATE_ID" ] && [ -n "$UPDATE_MACOS_ID" ] && [ -n "$UPDATE_MACOS_TEXT_ID" ] && [ -n "$UPDATE_CHECK_ID" ] \
    && [ -n "$UPDATE_TOOLS_ID" ] && [ -n "$UPDATE_TOOLS_TEXT_ID" ] && [ -n "$UPDATE_GUEST_ID" ] && [ -n "$UPDATE_GUEST_TEXT_ID" ] \
    && [ -n "$UPDATE_AFTER_ID" ] && [ -n "$UPDATE_COMMAND_ID" ] && [ -n "$UPDATE_NOTE_ID" ] && [ -n "$UPDATE_START_ID" ] || {
    printf '55-update-window: no view ids imported from the libraries\n' >&2
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
APP_PID="${OMC_APP_PROCESS_ID:?55-update-window: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-update-window-$$"
OTHER_UUID="OMCTEST-other-update-window-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
# The fake's first job.
FIRST="20260930-120001-000001"
# What `status --check-updates` learned: the newest macOS, and that dev-acp is behind it.
BEHIND='.newestMacOS = {version: "27.0.1", build: "26A434", checkedAt: "2026-09-29T09:00:00Z"}
    | (.images[] | select(.name == "dev-acp")).macOSUpdate = {version: "27.0.1", build: "26A434", checkedAt: "2026-09-29T09:00:00Z"}'

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
    "$PB" agentvm_open_request_update get
}

# registered <image>  ->  the pasteboard entry naming that image's update window.
registered() {
    "$PB" "agentvm_window_update_$1" get
}

# open_update <image> [uuid]  ->  that image's window opened the way Update... opens it: the
# request, then the window's init handler, in a window of its own.
open_update() {
    "$PB" agentvm_open_request_update set "$APP_PID update:$1"
    in_window "${2:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.update
    omc_run AgentVM.update.init
}

# tick <macos> <tools> <guest>  ->  the checkboxes as the user left them (true or false each), and
# the click's handler.
tick() {
    omc_control "$UPDATE_MACOS_ID" "$1"
    omc_control "$UPDATE_TOOLS_ID" "$2"
    omc_control "$UPDATE_GUEST_ID" "$3"
    omc_run AgentVM.update.choice
}

select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# ticks  ->  the three checkboxes as the window set them, and the choices it keeps.
ticks() {
    printf '%s %s %s|%s\n' "$(ui_value "$UPDATE_MACOS_ID")" "$(ui_value "$UPDATE_TOOLS_ID")" "$(ui_value "$UPDATE_GUEST_ID")" \
        "$("$PB" "agentvm_choices_$UUID" get)"
}

# started  ->  the jobs agent-vm was asked to start.
started() {
    fake_log | /usr/bin/grep '^job start' | /usr/bin/paste -sd '|' -
}

fake_reset
store '.'
for image in dev dev-acp dev-node latest-test; do
    "$PB" "agentvm_window_update_$image" set ""
done
"$PB" agentvm_open_request_update set ""
"$PB" agentvm_open_request_progress set ""

# -----------------------------------------------------------------------------------------------
section "Update... in the image pane"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
omc_run AgentVM.main.image.update
check "no image selected: the handler opens nothing" "0|" "$(chain_asked AgentVM.update)|$(request)"
select_image latest-test
check "a failed image cannot be updated" "0" "$(enabled "$MAIN_IMAGE_UPDATE_ID")"
select_image dev
check "a ready image can"            "1" "$(enabled "$MAIN_IMAGE_UPDATE_ID")"
check "  and its macOS row says when it was last updated" "27.0 (26A428), updated Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_MACOS_ID")"
select_image dev-acp
check "one never updated says only its macOS" "27.0 (26A428)" "$(ui_value "$MAIN_IMAGE_MACOS_ID")"
omc_run AgentVM.main.image.update
check "it asks for an update window" "1" "$(chain_asked AgentVM.update)"
check "  for the selected image, from this run of the app" "$APP_PID update:dev-acp" "$(request)"
"$PB" agentvm_open_request_update set ""
store '(.images[] | select(.name == "dev-acp")).updating = true'
omc_run AgentVM.main.activated
check "an image another command is changing cannot" "0" "$(enabled "$MAIN_IMAGE_UPDATE_ID")"
store '.'
omc_run AgentVM.main.activated

section "a newer macOS that is known is maintenance"
store "$BEHIND"
omc_run AgentVM.main.activated
check "the card is marked"           "Needs maintenance" "$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-acp | col 4)"
check "the pane says which, and what installs it" \
    "Needs maintenance|macOS 27.0.1 is available. Update... installs it, in about 15 minutes." \
    "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -)"
check "an image that is not behind is not marked" "" "$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-agents | col 4)"

section "the window opens on an image that is behind"
: > "$FAKE_AGENTVM_DIR/log"
open_update dev-acp
check_status "the init handler exits cleanly" 0
check "takes the request, once"      "" "$(request)"
check "becomes the image's window"   "$APP_PID $UUID" "$(registered dev-acp)"
check "asks agent-vm which it is, and reads status once" "--version|status --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "the title names the image"    "Update image dev-acp|Update image dev-acp" "$(ui_title)|$(ui_value "$UPDATE_TITLE_ID")"
check "its macOS, and that it was never updated" "macOS 27.0 (26A428). Not updated since it was built." "$(ui_value "$UPDATE_STATE_ID")"
check "macOS: what is available, when that was learned, and what it costs" \
    "macOS 27.0.1 (26A434) is available, as Apple said on Sep 29, 2026. Installing it takes about 15 minutes, and about 15 GB of disk that the image then no longer shares with its older boxes. Newer Command Line Tools are installed with it." \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")"
check "the tools: the recipes it keeps" \
    "Runs the update steps of the recipes this image keeps (dev-acp), then every recipe's checks. Not run since the image was built." \
    "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
check "the guest daemon: another version, replaced by this agent-vm's" \
    "The image's agent-vm-guest 0.2.18 is replaced by this agent-vm's, $VERSION. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
check "afterwards: its box, and what a failure leaves" \
    "Boxes made from it (s3) keep what they have until they are recreated.|The image can be used meanwhile: a box made during the update gets the image as it was.|An update that fails or is stopped leaves the image as it is now." \
    "$(ui_value "$UPDATE_AFTER_ID" | /usr/bin/paste -sd '|' -)"
check "all three have something to do: all three ticked" "true true true|1 1 1" "$(ticks)"
check "the command it would run"     "agent-vm image update dev-acp --macos --tools --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
check "nothing stands in the way: no note, and Update is on" "|1" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
check "the tools can be ticked"      "1" "$(enabled "$UPDATE_TOOLS_ID")"

section "a second Update... on the same image, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.main.image.update
check "opens no second window"       "0" "$(chain_asked AgentVM.update)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
"$PB" agentvm_open_request_update set "$APP_PID update:dev-acp"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.update
omc_run AgentVM.update.init
check "a second window for the same image: the first stays the image's, the second closes" "$APP_PID $UUID|1" \
    "$(registered dev-acp)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
for bad in "" "$APP_PID network:dev-acp" "1 update:dev-acp" "$APP_PID update:../x" "$APP_PID update:Dev" "$APP_PID update:--guest"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_update set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.update
    omc_run AgentVM.update.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "|" "$("$PB" "agentvm_image_$OTHER_UUID" get)|$("$PB" "agentvm_choices_$OTHER_UUID" get)"
done

section "the checkboxes"
open_update dev-acp
: > "$FAKE_AGENTVM_DIR/log"
tick true false false
check "macOS alone"                  "1 0 0|agent-vm image update dev-acp --macos|1" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
tick false true true
check "the tools and the guest daemon" "0 1 1|agent-vm image update dev-acp --tools --guest" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")"
tick false false false
check "nothing ticked: no command, and Update is off" "0 0 0|Tick what to update.|0" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
tick yes 1 "true --set x=y"
check "a value that is not a checkbox's is not a tick" "0 0 0|Tick what to update." \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")"
check "a click asks agent-vm nothing" "" "$(fake_log)"
# A repaint must not undo a click made while it ran: only the opening sets the checkboxes.
check "a click's handler does not set the checkboxes" "0" "$(ui_calls "${UUID}${TAB}${UPDATE_MACOS_ID}${TAB}false")"

section "an image that keeps no recipes, with a guest daemon that lacks a feature"
store "$BEHIND"
open_update dev-node
check "the tools: nothing to refresh" "This image keeps no recipes, so it has no tools an update can refresh." "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
check "  the checkbox is off and cannot be ticked" "false|0" "$(ui_value "$UPDATE_TOOLS_ID")|$(enabled "$UPDATE_TOOLS_ID")"
check "macOS: not behind what Apple last said" \
    "No newer macOS is known for this image: the newest is 27.0.1 (26A434), as of Sep 29, 2026. The update asks Apple again, and installs what is offered." \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")"
check "the guest daemon: what the new one adds" \
    "The image's agent-vm-guest 0.2.18 is replaced by this agent-vm's, $VERSION, which adds terminal-pixels. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
check "afterwards: the images built from it" \
    "Images built from it (dev-acp and dev-agents) are not updated with it: each is updated by itself." \
    "$(ui_value "$UPDATE_AFTER_ID" | /usr/bin/sed -n '1p')"
check "only the guest daemon is ticked" "false false true|0 0 1" "$(ticks)"
check "the command"                  "agent-vm image update dev-node --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
tick true true true
check "a tick on the tools that reached the handler anyway is dropped" "agent-vm image update dev-node --macos --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
omc_run AgentVM.update.close

section "an image that needs nothing known"
# dev-agents with this agent-vm's guest daemon: not behind, no recipes, the same daemon.
store "$BEHIND"' | (.images[] | select(.name == "dev-agents")).guestVersion = "'"$VERSION"'"'
open_update dev-agents
check "nothing is ticked, and Update is off until something is" "false false false|0 0 0|Tick what to update.|0" \
    "$(ticks)|$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
check "the guest daemon is this agent-vm's" \
    "The image has agent-vm-guest $VERSION, as this agent-vm does. It is replaced only if the two still differ." "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
omc_run AgentVM.update.close

section "Apple was never asked"
store '.'
open_update dev-agents
check "macOS says so, and is ticked: the update asks" \
    "Apple has not been asked which macOS is the newest: Check Now asks. The update asks too, and installs what Apple offers within macOS 27.|true" \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")|$(ui_value "$UPDATE_MACOS_ID")"
omc_run AgentVM.update.close
store '.newestMacOS = {version: "28.0", build: "27A100", checkedAt: "2026-09-29T09:00:00Z"}'
open_update dev-agents
check "a new major version is not what an update installs" \
    "The newest macOS is 28.0 (as of Sep 29, 2026), a new major version, which an update does not install: the image is built again for that. The update still asks Apple for what it offers within macOS 27.|false" \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")|$(ui_value "$UPDATE_MACOS_ID")"
omc_run AgentVM.update.close

section "an image updated before"
store "$BEHIND"' | (.images[] | select(.name == "dev")).recipes = [{name: "homebrew", folder: "1-homebrew"}, {name: "node", folder: "2-node"}]'
open_update dev
check "when it was last updated"     "macOS 27.0 (26A428). Last updated on Sep 30, 2026." "$(ui_value "$UPDATE_STATE_ID")"
check "the recipes in order, and when their update steps last ran" \
    "Runs the update steps of the recipes this image keeps (homebrew, node), then every recipe's checks. Last run on Sep 30, 2026." \
    "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
omc_run AgentVM.update.close

section "Check Now"
store '.newestMacOS = {version: "27.0", build: "26A428", checkedAt: "2026-09-20T09:00:00Z"}'
open_update dev-acp
check "not behind what Apple last said: macOS is not ticked" "false true true|0 1 1" "$(ticks)"
# Apple now has a newer one, and agent-vm learns it as it is asked.
store "$BEHIND"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.check
check_status "exits cleanly" 0
check "agent-vm asks Apple, in one call" "status --check-updates --json" "$(fake_log)"
check "the window says what is available" "macOS 27.0.1 (26A434) is available" "$(ui_value "$UPDATE_MACOS_TEXT_ID" | /usr/bin/cut -c1-34)"
check "  ticks macOS, and keeps the other ticks" "true true true|1 1 1" "$(ticks)"
check "  the command follows"        "agent-vm image update dev-acp --macos --tools --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
check "  the waiting note is gone, and the button is back" "|1" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_CHECK_ID")"
tick false true false
store '.newestMacOS = {version: "27.0", build: "26A428", checkedAt: "2026-09-20T09:00:00Z"} | .newestMacOSError = "The Internet connection appears to be offline."'
omc_run AgentVM.update.check
check "a lookup that failed says why" "Apple could not be asked for the newest macOS: The Internet connection appears to be offline." "$(ui_value "$UPDATE_NOTE_ID")"
check "  and leaves the ticks alone" "0 1 0" "$("$PB" "agentvm_choices_$UUID" get)"
check "  Update stays on: the update asks Apple itself" "1" "$(enabled "$UPDATE_START_ID")"
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.update.check
check "agent-vm itself failing is said, and Update is off" "agent-vm could not list the images: the store is locked by another agent-vm|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

section "coming back to the window"
store "$BEHIND"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.activated
check "status is read again"         "status --json" "$(fake_log)"
check "the note is gone, Update is on, and the ticks are as they were" "|1|0 1 0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")|$("$PB" "agentvm_choices_$UUID" get)"

section "no virtual machine slot is free"
store "$BEHIND"' | .runningVMs.count = 2'
omc_run AgentVM.update.activated
check "the window warns, and Update stays on: a slot may be free by the click" \
    "No virtual machine slot is free now (2 of 2 running), and an update needs one: it fails at once until a box or a build stops.|1" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"

section "what stands in the way"
store "$BEHIND"' | (.images[] | select(.name == "dev-acp")).updating = true'
omc_run AgentVM.update.activated
check "another command is changing the image" "Another agent-vm command is changing this image now. It can be updated when that ends.|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
store "$BEHIND"
/usr/bin/jq -n '[{id: "20260930-120000-0000e1", command: ["image", "setup", "dev-acp", "--json"], targets: ["image:dev-acp"],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
omc_run AgentVM.update.activated
check "a job holds the image"        "A job holds this image now (Setting up, 12 s so far). It can be updated when the job ends.|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.start
check "  Update, clicked anyway, starts nothing" "" "$(started)"
/bin/rm -f "$JOBS"
store "$BEHIND"' | (.images[] | select(.name == "dev-acp")) |= . + {state: "failed", failure: "the build was canceled", needs: []}'
omc_run AgentVM.update.activated
check "the image is not ready"       "Only a ready image can be updated, and this one is not: Failed: the build was canceled.|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
store "$BEHIND"' | .images |= map(select(.name != "dev-acp"))'
omc_run AgentVM.update.activated
check "the image is gone"            "There is no image named dev-acp any more.|0" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.start
check "  Update starts nothing"      "" "$(started)"
store "$BEHIND"
omc_run AgentVM.update.close
printf '0.1.0\n' > "$FAKE_AGENTVM_DIR/version"
: > "$FAKE_AGENTVM_DIR/log"
open_update dev-acp
check "an agent-vm that is too old is not asked for status" "--version" "$(fake_log)"
check "  the window says why, and Update is off" "yes|0" \
    "$(ui_value "$UPDATE_NOTE_ID" | /usr/bin/grep -q "AgentVM needs agent-vm $VERSION or newer" && echo yes)|$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/version"
omc_run AgentVM.update.close

section "Update: the job, its progress window, and the main window"
open_update dev-acp
tick true true false
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
alerts_reset
shown_command="$(ui_value "$UPDATE_COMMAND_ID")"
omc_run AgentVM.update.start
check_status "exits cleanly" 0
check "status is read first, then the job is started with the parts ticked" \
    "status --json|job start --json -- image update dev-acp --macos --tools" "$(fake_log | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$shown_command" "agent-vm $(started | /usr/bin/sed 's/^job start --json -- //')"
check "the job's progress window is asked for" "1|$APP_PID progress:$FIRST" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
check "the update window closes, its Update off since the job started" "1|0" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(enabled "$UPDATE_START_ID")"
check "no alert"                     "" "$(ui_alert_title)"
check "the main window read the lists again, and follows the job" "hammer.fill${TAB}Updating - macOS 27.0 - from dev-node|Updating, 12 s so far" \
    "$(ui_rows "$MAIN_IMAGES_ID" "$MAIN_UUID" | row_named dev-acp | /usr/bin/cut -f2,3)|$(ui_value "$MAIN_IMAGE_STATE_ID" "$MAIN_UUID")"
check "  it watches the job, so its end is said" "$FIRST" "$(/usr/bin/grep -x "$FIRST" "$TMPDIR/AgentVM/$MAIN_UUID/jobs-watched")"
check "  and its Update... is off"   "0" "$(ui_enabled "$MAIN_IMAGE_UPDATE_ID" "$MAIN_UUID")"
omc_run AgentVM.update.close
check "closing: the image has no update window, and the window keeps nothing" "||" \
    "$(registered dev-acp)|$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_choices_$UUID" get)"
check "  its cache is gone"          "" "$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)"
# The job ends: the main window says so, as for any job it watched.
/usr/bin/jq "map(if .id == \"$FIRST\" then . + {state: \"done\", status: 0, endedAt: \"2026-09-30T12:05:00Z\"} else . end)" "$JOBS" > "$JOBS.new" \
    && /bin/mv "$JOBS.new" "$JOBS"
in_window "$MAIN_UUID"
( AGENTVM_APP_POLL_PASSES=1; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
check "when the update ends, the main window's toast" "1" "$(ui_calls 'omc_present_toast Image dev-acp is up to date. 5')"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "an update that fails within the moment"
# The job has failed by the time the main window reads: it is watched from the start, so its end
# is said though the window never saw it running.
printf 'failed\n' > "$FAKE_AGENTVM_DIR/job-start-state"
printf 'no virtual machine slot is free\n' > "$FAKE_AGENTVM_DIR/job-start-error"
open_update dev-acp
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.start
/bin/rm -f "$FAKE_AGENTVM_DIR/job-start-state" "$FAKE_AGENTVM_DIR/job-start-error"
check "the job was started"          "job start --json -- image update dev-acp --macos --tools --guest" "$(started)"
check "the main window says that it failed, and why" "Image dev-acp was not updated|no virtual machine slot is free" \
    "$(ui_alert_title "$MAIN_UUID")|$(ui_alert_message "$MAIN_UUID")"
omc_run AgentVM.update.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "Update with no main window open"
in_window "$MAIN_UUID"
omc_run AgentVM.main.close
open_update dev-acp
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_run AgentVM.update.start
check_status "exits cleanly" 0
check "the job starts, and its progress window is asked for" "job start --json -- image update dev-acp --macos --tools --guest|1" \
    "$(started)|$(chain_asked AgentVM.progress)"
check "nothing is read for a main window that is not there" "status --json|job start --json -- image update dev-acp --macos --tools --guest" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  and no cache folder is made for one" "" "$(/bin/ls "$TMPDIR/AgentVM/$MAIN_UUID" 2>/dev/null)"
omc_run AgentVM.update.close
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"

section "agent-vm refuses the job"
open_update dev-acp
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
chains_reset
alerts_reset
omc_run AgentVM.update.start
check "an alert, in agent-vm's words" "The update of image dev-acp was not started|the store is locked by another agent-vm" \
    "$(ui_alert_title)|$(ui_alert_message)"
check "no progress window, and the update window stays, with Update on again" "0|0|1" \
    "$(chain_asked AgentVM.progress)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"

section "Update: only what the window kept, and only for its image"
: > "$FAKE_AGENTVM_DIR/log"
"$PB" "agentvm_choices_$UUID" set "1 1 1 --set x=y"
omc_run AgentVM.update.start
check "choices that are not three ticks start nothing" "" "$(started)"
"$PB" "agentvm_choices_$UUID" set "1 0 0"
"$PB" "agentvm_image_$UUID" set "--json"
omc_run AgentVM.update.start
check "an image name that is not one starts nothing" "" "$(started)"
"$PB" "agentvm_image_$UUID" set dev-acp

section "Cancel"
omc_run AgentVM.update.cancel
check "closes the window"            "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  and starts nothing"         "" "$(started)"
omc_run AgentVM.update.close

section "agent-vm cannot be read at opening"
store "$BEHIND"
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
open_update dev-acp
check "the window says why, keeps no ticks yet, and Update is off" "agent-vm could not list the images: the store is locked by another agent-vm||0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$("$PB" "agentvm_choices_$UUID" get)|$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.update.activated
check "the first reading that succeeds ticks what needs updating, as an opening does" "true true true|1 1 1" "$(ticks)"
check "  and the command and Update follow the ticks" "agent-vm image update dev-acp --macos --tools --guest|1" \
    "$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
tick false true false
omc_run AgentVM.update.activated
check "a later reading leaves the ticks and the checkboxes alone" "0 1 0|0" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_calls "${UUID}${TAB}${UPDATE_MACOS_ID}${TAB}false")"
omc_run AgentVM.update.close
printf 'the store is locked by another agent-vm\n' > "$FAKE_AGENTVM_DIR/fail-status"
open_update dev-acp
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.update.check
check "Check Now, as the first reading that succeeds, ticks them too" "true true true|1 1 1" "$(ticks)"
omc_run AgentVM.update.close

section "an image whose macOS and guest daemon versions are not on record"
store "$BEHIND"' | (.images[] | select(.name == "dev-agents")) |= del(.macOSVersion, .macOSBuild, .guestVersion)'
open_update dev-agents
check "the state line does not show a placeholder" "Its macOS version is not known. Not updated since it was built." "$(ui_value "$UPDATE_STATE_ID")"
check "macOS: the newest is not called a new major version" \
    "No newer macOS is known for this image: the newest is 27.0.1 (26A434), as of Sep 29, 2026. The update asks Apple again, and installs what is offered." \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")"
check "the guest daemon: replaced, without a version to name" \
    "The image's agent-vm-guest, whose version is not on record, is replaced by this agent-vm's, $VERSION. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
omc_run AgentVM.update.close
store '(.images[] | select(.name == "dev-agents")) |= del(.macOSVersion, .macOSBuild)'
open_update dev-agents
check "Apple never asked: no major version to name either" \
    "Apple has not been asked which macOS is the newest: Check Now asks. The update asks too, and installs what Apple offers within the image's major version." \
    "$(ui_value "$UPDATE_MACOS_TEXT_ID")"
omc_run AgentVM.update.close

section "the window closes while agent-vm is read"
# An agent-vm that, asked for status, first does what closing the window does: Cancel or the close
# button, clicked while Update or Check Now waits for agent-vm.
CLOSING="$OMCTEST_WORK/closing_agent_vm.sh"
printf '#!/bin/sh\n[ "$1" = "status" ] && /bin/sh "%s/AgentVM.update.close.sh"\nexec "%s" "$@"\n' "$APP_SCRIPTS" "$FAKE_AGENTVM" > "$CLOSING"
/bin/chmod +x "$CLOSING"
store "$BEHIND"
open_update dev-acp
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
( AGENTVM_APP_AGENT_VM="$CLOSING"; export AGENTVM_APP_AGENT_VM; omc_run AgentVM.update.start )
check "Update: status was being read"  "status --json" "$(fake_log | /usr/bin/sed -n '1p')"
check "  nothing is started, and no progress window is asked for" "|0" "$(started)|$(chain_asked AgentVM.progress)"
check "  the cache the reading made again is gone, and the window keeps nothing" "||" \
    "$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)|$("$PB" "agentvm_image_$UUID" get)|$("$PB" "agentvm_choices_$UUID" get)"
open_update dev-acp
tick false true true
: > "$FAKE_AGENTVM_DIR/log"
( AGENTVM_APP_AGENT_VM="$CLOSING"; export AGENTVM_APP_AGENT_VM; omc_run AgentVM.update.check )
check "Check Now: Apple was being asked" "status --check-updates --json" "$(fake_log)"
check "  the closed window keeps no ticks, and no cache" "||" \
    "$("$PB" "agentvm_choices_$UUID" get)|$("$PB" "agentvm_image_$UUID" get)|$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)"

section "a second Update while the first is worked on, and a window that closes while it is painted"
store "$BEHIND"
open_update dev-acp
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.start
check "a second click: agent-vm is not run, nothing is started" "|" "$(fake_log)|$(started)"
check "  the other click's mark is not taken away" "click-$$" "$("$PB" "agentvm_busy_$UUID" get)"
"$PB" "agentvm_busy_$UUID" set ""
# The window's tools, with one that does what closing the window does before the first write of
# the window's title line: the painting that follows reads the cache, which makes its folder again.
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
            OMC_OMC_SUPPORT_PATH="$REAL_TOOLS" /bin/sh "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/AgentVM.update.close.sh"
        fi ;;
esac
exec "$REAL_TOOLS/$tool" "$@"
TOOL
/bin/chmod +x "$CLOSING_TOOLS/closing_tool"
for tool in "$REAL_TOOLS"/*; do
    /bin/ln -sf "$tool" "$CLOSING_TOOLS/${tool##*/}"
done
/bin/rm -f "$CLOSING_TOOLS/omc_dialog_control"
/bin/cp "$CLOSING_TOOLS/closing_tool" "$CLOSING_TOOLS/omc_dialog_control"
/bin/rm -f "$CLOSE_MARK"
: > "$FAKE_AGENTVM_DIR/log"
( CLOSE_BEFORE="omc_dialog_control $UUID $UPDATE_TITLE_ID *"; OMC_OMC_SUPPORT_PATH="$CLOSING_TOOLS"
  export CLOSE_BEFORE CLOSE_MARK REAL_TOOLS OMC_OMC_SUPPORT_PATH
  omc_run AgentVM.update.start )
check "closed while Update painted: nothing is started, and no cache folder is left" "closed||no" \
    "$([ -e "$CLOSE_MARK" ] && echo closed)|$(started)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"

section "the library: the parts as options, and the job"
check "all three, in agent-vm's order" "--macos --tools --guest" "$(lib agentvm_image_update_flags 1 1 1)"
check "one"                          "--tools" "$(lib agentvm_image_update_flags 0 1 0)"
check "none, and values that are not 1" "|" "$(lib agentvm_image_update_flags 0 0 0)|$(lib agentvm_image_update_flags true yes "")"
fake_reset
id="$(with_fake agentvm_job_image_update dev-acp 1 0 1)"
check "the job is started, and its id returned" "0|$FIRST|job start --json -- image update dev-acp --macos --guest" "$?|$id|$(fake_log)"
fake_reset
with_fake agentvm_job_image_update dev-acp 0 0 0 >/dev/null
check "no part asked for: refused, since agent-vm would take that for all three" "2|" "$?|$(fake_log)"
with_fake agentvm_job_image_update "--macos" 1 1 1 >/dev/null
check "a name agent-vm would refuse is refused first" "2|" "$?|$(fake_log)"
with_fake agentvm_status_checked >/dev/null
check "asking Apple is one status call" "0|status --check-updates --json" "$?|$(fake_log)"

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
