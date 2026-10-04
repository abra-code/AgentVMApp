#!/bin/sh
# Tests/60-new-image.test.sh - the New Image window: the library functions under it (what a build
# from an image needs to know, the restore files, the recipes that come with agent-vm and what
# they ask for, the arguments of `image create` and their checks), the two buttons of the main
# window that open it, one window at a time and only when this run of the app asked for it, its
# five steps with what each keeps and refuses, and Build: the job it starts, with the command
# line shown, the progress window, and the main window following the job at once.
#
# agent-vm is the fake: status from a jq edit of fixtures/agentvm/status-variety.json, the restore
# files from fixtures/agentvm/ipsw-list.json, and the recipes from fixtures/recipes (small copies
# of agent-vm's own, with their descriptions, inputs and parameters).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.newimage.sh"
[ -n "$MAIN_IMAGES_ID" ] && [ -n "$MAIN_NEW_IMAGE_ID" ] && [ -n "$MAIN_IMAGE_DERIVE_ID" ] && [ -n "$NEW_HEADER_ID" ] \
    && [ -n "$NEW_SOURCES_ID" ] && [ -n "$NEW_TOOLS_TEXT_ID" ] && [ -n "$NEW_OPTIONS_TEXT_ID" ] && [ -n "$NEW_NAME_ID" ] \
    && [ -n "$NEW_CPUS_ID" ] && [ -n "$NEW_MEMORY_ID" ] && [ -n "$NEW_DISK_ID" ] && [ -n "$NEW_SIZE_TEXT_ID" ] \
    && [ -n "$NEW_SUMMARY_ID" ] && [ -n "$NEW_COMMAND_ID" ] && [ -n "$NEW_ADVICE_ID" ] && [ -n "$NEW_NOTE_ID" ] \
    && [ -n "$NEW_BACK_ID" ] && [ -n "$NEW_NEXT_ID" ] && [ -n "$NEW_BUILD_ID" ] && [ -n "$NEW_ADD_RECIPE_ID" ] || {
    printf '60-new-image: no view ids imported from the libraries\n' >&2
    exit 1
}
# The slots' ids are bases plus the slot's number; the bases are not named *_ID, so they are read here.
base() {
    /usr/bin/sed -n "s/^$1=\\([0-9][0-9]*\\)\$/\\1/p" "$APP_SCRIPTS/lib.agentvm.newimage.sh"
}
# The frame: the rail's marks and the panels are the window's base plus 10 and 40 (lib.agentvm.wizard.sh).
FRAME="$(base NEW_BASE)"
RAIL=$((${FRAME:-0} + 10))
PANEL=$((${FRAME:-0} + 40))
R_ROW="$(base NEW_RECIPE_ROW_BASE)"
R_TICK="$(base NEW_RECIPE_TICK_BASE)"
R_NAME="$(base NEW_RECIPE_NAME_BASE)"
R_TEXT="$(base NEW_RECIPE_TEXT_BASE)"
R_NOTE="$(base NEW_RECIPE_NOTE_BASE)"
O_ROW="$(base NEW_OPTION_ROW_BASE)"
O_LABEL="$(base NEW_OPTION_LABEL_BASE)"
O_FIELD="$(base NEW_OPTION_FIELD_BASE)"
O_CHOOSE="$(base NEW_OPTION_CHOOSE_BASE)"
O_TEXT="$(base NEW_OPTION_TEXT_BASE)"
[ -n "$FRAME" ] && [ -n "$R_ROW" ] && [ -n "$R_TICK" ] && [ -n "$R_NAME" ] && [ -n "$R_TEXT" ] && [ -n "$R_NOTE" ] \
    && [ -n "$O_ROW" ] && [ -n "$O_LABEL" ] && [ -n "$O_FIELD" ] && [ -n "$O_CHOOSE" ] && [ -n "$O_TEXT" ] || {
    printf '60-new-image: the slot bases were not found in the library\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_RECIPES="$OMCTEST_FIXTURES/recipes"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
AGENTVM_APP_NOW=1790769612
export AGENTVM_APP_AGENT_VM AGENTVM_APP_RECIPES AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ AGENTVM_APP_NOW
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?60-new-image: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-new-image-$$"
OTHER_UUID="OMCTEST-other-new-image-$$"
JOBS="$FAKE_AGENTVM_DIR/jobs.json"
FIRST="20260930-120001-000001"
RECIPES="$AGENTVM_APP_RECIPES"
IPSW="UniversalMac_27.0_26A428_Restore.ipsw"
IPSW_PATH="/Users/you/Library/Application Support/agent-vm/Cache/ipsw/$IPSW"
# An image built by an agent-vm that lists the recipes kept: dev-node with homebrew and node.
LISTED='(.images[] | select(.name == "dev-node")) |= (.recipes = [{name: "homebrew", folder: "1-homebrew", description: "Homebrew", digest: "aa"}, {name: "node", folder: "2-node", description: "Node", digest: "bb"}] | .needs = [])'

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
    "$PB" agentvm_open_request_newimage get
}

registered() {
    "$PB" agentvm_window_newimage_window get
}

# kept <name>  ->  one value the window keeps.
kept() {
    "$PB" "agentvm_${1}_$UUID" get
}

# open_new [image] [uuid]  ->  the window opened the way the main window opens it: the request and
# the image handed over, then the window's init handler, in a window of its own.
open_new() {
    "$PB" agentvm_open_request_newimage set "$APP_PID newimage:window"
    "$PB" agentvm_newimage_from set "$APP_PID ${1:-}"
    in_window "${2:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.newimage
    omc_run AgentVM.newimage.init
}

# pick <key> <name>  ->  that row selected in the start table, as the next click sees it.
pick() {
    omc_table_cell "$NEW_SOURCES_ID" 5 "$1"
    omc_table_cell "$NEW_SOURCES_ID" 1 "$2"
}

# ticked <recipe...>  ->  the checkboxes as the user left them: those recipes ticked, in the
# slots the window gave them, and the others not.
ticked() {
    local _slot=0 _name _on
    for _name in homebrew node python agent-clis acp-agents xcode xcode-platforms; do
        _slot=$((_slot + 1))
        _on=false
        case " $* " in
            *" $_name "*) _on=true ;;
        esac
        omc_control "$((R_TICK + _slot))" "$_on"
    done
}

# seen <view id...>  ->  those fields as the window last set them: what the next click sees when
# the user changed nothing.
seen() {
    local _id
    for _id; do
        omc_control "$_id" "$(ui_value "$_id")"
    done
}

next() { omc_run AgentVM.newimage.next; }
back() { omc_run AgentVM.newimage.back; }

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

shown() {
    [ "$(ui_visible "$1")" = "0" ] && echo 0 || echo 1
}

# step_shown  ->  the header, the panel shown, and the rail's marks (d done, n now, t to do).
step_shown() {
    local _n=0 _panels="" _marks=""
    while [ "$_n" -lt 5 ]; do
        _n=$((_n + 1))
        [ "$(ui_visible $((PANEL + _n)))" = "1" ] && _panels="$_panels$_n"
        case "$(ui_visible $((RAIL + _n)))$(ui_visible $((RAIL + 10 + _n)))$(ui_visible $((RAIL + 20 + _n)))" in
            100) _marks="${_marks}t" ;;
            010) _marks="${_marks}n" ;;
            001) _marks="${_marks}d" ;;
            *)   _marks="${_marks}?" ;;
        esac
    done
    printf '%s|%s|%s\n' "$(ui_value "$NEW_HEADER_ID")" "$_panels" "$_marks"
}

note() { ui_value "$NEW_NOTE_ID"; }

# started  ->  the jobs agent-vm was asked to start.
started() {
    fake_log | /usr/bin/grep -c '^job start'
}

# job_args  ->  the command of the fake's first job, one argument per line, without the --json the
# fake adds as agent-vm does.
job_args() {
    /usr/bin/jq -r '.[0].command | map(select(. != "--json")) | .[]' "$JOBS"
}

select_image() {
    omc_table_cell "$MAIN_IMAGES_ID" 1 "$1"
    omc_trigger "$MAIN_IMAGES_ID"
    omc_run AgentVM.main.image.selected
}

fake_reset
store '.'
"$PB" agentvm_window_newimage_window set ""
"$PB" agentvm_open_request_newimage set ""
"$PB" agentvm_open_request_progress set ""
"$PB" agentvm_newimage_from set ""

# -----------------------------------------------------------------------------------------------
section "the library: what a build from an image needs to know"
rows="$(lib agentvm_status_build_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "twelve fields"                "12" "$(printf '%s\n' "$rows" | field_count)"
check "a plain image: ready, not being changed, its macOS, 4 CPUs, 8 GB, a 64 GB disk, the Command Line Tools" \
    "dev${TAB}ready${TAB}false${TAB}27.0${TAB}4${TAB}8${TAB}64${TAB}-${TAB}-${TAB}Command Line Tools for Xcode 27.0-27.0" \
    "$(printf '%s\n' "$rows" | row_named dev | col 1-10)"
check "an image with a bigger disk"  "128" "$(printf '%s\n' "$rows" | row_named dev-xcode | col 7)"
check "an old image: a description, and no list of recipes" "-${TAB}Homebrew and Node" "$(printf '%s\n' "$rows" | row_named dev-node | col 8-9)"
check "its needs"                    "full-disk-access,guest-update" "$(printf '%s\n' "$rows" | row_named dev-node | col 11)"
check "the recipes an image keeps, in order" "homebrew,node" \
    "$(/usr/bin/jq "$LISTED" "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_build_rows | row_named dev-node | col 8)"
check "  and their descriptions"     "Homebrew; Node" \
    "$(/usr/bin/jq "$LISTED" "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_build_rows | row_named dev-node | col 12)"
check "an image another command is changing" "true" \
    "$(/usr/bin/jq '(.images[] | select(.name == "dev")).updating = true' "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_build_rows | row_named dev | col 3)"
