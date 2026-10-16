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
    && [ -n "$UPDATE_STATE_ID" ] && [ -n "$UPDATE_SYSTEM_ID" ] && [ -n "$UPDATE_SYSTEM_TEXT_ID" ] && [ -n "$UPDATE_CHECK_ID" ] \
    && [ -n "$UPDATE_TOOLS_ID" ] && [ -n "$UPDATE_TOOLS_TEXT_ID" ] && [ -n "$UPDATE_GUEST_ID" ] && [ -n "$UPDATE_GUEST_TEXT_ID" ] \
    && [ -n "$UPDATE_AFTER_ID" ] && [ -n "$UPDATE_COMMAND_ID" ] && [ -n "$UPDATE_NOTE_ID" ] && [ -n "$UPDATE_START_ID" ] || {
    printf '55-update-window: no view ids imported from the libraries\n' >&2
    exit 1
}
# The views of the recipe slots are a base each plus their slot.
update_base() {
    /usr/bin/sed -n "s/^$1=\\([0-9][0-9]*\\)\$/\\1/p" "$APP_SCRIPTS/lib.agentvm.update.sh"
}
UPDATE_SLOT_BASE="$(update_base UPDATE_SLOT_BASE)"
UPDATE_SLOT_NAME_BASE="$(update_base UPDATE_SLOT_NAME_BASE)"
UPDATE_SLOT_TEXT_BASE="$(update_base UPDATE_SLOT_TEXT_BASE)"
UPDATE_CHOOSE_BASE="$(update_base UPDATE_CHOOSE_BASE)"
UPDATE_CLEAR_BASE="$(update_base UPDATE_CLEAR_BASE)"
[ -n "$UPDATE_SLOT_BASE" ] && [ -n "$UPDATE_SLOT_NAME_BASE" ] && [ -n "$UPDATE_SLOT_TEXT_BASE" ] && [ -n "$UPDATE_CHOOSE_BASE" ] \
    && [ -n "$UPDATE_CLEAR_BASE" ] && [ -n "$UPDATE_PARTS_ID" ] && [ -n "$UPDATE_RECIPES_ID" ] && [ -n "$UPDATE_NEXT_ID" ] \
    && [ -n "$UPDATE_BACK_ID" ] && [ -n "$UPDATE_RECIPES_TEXT_ID" ] || {
    printf '55-update-window: no recipe slot bases or step ids in lib.agentvm.update.sh\n' >&2
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
    omc_control "$UPDATE_SYSTEM_ID" "$1"
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
    printf '%s %s %s|%s\n' "$(ui_value "$UPDATE_SYSTEM_ID")" "$(ui_value "$UPDATE_TOOLS_ID")" "$(ui_value "$UPDATE_GUEST_ID")" \
        "$("$PB" "agentvm_choices_$UUID" get)"
}

