#!/bin/sh
# Tests/10-agentvm-library.test.sh - which agent-vm the app runs, when it can be used, and how
# agent-vm's answers and failures reach the rest of the app (lib.agentvm.sh).
#
# agent-vm itself never runs here: AGENTVM_APP_AGENT_VM points the library at fake_agent_vm.sh,
# which answers from JSON captured from a real agent-vm (Tests/fixtures/agentvm/). The row
# filters are also run on the fixtures directly, and the drift checks are what fail when a
# refreshed fixture lost a field the library reads. 11-agentvm-contract.test.sh runs the real one.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

INSTALLED="$HOME/.local/bin/agent-vm"
# Where the library leaves agent-vm's stderr. lib runs it in a subshell of this file, so its $$ is
# this file's pid too.
ERR_FILE="${TMPDIR:-/tmp}/AgentVM.agentvm.$$.stderr"
MIN_VERSION="$(lib_value AGENTVM_MIN_VERSION)"
[ -n "$MIN_VERSION" ] || {
    printf '10-agentvm-library: no AGENTVM_MIN_VERSION in lib.agentvm.sh\n' >&2
    exit 1
}

# install_fake  ->  the fake at ~/.local/bin/agent-vm, as agent-vm's installer leaves a link there.
install_fake() {
    /bin/mkdir -p "$HOME/.local/bin"
    /bin/ln -sf "$FAKE_AGENTVM" "$INSTALLED"
}
uninstall_fake() {
    /bin/rm -f "$INSTALLED"
}

# available  ->  "<status> <output>" of agentvm_available, as one line.
available() {
    local _out
    _out="$(lib agentvm_available)"
    local _status=$?
    printf '%s %s\n' "$_status" "$_out"
}

# -----------------------------------------------------------------------------------------------
section "which agent-vm: the installed one by default"
settings_clear
check "the binary"            "$INSTALLED" "$(lib agentvm_bin)"
check "named as installed"    "installed"  "$(lib agentvm_origin)"
check "shown with ~"          "~/.local/bin/agent-vm" "$(lib agentvm_display_path "$INSTALLED")"
check "a path outside home is shown as it is" "/opt/x" "$(lib agentvm_display_path /opt/x)"

section "which agent-vm: a developer override in settings.json"
settings_write '{"developerAgentVM": "/Users/you/Development/agent-vm/.build/signed/release/agent-vm"}'
check "the override"          "/Users/you/Development/agent-vm/.build/signed/release/agent-vm" "$(lib agentvm_bin)"
check "named as developer"    "developer" "$(lib agentvm_origin)"
check "the test seam wins over it" "$FAKE_AGENTVM" "$(with_fake agentvm_bin)"
check "  and is named as test"     "test"          "$(with_fake agentvm_origin)"
settings_write '{"developerAgentVM": 42}'
check "a value that is not a string is no override" "$INSTALLED" "$(lib agentvm_bin)"
settings_write 'this is not JSON'
check "a malformed settings file is no override"    "$INSTALLED" "$(lib agentvm_bin)"
settings_write '{"developerAgentVM": ""}'
check "an empty override is none"                   "installed"  "$(lib agentvm_origin)"
settings_clear

section "the store setting becomes AGENT_VM_HOME"
fake_reset
with_fake agentvm_status >/dev/null
check "without it, agent-vm finds its store itself" "(unset)" "$(/bin/cat "$FAKE_AGENTVM_DIR/home")"
settings_write '{"agentVMHome": "/Volumes/Work/agent-vm"}'
with_fake agentvm_status >/dev/null
check "with it, every call gets it"                 "/Volumes/Work/agent-vm" "$(/bin/cat "$FAKE_AGENTVM_DIR/home")"
with_fake agentvm_doctor >/dev/null
check "  doctor too"                                "/Volumes/Work/agent-vm" "$(/bin/cat "$FAKE_AGENTVM_DIR/home")"
settings_clear

# -----------------------------------------------------------------------------------------------
section "agentvm_available: nothing installed"
settings_clear
uninstall_fake
fake_reset
check "not installed (2), and says where it looked" \
    "2 agent-vm is not installed: there is nothing at ~/.local/bin/agent-vm." "$(available)"
/bin/mkdir -p "$INSTALLED"
check "a folder at that path is not an agent-vm either" \
    "2 agent-vm is not installed: there is nothing at ~/.local/bin/agent-vm." "$(available)"
/bin/rmdir "$INSTALLED"

