#!/bin/sh
# Tests/80-get-started.test.sh - the Get started face of the main window: its six steps (agent-vm,
# this Mac can run boxes, a macOS restore file, an image, Full Disk Access, a box), each with a
# state, a fact and a button, in every state of a first use: no agent-vm, a doctor failure, an
# empty store with and without a restore file, a download and a build that run, images with and
# without Full Disk Access, and the move to Status once a box exists; and what the buttons open.
#
# agent-vm is the fake: status from jq edits of fixtures/agentvm/status-empty.json and
# status.json, the restore files from fixtures/agentvm/ipsw-list.json or none.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

# What the image step of Get started says about Local Network access while no image is ready.
LOCAL_NETWORK="macOS asks whether AgentVM may find devices on local networks: allow it, since that is how the build reaches the new virtual machine on this Mac. If it was declined before, turn AgentVM on in System Settings > Privacy & Security > Local Network"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh"
[ -n "$MAIN_GETSTARTED_ID" ] && [ -n "$MAIN_STATUS_ID" ] && [ -n "$MAIN_GETSTARTED_NOTE_ID" ] || {
    printf '80-get-started: no view ids imported from the library\n' >&2
    exit 1
}
base() {
    /usr/bin/sed -n "s/^$1=\\([0-9][0-9]*\\)\$/\\1/p" "$APP_SCRIPTS/lib.agentvm.main.sh"
}
SYMBOL="$(base MAIN_STAGE_SYMBOL_BASE)"
FACT="$(base MAIN_STAGE_FACT_BASE)"
BUTTON="$(base MAIN_STAGE_BUTTON_BASE)"
[ -n "$SYMBOL" ] && [ -n "$FACT" ] && [ -n "$BUTTON" ] || {
    printf '80-get-started: the bases of the steps were not found in the library\n' >&2
    exit 1
}

AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?80-get-started: OMC_APP_PROCESS_ID is not set}"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"

use_fake() {
    AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
    export AGENTVM_APP_AGENT_VM
}
use_nothing() {
    unset AGENTVM_APP_AGENT_VM
}

# store <fixture> [jq edit]  ->  the fake answers status with that fixture, edited.
store() {
    /usr/bin/jq "${2:-.}" "$FIXTURES_AGENTVM/$1" > "$FAKE_AGENTVM_DIR/status.json"
}

# files <none|one>  ->  the restore files the fake lists.
files() {
    if [ "$1" = "none" ]; then
        printf '[]\n' > "$FAKE_AGENTVM_DIR/ipsw-list.json"
    else
        /bin/rm -f "$FAKE_AGENTVM_DIR/ipsw-list.json"
    fi
}

open_window() {
    ui_reset
    chains_reset
    /bin/rm -rf "$TMPDIR/AgentVM/$UUID"
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}

# steps  ->  for each of the six steps, a letter for its symbol (d done, t to do, r running, f
# failed, a attention) and whether its button is on (step 1 is "-": its button, Install... or Update..., is checked in 81-install.test.sh).
steps() {
    local _n=0 _out="" _letter _on
    while [ "$_n" -lt 6 ]; do
        _n=$((_n + 1))
        case "$(ui_prop $((SYMBOL + _n)) systemName) $(ui_prop $((SYMBOL + _n)) foregroundStyle)" in
            "checkmark.circle.fill green")       _letter=d ;;
            "circle secondary")                  _letter=t ;;
            "arrow.clockwise.circle.fill blue")  _letter=r ;;
            "xmark.circle.fill red")             _letter=f ;;
            "exclamationmark.circle.fill orange") _letter=a ;;
            *)                                   _letter="?" ;;
        esac
        if [ "$_n" -eq 1 ]; then
            _on="-"
        else
            [ "$(ui_enabled $((BUTTON + _n)))" = "1" ] && _on=1 || _on=0
        fi
        _out="$_out$_letter$_on "
    done
    printf '%s\n' "${_out% }"
}

fact() {
    ui_value $((FACT + $1))
}

shown() {
    [ "$(ui_visible "$1")" = "1" ] && echo 1 || echo 0
}

# lib_steps  ->  the steps as `steps` writes them, from the library's rows for what the window has
# read. With an image ready the window shows Status and does not paint the steps, which are then
# checked this way. lib_fact <n>  ->  the fact of step n, from the same rows.
lib_rows() {
    ( . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1; main_stage_rows "$UUID" )
}
lib_steps() {
    lib_rows | /usr/bin/awk -F'\t' '{
        l = ($2 == "done") ? "d" : ($2 == "todo") ? "t" : ($2 == "running") ? "r" : ($2 == "failed") ? "f" : ($2 == "attention") ? "a" : "?"
        printf "%s%s%s", (NR > 1 ? " " : ""), l, ($1 == 1 ? "-" : $4) } END { print "" }'
}
lib_fact() {
    lib_rows | /usr/bin/awk -F'\t' -v n="$1" '$1 == n { print (($3 == "-") ? "" : $3) }'
}

