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

# -----------------------------------------------------------------------------------------------
section "a Linux image"
# The store with both kinds. `image info` is answered for deb-agents, the image the Linux capture
# measured; any other Linux image is not found until a test leaves its answer.
visible() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-mixed.json" "$FAKE_AGENTVM_DIR/status.json"
/bin/cp "$FIXTURES_AGENTVM/image-info-linux.json" "$FAKE_AGENTVM_DIR/image-info-deb-agents.json"
open_window
select_image deb-agents
check_status "the handler exits cleanly" 0
# The capture is of an image built before agent-vm kept a kernel's page size: 4 KiB pages.
check "its system, in agent-vm's words, and its kernel's pages" \
    "Debian GNU/Linux 13 (trixie), kernel with 4 KiB pages" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
/usr/bin/jq '(.images[] | select(.name == "deb-agents")) |= (.linux.pageSize = 16384 | .linux.kernel = "6.12.111+deb13-arm64-16k" | .updatedAt = "2026-10-09T10:00:00Z")' \
    "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "  one built with the Mac's page size, before the day it was updated" \
    "Debian GNU/Linux 13 (trixie), kernel with 16 KiB pages, updated Oct 9, 2026" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
/bin/cp "$FIXTURES_AGENTVM/status-mixed.json" "$FAKE_AGENTVM_DIR/status.json"
poll 1
check "what it was built from"  "deb" "$(ui_value "$MAIN_IMAGE_BASE_ID")"
check "its tools: its recipes and the compiler" \
    "Node and npm from nodejs.org, for Linux images; Claude Code, Codex and opencode (needs Node: put Recipes/node, or Recipes/linux-node in a Linux image, before it); build-essential 12.12" \
    "$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "the guest daemon and its three features" "0.7.9: terminal, time-sync, terminal-pixels" "$(ui_value "$MAIN_IMAGE_GUEST_ID")"
check "Full Disk Access is not needed, and the row says so" "not needed: a Linux image has no such permission" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
check "  with no Set Up..., shown or on" "0 0" "$(ui_visible "$MAIN_IMAGE_ACCESS_ID") $(enabled "$MAIN_IMAGE_ACCESS_ID")"
check "View is shown and on: a recipe gave this one a desktop" "1 1" "$(visible "$MAIN_IMAGE_VIEW_ID") $(enabled "$MAIN_IMAGE_VIEW_ID")"
check "Update, New Image and New Box are on" "1 1 1" \
    "$(enabled "$MAIN_IMAGE_UPDATE_ID") $(enabled "$MAIN_IMAGE_DERIVE_ID") $(enabled "$MAIN_IMAGE_BOX_ID")"
check "processors and memory"   "4 CPUs, 4 GB" "$(ui_value "$MAIN_IMAGE_HARDWARE_ID")"
check "the space: all, its own, and what it added over its base" \
    "3.6 GB; 1.7 GB its own (what Delete frees); 1.7 GB added over deb" "$(ui_value "$MAIN_IMAGE_SPACE_ID")"
check "the day it was made, and how long the build took" "Oct 7, 2026, built in 24 s" "$(ui_value "$MAIN_IMAGE_CREATED_ID")"
select_image deb
check "one built from no image, before agent-vm measured it: a cloud image, and nothing known of its tools" \
    "a cloud image|the system only" "$(ui_value "$MAIN_IMAGE_BASE_ID")|$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
check "  Full Disk Access is not needed whether it was measured or not" \
    "not needed: a Linux image has no such permission" "$(ui_value "$MAIN_IMAGE_FDA_ID")"
check "  the box made from it, and the image built from it" "lb (stopped)|deb-agents" \
    "$(ui_value "$MAIN_IMAGE_BOXES_ID")|$(ui_value "$MAIN_IMAGE_DERIVED_ID")"