# after_failure  ->  the window's line about what an update that fails or is stopped leaves.
after_failure() {
    ui_value "$UPDATE_AFTER_ID" | /usr/bin/tail -1
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
check "  and its System row says when it was last updated" "macOS 27.0 (26A428), updated Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
select_image dev-acp
check "one never updated says only its system" "macOS 27.0 (26A428)" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
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
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")"
check "the tools: the recipes it keeps" \
    "Runs the update steps of the recipes this image keeps (dev-acp), then every recipe's checks. Not run since the image was built. Continue lists them." \
    "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
check "the guest daemon: another version, replaced by this agent-vm's" \
    "The image's agent-vm-guest 0.2.18 is replaced by this agent-vm's, $VERSION. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then. With another part ticked too, the daemon is replaced first, and stays even if that part fails." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
check "afterwards: its box, and what a failure leaves: the guest daemon, which goes first when another part is ticked" \
    "Boxes made from it (s3) keep what they have until they are recreated.|The image can be used meanwhile: a box made during the update gets the image as it was.|An update that fails or is stopped leaves the image as it is now, except for its guest daemon once that is replaced." \
    "$(ui_value "$UPDATE_AFTER_ID" | /usr/bin/paste -sd '|' -)"
check "all three have something to do: all three ticked" "true true true|1 1 1" "$(ticks)"
check "the command it would run"     "agent-vm image update dev-acp --system --tools --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
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
for bad in "" "$APP_PID network:dev-acp" "1 update:dev-acp" "$APP_PID update:../x" "$APP_PID update:_dev" "$APP_PID update:--guest"; do
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
check "macOS alone"                  "1 0 0|agent-vm image update dev-acp --system|1" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
check "  one part: a failure leaves the image as it is" "An update that fails or is stopped leaves the image as it is now." "$(after_failure)"
tick false true true
check "the tools and the guest daemon" "0 1 1|agent-vm image update dev-acp --tools --guest" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")"
check "  the daemon goes first, so a failure may leave it replaced" \
    "An update that fails or is stopped leaves the image as it is now, except for its guest daemon once that is replaced." "$(after_failure)"
tick true true false
check "macOS and the tools are one update: a failure leaves the image as it is" "An update that fails or is stopped leaves the image as it is now." "$(after_failure)"
tick false false true
check "the guest daemon alone is one update too" "An update that fails or is stopped leaves the image as it is now." "$(after_failure)"
tick true false true
check "macOS and the guest daemon: the daemon goes first" \
    "An update that fails or is stopped leaves the image as it is now, except for its guest daemon once that is replaced." "$(after_failure)"
tick false false false
check "nothing ticked: no command, and Update is off" "0 0 0|Tick what to update.|0" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
tick yes 1 "true --set x=y"
check "a value that is not a checkbox's is not a tick" "0 0 0|Tick what to update." \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_value "$UPDATE_COMMAND_ID")"
check "a click asks agent-vm nothing" "" "$(fake_log)"
# A repaint must not undo a click made while it ran: only the opening sets the checkboxes.
check "a click's handler does not set the checkboxes" "0" "$(ui_calls "${UUID}${TAB}${UPDATE_SYSTEM_ID}${TAB}false")"

section "an image that keeps no recipes, with a guest daemon that lacks a feature"
store "$BEHIND"
open_update dev-node
check "the tools: nothing to refresh" "This image keeps no recipes, so it has no tools an update can refresh." "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
check "  the checkbox is off and cannot be ticked" "false|0" "$(ui_value "$UPDATE_TOOLS_ID")|$(enabled "$UPDATE_TOOLS_ID")"
check "macOS: not behind what Apple last said" \
    "No newer macOS is known for this image: the newest is 27.0.1 (26A434), as of Sep 29, 2026. The update asks Apple again, and installs what is offered." \
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")"
check "the guest daemon: what the new one adds" \
    "The image's agent-vm-guest 0.2.18 is replaced by this agent-vm's, $VERSION, which adds terminal-pixels. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then. With another part ticked too, the daemon is replaced first, and stays even if that part fails." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
check "afterwards: the images built from it" \
    "Images built from it (dev-acp and dev-agents) are not updated with it: each is updated by itself." \
    "$(ui_value "$UPDATE_AFTER_ID" | /usr/bin/sed -n '1p')"
check "only the guest daemon is ticked" "false false true|0 0 1" "$(ticks)"
check "the command"                  "agent-vm image update dev-node --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
tick true true true
check "a tick on the tools that reached the handler anyway is dropped" "agent-vm image update dev-node --system --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
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
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")|$(ui_value "$UPDATE_SYSTEM_ID")"
omc_run AgentVM.update.close
store '.newestMacOS = {version: "28.0", build: "27A100", checkedAt: "2026-09-29T09:00:00Z"}'
open_update dev-agents
check "a new major version is not what an update installs" \
    "The newest macOS is 28.0 (as of Sep 29, 2026), a new major version, which an update does not install: the image is built again for that. The update still asks Apple for what it offers within macOS 27.|false" \
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")|$(ui_value "$UPDATE_SYSTEM_ID")"
omc_run AgentVM.update.close