# press <step> <handler>  ->  a click on that step's button.
press() {
    omc_trigger "$((BUTTON + $1))"
    omc_run "$2"
}

: > "$FAKE_SLEEP_LOG"

# -----------------------------------------------------------------------------------------------
section "no agent-vm"
use_nothing
fake_reset
open_window
check "Get started is shown"         "1|0" "$(shown "$MAIN_GETSTARTED_ID")|$(shown "$MAIN_STATUS_ID")"
check "the first step failed, the others are to do, and no button is on" "f- t0 t0 t0 t0 t0" "$(steps)"
check "the other steps say nothing"  "||||" "$(fact 2)|$(fact 3)|$(fact 4)|$(fact 5)|$(fact 6)"
check "agent-vm never ran"           "" "$(fake_log)"

section "an empty store, and no restore file"
use_fake
fake_reset
store status-empty.json
files none
open_window
check "agent-vm is asked for the restore files too, after the lists" "--version|doctor --json|status --json|image fetch-ipsw --list --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "agent-vm and the Mac are done; a restore file is the next thing, and the only button but Check Again" "d- d1 t1 t0 t0 t0" "$(steps)"
check "what the Mac can share"       "supported; this Mac has 10 CPU cores and 24 GB of memory to share with boxes" "$(fact 2)"
check "the restore file, the image and the box, each with what comes first" \
    "none downloaded yet: about 27 GB, the first thing an image is built from|none ready yet: a macOS restore file comes first|granted once, by hand, on the screen of the first image|none yet. A box is a working copy of an image, made in seconds, and it is what runs: keep one for your own work, or let avm or Cadabra make throw-away ones" \
    "$(fact 3)|$(fact 4)|$(fact 5)|$(fact 6)"
press 3 AgentVM.getmacos.open
check "Get macOS... asks for the Get macOS window" "1|$APP_PID getmacos:window" "$(chain_asked AgentVM.getmacos)|$("$PB" agentvm_open_request_getmacos get)"
"$PB" agentvm_open_request_getmacos set ""

section "a download that runs"
/usr/bin/jq -n '[{id: "20260930-120000-0000a1", command: ["image", "fetch-ipsw", "--json"], targets: ["ipsw"], state: "running",
    createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z", progress: {event: "progress", step: "download", fraction: 0.48, message: "Downloading"}}]' > "$JOBS"
omc_run AgentVM.main.activated
check "the step runs, and says how far it is" "d- d1 r1 t0 t0 t0|Downloading: 48%" "$(steps)|$(fact 3)"
/usr/bin/jq '. + [.[0] | .id = "20260930-120100-0000a2" | .state = "queued" | del(.startedAt) | del(.progress)]' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
omc_run AgentVM.main.activated
check "with another waiting behind it, the one that runs is the one told" "Downloading: 48%" "$(fact 3)"
/usr/bin/jq '.[0:1]' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
/usr/bin/jq '.[0].state = "queued" | del(.[0].startedAt) | del(.[0].progress)' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
omc_run AgentVM.main.activated
check "one that waits"               "A download waits to start" "$(fact 3)"
/bin/rm -f "$JOBS"

section "a restore file is here"
files one
omc_run AgentVM.main.activated
check "the step is done, and an image is the next thing" "d- d1 d1 t1 t0 t0" "$(steps)"
check "the file's macOS and size, and what an image takes" "macOS 27.0, 26.6 GB|none ready yet: a first image takes about 10 minutes to build. $LOCAL_NETWORK" "$(fact 3)|$(fact 4)"
press 4 AgentVM.main.image.new
check "New Image... asks for the New Image window, with no image handed over" "1|$APP_PID " "$(chain_asked AgentVM.newimage)|$("$PB" agentvm_newimage_from get)"
"$PB" agentvm_open_request_newimage set ""

section "an image being built"
/usr/bin/jq -n '[{id: "20260930-120000-0000b1", command: ["image", "create", "dev", "--json"], targets: ["image:dev"], state: "running",
    createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z", progress: {event: "progress", step: "install", fraction: 0.4, message: "Installing macOS"}}]' > "$JOBS"