check "an empty store: no rows"      "" "$(lib agentvm_status_build_rows < "$FIXTURES_AGENTVM/status-empty.json")"

section "the library: the restore files"
check "one row: name, macOS, build, bytes, newest, path" \
    "$IPSW${TAB}27.0${TAB}26A428${TAB}26626436228${TAB}true${TAB}$IPSW_PATH" \
    "$(lib agentvm_ipsw_rows < "$FIXTURES_AGENTVM/ipsw-list.json")"
check "none downloaded: no rows"     "" "$(printf '[]\n' | lib agentvm_ipsw_rows)"
check "the list is a query"          "image fetch-ipsw --list --json" "$(with_fake agentvm_ipsw_list >/dev/null; fake_log | /usr/bin/tail -1)"

section "the library: where the recipes are"
check "the tests' seam"              "$RECIPES" "$(with_fake agentvm_recipes_dir)"
INSTALLED="$OMCTEST_WORK/installed"
/bin/mkdir -p "$INSTALLED/share/versions/1/Recipes" "$INSTALLED/bin"
/bin/cp "$FAKE_AGENTVM" "$INSTALLED/share/versions/1/agent-vm"
/bin/ln -s "../share/versions/1/agent-vm" "$INSTALLED/bin/agent-vm"
check "installed: beside the real executable, the link followed" "$(/bin/realpath "$INSTALLED/share/versions/1")/Recipes" \
    "$(unset AGENTVM_APP_RECIPES; AGENTVM_APP_AGENT_VM="$INSTALLED/bin/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_recipes_dir)"
TREE="$OMCTEST_WORK/tree"
/bin/mkdir -p "$TREE/.build/signed/release" "$TREE/Recipes"
: > "$TREE/Package.swift"
/bin/cp "$FAKE_AGENTVM" "$TREE/.build/signed/release/agent-vm"
check "a build in a working tree: the tree's" "$(/bin/realpath "$TREE")/Recipes" \
    "$(unset AGENTVM_APP_RECIPES; AGENTVM_APP_AGENT_VM="$TREE/.build/signed/release/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_recipes_dir)"
/bin/rm -f "$TREE/Package.swift"
check "a Recipes folder that is not a working tree's is not taken" "" \
    "$(unset AGENTVM_APP_RECIPES; AGENTVM_APP_AGENT_VM="$TREE/.build/signed/release/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_recipes_dir)"
check "no such agent-vm: nothing"    "" \
    "$(unset AGENTVM_APP_RECIPES; AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/nosuch/agent-vm"; export AGENTVM_APP_AGENT_VM; lib agentvm_recipes_dir)"

section "the library: the recipes and what they ask for"
rows="$(with_fake agentvm_recipe_rows)"
check "seven recipes, five fields each" "7|5" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')|$(printf '%s\n' "$rows" | field_count)"
check "a recipe: its folder's name, description, one input, no parameter, its file" \
    "xcode${TAB}Xcode from a .xip you downloaded (next: Recipes/xcode-platforms for simulator runtimes)${TAB}1${TAB}0${TAB}$RECIPES/xcode/recipe.json" \
    "$(printf '%s\n' "$rows" | row_named xcode)"
check "four parameters"              "0${TAB}4" "$(printf '%s\n' "$rows" | row_named acp-agents | col 3-4)"
BROKEN="$OMCTEST_WORK/broken-recipes"
/bin/mkdir -p "$BROKEN/good" "$BROKEN/notjson" "$BROKEN/Bad Name" "$BROKEN/empty"
printf '{"version": 1, "description": "Good"}\n' > "$BROKEN/good/recipe.json"
printf 'not json\n' > "$BROKEN/notjson/recipe.json"
printf '{"version": 1, "description": "Bad"}\n' > "$BROKEN/Bad Name/recipe.json"
check "a folder with no recipe, one that is not JSON, and a name agent-vm would not accept are left out" "good" \
    "$(AGENTVM_APP_RECIPES="$BROKEN"; export AGENTVM_APP_RECIPES; with_fake agentvm_recipe_rows | col 1)"
check "no folder: no rows"           "" "$(AGENTVM_APP_RECIPES="$OMCTEST_WORK/nosuch"; export AGENTVM_APP_RECIPES; with_fake agentvm_recipe_rows)"
check "an input: no default, its description" \
    "input${TAB}xcode${TAB}-${TAB}an Xcode .xip from https://developer.apple.com/download/all/ (any Apple ID; Apple does not offer it without one)" \
    "$(lib agentvm_recipe_option_rows "$RECIPES/xcode/recipe.json")"
check "parameters: each with its default; an empty default is none" \
    "set claude_acp 0.81.2|set codex_acp 1.13.1|set extras -|set opencode 1.18.32" \
    "$(lib agentvm_recipe_option_rows "$RECIPES/acp-agents/recipe.json" | /usr/bin/cut -f1-3 | /usr/bin/tr '\t' ' ' | /usr/bin/sort | /usr/bin/paste -sd '|' -)"
check "a recipe that asks for nothing" "" "$(lib agentvm_recipe_option_rows "$RECIPES/homebrew/recipe.json")"
printf '{"parameters": {"ok_1": {"default": "x"}, "--force": {"default": "y"}, "a b": {}}}\n' > "$BROKEN/good/recipe.json"
check "a name that could not be part of an argument is left out" "ok_1" "$(lib agentvm_recipe_option_rows "$BROKEN/good/recipe.json" | col 2)"

section "the library: a command line as it would be typed"
check "plain arguments are not quoted, others are" \
    "dev-tools --from dev --recipe /a/b/recipe.json --set 'extras=@google/gemini-cli @github/copilot' --input 'xcode=/Users/you/My Files/Xcode.xip' --set extras= --set 'it='\\''s'" \
    "$(printf '%s\n' dev-tools --from dev --recipe /a/b/recipe.json --set 'extras=@google/gemini-cli @github/copilot' --input 'xcode=/Users/you/My Files/Xcode.xip' --set extras= --set "it='s" | lib agentvm_args_text)"

section "the library: image create is started as a job, and only with arguments of its own"
fake_reset
store '.'
id="$(printf '%s\n' dev-tools --from dev --recipe "$RECIPES/homebrew/recipe.json" --set 'extras=a b' --cpus 6 | with_fake agentvm_job_image_create)"
check "the job's id"                 "$FIRST" "$id"
check "its command: the arguments as given, one each" \
    "image|create|dev-tools|--from|dev|--recipe|$RECIPES/homebrew/recipe.json|--set|extras=a b|--cpus|6" \
    "$(job_args | /usr/bin/paste -sd '|' -)"
: > "$FAKE_AGENTVM_DIR/log"
refused() {
    printf '%s\n' "$@" | with_fake agentvm_job_image_create >/dev/null 2>&1
    printf '%s|%s\n' "$?" "$(started)"
}
check "a name agent-vm would refuse" "2|0" "$(refused --force --from dev)"
check "no start"                     "2|0" "$(refused dev-tools --recipe /a/recipe.json)"
check "a name alone"                 "2|0" "$(refused dev-tools)"
check "an option without its value"  "2|0" "$(refused dev-tools --from dev --recipe)"
check "a start that is not a name"   "2|0" "$(refused dev-tools --from ../dev)"
check "a restore file that is not a full path" "2|0" "$(refused dev-tools --ipsw latest)"
check "a recipe that is not a full path" "2|0" "$(refused dev-tools --from dev --recipe recipe.json)"
check "an option this app does not pass" "2|0" "$(refused dev-tools --from dev --guest-daemon /tmp/x)"
check "a value that is an option"    "2|0" "$(refused dev-tools --from dev --set --json)"
check "an input that is not a full path" "2|0" "$(refused dev-tools --from dev --input xcode=Xcode.xip)"
check "a size that is not a number"  "2|0" "$(refused dev-tools --from dev --disk-gb 64GB)"
check "the refusal says what was refused" "\"--disk-gb 64GB\" is not something this app passes to image create." \
    "$( AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"; export AGENTVM_APP_AGENT_VM; . "$APP_SCRIPTS/lib.agentvm.sh"
        printf '%s\n' dev-tools --from dev --disk-gb 64GB | agentvm_job_image_create >/dev/null; agentvm_last_error 2 )"

# -----------------------------------------------------------------------------------------------
section "the main window's two buttons"
fake_reset
store '.'
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
omc_trigger "$MAIN_NEW_IMAGE_ID"
omc_run AgentVM.main.image.new
check "the plus button asks for the New Image window" "1" "$(chain_asked AgentVM.newimage)"
check "  with a request of this run of the app, and no image handed over" "$APP_PID newimage:window|$APP_PID " "$(request)|$("$PB" agentvm_newimage_from get)"
chains_reset
"$PB" agentvm_open_request_newimage set ""
omc_trigger "$MAIN_IMAGE_DERIVE_ID"
omc_run AgentVM.main.image.new
check "New Image from This... with no image selected opens nothing" "0|" "$(chain_asked AgentVM.newimage)|$(request)"
select_image latest-test
check "a failed image cannot be built from" "0" "$(enabled "$MAIN_IMAGE_DERIVE_ID")"
select_image dev
check "a ready image can"            "1" "$(enabled "$MAIN_IMAGE_DERIVE_ID")"
omc_trigger "$MAIN_IMAGE_DERIVE_ID"
omc_run AgentVM.main.image.new
check "it asks for the window, and hands the image over" "1|$APP_PID newimage:window|$APP_PID dev" \
    "$(chain_asked AgentVM.newimage)|$(request)|$("$PB" agentvm_newimage_from get)"

