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
check "  the disk space detail"      "55 GB free on the volume of /Users/you/Library/Application Support/agent-vm" \
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
check "twenty-one fields in every row" "21" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named s3)"
check "name, state, image"           "s3${TAB}stopped${TAB}dev-acp" "$(printf '%s\n' "$row" | col 1-3)"
check "network: allowlist, 6 rules"  "allowlist${TAB}6"             "$(printf '%s\n' "$row" | col 4-5)"
check "no running fields: all -"     "-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-12)"
check "not disposable"               "false"                         "$(printf '%s\n' "$row" | col 13)"
check "4 CPUs, 8 GB"                 "4${TAB}8"                     "$(printf '%s\n' "$row" | col 15-16)"
check "its folder"                   "/Users/you/Library/Application Support/agent-vm/Boxes/s3" "$(printf '%s\n' "$row" | col 17)"
check "needs nothing"                "-"                             "$(printf '%s\n' "$row" | col 18)"
check "the macOS it was made with, and when" "27.0${TAB}26A428${TAB}2026-09-25T06:53:07Z" "$(printf '%s\n' "$rows" | row_named cadabra-spike | col 19-21)"

section "box rows: running, unresponsive, disposable (status-variety.json)"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "twenty-one fields in every row" "21" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named s3)"
check "running"                      "running"            "$(printf '%s\n' "$row" | col 2)"
check "the supervisor and the owner" "44847${TAB}812"     "$(printf '%s\n' "$row" | col 6-7)"
check "the project, read-write"      "/Users/you/src/app${TAB}false" "$(printf '%s\n' "$row" | col 8-9)"
check "two programs, since"          "2${TAB}2026-09-29T14:02:10Z" "$(printf '%s\n' "$row" | col 10-11)"
check "the supervisor's version"     "$(/usr/bin/jq -r .version "$FIXTURES_AGENTVM/version.json")" "$(printf '%s\n' "$row" | col 12)"
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
check "still twenty-one fields"      "21"   "$(printf '%s\n' "$row" | field_count)"
check "still one line"               "1"    "$(printf '%s\n' "$row" | /usr/bin/awk 'END { print NR }')"
check "a tab and a line break become spaces" "/Users/you/my project folder" "$(printf '%s\n' "$row" | col 8)"
check "an empty string is -"         "-"    "$(printf '%s\n' "$row" | col 14)"
check "mode off, no allow list: 0 rules" "off${TAB}0" "$(printf '%s\n' "$row" | col 4-5)"
check "no CPU count or memory: -"    "-${TAB}-" "$(printf '%s\n' "$row" | col 15-16)"
check "no macOS or creation date: -" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 19-21)"

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

section "image info row (image-info.json)"
row="$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info.json")"
name="$(printf '%s\n' "$row" | col 1)"
check "twenty-two fields"            "22" "$(printf '%s\n' "$row" | field_count)"
check "the first eleven are status's row of the same image" \
    "$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json" | row_named "$name")" "$(printf '%s\n' "$row" | col 1-11)"
check "its guest daemon's features" "terminal,prompt-notices,wallpaper,time-sync,user-session,terminal-pixels" "$(printf '%s\n' "$row" | col 12)"
check "  none missing"                "-"    "$(printf '%s\n' "$row" | col 13)"
check "the build took 116 s"         "116"  "$(printf '%s\n' "$row" | col 14)"
check "Full Disk Access, and when"   "granted${TAB}2026-09-27T07:32:54Z" "$(printf '%s\n' "$row" | col 15-16)"
check "4 CPUs, 8 GB"                 "4${TAB}8" "$(printf '%s\n' "$row" | col 18-19)"
check "its space, its own, and added over its base" "39008120832${TAB}547110912${TAB}1917476864" "$(printf '%s\n' "$row" | col 20-22)"
check "what a guest update adds"     "terminal-pixels,wallpaper" \
    "$(/usr/bin/jq '.needs = [{kind: "full-disk-access"}, {kind: "guest-update", missing: ["terminal-pixels", "wallpaper"]}]' \
        "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 13)"
check "no Full Disk Access"          "not-granted" \
    "$(/usr/bin/jq '.fullDiskAccess.granted = false' "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 15)"
check "  never checked: -"           "-${TAB}-" \
    "$(/usr/bin/jq 'del(.fullDiskAccess)' "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 15-16)"