section "agentvm_available: the installed one"
install_fake
fake_reset
check "the newest: usable (0), and its version is the answer" "0 $MIN_VERSION" "$(available)"
check "it ran agent-vm --version and nothing else" "--version" "$(fake_log)"
printf '99.0.0\n' > "$FAKE_AGENTVM_DIR/version"
check "a newer one is usable too" "0 99.0.0" "$(available)"
printf '0.3.9\n' > "$FAKE_AGENTVM_DIR/version"
check "an older one is too old (3), with both versions" \
    "3 AgentVM needs agent-vm $MIN_VERSION or newer; the one at ~/.local/bin/agent-vm is 0.3.9." "$(available)"
printf 'agent-vm version 0.3.13\n' > "$FAKE_AGENTVM_DIR/version"
check "an answer that is not a version is too old (3)" \
    "3 ~/.local/bin/agent-vm did not report a version: \"agent-vm version 0.3.13\"." "$(available)"
/bin/rm -f "$FAKE_AGENTVM_DIR/version"
printf '134\n' > "$FAKE_AGENTVM_DIR/exit"
printf 'dyld: Library not loaded\n' > "$FAKE_AGENTVM_DIR/stderr"
check "one that does not run is too old (3): installing the newest fixes it" \
    "3 ~/.local/bin/agent-vm did not report its version (status 134: dyld: Library not loaded)." "$(available)"
fake_reset
uninstall_fake

section "agentvm_available: a developer override"
settings_write '{"developerAgentVM": "agent-vm"}'
check "a relative path: 1, installing would not help" \
    "1 The developer agent-vm in Settings is \"agent-vm\", which is not an absolute path. Fix it, or clear it to use the installed agent-vm." "$(available)"
settings_write "{\"developerAgentVM\": \"$HOME/no-such/agent-vm\"}"
check "a missing file: 1" \
    "1 The developer agent-vm in Settings is ~/no-such/agent-vm, which is not an executable file. Build agent-vm there, or clear the setting to use the installed agent-vm." "$(available)"
settings_write "{\"developerAgentVM\": \"$FAKE_AGENTVM\"}"
fake_reset
check "a working one: 0" "0 $MIN_VERSION" "$(available)"
printf '0.3.9\n' > "$FAKE_AGENTVM_DIR/version"
check "an older one: 1, and the fix is the setting" \
    "1 AgentVM needs agent-vm $MIN_VERSION or newer; the one at $FAKE_AGENTVM is 0.3.9. Rebuild it, or clear the developer agent-vm in Settings to use the installed one." "$(available)"
fake_reset
settings_clear

section "agentvm_available: the test seam"
check "a seam that points at nothing: 1" \
    "1 AGENTVM_APP_AGENT_VM is $OMCTEST_WORK/nothing, which is not an executable file." \
    "$( ( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/nothing"; export AGENTVM_APP_AGENT_VM; available ) )"

# -----------------------------------------------------------------------------------------------
section "agentvm_version_at_least"
for pair in "0.3.13 0.3.13 0" "0.3.14 0.3.13 0" "0.4 0.3.13 0" "1.0.0 0.3.13 0" "0.3.13.1 0.3.13 0" \
        "0.3.9 0.3.13 1" "0.3 0.3.13 1" "0.2.99 0.3.13 1" "0.3.13 0.3.13.0 0" \
        "0.3.x 0.3.13 1" " 0.3.13 1" "0.3..13 0.3.13 1" ".3 0.3.13 1" "0.3.13 bad 1"; do
    set -- $pair
    if [ "$#" -eq 2 ]; then
        have="" want="$1" expect="$2"
    else
        have="$1" want="$2" expect="$3"
    fi
    lib agentvm_version_at_least "$have" "$want"
    check "[$have] at least [$want]" "$expect" "$?"
done

section "agentvm_valid_name"
long63="abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyzabcdefghijk"
for pair in "work 0" "dev-agents 0" "a.b_c-1 0" "9lives 0" "$long63 0" "${long63}l 1" \
        "Work 1" "wOrk 1" "-rf 1" ".hidden 1" "_x 1" "a/b 1" "a:b 1"; do
    set -- $pair
    lib agentvm_valid_name "$1"
    check "[$1]" "$2" "$?"
done
lib agentvm_valid_name ""
check "the empty name" "1" "$?"
lib agentvm_valid_name "a b"
check "a name with a space" "1" "$?"

# -----------------------------------------------------------------------------------------------
section "agentvm_last_error: agent-vm's own message"
fake_reset
printf 'the store is locked by another agent-vm; wait for it to finish\n' > "$FAKE_AGENTVM_DIR/fail-status"
with_fake agentvm_status >/dev/null
check "a failed call returns agent-vm's status" "1" "$?"
check_exists "and leaves its stderr behind" "$ERR_FILE"
check "the message, without Error:" \
    "the store is locked by another agent-vm; wait for it to finish" "$(lib agentvm_last_error 1)"
