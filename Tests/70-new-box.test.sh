#!/bin/sh
# Tests/70-new-box.test.sh - the New Box window: the library functions under it (the agents that
# come with agent-vm and the hosts they need, the arguments of `box create` and their checks),
# the two buttons of the main window that open it, one window at a time and only when this run of
# the app asked for it, its four steps with what each keeps and refuses, and Create: the box
# made with the command line shown, the job that starts it, and the main window showing it.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json, the packs
# from fixtures/agentvm/packs.json, and the agents from fixtures/agents.json (made by hand: three
# agents as agent-vm's own, and three that test what is left out).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.newbox.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_NEW_BOX_ID" ] && [ -n "$MAIN_IMAGE_BOX_ID" ] && [ -n "$NBOX_HEADER_ID" ] \
    && [ -n "$NBOX_IMAGES_ID" ] && [ -n "$NBOX_IMAGE_NOTE_ID" ] && [ -n "$NBOX_ACCESS_ID" ] && [ -n "$NBOX_AGENTS_TEXT_ID" ] \
    && [ -n "$NBOX_MODE_ID" ] && [ -n "$NBOX_MODE_NOTE_ID" ] && [ -n "$NBOX_PACKS_ID" ] && [ -n "$NBOX_PUBLIC_ID" ] \
    && [ -n "$NBOX_PUBLIC_SYMBOL_ID" ] && [ -n "$NBOX_HOSTS_ID" ] && [ -n "$NBOX_HOST_FIELD_ID" ] && [ -n "$NBOX_ADD_ID" ] \
    && [ -n "$NBOX_REMOVE_ID" ] && [ -n "$NBOX_NAME_ID" ] && [ -n "$NBOX_CPUS_ID" ] && [ -n "$NBOX_MEMORY_ID" ] && [ -n "$NBOX_START_ID" ] \
    && [ -n "$NBOX_SIZE_TEXT_ID" ] && [ -n "$NBOX_SUMMARY_ID" ] && [ -n "$NBOX_COMMAND_ID" ] && [ -n "$NBOX_ADVICE_ID" ] \
    && [ -n "$NBOX_NOTE_ID" ] && [ -n "$NBOX_BACK_ID" ] && [ -n "$NBOX_NEXT_ID" ] && [ -n "$NBOX_CREATE_ID" ] || {
    printf '70-new-box: no view ids imported from the libraries\n' >&2
    exit 1
}
# The frame: the rail's marks and the panels are the window's base plus 10 and 40 (lib.agentvm.wizard.sh).
FRAME="$(/usr/bin/sed -n 's/^NBOX_BASE=\([0-9][0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.newbox.sh")"
[ -n "$FRAME" ] || {
    printf '70-new-box: the frame base was not found in the library\n' >&2
    exit 1
}
RAIL=$((FRAME + 10))
PANEL=$((FRAME + 40))

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_AGENTS="$OMCTEST_FIXTURES/agents.json"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_AGENTS AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?70-new-box: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-new-box-$$"
OTHER_UUID="OMCTEST-other-new-box-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
FIRST="20260930-120001-000001"
ALLOWLIST_TEXT="Only what the packs and hosts below allow."

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# store <jq edit of status-variety.json>  ->  the fake answers status with that.
store() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
}

request() {
    "$PB" agentvm_open_request_newbox get
}

registered() {
    "$PB" agentvm_window_newbox_window get
}

# kept <name>  ->  one value the window keeps.
kept() {
    "$PB" "agentvm_${1}_$UUID" get
}

# rules  ->  the rules the window keeps, on one line.
rules() {
    /bin/cat "$TMPDIR/AgentVM/$UUID/rules" 2>/dev/null | /usr/bin/paste -sd ' ' -
}

# open_new [image] [uuid]  ->  the window opened the way the main window opens it: the request and
# the image handed over, then the window's init handler, in a window of its own.
open_new() {
    "$PB" agentvm_open_request_newbox set "$APP_PID newbox:window"
    "$PB" agentvm_newbox_from set "$APP_PID ${1:-}"
    in_window "${2:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.newbox
    omc_run AgentVM.newbox.init
}

# pick <name>  ->  that row selected in the image table, as the click and the next ones see it.
pick() {
    omc_table_cell "$NBOX_IMAGES_ID" 5 "$1"
    omc_table_cell "$NBOX_IMAGES_ID" 1 "$1"
    omc_trigger "$NBOX_IMAGES_ID"
    omc_run AgentVM.newbox.image
}

# pack <name>  ->  a click on that pack's cell: the grid reports the row's 0-based index.
pack() {
    omc_trigger "$NBOX_PACKS_ID" "$(/usr/bin/jq --arg n "$1" 'map(.name) | index($n)' "$FIXTURES_AGENTVM/packs.json")"
    omc_run AgentVM.newbox.pack
}

# add <text>  ->  the text typed into the host field, and Add.
add() {
    omc_control "$NBOX_HOST_FIELD_ID" "$1"
    omc_trigger "$NBOX_ADD_ID"
    omc_run AgentVM.newbox.add
}

# sizes <name> <cpus> <memory> <start: true|false>  ->  the fields of step 3 as the user left them.
sizes() {
    omc_control "$NBOX_NAME_ID" "$1"
    omc_control "$NBOX_CPUS_ID" "$2"
    omc_control "$NBOX_MEMORY_ID" "$3"
    omc_control "$NBOX_START_ID" "$4"
}

next() { omc_run AgentVM.newbox.next; }
back() { omc_run AgentVM.newbox.back; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

shown() {
    [ "$(ui_visible "$1")" = "0" ] && echo 0 || echo 1
}

# step_shown  ->  the header, the panel shown, and the rail's marks (d done, n now, t to do).
step_shown() {
    local _n=0 _panels="" _marks=""
    while [ "$_n" -lt 4 ]; do
        _n=$((_n + 1))
        [ "$(ui_visible $((PANEL + _n)))" = "1" ] && _panels="$_panels$_n"
        case "$(ui_visible $((RAIL + _n)))$(ui_visible $((RAIL + 10 + _n)))$(ui_visible $((RAIL + 20 + _n)))" in
            100) _marks="${_marks}t" ;;
            010) _marks="${_marks}n" ;;
            001) _marks="${_marks}d" ;;
            *)   _marks="${_marks}?" ;;
        esac
    done
    printf '%s|%s|%s\n' "$(ui_value "$NBOX_HEADER_ID")" "$_panels" "$_marks"
}