section "image info and delete: names agent-vm would refuse are refused first"
fake_reset
with_fake agentvm_image_info "-rf" >/dev/null
check "image info"                   "2" "$?"
with_fake agentvm_image_delete "Dev" >/dev/null
check "image delete"                 "2" "$?"
check "  with the reason"             "yes" "$(lib agentvm_last_error 2 | /usr/bin/grep -q -F '"Dev" is not a valid image name: agent-vm accepts lower-case letters' && echo yes)"
check "  and agent-vm never ran"      "" "$(fake_log)"
with_fake agentvm_image_delete dev-acp
check "a valid name reaches agent-vm" "0${TAB}image delete dev-acp --json" "$?${TAB}$(fake_log)"

section "box info row (box-info.json)"
row="$(lib agentvm_box_info_row < "$FIXTURES_AGENTVM/box-info.json")"
name="$(printf '%s\n' "$row" | col 1)"
check "twenty-three fields"          "23" "$(printf '%s\n' "$row" | field_count)"
check "the first twenty-one are status's row of the same box" \
    "$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json" | row_named "$name")" "$(printf '%s\n' "$row" | col 1-21)"
check "its space, and its own"       "40161382400${TAB}2042597376" "$(printf '%s\n' "$row" | col 22-23)"
check "a volume that does not report its own part: -" "-" \
    "$(/usr/bin/jq 'del(.diskUsage.unsharedBytes)' "$FIXTURES_AGENTVM/box-info.json" | lib agentvm_box_info_row | col 23)"

section "box commands: names agent-vm would refuse are refused first"
fake_reset
for function in agentvm_box_info agentvm_box_view agentvm_box_recreate agentvm_box_delete agentvm_shell_file; do
    with_fake "$function" "-rf" >/dev/null
    check "$function"                "2" "$?"
done
with_fake agentvm_avm_file "-rf" "$OMCTEST_WORK" >/dev/null
check "agentvm_avm_file"             "2" "$?"
check "  with the reason"            "yes" "$(with_fake agentvm_box_delete "S3" 2>/dev/null; lib agentvm_last_error 2 | /usr/bin/grep -q -F '"S3" is not a valid box name' && echo yes)"
check "  and agent-vm never ran"     "" "$(fake_log)"

section "box commands: what reaches agent-vm"
fake_reset
with_fake agentvm_box_view s3
with_fake agentvm_box_view s3 interactive
with_fake agentvm_box_recreate s3
with_fake agentvm_box_delete s3
with_fake agentvm_box_info cadabra-spike >/dev/null
check "view, view and control, recreate, delete, info" \
    "box view s3 --json|box view s3 --interactive --json|box recreate s3 --json|box delete s3 --json|box info cadabra-spike --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
printf 'box s3 is running; stop it first\n' > "$FAKE_AGENTVM_DIR/fail-box-delete"
with_fake agentvm_box_delete s3
check "a refusal is agent-vm's status" "1" "$?"
check "  and its words"              "box s3 is running; stop it first" "$(lib agentvm_last_error 1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-box-delete"

