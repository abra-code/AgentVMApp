#!/bin/sh
# Tests/61-get-macos.test.sh - the Get macOS window: the library functions under it (what Apple
# offers, as one row; the job that downloads it), the two buttons that open it, one window at a
# time and only when this run of the app asked for it, what it says for a restore file that is
# not downloaded, partly downloaded, downloaded, or too big for the room left, a download that
# runs, and Download: the job it starts, its progress window, and the main window following it.
#
# agent-vm is the fake: status from fixtures/agentvm/status-variety.json, the restore files from
# fixtures/agentvm/ipsw-list.json, and what Apple offers from a jq edit of
# fixtures/agentvm/ipsw-check.json.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.newimage.sh" "$APP_SCRIPTS/lib.agentvm.getmacos.sh"
[ -n "$MAIN_GET_MACOS_ID" ] && [ -n "$NEW_GET_MACOS_ID" ] && [ -n "$GETMACOS_LATEST_ID" ] && [ -n "$GETMACOS_STATE_ID" ] \
    && [ -n "$GETMACOS_ROOM_ID" ] && [ -n "$GETMACOS_FILES_ID" ] && [ -n "$GETMACOS_COMMAND_ID" ] && [ -n "$GETMACOS_NOTE_ID" ] \
    && [ -n "$GETMACOS_CHECK_ID" ] && [ -n "$GETMACOS_PROGRESS_ID" ] && [ -n "$GETMACOS_DOWNLOAD_ID" ] || {
    printf '61-get-macos: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?61-get-macos: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-get-macos-$$"
OTHER_UUID="OMCTEST-other-get-macos-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
FIRST="20260930-120001-000001"
IPSW="UniversalMac_27.0_26A428_Restore.ipsw"
LATEST_PATH="/Users/you/Library/Application Support/agent-vm/Cache/ipsw/UniversalMac_27.0.1_26A434_Restore.ipsw"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# offered <jq edit of ipsw-check.json>  ->  the fake answers the check with that.
offered() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/ipsw-check.json" > "$FAKE_AGENTVM_DIR/ipsw-check.json"
}

request() {
    "$PB" agentvm_open_request_getmacos get
}

registered() {
    "$PB" agentvm_window_getmacos_window get
}