section "an image updated before"
store "$BEHIND"' | (.images[] | select(.name == "dev")).recipes = [{name: "homebrew", folder: "1-homebrew"}, {name: "node", folder: "2-node"}]'
open_update dev
check "when it was last updated"     "macOS 27.0 (26A428). Last updated on Sep 30, 2026." "$(ui_value "$UPDATE_STATE_ID")"
check "the recipes in order, and when their update steps last ran" \
    "Runs the update steps of the recipes this image keeps (homebrew, node), then every recipe's checks. Last run on Sep 30, 2026. Continue lists them." \
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
check "the window says what is available" "macOS 27.0.1 (26A434) is available" "$(ui_value "$UPDATE_SYSTEM_TEXT_ID" | /usr/bin/cut -c1-34)"
check "  ticks macOS, and keeps the other ticks" "true true true|1 1 1" "$(ticks)"
check "  the command follows"        "agent-vm image update dev-acp --system --tools --guest" "$(ui_value "$UPDATE_COMMAND_ID")"
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
    "No virtual machine slot is free now (2 of 2 macOS virtual machines running), and an update needs one: it fails at once until a macOS box or build stops.|1" \
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
check "a job holds the image"        "A job holds this image now (Setting up, elapsed 12 s). It can be updated when the job ends.|0" \
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
    "status --json|job start --json -- image update dev-acp --system --tools" "$(fake_log | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$shown_command" "agent-vm $(started | /usr/bin/sed 's/^job start --json -- //')"
check "the job's progress window is asked for" "1|$APP_PID progress:$FIRST" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
check "the update window closes, its Update off since the job started" "1|0" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(enabled "$UPDATE_START_ID")"
check "no alert"                     "" "$(ui_alert_title)"
check "the main window read the lists again, and follows the job" "hammer.fill${TAB}Updating - macOS 27.0 - from dev-node|Updating, elapsed 12 s" \
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
check "the job was started"          "job start --json -- image update dev-acp --system --tools --guest" "$(started)"
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
check "the job starts, and its progress window is asked for" "job start --json -- image update dev-acp --system --tools --guest|1" \
    "$(started)|$(chain_asked AgentVM.progress)"
check "nothing is read for a main window that is not there" "status --json|job start --json -- image update dev-acp --system --tools --guest" \
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
check "  and the command and Update follow the ticks" "agent-vm image update dev-acp --system --tools --guest|1" \
    "$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
tick false true false
omc_run AgentVM.update.activated
check "a later reading leaves the ticks and the checkboxes alone" "0 1 0|0" \
    "$("$PB" "agentvm_choices_$UUID" get)|$(ui_calls "${UUID}${TAB}${UPDATE_SYSTEM_ID}${TAB}false")"
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
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")"
check "the guest daemon: replaced, without a version to name" \
    "The image's agent-vm-guest, whose version is not on record, is replaced by this agent-vm's, $VERSION. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then. With another part ticked too, the daemon is replaced first, and stays even if that part fails." \
    "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
omc_run AgentVM.update.close
store '(.images[] | select(.name == "dev-agents")) |= del(.macOSVersion, .macOSBuild)'
open_update dev-agents
check "Apple never asked: no major version to name either" \
    "Apple has not been asked which macOS is the newest: Check Now asks. The update asks too, and installs what Apple offers within the image's major version." \
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")"
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

# -----------------------------------------------------------------------------------------------
section "a Linux image"
# The store with both kinds. deb-agents keeps two recipes and has an older guest daemon; deb keeps
# none. agent-vm looked at each one's packages when it was built.
# mixed <jq edit of status-mixed.json>  ->  the fake answers status with that.
mixed() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
}
fake_reset
mixed '.'
for image in deb deb-agents dev-acp; do
    "$PB" "agentvm_window_update_$image" set ""
done
open_update deb-agents
check "its system in agent-vm's words, and that it was not updated" \
    "Debian GNU/Linux 13 (trixie). Not updated since it was built." "$(ui_value "$UPDATE_STATE_ID")"
check "the system's part: the package updates of its distribution, and when they were last looked for" \
    "Installs the package updates of Debian 13, which takes seconds to minutes. When they bring a new kernel, the image is started once more to check it before the update is kept. Its packages were last looked at on Oct 7, 2026." \
    "$(ui_value "$UPDATE_SYSTEM_TEXT_ID")"