section "Terminal: the .command files"
TERMINAL_DIR="$HOME/Library/Application Support/AgentVM/Terminal"
fake_reset
settings_clear
file="$(with_fake agentvm_shell_file s3)"
check "a shell file in the app's Terminal folder" "$TERMINAL_DIR" "$(/usr/bin/dirname "$file")"
check "  named for the box, and a .command" "yes" "$(case "${file##*/}" in (s3-shell-*.command) echo yes ;; esac)"
check "  only its owner can read or run it" "-rwx------" "$(/bin/ls -l "$file" | /usr/bin/cut -c1-10)"
check "  deletes itself, then runs agent-vm's shell, on the store agent-vm finds by itself" \
    "/bin/rm -f \"\$0\"|unset AGENT_VM_HOME|exec '$FAKE_AGENTVM' box shell s3" \
    "$(/usr/bin/grep -v '^#' "$file" | /usr/bin/paste -sd '|' -)"
check "  agent-vm never ran"         "" "$(fake_log)"
# Terminal runs the file from the user's login shell: an AGENT_VM_HOME its profile exports must
# not send the file to a store the app does not show. One the app itself runs with is carried.
file="$(AGENT_VM_HOME="/Volumes/App Store"; export AGENT_VM_HOME; with_fake agentvm_shell_file s3)"
check "the app's own AGENT_VM_HOME is carried" "AGENT_VM_HOME='/Volumes/App Store'" \
    "$(/usr/bin/grep '^AGENT_VM_HOME=' "$file")"
fake_reset
file="$(with_fake agentvm_shell_file s3)"
( AGENT_VM_HOME="/Volumes/Profile Store"; export AGENT_VM_HOME; /bin/sh "$file" )
check "  without one, a login shell's AGENT_VM_HOME does not reach agent-vm" "(unset)" \
    "$(/bin/cat "$FAKE_AGENTVM_DIR/home")"
settings_write '{"agentVMHome": "/Volumes/Big Disk/it'"'"'s store"}'
file="$(AGENT_VM_HOME="/Volumes/App Store"; export AGENT_VM_HOME; with_fake agentvm_shell_file s3)"
check "the store setting is carried, quoted, over the app's own" "AGENT_VM_HOME='/Volumes/Big Disk/it'\\''s store'" \
    "$(/usr/bin/grep '^AGENT_VM_HOME=' "$file")"
settings_clear
project="$OMCTEST_WORK/it's a project"
/bin/mkdir -p "$project"
file="$(with_fake agentvm_avm_file s3 "$project")"
check "avm, run from the folder, quoted; through the app's link to the agent-vm in use" \
    "cd '$OMCTEST_WORK/it'\\''s a project' && exec '$HOME/Library/Application Support/AgentVM/bin/avm' --box s3" \
    "$(/usr/bin/tail -1 "$file")"
listfile="$(with_fake agentvm_avm_file list "$project")"
check "  a box named like an avm subcommand goes in as the box, not the subcommand" "--box list" \
    "$(/usr/bin/tail -1 "$listfile" | /usr/bin/sed 's/^.*avm. //')"
/bin/rm -f "$listfile"
check "  the link is named avm and points at that agent-vm" "$FAKE_AGENTVM" \
    "$(/usr/bin/readlink "$HOME/Library/Application Support/AgentVM/bin/avm")"
# Two clicks are two handler processes; lib's subshells share this file's pid, so the second
# click is a process of its own here too.
other="$(AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM" /bin/sh -c '. "$1/lib.agentvm.sh" && agentvm_avm_file s3 "$2"' sh "$APP_SCRIPTS" "$project")"
check "  each click's file has a name of its own" "yes" \
    "$([ -n "$other" ] && [ "$other" != "$file" ] && [ -f "$file" ] && [ -f "$other" ] && echo yes)"
install_fake
/bin/ln -sf "$FAKE_AGENTVM" "$HOME/.local/bin/avm"
file="$(lib agentvm_avm_file s3 "$project")"
check "the installed agent-vm: its own avm link" "$HOME/.local/bin/avm" \
    "$(/usr/bin/tail -1 "$file" | /usr/bin/sed "s/^.* && exec '\\(.*\\)' --box s3\$/\\1/")"
/bin/rm -f "$HOME/.local/bin/avm"
file="$(lib agentvm_avm_file s3 "$project")"
check "  without it: the app's link"  "$HOME/Library/Application Support/AgentVM/bin/avm" \
    "$(/usr/bin/tail -1 "$file" | /usr/bin/sed "s/^.* && exec '\\(.*\\)' --box s3\$/\\1/")"
uninstall_fake
with_fake agentvm_avm_file s3 "relative/folder" >/dev/null
check "a folder that is not a full path is refused" "2" "$?"
with_fake agentvm_avm_file s3 "$OMCTEST_WORK/no such folder" >/dev/null
check "  and one that is not there"  "2" "$?"
check "  saying so"                  "There is no folder at $OMCTEST_WORK/no such folder." "$(lib agentvm_last_error 2)"
# A file where the folder should be: mkdir -p fails.
/bin/rm -rf "$TERMINAL_DIR"
: > "$TERMINAL_DIR"
with_fake agentvm_shell_file s3 >/dev/null 2>&1
check "a Terminal folder that cannot be made: refused, not a file elsewhere" "1" "$?"
/bin/rm -f "$TERMINAL_DIR"

section "Terminal: a file runs as written"
# The shell file, run as Terminal would run it: it deletes itself and execs the fake's shell.
fake_reset
file="$(with_fake agentvm_shell_file s3)"
/bin/sh "$file"
check "it ran agent-vm's shell"      "box shell s3" "$(fake_log)"
check "  and deleted itself"         "no" "$([ -e "$file" ] && echo yes || echo no)"

section "a box's network: what is read"
rows="$(lib agentvm_packs_rows < "$FIXTURES_AGENTVM/packs.json")"
check "one row per pack, two fields"  "$(/usr/bin/jq length "$FIXTURES_AGENTVM/packs.json") 2" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }') $(printf '%s\n' "$rows" | field_count)"
check "  a name and its description" "github" "$(printf '%s\n' "$rows" | row_named github | col 1)"
check "the rules: the mode first, then each rule in agent-vm's order" \
    "allowlist|pack:npm|opencode.ai|models.opencode.ai|pack:anthropic|html.duckduckgo.com" \
    "$(lib agentvm_rules_lines < "$FIXTURES_AGENTVM/box-network.json" | /usr/bin/paste -sd '|' -)"
