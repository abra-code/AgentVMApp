#!/bin/sh
# Tests/21-maintenance.test.sh - what needs doing to a box or an image: the "Needs maintenance"
# mark on its card, the lines its detail pane lists, and the state line of a running box nobody
# uses.
#
# Text only for now; each thing gets the button that does it later. Driven through the init
# handler and a selection, as the window meets them, with the fake agent-vm answering status from
# fixtures/agentvm/status-variety.json or from a jq edit of it.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_BOX_MAINTENANCE_ID" ] && [ -n "$MAIN_IMAGE_MAINTENANCE_ID" ] || {
    printf '21-maintenance: no view ids imported from lib.agentvm.main.sh\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP FAKE_SLEEP_LOG
VERSION="$(lib_value AGENTVM_MIN_VERSION)"
# 2026-09-29T14:02:10Z, when box s3 of status-variety.json started, as seconds since 1970.
S3_STARTED=1790690530
MARK="Needs maintenance${TAB}exclamationmark.triangle.fill"

# open_with <jq edit of status-variety.json> [now]  ->  the window opened on that status.
open_with() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
    ui_reset
    omc_control_defaults AgentVM
    ( AGENTVM_APP_NOW="${2:-}"; export AGENTVM_APP_NOW; omc_run AgentVM.main.init )
}

# box_mark <name> / image_mark <name>  ->  the card's mark and its symbol, tab-separated (two
# empty fields when there is none).
box_mark() {
    ui_rows "$MAIN_BOXES_ID" | row_named "$1" | col 4-5
}
image_mark() {
    ui_rows "$MAIN_IMAGES_ID" | row_named "$1" | col 4-5
}

# box_lines <name> [now] / image_lines <name>  ->  the detail pane's maintenance text for that
# selection, its lines joined with "|".
box_lines() {
    omc_table_cell "$MAIN_BOXES_ID" 1 "$1"
    omc_trigger "$MAIN_BOXES_ID"
    ( AGENTVM_APP_NOW="${2:-}"; export AGENTVM_APP_NOW; omc_run AgentVM.main.box.selected )
    ui_value "$MAIN_BOX_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -
}
image_lines() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
    ui_value "$MAIN_IMAGE_MAINTENANCE_ID" | /usr/bin/paste -sd '|' -
}

# box_state <name> <now>  ->  the detail pane's state line for that box.
box_state() {
    box_lines "$1" "$2" > /dev/null
    ui_value "$MAIN_BOX_STATE_ID"
}

# Nothing needs doing: no needs, no failed image, every supervisor current, s3 owned.
QUIET='.images |= map(.needs = [] | if .state == "failed" then .state = "ready" | del(.failure) else . end)'
QUIET="$QUIET"' | .boxes |= map(.needs = [])'
QUIET="$QUIET"' | (.boxes[] | select(.running)).supervisorVersion = "'"$VERSION"'"'

fake_reset

section "the fixture: images that need a guest update or Full Disk Access"
open_with '.'
check "the Status face shows them" "1" "$([ "$(ui_visible "$MAIN_STATUS_ID")" = "1" ] && echo 1 || echo 0)"
check "a guest update: marked" "$MARK" "$(image_mark dev)"
check "Full Disk Access: marked" "$MARK" "$(image_mark dev-xcode)"
check "nothing to do: no mark" "$TAB" "$(image_mark dev-acp)"
check "a failed image is not maintenance" "$TAB" "$(image_mark latest-test)"
check "no box needs anything" "$TAB$TAB$TAB" "$(box_mark s3)$(box_mark try1)$(box_mark cadabra-spike)"
check "the guest update, for this agent-vm" \
    "Needs maintenance|Needs a guest update for agent-vm $VERSION." "$(image_lines dev)"
check "Full Disk Access, and what is lost without it" \
    "Needs maintenance|Needs Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads." \
    "$(image_lines dev-xcode)"
check "both, the guest update first" \
    "Needs maintenance|Needs a guest update for agent-vm $VERSION.|Needs Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads." \
    "$(image_lines dev-node)"
check "nothing: no text at all" "" "$(image_lines dev-acp)"

section "a failed image that also reports needs"
open_with '(.images[] | select(.name == "latest-test")).needs = [{kind: "full-disk-access", reason: "not-granted"}]'
check "is still not marked: its card says Failed" "$TAB" "$(image_mark latest-test)"
check "  and its pane lists nothing" "" "$(image_lines latest-test)"