note() { ui_value "$NBOX_NOTE_ID"; }

# created  ->  the boxes agent-vm was asked to make. started  ->  the jobs it was asked to start.
created() {
    fake_log | /usr/bin/grep -c '^box create'
}
started() {
    fake_log | /usr/bin/grep -c '^job start'
}

# create_args  ->  the arguments of the last `box create`, as the fake logged them, without --json.
create_args() {
    fake_log | /usr/bin/sed -n 's/^box create \(.*\) --json$/\1/p' | /usr/bin/tail -1
}

select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

fake_reset
store '.'
"$PB" agentvm_window_newbox_window set ""
"$PB" agentvm_open_request_newbox set ""
"$PB" agentvm_open_request_access set ""
"$PB" agentvm_newbox_from set ""

# -----------------------------------------------------------------------------------------------
section "the library: the agents that come with agent-vm"
check "the tests' seam"              "$AGENTVM_APP_AGENTS" "$(with_fake agentvm_agents_file)"
check "id, name and the rules each needs; an id that is not one is left out; none is a dash" \
    "claude${TAB}Claude Code${TAB}pack:anthropic|codex${TAB}Codex${TAB}pack:openai|opencode${TAB}opencode${TAB}opencode.ai,Models.OpenCode.ai.|node${TAB}A Rule That Is None${TAB}--net,10.0.0.1,pack:npm|quiet${TAB}No Hosts${TAB}-" \
    "$(with_fake agentvm_agent_rows | /usr/bin/paste -sd '|' -)"
INSTALLED="$OMCTEST_WORK/installed-box"
/bin/mkdir -p "$INSTALLED/versions/9.9.9" "$INSTALLED/bin"
/bin/cp "$FAKE_AGENTVM" "$INSTALLED/versions/9.9.9/agent-vm"
/bin/cp "$AGENTVM_APP_AGENTS" "$INSTALLED/versions/9.9.9/agents.json"
/bin/ln -s "$INSTALLED/versions/9.9.9/agent-vm" "$INSTALLED/bin/agent-vm"
check "beside the real executable, the link resolved" "$(/bin/realpath "$INSTALLED/versions/9.9.9")/agents.json" \
    "$( unset AGENTVM_APP_AGENTS; AGENTVM_APP_AGENT_VM="$INSTALLED/bin/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_agents_file )"
TREE="$OMCTEST_WORK/tree-box"
/bin/mkdir -p "$TREE/.build/release" "$TREE/Resources"
/bin/cp "$FAKE_AGENTVM" "$TREE/.build/release/agent-vm"
/bin/cp "$AGENTVM_APP_AGENTS" "$TREE/Resources/agents.json"
check "a developer's build: not found without Package.swift above it" "" \
    "$( unset AGENTVM_APP_AGENTS; AGENTVM_APP_AGENT_VM="$TREE/.build/release/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_agents_file )"
: > "$TREE/Package.swift"
check "  found in the working tree's Resources" "$(/bin/realpath "$TREE")/Resources/agents.json" \
    "$( unset AGENTVM_APP_AGENTS; AGENTVM_APP_AGENT_VM="$TREE/.build/release/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_agents_file )"
check "no file: no rows"             "" "$( AGENTVM_APP_AGENTS="$OMCTEST_WORK/none.json"; export AGENTVM_APP_AGENTS; with_fake agentvm_agent_rows )"
printf 'not json\n' > "$OMCTEST_WORK/broken.json"
check "a file that is not JSON: no rows" "" "$( AGENTVM_APP_AGENTS="$OMCTEST_WORK/broken.json"; export AGENTVM_APP_AGENTS; with_fake agentvm_agent_rows )"

section "the library: box create"
: > "$FAKE_AGENTVM_DIR/log"
printf '%s\n' work --image dev --cpus 6 --memory-gb 12 --net off --allow pack:github --allow '*.example.com' | with_fake agentvm_box_create
check "a name, an image and options: made" "0" "$?"
check "the arguments as given, one each, and --json" "box create work --image dev --cpus 6 --memory-gb 12 --net off --allow pack:github --allow *.example.com --json" \
    "$(fake_log | /usr/bin/tail -1)"
check "the fake holds the box, stopped, with what was asked" "stopped|dev|6|12|off|pack:github *.example.com" \
    "$(/usr/bin/jq -r '.boxes[] | select(.box.name == "work") | [.state, .box.image, .box.cpuCount, (.box.memoryBytes / 1073741824), .box.network.mode, (.box.network.allow | join(" "))] | join("|")' "$FAKE_AGENTVM_DIR/status.json")"
store '.'
refused() {
    : > "$FAKE_AGENTVM_DIR/log"
    printf '%s\n' "$@" | with_fake agentvm_box_create
    printf '%s|%s\n' "$?" "$(fake_log)"
}
check "a name that is none"          "2|" "$(refused --rm --image dev)"
check "no image"                     "2|" "$(refused work --cpus 4)"
check "an image that is not a name"  "2|" "$(refused work --image '../dev')"
check "an option that is not one of them" "2|" "$(refused work --image dev --disposable yes)"
check "an option without its value"  "2|" "$(refused work --image dev --cpus)"
check "processors that are not a number" "2|" "$(refused work --image dev --cpus 4x)"
check "a mode that is none"          "2|" "$(refused work --image dev --net wide)"
check "a rule that begins like an option" "2|" "$(refused work --image dev --allow --net)"
check "a rule with a space in it"    "2|" "$(refused work --image dev --allow 'a b')"
check "the reason is kept for the alert" "\"--disposable yes\" is not something this app passes to box create." \
    "$( AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"; export AGENTVM_APP_AGENT_VM; . "$APP_SCRIPTS/lib.agentvm.sh"
        printf '%s\n' work --image dev --disposable yes | agentvm_box_create >/dev/null; agentvm_last_error 2 )"
