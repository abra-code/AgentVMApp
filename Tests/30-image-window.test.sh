#!/bin/sh
# Tests/30-image-window.test.sh - an image's window: how it opens (from the main window's
# Open in Window, or a double-click on a card), one window per image, what it shows, Show in
# Finder, and Delete with its question.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, and `image info` from
# fixtures/agentvm/image-info.json, which describes dev-acp (built from dev-node; box s3 is made
# from it). Finder is fake_open.sh. Dates are read in UTC.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.image.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$IMAGE_FACTS_ID" ] && [ -n "$IMAGE_DELETE_ID" ] || {
    printf '30-image-window: no view ids imported from the window libraries\n' >&2
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
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
# The app's pid, as the engine exports it: every window entry and open request carries it.
APP_PID="${OMC_APP_PROCESS_ID:?30-image-window: OMC_APP_PROCESS_ID is not set}"
IMAGE_UUID="OMCTEST-image-window-$$"
OTHER_UUID="OMCTEST-other-image-window-$$"

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

# request  ->  the open request a Details left for the window it chained.
request() {
    "$PB" agentvm_open_request get
}

# registered <name>  ->  the pasteboard entry naming that image's window: "<app pid> <uuid>".
registered() {
    "$PB" "agentvm_window_image_$1" get
}