section "nothing needs doing"
open_with "$QUIET"
check "no card is marked" "" "$( { ui_rows "$MAIN_IMAGES_ID"; ui_rows "$MAIN_BOXES_ID"; } | col 4-5 | /usr/bin/tr -d "$TAB\n")"

section "a box made before its image changed"
RECREATE='[{kind: "recreate", reason: "image-updated", macOSBuild: "26A434"}]'
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3" or .box.name == "cadabra-spike")).needs = '"$RECREATE"
check "marked" "$MARK" "$(box_mark s3)"
check "which image, and what recreating costs" \
    "Needs maintenance|Made before image dev-acp was updated. Recreate it to get the update; what was changed inside it is lost." \
    "$(box_lines s3)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate", reason: "guest-update", guestVersion: "0.5.7"}]'
check "the image's guest daemon was replaced" \
    "Needs maintenance|Made before image dev-acp had its guest daemon replaced. Recreate it to get the new one; what was changed inside it is lost." \
    "$(box_lines s3)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate", reason: "image-rebuilt", macOSBuild: "26A434"}]'
check "the image was built again" \
    "Needs maintenance|Made before image dev-acp was built again. Recreate it to get the new image; what was changed inside it is lost." \
    "$(box_lines s3)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate"}]'
check "a reason this app does not know is not guessed at" \
    "Needs maintenance|Made before image dev-acp changed. Recreate it to get the image as it is now; what was changed inside it is lost." \
    "$(box_lines s3)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3" or .box.name == "cadabra-spike")).needs = '"$RECREATE"
check "a disposable box is not marked: it is deleted when it stops" "$TAB" "$(box_mark cadabra-spike)"
check "  and lists nothing" "" "$(box_lines cadabra-spike)"

section "a running box whose supervisor is another agent-vm version"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")).supervisorVersion = "0.3.12"'
check "marked" "$MARK" "$(box_mark s3)"
check "says which, and how to move it" \
    "Needs maintenance|Runs agent-vm 0.3.12. Stop it and start it again to move it to $VERSION." "$(box_lines s3)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "try1")).supervisorVersion = "0.3.12"'
check "an unresponsive box too: its supervisor still runs" "$MARK" "$(box_mark try1)"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= (.state = "stopped" | .supervisorVersion = "0.3.12")'
check "a stopped box is not marked: it has no supervisor" "$TAB" "$(box_mark s3)"

section "both at once, the recreate first"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= (.needs = '"$RECREATE"' | .supervisorVersion = "0.3.12")'
check "two lines under the heading" "3" "$(box_lines s3 | /usr/bin/tr '|' '\n' | /usr/bin/awk 'END { print NR }')"
check "  the recreate first" "Made before" "$(box_lines s3 | /usr/bin/cut -d'|' -f2 | /usr/bin/cut -c1-11)"

section "a running box nobody uses"
IDLE="$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= (del(.ownerPid) | .activeExecs = 0)'
open_with "$IDLE"
check "no owner, no program, three hours: the state line says so" \
    "Running for 3 h 2 min. No program runs in it now." "$(box_state s3 $((S3_STARTED + 3 * 3600 + 100)))"
check "  and it is not maintenance" "$TAB" "$(box_mark s3)"
check "exactly two hours is enough" \
    "Running for 2 h 0 min. No program runs in it now." "$(box_state s3 $((S3_STARTED + 2 * 3600)))"
check "a minute less is not" "Running for 1 h 59 min" "$(box_state s3 $((S3_STARTED + 2 * 3600 - 60)))"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")).activeExecs = 0'
check "with an owner (a Cadabra chat) it is not idle" "Running for 5 h 0 min" "$(box_state s3 $((S3_STARTED + 5 * 3600)))"
open_with "$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= del(.ownerPid)'
check "with a program running it is not idle" "Running for 5 h 0 min" "$(box_state s3 $((S3_STARTED + 5 * 3600)))"
open_with "$IDLE"' | (.boxes[] | select(.box.name == "s3")).startedAt = "yesterday"'
check "a start time that is not a time is not guessed at" "Running" "$(box_state s3 $((S3_STARTED + 5 * 3600)))"
open_with "$IDLE"
check "a clock behind the start time is not either" "Running" "$(box_state s3 $((S3_STARTED - 60)))"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"

omctest_end