section "the window opens on step 1"
: > "$FAKE_AGENTVM_DIR/log"
open_new
check_status "the init handler exits cleanly" 0
check "takes the request, and what was handed over, once" "|" "$(request)|$("$PB" agentvm_newimage_from get)"
check "becomes the New Image window" "$APP_PID $UUID|1" "$(registered)|$(kept newimage)"
check "asks agent-vm which it is, reads status and the restore files" "--version|status --json|image fetch-ipsw --list --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                    "New Image" "$(ui_title)"
check "step 1 of 5: its panel, the first mark is now" "Step 1 of 5 - Start from|1|ntttt" "$(step_shown)"
check "Back is off, Continue is there, Build is not" "0|1|0" "$(enabled "$NEW_BACK_ID")|$(shown "$NEW_NEXT_ID")|$(shown "$NEW_BUILD_ID")"
check "the ready images, then the restore file; the failed image is not listed" \
    "dev|dev-acp|dev-agents|dev-node|dev-xcode|dev-xcode-ios|$IPSW" "$(ui_rows "$NEW_SOURCES_ID" | col 1 | /usr/bin/paste -sd '|' -)"
check "a plain image: its macOS, what it holds, ready, and its key" \
    "dev${TAB}27.0${TAB}macOS and the Command Line Tools${TAB}ready${TAB}image dev" "$(ui_rows "$NEW_SOURCES_ID" | row_named dev)"
check "an old image holds what its recipe said; one without Full Disk Access says so" \
    "Homebrew and Node${TAB}no Full Disk Access" "$(ui_rows "$NEW_SOURCES_ID" | row_named dev-node | col 3-4)"
check "  without the recipe's advice for the command line" "Simulator runtimes and Xcode components" "$(ui_rows "$NEW_SOURCES_ID" | row_named dev-xcode-ios | col 3)"
check "the restore file: its macOS, that macOS is installed from it, its size, its key" \
    "$IPSW${TAB}27.0${TAB}a restore file: macOS is installed from it${TAB}26.6 GB${TAB}ipsw $IPSW" "$(ui_rows "$NEW_SOURCES_ID" | row_named "$IPSW")"
check "nothing writes to a view the window does not have" "" "$(ui_unknown_writes)"
next
check "Continue with nothing selected: the step stays, and says why" "Step 1 of 5 - Start from|1|ntttt|Choose what the new image starts from." "$(step_shown)|$(note)"

section "a second request, and windows nobody asked for"
in_window "$MAIN_UUID"
chains_reset
omc_trigger "$MAIN_NEW_IMAGE_ID"
omc_run AgentVM.main.image.new
check "the plus button opens no second window" "0" "$(chain_asked AgentVM.newimage)"
check "  and brings the open one to the front" "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")"
"$PB" agentvm_open_request_newimage set "$APP_PID newimage:window"
in_window "$OTHER_UUID"
omc_control_defaults AgentVM.newimage
omc_run AgentVM.newimage.init
check "a second window: the first stays the New Image window, the second closes" "$APP_PID $UUID|1|" \
    "$(registered)|$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$("$PB" "agentvm_newimage_$OTHER_UUID" get)"
in_window "$UUID"
omc_run AgentVM.newimage.close
check "closing: there is no New Image window, and it keeps nothing" "||" "$(registered)|$(kept newimage)|$(kept start)"
check_absent "  nor a cache folder"   "$TMPDIR/AgentVM/$UUID"
for bad in "" "$APP_PID update:window" "1 newimage:window" "$APP_PID newimage:dev"; do
    ui_reset
    : > "$FAKE_AGENTVM_DIR/log"
    "$PB" agentvm_open_request_newimage set "$bad"
    in_window "$OTHER_UUID"
    omc_control_defaults AgentVM.newimage
    omc_run AgentVM.newimage.init
    check "request [$bad]: the window closes, and agent-vm is not run" "1|" \
        "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)"
    check "  it claims nothing"      "|" "$(registered)|$("$PB" "agentvm_newimage_$OTHER_UUID" get)"
done
section "handlers in a window that is not a New Image window"
in_window "$OTHER_UUID"
ui_reset
: > "$FAKE_AGENTVM_DIR/log"
# Everything a New Image window keeps is there but its mark, and each handler finds the step it
# acts on: so one that did not ask whether the window is a New Image window would act.
"$PB" "agentvm_start_$OTHER_UUID" set "image dev"
"$PB" "agentvm_name_$OTHER_UUID" set "planted"
"$PB" "agentvm_ticks_$OTHER_UUID" set "xcode"
/bin/mkdir -p "$TMPDIR/AgentVM/$OTHER_UUID"
with_fake agentvm_recipe_rows > "$TMPDIR/AgentVM/$OTHER_UUID/recipes.tsv"
printf '0\n%s\ntest\n%s\n' "$(lib_value AGENTVM_MIN_VERSION)" "$FAKE_AGENTVM" > "$TMPDIR/AgentVM/$OTHER_UUID/agentvm"
: > "$FAKE_AGENTVM_DIR/log"
pick "image dev" dev
omc_control "$((R_TICK + 1))" "true"
for planted in "next 1" "tick 2" "recipe 2" "choose 3" "back 4" "build 5" "activated 5"; do
    "$PB" "agentvm_step_$OTHER_UUID" set "${planted#* }"
    omc_dialog_answer choose_file "/tmp/planted.xip"
    omc_trigger "$((O_CHOOSE + 1))"
    omc_run "AgentVM.newimage.${planted% *}"
    check "${planted% *}: agent-vm is not run, nothing is written to the window, nothing is kept or removed" "|0|xcode||yes" \
        "$(fake_log)|$(ui_calls "$OTHER_UUID")|$("$PB" "agentvm_ticks_$OTHER_UUID" get)|$(/bin/cat "$TMPDIR/AgentVM/$OTHER_UUID/values.tsv" 2>/dev/null)|$([ -f "$TMPDIR/AgentVM/$OTHER_UUID/agentvm" ] && echo yes)"
done
for key in step start name ticks; do
    "$PB" "agentvm_${key}_$OTHER_UUID" set ""
done
/bin/rm -rf "$TMPDIR/AgentVM/$OTHER_UUID"
omc_reset_controls

# -----------------------------------------------------------------------------------------------
section "step 1: a start that cannot be built from"
open_new
store '(.images[] | select(.name == "dev")).updating = true'
pick "image dev" dev
next
check "an image another command is changing: the step stays, and says why" \
    "Step 1 of 5 - Start from|Another command is changing image dev. A build can start from it when that has ended." "$(step_shown | /usr/bin/cut -d'|' -f1)|$(note)"
store 'del(.images[] | select(.name == "dev"))'
next
check "an image that is gone"        "Image dev is not there any more. Choose another start." "$(note)"
store '.'
pick "image latest-test" latest-test
next
check "an image that is not ready"   "Image latest-test is not ready, so nothing can be built from it." "$(note)"
pick "image --force" dev
next
check "a key that is not a name is not a start" "Choose what the new image starts from.|" "$(note)|$(kept start)"
printf 'no status today\n' > "$FAKE_AGENTVM_DIR/fail-status"
pick "image dev" dev
next
check "status fails: the step stays, with agent-vm's words" "Step 1 of 5 - Start from|agent-vm could not be read: no status today" \
    "$(step_shown | /usr/bin/cut -d'|' -f1)|$(note)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-status"

section "step 2: the tools, on a plain image"
: > "$FAKE_AGENTVM_DIR/log"
pick "" dev
next
check "the row's name is enough when its key did not arrive" "image dev" "$(kept start)"
check "status and the restore files are read again" "status --json|image fetch-ipsw --list --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "step 2: its panel, step 1 done" "Step 2 of 5 - Tools|2|dnttt" "$(step_shown)"
check "Back is on"                   "1" "$(enabled "$NEW_BACK_ID")"
check "the line above them names the start" \
    "Tick the tools to install on top of image dev (macOS 27.0). They are installed in the order listed. With nothing ticked, the new image is the start as it is." \
    "$(ui_value "$NEW_TOOLS_TEXT_ID")"
names=""
slot=0
while [ "$slot" -lt 10 ]; do
    slot=$((slot + 1))
    names="$names$(ui_value $((R_NAME + slot)))/$(ui_visible $((R_ROW + slot))) "
done
check "the recipes in the order they are applied, each in a slot shown; the other slots stay hidden" \
    "homebrew/1 node/1 python/1 agent-clis/1 acp-agents/1 xcode/1 xcode-platforms/1 / / / " "$names"
check "a description without its advice for the command line" "Node and npm, from Homebrew|Xcode from a .xip you downloaded" \
    "$(ui_value $((R_TEXT + 2)))|$(ui_value $((R_TEXT + 6)))"
check "no checkbox is set by the window" "0" "$(ui_calls "${UUID}${TAB}$((R_TICK + 1))${TAB}")"
ticked node
omc_run AgentVM.newimage.tick
check "node alone: it is kept, and its note says what it needs" "node|needs homebrew" "$(kept ticks)|$(ui_value $((R_NOTE + 2)))"
check "  and the step says to tick it" "node needs homebrew: tick homebrew too." "$(note)"
next
check "Continue: the step stays"     "Step 2 of 5 - Tools|node needs homebrew: tick homebrew too." "$(step_shown | /usr/bin/cut -d'|' -f1)|$(note)"
ticked agent-clis node homebrew
omc_run AgentVM.newimage.tick
check "three ticked: kept in the order they are applied, and nothing is missing" "homebrew node agent-clis|||" \
    "$(kept ticks)|$(ui_value $((R_NOTE + 2)))|$(ui_value $((R_NOTE + 4)))|$(note)"

section "tools that ask for nothing: Options is skipped"
next
check "step 4, with the steps before it done" "Step 4 of 5 - Name and size|4|dddnt" "$(step_shown)"
check "a name from the start, and the start's sizes" "dev-tools|4|8|64" \
    "$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_CPUS_ID")|$(ui_value "$NEW_MEMORY_ID")|$(ui_value "$NEW_DISK_ID")"
check "the line under them"          "These start as image dev has them. The disk is a sparse file, which takes only what is written to it; the disk of a copy stays as it is or grows by at least 8 GB." \
    "$(ui_value "$NEW_SIZE_TEXT_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