printf '%s\n' s3 --image dev | with_fake agentvm_box_create
check "agent-vm's own refusal (a name that is taken) is its status" "1" "$?"

# -----------------------------------------------------------------------------------------------
section "the main window's two buttons"
fake_reset
store '.'
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
omc_trigger "$MAIN_NEW_BOX_ID"
omc_run AgentVM.main.box.new
check "the plus button asks for the New Box window" "1" "$(chain_asked AgentVM.newbox)"
check "  with a request of this run of the app, and no image handed over" "$APP_PID newbox:window|$APP_PID " "$(request)|$("$PB" agentvm_newbox_from get)"
chains_reset
"$PB" agentvm_open_request_newbox set ""
omc_trigger "$MAIN_IMAGE_BOX_ID"
omc_run AgentVM.main.box.new
check "New Box from It... with no image selected opens nothing" "0|" "$(chain_asked AgentVM.newbox)|$(request)"
select_image latest-test
check "no box from a failed image"   "0" "$(enabled "$MAIN_IMAGE_BOX_ID")"
select_image dev-agents
check "one from a ready image"       "1" "$(enabled "$MAIN_IMAGE_BOX_ID")"
omc_trigger "$MAIN_IMAGE_BOX_ID"
omc_run AgentVM.main.box.new
check "it asks for the window, and hands the image over" "1|$APP_PID newbox:window|$APP_PID dev-agents" \
    "$(chain_asked AgentVM.newbox)|$(request)|$("$PB" agentvm_newbox_from get)"

section "the window opens on step 1"
: > "$FAKE_AGENTVM_DIR/log"
open_new
check_status "the init handler exits cleanly" 0
check "takes the request, and what was handed over, once" "|" "$(request)|$("$PB" agentvm_newbox_from get)"
check "becomes the New Box window"   "$APP_PID $UUID|1" "$(registered)|$(kept newbox)"
check "asks agent-vm which it is, reads its packs and status" "--version|box packs --json|status --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                    "New Box" "$(ui_title)"
check "step 1 of 4: its panel, the first mark is now" "Step 1 of 4 - Image|1|nttt" "$(step_shown)"
check "Back is off, Continue is there, Create is not" "0|1|0" "$(enabled "$NBOX_BACK_ID")|$(shown "$NBOX_NEXT_ID")|$(shown "$NBOX_CREATE_ID")"
check "the ready images; the failed image is not listed" \
    "dev|dev-acp|dev-agents|dev-node|dev-xcode|dev-xcode-ios" "$(ui_rows "$NBOX_IMAGES_ID" | col 1 | /usr/bin/paste -sd '|' -)"
check "an image: its macOS, what it holds, its state, and its key" \
    "dev-agents${TAB}27.0${TAB}Claude Code, Codex and opencode${TAB}ready${TAB}dev-agents" "$(ui_rows "$NBOX_IMAGES_ID" | row_named dev-agents)"
check "one without Full Disk Access says so" "no Full Disk Access" "$(ui_rows "$NBOX_IMAGES_ID" | row_named dev-node | col 4)"
check "nothing is selected: no line under the table, Set Up... off" "|0" "$(ui_value "$NBOX_IMAGE_NOTE_ID")|$(enabled "$NBOX_ACCESS_ID")"
check "nothing writes to a view the window does not have" "" "$(ui_unknown_writes)"
next
check "Continue with nothing selected: the step stays, and says why" "Step 1 of 4 - Image|1|nttt|Choose the image the box is made from." "$(step_shown)|$(note)"

section "a second request, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_trigger "$MAIN_NEW_BOX_ID"
omc_run AgentVM.main.box.new
check "the plus button opens no second window" "0" "$(chain_asked AgentVM.newbox)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
"$PB" agentvm_open_request_newbox set "$APP_PID newbox:window"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.newbox
omc_run AgentVM.newbox.init
check "a second window: the first stays the New Box window, the second closes" "$APP_PID $UUID|1|" \
    "$(registered)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$("$PB" "agentvm_newbox_$OTHER_UUID" get)"
in_window "$UUID"
omc_run AgentVM.newbox.close
check "closing: there is no New Box window, and it keeps nothing" "||" "$(registered)|$(kept newbox)|$(kept image)"
check_absent "  nor a cache folder"   "$TMPDIR/AgentVM/$UUID"
for bad in "" "$APP_PID newimage:window" "1 newbox:window" "$APP_PID newbox:dev"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_newbox set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.newbox
    omc_run AgentVM.newbox.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "|" "$(registered)|$("$PB" "agentvm_newbox_$OTHER_UUID" get)"
done
"$PB" agentvm_open_request_newbox set "$APP_PID newbox:window"
"$PB" agentvm_newbox_from set "1 dev-agents"
in_window "$UUID"
ui_reset
omc_control_defaults AgentVM.newbox
omc_run AgentVM.newbox.init
check "an image handed over by another run of the app is not taken: step 1, no image" "Step 1 of 4 - Image|" "$(ui_value "$NBOX_HEADER_ID")|$(kept image)"
omc_run AgentVM.newbox.close

