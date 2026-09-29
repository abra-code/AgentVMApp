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