back
check "Back from it is Tools"        "Step 2 of 5 - Tools|2|dnttt" "$(step_shown)"
ticked node homebrew
next
check "one tool less: the name suggested follows, since it was not changed" "dev-tools" "$(ui_value "$NEW_NAME_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
back
ticked homebrew
next
check "a single tool names the image" "dev-homebrew" "$(ui_value "$NEW_NAME_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
back
ticked
next
check "no tool: a copy"              "dev-copy" "$(ui_value "$NEW_NAME_ID")"

section "step 4: the name and the sizes"
size_try() {
    omc_control "$NEW_NAME_ID" "$1"
    omc_control "$NEW_CPUS_ID" "$2"
    omc_control "$NEW_MEMORY_ID" "$3"
    omc_control "$NEW_DISK_ID" "$4"
    next
    printf '%s|%s\n' "$(ui_value "$NEW_HEADER_ID")" "$(note)"
}
check "no name"                      "Step 4 of 5 - Name and size|Give the new image a name." "$(size_try "" 4 8 64)"
check "a name agent-vm would refuse" \
    "Step 4 of 5 - Name and size|\"Dev Tools\" cannot be a name: lower-case letters, digits, \".\", \"_\" and \"-\", starting with a letter or a digit, at most 63 characters." \
    "$(size_try "Dev Tools" 4 8 64)"
check "an option as a name"          "Step 4 of 5 - Name and size" "$(size_try "--force" 4 8 64 | /usr/bin/cut -d'|' -f1)"
check "a name that is taken"         "Step 4 of 5 - Name and size|An image named dev-node is there already." "$(size_try dev-node 4 8 64)"
check "processors that are not a number" "Step 4 of 5 - Name and size|Processors: a whole number, 1 or more." "$(size_try mine four 8 64)"
check "no processors"                "Step 4 of 5 - Name and size|Processors: a whole number, 1 or more." "$(size_try mine 0 8 64)"
check "memory that is not a number"  "Step 4 of 5 - Name and size|Memory: a whole number of GB." "$(size_try mine 4 8.5 64)"
check "a disk that is not a number"  "Step 4 of 5 - Name and size|Disk: a whole number of GB." "$(size_try mine 4 8 -64)"
check "a smaller disk"               "Step 4 of 5 - Name and size|The disk can stay at 64 GB, as in image dev, or grow to 72 GB or more. It cannot shrink." "$(size_try mine 4 8 32)"
check "a disk that grows too little" "Step 4 of 5 - Name and size|The disk can stay at 64 GB, as in image dev, or grow to 72 GB or more. It cannot shrink." "$(size_try mine 4 8 71)"
check "spaces around a value are dropped, and the smallest growth is taken" "Step 5 of 5 - Check|" "$(size_try " mine " 6 " 16" 72)"
check "what is kept"                 "mine|6|16|72" "$(kept name)|$(kept cpus)|$(kept memory)|$(kept disk)"

section "step 5: a copy with no tools"
check "the last step: Build in place of Continue, and on" "Step 5 of 5 - Check|5|ddddn|0|1|1" \
    "$(step_shown)|$(shown "$NEW_NEXT_ID")|$(shown "$NEW_BUILD_ID")|$(enabled "$NEW_BUILD_ID")"
check "what is built"                "Image mine, built as a copy of image dev (macOS 27.0).|No tools are added.|6 CPUs, 16 GB of memory, a 72 GB disk." \
    "$(ui_value "$NEW_SUMMARY_ID" | /usr/bin/paste -sd '|' -)"
check "the advice: Full Disk Access, and that it is a job" \
    "The new image keeps the Full Disk Access of image dev.|The build runs as a job. Its progress window opens, and the build goes on when the windows, or the app, are closed." \
    "$(ui_value "$NEW_ADVICE_ID" | /usr/bin/paste -sd '|' -)"
check "the command: only the sizes that differ from the start's" "agent-vm image create mine --from dev --cpus 6 --memory-gb 16 --disk-gb 72" "$(ui_value "$NEW_COMMAND_ID")"
# A name kept that is more than one line (a pasteboard is not a trusted place) would become more
# than one argument: no arguments are made of it, and nothing is started.
"$PB" "agentvm_name_$UUID" set "mine
--recipe
/tmp/evil/recipe.json"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newimage.build
check "a name kept that is not a name: no arguments, Build is off, nothing starts" "agent-vm image create |0|0" \
    "$(ui_value "$NEW_COMMAND_ID")|$(enabled "$NEW_BUILD_ID")|$(started)"
"$PB" "agentvm_name_$UUID" set "mine"
"$PB" "agentvm_cpus_$UUID" set "6
--recipe"
check "a size kept that is not a number: no arguments" "" "$(in_window "$UUID"; ( . "$APP_SCRIPTS/lib.agentvm.newimage.sh"; newimage_args "$UUID" ))"
"$PB" "agentvm_cpus_$UUID" set "6"
back
check "Back shows the name and sizes kept" "Step 4 of 5 - Name and size|mine|6|16|72" \
    "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_CPUS_ID")|$(ui_value "$NEW_MEMORY_ID")|$(ui_value "$NEW_DISK_ID")"
omc_run AgentVM.newimage.close

# -----------------------------------------------------------------------------------------------
section "New Image from This...: the window opens on the tools"
store "$LISTED"
open_new dev-node
check "step 2, with the image as the start" "Step 2 of 5 - Tools|2|dnttt|image dev-node" "$(step_shown)|$(kept start)"
check "the start table has it selected, for Back" "1|3" "$(ui_calls "omc_select_row_with_content")|$(ui_selection "$NEW_SOURCES_ID")"
check "the recipes it keeps say so"  "dev-node has it|dev-node has it|" "$(ui_value $((R_NOTE + 1)))|$(ui_value $((R_NOTE + 2)))|$(ui_value $((R_NOTE + 3)))"
ticked agent-clis python
omc_run AgentVM.newimage.tick
check "what they need is in the image: nothing is missing" "python agent-clis|||" "$(kept ticks)|$(ui_value $((R_NOTE + 3)))|$(ui_value $((R_NOTE + 4)))|$(note)"
ticked agent-clis python xcode-platforms
omc_run AgentVM.newimage.tick
check "a need the image lists no recipe for: a warning, since its list may be short" \
    "needs xcode|xcode-platforms needs xcode. Tick xcode too, unless image dev-node already has it: the build stops at its first step when it does not." \
    "$(ui_value $((R_NOTE + 7)))|$(note)"
next
check "  and Continue goes on"       "Step 3 of 5 - Options" "$(ui_value "$NEW_HEADER_ID")"
omc_run AgentVM.newimage.close
for from in "1 dev" "$APP_PID --force" "$APP_PID latest-test" "$APP_PID nosuch"; do
    "$PB" agentvm_open_request_newimage set "$APP_PID newimage:window"
    "$PB" agentvm_newimage_from set "$from"
    in_window "$UUID"
    ui_reset
    omc_control_defaults AgentVM.newimage
    omc_run AgentVM.newimage.init
    check "handed over [$from]: step 1, and no start" "Step 1 of 5 - Start from|" "$(ui_value "$NEW_HEADER_ID")|$(kept start)"
    omc_run AgentVM.newimage.close
done

section "an old image: what it holds is not known"
store '.'
open_new dev-node
ticked agent-clis
omc_run AgentVM.newimage.tick
check "a warning, not a refusal"     "needs node|agent-clis needs node. Tick node too, unless image dev-node already has it: the build stops at its first step when it does not." \
    "$(ui_value $((R_NOTE + 4)))|$(note)"
next
check "Continue goes on, past Options" "Step 4 of 5 - Name and size|dev-node-agent-clis" "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
next
check "the advice repeats it, and says what Full Disk Access will be" \
    "agent-clis needs node. Tick node too, unless image dev-node already has it: the build stops at its first step when it does not.|Image dev-node has no Full Disk Access, so the new image will have none either. Set Up... in the pane of either grants it." \
    "$(ui_value "$NEW_ADVICE_ID" | /usr/bin/sed -n '1,2p' | /usr/bin/paste -sd '|' -)"
check "the command"                  "agent-vm image create dev-node-agent-clis --from dev-node --recipe $RECIPES/agent-clis/recipe.json" "$(ui_value "$NEW_COMMAND_ID")"
omc_run AgentVM.newimage.close

# -----------------------------------------------------------------------------------------------
section "step 3: what the tools ask for"
XIP="$OMCTEST_WORK/My Downloads/Xcode_27.xip"
/bin/mkdir -p "$OMCTEST_WORK/My Downloads"
: > "$XIP"
store '.'
open_new dev
ticked homebrew node acp-agents xcode xcode-platforms
omc_run AgentVM.newimage.tick
next
check "step 3"                       "Step 3 of 5 - Options|3|ddntt" "$(step_shown)"
check "the line above them"          "What the tools you ticked ask for. A parameter left as it is keeps its default." "$(ui_value "$NEW_OPTIONS_TEXT_ID")"
labels=""
slot=0
while [ "$slot" -lt 8 ]; do
    slot=$((slot + 1))
    labels="$labels$(ui_value $((O_LABEL + slot)))=$(ui_value $((O_FIELD + slot)))/$(ui_visible $((O_ROW + slot)))$(ui_visible $((O_CHOOSE + slot))) "
done
check "the file first, with Choose..., then the parameters with their defaults; the last slot is hidden" \
    "xcode=/11 claude_acp=0.81.2/10 codex_acp=1.13.1/10 opencode=1.18.32/10 extras=/10 platforms=iOS/10 components=MetalToolchain/10 =/0 " "$labels"
check "what a file is, and what a parameter is" \
    "A file: an Xcode .xip from https://developer.apple.com/download/all/ (any Apple ID; Apple does not offer it without one)|version of @agentclientprotocol/claude-agent-acp (latest, or empty, for the newest)" \
    "$(ui_value $((O_TEXT + 1)))|$(ui_value $((O_TEXT + 2)))"
fields="$((O_FIELD + 1)) $((O_FIELD + 2)) $((O_FIELD + 3)) $((O_FIELD + 4)) $((O_FIELD + 5)) $((O_FIELD + 6)) $((O_FIELD + 7))"

