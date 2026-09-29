#!/bin/sh
# Tests/21-attention.test.sh - the main window's attention lines: what needs doing, most
# important first, at most three, from what agent-vm's status says.
#
# The lines are text only for now; each gets its one button with the action it names. Driven
# through the poll loop's pass, as the window meets them, with the fake agent-vm answering
# status from fixtures/agentvm/status-variety.json or from a jq edit of it.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_ATTENTION_ID" ] && [ -n "$MAIN_STATUS_ID" ] || {
    printf '21-attention: no view ids imported from lib.agentvm.main.sh\n' >&2
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

# attention_for <jq edit of status-variety.json> [now]  ->  the attention lines the window shows
# for that status, one per line.
attention_for() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
    ui_reset
    omc_control_defaults AgentVM
    ( AGENTVM_APP_NOW="${2:-}"; export AGENTVM_APP_NOW; omc_run AgentVM.main.init )
    ui_value "$MAIN_ATTENTION_ID"
}

# Nothing needs attention: no needs, no failed image, every supervisor current, s3 owned.
QUIET='.images |= map(.needs = [] | if .state == "failed" then .state = "ready" | del(.failure) else . end)'
QUIET="$QUIET"' | (.boxes[] | select(.running)).supervisorVersion = "'"$VERSION"'"'

fake_reset

section "the fixture: three kinds at once, most important first"
lines="$(attention_for '.')"
check "the Status face shows them" "1" "$([ "$(ui_visible "$MAIN_STATUS_ID")" = "1" ] && echo 1 || echo 0)"
check "at most three lines" "3" "$(printf '%s\n' "$lines" | /usr/bin/awk 'END { print NR }')"
check "guest updates first, with the names" \
    "! 2 images need a guest update for agent-vm $VERSION: dev and dev-node." \
    "$(printf '%s\n' "$lines" | /usr/bin/sed -n 1p)"
check "then Full Disk Access" \
    "! 3 images need Full Disk Access, or programs in their boxes cannot open Desktop, Documents or Downloads: dev-node, dev-xcode and dev-xcode-ios." \
    "$(printf '%s\n' "$lines" | /usr/bin/sed -n 2p)"
check "then a failed image, with why" \
    "! Image latest-test failed: the build was canceled." \
    "$(printf '%s\n' "$lines" | /usr/bin/sed -n 3p)"

section "four kinds at once: the least important is left out"
lines="$(attention_for '(.boxes[] | select(.box.name == "s3")).supervisorVersion = "0.3.12"')"
check "still three lines" "3" "$(printf '%s\n' "$lines" | /usr/bin/awk 'END { print NR }')"
check "the box's line is the one cut" "0" "$(printf '%s\n' "$lines" | /usr/bin/grep -c 'Box s3')"
check "  though it needs attention on its own" "1" \
    "$(attention_for "$QUIET"' | (.boxes[] | select(.box.name == "s3")).supervisorVersion = "0.3.12"' | /usr/bin/grep -c 'Box s3')"

section "nothing needs attention"
check "no lines at all" "" "$(attention_for "$QUIET")"

section "one image needing each"
check "a guest update" "! Image dev needs a guest update for agent-vm $VERSION." \
    "$(attention_for "$QUIET"' | (.images[] | select(.name == "dev")).needs = [{kind: "guest-update"}]')"
check "Full Disk Access" "! Image dev needs Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads." \
    "$(attention_for "$QUIET"' | (.images[] | select(.name == "dev")).needs = [{kind: "full-disk-access", reason: "not-granted"}]')"
check "a failed image agent-vm gave no reason for" "! Image dev failed." \
    "$(attention_for "$QUIET"' | (.images[] | select(.name == "dev")).state = "failed"')"

section "a box whose supervisor is another agent-vm version"
check "says which, and how to move it" \
    "! Box s3 runs agent-vm 0.3.12; stop it and start it again to move it to $VERSION." \
    "$(attention_for "$QUIET"' | (.boxes[] | select(.box.name == "s3")).supervisorVersion = "0.3.12"')"
check "a stopped box is not named: it has no supervisor" "" \
    "$(attention_for "$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= (.state = "stopped" | .supervisorVersion = "0.3.12")')"

section "a running box nobody uses"
IDLE="$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= (del(.ownerPid) | .activeExecs = 0)'
check "no owner, no program, three hours: named" \
    "! Box s3 has run 3 hours, and no program runs in it now." \
    "$(attention_for "$IDLE" $((S3_STARTED + 3 * 3600 + 100)))"
check "exactly two hours is enough" \
    "! Box s3 has run 2 hours, and no program runs in it now." \
    "$(attention_for "$IDLE" $((S3_STARTED + 2 * 3600)))"
check "a minute less is not" "" "$(attention_for "$IDLE" $((S3_STARTED + 2 * 3600 - 60)))"
check "with an owner (a Cadabra chat) it is not idle" "" \
    "$(attention_for "$QUIET"' | (.boxes[] | select(.box.name == "s3")).activeExecs = 0' $((S3_STARTED + 5 * 3600)))"
check "with a program running it is not idle" "" \
    "$(attention_for "$QUIET"' | (.boxes[] | select(.box.name == "s3")) |= del(.ownerPid)' $((S3_STARTED + 5 * 3600)))"
check "a start time that is not a time is not guessed at" "" \
    "$(attention_for "$IDLE"' | (.boxes[] | select(.box.name == "s3")).startedAt = "yesterday"' $((S3_STARTED + 5 * 3600)))"

section "no writes to views the window does not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"

omctest_end
