#!/bin/sh
# Tests/30-image-detail.test.sh - the image detail pane's measured facts (`image info`: tools,
# guest daemon, Full Disk Access, processors and memory, space, how long the build took), when
# they are read, Show in Finder for an image and for a box, and Delete with its question.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, and `image info` from
# fixtures/agentvm/image-info.json, which describes dev-acp (built from dev-node; box s3 is made
# from it). Finder is fake_open.sh. Dates are read in UTC.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_IMAGE_SPACE_ID" ] && [ -n "$MAIN_IMAGE_DELETE_ID" ] && [ -n "$MAIN_BOX_SHOW_ID" ] || {
    printf '30-image-detail: no view ids imported from lib.agentvm.main.sh\n' >&2
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
VERSION="$(lib_value AGENTVM_MIN_VERSION)"
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
UUID="$OMC_ACTIONUI_WINDOW_UUID"

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

# info <jq edit of image-info.json>  ->  the fake answers `image info dev-acp` with that.
info() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/image-info.json" > "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"
}

# open_window  ->  the main window, freshly opened on what store and info left.
open_window() {
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

# poll <passes>  ->  the poll loop, ended after that many passes.
poll() {
    ( AGENTVM_APP_POLL_PASSES="$1"; export AGENTVM_APP_POLL_PASSES; omc_run AgentVM.main.poll )
}

# select_image <name> / select_box <name>  ->  a click on that card.
select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}
select_box() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    omc_run AgentVM.main.box.selected
}

# asks  ->  how many times the fake was asked to measure an image.
asks() {
    fake_log | /usr/bin/grep -c '^image info'
}