section "a click while another one is still being worked on"
# The second click of a double click on Continue is made while the first one's step is being
# filled: what it saw of the fields (here: nothing yet) must not be kept as that step's.
"$PB" "agentvm_busy_$UUID" set "click-$$"
calls_before="$(ui_calls "$UUID")"
next
check "Continue: the step stays, nothing is kept, nothing is written" "3|no|0" \
    "$(kept step)|$([ -f "$TMPDIR/AgentVM/$UUID/values.tsv" ] && echo yes || echo no)|$(( $(ui_calls "$UUID") - calls_before ))"
back
check "Back: the same"               "3|no|0" \
    "$(kept step)|$([ -f "$TMPDIR/AgentVM/$UUID/values.tsv" ] && echo yes || echo no)|$(( $(ui_calls "$UUID") - calls_before ))"
omc_dialog_answer choose_file "$XIP"
omc_trigger "$((O_CHOOSE + 1))"
omc_run AgentVM.newimage.choose
check "Choose...: the same"          "3|no|0" \
    "$(kept step)|$([ -f "$TMPDIR/AgentVM/$UUID/values.tsv" ] && echo yes || echo no)|$(( $(ui_calls "$UUID") - calls_before ))"
check "the other click's mark is not taken away" "click-$$" "$(kept busy)"
# A handler that was killed leaves its mark behind: it holds nothing.
/usr/bin/true &
gone=$!
wait "$gone"
seen $fields
for mark in "click-$gone" "click-" "click-0" "click-1 2" "junk"; do
    "$PB" "agentvm_busy_$UUID" set "$mark"
    back
    check "a mark that names no running handler [$mark] holds nothing: Back acts, and its own mark goes" "2|" "$(kept step)|$(kept busy)"
    next
done
check "and Continue is back on step 3" "Step 3 of 5 - Options" "$(ui_value "$NEW_HEADER_ID")"

section "step 3: the file and the parameters"
seen $fields
next
check "Continue without the file: the step stays, and asks for it" \
    "Step 3 of 5 - Options|Choose the file for xcode: an Xcode .xip from https://developer.apple.com/download/all/ (any Apple ID; Apple does not offer it without one)." \
    "$(ui_value "$NEW_HEADER_ID")|$(note)"
omc_control "$((O_FIELD + 1))" "Xcode_27.xip"
next
check "a file that is not a full path" "The file for xcode must be a full path, starting with \"/\" or \"~/\"." "$(note)"
omc_control "$((O_FIELD + 1))" "/nosuch/Xcode_27.xip"
next
check "a file that is not there"     "/nosuch/Xcode_27.xip is not a file on this Mac." "$(note)"
omc_control "$((O_FIELD + 1))" "~/Xcode_27.xip"
next
check "a path in the home folder is written out" "$HOME/Xcode_27.xip is not a file on this Mac." "$(note)"
omc_control "$((O_FIELD + 2))" "latest"
omc_control "$((O_FIELD + 5))" "@google/gemini-cli @github/copilot"
omc_dialog_answer choose_file "$XIP"
omc_trigger "$((O_CHOOSE + 1))"
omc_run AgentVM.newimage.choose
check "Choose...: the file is in its field, and the note goes" "$XIP|" "$(ui_value $((O_FIELD + 1)))|$(note)"
omc_control "$((O_FIELD + 1))" "$XIP"
check "  and what the other fields held at the click is kept" "latest|@google/gemini-cli @github/copilot" \
    "$(/usr/bin/awk -F'\t' '$2 == "claude_acp" { print $3 }' "$TMPDIR/AgentVM/$UUID/values.tsv")|$(/usr/bin/awk -F'\t' '$2 == "extras" { print $3 }' "$TMPDIR/AgentVM/$UUID/values.tsv")"
omc_trigger "$((O_CHOOSE + 1))"
omc_run AgentVM.newimage.choose
check "a file dialog that was canceled changes nothing" "$XIP" "$(/usr/bin/awk -F'\t' '$1 == "input" && $2 == "xcode" { print $3 }' "$TMPDIR/AgentVM/$UUID/values.tsv")"
omc_dialog_answer choose_file "/tmp/other.xip"
omc_trigger "$((O_CHOOSE + 2))"
omc_run AgentVM.newimage.choose
check "Choose... of a slot that holds a parameter sets nothing" "latest" "$(/usr/bin/awk -F'\t' '$2 == "claude_acp" { print $3 }' "$TMPDIR/AgentVM/$UUID/values.tsv")"
omc_dialog_answer choose_file "/tmp/other.xip"
omc_trigger "$NEW_NEXT_ID"
omc_run AgentVM.newimage.choose
check "  nor does a click that came from no slot" "$XIP" "$(/usr/bin/awk -F'\t' '$1 == "input" && $2 == "xcode" { print $3 }' "$TMPDIR/AgentVM/$UUID/values.tsv")"
omc_control "$((O_FIELD + 6))" ""
next
check "with the file: step 4, and a disk for Xcode" "Step 4 of 5 - Name and size|dev-tools|128" "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_DISK_ID")"
check "  the line under the sizes says why" "Xcode takes about 4 GB and each simulator runtime about 8 GB: 128 GB or more is a good disk for it." \
    "$(ui_value "$NEW_SIZE_TEXT_ID" | /usr/bin/sed -n '2p')"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
back
check "Back from it is Options, with the values kept" "Step 3 of 5 - Options|$XIP|latest|@google/gemini-cli @github/copilot|" \
    "$(ui_value "$NEW_HEADER_ID")|$(ui_value $((O_FIELD + 1)))|$(ui_value $((O_FIELD + 2)))|$(ui_value $((O_FIELD + 5)))|$(ui_value $((O_FIELD + 6)))"
seen $fields
next
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
next

section "step 5: tools with options"
check "what is built"                "Image dev-tools, built as a copy of image dev (macOS 27.0).|Tools, installed in this order: homebrew, node, acp-agents, xcode and xcode-platforms.|4 CPUs, 8 GB of memory, a 128 GB disk." \
    "$(ui_value "$NEW_SUMMARY_ID" | /usr/bin/paste -sd '|' -)"
EXPECTED="dev-tools|--from|dev|--recipe|$RECIPES/homebrew/recipe.json|--recipe|$RECIPES/node/recipe.json|--recipe|$RECIPES/acp-agents/recipe.json|--recipe|$RECIPES/xcode/recipe.json|--recipe|$RECIPES/xcode-platforms/recipe.json|--input|xcode=$XIP|--set|claude_acp=latest|--set|extras=@google/gemini-cli @github/copilot|--set|platforms=|--disk-gb|128"
check "the command: the recipes in order, the file, the parameters that are not at their defaults, the disk" \
    "agent-vm image create $(printf '%s\n' "$EXPECTED" | /usr/bin/tr '|' '\n' | lib agentvm_args_text)" "$(ui_value "$NEW_COMMAND_ID")"
check "  with what has a space in it quoted" "1" "$(ui_value "$NEW_COMMAND_ID" | /usr/bin/grep -c -F -- "--input 'xcode=$XIP' --set claude_acp=latest --set 'extras=@google/gemini-cli @github/copilot' --set platforms= --disk-gb 128")"
check "nothing stands in the way"    "|1" "$(note)|$(enabled "$NEW_BUILD_ID")"

section "what stands in the way of a build"
store '.runningVMs.count = 2'
omc_run AgentVM.newimage.activated
check "no virtual machine slot is free: Build is off, and says why" "2 of 2 virtual machines are running, and a build needs one. Stop a box first.|0" "$(note)|$(enabled "$NEW_BUILD_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newimage.build
check "  Build, clicked anyway, starts nothing" "0" "$(started)"
store '(.images[] | select(.name == "dev")).updating = true'
omc_run AgentVM.newimage.activated
check "the start is being changed"   "Another command is changing image dev. A build can start from it when that has ended.|0" "$(note)|$(enabled "$NEW_BUILD_ID")"
store '.images += [.images[0] | .name = "dev-tools"]'
omc_run AgentVM.newimage.activated
check "the name was taken meanwhile" "An image named dev-tools is there already.|0" "$(note)|$(enabled "$NEW_BUILD_ID")"
store '.'
/bin/rm -f "$XIP"
omc_run AgentVM.newimage.activated
check "the file is gone"             "$XIP is not a file on this Mac.|0" "$(note)|$(enabled "$NEW_BUILD_ID")"
: > "$XIP"
omc_run AgentVM.newimage.activated
check "all clear again: Build is on" "|1" "$(note)|$(enabled "$NEW_BUILD_ID")"

section "Build"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newimage.build
check "a second Build while the first is worked on: agent-vm is not run, nothing starts" "|0" "$(fake_log)|$(started)"
"$PB" "agentvm_busy_$UUID" set ""
printf 'the job cannot be recorded\n' > "$FAKE_AGENTVM_DIR/fail-job"
alerts_before="$(ui_calls omc_present_alert)"
omc_run AgentVM.newimage.build
check "agent-vm refuses the job: an alert with its words, and the window stays" "1|The build of image dev-tools was not started|the job cannot be recorded|0" \
    "$(( $(ui_calls omc_present_alert) - alerts_before ))|$(ui_alert_title)|$(ui_alert_message)|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "  Build is on again, and can be clicked again" "1|" "$(enabled "$NEW_BUILD_ID")|$(kept busy)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job"
in_window "$MAIN_UUID"
omc_run AgentVM.main.activated
in_window "$UUID"
: > "$FAKE_AGENTVM_DIR/log"
chains_reset
omc_run AgentVM.newimage.build
check_status "the handler exits cleanly" 0
# The recipes are checked twice: for the Check step as it is painted again, and for the decision.
check "status and the restore files are read first, the recipes are checked, then the build is started as a job" "status --json|image fetch-ipsw|recipe check|recipe check|job start" \
    "$(fake_log | /usr/bin/sed -n '1,5p' | /usr/bin/cut -d' ' -f1-2 | /usr/bin/paste -sd '|' -)"