check "the system is ticked, though nobody can say beforehand that it needs doing; the tools for its recipes; the guest daemon, which is another version" \
    "true true true|1 1 1" "$(ticks)"
check "Check Now is not shown: Apple has nothing to say of a Linux image" "0" "$(ui_visible "$UPDATE_CHECK_ID")"
check "the guest daemon's part says nothing of Full Disk Access" \
    "The image's agent-vm-guest 0.7.9 is replaced by this agent-vm's, $VERSION. With another part ticked too, the daemon is replaced first, and stays even if that part fails." "$(ui_value "$UPDATE_GUEST_TEXT_ID")"
check "the command it would run: the system's part is --system" \
    "agent-vm image update deb-agents --system --tools --guest|1" "$(ui_value "$UPDATE_COMMAND_ID")|$(enabled "$UPDATE_START_ID")"
mixed '.runningVMs = {count: 2, limit: 2, linuxBoxes: 0, linuxImages: 0}'
omc_run AgentVM.update.activated
check "both macOS places taken: no warning, since a Linux image needs none" "|1" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.update.check
check "Check Now, however it came to run, asks Apple nothing for a Linux image" "" "$(fake_log)"
mixed '.'
: > "$FAKE_AGENTVM_DIR/log"
shown_command="$(ui_value "$UPDATE_COMMAND_ID")"
omc_run AgentVM.update.start
check "Update starts the job with the parts ticked" "job start --json -- image update deb-agents --system --tools --guest" "$(started)"
check "  and the command line shown is the one run" "$shown_command" "agent-vm $(started | /usr/bin/sed 's/^job start --json -- //')"
/bin/rm -f "$JOBS"
"$PB" agentvm_window_update_deb-agents set ""
"$PB" agentvm_open_request_progress set ""
open_update deb
check "a Linux image that keeps no recipes: the system and the guest daemon, and the tools off" \
    "true false true|1 0 1|0|agent-vm image update deb --system --guest" \
    "$(ticks)|$(enabled "$UPDATE_TOOLS_ID")|$(ui_value "$UPDATE_COMMAND_ID")"
"$PB" agentvm_window_update_deb set ""
open_update dev-acp
check "a macOS image in the same store: Check Now is shown, and its macOS is what is said" "1|macOS 27.0 (26A428). Not updated since it was built." \
    "$(ui_visible "$UPDATE_CHECK_ID")|$(ui_value "$UPDATE_STATE_ID")"
mixed '.runningVMs = {count: 3, limit: 2, linuxBoxes: 1, linuxImages: 1}'
omc_run AgentVM.update.activated
check "  three machines run, two of them Linux: a place is free for a macOS update, and the note is empty" "" \
    "$(ui_value "$UPDATE_NOTE_ID")"
mixed '.runningVMs = {count: 3, limit: 2, linuxBoxes: 1, linuxImages: 0}'
omc_run AgentVM.update.activated
check "  three machines run, one of them Linux: both places are taken" \
    "No virtual machine slot is free now (2 of 2 macOS virtual machines running), and an update needs one: it fails at once until a macOS box or build stops." \
    "$(ui_value "$UPDATE_NOTE_ID")"
"$PB" agentvm_window_update_dev-acp set ""

section "two steps: the recipes, and a new file for a recipe's input (agent-vm 0.7.57)"
# dev-acp keeps an xcode recipe built with Xcode_27.xip, as agent-vm 0.7.57 lists one.
XCODE='| (.images[] | select(.name == "dev-acp")).recipes += [{name: "xcode", folder: "2-xcode", description: "Xcode from a .xip",
    inputs: [{name: "xcode", file: "Xcode_27.xip", path: "/Users/you/Downloads/Xcode_27.xip", bytes: 1, sha256: "a"}]}]'