# pending  ->  the image a Delete question was asked about.
pending() {
    "$PB" "agentvm_image_delete_$UUID" get
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

fake_reset
store '.'
open_window

# -----------------------------------------------------------------------------------------------
section "an image's measured facts, read when it is selected"
check "nothing selected at opening: nothing measured" "0" "$(asks)"
select_image dev-acp
check_status "the handler exits cleanly" 0
check "agent-vm measures the selected image once" "image info dev-acp --json" "$(fake_log | /usr/bin/grep '^image info')"
check "its tools: the recipe and the Command Line Tools" \
    "ACP agents: Claude Agent ACP, Codex ACP and opencode (needs Node: build from an image with Recipes/homebrew-node); Command Line Tools for Xcode 27.0-27.0" \
    "$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "the guest daemon and its features" \
    "0.2.18: terminal, prompt-notices, wallpaper, time-sync, user-session, terminal-pixels" "$(ui_value "$MAIN_IMAGE_GUEST_ID")"
check "Full Disk Access, and when it was checked" "granted (checked Oct 2, 2026)" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
check "processors and memory"   "4 CPUs, 8 GB" "$(ui_value "$MAIN_IMAGE_HARDWARE_ID")"
check "the space: all, its own, and what it added over its base" \
    "38.8 GB; 1.7 GB its own (what Delete frees); 1.7 GB added over dev-node" "$(ui_value "$MAIN_IMAGE_SPACE_ID")"
check "the day it was made, and how long the build took" "Sep 26, 2026, built in 2 min" "$(ui_value "$MAIN_IMAGE_CREATED_ID")"
check "the box made from it"    "s3 (running)" "$(ui_value "$MAIN_IMAGE_BOXES_ID")"
check "Delete is enabled"       "1" "$(enabled "$MAIN_IMAGE_DELETE_ID")"
check "a folder that is not on this Mac: Show in Finder is not" "0" "$(enabled "$MAIN_IMAGE_SHOW_ID")"

section "the poll loop does not measure again"
: > "$FAKE_AGENTVM_DIR/log"
poll 2
check "status only"             "0" "$(asks)"
check "the space is still shown" "38.8 GB" "$(ui_value "$MAIN_IMAGE_SPACE_ID" | /usr/bin/cut -d';' -f1)"

section "activation measures the selected image again"
info '.diskUsage.bytes = 40008120832'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.activated
check "once"                    "1" "$(asks)"
check "  with the new size"     "40.0 GB" "$(ui_value "$MAIN_IMAGE_SPACE_ID" | /usr/bin/cut -d';' -f1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"

section "measurements belong to the image they were read for"
# Two selections' handlers overlap: A's slower measuring lands after B was selected. The pane
# for B must not show A's facts.
"$PB" "agentvm_image_$UUID" set dev-agents
poll 1
check "dev-agents, with dev-acp's row in the cache: no size shown" "not measured" "$(ui_value "$MAIN_IMAGE_SPACE_ID")"
check "  nor its processors and memory" "-" "$(ui_value "$MAIN_IMAGE_HARDWARE_ID")"

section "an image agent-vm cannot measure"
# No image-info fixture for dev: image info says it has none, and the status row serves.
select_image dev
check "the space says why"      "not measured: no image dev; \`agent-vm image list\` shows the existing ones" \
    "$(ui_value "$MAIN_IMAGE_SPACE_ID")"
check "no recipe, no tools recorded" "macOS only" "$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "the guest daemon without its features" "0.2.18" "$(ui_value "$MAIN_IMAGE_GUEST_ID")"
check "Full Disk Access unknown: status says nothing" "-" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
check "the day, without a build time" "Sep 23, 2026" "$(ui_value "$MAIN_IMAGE_CREATED_ID")"
check "dev-acp's measurements are not shown for dev" "-" "$(ui_value "$MAIN_IMAGE_HARDWARE_ID")"
check "the images built from it" "dev-node and dev-xcode" "$(ui_value "$MAIN_IMAGE_DERIVED_ID")"
# The overlap again, with a failure: dev's failed measuring lands after dev-acp was selected.
"$PB" "agentvm_image_$UUID" set dev-acp
poll 1
check "dev-acp after dev's failure: its own last measurement, not dev's reason" "40.0 GB" "$(ui_value "$MAIN_IMAGE_SPACE_ID" | /usr/bin/cut -d';' -f1)"
select_image dev-node
check "without image info, a Full Disk Access need says not granted" "not granted" "$(ui_value "$MAIN_IMAGE_FDA_ID")"

section "a guest update and Full Disk Access, from image info"
store '(.images[] | select(.name == "dev-acp")).needs = [{kind: "guest-update"}, {kind: "full-disk-access", reason: "not-granted"}]'
info '.needs = [{kind: "guest-update", missing: ["terminal-pixels", "wallpaper"]}, {kind: "full-disk-access", reason: "not-granted"}]
    | .fullDiskAccess.granted = false'
poll 1
select_image dev-acp
check "what the update adds" \
    "Needs maintenance|Needs a guest update for agent-vm $VERSION, which adds terminal-pixels, wallpaper." \
    "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -)"
check "Full Disk Access not granted, and when it was checked" "not granted (checked Oct 2, 2026)" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
info '.fullDiskAccess.granted = true'
store '.'
poll 1
select_image dev-acp
check "granted, and when it was checked" "granted (checked Oct 2, 2026)" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
info 'del(.fullDiskAccess)'
store '.'
poll 1
select_image dev-acp
check "never checked" "not checked yet" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
check "  and no update: no maintenance" "" "$(ui_value "$MAIN_IMAGE_MAINTENANCE_ID")"
info '.fullDiskAccess.granted = true'
select_image dev-acp
store '(.images[] | select(.name == "dev-acp")).needs = [{kind: "full-disk-access", reason: "not-granted"}]'
poll 1
check "access lost after the measuring: status's need wins over the cached answer" "not granted" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
store '.'
poll 1
store '(.images[] | select(.name == "dev-acp")).recipe = null'
poll 1
select_image dev-acp
check "the Command Line Tools without a recipe: not macOS only" "Command Line Tools for Xcode 27.0-27.0" "$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
store '.'
/bin/rm -f "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"

# -----------------------------------------------------------------------------------------------
section "Show in Finder"
select_image dev-acp
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.show
check "a folder that is not on this Mac: nothing opens" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
image_folder="$OMCTEST_WORK/store/Images/dev-acp"
box_folder="$OMCTEST_WORK/store/Boxes/s3"
/bin/mkdir -p "$image_folder" "$box_folder"
store '(.images[] | select(.name == "dev-acp")).path = "'"$image_folder"'" | (.boxes[] | select(.box.name == "s3")).path = "'"$box_folder"'"'
poll 1
check "a folder on this Mac: Show in Finder is enabled" "1" "$(enabled "$MAIN_IMAGE_SHOW_ID")"
omc_run AgentVM.main.image.show
check "the image's folder, selected in Finder" "-R $image_folder" "$(/bin/cat "$FAKE_OPEN_LOG")"
: > "$FAKE_OPEN_LOG"
select_box s3
check "a box's folder on this Mac: its Show in Finder is enabled" "1" "$(enabled "$MAIN_BOX_SHOW_ID")"
omc_run AgentVM.main.box.show
check "the box's folder, selected in Finder" "-R $box_folder" "$(/bin/cat "$FAKE_OPEN_LOG")"
select_box try1
check "another box's folder is not on this Mac: disabled" "0" "$(enabled "$MAIN_BOX_SHOW_ID")"
select_box s3
select_box ""
check "no box selected: Show in Finder, in the bar under the list, is off" "0" "$(enabled "$MAIN_BOX_SHOW_ID")"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.box.show
check "no box selected: nothing opens" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
store '.'
poll 1

# -----------------------------------------------------------------------------------------------
section "Delete: the question"
select_image dev-acp
alerts_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.delete
check_status "exits cleanly" 0
check "reads status and measures the image again first" "status --json|image info dev-acp --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "asks" "Delete image dev-acp?" "$(ui_alert_title)"
check "  what it frees, the box made from it, and that it is final" \
    "The image's folder and disk are deleted, which frees about 1.7 GB. Boxes made from it (s3) keep working, but cannot be recreated. This cannot be undone." \
    "$(ui_alert_message)"
check "  Delete confirms" "AgentVM.main.image.delete.confirmed" "$(ui_alert_action Delete)"
check "  Cancel does nothing" "" "$(ui_alert_action Cancel)"
check "  nothing is deleted yet" "0" "$(fake_log | /usr/bin/grep -c '^image delete')"
check "  and the image asked about is kept" "dev-acp" "$(pending)"
select_image dev-node
alerts_reset
omc_run AgentVM.main.image.delete
check "an image others were built from says they keep working, and one not measured says no size" \
    "The image's folder and disk are deleted. Images built from it (dev-acp and dev-agents) keep working. This cannot be undone." \
    "$(ui_alert_message)"

section "Delete: the image asked about is the one deleted"
select_image dev-acp
omc_run AgentVM.main.image.delete
select_image dev-node
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.delete.confirmed
check "a selection changed after the question does not change what is deleted" \
    "1" "$(fake_log | /usr/bin/grep -c -x 'image delete dev-acp --json')"
check "  and dev-node is not deleted" "0" "$(fake_log | /usr/bin/grep -c 'image delete dev-node')"
check "  the other image stays selected" "dev-node" "$("$PB" "agentvm_image_$UUID" get)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.delete.confirmed
check "a second confirmation deletes nothing" "0" "$(fake_log | /usr/bin/grep -c '^image delete')"

section "Delete: agent-vm refuses"
select_image dev-acp
omc_run AgentVM.main.image.delete
printf 'image dev-acp is in use by another agent-vm process\n' > "$FAKE_AGENTVM_DIR/fail-image-delete"
alerts_reset
omc_run AgentVM.main.image.delete.confirmed
check_status "exits cleanly" 0
check "the reason is shown" "Image dev-acp was not deleted" "$(ui_alert_title)"
check "  in agent-vm's words" "image dev-acp is in use by another agent-vm process" "$(ui_alert_message)"
check "  and the image stays selected" "dev-acp" "$("$PB" "agentvm_image_$UUID" get)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-image-delete"

section "Delete: done"
omc_run AgentVM.main.image.delete
: > "$FAKE_AGENTVM_DIR/log"
store 'del(.images[] | select(.name == "dev-acp"))'
omc_run AgentVM.main.image.delete.confirmed
check "agent-vm deletes it" "1" "$(fake_log | /usr/bin/grep -c -x 'image delete dev-acp --json')"
check "  the lists are read again" "1" "$(fake_log | /usr/bin/grep -c -x 'status --json')"
check "  the selection is gone" "" "$("$PB" "agentvm_image_$UUID" get)"
check "  the placeholder is back" "1" "$(ui_visible "$MAIN_IMAGE_NONE_ID")"
check "  and its card" "" "$(ui_rows "$MAIN_IMAGES_ID" | row_named dev-acp)"

section "Delete: nothing to ask about"
store '.'
poll 1
select_image dev-acp
store 'del(.images[] | select(.name == "dev-acp"))'
alerts_reset
ui_reset
omc_run AgentVM.main.image.delete
check "an image deleted elsewhere meanwhile: no question" "" "$(ui_alert_title)"
check "  no pending delete" "" "$(pending)"
check "  and the pane shows it is gone" "1" "$(ui_visible "$MAIN_IMAGE_NONE_ID")"
store '.'
poll 1
select_image dev-acp
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
alerts_reset
ui_reset
omc_run AgentVM.main.image.delete
check "status fails: no question about rows that may be old" "" "$(ui_alert_title)"
check "  the note says why" "the store is locked" "$(ui_value "$MAIN_IMAGES_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
"$PB" "agentvm_image_delete_$UUID" set "-rf"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.image.delete.confirmed
check "a pending name agent-vm would refuse is not passed on" "0" "$(fake_log | /usr/bin/grep -c '^image delete')"
select_image ""
check "no image selected: the bar under the list has Show in Finder and Delete off" "0 0" \
    "$(enabled "$MAIN_IMAGE_SHOW_ID") $(enabled "$MAIN_IMAGE_DELETE_ID")"
alerts_reset
ui_reset
omc_run AgentVM.main.image.delete
check "no image selected: no question" "" "$(ui_alert_title)"

section "closing the window forgets a pending delete"
select_image dev-acp
omc_run AgentVM.main.image.delete
check "a question was asked"    "dev-acp" "$(pending)"
omc_run AgentVM.main.close
check "  closing forgets it"    "" "$(pending)"

# -----------------------------------------------------------------------------------------------
section "sizes, durations and dates as the window writes them"
# ui <function> [args...]  ->  a function of lib.agentvm.ui.sh, run in a subshell.
ui() {
    ( . "$APP_SCRIPTS/lib.agentvm.ui.sh" >/dev/null 2>&1
      "$@" )
}
check "a size under 1 GB, in whole MB" "296 MB"  "$(ui ui_size_text 296226816)"
check "  rounded"                      "1 MB"    "$(ui ui_size_text 500000)"
check "1 GB and over, one decimal"     "1.0 GB"  "$(ui ui_size_text 1000000000)"
check "not a number: nothing"          ""        "$(ui ui_size_text -)"
check "under a minute, in seconds"     "59 s"    "$(ui ui_duration_text 59)"
check "minutes, rounded"               "2 min"   "$(ui ui_duration_text 90)"
check "hours and minutes"              "1 h 5 min" "$(ui ui_duration_text 3900)"
check "  a minute short of the hour, rounded up to it" "1 h 0 min" "$(ui ui_duration_text 3599)"
check "  and of the next one"          "2 h 0 min" "$(ui ui_duration_text 7199)"
check "  not a number: nothing"        ""        "$(ui ui_duration_text 1.5)"
check "a day, no leading space"        "Sep 3, 2026" "$(ui ui_date_text 2026-09-03T12:00:00Z)"
check "  not agent-vm's form: nothing" ""        "$(ui ui_date_text yesterday)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