check_absent "and it is forgotten once read" "$ERR_FILE"
check "a second read says only the status" \
    "agent-vm failed (status 1) and gave no reason." "$(lib agentvm_last_error 1)"
printf '75\n' > "$FAKE_AGENTVM_DIR/fail-status-status"
with_fake agentvm_status >/dev/null
check "the status agent-vm chose comes through" "75" "$?"
lib agentvm_last_error >/dev/null

section "agentvm_last_error: other shapes"
printf 'a progress line\n{"event":"progress"}\nError: first line\nsecond line\n' > "$ERR_FILE"
check "everything from the Error: line on" "first line
second line" "$(lib agentvm_last_error 1)"
printf 'Segmentation fault\n{"event":"progress"}\n' > "$ERR_FILE"
check "no Error: line: the lines that are not events" "Segmentation fault" "$(lib agentvm_last_error 139)"
fake_reset
with_fake agentvm_status >/dev/null
check_absent "a call that succeeds leaves nothing" "$ERR_FILE"

# -----------------------------------------------------------------------------------------------
section "reads through the fake"
fake_reset
check "agentvm_status is status --json as it is" \
    "$(/bin/cat "$FIXTURES_AGENTVM/status.json")" "$(with_fake agentvm_status)"
check "one call"                     "status --json" "$(fake_log)"
fake_reset
rows="$(with_fake agentvm_doctor)"
check "agentvm_doctor: one row per check" "6" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "  name, status and detail"    "macOS${TAB}ok${TAB}macOS 27.0.0" "$(printf '%s\n' "$rows" | /usr/bin/head -1)"
check "  the disk space detail"      "67 GB free on the volume of /Users/you/Library/Application Support/agent-vm" \
    "$(printf '%s\n' "$rows" | row_named "disk space" | col 3)"
check "  one call"                   "doctor --json" "$(fake_log)"
printf 'no store\n' > "$FAKE_AGENTVM_DIR/fail-doctor"
with_fake agentvm_doctor >/dev/null
check "  a failed doctor fails"      "1" "$?"
check "  with its message"           "no store" "$(lib agentvm_last_error 1)"

# -----------------------------------------------------------------------------------------------
section "box rows: every box stopped (status.json)"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json")"
check "one row per box"              "3"  "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "eighteen fields in every row" "18" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named s3)"
check "name, state, image"           "s3${TAB}stopped${TAB}dev-acp" "$(printf '%s\n' "$row" | col 1-3)"
check "network: allowlist, 6 rules"  "allowlist${TAB}6"             "$(printf '%s\n' "$row" | col 4-5)"
check "no running fields: all -"     "-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-12)"
check "not disposable"               "false"                         "$(printf '%s\n' "$row" | col 13)"
check "4 CPUs, 8 GB"                 "4${TAB}8"                     "$(printf '%s\n' "$row" | col 15-16)"
check "its folder"                   "/Users/you/Library/Application Support/agent-vm/Boxes/s3" "$(printf '%s\n' "$row" | col 17)"
check "needs nothing"                "-"                             "$(printf '%s\n' "$row" | col 18)"

section "box rows: running, unresponsive, disposable (status-variety.json)"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "eighteen fields in every row" "18" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named s3)"
check "running"                      "running"            "$(printf '%s\n' "$row" | col 2)"
check "the supervisor and the owner" "44847${TAB}812"     "$(printf '%s\n' "$row" | col 6-7)"
check "the project, read-write"      "/Users/you/src/app${TAB}false" "$(printf '%s\n' "$row" | col 8-9)"
check "two programs, since"          "2${TAB}2026-09-29T14:02:10Z" "$(printf '%s\n' "$row" | col 10-11)"
check "the supervisor's version"     "0.4.3"              "$(printf '%s\n' "$row" | col 12)"
check "no status error"              "-"                  "$(printf '%s\n' "$row" | col 14)"
row="$(printf '%s\n' "$rows" | row_named try1)"
check "unresponsive"                 "unresponsive"       "$(printf '%s\n' "$row" | col 2)"
check "  and says why"               "no answer from the supervisor within 5 s" "$(printf '%s\n' "$row" | col 14)"
check "  no network record: open, no rules" "open${TAB}0" "$(printf '%s\n' "$row" | col 4-5)"
check "  no pid to signal"           "-"                  "$(printf '%s\n' "$row" | col 6)"
check "disposable"                   "true"               "$(printf '%s\n' "$rows" | row_named cadabra-spike | col 13)"
check "a box to recreate"            "recreate" \
    "$(/usr/bin/jq '(.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate", guestVersion: "0.4.3"}]' \
        "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_box_rows | row_named s3 | col 18)"