NEW_XIP="$OMCTEST_WORK/Xcode 27.1.xip"
: > "$NEW_XIP"
# choose_input <slot> <path>  ->  the file dialog answered, and that recipe slot's Choose... clicked.
choose_input() {
    omc_dialog_answer choose_file "$2"
    omc_trigger "$((UPDATE_CHOOSE_BASE + $1))"
    omc_run AgentVM.update.input
}
# clear_input <slot>  ->  that recipe slot's Clear clicked.
clear_input() {
    omc_trigger "$((UPDATE_CLEAR_BASE + $1))"
    omc_run AgentVM.update.clear
}
# step  ->  what shows the step: the first panel, the second, Continue, Update, and Back on.
step() {
    printf '%s|%s|%s|%s|%s\n' "$(ui_visible "$UPDATE_PARTS_ID")" "$(ui_visible "$UPDATE_RECIPES_ID")" \
        "$(ui_visible "$UPDATE_NEXT_ID")" "$(ui_visible "$UPDATE_START_ID")" "$(enabled "$UPDATE_BACK_ID")"
}
# slot <n>  ->  a recipe slot: shown, its name, Choose... shown, Clear shown.
slot() {
    printf '%s|%s|%s|%s\n' "$(ui_visible $((UPDATE_SLOT_BASE + $1)))" "$(ui_value $((UPDATE_SLOT_NAME_BASE + $1)))" \
        "$(ui_visible $((UPDATE_CHOOSE_BASE + $1)))" "$(ui_visible $((UPDATE_CLEAR_BASE + $1)))"
}
slot_text() {
    ui_value $((UPDATE_SLOT_TEXT_BASE + $1)) | /usr/bin/paste -sd '|' -
}
chosen_kept() {
    [ -f "$TMPDIR/AgentVM/$UUID/chosen.tsv" ] && echo yes || echo no
}
store "$BEHIND$XCODE"
open_update dev-acp
tick true false false
check "without the tools: one step, with Update" "1|0|0|1|0" "$(step)"
check "  the tools part names what ticking it adds" \
    "Runs the update steps of the recipes this image keeps (dev-acp, xcode), then every recipe's checks. Not run since the image was built. Ticking it adds a step that lists them, and takes a newer file for xcode." \
    "$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
omc_run AgentVM.update.next
check "  Continue, however it came to run, has no second step to show" "1|0|0|1|0" "$(step)"
tick true true false
check "with the tools: Continue in Update's place" "1|0|1|0|0" "$(step)"
choose_input 2 "$NEW_XIP"
check "  a Choose... click that reaches the first step keeps nothing" "no" "$(chosen_kept)"
omc_run AgentVM.update.next
check_status "Continue exits cleanly" 0
check "Continue: the second step, with Back and Update" "0|1|0|1|1" "$(step)"
check "  the recipes in the order they run, each with its name; the slots past them hidden" "1|dev-acp|0|0 1|xcode|1|0 0" \
    "$(slot 1) $(slot 2) $(ui_visible $((UPDATE_SLOT_BASE + 3)))"
check "  a recipe without inputs: its description" \
    "ACP agents: Claude Agent ACP, Codex ACP and opencode (needs Node: build from an image with Recipes/homebrew-node)" "$(slot_text 1)"
check "  the recipe with an input: the file it was built with, and its button" \
    "Xcode from a .xip|Built with Xcode_27.xip. Choose xcode... gives it a newer file, and the recipe then runs again with it.|Choose xcode..." \
    "$(slot_text 2)|$(ui_prop $((UPDATE_CHOOSE_BASE + 2)) title)"
check "  which input each slot's button is for" "- xcode - - - - - - - - - -" "$("$PB" "agentvm_inputs_$UUID" get)"
check "  what the tools update does with them" \
    "The tools update runs the update steps of these recipes, in this order, then every recipe's checks. A recipe that came with agent-vm is first replaced by the installed version, when that is newer. Not run since the image was built." \
    "$(ui_value "$UPDATE_RECIPES_TEXT_ID")"
check "  Update is on, and the command is the step's" "1|agent-vm image update dev-acp --system --tools" "$(enabled "$UPDATE_START_ID")|$(ui_value "$UPDATE_COMMAND_ID")"
choose_input 2 ""
check "the dialog canceled: nothing changes" "no|agent-vm image update dev-acp --system --tools" "$(chosen_kept)|$(ui_value "$UPDATE_COMMAND_ID")"
choose_input 2 "$NEW_XIP"
check_status "exits cleanly" 0
check "a file chosen: the command gives it, and Clear is shown" \
    "agent-vm image update dev-acp --system --tools --input 'xcode=$NEW_XIP'|1|xcode|1|1" "$(ui_value "$UPDATE_COMMAND_ID")|$(slot 2)"
