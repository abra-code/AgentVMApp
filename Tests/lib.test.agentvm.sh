#!/bin/sh
# Tests/lib.test.agentvm.sh - AgentVM.app's accessors for omctest.
#
# Sourced by every test file, right after omctest.sh.
#
# The app keeps its settings under $HOME (~/Library/Application Support/AgentVM) and looks for
# agent-vm in $HOME/.local/bin, so a test that ran against the real home folder would read, and
# one day write, the developer's own settings and run the developer's own agent-vm. omctest API
# 3 and later give every test file a home folder of its own inside the scratch tree; the guards
# below refuse to run without it. Every guard fails closed: an empty variable or a failed test
# stops the file rather than falling through.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".

# The version is matched as digits before it is compared: a value that is not a number makes
# `[ -lt ]` exit 2, which an `if` treats as false, and execution would go on past the check.
case "${OMCTEST_API_VERSION:-}" in
    ''|*[!0123456789]*)
        printf 'lib.test.agentvm: OMCTEST_API_VERSION is [%s], not a number - refusing to run\n' \
            "${OMCTEST_API_VERSION:-}" >&2
        exit 1 ;;
esac
if [ "$OMCTEST_API_VERSION" -lt 4 ]; then
    printf 'lib.test.agentvm: needs omctest API 4 or newer (an isolated $HOME and namespaced pasteboards), found %s - refusing to run\n' \
        "$OMCTEST_API_VERSION" >&2
    exit 1
fi

# Both must be non-empty before either is used as a pattern: an empty OMCTEST_SCRATCH would make
# the pattern "/*", which every home folder matches.
[ -n "${OMCTEST_SCRATCH:-}" ] || {
    printf 'lib.test.agentvm: OMCTEST_SCRATCH is empty - refusing to run\n' >&2
    exit 1
}
[ -n "${HOME:-}" ] || {
    printf 'lib.test.agentvm: HOME is empty - refusing to run\n' >&2
    exit 1
}
case "$HOME" in
    "$OMCTEST_SCRATCH"/*) ;;
    *)  printf 'lib.test.agentvm: HOME is %s, which is not inside the test scratch - refusing to run\n' "$HOME" >&2
        exit 1 ;;
esac

APP_RESOURCES="$OMC_APP_BUNDLE_PATH/Contents/Resources"
APP_SCRIPTS="$APP_RESOURCES/Scripts"
APP_INFO_PLIST="$OMC_APP_BUNDLE_PATH/Contents/Info.plist"
TEST_HELPERS="$OMCTEST_TESTS/helpers"

# plist_value <key path>  ->  one value from the app's Info.plist, as plutil prints it raw.
plist_value() {
    /usr/bin/plutil -extract "$1" raw "$APP_INFO_PLIST" 2>/dev/null
}

# command_value <jq filter>  ->  the filter applied to Command.json, one raw line per result.
command_value() {
    /usr/bin/jq -r "$1" "$APP_RESOURCES/Command.json" 2>/dev/null
}

# -- agent-vm ------------------------------------------------------------------------------------
# agent-vm never runs in these tests except in the contract test: AGENTVM_APP_AGENT_VM points
# the library at the fake, which answers from Tests/fixtures/agentvm/.
FAKE_AGENTVM="$TEST_HELPERS/fake_agent_vm.sh"
FIXTURES_AGENTVM="$OMCTEST_FIXTURES/agentvm"
# Named for the fake, which otherwise finds them beside itself: a copy installed as
# ~/.local/bin/agent-vm would look in the wrong place.
FAKE_AGENTVM_FIXTURES="$FIXTURES_AGENTVM"
FAKE_AGENTVM_DIR="$OMCTEST_WORK/fakevm"
export FAKE_AGENTVM_DIR FAKE_AGENTVM_FIXTURES
TAB=$(printf '\t')

# The developer's own environment must not decide which binary the library picks or which store
# it reads. The scratch $HOME does not isolate a real agent-vm: it finds its home folder from the
# account, not from $HOME, so every real run needs AGENT_VM_HOME set to a scratch store.
unset AGENTVM_APP_AGENT_VM AGENT_VM_HOME

# The app's settings file, computed as the library computes it, from $HOME.
APP_SETTINGS="$HOME/Library/Application Support/AgentVM/settings.json"

# lib_value <NAME>  ->  a variable's value as lib.agentvm.sh assigns it, read from the file.
# For guards that compare the library with something else (the fixtures' version), never for
# the expected value of a check about the library's own behavior.
lib_value() {
    /usr/bin/sed -n "s/^$1=\"\\(.*\\)\"\$/\\1/p" "$APP_SCRIPTS/lib.agentvm.sh"
}

# lib <function> [args...]  ->  the library function, run in a subshell with the library sourced,
# so its variables and the files it names are computed from this file's $HOME and $TMPDIR.
lib() {
    ( . "$APP_SCRIPTS/lib.agentvm.sh" >/dev/null 2>&1
      "$@" )
}

# with_fake <function> [args...]  ->  the same, with the test seam pointing at the fake.
# A subshell, because in POSIX mode an assignment before a FUNCTION call outlives the call.
with_fake() {
    ( AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"; export AGENTVM_APP_AGENT_VM; lib "$@" )
}

# fake_reset  ->  a fake with no overrides and an empty log.
fake_reset() {
    /bin/rm -rf "$FAKE_AGENTVM_DIR"
    /bin/mkdir -p "$FAKE_AGENTVM_DIR"
}

# fake_log  ->  the arguments of every call the fake answered, one call per line.
fake_log() {
    /bin/cat "$FAKE_AGENTVM_DIR/log" 2>/dev/null
}

# settings_write <json>  ->  the app's settings file, as the Settings window would leave it.
# settings_clear removes it.
settings_write() {
    /bin/mkdir -p "$(/usr/bin/dirname "$APP_SETTINGS")"
    printf '%s\n' "$1" > "$APP_SETTINGS"
}
settings_clear() {
    /bin/rm -f "$APP_SETTINGS"
}

# col <n>  ->  one tab-separated column of stdin. field_count  ->  the fields of each line.
col() { /usr/bin/cut -f"$1"; }
field_count() { /usr/bin/awk -F'\t' '{ print NF }' | /usr/bin/sort -u; }

# row_named <name>  ->  the line of stdin whose first field is name.
row_named() { /usr/bin/awk -F'\t' -v name="$1" '$1 == name'; }