section "handlers in a window that is not a New Box window"
in_window "$OTHER_UUID"
ui_reset
# Everything a New Box window keeps is there but its mark, and each handler finds the step it acts
# on: so one that did not ask whether the window is a New Box window would act.
"$PB" "agentvm_image_$OTHER_UUID" set "dev"
"$PB" "agentvm_picked_$OTHER_UUID" set "dev-node"
"$PB" "agentvm_name_$OTHER_UUID" set "planted"
"$PB" "agentvm_cpus_$OTHER_UUID" set "4"
"$PB" "agentvm_memory_$OTHER_UUID" set "8"
/bin/mkdir -p "$TMPDIR/AgentVM/$OTHER_UUID"
printf '0\n%s\ntest\n%s\n' "$(lib_value AGENTVM_MIN_VERSION)" "$FAKE_AGENTVM" > "$TMPDIR/AgentVM/$OTHER_UUID/agentvm"
lib agentvm_status_build_rows < "$FAKE_AGENTVM_DIR/status.json" > "$TMPDIR/AgentVM/$OTHER_UUID/build.tsv"
lib agentvm_packs_rows < "$FIXTURES_AGENTVM/packs.json" > "$TMPDIR/AgentVM/$OTHER_UUID/packs.tsv"
printf 'pack:npm\nexample.com\n' > "$TMPDIR/AgentVM/$OTHER_UUID/rules"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_table_cell "$NBOX_IMAGES_ID" 5 dev
omc_table_cell "$NBOX_IMAGES_ID" 1 dev
omc_table_cell "$NBOX_HOSTS_ID" 1 example.com
omc_control "$NBOX_HOST_FIELD_ID" "other.example.com"
omc_control "$NBOX_MODE_ID" "3"
for planted in "next 1" "image 1" "access 1" "mode 2" "pack 2" "public 2" "add 2" "remove 2" "host.selected 2" "back 3" "create 4" "activated 4" "cancel 4"; do
    "$PB" "agentvm_step_$OTHER_UUID" set "${planted#* }"
    omc_trigger "$NBOX_PACKS_ID" 0
    omc_run "AgentVM.newbox.${planted% *}"
    check "${planted% *}: agent-vm is not run, nothing is written to the window, nothing is kept or chained" "|0|pack:npm example.com|dev-node||0" \
        "$(fake_log)|$(ui_calls "$OTHER_UUID")|$(/usr/bin/paste -sd ' ' - < "$TMPDIR/AgentVM/$OTHER_UUID/rules")|$("$PB" "agentvm_picked_$OTHER_UUID" get)|$("$PB" "agentvm_mode_$OTHER_UUID" get)|$(chain_asked AgentVM.access)"
done
for key in step image picked name cpus memory; do
    "$PB" "agentvm_${key}_$OTHER_UUID" set ""
done
/bin/rm -rf "$TMPDIR/AgentVM/$OTHER_UUID"
omc_reset_controls

# -----------------------------------------------------------------------------------------------
section "step 1: the image"
fake_reset
store '(.images[] | select(.name == "dev-acp")).updating = true'
open_new
pick dev-agents
check "selecting an image: what a box made from it gets, and its agents" \
    "Image dev-agents: 4 CPUs, 8 GB of memory, Full Disk Access granted. Agents in it: Claude Code, Codex and opencode.|0|dev-agents" \
    "$(ui_value "$NBOX_IMAGE_NOTE_ID")|$(enabled "$NBOX_ACCESS_ID")|$(kept picked)"
pick dev
check "an image with no agent"       "Image dev: 4 CPUs, 8 GB of memory, Full Disk Access granted." "$(ui_value "$NBOX_IMAGE_NOTE_ID")"
pick dev-acp
check "an image another command is changing" "Another command is changing image dev-acp. A box can be made from it when that has ended.|0" \
    "$(ui_value "$NBOX_IMAGE_NOTE_ID")|$(enabled "$NBOX_ACCESS_ID")"
next
check "  Continue: the step stays, and says why" "Step 1 of 4 - Image|Another command is changing image dev-acp. A box can be made from it when that has ended.|" \
    "$(ui_value "$NBOX_HEADER_ID")|$(note)|$(kept image)"
pick dev-node
check "an image without Full Disk Access: what that means, and Set Up... is on" \
    "Image dev-node has no Full Disk Access yet. In a box made from it now, a program that opens Desktop, Documents or Downloads waits on a question nobody sees. Set Up... grants it first, once, on the image.|1" \
    "$(ui_value "$NBOX_IMAGE_NOTE_ID")|$(enabled "$NBOX_ACCESS_ID")"
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_trigger "$NBOX_ACCESS_ID"
omc_run AgentVM.newbox.access
check "Set Up... asks for that image's guide, and starts nothing" "1|$APP_PID access:dev-node|" \
    "$(chain_asked AgentVM.access)|$("$PB" agentvm_open_request_access get)|$(fake_log)"
"$PB" agentvm_open_request_access set ""
# The grant was made in the guide, and the window comes back to the front.
store '(.images[] | select(.name == "dev-node")).needs = []'
omc_run AgentVM.newbox.activated
check "coming back: the table says ready, the row (the fourth) is selected again, Set Up... is off" "ready|3|0" \
    "$(ui_rows "$NBOX_IMAGES_ID" | row_named dev-node | col 4)|$(ui_selection "$NBOX_IMAGES_ID")|$(enabled "$NBOX_ACCESS_ID")"
omc_table_cell "$NBOX_IMAGES_ID" 5 "--rm"
omc_table_cell "$NBOX_IMAGES_ID" 1 "--rm"
omc_trigger "$NBOX_IMAGES_ID"
omc_run AgentVM.newbox.image
check "a key that is not a name is not an image" "|" "$(kept picked)|$(ui_value "$NBOX_IMAGE_NOTE_ID")"
omc_table_cell "$NBOX_IMAGES_ID" 5 ""
omc_table_cell "$NBOX_IMAGES_ID" 1 "latest-test"
omc_trigger "$NBOX_IMAGES_ID"
omc_run AgentVM.newbox.image
check "a row found by its name: an image that is not ready" "latest-test|Image latest-test is not ready, so no box can be made from it." "$(kept picked)|$(ui_value "$NBOX_IMAGE_NOTE_ID")"
next
check "  Continue: the step stays"   "Step 1 of 4 - Image|Image latest-test is not ready, so no box can be made from it." "$(ui_value "$NBOX_HEADER_ID")|$(note)"
pick gone
next
check "an image that is not listed"  "Step 1 of 4 - Image|Image gone is not there any more. Choose another." "$(ui_value "$NBOX_HEADER_ID")|$(note)"
pick dev-agents
# The click on Continue did not carry the selection (a row the program selected): the row last
# picked is taken.
omc_table_cell "$NBOX_IMAGES_ID" 5 ""
omc_table_cell "$NBOX_IMAGES_ID" 1 ""
: > "$FAKE_AGENTVM_DIR/log"
next
check "Continue: status is read again, the image is kept, step 2" "status --json|dev-agents|Step 2 of 4 - Network|2|dntt|" \
    "$(fake_log | /usr/bin/paste -sd '|' -)|$(kept image)|$(step_shown)|$(note)"

