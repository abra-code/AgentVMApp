# Tests/agentvm.itest.sh - AgentVM through the real engine (appletbuilder itest, OMC 5.5).
#
# The omctest suites (*.test.sh) run the handlers one at a time; this file launches the app and
# walks the paths a user does: the first launch with no agent-vm (Get started), then a main window
# on a store, and the New Image and New Box windows through every step up to Build and Create.
# It never clicks Build or Create, and it checks that nothing that makes an image, a box or a job
# reached agent-vm.
#
# NO REAL agent-vm RUNS. The harness gives the app a private $HOME, so at launch the library finds
# no ~/.local/bin/agent-vm there and shows Get started. The test then points the app's own
# developer setting (developerAgentVM in settings.json, read on every call) at a wrapper in its
# own folder that runs the suites' fake (helpers/fake_agent_vm.sh, answered from
# fixtures/agentvm/), with the fixture recipes and agents beside it, where the library looks for
# them next to the agent-vm in use. The other test seams (AGENTVM_APP_OPEN, _PBCOPY, _PS, _CURL)
# are environment variables, which a test file cannot give an app that is already running, so
# nothing here clicks what would run Finder, Terminal, the clipboard or the network.
#
# NO itest_wait_idle. Every main window runs a poll loop as a command until it closes, so the app
# is never idle while one is open. settle waits instead for the commands to come down to the poll
# loops, with nothing scheduled and no new activity.

# Absolute: it is written into the wrapper, which the app runs from another folder.
tests_dir="$(CDPATH= cd -P -- "$(/usr/bin/dirname -- "${BASH_SOURCE[0]}")" && pwd)"
check "the tests folder is known" "yes" "$([ -n "$tests_dir" ] && [ -d "$tests_dir/helpers" ] && printf yes || printf no)"
scripts="$ITEST_APP/Contents/Resources/Scripts"
jq=/usr/bin/jq

# View ids from the libraries, never restated; checked, or a renamed constant reads empty.
eval "$(/usr/bin/sed -n 's/^\([A-Z][A-Z0-9_]*_ID\)=\([0-9][0-9]*\)$/\1=\2/p' \
    "$scripts/lib.agentvm.main.sh" "$scripts/lib.agentvm.newimage.sh" "$scripts/lib.agentvm.newbox.sh")"
check "the view ids imported" "200 300 311 314 411 414 501 1001 1051 1094 1095 1071 1082 2001 2051 2094 2095 2071 2082" \
    "$MAIN_GETSTARTED_ID $MAIN_STATUS_ID $MAIN_BOXES_ID $MAIN_NEW_BOX_ID $MAIN_IMAGES_ID $MAIN_NEW_IMAGE_ID $MAIN_AGENTVM_VERSION_ID $NEW_HEADER_ID $NEW_SOURCES_ID $NEW_NEXT_ID $NEW_BUILD_ID $NEW_NAME_ID $NEW_COMMAND_ID $NBOX_HEADER_ID $NBOX_IMAGES_ID $NBOX_NEXT_ID $NBOX_CREATE_ID $NBOX_NAME_ID $NBOX_COMMAND_ID"

flag_off() { # <window> <view-id> <name>  ->  0 when the boolean property is true, 1 when it is
    # not, "?" when the bridge call failed: a failed call must not read as shown or enabled.
    local _value
    _value="$(itest_call actionui.getProperty "{\"window\": \"$1\", \"viewID\": $2, \"name\": \"$3\"}")"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        printf '?\n'
        return 0
    fi
    case "$_value" in true) printf '0\n' ;; *) printf '1\n' ;; esac
}
shown() { # <window> <view-id>  ->  1 unless the view is hidden
    flag_off "$1" "$2" hidden
}
enabled() { # <window> <view-id>  ->  1 unless the view is disabled
    flag_off "$1" "$2" disabled
}
row_names() { # <window> <table-id>  ->  the first column of every row, joined by "|"
    itest_call actionui.getRows "{\"window\": \"$1\", \"viewID\": $2}" | "$jq" -r '[.[][0]] | join("|")'
}
select_named() { # <window> <table-id> <name>: selects the row whose first column is name; fires nothing
    local _index
    _index="$(itest_call actionui.getRows "{\"window\": \"$1\", \"viewID\": $2}" \
        | "$jq" -r --arg name "$3" 'map(.[0]) | index($name) // empty')"
    if [ -z "$_index" ]; then
        printf 'agentvm.itest: no row named %s in view %s\n' "$3" "$2" >&2
        return 1
    fi
    itest_call actionui.selectRow "{\"window\": \"$1\", \"viewID\": $2, \"index\": $_index}" > /dev/null
}