# open_window [uuid]  ->  the window opened the way a button opens it: the request, then the
# window's init handler, in a window of its own.
open_window() {
    "$PB" agentvm_open_request_getmacos set "$APP_PID getmacos:window"
    in_window "${1:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.getmacos
    omc_run AgentVM.getmacos.init
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# said  ->  the three lines about what Apple offers, the note, and whether Download, Progress...
# and Check Again are on.
said() {
    printf '%s|%s|%s|%s|%s%s%s\n' "$(ui_value "$GETMACOS_LATEST_ID")" "$(ui_value "$GETMACOS_STATE_ID")" "$(ui_value "$GETMACOS_ROOM_ID")" \
        "$(ui_value "$GETMACOS_NOTE_ID")" "$(enabled "$GETMACOS_DOWNLOAD_ID")" "$(enabled "$GETMACOS_PROGRESS_ID")" "$(enabled "$GETMACOS_CHECK_ID")"
}

# started  ->  the jobs agent-vm was asked to start.
started() {
    fake_log | /usr/bin/grep -c '^job start'
}

fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
"$PB" agentvm_window_getmacos_window set ""
"$PB" agentvm_open_request_getmacos set ""
"$PB" agentvm_open_request_progress set ""

# -----------------------------------------------------------------------------------------------
section "the library: what Apple offers"
check "one row: state, macOS, build, the file's bytes, none got so far, bytes free, fits, path" \
    "missing${TAB}27.0.1${TAB}26A434${TAB}26637307067${TAB}-${TAB}111895662592${TAB}true${TAB}$LATEST_PATH" \
    "$(lib agentvm_ipsw_check_row < "$FIXTURES_AGENTVM/ipsw-check.json")"
check "a download begun: the bytes got so far" "partial${TAB}12800000000" \
    "$(/usr/bin/jq '.state = "partial" | .partialBytes = 12800000000' "$FIXTURES_AGENTVM/ipsw-check.json" | lib agentvm_ipsw_check_row | col 1,5)"
check "the check is a query, and its progress event is not taken for the answer" "image fetch-ipsw --check --json|missing" \
    "$(with_fake agentvm_ipsw_check | lib agentvm_ipsw_check_row | col 1 > "$OMCTEST_WORK/state"; fake_log | /usr/bin/tail -1)|$(/bin/cat "$OMCTEST_WORK/state")"
: > "$FAKE_AGENTVM_DIR/log"
job="$(with_fake agentvm_job_fetch_ipsw)"
check "the download is a job of its own command" "$FIRST|image fetch-ipsw|ipsw" \
    "$job|$(/usr/bin/jq -r '.[0].command | map(select(. != "--json")) | join(" ")' "$JOBS")|$(/usr/bin/jq -r '.[0].targets[0]' "$JOBS")"

# -----------------------------------------------------------------------------------------------
section "the buttons that open it"
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_trigger "$MAIN_GET_MACOS_ID"
omc_run AgentVM.getmacos.open
check "the button of the image list asks for the window, with a request of this run, and asks agent-vm nothing" \
    "1|$APP_PID getmacos:window|" "$(chain_asked AgentVM.getmacos)|$(request)|$(fake_log)"
check "both buttons run that handler" "AgentVM.getmacos.open|AgentVM.getmacos.open" \
    "$(/usr/bin/jq -r --argjson id "$MAIN_GET_MACOS_ID" '.. | objects | select(.id? == $id) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.json")|$(/usr/bin/jq -r --argjson id "$NEW_GET_MACOS_ID" '.. | objects | select(.id? == $id) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.newimage.json")"

section "the window opens: a restore file that is not downloaded"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check_status "the init handler exits cleanly" 0
check "takes the request, once"      "" "$(request)"
check "becomes the Get macOS window" "$APP_PID $UUID|1" "$(registered)|$("$PB" "agentvm_getmacos_$UUID" get)"
check "asks agent-vm which it is, reads status and the files, then asks what Apple offers" \
    "--version|status --json|image fetch-ipsw --list --json|image fetch-ipsw --check --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                    "Get macOS" "$(ui_title)"
check "what Apple offers, that it is not here, that it fits; Download and Check Again are on" \
    "macOS 27.0.1 (26A434), 26.6 GB|Not downloaded yet.|111.9 GB free on the volume of the store: it fits.||101" "$(said)"
check "the restore file downloaded already: its name, macOS and build, size, and that it is the newest here" \
    "$IPSW${TAB}27.0 (26A428)${TAB}26.6 GB${TAB}newest here" "$(ui_rows "$GETMACOS_FILES_ID")"
check "the command"                  "agent-vm image fetch-ipsw" "$(ui_value "$GETMACOS_COMMAND_ID")"
check "nothing writes to a view the window does not have" "" "$(ui_unknown_writes)"

section "a second request, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_run AgentVM.getmacos.open
check "the button opens no second window, and brings the open one to the front" "0|1" \
    "$(chain_asked AgentVM.getmacos)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
"$PB" agentvm_open_request_getmacos set "$APP_PID getmacos:window"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.getmacos
omc_run AgentVM.getmacos.init
check "a second window: the first stays the Get macOS window, the second closes" "$APP_PID $UUID|1|" \
    "$(registered)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$("$PB" "agentvm_getmacos_$OTHER_UUID" get)"
in_window "$UUID"
omc_run AgentVM.getmacos.close
check "closing: there is no Get macOS window, and it keeps nothing" "|" "$(registered)|$("$PB" "agentvm_getmacos_$UUID" get)"
check_absent "  nor a cache folder"   "$TMPDIR/AgentVM/$UUID"
for bad in "" "$APP_PID newimage:window" "1 getmacos:window" "$APP_PID getmacos:dev"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_getmacos set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.getmacos
    omc_run AgentVM.getmacos.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "|" "$(registered)|$("$PB" "agentvm_getmacos_$OTHER_UUID" get)"
done

section "handlers in a window that is not a Get macOS window"
in_window "$OTHER_UUID"
ui_reset
# Everything a Get macOS window reads is there but its mark, with a download that could start
# and one that runs: so a handler that did not ask whether the window is one would act.
/bin/mkdir -p "$TMPDIR/AgentVM/$OTHER_UUID"
printf '0\n%s\ntest\n%s\n' "$(lib_value AGENTVM_MIN_VERSION)" "$FAKE_AGENTVM" > "$TMPDIR/AgentVM/$OTHER_UUID/agentvm"
lib agentvm_ipsw_check_row < "$FIXTURES_AGENTVM/ipsw-check.json" > "$TMPDIR/AgentVM/$OTHER_UUID/check.tsv"
printf '%s\trunning\tipsw\timage fetch-ipsw\n' "$FIRST" > "$TMPDIR/AgentVM/$OTHER_UUID/jobs.tsv"
chains_reset
for handler in activated check progress download; do
    [ "$handler" = "download" ] && : > "$TMPDIR/AgentVM/$OTHER_UUID/jobs.tsv"
    : > "$FAKE_AGENTVM_DIR/log"
    omc_run "AgentVM.getmacos.$handler"
    check "$handler: agent-vm is not run, nothing is written to the window, nothing is chained" "|0|0" \
        "$(fake_log)|$(ui_calls "$OTHER_UUID")|$(chain_asked AgentVM.progress)"
done
/bin/rm -rf "$TMPDIR/AgentVM/$OTHER_UUID"

# -----------------------------------------------------------------------------------------------
section "what the window says"
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
offered '.state = "partial" | .partialBytes = 12800000000'
open_window
check "a download begun before: how far it got, that it goes on, that the rest fits; Download is on" \
    "macOS 27.0.1 (26A434), 26.6 GB|48% downloaded (12.8 GB of 26.6 GB). Download goes on from there.|111.9 GB free on the volume of the store: it fits.||101" "$(said)"
offered '.fits = false | .freeBytes = 20000000000'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.check
check "Check Again reads status, the files and what Apple offers" "status --json|image fetch-ipsw --list --json|image fetch-ipsw --check --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "no room: the line says how much is free and what must stay, Download is off, and the note says what to do" \
    "macOS 27.0.1 (26A434), 26.6 GB|Not downloaded yet.|20.0 GB free on the volume of the store: not enough. At least 10 GB must stay free after the download.|There is not enough room for the download. Free some space on the volume of the store, then Check Again.|001" "$(said)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.download
check "  Download, clicked anyway, starts nothing" "0" "$(started)"
offered '.state = "ready"'
omc_run AgentVM.getmacos.check
check "downloaded: no line about room, Download is off" \
    "macOS 27.0.1 (26A434), 26.6 GB|Downloaded. The New Image window lists it as a start.||The newest macOS is downloaded already.|001" "$(said)"
offered 'del(.macOSVersion) | del(.macOSBuild) | del(.totalBytes) | del(.freeBytes) | del(.fits)'
omc_run AgentVM.getmacos.check
check "an answer without the version, the size or the room: said as far as it is known" \
    "The newest restore file for this Mac|Not downloaded yet.|||101" "$(said)"
offered '.state = "partial" | .partialBytes = 40000000000'
omc_run AgentVM.getmacos.check
check "more got so far than the file has: no percentage is made of it" "Partly downloaded. Download goes on from there." "$(ui_value "$GETMACOS_STATE_ID")"
offered '.state = "partial" | .partialBytes = 5 | .totalBytes = 0'
omc_run AgentVM.getmacos.check
check "  nor of a file of no size" "Partly downloaded. Download goes on from there." "$(ui_value "$GETMACOS_STATE_ID")"
offered '.state = "partial" | .partialBytes = 12800000000 | .totalBytes = "many"'
omc_run AgentVM.getmacos.check
check "a size that is no number: not shown, and no percentage" "macOS 27.0.1 (26A434)|Partly downloaded. Download goes on from there." \
    "$(ui_value "$GETMACOS_LATEST_ID")|$(ui_value "$GETMACOS_STATE_ID")"
offered 'del(.state)'
omc_run AgentVM.getmacos.check
check "an answer without the state: what Apple offers is said, and the window does not go on saying it is asking" \
    "macOS 27.0.1 (26A434), 26.6 GB||||101" "$(said)"
offered '[]'
omc_run AgentVM.getmacos.check 2>/dev/null
check "an answer that says nothing: the window says so, and does not go on saying it is asking" \
    "agent-vm did not say which macOS Apple offers. Check Again asks once more.||||101" "$(said)"
printf 'The Internet connection appears to be offline.\n' > "$FAKE_AGENTVM_DIR/fail-image-fetch-ipsw"
omc_run AgentVM.getmacos.check
check "Apple cannot be asked: the window says why in agent-vm's words, and the answer before is not shown" \
    "Apple could not be asked for the newest macOS: The Internet connection appears to be offline.|||" "$(said | /usr/bin/cut -d'|' -f1-4)"
check "  the files downloaded are those of the reading before" "$IPSW" "$(ui_rows "$GETMACOS_FILES_ID" | col 1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-image-fetch-ipsw"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.activated
check "coming back to the window reads status and the files, and does not ask Apple" "status --json|image fetch-ipsw --list --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.getmacos.activated
check "status cannot be read: the note says so, and Download is off" "agent-vm could not be read: the store is locked|0" \
    "$(ui_value "$GETMACOS_NOTE_ID")|$(enabled "$GETMACOS_DOWNLOAD_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.getmacos.close

section "a download that runs"
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
running="$(with_fake agentvm_job_fetch_ipsw)"
offered '.state = "partial" | .partialBytes = 12800000000'
open_window
check "the note says so; Download is off, Progress... is on" \
    "A download is running. Progress... shows how far it is, and has Stop.|011" "$(said | /usr/bin/cut -d'|' -f4-5)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.download
check "Download, clicked anyway, starts no second one" "0" "$(started)"
chains_reset
omc_run AgentVM.getmacos.progress
check "Progress... asks for that job's progress window" "1|$APP_PID progress:$running" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
"$PB" agentvm_open_request_progress set ""
/usr/bin/jq 'map(. + {state: "queued"})' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
omc_run AgentVM.getmacos.activated
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.download
check "a download that waits its turn: the same, and Download starts no second one" \
    "A download is running. Progress... shows how far it is, and has Stop.|011|0" "$(said | /usr/bin/cut -d'|' -f4-5)|$(started)"
/usr/bin/jq 'map(. + {state: "canceled", endedAt: "2026-09-30T12:05:00Z", error: "canceled"})' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
omc_run AgentVM.getmacos.activated
check "the download was stopped: Download is on again, Progress... is off" "|101" "$(said | /usr/bin/cut -d'|' -f4-5)"
chains_reset
omc_run AgentVM.getmacos.progress
check "  Progress... with no download running opens nothing" "0" "$(chain_asked AgentVM.progress)"

section "Download"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.download
check "a second Download while the first is worked on: agent-vm is not run" "" "$(fake_log)"
"$PB" "agentvm_busy_$UUID" set ""
printf 'the job cannot be recorded\n' > "$FAKE_AGENTVM_DIR/fail-job"
alerts_before="$(ui_calls omc_present_alert)"
omc_run AgentVM.getmacos.download
check "agent-vm refuses the job: an alert with its words, and the window stays" "1|The download was not started|the job cannot be recorded|0" \
    "$(( $(ui_calls omc_present_alert) - alerts_before ))|$(ui_alert_title)|$(ui_alert_message)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  Download is on again, and can be clicked again" "1|" "$(enabled "$GETMACOS_DOWNLOAD_ID")|$("$PB" "agentvm_busy_$UUID" get)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job"
in_window "$MAIN_UUID"
omc_run AgentVM.main.activated
in_window "$UUID"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_run AgentVM.getmacos.download
check_status "the handler exits cleanly" 0
check "status and the files are read first, then the download is started as a job; Apple is not asked again" \
    "status --json|image fetch-ipsw --list --json|job start --json -- image fetch-ipsw" "$(fake_log | /usr/bin/sed -n '1,3p' | /usr/bin/paste -sd '|' -)"
second="$(/usr/bin/jq -r '.[-1].id' "$JOBS")"
check "one job, the command shown" "1|agent-vm image fetch-ipsw" \
    "$(started)|agent-vm $(/usr/bin/jq -r '.[-1].command | map(select(. != "--json")) | join(" ")' "$JOBS")"
check "the command line shown is the one run" "$(ui_value "$GETMACOS_COMMAND_ID")" "agent-vm $(/usr/bin/jq -r '.[-1].command | map(select(. != "--json")) | join(" ")' "$JOBS")"
check "its progress window is asked for" "1|$APP_PID progress:$second" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
check "the window closes"            "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "the main window watches the job" "$second" "$(/usr/bin/grep -x "$second" "$TMPDIR/AgentVM/$MAIN_UUID/jobs-watched")"
omc_run AgentVM.getmacos.close
"$PB" agentvm_open_request_progress set ""

section "a window that closes while agent-vm is read"
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
# An agent-vm that, asked for status, does what the window's close handler does meanwhile.
CLOSER="$OMCTEST_WORK/closing-agent-vm"
{
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "status" ]; then\n'
    printf '    "%s" "agentvm_getmacos_%s" set ""\n' "$PB" "$UUID"
    printf '    /bin/rm -rf "%s"\n' "$TMPDIR/AgentVM/$UUID"
    printf 'fi\n'
    printf 'exec "%s" "$@"\n' "$FAKE_AGENTVM"
} > "$CLOSER"
/bin/chmod +x "$CLOSER"
AGENTVM_APP_AGENT_VM="$CLOSER"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check "on opening: Apple is not asked, nothing is painted, and no cache folder is left" "0||no" \
    "$(fake_log | /usr/bin/grep -c -- '--check')|$(ui_value "$GETMACOS_LATEST_ID")|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.getmacos.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