# -----------------------------------------------------------------------------------------------
section "step 2: the network"
check "what the image's agents need is allowed already, each rule as agent-vm reads it" "pack:anthropic pack:openai opencode.ai models.opencode.ai" "$(rules)"
check "the line above says whose"    "What the box may reach. Image dev-agents holds Claude Code, Codex and opencode: what they need is allowed already." "$(ui_value "$NBOX_AGENTS_TEXT_ID")"
check "the mode: allowlist, and what it lets through" "1|$ALLOWLIST_TEXT" "$(ui_value "$NBOX_MODE_ID")|$(ui_value "$NBOX_MODE_NOTE_ID")"
check "the packs, in agent-vm's order" "anthropic|anthropic-connectors|apple-updates|github|homebrew|npm|openai|pypi|swiftpm" \
    "$(ui_rows "$NBOX_PACKS_ID" | col 2 | /usr/bin/paste -sd '|' -)"
check "the agents' packs are ticked, the others not" "checkmark.square.fill|square|checkmark.square.fill" \
    "$(ui_rows "$NBOX_PACKS_ID" | /usr/bin/awk -F'\t' '$2 == "anthropic" || $2 == "github" || $2 == "openai" { print $1 }' | /usr/bin/paste -sd '|' -)"
check "a pack's description is its help" "The npm and Yarn registries." "$(ui_rows "$NBOX_PACKS_ID" | /usr/bin/awk -F'\t' '$2 == "npm" { print $3 }')"
check "public is not allowed"        "square" "$(ui_prop "$NBOX_PUBLIC_SYMBOL_ID" systemName)"
check "the other hosts, and who needs them" "opencode.ai${TAB}for opencode|models.opencode.ai${TAB}for opencode" "$(ui_rows "$NBOX_HOSTS_ID" | /usr/bin/paste -sd '|' -)"
check "Remove is off until a host is selected" "0" "$(enabled "$NBOX_REMOVE_ID")"
pack github
check "a click on a pack ticks it"   "checkmark.square.fill|pack:anthropic pack:openai opencode.ai models.opencode.ai pack:github" \
    "$(ui_rows "$NBOX_PACKS_ID" | /usr/bin/awk -F'\t' '$2 == "github" { print $1 }')|$(rules)"
pack anthropic
check "a click on a ticked pack unticks it" "square|pack:openai opencode.ai models.opencode.ai pack:github" \
    "$(ui_rows "$NBOX_PACKS_ID" | /usr/bin/awk -F'\t' '$2 == "anthropic" { print $1 }')|$(rules)"
omc_trigger "$NBOX_PACKS_ID" 99
omc_run AgentVM.newbox.pack
omc_trigger "$NBOX_PACKS_ID" "x"
omc_run AgentVM.newbox.pack
check "a click that names no pack changes nothing" "pack:openai opencode.ai models.opencode.ai pack:github" "$(rules)"
omc_trigger "$NBOX_PUBLIC_ID"
omc_run AgentVM.newbox.public
check "Any public host name: ticked" "checkmark.square.fill|pack:openai opencode.ai models.opencode.ai pack:github public" "$(ui_prop "$NBOX_PUBLIC_SYMBOL_ID" systemName)|$(rules)"
omc_run AgentVM.newbox.public
check "  and unticked"               "square|pack:openai opencode.ai models.opencode.ai pack:github" "$(ui_prop "$NBOX_PUBLIC_SYMBOL_ID" systemName)|$(rules)"
alerts_reset
add "  Registry.Example.COM.  "
check "Add: the rule as agent-vm reads it, and the field is emptied" "pack:openai opencode.ai models.opencode.ai pack:github registry.example.com||" \
    "$(rules)|$(ui_value "$NBOX_HOST_FIELD_ID")|$(ui_alert_title)"
add "*.example.org:8443"
check "subdomains and a port"        "*.example.org:8443${TAB}" "$(ui_rows "$NBOX_HOSTS_ID" | /usr/bin/tail -1)"
add "registry.example.com"
check "a rule that is there already is there once" "1" "$(ui_rows "$NBOX_HOSTS_ID" | /usr/bin/grep -c '^registry.example.com')"
for bad in "10.0.0.1" "--net" "a b" "http://example.com/x"; do
    alerts_reset
    before="$(rules)"
    add "$bad"
    check "[$bad] is not a rule: an alert, and nothing is added" "\"$bad\" is not a network rule|$before" "$(ui_alert_title)|$(rules)"
done
add ""
check "Add with an empty field does nothing" "$before" "$(rules)"
omc_table_cell "$NBOX_HOSTS_ID" 1 "registry.example.com"
omc_trigger "$NBOX_HOSTS_ID"
omc_run AgentVM.newbox.host.selected
check "a host selected: Remove is on" "1" "$(enabled "$NBOX_REMOVE_ID")"
omc_trigger "$NBOX_REMOVE_ID"
omc_run AgentVM.newbox.remove
check "Remove: the rule goes, and Remove is off again" "pack:openai opencode.ai models.opencode.ai pack:github *.example.org:8443|0" "$(rules)|$(enabled "$NBOX_REMOVE_ID")"
omc_table_cell "$NBOX_HOSTS_ID" 1 ""
omc_run AgentVM.newbox.remove
check "Remove with nothing selected does nothing" "pack:openai opencode.ai models.opencode.ai pack:github *.example.org:8443" "$(rules)"
omc_control "$NBOX_MODE_ID" "3"
omc_trigger "$NBOX_MODE_ID"
omc_run AgentVM.newbox.mode
check "the mode picked: open, and what that means" "open|Any host, your local network included, and no connection is logged; the rules are kept for later." \
    "$(kept mode)|$(ui_value "$NBOX_MODE_NOTE_ID")"
