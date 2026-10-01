#!/bin/bash
# Tests/helpers/refresh_agentvm_fixtures.sh - capture Tests/fixtures/agentvm/ from a real agent-vm.
#
# Usage: Tests/helpers/refresh_agentvm_fixtures.sh <path to agent-vm>
#
# Runs only queries that start and stop nothing: `version`, `doctor`, `status` (which, unlike
# `box list`, deletes no stopped disposable box), `image info` of one image, `box info` and the
# rules (`box network` with no change) of one box, and `box packs`, against the
# store agent-vm finds by itself (AGENT_VM_HOME, or ~/Library/Application Support/agent-vm),
# and, against an empty store in a temporary folder, `status` again and one job that can only
# fail, for the shape of a job's record. Each answer is re-serialized
# with sorted keys, and the home folder in every string is replaced with /Users/you, so a capture
# names no real account.
#
# status-variety.json is not captured: it is made by hand (see the README beside the fixtures)
# and this script leaves it alone.
#
# After a refresh, run the suite: the drift checks in Tests/10-agentvm-library.test.sh fail
# when a field the library reads is gone, and the version check fails until the library's
# AGENTVM_MIN_VERSION and version.json agree. A coding agent must run this with its sandbox
# off: doctor asks the virtualization framework, which a sandbox refuses.

fail() {
    printf 'refresh_agentvm_fixtures.sh: %s\n' "$*" >&2
    exit 1
}

[ "$#" -eq 1 ] || fail "usage: $0 <path to agent-vm>"
agentvm="$1"
[ -f "$agentvm" ] && [ -x "$agentvm" ] || fail "$agentvm is not an executable file"

script_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd -P)"
fixtures="$script_dir/../fixtures/agentvm"
[ -d "$fixtures" ] || fail "no fixtures folder at $fixtures"

work="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/agentvm-fixtures.XXXXXX")"
status=$?
[ "$status" -eq 0 ] && [ -n "$work" ] || fail "cannot make a temporary folder"
trap '/bin/rm -rf "$work"' EXIT

# capture <fixture name> <agent-vm args...> - one answer, sanitized, into the fixtures folder.
# Written to the temporary folder first and moved into place only when agent-vm and jq both
# succeeded, so a failed capture leaves the old fixture as it was.
capture() {
    local name="$1"
    shift
    "$agentvm" "$@" > "$work/$name.raw" 2> "$work/$name.err"
    local status=$?
    if [ "$status" -ne 0 ]; then
        /bin/cat "$work/$name.err" >&2
        fail "agent-vm $* failed with status $status"
    fi
    /usr/bin/jq -S --arg home "$HOME" \
        'walk(if type == "string" then split($home) | join("/Users/you") else . end)' \
        "$work/$name.raw" > "$work/$name.json"
    status=$?
    [ "$status" -eq 0 ] || fail "agent-vm $* did not print JSON (see $work/$name.raw)"
    /bin/mv -f "$work/$name.json" "$fixtures/$name.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot write $fixtures/$name.json"
    printf '  %s.json  <-  agent-vm %s\n' "$name" "$*"
}

printf 'Capturing from %s (%s)\n' "$agentvm" "$("$agentvm" --version 2>&1)"
capture version version --json
capture doctor doctor --json
capture status status --json

# The image detail pane reads `image info`: the first ready image built from another, which has
# every field the pane shows (a recipe, the space added over its base).
info_image="$(/usr/bin/jq -r '[.images[] | select(.state == "ready" and .derivedFrom != null)][0].name // empty' "$fixtures/status.json")"
if [ -n "$info_image" ]; then
    capture image-info image info "$info_image" --json
else
    printf '  image-info.json left as it was: no ready image built from another in this store\n'
fi

# The box detail pane reads `box info`: the first box, measured whether it runs or not.
info_box="$(/usr/bin/jq -r '.boxes[0].box.name // empty' "$fixtures/status.json")"
if [ -n "$info_box" ]; then
    capture box-info box info "$info_box" --json
    # The network window: the same box's rules (`box network` with no change only reads them).
    # Its connection log is not captured: it lists what programs in the box reached, which does
    # not belong in a public repository; box-netlog.json is made by hand (see the README).
    capture box-network box network "$info_box" --json
else
    printf '  box-info.json and box-network.json left as they were: no box in this store\n'
fi
capture packs box packs --json

/bin/mkdir -p "$work/empty-store"
status=$?
[ "$status" -eq 0 ] || fail "cannot make an empty store in $work"
AGENT_VM_HOME="$work/empty-store" capture status-empty status --json

# A job's record: one job started against the empty store, where it can only fail (there is no
# such box), so nothing outside the temporary folder changes. It ends within a second; the wait
# is for its runner to record the end. The store's path in the record is replaced like the home
# folder, since the temporary folder has a new name every time.
AGENT_VM_HOME="$work/empty-store" "$agentvm" job start -- box start nosuch > /dev/null 2> "$work/job-start.err"
status=$?
if [ "$status" -ne 0 ]; then
    /bin/cat "$work/job-start.err" >&2
    fail "agent-vm job start failed with status $status"
fi
/bin/sleep 2
AGENT_VM_HOME="$work/empty-store" capture job-list job list --json
/usr/bin/jq -S 'walk(if type == "string" then sub("^.*/empty-store"; "/Users/you/Library/Application Support/agent-vm") else . end)' \
    "$fixtures/job-list.json" > "$work/job-list.clean.json"
status=$?
[ "$status" -eq 0 ] || fail "cannot rewrite the store path in job-list.json"
/bin/mv -f "$work/job-list.clean.json" "$fixtures/job-list.json"

printf 'Done. Run the suite; update the README beside the fixtures with the date and version.\n'