open_window
AGENTVM_APP_AGENT_VM="$CLOSER"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.getmacos.download
check "at Download: no job is started, and no cache folder is left" "0|no" "$(started)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.getmacos.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"

section "a window that closes while it is painted"
# The window's tools, with one that does what closing the window does before the first call whose
# arguments match CLOSE_BEFORE. Painting reads the cache, which makes the window's cache folder
# again; and a cache that is gone has nothing that stands in the way of a download.
REAL_TOOLS="$OMC_OMC_SUPPORT_PATH"
CLOSING_TOOLS="$OMCTEST_WORK/closing_tools"
CLOSE_MARK="$OMCTEST_WORK/closed-once"
/bin/mkdir -p "$CLOSING_TOOLS"
/bin/cat > "$CLOSING_TOOLS/closing_tool" <<'TOOL'
#!/bin/sh
tool="${0##*/}"
case "$tool $*" in
    $CLOSE_BEFORE)
        if [ ! -e "$CLOSE_MARK" ]; then
            printf '' > "$CLOSE_MARK"
            OMC_OMC_SUPPORT_PATH="$REAL_TOOLS" /bin/sh "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/AgentVM.getmacos.close.sh"
        fi ;;
esac
exec "$REAL_TOOLS/$tool" "$@"
TOOL
/bin/chmod +x "$CLOSING_TOOLS/closing_tool"
for tool in "$REAL_TOOLS"/*; do
    /bin/ln -sf "$tool" "$CLOSING_TOOLS/${tool##*/}"