omc_control "$NBOX_MODE_ID" "7"
omc_run AgentVM.newbox.mode
check "a value that is no mode changes nothing" "open" "$(kept mode)"
omc_control "$NBOX_MODE_ID" "1"
omc_run AgentVM.newbox.mode
check "back to allowlist"            "allowlist|$ALLOWLIST_TEXT" "$(kept mode)|$(ui_value "$NBOX_MODE_NOTE_ID")"

section "another image: its agents' rules replace the last image's, the user's stay"
back
check "Back: step 1, with the image (the third row) selected again" "Step 1 of 4 - Image|1|nttt|2" "$(step_shown)|$(ui_selection "$NBOX_IMAGES_ID")"
pick dev-node
next
check "the rules: the old agents' are gone, the new one's first, what is not a rule left out, the user's kept" \
    "pack:npm pack:github *.example.org:8443" "$(rules)"
check "the line above: an agent found by a word of the description, not of its advice" \
    "What the box may reach. Image dev-node holds A Rule That Is None: what they need is allowed already." "$(ui_value "$NBOX_AGENTS_TEXT_ID")"
back
pick dev
next
check "an image with no agent: only the user's rules" "pack:github *.example.org:8443|What the box may reach. No agent is known in image dev, so nothing is allowed yet." \
    "$(rules)|$(ui_value "$NBOX_AGENTS_TEXT_ID")"
back
pick dev-acp
store '.'
next
check "an agent named in a recipe's description only as a need is not held" "pack:anthropic pack:openai opencode.ai models.opencode.ai pack:github *.example.org:8443" "$(rules)"

# -----------------------------------------------------------------------------------------------
section "step 3: name and size"
next
check "step 3"                       "Step 3 of 4 - Name and size|3|ddnt" "$(step_shown)"
check "a free name, and the image's sizes" "work|4|8" "$(ui_value "$NBOX_NAME_ID")|$(ui_value "$NBOX_CPUS_ID")|$(ui_value "$NBOX_MEMORY_ID")"
check "the line under them"          "These start as image dev-acp has them. The disk of a box is the image's, and takes room only for what the box writes." "$(ui_value "$NBOX_SIZE_TEXT_ID")"
check "the start checkbox is not set by the window" "0" "$(ui_calls "${UUID}${TAB}${NBOX_START_ID}")"
sizes "" 4 8 true
next
check "no name"                      "Step 3 of 4 - Name and size|Give the box a name." "$(ui_value "$NBOX_HEADER_ID")|$(note)"
sizes "My Box" 4 8 true
next
check "a name that cannot be one"    "\"My Box\" cannot be a name: lower-case letters, digits, \".\", \"_\" and \"-\", starting with a letter or a digit, at most 63 characters." "$(note)"
sizes "s3" 4 8 true
next
check "a name that is taken"         "A box named s3 is there already." "$(note)"
sizes "work" 0 8 true
next
check "processors that are not a number" "Processors: a whole number from 1 to 256." "$(note)"
sizes "work" 300 8 true
next
check "more processors than agent-vm takes" "Processors: a whole number from 1 to 256." "$(note)"
sizes "work" 4 "8 GB" true
next
check "memory that is not a number"  "Memory: a whole number of GB, from 1 to 4096." "$(note)"
sizes "  tools  " 6 12 true
next
check "a name with spaces around it, other sizes: step 4" "Step 4 of 4 - Check|4|dddn|tools|6|12|true" \
    "$(step_shown)|$(kept name)|$(kept cpus)|$(kept memory)|$(kept start)"

# -----------------------------------------------------------------------------------------------
section "step 4: check"
check "Create is there, Continue is not" "1|0" "$(shown "$NBOX_CREATE_ID")|$(shown "$NBOX_NEXT_ID")"
check "what is made"                 "Box tools, a copy of image dev-acp (macOS 27.0).|6 CPUs, 12 GB of memory.|Network: only pack:anthropic, pack:openai, opencode.ai, models.opencode.ai, pack:github and *.example.org:8443.|It is started once made, and runs until it is stopped." \
    "$(ui_value "$NBOX_SUMMARY_ID" | /usr/bin/paste -sd '|' -)"
check "the advice"                   "The box is kept until it is deleted. What is installed or written in it stays in the box, and its network can be changed later in its Network window." "$(ui_value "$NBOX_ADVICE_ID")"
EXPECTED="tools --image dev-acp --cpus 6 --memory-gb 12 --allow pack:anthropic --allow pack:openai --allow opencode.ai --allow models.opencode.ai --allow pack:github --allow *.example.org:8443"
check "the commands: the sizes that are not the image's, every rule, and the start" \
    "agent-vm box create tools --image dev-acp --cpus 6 --memory-gb 12 --allow pack:anthropic --allow pack:openai --allow opencode.ai --allow models.opencode.ai --allow pack:github --allow '*.example.org:8443'|agent-vm box start tools" \
    "$(ui_value "$NBOX_COMMAND_ID" | /usr/bin/paste -sd '|' -)"
check "nothing stands in the way"    "|1" "$(note)|$(enabled "$NBOX_CREATE_ID")"
# A rule with a star is a pattern to the shell: run from a folder whose files match it, nothing
# that lists the rules may take the files' names for rules.
FILES="$OMCTEST_WORK/folder-with-files"
/bin/mkdir -p "$FILES"
: > "$FILES/first.example.org:8443"
: > "$FILES/second.example.org:8443"
: > "$FILES/files.example.com"
check "from a folder with files a rule matches: the arguments are the rules, not the files" "$EXPECTED" \
    "$( cd "$FILES" && . "$APP_SCRIPTS/lib.agentvm.newbox.sh" && newbox_args "$UUID" | /usr/bin/paste -sd ' ' - )"