check "  a box made before network rules: open, no rules" "open" "$(printf '{}\n' | lib agentvm_rules_lines)"
row="$(lib agentvm_netlog_rows < "$FIXTURES_AGENTVM/box-netlog.json" | /usr/bin/sed -n '1p')"
check "a connection: time, decision, host, port, method, and the rule that allowed it" \
    "2026-09-30T10:00:01Z${TAB}allowed${TAB}registry.npmjs.org${TAB}443${TAB}CONNECT${TAB}pack:npm" "$row"
check "  a refused one: agent-vm's reason" "not in the allowlist" \
    "$(lib agentvm_netlog_rows < "$FIXTURES_AGENTVM/box-netlog.json" | /usr/bin/sed -n '2p' | col 6)"

section "a box's network: what reaches agent-vm"
fake_reset
with_fake agentvm_box_rules s3 >/dev/null
with_fake agentvm_box_netlog s3 200 >/dev/null
with_fake agentvm_box_packs >/dev/null
with_fake agentvm_box_network_change s3 off "+*.example.com" "-pack:npm" "+public"
check "reads, then one change with the mode, the additions and removals in order" \
    "box network s3 --json|box netlog s3 --last 200 --json|box packs --json|box network s3 --net off --allow *.example.com --disallow pack:npm --allow public --json" \
    "$(fake_log | /usr/bin/paste -sd '|' -)"
fake_reset
with_fake agentvm_box_network_change s3 - "+github.com"
check "no mode: no --net" "box network s3 --allow github.com --json" "$(fake_log)"
fake_reset
for bad in "+-rf" "+a b" "+" "github.com" "-"; do
    with_fake agentvm_box_network_change s3 - "+ok.example.com" "$bad" >/dev/null
    check "refused before agent-vm runs: \"$bad\"" "2" "$?"
done
with_fake agentvm_box_network_change s3 sideways >/dev/null
check "  and a mode agent-vm does not have" "2" "$?"
with_fake agentvm_box_netlog s3 "-1" >/dev/null
check "  and a count that is not one" "2" "$?"
check "  agent-vm never ran" "" "$(fake_log)"

section "a box's network: rules typed by hand, and rules built from the log"
AWK="$APP_SCRIPTS/lib.agentvm.network.awk"
typed() { printf '%s\n' "$1" | /usr/bin/awk -v mode=check -f "$AWK"; }
check "a host, as agent-vm reads it" "github.com" "$(typed GitHub.com.)"
check "subdomains"                   "*.example.com" "$(typed '*.example.com')"
check "a host and port"              "example.com:8443" "$(typed example.com:08443)"
check "a pack"                       "pack:npm" "$(typed pack:npm)"
check "public, and public with a port" "public public:22" "$(typed public) $(typed public:022)"
for bad in "-rf" "a b" "203.0.113.9" "example.com:70000" "*." "pack:" "a..b" "exam_ple.com"; do
    check "not a rule: \"$bad\"" "-" "$(typed "$bad")"
done
built() { printf '%s\t%s\t%s\n' "$1" "$2" "$3" | /usr/bin/awk -F'\t' -v mode=rule -f "$AWK"; }
check "a tunnel to 443: the host"    "registry.yarnpkg.com" "$(built registry.yarnpkg.com 443 CONNECT)"
check "plain HTTP to 80: the host"   "plain.example.org" "$(built plain.example.org 80 GET)"
check "another port: named"          "example.org:8443" "$(built example.org 8443 CONNECT)"
check "a raw tunnel to 80, an address, public: none" "- - -" \
    "$(built raw.example.org 80 CONNECT) $(built 203.0.113.9 443 CONNECT) $(built public 443 CONNECT)"

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
check "no image info field is absent" "" "$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("12:guestFeatures 14:provisionSeconds 15:fullDiskAccess 16:checkedAt 17:commandLineTools 18:cpus 19:memoryGB 20:bytes 21:unsharedBytes 22:addedBytes", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no box info field is absent" "" "$(lib agentvm_box_info_row < "$FIXTURES_AGENTVM/box-info.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 3:image 15:cpus 16:memoryGB 17:path 22:bytes 23:unsharedBytes", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
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