check "one job"                      "1" "$(started)"
check "its command is image create with the arguments the window listed" "image|create|$EXPECTED" "$(job_args | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$(ui_value "$NEW_COMMAND_ID")" "agent-vm $(job_args | lib agentvm_args_text)"
check "its progress window is asked for" "1|$APP_PID progress:$FIRST" "$(chain_asked AgentVM.progress)|$("$PB" agentvm_open_request_progress get)"
check "the window closes"            "1" "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")"
check "the main window watches the job" "$FIRST" "$(/usr/bin/grep -x "$FIRST" "$TMPDIR/AgentVM/$MAIN_UUID/jobs-watched")"
omc_run AgentVM.newimage.close
"$PB" agentvm_open_request_progress set ""

# -----------------------------------------------------------------------------------------------
section "a build from a restore file"
fake_reset
store '.'
open_new
pick "ipsw $IPSW" "$IPSW"
next
check "the restore file is the start" "ipsw $IPSW|Step 2 of 5 - Tools" "$(kept start)|$(ui_value "$NEW_HEADER_ID")"
check "the line above the tools names it" \
    "Tick the tools to install on top of the restore file $IPSW (macOS 27.0). They are installed in the order listed. With nothing ticked, the new image is the start as it is." \
    "$(ui_value "$NEW_TOOLS_TEXT_ID")"
ticked python
omc_run AgentVM.newimage.tick
check "nothing is in a restore file: a need not ticked is refused" "python needs homebrew: tick homebrew too." "$(note)"
ticked homebrew python
next
check "the name: dev is taken, so dev2; agent-vm's default sizes" "Step 4 of 5 - Name and size|dev2|4|8|64" \
    "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_CPUS_ID")|$(ui_value "$NEW_MEMORY_ID")|$(ui_value "$NEW_DISK_ID")"
check "the line under the sizes"     "These start as the defaults of agent-vm. The disk is a sparse file, which takes only what is written to it." "$(ui_value "$NEW_SIZE_TEXT_ID")"
check "any disk can be asked for: agent-vm judges it" "Step 5 of 5 - Check|" "$(size_try base 4 8 40)"
check "what is built"                "Image base, with macOS installed from the restore file $IPSW (macOS 27.0).|Tools, installed in this order: homebrew and python.|4 CPUs, 8 GB of memory, a 40 GB disk." \
    "$(ui_value "$NEW_SUMMARY_ID" | /usr/bin/paste -sd '|' -)"
check "the advice: Full Disk Access comes after the build" \
    "An image built from a restore file has no Full Disk Access yet: Set Up... in its pane grants it, once, after the build." "$(ui_value "$NEW_ADVICE_ID" | /usr/bin/sed -n '1p')"
omc_run AgentVM.newimage.build
check "the job: the restore file by its full path, as agent-vm listed it, and all three sizes" \
    "image|create|base|--ipsw|$IPSW_PATH|--recipe|$RECIPES/homebrew/recipe.json|--recipe|$RECIPES/python/recipe.json|--cpus|4|--memory-gb|8|--disk-gb|40" "$(job_args | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$(ui_value "$NEW_COMMAND_ID")" "agent-vm $(job_args | lib agentvm_args_text)"
omc_run AgentVM.newimage.close
"$PB" agentvm_open_request_progress set ""
printf '[]\n' > "$FAKE_AGENTVM_DIR/ipsw-list.json"
store '.images = []'
open_new
check "no image and no restore file: an empty table" "0" "$(ui_row_count "$NEW_SOURCES_ID")"
omc_run AgentVM.newimage.close
/bin/rm -f "$FAKE_AGENTVM_DIR/ipsw-list.json"

section "a start that changes takes the name and sizes with it"
store '.'
open_new
pick "image dev" dev
next
ticked
next
check "a copy of dev"                "dev-copy|64" "$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_DISK_ID")"
omc_control "$NEW_NAME_ID" "kept-name"
omc_control "$NEW_CPUS_ID" "2"
omc_control "$NEW_MEMORY_ID" "8"
omc_control "$NEW_DISK_ID" "64"
back
back
check "back on step 1"               "Step 1 of 5 - Start from|1|ntttt" "$(step_shown)"
pick "image dev" dev
next
next
check "the same start again: the name and sizes typed are kept" "kept-name|2|64" "$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_CPUS_ID")|$(ui_value "$NEW_DISK_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
back
back
pick "image dev-xcode" dev-xcode
next
next
check "another start: its name and sizes" "dev-xcode-copy|4|128" "$(ui_value "$NEW_NAME_ID")|$(ui_value "$NEW_CPUS_ID")|$(ui_value "$NEW_DISK_ID")"
omc_run AgentVM.newimage.close

# -----------------------------------------------------------------------------------------------
section "the library: a recipe file of one's own"
OWN="$OMCTEST_WORK/My Recipes"
/bin/mkdir -p "$OWN/team-tools" "$OWN/---" "$OWN/node"
printf '%s\n' '{ "version": 1, "description": "The linters of the team (needs Node: put Recipes/node before it)", "inputs": { "license": { "description": "the license file" } }, "parameters": { "channel": { "description": "release channel", "default": "stable" } }, "steps": [ { "name": "Linters", "run": "true" } ] }' > "$OWN/team-tools/recipe.json"
printf '%s\n' '{ "version": 1, "steps": [ { "name": "Extra", "run": "true" } ] }' > "$OWN/Extra Things.json"
printf '%s\n' '{ "version": 1, "description": "Another Node", "steps": [] }' > "$OWN/node/recipe.json"
for n in third fourth fifth; do
    printf '{ "version": 1, "description": "The %s", "steps": [] }\n' "$n" > "$OWN/$n.json"
done
printf 'not json\n' > "$OWN/broken.json"
printf '{ "version": 1, "description": "no steps" }\n' > "$OWN/nosteps.json"
printf '[ 1, 2 ]\n' > "$OWN/list.json"
# checked <path>...  ->  the rows of agent-vm's check of those files.
checked() {
    with_fake agentvm_recipe_check "$@" | lib agentvm_recipe_check_rows
}
fake_reset
rows="$(checked "$OWN/team-tools/recipe.json" "$OWN/Extra Things.json")"
check "agent-vm is asked once about the files, in their order" "recipe check $OWN/team-tools/recipe.json $OWN/Extra Things.json --json" "$(fake_log)"
check "a row: agent-vm's name, description, one input file, one parameter, its path, no mistake, no warnings" \
    "team-tools${TAB}The linters of the team (needs Node: put Recipes/node before it)${TAB}1${TAB}1${TAB}$OWN/team-tools/recipe.json${TAB}-${TAB}0${TAB}-" \
    "$(printf '%s\n' "$rows" | /usr/bin/sed -n '1p')"
check "a recipe without a description" "Extra-Things${TAB}-${TAB}0${TAB}0${TAB}$OWN/Extra Things.json${TAB}-${TAB}0${TAB}-" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '2p')"
check "eight fields in every row"    "8" "$(printf '%s\n' "$rows" | field_count)"
with_fake agentvm_recipe_check "$OWN/team-tools/recipe.json" > /dev/null
check "recipes agent-vm accepts: status 0" "0" "$?"
rows="$(checked "$OWN/broken.json" "$OWN/list.json" "$OWN/none.json" "$OWN/third.json")"
check "what agent-vm refuses has its reason, and no name" \
    "-|it is not valid JSON: the data is not in the correct format;-|the top level must be a JSON object;-|cannot read it: there is no such file;third|-;" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ printf "%s|%s;", $1, $6 }')"
with_fake agentvm_recipe_check "$OWN/broken.json" > /dev/null
check "  status 1, with the answer"  "1" "$?"
# A real answer's warnings, and what a build refuses in recipes it accepts one by one.
/usr/bin/jq -n --arg path "$OWN/team-tools/recipe.json" '{error: "the input license is declared by team-tools and by other",
    recipes: [{path: $path, name: "team-tools", inputs: [{name: "license"}], parameters: [], steps: 1, updateSteps: 0, checks: 0, notes: [],
        warnings: [{code: "sudo", place: "step 1", message: "it runs sudo,\twhich asks for a password"},
                   {code: "no-checks", place: "the recipe", message: "it has no checks"}]}]}' > "$FAKE_AGENTVM_DIR/recipe-check.json"
check "warnings: how many, and the first with its place, on one line" "2${TAB}step 1: it runs sudo, which asks for a password" \
    "$(checked "$OWN/team-tools/recipe.json" | /usr/bin/cut -f7-8)"
check "what a build refuses in the recipes together" "the input license is declared by team-tools and by other" \
    "$(with_fake agentvm_recipe_check "$OWN/team-tools/recipe.json" | lib agentvm_recipe_check_error)"
/bin/rm -f "$FAKE_AGENTVM_DIR/recipe-check.json"
check "  none: nothing"              "" "$(with_fake agentvm_recipe_check "$OWN/team-tools/recipe.json" | lib agentvm_recipe_check_error)"
printf 'no such command\n' > "$FAKE_AGENTVM_DIR/fail-recipe"
printf '64\n' > "$FAKE_AGENTVM_DIR/fail-recipe-status"
out="$(with_fake agentvm_recipe_check "$OWN/team-tools/recipe.json")"
check "an agent-vm that cannot check: its status, and no answer" "64|" "$?|$out"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-recipe" "$FAKE_AGENTVM_DIR/fail-recipe-status"

section "step 2: a recipe of one's own joins the list"
# add_own <path>  ->  Add a Recipe File..., with that file chosen in the dialog ("" is Cancel).
add_own() {
    [ -n "$1" ] && omc_dialog_answer choose_file "$1"
    omc_trigger "$NEW_ADD_RECIPE_ID"
    omc_run AgentVM.newimage.recipe
}