check "  and so is the network in words" "Network: only pack:anthropic, pack:openai, opencode.ai, models.opencode.ai, pack:github and *.example.org:8443." \
    "$( cd "$FILES" && . "$APP_SCRIPTS/lib.agentvm.newbox.sh" && newbox_network_text "$UUID" )"
STAR_UUID="OMCTEST-star-new-box-$$"
/bin/mkdir -p "$TMPDIR/AgentVM/$STAR_UUID"
printf 'dev\tready\tfalse\t27.0\t4\t8\t64\t-\tStar tools\t-\t-\t-\n' > "$TMPDIR/AgentVM/$STAR_UUID/build.tsv"
printf 'star\tStar\t*.example.com,pack:npm\n' > "$TMPDIR/AgentVM/$STAR_UUID/agents.tsv"
check "  and the rules an agent needs" "*.example.com${TAB}Star|pack:npm${TAB}Star" \
    "$( cd "$FILES" && . "$APP_SCRIPTS/lib.agentvm.newbox.sh" && newbox_agent_rule_rows "$STAR_UUID" dev | /usr/bin/paste -sd '|' - )"
/bin/rm -rf "$TMPDIR/AgentVM/$STAR_UUID"

section "what stands in the way"
store '.runningVMs.count = 2'
omc_run AgentVM.newbox.activated
check "no virtual machine slot is free, and the box is to be started: Create is off, and says why" \
    "2 of 2 virtual machines are running, so the box cannot be started now. Stop a box first, or go back and choose not to start it.|0" "$(note)|$(enabled "$NBOX_CREATE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check "  Create, clicked anyway, makes nothing" "0" "$(created)"
store '(.images[] | select(.name == "dev-acp")).updating = true'
omc_run AgentVM.newbox.activated
check "the image is being changed"   "Another command is changing image dev-acp. A box can be made from it when that has ended.|0" "$(note)|$(enabled "$NBOX_CREATE_ID")"
store '.boxes += [.boxes[0] | .box.name = "tools"]'
omc_run AgentVM.newbox.activated
check "the name was taken meanwhile" "A box named tools is there already.|0" "$(note)|$(enabled "$NBOX_CREATE_ID")"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-status"
omc_run AgentVM.newbox.activated
check "agent-vm cannot be read"      "agent-vm could not be read: the store is locked|0" "$(note)|$(enabled "$NBOX_CREATE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"
store '.'
omc_run AgentVM.newbox.activated
check "all clear again: Create is on" "|1" "$(note)|$(enabled "$NBOX_CREATE_ID")"

section "Create"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check "a second Create while the first is worked on: agent-vm is not run, nothing is made" "|0" "$(fake_log)|$(created)"
back
check "  nor does Back act"          "4" "$(kept step)"
"$PB" "agentvm_busy_$UUID" set ""
printf 'the disk is full\n' > "$FAKE_AGENTVM_DIR/fail-box-create"
alerts_before="$(ui_calls omc_present_alert)"
omc_run AgentVM.newbox.create
check "agent-vm refuses the box: an alert with its words, the window stays, no job is started" "1|Box tools was not made|the disk is full|0|0" \
    "$(( $(ui_calls omc_present_alert) - alerts_before ))|$(ui_alert_title)|$(ui_alert_message)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(started)"
check "  Create is on again, and can be clicked again" "1|" "$(enabled "$NBOX_CREATE_ID")|$(kept busy)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-create"
in_window "$MAIN_UUID"
omc_run AgentVM.main.activated
in_window "$UUID"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check_status "the handler exits cleanly" 0
check "status is read first, then the box is made, then its start is a job" "status --json|box create|job start" \
    "$(fake_log | /usr/bin/sed -n '1,3p' | /usr/bin/cut -d' ' -f1-2 | /usr/bin/paste -sd '|' -)"
check "one box, with the arguments the window listed" "1|$EXPECTED" "$(created)|$(create_args)"
check "the command line shown is the one run" "$(ui_value "$NBOX_COMMAND_ID" | /usr/bin/sed -n '1p')" \
    "agent-vm box create $(create_args | /usr/bin/tr ' ' '\n' | lib agentvm_args_text)"
check "one job, which starts the box, with no owner" "1|box start tools" \
    "$(started)|$(/usr/bin/jq -r '.[0].command | map(select(. != "--json")) | join(" ")' "$JOBS")"
check "the main window watches the job" "$FIRST" "$(/usr/bin/grep -x "$FIRST" "$TMPDIR/AgentVM/$MAIN_UUID/jobs-watched")"
check "  shows the box, on the Boxes tab, and comes to the front" "tools|0|1" \
    "$("$PB" "agentvm_box_$MAIN_UUID" get)|$(ui_value "$MAIN_STATUS_ID" "$MAIN_UUID")|$(ui_calls "${MAIN_UUID}${TAB}omc_window${TAB}omc_select")"
check "the window closes"            "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "no alert"                     "$alerts_before" "$(( $(ui_calls omc_present_alert) - 1 ))"
omc_run AgentVM.newbox.close

# -----------------------------------------------------------------------------------------------
section "from an image handed over, not started, another mode"
fake_reset
store '.runningVMs.count = 2'
in_window "$MAIN_UUID"
omc_run AgentVM.main.activated
open_new dev-node
check "the window opens on step 2, with the image chosen and its rules" "Step 2 of 4 - Network|2|dntt|dev-node|pack:npm" "$(step_shown)|$(kept image)|$(rules)"
check "  and the image is the row selected, should the user go back" "dev-node" "$(kept picked)"
omc_control "$NBOX_MODE_ID" "2"
omc_trigger "$NBOX_MODE_ID"
omc_run AgentVM.newbox.mode
check "the mode picked: off"         "off|No network: every connection is refused, whatever the rules say." "$(kept mode)|$(ui_value "$NBOX_MODE_NOTE_ID")"
next
check "a free name"                  "work" "$(ui_value "$NBOX_NAME_ID")"
sizes work 4 8 false
next
check "what is made"                 "Box work, a copy of image dev-node (macOS 27.0).|4 CPUs, 8 GB of memory.|Network: off. Every connection is refused.|Its rules (pack:npm) are kept for when the mode is allowlist.|It is not started." \
    "$(ui_value "$NBOX_SUMMARY_ID" | /usr/bin/paste -sd '|' -)"