done
/bin/rm -f "$CLOSING_TOOLS/omc_dialog_control"
/bin/cp "$CLOSING_TOOLS/closing_tool" "$CLOSING_TOOLS/omc_dialog_control"
# closing_before <pattern> <handler>  ->  the handler run with those tools.
closing_before() {
    /bin/rm -f "$CLOSE_MARK"
    ( CLOSE_BEFORE="$1"; OMC_OMC_SUPPORT_PATH="$CLOSING_TOOLS"
      export CLOSE_BEFORE CLOSE_MARK REAL_TOOLS OMC_OMC_SUPPORT_PATH
      omc_run "$2" )
}
left() {
    printf '%s|%s|%s\n' "$([ -e "$CLOSE_MARK" ] && echo closed)" "$("$PB" "agentvm_getmacos_$UUID" get)" "$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
}
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
open_window
closing_before "omc_dialog_control $UUID $GETMACOS_NOTE_ID *" AgentVM.getmacos.activated
check "on coming back to it: the window was closed, and no cache folder is left" "closed||no" "$(left)"
open_window
closing_before "omc_dialog_control $UUID $GETMACOS_LATEST_ID *" AgentVM.getmacos.check
check "at Check Again: the same" "closed||no" "$(left)"
# The first paint of an opening window says that Apple is asked; the second names the macOS.
"$PB" agentvm_open_request_getmacos set "$APP_PID getmacos:window"
ui_reset
omc_control_defaults AgentVM.getmacos
closing_before "omc_dialog_control $UUID $GETMACOS_LATEST_ID macOS*" AgentVM.getmacos.init
check "on opening, at the second paint: the same" "closed||no" "$(left)"
open_window
: > "$FAKE_AGENTVM_DIR/log"
closing_before "omc_dialog_control $UUID $GETMACOS_LATEST_ID *" AgentVM.getmacos.download
check "at Download: the same, and no job is started" "closed||no|0" "$(left)|$(started)"

section "an agent-vm that cannot be used"
printf '0.1.0\n' > "$FAKE_AGENTVM_DIR/version"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check "the note says why; nothing can be clicked" "1|000" "$(ui_value "$GETMACOS_NOTE_ID" | /usr/bin/grep -c 'agent-vm')|$(said | /usr/bin/cut -d'|' -f5)"
check "only its version was asked"   "--version" "$(fake_log | /usr/bin/paste -sd '|' -)"
omc_run AgentVM.getmacos.close
/bin/rm -f "$FAKE_AGENTVM_DIR/version"

section "nothing went wrong in the harness"
check "no write to a view no window has" "" "$(ui_unknown_writes)"
check "no table had its rows replaced by a value" "" "$(ui_suspect_writes)"
check "no harness errors"            "" "$(ui_errors)"

omctest_end