store status-empty.json '.images = [{name: "dev", state: "installing", path: "/Users/you/Library/Application Support/agent-vm/Images/dev"}]'
omc_run AgentVM.main.activated
check "the step runs, and says which image and what it does" "r1|1" "$(steps | /usr/bin/cut -d' ' -f4)|$(fact 4 | /usr/bin/grep -c '^dev: Building.*Installing macOS\. macOS asks whether AgentVM may find devices on local networks: allow it.*Local Network$')"
/usr/bin/jq '. + [.[0] | .id = "20260930-120100-0000b2" | .command[2] = "web" | .targets = ["image:web"] | .state = "queued" | del(.startedAt) | del(.progress)]' "$JOBS" > "$JOBS.new" && /bin/mv "$JOBS.new" "$JOBS"
omc_run AgentVM.main.activated
check "with another build waiting behind it, the one that runs is the one told" "1" "$(fact 4 | /usr/bin/grep -c '^dev: Building.*Installing macOS\. macOS asks whether AgentVM may find devices on local networks: allow it.*Local Network$')"
/bin/rm -f "$JOBS"

section "an image built outside the app, and a build that failed"
omc_run AgentVM.main.activated
check "an image that is being built with no job: the step runs, and says so" "r1|dev: being built by a command outside this app" \
    "$(steps | /usr/bin/cut -d' ' -f4)|$(fact 4)"
store status-empty.json '.images = [{name: "dev", state: "failed", failure: "the build was canceled", path: "/x"}]'
omc_run AgentVM.main.activated
check "only a failed image: the step wants attention, names it, and New Image... is on" \
    "a1|none ready: the build of dev failed. agent-vm image delete in Terminal removes a failed image" "$(steps | /usr/bin/cut -d' ' -f4)|$(fact 4)"