check "an image without Full Disk Access: the advice says what that means for the box" \
    "Image dev-node has no Full Disk Access, so the box has none either: a program in it that opens Desktop, Documents or Downloads waits on a question nobody sees. Set Up... on the first step grants it; a box made before that gets it when it is recreated." \
    "$(ui_value "$NBOX_ADVICE_ID" | /usr/bin/sed -n '1p')"
check "the command: sizes that are the image's are left out, the mode is named, no start" "agent-vm box create work --image dev-node --net off --allow pack:npm" "$(ui_value "$NBOX_COMMAND_ID")"
check "a box that is not started needs no virtual machine slot" "|1" "$(note)|$(enabled "$NBOX_CREATE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check "Create: the box is made, and no job is started" "1|0|work --image dev-node --net off --allow pack:npm" "$(created)|$(started)|$(create_args)"
check "the main window shows it, and the window closes" "work|1" \
    "$("$PB" "agentvm_box_$MAIN_UUID" get)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
omc_run AgentVM.newbox.close

section "a box that is made, and cannot be started"
fake_reset
store '.'
open_new dev-agents
next
sizes work 4 8 true
next
printf 'the job cannot be recorded\n' > "$FAKE_AGENTVM_DIR/fail-job"
alerts_before="$(ui_calls omc_present_alert)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check "the box is made; the alert says it was not started, in agent-vm's words" "1|1|Box work was made, but not started|the job cannot be recorded" \
    "$(created)|$(( $(ui_calls omc_present_alert) - alerts_before ))|$(ui_alert_title)|$(ui_alert_message)"
check "  the window stays until its OK" "0" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  the alert's button runs the handler that closes" "1" "$(/usr/bin/grep -c 'OK::AgentVM.newbox.cancel' "$APP_SCRIPTS/AgentVM.newbox.create.sh")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job"
omc_run AgentVM.newbox.cancel
check "Cancel closes the window"     "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
omc_run AgentVM.newbox.close

section "a window that closes while agent-vm is read"
# An agent-vm that, asked for status, does what the window's close handler does meanwhile.
CLOSER="$OMCTEST_WORK/closing-agent-vm-box"
{
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "status" ]; then\n'
    printf '    "%s" "agentvm_newbox_%s" set ""\n' "$PB" "$UUID"
    printf '    /bin/rm -rf "%s"\n' "$TMPDIR/AgentVM/$UUID"
    printf 'fi\n'
    printf 'exec "%s" "$@"\n' "$FAKE_AGENTVM"
} > "$CLOSER"
/bin/chmod +x "$CLOSER"
fake_reset
store '.'
AGENTVM_APP_AGENT_VM="$CLOSER"
open_new dev-agents
check "guard: agent-vm was read, and the window's mark went meanwhile" "1|" "$(fake_log | /usr/bin/grep -c '^status')|$(kept newbox)"
check "on opening: nothing is painted, no step or image is kept" "|||" "$(ui_value "$NBOX_HEADER_ID")|$(kept step)|$(kept image)|$(kept busy)"
check_absent "  and no cache folder is left" "$TMPDIR/AgentVM/$UUID"
omc_run AgentVM.newbox.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
open_new
AGENTVM_APP_AGENT_VM="$CLOSER"
pick dev
next
check "at Continue on step 1: the step is not left, no image is kept, and no cache folder is left" "1||no" \
    "$(kept step)|$(kept image)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.newbox.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
open_new dev
next
sizes work 4 8 true
next
check "guard: the last step, and Create is on" "Step 4 of 4 - Check|1" "$(ui_value "$NBOX_HEADER_ID")|$(enabled "$NBOX_CREATE_ID")"
AGENTVM_APP_AGENT_VM="$CLOSER"
alerts_before="$(ui_calls omc_present_alert)"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newbox.create
check "at Create: status was read, no box is made, no job is started, no alert, and no cache folder is left" "1|0|0|0|no" \
    "$(fake_log | /usr/bin/grep -c '^status')|$(created)|$(started)|$(( $(ui_calls omc_present_alert) - alerts_before ))|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.newbox.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"

section "agent-vm cannot be used, or its packs cannot be read"
fake_reset
store '.'
printf '0.0.1\n' > "$FAKE_AGENTVM_DIR/version"
open_new
check "an agent-vm that is too old: the window says so, and lists nothing" "1|" "$([ -n "$(note)" ] && echo 1)|$(ui_rows "$NBOX_IMAGES_ID")"
check "  and asks it nothing more"   "--version" "$(fake_log | /usr/bin/paste -sd '|' -)"
omc_run AgentVM.newbox.close
fake_reset
store '.'
printf 'the packs file is broken\n' > "$FAKE_AGENTVM_DIR/fail-box-packs"
open_new dev-agents
check "packs that cannot be read: the step says why, and the agents' rules are there all the same" \
    "The packs could not be read: the packs file is broken|pack:anthropic pack:openai opencode.ai models.opencode.ai|" \
    "$(ui_value "$NBOX_AGENTS_TEXT_ID" | /usr/bin/sed -n '2p')|$(rules)|$(ui_rows "$NBOX_PACKS_ID")"
omc_run AgentVM.newbox.close

section "nothing went wrong in the harness"
check "no write to a view no window has" "" "$(ui_unknown_writes)"
check "no table had its rows replaced by a value" "" "$(ui_suspect_writes)"
check "no harness errors"            "" "$(ui_errors)"

omctest_end