check "  no View: it has no desktop, so no screen" "0 0" "$(ui_visible "$MAIN_IMAGE_VIEW_ID") $(enabled "$MAIN_IMAGE_VIEW_ID")"
/usr/bin/jq '.name = "deb" | del(.derivedFrom) | del(.recipe) | del(.recipes) | del(.addedOverBase) | .base.build = "20261001-2618"' \
    "$FIXTURES_AGENTVM/image-info-linux.json" > "$FAKE_AGENTVM_DIR/image-info-deb.json"
select_image deb-agents
select_image deb
check "  once measured: the cloud image's file and its build, and the compiler as its tools" \
    "the cloud image debian-13-genericcloud-arm64.tar.xz, build 20261001-2618|build-essential 12.12" \
    "$(ui_value "$MAIN_IMAGE_BASE_ID")|$(ui_value "$MAIN_IMAGE_TOOLS_ID")"
/usr/bin/jq '.name = "deb" | del(.derivedFrom) | del(.base.build)' \
    "$FIXTURES_AGENTVM/image-info-linux.json" > "$FAKE_AGENTVM_DIR/image-info-deb.json"
select_image deb-agents
select_image deb
check "  a cloud image whose distribution names no build: its file alone" \
    "the cloud image debian-13-genericcloud-arm64.tar.xz" "$(ui_value "$MAIN_IMAGE_BASE_ID")"
# The handler behind Set Up..., run as a URL naming it would run it: the button is not shown.
chains_reset
omc_run AgentVM.main.image.access
check "Set Up..., however it came to run, opens no guide for a Linux image" "0" "$(chain_asked AgentVM.access)"
select_image dev-acp
check "a macOS image selected after it has Set Up... and View again, shown and on" "1 1 1 1" \
    "$(visible "$MAIN_IMAGE_ACCESS_ID") $(enabled "$MAIN_IMAGE_ACCESS_ID") $(visible "$MAIN_IMAGE_VIEW_ID") $(enabled "$MAIN_IMAGE_VIEW_ID")"
check "  and its system, with the build, and no word of a kernel" "macOS 27.0 (26A428)" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
omc_run AgentVM.main.image.access
check "  and its guide is asked for" "1" "$(chain_asked AgentVM.access)"
"$PB" agentvm_open_request_access set ""
/usr/bin/jq '(.images[] | select(.name == "ub")).state = "installing" | (.images[] | select(.name == "ub-agents")).state = "installed"
    | (.images[] | select(.name == "dev")).state = "installing"' "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
select_image ub
check "a Linux image being built: what is being installed is the system" "Building: installing the system" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
check "  and nothing is said of its kernel, which the build may still change" "Ubuntu 26.04.1 LTS" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
select_image ub-agents
check "  and then is installed" "Building: the system is installed" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
select_image dev
check "  a macOS image: macOS" "Building: installing macOS" "$(ui_value "$MAIN_IMAGE_STATE_ID")"
/usr/bin/jq '(.images[] | select(.name == "dev")) |= (del(.macOSVersion) | del(.macOSBuild) | .system = "macOS ? (?)")' \
    "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "a macOS image whose version agent-vm does not know: nothing known, not agent-vm's question marks" "-, updated Oct 1, 2026" \
    "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
/usr/bin/jq '(.images[] | select(.name == "dev")) |= (del(.macOSBuild) | .system = "macOS 27.0.1 (?)")' \
    "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "  one whose build it does not know: its version alone" "macOS 27.0.1, updated Oct 1, 2026" "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"
/usr/bin/jq '(.images[] | select(.name == "dev")) |= del(.system)' \
    "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
omc_run AgentVM.main.activated
check "  a record with its version and build is shown by them, whatever its words" "macOS 27.0.1 (26A434), updated Oct 1, 2026" \
    "$(ui_value "$MAIN_IMAGE_SYSTEM_ID")"