# open_main  ->  the main window, freshly opened, with status-variety.json.
open_main() {
    in_window "$MAIN_UUID"
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

# open_image <name> [uuid]  ->  that image's window opened the way Details opens it: the request,
# then the window's init handler, in a window of its own.
open_image() {
    "$PB" agentvm_open_request set "$APP_PID image:$1"
    in_window "${2:-$IMAGE_UUID}"
    omc_control_defaults AgentVM.image
    omc_run AgentVM.image.init
}

# shown_index <name>  ->  the 0-based index of that image's row in the rows the main window's
# table was last sent (ui_reset forgets the virtual window; the window keeps showing them).
SHOWN_ROWS="$OMCTEST_WORK/images-shown"
shown_index() {
    /usr/bin/awk -F'\t' -v name="$1" '$1 == name { print NR - 1; exit }' "$SHOWN_ROWS"
}

fake_reset
store '.'
"$PB" "agentvm_window_image_dev-acp" set ""

# -----------------------------------------------------------------------------------------------
section "Open in Window from the main window"
open_main
ui_rows "$MAIN_IMAGES_ID" > "$SHOWN_ROWS"
chains_reset
omc_table_cell "$MAIN_IMAGES_ID" 1 dev-acp
omc_trigger "$MAIN_IMAGES_ID"
omc_run AgentVM.main.image.selected
omc_trigger 432
omc_run AgentVM.main.image.details
check "Open in Window asks for an image window" "1" "$(chain_asked AgentVM.image)"
check "  for the selected image, from this run of the app" "$APP_PID image:dev-acp" "$(request)"

"$PB" agentvm_open_request set ""
index="$(shown_index dev-node)"
check "the fixture shows dev-node" "yes" "$([ -n "$index" ] && echo yes)"
omc_trigger "$MAIN_IMAGES_ID" 0 "$index"
omc_run AgentVM.main.image.details
check "a double-click on a card names the image on that card" "$APP_PID image:dev-node" "$(request)"

"$PB" agentvm_open_request set ""
chains_reset
omc_trigger "$MAIN_IMAGES_ID" 0 "99"
omc_run AgentVM.main.image.details
check "a row index past the rows opens nothing" "0" "$(chain_asked AgentVM.image)"
omc_trigger "$MAIN_IMAGES_ID" 0 "-1"
omc_run AgentVM.main.image.details
check "  nor one that is not an index" "0" "$(chain_asked AgentVM.image)"
check "  and leaves no request" "" "$(request)"

# -----------------------------------------------------------------------------------------------
section "the window: an image built from another"
ui_reset
chains_reset
open_image dev-acp
check_status "the init handler exits cleanly" 0
check "takes the request, once" "" "$(request)"
check "becomes the image's window" "$APP_PID $IMAGE_UUID" "$(registered dev-acp)"
check "the title names it" "Image dev-acp" "$(ui_title)"
check "state, macOS, where it came from, when, how long, processors and memory" \
    "ready  -  macOS 27.0 (26A428)  -  built from dev-node on Sep 26, 2026 in 2 min  -  4 CPUs, 8 GB" \
    "$(ui_value "$IMAGE_FACTS_ID")"
check "no note" "" "$(ui_value "$IMAGE_NOTE_ID")"
check "the recipe and the command line tools" \
    "Tools: ACP agents: Claude Agent ACP, Codex ACP and opencode (needs Node: build from an image with Recipes/homebrew-node); Command Line Tools for Xcode 27.0-27.0" \
    "$(ui_value "$IMAGE_TOOLS_ID")"
check "the guest daemon, current" \
    "Guest daemon 0.2.18: terminal, prompt-notices, wallpaper, time-sync, user-session, terminal-pixels. Has everything agent-vm $VERSION uses." \
    "$(ui_value "$IMAGE_GUEST_ID")"
check "Full Disk Access, and when it was checked" "Full Disk Access: granted (checked Sep 27, 2026)." "$(ui_value "$IMAGE_FDA_ID")"
check "its space, its own, and what it added" \
    "Space: 39.0 GB; 547 MB its own (what Delete frees); 1.9 GB added over dev-node" "$(ui_value "$IMAGE_SPACE_ID")"
check "its folder" "Folder: /Users/you/Library/Application Support/agent-vm/Images/dev-acp" "$(ui_value "$IMAGE_FOLDER_ID")"
check "the box made from it, with its state" "Boxes made from it: s3 (running)." "$(ui_value "$IMAGE_BOXES_ID")"
check "no image built from it" "Images built from it: none." "$(ui_value "$IMAGE_DERIVED_ID")"
check "Show in Finder enabled" "1" "$(ui_enabled "$IMAGE_SHOW_ID")"
check "Delete enabled" "1" "$(ui_enabled "$IMAGE_DELETE_ID")"
check "New Box, New Image, Update Guest and Full Disk Access stay disabled" "" \
    "$(ui_enabled "$IMAGE_NEW_BOX_ID")$(ui_enabled "$IMAGE_NEW_IMAGE_ID")$(ui_enabled "$IMAGE_UPDATE_GUEST_ID")$(ui_enabled "$IMAGE_SETUP_ID")"

section "a second Details on the same image"
in_window "$MAIN_UUID"
chains_reset
"$PB" agentvm_open_request set ""
omc_trigger "$MAIN_IMAGES_ID" 0 "$(shown_index dev-acp)"
omc_run AgentVM.main.image.details
check "opens no second window" "0" "$(chain_asked AgentVM.image)"
check "  and brings the open one to the front" "1" "$(ui_calls "${IMAGE_UUID}${TAB}omc_window${TAB}omc_select")"
check "  leaving no request" "" "$(request)"

section "an entry an earlier run of the app left (it quit without closing the window)"
"$PB" "agentvm_window_image_dev-acp" set "1 $IMAGE_UUID"
chains_reset
omc_trigger "$MAIN_IMAGES_ID" 0 "$(shown_index dev-acp)"
omc_run AgentVM.main.image.details
check "is not a window: a new one is asked for" "1" "$(chain_asked AgentVM.image)"
"$PB" "agentvm_window_image_dev-acp" set "$APP_PID $IMAGE_UUID"
"$PB" agentvm_open_request set ""

section "two windows asked for the same image before either opened"
ui_reset
open_image dev-acp "$OTHER_UUID"
check_status "the second init exits cleanly" 0
check "the first stays the image's window" "$APP_PID $IMAGE_UUID" "$(registered dev-acp)"
check "  and comes to the front" "1" "$(ui_calls "${IMAGE_UUID}${TAB}omc_window${TAB}omc_select")"
check "  and the second closes" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"

section "a window opened with no request of this run (a URL naming the command)"
ui_reset
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.image
omc_run AgentVM.image.init
check "closes" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  saying why, in case it stays" "No image was named for this window." "$(ui_value "$IMAGE_FACTS_ID")"
ui_reset
"$PB" agentvm_open_request set "1 image:dev-node"
omc_run AgentVM.image.init
check "a request another run left: closes too" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  and the request is gone" "" "$(request)"
"$PB" agentvm_open_request set "$APP_PID box:s3"
omc_run AgentVM.image.init
check "a request for a box is not an image's" "" "$("$PB" "agentvm_item_$OTHER_UUID" get)"
ui_reset
"$PB" agentvm_open_request set "$APP_PID image:-rf"
omc_run AgentVM.image.init
check "  nor one whose name agent-vm would refuse" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
ui_reset
"$PB" agentvm_open_request set " image:dev-node"
( OMC_APP_PROCESS_ID=""; export OMC_APP_PROCESS_ID; omc_run AgentVM.image.init )
check "  nor any request, to a handler without the app's pid" "1" "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
in_window "$IMAGE_UUID"

# -----------------------------------------------------------------------------------------------
section "an image built from a restore file, with images and a box made from it"
# No image-info fixture for dev: image info says it has none, and the status row serves.
ui_reset
in_window "$OTHER_UUID"
open_image dev "$OTHER_UUID"
check "made from a restore file, no size from image info" \
    "ready  -  macOS 27.0 (26A428)  -  made from a restore file on Sep 23, 2026" "$(ui_value "$IMAGE_FACTS_ID")"
check "the note says why it was not measured" \
    "agent-vm could not measure it: no image dev; \`agent-vm image list\` shows the existing ones" "$(ui_value "$IMAGE_NOTE_ID")"
check "  and the space line says so" "Space: not measured." "$(ui_value "$IMAGE_SPACE_ID")"
check "no recipe, no tools recorded" "Tools: macOS only" "$(ui_value "$IMAGE_TOOLS_ID")"
check "the images built from it" "Images built from it: dev-node and dev-xcode." "$(ui_value "$IMAGE_DERIVED_ID")"
check "the box made from it" "Boxes made from it: try1 (unresponsive)." "$(ui_value "$IMAGE_BOXES_ID")"
check "a guest update it needs" "Guest daemon 0.2.18. Needs a guest update for agent-vm $VERSION." "$(ui_value "$IMAGE_GUEST_ID")"
omc_run AgentVM.image.close
in_window "$IMAGE_UUID"

section "a guest update and Full Disk Access, from image info"
/usr/bin/jq '.needs = [{kind: "guest-update", missing: ["terminal-pixels", "wallpaper"]}, {kind: "full-disk-access", reason: "not-granted"}]
    | .fullDiskAccess.granted = false' "$FIXTURES_AGENTVM/image-info.json" > "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"
omc_run AgentVM.image.activated
check "what the update adds" \
    "Guest daemon 0.2.18: terminal, prompt-notices, wallpaper, time-sync, user-session, terminal-pixels. Needs a guest update for agent-vm $VERSION, which adds terminal-pixels, wallpaper." \
    "$(ui_value "$IMAGE_GUEST_ID")"
check "what no Full Disk Access means" \
    "Full Disk Access: not granted, so programs in its boxes cannot open Desktop, Documents or Downloads (checked Sep 27, 2026)." \
    "$(ui_value "$IMAGE_FDA_ID")"
/usr/bin/jq 'del(.fullDiskAccess)' "$FIXTURES_AGENTVM/image-info.json" > "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"
omc_run AgentVM.image.activated
check "never checked" "Full Disk Access: not checked yet." "$(ui_value "$IMAGE_FDA_ID")"

section "a failed build"
/usr/bin/jq '.state = "failed" | .failure = "the build was canceled"' "$FIXTURES_AGENTVM/image-info.json" \
    > "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"
omc_run AgentVM.image.activated
check "says why" "The build failed: the build was canceled." "$(ui_value "$IMAGE_NOTE_ID")"
check "  and the state says failed" "failed" "$(ui_value "$IMAGE_FACTS_ID" | /usr/bin/cut -d' ' -f1)"
/usr/bin/jq '.state = "failed" | .failure = "the disk is full." | del(.memoryBytes)' "$FIXTURES_AGENTVM/image-info.json" \
    > "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"
omc_run AgentVM.image.activated
check "  a reason that ends with a period gets no second one" "The build failed: the disk is full." "$(ui_value "$IMAGE_NOTE_ID")"
check "  no memory recorded: the processors alone" "yes" "$(ui_value "$IMAGE_FACTS_ID" | /usr/bin/grep -q '  -  4 CPUs$' && echo yes)"
/bin/rm -f "$FAKE_AGENTVM_DIR/image-info-dev-acp.json"

# -----------------------------------------------------------------------------------------------
section "Show in Finder"
: > "$FAKE_OPEN_LOG"
omc_run AgentVM.image.show
check "a folder that is not on this Mac: nothing opens" "" "$(/bin/cat "$FAKE_OPEN_LOG")"
folder="$OMCTEST_WORK/store/Images/dev-acp"
/bin/mkdir -p "$folder"
store '(.images[] | select(.name == "dev-acp")).path = "'"$folder"'"'
omc_run AgentVM.image.activated
omc_run AgentVM.image.show
check "the image's folder, selected in Finder" "-R $folder" "$(/bin/cat "$FAKE_OPEN_LOG")"
store '.'

# -----------------------------------------------------------------------------------------------
section "Delete: the question"
alerts_reset
omc_run AgentVM.image.delete
check_status "exits cleanly" 0
check "asks" "Delete image dev-acp?" "$(ui_alert_title)"
check "  what it frees, the box made from it, and that it is final" \
    "The image's folder and disk are deleted, which frees about 547 MB. Boxes made from it (s3) keep working, but cannot be recreated. This cannot be undone." \
    "$(ui_alert_message)"
check "  Delete confirms" "AgentVM.image.delete.confirmed" "$(ui_alert_action Delete)"
check "  Cancel does nothing" "" "$(ui_alert_action Cancel)"
check "  and nothing is deleted yet" "0" "$(fake_log | /usr/bin/grep -c '^image delete')"
in_window "$OTHER_UUID"
ui_reset
open_image dev-node "$OTHER_UUID"
omc_run AgentVM.image.delete
check "an image others were built from says they keep working" \
    "The image's folder and disk are deleted. Images built from it (dev-acp and dev-agents) keep working. This cannot be undone." \
    "$(ui_alert_message)"
omc_run AgentVM.image.close
in_window "$IMAGE_UUID"

section "Delete: agent-vm refuses"
printf 'image dev-acp is in use by another agent-vm process\n' > "$FAKE_AGENTVM_DIR/fail-image-delete"
ui_reset
omc_run AgentVM.image.delete.confirmed
check_status "exits cleanly" 0
check "the reason is shown" "Image dev-acp was not deleted" "$(ui_alert_title)"
check "  in agent-vm's words" "image dev-acp is in use by another agent-vm process" "$(ui_alert_message)"
check "  the window stays" "0" "$(ui_calls "omc_terminate_cancel")"
check "  and is still the image's window" "$APP_PID $IMAGE_UUID" "$(registered dev-acp)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-image-delete"

section "Delete: done"
ui_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.image.delete.confirmed
check "agent-vm deletes it" "1" "$(fake_log | /usr/bin/grep -c -x 'image delete dev-acp --json')"
check "the window closes" "1" "$(ui_calls "${IMAGE_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  and is no longer the image's window" "" "$(registered dev-acp)"

section "the image deleted elsewhere while its window is open"
open_image dev-acp
store 'del(.images[] | select(.name == "dev-acp"))'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.image.activated
check "says so" "Image dev-acp no longer exists." "$(ui_value "$IMAGE_FACTS_ID")"
check "  and shows nothing of it" "" "$(ui_value "$IMAGE_SPACE_ID")$(ui_value "$IMAGE_BOXES_ID")$(ui_value "$IMAGE_FOLDER_ID")"
check "Show and Delete disabled" "00" "$(ui_enabled "$IMAGE_SHOW_ID")$(ui_enabled "$IMAGE_DELETE_ID")"
check "nothing to measure: no image info" "0" "$(fake_log | /usr/bin/grep -c '^image info')"
alerts_reset
ui_reset
omc_run AgentVM.image.delete
check "Delete asks nothing" "" "$(ui_alert_title)"
store '.'

section "status fails while the window is open"
omc_run AgentVM.image.activated
check "first read well: the image is shown" "Folder: /Users/you/Library/Application Support/agent-vm/Images/dev-acp" "$(ui_value "$IMAGE_FOLDER_ID")"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.image.activated
check_status "exits cleanly" 0
check "the note says status failed, not the measuring" "agent-vm status failed: the store is locked" "$(ui_value "$IMAGE_NOTE_ID")"
alerts_reset
ui_reset
omc_run AgentVM.image.delete
check "Delete asks nothing about rows that may be old" "" "$(ui_alert_title)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

section "agent-vm gone while the window is open"
printf 'no such file\n' > "$FAKE_AGENTVM_DIR/stderr"
printf '127\n' > "$FAKE_AGENTVM_DIR/exit"
omc_run AgentVM.image.activated
check "says agent-vm cannot be used" "agent-vm cannot be used" "$(ui_value "$IMAGE_FACTS_ID")"
check "  with why" "yes" "$([ -n "$(ui_value "$IMAGE_NOTE_ID")" ] && echo yes)"
check "  and Delete is disabled" "0" "$(ui_enabled "$IMAGE_DELETE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/stderr" "$FAKE_AGENTVM_DIR/exit"

# -----------------------------------------------------------------------------------------------
section "closing"
open_image dev-acp
cache="$TMPDIR/AgentVM/$IMAGE_UUID"
check "the window has a cache" "yes" "$([ -d "$cache" ] && echo yes)"
omc_run AgentVM.image.close
check "the image has no window" "" "$(registered dev-acp)"
check "  the window forgets its image" "" "$("$PB" "agentvm_item_$IMAGE_UUID" get)"
check "  and its cache is gone" "no" "$([ -d "$cache" ] && echo yes || echo no)"
"$PB" "agentvm_window_image_dev-acp" set "$APP_PID $OTHER_UUID"
"$PB" "agentvm_item_$IMAGE_UUID" set "dev-acp"
omc_run AgentVM.image.close
check "a window that was not the image's leaves the entry alone" "$APP_PID $OTHER_UUID" "$(registered dev-acp)"

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

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"

omctest_end