# settle <poll-loops> [seconds]: waits until only the poll loops run, nothing is scheduled, and
# the activity count stayed the same over two readings; on timeout it fails a check (as
# itest_wait_idle does) and returns 1, so a wait no caller checks still shows.
settle() {
    local _loops="$1"
    local _seconds="${2:-60}"
    local _deadline=$(( SECONDS + _seconds ))
    local _last=""
    local _now
    while [ "$SECONDS" -lt "$_deadline" ]; do
        _now="$(itest_call omc.test.status | "$jq" -r '"\(.activeCommands) \(.scheduledRuns) \(.scheduledCloses) \(.activity)"')"
        case "$_now" in
            *[!0-9\ ]*|'') ;;
            *)
                set -- $_now
                if [ "$1" -le "$_loops" ] && [ "$2" -eq 0 ] && [ "$3" -eq 0 ] && [ "$_now" = "$_last" ]; then
                    return 0
                fi ;;
        esac
        _last="$_now"
        /bin/sleep 0.5
    done
    check "settled to $_loops poll loops within ${_seconds}s (active scheduled closes activity)" "settled" "$_now"
    return 1
}

fake_dir="$ITEST_WORK/fakevm"
fake_log() { /bin/cat "$fake_dir/log" 2>/dev/null; }
# made  ->  every call that reached agent-vm and is not one of the reads these windows make, one
# per line; nothing when only reads came. Read calls are listed, not the changing ones, so a
# change this file did not think of (recreate, stop, rename, a secret, a job) shows too.
made() {
    if [ ! -f "$fake_dir/log" ]; then
        printf '(no call log)\n'
        return 0
    fi
    /usr/bin/grep -v -x -E -- '--version|version --json|doctor --json|status --json|box packs --json|connect agents --json|image fetch-ipsw --(list|check) --json|recipe check .* --json|(image|box) info [^ ]+ --json|job list --json' \
        "$fake_dir/log"
}

# -----------------------------------------------------------------------------------------------
section "A first launch with no agent-vm shows Get started"
settle 1
first="$(itest_windows)"
check "one window" "1" "$(printf '%s\n' "$first" | /usr/bin/grep -c .)"
check "Get started is shown, Status is not" "1|0" "$(shown "$first" "$MAIN_GETSTARTED_ID")|$(shown "$first" "$MAIN_STATUS_ID")"
check "no agent-vm in the private home" "no" "$([ -e "$ITEST_HOME/.local/bin/agent-vm" ] && printf yes || printf no)"

# -----------------------------------------------------------------------------------------------
section "With the fake agent-vm, a main window shows the store"
avm="$ITEST_WORK/avm"
/bin/mkdir -p "$avm" "$fake_dir"
/bin/cp -R "$tests_dir/fixtures/recipes" "$avm/Recipes"
/bin/cp "$tests_dir/fixtures/agents.json" "$avm/agents.json"
/bin/cat > "$avm/agent-vm" <<EOF
#!/bin/sh
# The tests' fake agent-vm, for the app under test (agentvm.itest.sh).
FAKE_AGENTVM_DIR='$fake_dir'
FAKE_AGENTVM_FIXTURES='$tests_dir/fixtures/agentvm'
export FAKE_AGENTVM_DIR FAKE_AGENTVM_FIXTURES
exec /bin/sh '$tests_dir/helpers/fake_agent_vm.sh' "\$@"
EOF
/bin/chmod 755 "$avm/agent-vm"
fixtures_version="$("$jq" -r '.version' "$tests_dir/fixtures/agentvm/version.json")"
check "the wrapper answers as the fake" "$fixtures_version" "$("$avm/agent-vm" --version)"
: > "$fake_dir/log"
settings="$ITEST_HOME/Library/Application Support/AgentVM/settings.json"
/bin/mkdir -p "$(/usr/bin/dirname "$settings")"
"$jq" -n --arg bin "$avm/agent-vm" '{developerAgentVM: $bin}' > "$settings"

itest_run AgentVM > /dev/null
settle 2
main="$(itest_new_window "$first")"
check "a second main window" "yes" "$([ -n "$main" ] && printf yes || printf no)"
check "Status is shown, Get started is not" "1|0" "$(shown "$main" "$MAIN_STATUS_ID")|$(shown "$main" "$MAIN_GETSTARTED_ID")"
check_contains "the version of agent-vm in use" "$fixtures_version" "$(itest_value "$main" "$MAIN_AGENTVM_VERSION_ID")"
check_contains "the store's images" "dev|dev-acp|dev-agents" "$(row_names "$main" "$MAIN_IMAGES_ID")"
check_contains "the store's boxes" "s3" "$(row_names "$main" "$MAIN_BOXES_ID")"
check_contains "agent-vm was asked for the store" "status --json" "$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "New Image: every step up to Build"
before="$(itest_windows)"
itest_click "$main" "$MAIN_NEW_IMAGE_ID" > /dev/null
settle 2
image_window="$(itest_new_window "$before")"
check "the New Image window opened" "yes" "$([ -n "$image_window" ] && printf yes || printf no)"
check "step 1: the start" "Step 1 of 5 - Start from" "$(itest_value "$image_window" "$NEW_HEADER_ID")"
check_contains "it lists the ready images" "dev|dev-acp" "$(row_names "$image_window" "$NEW_SOURCES_ID")"
check "Build is not there yet" "0" "$(shown "$image_window" "$NEW_BUILD_ID")"