/usr/bin/jq -n '[{id: "20260930-120000-0000c1", command: ["image", "create", "more", "--json"], targets: ["image:more"], state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"},
    {id: "20260930-120000-0000c2", command: ["image", "fetch-ipsw", "--json"], targets: ["ipsw"], state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$JOBS"
store status.json '.boxes = []'
omc_run AgentVM.main.activated
check "a step that is done stays done while a job adds to it: another image, a newer restore file" "d1 d1" "$(lib_steps | /usr/bin/cut -d' ' -f3-4)"
/bin/rm -f "$JOBS"
store status-empty.json

section "this Mac cannot run boxes"
/usr/bin/jq '(.checks[] | select(.name == "virtualization")) |= (.status = "failure" | .detail = "Virtualization reports that this process cannot run virtual machines")
    | (.checks[] | select(.name == "entitlement")) |= (.status = "failure" | .detail = "com.apple.security.virtualization is missing")' \
    "$FIXTURES_AGENTVM/doctor.json" > "$FAKE_AGENTVM_DIR/doctor.json"
store status-empty.json
omc_run AgentVM.main.activated
check "the step failed, with every failure named; only Check Again is on" \
    "d- f1 d0 t0 t0 t0|Virtualization reports that this process cannot run virtual machines (virtualization); com.apple.security.virtualization is missing (entitlement)" "$(steps)|$(fact 2)"
/bin/rm -f "$FAKE_AGENTVM_DIR/doctor.json"
: > "$FAKE_AGENTVM_DIR/log"
press 2 AgentVM.main.getstarted.check
check "Check Again asks agent-vm which it is, doctor, and the lists" "--version|doctor --json|status --json|image fetch-ipsw --list --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "  and the step is done again" "d- d1 d1 t1 t0 t0" "$(steps)"
/usr/bin/jq '(.checks[] | select(.name == "disk space")) |= (.status = "warning" | .detail = "8 GB free: a build needs more")' \
    "$FIXTURES_AGENTVM/doctor.json" > "$FAKE_AGENTVM_DIR/doctor.json"
omc_run AgentVM.main.activated
check "a warning does not fail the step, and is said" "d1|supported; this Mac has 10 CPU cores and 24 GB of memory to share with boxes; 8 GB free: a build needs more" \
    "$(steps | /usr/bin/cut -d' ' -f2)|$(fact 2)"
/bin/rm -f "$FAKE_AGENTVM_DIR/doctor.json"

section "images, and no box"
# With an image ready the window shows Status: the steps are checked from the library's rows.
store status.json '.boxes = [] | .images |= map(.needs = [{kind: "full-disk-access", reason: "not-granted"}])'
omc_run AgentVM.main.activated
check "an image is done; no image has Full Disk Access, which wants attention; a box can be made" "d- d1 d1 d1 a1 t1" "$(lib_steps)"
check "the images, the ones without the grant, and the box" \
    "6 ready: dev, dev-acp, dev-agents, and 3 more|no image has it yet (dev, dev-acp, dev-agents, and 3 more): a program in a box that opens Desktop, Documents or Downloads would wait on a question nobody sees|none yet. A box is a working copy of an image, made in seconds, and it is what runs: keep one for your own work, or let avm or Cadabra make throw-away ones" \
    "$(lib_fact 4)|$(lib_fact 5)|$(lib_fact 6)"
chains_reset
press 5 AgentVM.main.getstarted.access
check "Set Up... asks for the guide of the first image without it" "1|$APP_PID access:dev" "$(chain_asked AgentVM.access)|$("$PB" agentvm_open_request_access get)"
"$PB" agentvm_open_request_access set ""
store status.json '.boxes = []'
omc_run AgentVM.main.activated
check "some images have it: the step is done, and Set Up... is still there for the others" \
    "d1|dev, dev-acp and dev-agents; not yet: dev-node, dev-xcode and dev-xcode-ios" "$(lib_steps | /usr/bin/cut -d' ' -f5)|$(lib_fact 5)"
store status.json '.boxes = [] | .images |= map(.needs = [])'
omc_run AgentVM.main.activated
check "every image has it: nothing is left to set up" "d0|every ready image has it" "$(lib_steps | /usr/bin/cut -d' ' -f5)|$(lib_fact 5)"
chains_reset
press 5 AgentVM.main.getstarted.access
check "  Set Up..., run anyway, opens nothing" "0" "$(chain_asked AgentVM.access)"
# Images and no restore file show on Get started only while this Mac cannot run boxes.
files none
/usr/bin/jq '(.checks[] | select(.name == "virtualization")) |= (.status = "failure" | .detail = "no virtualization")' \
    "$FIXTURES_AGENTVM/doctor.json" > "$FAKE_AGENTVM_DIR/doctor.json"
omc_run AgentVM.main.activated
check "no restore file, with images: Get started says one is needed only for an image built from nothing" \
    "1|t0 d0|none downloaded; one is needed only for an image built from nothing" "$(shown "$MAIN_GETSTARTED_ID")|$(steps | /usr/bin/cut -d' ' -f3-4)|$(fact 3)"
/bin/rm -f "$FAKE_AGENTVM_DIR/doctor.json"
chains_reset
press 6 AgentVM.main.box.new
check "New Box... asks for the New Box window" "1|$APP_PID newbox:window" "$(chain_asked AgentVM.newbox)|$("$PB" agentvm_open_request_newbox get)"
"$PB" agentvm_open_request_newbox set ""

section "an image is ready: Status, with or without a box"
store status.json '.boxes = []'
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.activated
check "the window moves to Status, with no box"   "0|1" "$(shown "$MAIN_GETSTARTED_ID")|$(shown "$MAIN_STATUS_ID")"
check "  and the restore files are not asked for" "0" "$(fake_log | /usr/bin/grep -c 'fetch-ipsw')"

section "the library: the steps as rows"
check "six rows of four fields"      "6|4" \
    "$( AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"; export AGENTVM_APP_AGENT_VM; . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1
        main_stage_rows "$UUID" | /usr/bin/awk -F'\t' '{ n++; f = NF } END { print n "|" f }' )"
check "a step that says nothing has a dash for its fact, so that its button's field is not taken for it" "todo${TAB}-${TAB}0" \
    "$( unset AGENTVM_APP_AGENT_VM; . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1
        printf '127\nagent-vm is not installed.\ninstalled\n/x/agent-vm\n' > "$TMPDIR/AgentVM/$UUID/agentvm"
        main_stage_rows "$UUID" | /usr/bin/sed -n '4p' | /usr/bin/cut -f2-4 )"
check "a reason that is missing is a dash too, and the fields stay where they are" "failed${TAB}-${TAB}0" \
    "$( unset AGENTVM_APP_AGENT_VM; . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1
        printf '127\n\ntest\n/x/agent-vm\n' > "$TMPDIR/AgentVM/$UUID/agentvm"
        main_stage_rows "$UUID" | /usr/bin/sed -n '1p' | /usr/bin/cut -f2-4 )"
check "names beyond three are counted" "a, b, c, and 2 more|a and b|a" \
    "$( . "$APP_SCRIPTS/lib.agentvm.main.sh" >/dev/null 2>&1
        printf '%s|%s|%s\n' "$(main_some_names "$(printf 'a\nb\nc\nd\ne\n')")" "$(main_some_names "$(printf 'a\nb\n')")" "$(main_some_names a)" )"

section "nothing went wrong in the harness"
check "no write to a view no window has" "" "$(ui_unknown_writes)"
check "no table had its rows replaced by a value" "" "$(ui_suspect_writes)"
check "no harness errors"            "" "$(ui_errors)"

omctest_end