check "  the slot says the recipe runs again with it" \
    "Xcode from a .xip|Runs again with Xcode 27.1.xip in place of Xcode_27.xip: what it installs is installed from the new file, instead of by its update steps." \
    "$(slot_text 2)"
check "  and the step says what that takes" "Running a recipe again needs about 10 GB free, as a build does." \
    "$(ui_value "$UPDATE_RECIPES_TEXT_ID" | /usr/bin/tail -1)"
check "  Update is on"                "1" "$(enabled "$UPDATE_START_ID")"
choose_input 1 "$NEW_XIP"
check "a click on a slot without a button keeps nothing more" "1" "$(/usr/bin/awk 'END { print NR }' "$TMPDIR/AgentVM/$UUID/chosen.tsv")"
clear_input 2
check "Clear forgets the file: the command, the slot and the button follow" \
    "agent-vm image update dev-acp --system --tools|1|xcode|1|0|no" "$(ui_value "$UPDATE_COMMAND_ID")|$(slot 2)|$(chosen_kept)"
choose_input 2 "$NEW_XIP"
clear_input 1
check "  a Clear of a slot without an input changes nothing" "yes" "$(chosen_kept)"
omc_run AgentVM.update.back
check "Back: the first step, with Continue" "1|0|1|0|0" "$(step)"
check "  the file stays, and the tools part names it" \
    "agent-vm image update dev-acp --system --tools --input 'xcode=$NEW_XIP'|Runs the update steps of the recipes this image keeps (dev-acp, xcode), then every recipe's checks. Not run since the image was built. Continue lists them, with the new file for xcode." \
    "$(ui_value "$UPDATE_COMMAND_ID")|$(ui_value "$UPDATE_TOOLS_TEXT_ID")"
tick true false false
check "unticking the tools forgets the file" "agent-vm image update dev-acp --system|no|1|0|0|1|0" \
    "$(ui_value "$UPDATE_COMMAND_ID")|$(chosen_kept)|$(step)"
tick true true false
check "  ticking them again does not bring it back, and stays on the first step" "agent-vm image update dev-acp --system --tools|1|0|1|0|0" \
    "$(ui_value "$UPDATE_COMMAND_ID")|$(step)"
omc_run AgentVM.update.next
choose_input 2 "$NEW_XIP"
/bin/rm -f "$NEW_XIP"
omc_run AgentVM.update.activated
check "a file chosen that is gone: said, and Update is off, on the second step still" "The file chosen for xcode cannot be read any more: $NEW_XIP|0|0|1|0|1|1" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")|$(step)"
: > "$NEW_XIP"
omc_run AgentVM.update.activated
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
shown_command="$(ui_value "$UPDATE_COMMAND_ID")"
omc_run AgentVM.update.start
check "Update: the job gets the file as one argument" \
    "job start --json -- image update dev-acp --system --tools --input xcode=$NEW_XIP" "$(started)"
check "  the command line shown is the one run" "agent-vm image update dev-acp --system --tools --input 'xcode=$NEW_XIP'" "$shown_command"
check "  its progress window is asked for" "1" "$(chain_asked AgentVM.progress)"
omc_run AgentVM.update.close
check "closing keeps nothing of the window" "||" "$("$PB" "agentvm_inputs_$UUID" get)|$("$PB" "agentvm_step_$UUID" get)|$(/bin/ls "$TMPDIR/AgentVM/$UUID" 2>/dev/null)"
/bin/rm -f "$JOBS" "$FAKE_AGENTVM_DIR/job-count"
"$PB" agentvm_window_update_dev-acp set ""
"$PB" agentvm_open_request_progress set ""
open_update dev-acp
check "opened again: the first step" "1|0" "$(step | /usr/bin/cut -d'|' -f1-2)"
omc_run AgentVM.update.close

