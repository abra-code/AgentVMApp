#!/bin/sh
# Tests/helpers/fake_agent_vm.sh - agent-vm, answered from files.
#
# Copied from Cadabra's Tests/helpers/fake_agent_vm.sh (AIChatApp, 2026-09-29) and cut down to
# the commands AgentVM.app runs so far; the long commands and their progress events come back
# with the jobs. The same state-directory conventions, so a test written against one reads
# naturally against the other.
#
# lib.agentvm.sh runs agent-vm through agentvm_bin, and AGENTVM_APP_AGENT_VM points that here.
# The real agent-vm needs macOS 27, a store of multi-GB images and virtual machines, and answers
# differently on every Mac; this answers the same way every time, from JSON captured from a real
# agent-vm (Tests/fixtures/agentvm/, see the README there), and it can fail on request.
#
# -- The state directory ($FAKE_AGENTVM_DIR) ----------------------------------------------------
#   log        APPENDED to, one line per invocation: the arguments, space-joined.
#   home       REWRITTEN each invocation: AGENT_VM_HOME as the fake saw it, or "(unset)".
#   exit       when present, every invocation prints the file "stderr" (if any) to stderr and
#              exits with this status, before looking at its arguments.
#   fail-<a>   when present, the command "<a>" (fail-status, fail-doctor) prints "Error: " and
#              the file's text to stderr and exits 1, or with the status in fail-<a>-status
#              when that is present.
#   version    what --version prints (default: AGENTVM_MIN_VERSION from the library, the oldest
#              version the app accepts, so raising it needs no change here).
#   <key>.json the answer to one query, overriding the fixture of that name: version, doctor,
#              status.
#
# -- What it implements -------------------------------------------------------------------------
#   --version, version --json, doctor --json, status --json.
# Anything else fails with status 64, so a test that reaches an unimplemented command finds out.

state="${FAKE_AGENTVM_DIR:?fake_agent_vm: FAKE_AGENTVM_DIR is not set}"
fixtures="${FAKE_AGENTVM_FIXTURES:-$(/usr/bin/dirname "$0")/../fixtures/agentvm}"
agentvm_library="${OMC_APP_BUNDLE_PATH:-$(/usr/bin/dirname "$0")/../../AgentVM.app}/Contents/Resources/Scripts/lib.agentvm.sh"
[ -d "$state" ] || /bin/mkdir -p "$state"

printf '%s\n' "$*" >> "$state/log"
if [ -n "${AGENT_VM_HOME+set}" ]; then
    printf '%s\n' "$AGENT_VM_HOME" > "$state/home"
else
    printf '(unset)\n' > "$state/home"
fi

if [ -f "$state/exit" ]; then
    [ -f "$state/stderr" ] && /bin/cat "$state/stderr" >&2
    exit "$(/bin/cat "$state/exit")"
fi
if [ -n "$1" ] && [ -f "$state/fail-$1" ]; then
    printf 'Error: %s\n' "$(/bin/cat "$state/fail-$1")" >&2
    if [ -f "$state/fail-$1-status" ]; then
        exit "$(/bin/cat "$state/fail-$1-status")"
    fi
    exit 1
fi

# answer <key> - the state directory's <key>.json, else the fixture of that name.
answer() {
    if [ -f "$state/$1.json" ]; then
        /bin/cat "$state/$1.json"
    else
        /bin/cat "$fixtures/$1.json"
    fi
}

case "$*" in
    "--version")
        if [ -f "$state/version" ]; then
            /bin/cat "$state/version"
        else
            /usr/bin/sed -n 's/^AGENTVM_MIN_VERSION="\(.*\)"$/\1/p' "$agentvm_library"
        fi ;;
    "version --json")
        answer version ;;
    "doctor --json")
        answer doctor ;;
    "status --json")
        answer status ;;
    *)
        printf 'Error: fake_agent_vm does not implement: %s\n' "$*" >&2
        exit 64 ;;
esac