section "the Logs row: the log of an image's last build or update, and a Linux image's console"
# The row points to a job's log in the store and to console.log in a Linux image's folder, and
# nothing is read from either. The folders are made here: the fixtures' are not on this Mac.
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
JOB_FOLDERS="$OMCTEST_WORK/logs store/Jobs"
# job_id <n>  ->  the id of the test's nth job: an id begins with the time, so a greater n is a
# newer job.
job_id() {
    printf '20260930-12000%s-0000f%s\n' "$1" "$1"
}
# job_record <n> <image> <create|update|...> <state>  ->  that job as agent-vm lists it, with its
# folder under $JOB_FOLDERS.
job_record() {
    /usr/bin/jq -n --arg id "$(job_id "$1")" --arg image "$2" --arg what "$3" --arg state "$4" --arg folders "$JOB_FOLDERS" '
        {id: $id, command: ["image", $what, $image, "--json"], targets: ["image:\($image)"], state: $state, path: "\($folders)/\($id)",
         createdAt: "2026-09-30T12:00:00Z"}
        + (if $state == "queued" then {} else {startedAt: "2026-09-30T12:00:00Z"} end)
        + (if $state == "running" or $state == "queued" then {} else {endedAt: "2026-09-30T12:05:00Z"} end)'
}
# jobs <record...>  ->  the jobs agent-vm lists, and carries in status.
jobs() {
    printf '%s\n' "$@" | /usr/bin/jq -s '.' > "$JOBS"
}
# job_log <n>  ->  the log file of that job, on this Mac.
job_log() {
    /bin/mkdir -p "$JOB_FOLDERS/$(job_id "$1")"
    : > "$JOB_FOLDERS/$(job_id "$1")/log"
}
# image_logs  ->  the row: its text, whether Show Build Log is on, and whether Show Console Log
# is shown and on.
image_logs() {
    printf '%s|%s|%s|%s\n' "$(ui_value "$MAIN_IMAGE_LOGS_ID")" "$(enabled "$MAIN_IMAGE_LOGS_BUILD_ID")" \
        "$(ui_visible "$MAIN_IMAGE_LOGS_CONSOLE_ID")" "$(enabled "$MAIN_IMAGE_LOGS_CONSOLE_ID")"
}
opened() {
    /bin/cat "$FAKE_OPEN_LOG"
}
listed() {
    fake_log | /usr/bin/grep -c '^job list --json$'
}
NONE="No build log: agent-vm keeps one for a week"
fake_reset
deb_folder="$OMCTEST_WORK/logs store/Images/deb"
/bin/mkdir -p "$deb_folder" "$JOB_FOLDERS"
/usr/bin/jq --arg deb "$deb_folder" '(.images[] | select(.name == "deb")).path = $deb' "$FIXTURES_AGENTVM/status-mixed.json" > "$FAKE_AGENTVM_DIR/status.json"
open_window
: > "$FAKE_AGENTVM_DIR/log"
select_image dev
check "no build or update of the image is listed: the row says how long a log is kept, Show Build Log is off, and a macOS image has no Show Console Log" \
    "$NONE|0|0|0" "$(image_logs)"
check "selecting an image asks agent-vm for the jobs it lists" "1" "$(listed)"
poll 2
check "  the poll loop does not ask again" "1" "$(listed)"
omc_run AgentVM.main.activated
check "  activation does"            "2" "$(listed)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.build
omc_run AgentVM.main.image.logs.console
check "  the handlers, run anyway, open nothing" "" "$(opened)"
jobs "$(job_record 1 dev create done)"
select_image dev
check "a build is listed, and its log is not on this Mac: as if there were none" "$NONE|0" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
job_log 1
select_image dev
check "its log is on this Mac: the row says when the build ended, and Show Build Log is on" "Last build: Sep 30, 2026|1|0|0" "$(image_logs)"
omc_run AgentVM.main.image.logs.build
check "  Show Build Log selects the job's log in Finder" "-R $JOB_FOLDERS/$(job_id 1)/log" "$(opened)"
jobs "$(job_record 1 dev create done)" "$(job_record 2 dev update failed)"
job_log 2
select_image dev
check "the newest job of the image is the one told: an update that failed" "Last update failed: Sep 30, 2026|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.build
check "  and the one whose log is shown" "-R $JOB_FOLDERS/$(job_id 2)/log" "$(opened)"
jobs "$(job_record 2 dev update failed)" "$(job_record 3 dev update-guest canceled)"
job_log 3
select_image dev
check "an update that was stopped"   "Last update stopped: Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_LOGS_ID")"
jobs "$(job_record 3 dev update-guest canceled)" "$(job_record 4 dev rebuild lost)"
job_log 4
select_image dev
check "a build whose runner was lost" "Last build did not finish: Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_LOGS_ID")"
jobs "$(job_record 4 dev rebuild lost)" "$(job_record 5 dev update running)" "$(job_record 6 dev update queued)"
job_log 5
job_log 6
select_image dev
check "an update that runs, with another waiting behind it: the one that runs is told, since one that waits has written nothing" \
    "Update running now|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.build