# A recipe kept twice (an image made before agent-vm 0.7.56), and one with two inputs: the slot's
# button is for its first input, and the second is given in Terminal.
store "$BEHIND"' | (.images[] | select(.name == "dev-acp")).recipes += [
    {name: "xcode", folder: "2-xcode", inputs: [{name: "xcode", file: "Xcode_27.xip", path: "/Users/you/Downloads/Xcode_27.xip"}]},
    {name: "xcode", folder: "3-xcode", inputs: [{name: "xcode", file: "Xcode_27.1.xip", path: "/Users/you/Downloads/Xcode_27.1.xip"}]},
    {name: "mine", folder: "4-mine", inputs: [{name: "kit", file: "kit.zip"}, {name: "data", file: "data.bin"}]}]'
open_update dev-acp
tick false true false
check "the tools part names only the inputs the next step has a button for" "Continue lists them, and takes a newer file for xcode and kit." \
    "$(ui_value "$UPDATE_TOOLS_TEXT_ID" | /usr/bin/sed 's/^.*built. //')"
omc_run AgentVM.update.next
check "a recipe kept twice: the later one takes the file, and the earlier one says so" \
    "1|xcode|0|0 1|xcode|1|0|A newer file for xcode goes to the xcode recipe listed after this one.|Built with Xcode_27.1.xip. Choose xcode... gives it a newer file, and the recipe then runs again with it." \
    "$(slot 2) $(slot 3)|$(slot_text 2)|$(slot_text 3)"
check "two inputs: the button is for the first, and the second is given in Terminal" \
    "Choose kit...|Built with kit.zip. Choose kit... gives it a newer file, and the recipe then runs again with it.|Built with data.bin for data. A newer one is given in Terminal: agent-vm image update dev-acp --tools --input data=<path>." \
    "$(ui_prop $((UPDATE_CHOOSE_BASE + 4)) title)|$(slot_text 4)"
check "  the inputs of the slots" "- - xcode kit - - - - - - - -" "$("$PB" "agentvm_inputs_$UUID" get)"
choose_input 3 "$NEW_XIP"
choose_input 4 "/Users/you/kit.zip"
check "  each button gives its own input" "--input 'xcode=$NEW_XIP' --input kit=/Users/you/kit.zip" \
    "$(ui_value "$UPDATE_COMMAND_ID" | /usr/bin/sed "s/^.* --tools //")"
: > "$OMCTEST_WORK/kit2.zip"
choose_input 4 "$OMCTEST_WORK/kit2.zip"
check "  choosing again replaces the file" "--input 'xcode=$NEW_XIP' --input kit=$OMCTEST_WORK/kit2.zip" \
    "$(ui_value "$UPDATE_COMMAND_ID" | /usr/bin/sed "s/^.* --tools //")"
check "  the recipe's other input has no file on record: said, and Update is off" \
    "The recipe mine runs again with its other files too, and the one for data (data.bin) is not where it was. Give all of its files in Terminal: agent-vm image update dev-acp --tools, with --input <name>=<path> for each.|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
clear_input 4
check "  Clear of that input: nothing stands in the way" "|1" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
omc_run AgentVM.update.close
/bin/rm -f "$OMCTEST_WORK/kit2.zip"
# The same, with the other input's file still where the record says.
: > "$OMCTEST_WORK/kit.zip"
: > "$OMCTEST_WORK/data.bin"
store "$BEHIND"' | (.images[] | select(.name == "dev-acp")).recipes += [{name: "mine", folder: "2-mine",
    inputs: [{name: "kit", file: "kit.zip"}, {name: "data", file: "data.bin", path: "'"$OMCTEST_WORK/data.bin"'"}]}]'
open_update dev-acp
tick false true false
omc_run AgentVM.update.next
choose_input 2 "$OMCTEST_WORK/kit.zip"
check "the other input's file is where it was: nothing stands in the way" "1" "$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$OMCTEST_WORK/data.bin"
omc_run AgentVM.update.activated
check "  and once it is gone, the note names it" \
    "The recipe mine runs again with its other files too, and the one for data (data.bin) is not where it was. Give all of its files in Terminal: agent-vm image update dev-acp --tools, with --input <name>=<path> for each.|0" \
    "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