# listed  ->  the names in the slots shown, and whether Add a Recipe File... is on.
listed() {
    local _slot=0 _names=""
    while [ "$_slot" -lt 10 ]; do
        _slot=$((_slot + 1))
        [ "$(ui_visible $((R_ROW + _slot)))" = "1" ] && _names="$_names$(ui_value $((R_NAME + _slot))) "
    done
    printf '%s|%s\n' "${_names% }" "$(enabled "$NEW_ADD_RECIPE_ID")"
}
SHIPPED="homebrew node python agent-clis acp-agents xcode xcode-platforms"

fake_reset
store '.'
open_new dev
check "agent-vm's recipes, and Add a Recipe File... is on" "$SHIPPED|1" "$(listed)"
ticked homebrew
add_own "$OWN/team-tools/recipe.json"
check "a recipe added: the next slot, and the checkboxes kept as the click saw them" "$SHIPPED team-tools|1|homebrew" "$(listed)|$(kept ticks)"
check "  its description, without the advice, and where its file is" "The linters of the team, from $OWN/team-tools/recipe.json" "$(ui_value $((R_TEXT + 8)))"
check "  it is not ticked for the user: the note says to tick it" "team-tools is in the list now. Tick it to install it.|0" \
    "$(note)|$(ui_calls "${UUID}${TAB}$((R_TICK + 8))${TAB}")"
add_own ""
check "a file dialog that was canceled changes nothing" "$SHIPPED team-tools|1" "$(listed)"
add_own "$OWN/team-tools/recipe.json"
check "the same file again"          "That is the recipe team-tools, which is in the list already.|$SHIPPED team-tools|1" "$(note)|$(listed)"
add_own "$RECIPES/node/recipe.json"
check "one of agent-vm's own recipes" "That is the recipe node, which is in the list already." "$(note)"
add_own "$OWN/node/recipe.json"
check "another recipe of a name in the list" \
    "A recipe named node is in the list already. A recipe is named by its folder, or by its file when that is not recipe.json: rename one to add this recipe.|$SHIPPED team-tools|1" "$(note)|$(listed)"
add_own "$OWN/broken.json"
check "a file agent-vm does not accept as a recipe: its reason" "agent-vm does not accept $OWN/broken.json as a recipe: it is not valid JSON: the data is not in the correct format.|$SHIPPED team-tools|1" "$(note)|$(listed)"
add_own "$OWN/none.json"
check "a file that is not there"     "$OWN/none.json is not a file on this Mac." "$(note)"
add_own "relative/recipe.json"
check "a path that is not a full one" "Choose a recipe file." "$(note)"
add_own "$OWN/Extra Things.json"
check "a second, without a description" "$SHIPPED team-tools Extra-Things|1|Your recipe, from $OWN/Extra Things.json" "$(listed)|$(ui_value $((R_TEXT + 9)))"
"$PB" "agentvm_busy_$UUID" set "click-$$"
add_own "$OWN/third.json"
check "a click while another one is worked on adds nothing" "$SHIPPED team-tools Extra-Things|1" "$(listed)"
# Rows that are not a recipe's, should the file of the recipes added ever hold one: not listed,
# and gone when the file is next written.
printf 'junk\nfifth\tThe fifth\t0\t0\trelative/fifth.json\n' >> "$TMPDIR/AgentVM/$UUID/own.tsv"
"$PB" "agentvm_busy_$UUID" set ""
add_own "$OWN/third.json"
check "a third: every slot is taken, and Add a Recipe File... is off" "$SHIPPED team-tools Extra-Things third|0" "$(listed)"
check "  a row without its fields, or without a full path, was not taken for a recipe" "3" "$(/usr/bin/awk 'END { print NR }' "$TMPDIR/AgentVM/$UUID/own.tsv")"
add_own "$OWN/fourth.json"
check "one more is refused"          "This window lists 10 recipes. With more, build the image with agent-vm image create in Terminal.|$SHIPPED team-tools Extra-Things third|0" "$(note)|$(listed)"

printf '%s\n' '{ "version": 1, "steps": [] }' > "$OWN/omc_hide.json"
before="$(listed)"
add_own "$OWN/omc_hide.json"
check "a name the window tool would read as an instruction is refused" \
    "A recipe cannot be listed under the name omc_hide. Rename the file or its folder to add this recipe.|$before" "$(note)|$(listed)"
printf 'a b\tA name with a space\t0\t0\t/x/a b.json\n' >> "$TMPDIR/AgentVM/$UUID/own.tsv"
check "a row whose name could not be a recipe's is not one" "" \
    "$( . "$APP_SCRIPTS/lib.agentvm.newimage.sh" >/dev/null 2>&1; newimage_own_rows "$UUID" | /usr/bin/grep -c 'a b' | /usr/bin/grep -v '^0$' )"

section "a build with recipes of one's own"
omc_control "$((R_TICK + 1))" "true"
omc_control "$((R_TICK + 2))" "true"
omc_control "$((R_TICK + 8))" "true"
omc_control "$((R_TICK + 9))" "true"
omc_run AgentVM.newimage.tick
check "ticked: agent-vm's recipes in their order, then one's own in the order added" "homebrew node team-tools Extra-Things" "$(kept ticks)"
next
check "what they ask for: the file first, then the parameter with its default" \
    "Step 3 of 5 - Options|license=/11|channel=stable/10" \
    "$(ui_value "$NEW_HEADER_ID")|$(ui_value $((O_LABEL + 1)))=$(ui_value $((O_FIELD + 1)))/$(ui_visible $((O_ROW + 1)))$(ui_visible $((O_CHOOSE + 1)))|$(ui_value $((O_LABEL + 2)))=$(ui_value $((O_FIELD + 2)))/$(ui_visible $((O_ROW + 2)))$(ui_visible $((O_CHOOSE + 2)))"
LICENSE="$OMCTEST_WORK/license.txt"
: > "$LICENSE"
omc_control "$((O_FIELD + 1))" "$LICENSE"
omc_control "$((O_FIELD + 2))" "stable"
next
check "several tools name the image" "Step 4 of 5 - Name and size|dev-tools" "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")"
seen "$NEW_NAME_ID" "$NEW_CPUS_ID" "$NEW_MEMORY_ID" "$NEW_DISK_ID"
next
check "what is built"                "Tools, installed in this order: homebrew, node, team-tools and Extra-Things." "$(ui_value "$NEW_SUMMARY_ID" | /usr/bin/sed -n '2p')"
OWN_EXPECTED="dev-tools|--from|dev|--recipe|$RECIPES/homebrew/recipe.json|--recipe|$RECIPES/node/recipe.json|--recipe|$OWN/team-tools/recipe.json|--recipe|$OWN/Extra Things.json|--input|license=$LICENSE"
check "the command"                  "agent-vm image create $(printf '%s\n' "$OWN_EXPECTED" | /usr/bin/tr '|' '\n' | lib agentvm_args_text)" "$(ui_value "$NEW_COMMAND_ID")"
check "nothing stands in the way"    "|1" "$(note)|$(enabled "$NEW_BUILD_ID")"
/bin/mv "$OWN/Extra Things.json" "$OWN/moved.json"
omc_run AgentVM.newimage.activated
check "a recipe file that is gone: Build is off, and says why" "The recipe file $OWN/Extra Things.json is not there any more. Untick Extra-Things.|0" "$(note)|$(enabled "$NEW_BUILD_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newimage.build
check "  Build, clicked anyway, starts nothing" "0" "$(started)"
/bin/mv "$OWN/moved.json" "$OWN/Extra Things.json"
omc_run AgentVM.newimage.activated
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.newimage.build
check "Build: the job's command is the one listed" "image|create|$OWN_EXPECTED" "$(job_args | /usr/bin/paste -sd '|' -)"
check "the command line shown is the one run" "$(ui_value "$NEW_COMMAND_ID")" "agent-vm $(job_args | lib agentvm_args_text)"
omc_run AgentVM.newimage.close
check_absent "closing forgets the recipes added" "$TMPDIR/AgentVM/$UUID"
"$PB" agentvm_open_request_progress set ""

section "one's own recipe alone"
fake_reset
store '.'
open_new dev
ticked
add_own "$OWN/Extra Things.json"
omc_control "$((R_TICK + 8))" "true"
/bin/mv "$OWN/Extra Things.json" "$OWN/moved.json"
next
check "Continue with a ticked recipe whose file is gone: the step stays, and says why" \
    "Step 2 of 5 - Tools|The recipe file $OWN/Extra Things.json is not there any more. Untick Extra-Things." "$(ui_value "$NEW_HEADER_ID")|$(note)"
/bin/mv "$OWN/moved.json" "$OWN/Extra Things.json"
next
check "it asks for nothing: step 4, named by the recipe, in lower case" "Step 4 of 5 - Name and size|dev-extra-things" "$(ui_value "$NEW_HEADER_ID")|$(ui_value "$NEW_NAME_ID")"
omc_run AgentVM.newimage.close

section "what agent-vm says about a recipe of one's own"
# agentvm_says <jq filter>  ->  agent-vm's answer about team-tools from now on: the fake's own
# answer, changed by that filter.
agentvm_says() {
    /bin/rm -f "$FAKE_AGENTVM_DIR/recipe-check.json"
    "$FAKE_AGENTVM" recipe check "$OWN/team-tools/recipe.json" --json | /usr/bin/jq "$1" > "$OMCTEST_WORK/recipe-check.json"
    /bin/mv "$OMCTEST_WORK/recipe-check.json" "$FAKE_AGENTVM_DIR/recipe-check.json"
}
fake_reset
store '.'
open_new dev
ticked
printf 'the recipe command is not there\n' > "$FAKE_AGENTVM_DIR/fail-recipe"
printf '64\n' > "$FAKE_AGENTVM_DIR/fail-recipe-status"
add_own "$OWN/team-tools/recipe.json"
check "agent-vm cannot check: the file is not added, and the note has agent-vm's words" \
    "agent-vm could not check $OWN/team-tools/recipe.json: the recipe command is not there|$SHIPPED|1" "$(note)|$(listed)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-recipe-status"
