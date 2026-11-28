#!/bin/sh
# Tests/24-settings-timemachine.test.sh - Settings: the Time Machine group. A checkbox each leaves
# the store's Boxes, Images or Cache out of Time Machine backups, or backs it up again, and a
# folder button shows it in Finder. The choice is kept per store and folder; a folder made again is
# left out again when the window opens, and a folder left out by hand is taken as checked.
#
# agent-vm is the fake: status is status-variety.json with its kept logs in a store made here.
# tmutil is the fake too (fake_tmutil.sh, set for every test by lib.test.agentvm.sh).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.timemachine.sh"
[ -n "$TM_BASE_ID" ] && [ -n "$TM_TEXT_ID" ] || {
    printf '24-settings-timemachine: no view ids imported from the library\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG
STORE="$OMCTEST_WORK/store"
CHOICES="$HOME/Library/Application Support/AgentVM/time-machine-left-out"

# store_with <folder...>  ->  a store holding those folders and Logs, named by the fake's status.
store_with() {
    /bin/rm -rf "$STORE"
    /bin/mkdir -p "$STORE/Logs"
    local _name
    for _name in "$@"; do
        /bin/mkdir -p "$STORE/$_name"
    done
    /usr/bin/jq --arg dir "$STORE/Logs" '.keptLogs.directory = $dir' \
        "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

open_window() {
    omc_run AgentVM.main.close
    alerts_reset
    ui_reset
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

on() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# The view ids of folder n's checkbox and Finder button (Boxes 1, Images 2, Cache 3).
toggle_id() {
    echo $(( TM_BASE_ID + 2 * $1 ))
}
show_id() {
    echo $(( TM_BASE_ID + 2 * $1 + 1 ))
}

# turn <n> <true|false>  ->  folder n's checkbox checked or unchecked.
turn() {
    omc_control "$(toggle_id "$1")" "$2"
    omc_trigger "$(toggle_id "$1")"
    omc_run AgentVM.main.timemachine
}

# boxes  ->  the three checkboxes, "true false true" for Boxes, Images and Cache.
boxes() {
    printf '%s %s %s\n' "$(ui_value "$(toggle_id 1)")" "$(ui_value "$(toggle_id 2)")" "$(ui_value "$(toggle_id 3)")"
}

# excluded  ->  the folders the fake holds as left out, by name, space-joined.
excluded() {
    /usr/bin/sed "s|^$STORE/||" "$FAKE_TMUTIL_EXCLUDED" 2>/dev/null | /usr/bin/sort | /usr/bin/tr '\n' ' ' | /usr/bin/sed 's/ $//'
}

reset_all() {
    fake_reset
    : > "$FAKE_TMUTIL_EXCLUDED"
    : > "$FAKE_TMUTIL_LOG"
    /bin/rm -f "$CHOICES"
    unset FAKE_TMUTIL_REFUSE
}

section "nothing chosen"
reset_all
store_with Boxes Images Cache
open_window
check "all unchecked and on, the folder buttons on, and where the setting is seen" "false false false|1 1 1|1 1 1|Time Machine settings do not list these folders." \
    "$(boxes)|$(on "$(toggle_id 1)") $(on "$(toggle_id 2)") $(on "$(toggle_id 3)")|$(on "$(show_id 1)") $(on "$(show_id 2)") $(on "$(show_id 3)")|$(ui_value "$TM_TEXT_ID")"
check "  reading changes nothing" "0" "$(/usr/bin/grep -c 'exclusion' "$FAKE_TMUTIL_LOG")"

section "checked one at a time"
turn 1 true
check "Boxes: left out, checked, kept as chosen" "Boxes|true false false|$STORE${TAB}Boxes" \
    "$(excluded)|$(boxes)|$(/bin/cat "$CHOICES")"
turn 3 true
check "Cache too" "Boxes Cache|true false true" "$(excluded)|$(boxes)"
check "  Logs is never touched" "0" "$(/usr/bin/grep -c '/Logs$' "$FAKE_TMUTIL_LOG")"
turn 1 false
check "Boxes unchecked: backed up again, no longer chosen" "Cache|false false true|$STORE${TAB}Cache" \
    "$(excluded)|$(boxes)|$(/bin/cat "$CHOICES")"
open_window
check "  the next opening changes nothing" "Cache|false false true" "$(excluded)|$(boxes)"

section "a folder made again"
/bin/rm -rf "$STORE/Cache"
/usr/bin/grep -vxF "$STORE/Cache" "$FAKE_TMUTIL_EXCLUDED" > "$FAKE_TMUTIL_EXCLUDED.new"
/bin/mv -f "$FAKE_TMUTIL_EXCLUDED.new" "$FAKE_TMUTIL_EXCLUDED"
/bin/mkdir -p "$STORE/Cache"
omc_run AgentVM.main.activated
check "activation leaves it out again" "Cache|false false true" "$(excluded)|$(boxes)"

section "a folder left out by hand"
reset_all
store_with Boxes Images Cache
printf '%s\n' "$STORE/Boxes" > "$FAKE_TMUTIL_EXCLUDED"
open_window
check "taken as checked, and kept as chosen" "true false false|$STORE${TAB}Boxes" "$(boxes)|$(/bin/cat "$CHOICES")"

section "a folder not made yet"
reset_all
store_with Images
open_window
check "its folder button off, its checkbox on" "0|1" "$(on "$(show_id 1)")|$(on "$(toggle_id 1)")"
turn 1 true
check "checked: nothing to change yet" "|true false false" "$(excluded)|$(boxes)"
/bin/mkdir -p "$STORE/Boxes"
open_window
check "  made later: left out on the next opening" "Boxes|1" "$(excluded)|$(on "$(show_id 1)")"

section "the folder buttons"
: > "$FAKE_OPEN_LOG"
omc_trigger "$(show_id 1)"
omc_run AgentVM.main.timemachine.show
check "show Boxes in Finder" "$STORE/Boxes" "$(/bin/cat "$FAKE_OPEN_LOG")"
: > "$FAKE_OPEN_LOG"
omc_trigger "$(show_id 3)"
omc_run AgentVM.main.timemachine.show
check "  a folder not made: nothing opened" "" "$(/bin/cat "$FAKE_OPEN_LOG")"

section "tmutil refuses"
reset_all
store_with Boxes Images Cache
open_window
FAKE_TMUTIL_REFUSE=Images
export FAKE_TMUTIL_REFUSE
turn 2 true
check "not left out, and the line says which and why" "|Could not change Images: Operation not permitted." \
    "$(excluded)|$(ui_value "$TM_TEXT_ID")"
unset FAKE_TMUTIL_REFUSE
open_window
check "  once it works: left out on the next opening, and the message gone" "Images|Time Machine settings do not list these folders." \
    "$(excluded)|$(ui_value "$TM_TEXT_ID")"
FAKE_TMUTIL_REFUSE=Images
export FAKE_TMUTIL_REFUSE
turn 2 false
check "unchecking refused: still left out, so checked again, and said" "Images|false true false|Could not change Images: Operation not permitted." \
    "$(excluded)|$(boxes)|$(ui_value "$TM_TEXT_ID")"
unset FAKE_TMUTIL_REFUSE

section "the store the app uses"
reset_all
store_with Boxes Images Cache
open_window
turn 1 true
OTHER="$OMCTEST_WORK/other-store"
/bin/mkdir -p "$OTHER/Logs" "$OTHER/Boxes"
/usr/bin/jq --arg dir "$OTHER/Logs" '.keptLogs.directory = $dir' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
open_window
check "another store's Boxes is not chosen: unchecked, backed up" "false|0" \
    "$(ui_value "$(toggle_id 1)")|$(/usr/bin/grep -c "^$OTHER" "$FAKE_TMUTIL_EXCLUDED")"

omctest_end