omc_run AgentVM.update.back
tick false false false
check "  unticking the tools clears it" "|0" "$(ui_value "$UPDATE_NOTE_ID")|$(enabled "$UPDATE_START_ID")"
/bin/rm -f "$OMCTEST_WORK/kit.zip"
omc_run AgentVM.update.close
# More recipes than slots: the last ones are named in the step's line.
store "$BEHIND"' | (.images[] | select(.name == "dev-acp")).recipes += [range(2; 15) | {name: "r\(.)", folder: "\(.)-r\(.)"}]'
open_update dev-acp
tick false true false
omc_run AgentVM.update.next
check "fourteen recipes: twelve slots, and the last two named in the step's line" \
    "1|r12|0|0|The image keeps 14 recipes, and the last 2 are not listed: a newer file for one of them is given in Terminal." \
    "$(slot 12)|$(ui_value "$UPDATE_RECIPES_TEXT_ID" | /usr/bin/tail -1)"
omc_run AgentVM.update.close
/bin/rm -f "$NEW_XIP"
store "$BEHIND"

section "the library: the parts as options, and the job"
check "all three, in agent-vm's order" "--system --tools --guest" "$(lib agentvm_image_update_flags 1 1 1)"
check "one"                          "--tools" "$(lib agentvm_image_update_flags 0 1 0)"
check "none, and values that are not 1" "|" "$(lib agentvm_image_update_flags 0 0 0)|$(lib agentvm_image_update_flags true yes "")"
fake_reset
id="$(with_fake agentvm_job_image_update dev-acp 1 0 1)"
check "the job is started, and its id returned" "0|$FIRST|job start --json -- image update dev-acp --system --guest" "$?|$id|$(fake_log)"
fake_reset
with_fake agentvm_job_image_update dev-acp 0 0 0 >/dev/null
check "no part asked for: refused, since agent-vm would take that for all three" "2|" "$?|$(fake_log)"
with_fake agentvm_job_image_update "--macos" 1 1 1 >/dev/null
check "a name agent-vm would refuse is refused first" "2|" "$?|$(fake_log)"
check "the arguments with input files, one per line" "dev-acp|--tools|--input|xcode=/a b.xip|--input|kit=/k" \
    "$(lib agentvm_image_update_args dev-acp 0 1 0 "xcode=/a b.xip" kit=/k | /usr/bin/paste -sd '|' -)"
check "  as typed in Terminal"       "dev-acp --tools --input 'xcode=/a b.xip'" \
    "$(lib agentvm_image_update_args dev-acp 0 1 0 "xcode=/a b.xip" | lib agentvm_args_text)"
id="$(with_fake agentvm_job_image_update dev-acp 1 1 0 "xcode=/a b.xip")"
check "the job gets each input file as one argument" "0|$FIRST|job start --json -- image update dev-acp --system --tools --input xcode=/a b.xip" \
    "$?|$id|$(fake_log | /usr/bin/tail -1)"
for bad in "xcode=a.xip" "xcode=a=/b" "-x=/a" "bad-name=/a" "xcode" "=/a" "x=/a
b"; do
    fake_reset
    with_fake agentvm_job_image_update dev-acp 0 1 0 "$bad" >/dev/null
    refused=$?
    check "an input file that is not a name and an absolute path is refused: $(printf "%s" "$bad" | /usr/bin/tr "\n" " ")" "2|" "$refused|$(fake_log)"
done
fake_reset
with_fake agentvm_job_image_update dev-acp 1 0 0 "xcode=/a.xip" >/dev/null
check "an input file without the tools update is refused, as agent-vm would" "2|" "$?|$(fake_log)"
check "  with the reason"            "A new file for the input xcode is used by the tools update, which is not chosen." \
    "$(lib eval 'agentvm_image_update_args dev-acp 1 0 0 xcode=/a.xip >/dev/null; agentvm_last_error 2')"
with_fake agentvm_status_checked >/dev/null
check "asking Apple is one status call" "0|status --check-updates --json" "$?|$(fake_log)"

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no rows written as a value" "" "$(ui_suspect_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