# Status 1 is also how agent-vm ends on any error of its own: then there is no answer, only words.
add_own "$OWN/team-tools/recipe.json"
check "agent-vm fails with status 1 and no answer: the note still has agent-vm's words" \
    "agent-vm could not check $OWN/team-tools/recipe.json: the recipe command is not there|$SHIPPED|1" "$(note)|$(listed)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-recipe"
agentvm_says '.recipes[0] |= ({path, error: "it is not valid JSON: The data is not in the correct format.", notes: [], warnings: []})'
printf '1\n' > "$FAKE_AGENTVM_DIR/recipe-check-status"
add_own "$OWN/team-tools/recipe.json"
check "a reason that ends in a full stop, as the system's do: one full stop" \
    "agent-vm does not accept $OWN/team-tools/recipe.json as a recipe: it is not valid JSON: The data is not in the correct format.|$SHIPPED|1" "$(note)|$(listed)"
agentvm_says '.error = "none of the recipes has an input license"'
add_own "$OWN/team-tools/recipe.json"
check "status 1 with no mistake in the file itself: not added, with what agent-vm refuses" \
    "agent-vm does not accept $OWN/team-tools/recipe.json as a recipe: none of the recipes has an input license.|$SHIPPED|1" "$(note)|$(listed)"
agentvm_says '.'
add_own "$OWN/team-tools/recipe.json"
check "  and with no reason at all: not added either" \
    "agent-vm does not accept $OWN/team-tools/recipe.json as a recipe: it gave no reason.|$SHIPPED|1" "$(note)|$(listed)"
/bin/rm -f "$FAKE_AGENTVM_DIR/recipe-check.json" "$FAKE_AGENTVM_DIR/recipe-check-status"
agentvm_says '.recipes[0].warnings = [{code: "sudo", place: "step 1", message: "it runs sudo, which asks for a password"}]'
: > "$FAKE_AGENTVM_DIR/log"
add_own "$OWN/team-tools/recipe.json"
check "a recipe with a warning is added, and the note has the warning" \
    "team-tools is in the list now. Tick it to install it. agent-vm warns about it: step 1: it runs sudo, which asks for a password.|$SHIPPED team-tools|1" "$(note)|$(listed)"
check "  agent-vm was asked once, about that file" "recipe check $OWN/team-tools/recipe.json --json" "$(fake_log | /usr/bin/grep '^recipe ')"
omc_run AgentVM.newimage.close
open_new dev
ticked
agentvm_says '.recipes[0].warnings = [{code: "sudo", place: "step 1", message: "it runs sudo"}, {code: "no-checks", place: "the recipe", message: "it has no checks"}, {code: "unused-input", place: "input license", message: "no step uses it"}]'
add_own "$OWN/team-tools/recipe.json"
check "several warnings: the first, and how many more" \
    "team-tools is in the list now. Tick it to install it. agent-vm warns about it: step 1: it runs sudo, and 2 more (agent-vm recipe check lists them)." "$(note)"
omc_control "$((R_TICK + 8))" "true"
next
check "  warnings do not stop Continue" "Step 3 of 5 - Options" "$(ui_value "$NEW_HEADER_ID")"
back
agentvm_says '.recipes[0] |= ({path, error: "step 1 has unknown key \"timeout\"", notes: [], warnings: []})'
printf '1\n' > "$FAKE_AGENTVM_DIR/recipe-check-status"
next
check "a ticked recipe agent-vm no longer accepts: the step stays, with its reason" \
    "Step 2 of 5 - Tools|agent-vm does not accept the recipe file $OWN/team-tools/recipe.json now: step 1 has unknown key \"timeout\". Untick team-tools." "$(ui_value "$NEW_HEADER_ID")|$(note)"
agentvm_says '.recipes[0] |= ({path, error: "cannot read it: The file could not be opened.", notes: [], warnings: []})'
next
check "  a reason that ends in a full stop: one full stop" \
    "agent-vm does not accept the recipe file $OWN/team-tools/recipe.json now: cannot read it: The file could not be opened. Untick team-tools." "$(note)"
printf 'the store is locked\n' > "$FAKE_AGENTVM_DIR/fail-recipe"
next
check "  agent-vm fails with status 1 and no answer: its words" "agent-vm could not check the recipes: the store is locked" "$(note)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-recipe"
agentvm_says '.error = "the name license is an input in one recipe and a parameter in another"'
next
check "recipes agent-vm accepts one by one and not together" \
    "Step 2 of 5 - Tools|agent-vm does not accept these recipes together: the name license is an input in one recipe and a parameter in another." "$(ui_value "$NEW_HEADER_ID")|$(note)"
/bin/rm -f "$FAKE_AGENTVM_DIR/recipe-check.json" "$FAKE_AGENTVM_DIR/recipe-check-status"
printf 'the recipe command is not there\n' > "$FAKE_AGENTVM_DIR/fail-recipe"
printf '64\n' > "$FAKE_AGENTVM_DIR/fail-recipe-status"
next
check "an agent-vm that cannot check them" "Step 2 of 5 - Tools|agent-vm could not check the recipes: the recipe command is not there" "$(ui_value "$NEW_HEADER_ID")|$(note)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-recipe" "$FAKE_AGENTVM_DIR/fail-recipe-status"
: > "$FAKE_AGENTVM_DIR/log"
omc_control "$((R_TICK + 1))" "true"
omc_run AgentVM.newimage.tick
next
check "Continue asks agent-vm once, about every ticked recipe in the order of the build" \
    "recipe check $RECIPES/homebrew/recipe.json $OWN/team-tools/recipe.json --json" "$(fake_log | /usr/bin/grep '^recipe ')"
omc_run AgentVM.newimage.close

section "one's own recipes: paths and names that are easy to take for another"
CR="$(printf '\r')"
for n in "tab${TAB}name" "tab name" "cr${CR}name" "cr name" "1" "1.0" 'back\tslash'; do
    printf '{ "version": 1, "description": "The %s", "steps": [] }\n' "$(printf '%s' "$n" | /usr/bin/tr '\t\r\\' '___')" > "$OWN/$n.json"
done
fake_reset
store '.'
open_new dev
ticked
add_own "$OWN/tab${TAB}name.json"
check "a path with a tab in it is refused, and the file whose path has a space there is not taken for it" \
    "The path of that file has a tab or a line break in it. Rename the file or its folder to add this recipe.|$SHIPPED|1" "$(note)|$(listed)"
add_own "$OWN/cr${CR}name.json"
check "so is a path with a line break in it" \
    "The path of that file has a tab or a line break in it. Rename the file or its folder to add this recipe.|$SHIPPED|1" "$(note)|$(listed)"
add_own "$OWN/1.json"
add_own "$OWN/1.0.json"
check "two names that are the same number are two recipes" "$SHIPPED 1 1.0|1|The 1, from $OWN/1.json|The 1.0, from $OWN/1.0.json" \
    "$(listed)|$(ui_value $((R_TEXT + 8)))|$(ui_value $((R_TEXT + 9)))"
add_own "$OWN/back\\tslash.json"
check "a path with a backslash in it" "$SHIPPED 1 1.0 back-tslash|0|The back_tslash, from $OWN/back\\tslash.json" "$(listed)|$(ui_value $((R_TEXT + 10)))"
add_own "$OWN/back\\tslash.json"
check "  the same file again is known by its path" "That is the recipe back-tslash, which is in the list already." "$(note)"
omc_run AgentVM.newimage.close

section "a window that closes while agent-vm is read"
# An agent-vm that, asked for status, does what the window's close handler does meanwhile.
CLOSER="$OMCTEST_WORK/closing-agent-vm"
{
    printf '#!/bin/sh\n'
    printf 'if [ "$1" = "status" ]; then\n'
    printf '    "%s" "agentvm_newimage_%s" set ""\n' "$PB" "$UUID"
    printf '    /bin/rm -rf "%s"\n' "$TMPDIR/AgentVM/$UUID"
    printf 'fi\n'
    printf 'exec "%s" "$@"\n' "$FAKE_AGENTVM"
} > "$CLOSER"
/bin/chmod +x "$CLOSER"
store '.'
AGENTVM_APP_AGENT_VM="$CLOSER"
: > "$FAKE_AGENTVM_DIR/log"
open_new dev
check "guard: agent-vm was read, and the window's mark went meanwhile" "1|" "$(fake_log | /usr/bin/grep -c '^status')|$(kept newimage)"
check "on opening: nothing is painted, no step or start is kept" "||||" "$(ui_value "$NEW_HEADER_ID")|$(ui_row_count "$NEW_SOURCES_ID" 2>/dev/null | /usr/bin/grep -v '^0$')|$(kept step)|$(kept start)|$(kept busy)"
check_absent "  and no cache folder is left" "$TMPDIR/AgentVM/$UUID"
omc_run AgentVM.newimage.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
open_new
AGENTVM_APP_AGENT_VM="$CLOSER"
pick "image dev" dev
next
check "at Continue on step 1: the step is not left, and no cache folder is left" "1|no" "$(kept step)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
omc_run AgentVM.newimage.close
AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"

section "an agent-vm that cannot be used"
printf '0.1.0\n' > "$FAKE_AGENTVM_DIR/version"
: > "$FAKE_AGENTVM_DIR/log"
open_new
check "the window says why, and lists nothing" "1|0" "$(note | /usr/bin/grep -c 'agent-vm')|$(ui_row_count "$NEW_SOURCES_ID")"
check "only its version was asked"   "--version" "$(fake_log | /usr/bin/paste -sd '|' -)"
pick "image dev" dev
next
check "Continue stays on step 1"     "Step 1 of 5 - Start from" "$(ui_value "$NEW_HEADER_ID")"
omc_run AgentVM.newimage.close
/bin/rm -f "$FAKE_AGENTVM_DIR/version"

section "nothing went wrong in the harness"
check "no write to a view no window has" "" "$(ui_unknown_writes)"
check "no table had its rows replaced by a value" "" "$(ui_suspect_writes)"
check "no harness errors"            "" "$(ui_errors)"

omctest_end