section "box rows: values that would break a row"
json='{"boxes": [{"box": {"name": "odd", "image": "dev", "network": {"mode": "off"}}, "state": "running",
    "project": "/Users/you/my\tproject\nfolder", "statusError": "", "path": "/p"}], "images": [], "runningVMs": {"limit": 2}}'
row="$(printf '%s\n' "$json" | lib agentvm_status_box_rows)"
check "still eighteen fields"        "18"   "$(printf '%s\n' "$row" | field_count)"
check "still one line"               "1"    "$(printf '%s\n' "$row" | /usr/bin/awk 'END { print NR }')"
check "a tab and a line break become spaces" "/Users/you/my project folder" "$(printf '%s\n' "$row" | col 8)"
check "an empty string is -"         "-"    "$(printf '%s\n' "$row" | col 14)"
check "mode off, no allow list: 0 rules" "off${TAB}0" "$(printf '%s\n' "$row" | col 4-5)"
check "no CPU count or memory: -"    "-${TAB}-" "$(printf '%s\n' "$row" | col 15-16)"

section "image rows (status.json)"
rows="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json")"
check "one row per image"            "7"  "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "eleven fields in every row"   "11" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named dev)"
check "dev: ready, no failure, macOS 27.0 (26A428)" "dev${TAB}ready${TAB}-${TAB}27.0${TAB}26A428" "$(printf '%s\n' "$row" | col 1-5)"
check "  built from a restore file, no recipe, needs nothing" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-8)"
check "  its guest daemon"           "0.2.18" "$(printf '%s\n' "$row" | col 9)"
row="$(printf '%s\n' "$rows" | row_named dev-node)"
check "dev-node: built from dev"     "dev"               "$(printf '%s\n' "$row" | col 6)"
check "  with its recipe"            "Homebrew and Node" "$(printf '%s\n' "$row" | col 7)"
check "  needs Full Disk Access"     "full-disk-access"  "$(printf '%s\n' "$row" | col 8)"

section "image rows (status-variety.json)"
rows="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "two needs, comma-joined"      "full-disk-access,guest-update" "$(printf '%s\n' "$rows" | row_named dev-node | col 8)"
check "a failed image and why"       "failed${TAB}the build was canceled" "$(printf '%s\n' "$rows" | row_named latest-test | col 2-3)"

section "the virtual machine row"
check "none running, two at most"    "0${TAB}2" "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status.json")"
check "one running"                  "1${TAB}2" "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status-variety.json")"
check "a count agent-vm could not take is -" "-${TAB}2" \
    "$(printf '{"boxes": [], "images": [], "runningVMs": {"limit": 2}}\n' | lib agentvm_status_vm_row)"

section "an empty store (status-empty.json)"
check "no box rows"                  "" "$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "no image rows"                "" "$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "and the virtual machines"     "0${TAB}2" "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status-empty.json")"

# -----------------------------------------------------------------------------------------------
section "drift: every field the library reads is in the real capture"
# The checks the fixture refresh exists for. A field agent-vm renamed or dropped comes out as
# "-", and these name it instead of letting the window show "-" as an answer. The running fields
# are absent from a capture with every box stopped; status-variety.json carries them, made by hand
# after agent-vm's BoxStatus.
missing="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 3:image 4:netMode 15:cpus 16:memoryGB 17:path", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no box field is absent" "" "$missing"
check "every box says what it needs, if only nothing" "true" \
    "$(/usr/bin/jq '[.boxes[] | has("needs")] | all' "$FIXTURES_AGENTVM/status.json")"
missing="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 4:macOS 5:macOSBuild 9:guestVersion 10:createdAt 11:path", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no image field is absent" "" "$missing"
check "the virtual machine count is there" "0" \
    "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status.json" | col 1)"
check "doctor has the checks the window reads" "virtualization disk space running VMs " \
    "$(lib agentvm_doctor_rows < "$FIXTURES_AGENTVM/doctor.json" | col 1 \
        | /usr/bin/grep -x -e virtualization -e 'disk space' -e 'running VMs' | /usr/bin/tr '\n' ' ')"

section "the version rule"
fixture_version="$(/usr/bin/jq -r '.version' "$FIXTURES_AGENTVM/version.json")"
# When this fails after an agent-vm update, refresh the fixtures from the new agent-vm with
# Tests/helpers/refresh_agentvm_fixtures.sh: the app requires exactly the agent-vm it was tested with.
check "AGENTVM_MIN_VERSION is the fixtures' agent-vm (refresh them after an update)" "$fixture_version" "$MIN_VERSION"

omctest_end