select_named "$image_window" "$NEW_SOURCES_ID" dev
itest_click "$image_window" "$NEW_NEXT_ID" > /dev/null
settle 2
check "step 2: the tools" "Step 2 of 5 - Tools" "$(itest_value "$image_window" "$NEW_HEADER_ID")"

itest_click "$image_window" "$NEW_NEXT_ID" > /dev/null
settle 2
check "no tools ticked: on to the name and size" "Step 4 of 5 - Name and size" "$(itest_value "$image_window" "$NEW_HEADER_ID")"

itest_set_value "$image_window" "$NEW_NAME_ID" "itest-image" > /dev/null
itest_click "$image_window" "$NEW_NEXT_ID" > /dev/null
settle 2
check "step 5: the check" "Step 5 of 5 - Check" "$(itest_value "$image_window" "$NEW_HEADER_ID")"
check "the command it would run" "agent-vm image create itest-image --from dev" "$(itest_value "$image_window" "$NEW_COMMAND_ID")"
check "Build is there and on, Continue is not" "1|1|0" \
    "$(shown "$image_window" "$NEW_BUILD_ID")|$(enabled "$image_window" "$NEW_BUILD_ID")|$(shown "$image_window" "$NEW_NEXT_ID")"
check "only reads reached agent-vm" "" "$(made)"

itest_close "$image_window" > /dev/null
settle 2
check "the window is gone, the main window is not" "$main" "$(itest_windows | /usr/bin/grep -x -e "$image_window" -e "$main")"

# -----------------------------------------------------------------------------------------------
section "New Box: every step up to Create"
before="$(itest_windows)"
itest_click "$main" "$MAIN_NEW_BOX_ID" > /dev/null
settle 2
box_window="$(itest_new_window "$before")"
check "the New Box window opened" "yes" "$([ -n "$box_window" ] && printf yes || printf no)"
check "step 1: the image" "Step 1 of 4 - Image" "$(itest_value "$box_window" "$NBOX_HEADER_ID")"
check_contains "it lists the ready images" "dev|dev-acp" "$(row_names "$box_window" "$NBOX_IMAGES_ID")"
check "Create is not there yet" "0" "$(shown "$box_window" "$NBOX_CREATE_ID")"

select_named "$box_window" "$NBOX_IMAGES_ID" dev
itest_click "$box_window" "$NBOX_IMAGES_ID" > /dev/null
settle 2
itest_click "$box_window" "$NBOX_NEXT_ID" > /dev/null
settle 2
check "step 2: the network" "Step 2 of 4 - Network" "$(itest_value "$box_window" "$NBOX_HEADER_ID")"

itest_click "$box_window" "$NBOX_NEXT_ID" > /dev/null
settle 2
check "step 3: the name and size" "Step 3 of 4 - Name and size" "$(itest_value "$box_window" "$NBOX_HEADER_ID")"

itest_set_value "$box_window" "$NBOX_NAME_ID" "itest-box" > /dev/null
itest_click "$box_window" "$NBOX_NEXT_ID" > /dev/null
settle 2
check "step 4: the check" "Step 4 of 4 - Check" "$(itest_value "$box_window" "$NBOX_HEADER_ID")"
check_contains "the command it would run" "agent-vm box create itest-box --image dev" "$(itest_value "$box_window" "$NBOX_COMMAND_ID")"
check "Create is there and on, Continue is not" "1|1|0" \
    "$(shown "$box_window" "$NBOX_CREATE_ID")|$(enabled "$box_window" "$NBOX_CREATE_ID")|$(shown "$box_window" "$NBOX_NEXT_ID")"
check "only reads reached agent-vm" "" "$(made)"

itest_close "$box_window" > /dev/null
settle 2
check "the window is gone, the main window is not" "$main" "$(itest_windows | /usr/bin/grep -x -e "$box_window" -e "$main")"

# -----------------------------------------------------------------------------------------------
section "Nothing reached agent-vm that makes or changes anything"
check "only reads reached agent-vm: nothing made, started, changed or deleted" "" "$(made)"
check_contains "the main window was still reading the store" "status --json" "$(fake_log)"