check "  and its log is the one shown" "-R $JOB_FOLDERS/$(job_id 5)/log" "$(opened)"
# The image stays selected while the update ends: status carries the job as ended, and the
# reading made when the image was selected still has it running.
jobs "$(job_record 4 dev rebuild lost)" "$(job_record 5 dev update done)"
poll 1
check "it ends while the image stays selected: the row follows status, with no new selection" "Last update: Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_LOGS_ID")"
jobs "$(job_record 1 dev create done)" "$(job_record 7 dev setup done)" "$(job_record 8 dev view done)" "$(job_record 9 dev-acp create failed)"
job_log 7
job_log 8
job_log 9
# Status is read, so that both readings carry the setup and the view: neither is a build.
poll 1
select_image dev
check "a setup, a view and another image's build, all newer: the image's own build is told" "Last build: Sep 30, 2026|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.build
check "  and its log is the one shown, not the setup's or the view's" "-R $JOB_FOLDERS/$(job_id 1)/log" "$(opened)"
select_image dev-acp
check "  and the other image has its own" "Last build failed: Sep 30, 2026" "$(ui_value "$MAIN_IMAGE_LOGS_ID")"
# What status carries is the last hour's jobs, and the pane's reading the week's. The fake gives
# both the same jobs, so the two are told apart by when each was read.
jobs "$(job_record 1 dev create done)"
select_image dev
/bin/rm -f "$JOBS"
poll 1
check "a job status no longer carries is told from the jobs read when the image was selected" "Last build: Sep 30, 2026|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
jobs "$(job_record 2 dev update failed)"
poll 1
check "a job made after that reading is told from status, with no new selection" "Last update failed: Sep 30, 2026|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
/bin/rm -f "$JOBS"
printf 'no jobs today\n' > "$FAKE_AGENTVM_DIR/fail-job"
# Status is read again, and carries no job now; the list of jobs cannot be read.
poll 1
select_image dev
check "agent-vm cannot list the jobs: what was read before stays" "Last build: Sep 30, 2026|1" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job"
select_image dev
check "  and the next reading puts it right" "$NONE|0" "$(image_logs | /usr/bin/cut -d'|' -f1-2)"
select_image deb
check "a Linux image: Show Console Log is shown, and off while there is no console log" "$NONE|0|1|0" "$(image_logs)"
: > "$deb_folder/console.log"
poll 1
check "  with a console log in its folder: on" "$NONE|0|1|1" "$(image_logs)"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.console
check "  Show Console Log selects it in Finder" "-R $deb_folder/console.log" "$(opened)"
select_image ub
check "a Linux image whose folder is not on this Mac: shown, and off" "1|0" "$(visible "$MAIN_IMAGE_LOGS_CONSOLE_ID")|$(enabled "$MAIN_IMAGE_LOGS_CONSOLE_ID")"
select_image dev
check "a macOS image selected after it: Show Console Log is not shown" "0" "$(visible "$MAIN_IMAGE_LOGS_CONSOLE_ID")"
select_image ""
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.main.image.logs.build
omc_run AgentVM.main.image.logs.console
check "no image selected: nothing opens" "" "$(opened)"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
