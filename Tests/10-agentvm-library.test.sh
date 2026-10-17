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
# Capitals since agent-vm 0.7.54, kept as given.
for pair in "work 0" "dev-agents 0" "a.b_c-1 0" "9lives 0" "$long63 0" "${long63}l 1" \
        "Work 0" "wOrk 0" "MyBox 0" "Z 0" "-rf 1" ".hidden 1" "_x 1" "a/b 1" "a:b 1" "-Work 1"; do
    set -- $pair
    lib agentvm_valid_name "$1"
    check "[$1]" "$2" "$?"
done
lib agentvm_valid_name ""
check "the empty name" "1" "$?"
lib agentvm_valid_name "a b"
check "a name with a space" "1" "$?"
lib agentvm_valid_name "$(printf '%s\n' "$long63" | /usr/bin/tr 'abcdefghijklmnopqrstuvwxyz' 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"
check "63 capitals" "0" "$?"
lib agentvm_valid_name "Wörk"
check "a letter outside A to Z" "1" "$?"

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
check "agentvm_doctor: one row per check" "9" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "  name, status and detail"    "macOS${TAB}ok${TAB}macOS 27.0.1" "$(printf '%s\n' "$rows" | /usr/bin/head -1)"
check "  the disk space detail"      "134 GB free on the volume of /Users/you/Library/Application Support/agent-vm" \
    "$(printf '%s\n' "$rows" | row_named "disk space" | col 3)"
check "  one call"                   "doctor --json" "$(fake_log)"
printf 'no store\n' > "$FAKE_AGENTVM_DIR/fail-doctor"
with_fake agentvm_doctor >/dev/null
check "  a failed doctor fails"      "1" "$?"
check "  with its message"           "no store" "$(lib agentvm_last_error 1)"

# -----------------------------------------------------------------------------------------------
section "box rows: every box stopped (status.json)"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json")"
check "one row per box"              "2"  "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "twenty-six fields in every row" "26" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named s3)"
check "name, state, image"           "s3${TAB}stopped${TAB}dev-acp" "$(printf '%s\n' "$row" | col 1-3)"
check "network: allowlist, 6 rules"  "allowlist${TAB}6"             "$(printf '%s\n' "$row" | col 4-5)"
check "no running fields: all -"     "-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-12)"
check "not disposable"               "false"                         "$(printf '%s\n' "$row" | col 13)"
check "4 CPUs, 8 GB"                 "4${TAB}8"                     "$(printf '%s\n' "$row" | col 15-16)"
check "its folder"                   "/Users/you/Library/Application Support/agent-vm/Boxes/s3" "$(printf '%s\n' "$row" | col 17)"
check "needs nothing, so no reason"  "-${TAB}-"                      "$(printf '%s\n' "$row" | col 18,22)"
check "the macOS it was made with, and when" "27.0${TAB}26A428${TAB}2026-09-25T06:53:07Z" "$(printf '%s\n' "$rows" | row_named cadabra-spike | col 19-21)"

section "box rows: running, unresponsive, disposable (status-variety.json)"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "twenty-six fields in every row" "26" "$(printf '%s\n' "$rows" | field_count)"
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
check "a box to recreate, and why"   "recreate${TAB}image-updated" \
    "$(/usr/bin/jq '(.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate", reason: "image-updated", macOSBuild: "26A434"}]' \
        "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_box_rows | row_named s3 | col 18,22)"
check "  a need without a reason: -"  "recreate${TAB}-" \
    "$(/usr/bin/jq '(.boxes[] | select(.box.name == "s3")).needs = [{kind: "recreate", guestVersion: "0.4.3"}]' \
        "$FIXTURES_AGENTVM/status-variety.json" | lib agentvm_status_box_rows | row_named s3 | col 18,22)"

section "box rows: values that would break a row"
json='{"boxes": [{"box": {"name": "odd", "image": "dev", "network": {"mode": "off"}}, "state": "running",
    "project": "/Users/you/my\tproject\nfolder", "statusError": "", "path": "/p"}], "images": [], "runningVMs": {"limit": 2}}'
row="$(printf '%s\n' "$json" | lib agentvm_status_box_rows)"
check "still twenty-six fields"      "26"   "$(printf '%s\n' "$row" | field_count)"
check "still one line"               "1"    "$(printf '%s\n' "$row" | /usr/bin/awk 'END { print NR }')"
check "a tab and a line break become spaces" "/Users/you/my project folder" "$(printf '%s\n' "$row" | col 8)"
check "an empty string is -"         "-"    "$(printf '%s\n' "$row" | col 14)"
check "mode off, no allow list: 0 rules" "off${TAB}0" "$(printf '%s\n' "$row" | col 4-5)"
check "no CPU count or memory: -"    "-${TAB}-" "$(printf '%s\n' "$row" | col 15-16)"
check "no macOS or creation date: -" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 19-21)"

section "image rows (status.json)"
rows="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json")"
check "one row per image"            "6"  "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "fifteen fields in every row"  "15" "$(printf '%s\n' "$rows" | field_count)"
row="$(printf '%s\n' "$rows" | row_named dev)"
check "dev: ready, no failure, macOS 27.0.1 (26A434)" "dev${TAB}ready${TAB}-${TAB}27.0.1${TAB}26A434" "$(printf '%s\n' "$row" | col 1-5)"
check "  built from a restore file, no recipe, needs nothing" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-8)"
check "  its guest daemon"           "0.5.6" "$(printf '%s\n' "$row" | col 9)"
row="$(printf '%s\n' "$rows" | row_named dev-node)"
check "dev-node: built from dev"     "dev"               "$(printf '%s\n' "$row" | col 6)"
check "  with its recipe"            "Homebrew and Node" "$(printf '%s\n' "$row" | col 7)"
check "  needs Full Disk Access"     "full-disk-access"  "$(printf '%s\n' "$row" | col 8)"

section "image rows (status-variety.json)"
rows="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-variety.json")"
check "two needs, comma-joined"      "full-disk-access,guest-update" "$(printf '%s\n' "$rows" | row_named dev-node | col 8)"
check "a failed image and why"       "failed${TAB}the build was canceled" "$(printf '%s\n' "$rows" | row_named latest-test | col 2-3)"

section "what an image and a box run (status-mixed.json: both kinds in one store)"
rows="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-mixed.json")"
check "one row per image, fifteen fields each" "10 15" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }') $(printf '%s\n' "$rows" | field_count)"
check "a macOS image: its guest, agent-vm's words for its system, and the system in short" \
    "macos${TAB}macOS 27.0.1 (26A434)${TAB}macOS 27.0.1" "$(printf '%s\n' "$rows" | row_named dev | col 12-14)"
row="$(printf '%s\n' "$rows" | row_named deb)"
check "a Linux image: ready, with no macOS version or build" "ready${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 2-5)"
check "  built from no image, with no recipe, needing nothing" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 6-8)"
check "  its guest, agent-vm's words for its system, and the system in short" \
    "linux${TAB}Debian GNU/Linux 13 (trixie)${TAB}Debian 13" "$(printf '%s\n' "$row" | col 12-14)"
check "one built from it, with its recipes" "deb${TAB}Node and npm from nodejs.org, for Linux images; Claude Code, Codex and opencode (needs Node: put Recipes/node, or Recipes/linux-node in a Linux image, before it)" \
    "$(printf '%s\n' "$rows" | row_named deb-agents | col 6-7)"
check "Ubuntu in short: the distribution and its release, not the point release agent-vm's words have" \
    "Ubuntu 26.04.1 LTS${TAB}Ubuntu 26.04" "$(printf '%s\n' "$rows" | row_named ub | col 13-14)"
check "a screen: true for the Linux image a recipe gave a desktop, - for one without and for a macOS image, which records none" \
    "dev:-|deb:-|deb-agents:true|ub:-" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$1 == "dev" || $1 == "deb" || $1 == "deb-agents" || $1 == "ub" { printf "%s%s:%s", (n++ ? "|" : ""), $1, $15 }')"
rows="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-mixed.json")"
check "one row per box, twenty-six fields each" "3 26" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }') $(printf '%s\n' "$rows" | field_count)"
check "a macOS box"                  "macos${TAB}macOS 27.0 (26A428)${TAB}macOS 27.0" "$(printf '%s\n' "$rows" | row_named cadabra-spike | col 23-25)"
row="$(printf '%s\n' "$rows" | row_named lb)"
check "a Linux box: stopped, made from deb, with no macOS version or build" "stopped${TAB}deb${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 2,3,19,20)"
check "  its guest, its system, and the system in short" "linux${TAB}Debian GNU/Linux 13 (trixie)${TAB}Debian 13" "$(printf '%s\n' "$row" | col 23-25)"
check "  its own screen, which its image (deb, with none here) does not decide" "true" "$(printf '%s\n' "$row" | col 26)"
check "a macOS box records no screen" "-" "$(printf '%s\n' "$rows" | row_named cadabra-spike | col 26)"

section "what an image and a box run: records a capture does not hold"
# guests <images as JSON>  ->  each image's name with its three guest cells.
guests() { printf '{"images": %s}\n' "$1" | lib agentvm_status_image_rows | col 1,12-14; }
check "a record that does not say is macOS, and one with no version has agent-vm's words in short too" \
    "old${TAB}macos${TAB}macOS ? (?)${TAB}macOS ? (?)" "$(guests '[{"name": "old", "system": "macOS ? (?)"}]')"
check "a distribution agent-vm has no word for: its first letter in upper case" \
    "gentoo${TAB}linux${TAB}Gentoo Linux${TAB}Gentoo 2.17" \
    "$(guests '[{"name": "gentoo", "guest": "linux", "system": "Gentoo Linux", "linux": {"distribution": "gentoo", "version": "2.17"}}]')"
check "  one without a version: the distribution alone" "Arch" \
    "$(guests '[{"name": "arch", "guest": "linux", "system": "Arch Linux", "linux": {"distribution": "arch", "version": ""}}]' | col 4)"
check "  a Linux record that names no distribution: agent-vm's words" "Linux" \
    "$(guests '[{"name": "bare", "guest": "linux", "system": "Linux"}]' | col 4)"
check "a macOS version is never read into a Linux record's short name" "Debian 13" \
    "$(guests '[{"name": "odd", "guest": "linux", "system": "x", "macOSVersion": "27.0", "linux": {"distribution": "debian", "version": "13"}}]' | col 4)"
check "a tab in agent-vm's words does not break the row" "fifteen" \
    "$(printf '{"images": [{"name": "tab", "guest": "linux", "system": "A\\tB", "linux": {"distribution": "a\\tb", "version": "1"}}]}\n' \
        | lib agentvm_status_image_rows | /usr/bin/awk -F'\t' 'NF == 15 { print "fifteen" }')"
check "a screen is true or -: false, a string, or none at all are -" "true - - -|true - -" \
    "$(printf '%s\n' '{"images": [{"name": "a", "screen": true}, {"name": "b", "screen": false}, {"name": "c", "screen": "true"}, {"name": "d"}]}' \
        | lib agentvm_status_image_rows | col 15 | /usr/bin/paste -sd ' ' -)|$(printf '%s\n' '{"boxes": [{"box": {"name": "a", "screen": true}}, {"box": {"name": "b", "screen": false}}, {"box": {"name": "c"}, "screen": true}]}' \
        | lib agentvm_status_box_rows | col 26 | /usr/bin/paste -sd ' ' -)"
check "a box says its guest beside its record, or failing that inside it" "linux linux macos" \
    "$(printf '%s\n' '{"boxes": [{"box": {"name": "a"}, "guest": "linux"}, {"box": {"name": "b", "guest": "linux"}}, {"box": {"name": "c"}}]}' \
        | lib agentvm_status_box_rows | col 23 | /usr/bin/paste -sd ' ' -)"

section "update rows: what an update of each image would find (status.json)"
rows="$(lib agentvm_status_update_rows < "$FIXTURES_AGENTVM/status.json")"
check "one row per image"            "6"  "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "twelve fields in every row"   "12" "$(printf '%s\n' "$rows" | field_count)"
check "dev was updated once, and when; macOS and its tools were looked at then" \
    "dev${TAB}1${TAB}2026-10-01T18:42:49Z${TAB}2026-10-01T18:42:49Z${TAB}2026-10-01T18:42:49Z" "$(printf '%s\n' "$rows" | row_named dev | col 1-5)"
check "  it is not behind, keeps no recipes, is not being changed, and its daemon lacks nothing" \
    "-${TAB}-${TAB}-${TAB}-${TAB}false${TAB}-" "$(printf '%s\n' "$rows" | row_named dev | col 6-11)"
check "dev-acp was never updated"    "-${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$rows" | row_named dev-acp | col 2-5)"
check "  it is behind: the newer macOS, its build, and when that was learned" \
    "27.0.1${TAB}26A434${TAB}2026-10-01T17:30:02Z" "$(printf '%s\n' "$rows" | row_named dev-acp | col 6-8)"
check "  the recipe it keeps"        "dev-acp" "$(printf '%s\n' "$rows" | row_named dev-acp | col 9)"
check "an image built before recipes were listed keeps none" "-" "$(printf '%s\n' "$rows" | row_named dev-node | col 9)"
check "every one of them is a macOS image" "macos" "$(printf '%s\n' "$rows" | col 12 | /usr/bin/sort -u)"

section "kernel rows (status-mixed.json)"
rows="$(lib agentvm_status_kernel_rows < "$FIXTURES_AGENTVM/status-mixed.json")"
check "one row per Linux image and Linux box, four fields each, and none for a macOS one" \
    "image:deb image:deb-agents image:ub image:ub-agents box:lb|4" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ printf "%s%s:%s", (NR > 1 ? " " : ""), $1, $2 }')|$(printf '%s\n' "$rows" | field_count)"
check "a record from before agent-vm kept the page size: its kernel, and 4 KiB pages" \
    "6.12.111+deb13-cloud-arm64${TAB}4096" "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$1 == "image" && $2 == "deb"' | col 3-4)"
rows="$(/usr/bin/jq '(.images[] | select(.name == "deb")).linux |= (.pageSize = 16384 | .kernel = "6.12.111+deb13-arm64-16k")
    | (.boxes[] | select(.box.name == "lb")).box.linux |= del(.kernel)' "$FIXTURES_AGENTVM/status-mixed.json" | lib agentvm_status_kernel_rows)"
check "an image that says its page size" "6.12.111+deb13-arm64-16k${TAB}16384" "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$1 == "image" && $2 == "deb"' | col 3-4)"
check "  its box keeps its own, and one whose record names no kernel has -" "-${TAB}4096" "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$1 == "box" && $2 == "lb"' | col 3-4)"
rows="$(/usr/bin/jq '(.images[] | select(.name == "deb")) |= (del(.linux) | .state = "building") | (.boxes[] | select(.box.name == "lb")).box |= del(.linux)' "$FIXTURES_AGENTVM/status-mixed.json" | lib agentvm_status_kernel_rows)"
check "a Linux image or box whose record has no system yet: no row, since nothing is known of its kernel" \
    "image:deb-agents image:ub image:ub-agents" "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ printf "%s%s:%s", (NR > 1 ? " " : ""), $1, $2 }')"
check "a store of macOS images and boxes, and an empty one: no row" "|" \
    "$(lib agentvm_status_kernel_rows < "$FIXTURES_AGENTVM/status.json")|$(lib agentvm_status_kernel_rows < "$FIXTURES_AGENTVM/status-empty.json")"

section "update rows of Linux images (status-linux.json)"
rows="$(lib agentvm_status_update_rows < "$FIXTURES_AGENTVM/status-linux.json")"
check "one row per image, twelve fields each" "4 12" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }') $(printf '%s\n' "$rows" | field_count)"
check "never updated; when its packages were last looked at, where a macOS image has when Apple was asked" \
    "-${TAB}-${TAB}$(/usr/bin/jq -r '.images[] | select(.name == "deb") | .systemCheckedAt' "$FIXTURES_AGENTVM/status-linux.json")${TAB}-" \
    "$(printf '%s\n' "$rows" | row_named deb | col 2-5)"
check "  that is a time, not -"      "yes" "$(printf '%s\n' "$rows" | row_named deb | col 4 | /usr/bin/awk '/^20[0-9][0-9]-/ { print "yes" }')"
check "no newer macOS is ever known for one" "-${TAB}-${TAB}-" "$(printf '%s\n' "$rows" | row_named deb | col 6-8)"
check "the recipes one keeps"        "linux-node,agent-clis" "$(printf '%s\n' "$rows" | row_named deb-agents | col 9)"
check "every one of them is a Linux image" "linux" "$(printf '%s\n' "$rows" | col 12 | /usr/bin/sort -u)"

section "update rows: values a capture does not hold"
json='{"images": [{"name": "one", "state": "ready", "updating": true,
    "recipes": [{"name": "homebrew", "folder": "1-homebrew"}, {"name": "inherited"}, {"folder": "3-node"}, {"name": "agent\tclis", "folder": "4"}],
    "needs": [{"kind": "full-disk-access"}, {"kind": "guest-update", "missing": ["wallpaper", "terminal-pixels"]}]}]}'
row="$(printf '%s\n' "$json" | lib agentvm_status_update_rows)"
check "still twelve fields, on one line" "12 1" "$(printf '%s\n' "$row" | field_count) $(printf '%s\n' "$row" | /usr/bin/awk 'END { print NR }')"
check "the recipes whose files it keeps, in order; one without a name by its folder" \
    "homebrew,3-node,agent clis" "$(printf '%s\n' "$row" | col 9)"
check "being changed"                "true" "$(printf '%s\n' "$row" | col 10)"
check "what its guest daemon lacks"  "wallpaper,terminal-pixels" "$(printf '%s\n' "$row" | col 11)"

section "input rows: the files of the recipes an image keeps"
check "no image of the captures keeps a recipe with an input under recipes" "||" \
    "$(lib agentvm_status_input_rows < "$FIXTURES_AGENTVM/status.json")|$(lib agentvm_status_input_rows < "$FIXTURES_AGENTVM/status-linux.json")|$(lib agentvm_status_input_rows < "$FIXTURES_AGENTVM/status-empty.json")"
# As agent-vm 0.7.57 lists an image made before 0.7.56 that ran xcode twice: the inherited entry,
# then its own, each with the file it ran with; and a recipe of its own with two inputs.
json='{"images": [{"name": "tools", "recipes": [
    {"name": "homebrew", "folder": "1-homebrew"},
    {"name": "xcode", "folder": "2-xcode", "inheritedFrom": "base", "inputs": [{"name": "xcode", "file": "Xcode_27.xip", "path": "/Users/you/Downloads/Xcode_27.xip", "bytes": 1, "sha256": "a"}]},
    {"name": "xcode", "folder": "3-xcode", "inputs": [{"name": "xcode", "file": "Xcode_27.1.xip", "path": "/Volumes/share/Xcode 27.1.xip", "bytes": 2, "sha256": "b"}]},
    {"name": "mine", "folder": "4-mine", "inputs": [{"name": "kit", "file": "kit.zip"}, {"name": "bad-name", "file": "x"}, {"name": "data", "file": "d\tz.bin", "path": "/d"}]},
    {"name": "gone", "inputs": [{"name": "old", "file": "old.zip"}]}]},
  {"name": "plain"}]}'
rows="$(printf '%s\n' "$json" | lib agentvm_status_input_rows)"
check "one row per input name, in the order the recipes ran, six fields each" "xcode kit data|6" \
    "$(printf '%s\n' "$rows" | col 2 | /usr/bin/paste -sd ' ' -)|$(printf '%s\n' "$rows" | field_count)"
check "  an input kept twice goes to the last recipe that has it, with the file it ran with" \
    "tools${TAB}xcode${TAB}xcode${TAB}Xcode_27.1.xip${TAB}/Volumes/share/Xcode 27.1.xip${TAB}3" "$(printf '%s\n' "$rows" | /usr/bin/sed -n 1p)"
check "  a record that does not say where the file was: -; and the place of its recipe among those whose files are kept" "kit.zip${TAB}-${TAB}4" "$(printf '%s\n' "$rows" | /usr/bin/sed -n 2p | col 4-6)"
check "  a tab in a file's name does not break the row" "mine${TAB}d z.bin" "$(printf '%s\n' "$rows" | /usr/bin/sed -n 3p | col 3-4)"
check "  a name that cannot be an argument, and a recipe whose files are not kept, give no row" "" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '$2 == "bad-name" || $2 == "old"')"

section "recipe rows: the recipes an image keeps"
rows="$(printf '%s\n' "$json" | lib agentvm_status_recipe_rows)"
check "one row per recipe whose files are kept, a recipe kept twice twice, in order, five fields each" "1 2 3 4|homebrew xcode xcode mine|5" \
    "$(printf '%s\n' "$rows" | col 2 | /usr/bin/paste -sd ' ' -)|$(printf '%s\n' "$rows" | col 3 | /usr/bin/paste -sd ' ' -)|$(printf '%s\n' "$rows" | field_count)"
check "  the inputs each was built with, by the names an argument can take; - for none" "-|xcode|xcode|kit,data" \
    "$(printf '%s\n' "$rows" | col 5 | /usr/bin/paste -sd '|' -)"
check "  the places are those of the input rows" "3 4" \
    "$(printf '%s\n' "$json" | lib agentvm_status_input_rows | col 6 | /usr/bin/sort -u | /usr/bin/paste -sd ' ' -)"
check "a description, with a tab in it; a recipe without a name by its folder" "tools${TAB}1${TAB}2-node${TAB}Node and npm${TAB}-" \
    "$(printf '%s\n' '{"images": [{"name": "tools", "recipes": [{"folder": "2-node", "description": "Node\tand npm"}]}]}' | lib agentvm_status_recipe_rows)"
check "the captures: dev-acp keeps one, with its description" "dev-acp${TAB}1${TAB}dev-acp" \
    "$(lib agentvm_status_recipe_rows < "$FIXTURES_AGENTVM/status-variety.json" | col 1-3)"
check "an image that keeps none has no row" "" "$(lib agentvm_status_recipe_rows < "$FIXTURES_AGENTVM/status-empty.json")"

section "the newest macOS row"
check "what status --check-updates last learned" "27.0.1${TAB}26A434${TAB}2026-10-01T17:30:02Z${TAB}-" \
    "$(lib agentvm_status_newest_row < "$FIXTURES_AGENTVM/status.json")"
check "never asked: all -"           "-${TAB}-${TAB}-${TAB}-" "$(lib agentvm_status_newest_row < "$FIXTURES_AGENTVM/status-empty.json")"
check "a lookup that failed says why" "27.0${TAB}26A428${TAB}2026-09-30T10:00:00Z${TAB}the lookup timed out" \
    "$(printf '{"newestMacOS": {"version": "27.0", "build": "26A428", "checkedAt": "2026-09-30T10:00:00Z"}, "newestMacOSError": "the lookup\\ttimed out"}\n' | lib agentvm_status_newest_row)"

section "image info row (image-info.json)"
row="$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info.json")"
name="$(printf '%s\n' "$row" | col 1)"
check "twenty-nine fields"           "29" "$(printf '%s\n' "$row" | field_count)"
check "the first fifteen are status's row of the same image" \
    "$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json" | row_named "$name")" "$(printf '%s\n' "$row" | col 1-15)"
check "  a macOS image records no screen, though it has one" "-" "$(printf '%s\n' "$row" | col 15)"
check "its guest daemon's features" "terminal,prompt-notices,wallpaper,time-sync,user-session,terminal-pixels" "$(printf '%s\n' "$row" | col 16)"
check "  none missing"                "-"    "$(printf '%s\n' "$row" | col 17)"
check "the build took 92 s"          "92"  "$(printf '%s\n' "$row" | col 18)"
check "Full Disk Access, and when"   "granted${TAB}2026-10-02T02:40:30Z" "$(printf '%s\n' "$row" | col 19-20)"
check "its Command Line Tools"       "Command Line Tools for Xcode 27.0-27.0" "$(printf '%s\n' "$row" | col 21)"
check "4 CPUs, 8 GB"                 "4${TAB}8" "$(printf '%s\n' "$row" | col 22-23)"
check "its space, its own, and added over its base" "38831345664${TAB}1659764736${TAB}1658654720" "$(printf '%s\n' "$row" | col 24-26)"
check "a macOS image has no cloud image" "-${TAB}-${TAB}-" "$(printf '%s\n' "$row" | col 27-29)"
check "what a guest update adds"     "terminal-pixels,wallpaper" \
    "$(/usr/bin/jq '.needs = [{kind: "full-disk-access"}, {kind: "guest-update", missing: ["terminal-pixels", "wallpaper"]}]' \
        "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 17)"
check "Full Disk Access granted"     "granted" \
    "$(/usr/bin/jq '.fullDiskAccess.granted = true' "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 19)"
check "  never checked: -"           "-${TAB}-" \
    "$(/usr/bin/jq 'del(.fullDiskAccess)' "$FIXTURES_AGENTVM/image-info.json" | lib agentvm_image_info_row | col 19-20)"

section "image info row of a Linux image (image-info-linux.json)"
row="$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info-linux.json")"
name="$(printf '%s\n' "$row" | col 1)"
check "twenty-nine fields"           "29" "$(printf '%s\n' "$row" | field_count)"
check "the first fifteen are status's row of the same image" \
    "$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-linux.json" | row_named "$name")" "$(printf '%s\n' "$row" | col 1-15)"
check "  its screen: a recipe gave it a desktop" "true" "$(printf '%s\n' "$row" | col 15)"
check "its guest daemon's three features" "terminal,time-sync,terminal-pixels" "$(printf '%s\n' "$row" | col 16)"
check "no Full Disk Access to have been checked" "-${TAB}-" "$(printf '%s\n' "$row" | col 19-20)"
check "the compiler, where a macOS image has the Command Line Tools" "build-essential 12.12" "$(printf '%s\n' "$row" | col 21)"
check "4 CPUs, 4 GB"                 "4${TAB}4" "$(printf '%s\n' "$row" | col 22-23)"
check "its space, its own, and added over its base" "3572355072${TAB}1704493056${TAB}1704382464" "$(printf '%s\n' "$row" | col 24-26)"
check "the release it was first built from, no build named, and the cloud image's file" \
    "debian-13${TAB}-${TAB}debian-13-genericcloud-arm64.tar.xz" "$(printf '%s\n' "$row" | col 27-29)"
check "  a build the distribution names" "20261001-2618" \
    "$(/usr/bin/jq '.base.build = "20261001-2618"' "$FIXTURES_AGENTVM/image-info-linux.json" | lib agentvm_image_info_row | col 28)"

section "image info and delete: names agent-vm would refuse are refused first"
fake_reset
with_fake agentvm_image_info "-rf" >/dev/null
check "image info"                   "2" "$?"
with_fake agentvm_image_delete "Dev Tools" >/dev/null
check "image delete"                 "2" "$?"
check "  with the reason"             "yes" "$(lib agentvm_last_error 2 | /usr/bin/grep -q -F '"Dev Tools" is not a valid image name: agent-vm accepts letters, digits' && echo yes)"
check "  and agent-vm never ran"      "" "$(fake_log)"
with_fake agentvm_image_delete dev-acp
check "a valid name reaches agent-vm" "0${TAB}image delete dev-acp --json" "$?${TAB}$(fake_log)"
fake_reset
with_fake agentvm_image_delete Dev-ACP
check "  one with capitals too, as it is" "image delete Dev-ACP --json" "$(fake_log)"

section "box info row (box-info.json)"
row="$(lib agentvm_box_info_row < "$FIXTURES_AGENTVM/box-info.json")"
name="$(printf '%s\n' "$row" | col 1)"
check "twenty-eight fields"          "28" "$(printf '%s\n' "$row" | field_count)"
check "the first twenty-six are status's row of the same box" \
    "$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json" | row_named "$name")" "$(printf '%s\n' "$row" | col 1-26)"
check "its space, and its own"       "40191254528${TAB}2083131392" "$(printf '%s\n' "$row" | col 27-28)"
check "a volume that does not report its own part: -" "-" \
    "$(/usr/bin/jq 'del(.diskUsage.unsharedBytes)' "$FIXTURES_AGENTVM/box-info.json" | lib agentvm_box_info_row | col 28)"
row="$(lib agentvm_box_info_row < "$FIXTURES_AGENTVM/box-info-linux.json")"
check "a Linux box (box-info-linux.json): the first twenty-six are status's row of the same box" \
    "$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-linux.json" | row_named "$(printf '%s\n' "$row" | col 1)")" "$(printf '%s\n' "$row" | col 1-26)"
check "  its screen, and its space and its own" "true${TAB}2044194816${TAB}159846400" "$(printf '%s\n' "$row" | col 26-28)"

section "box commands: names agent-vm would refuse are refused first"
fake_reset
for function in agentvm_box_info agentvm_box_view agentvm_box_recreate agentvm_box_delete agentvm_shell_file; do
    with_fake "$function" "-rf" >/dev/null
    check "$function"                "2" "$?"
done
with_fake agentvm_avm_file "-rf" "$OMCTEST_WORK" >/dev/null
check "agentvm_avm_file"             "2" "$?"
check "  with the reason"            "yes" "$(with_fake agentvm_box_delete "S 3" 2>/dev/null; lib agentvm_last_error 2 | /usr/bin/grep -q -F '"S 3" is not a valid box name' && echo yes)"
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
fake_reset
said="$(with_fake agentvm_box_delete s3)"
check "a box that logged nothing: the delete names no folder of logs, and no problem" "0|-${TAB}-" "$?|$said"
KEPT_S3="/Users/you/Library/Application Support/agent-vm/Logs/s3-20261008T120000Z"
printf '%s\n' "$KEPT_S3" > "$FAKE_AGENTVM_DIR/kept-logs"
said="$(with_fake agentvm_box_delete s3)"
check "a box whose logs agent-vm kept: the delete says where they are" "0|$KEPT_S3${TAB}-" "$?|$said"
printf 'network.jsonl: No space left on device\n' > "$FAKE_AGENTVM_DIR/kept-logs-problem"
said="$(with_fake agentvm_box_delete s3)"
check "  some of them could not be kept: where the others are, and why" "0|$KEPT_S3${TAB}network.jsonl: No space left on device" "$?|$said"
/bin/rm -f "$FAKE_AGENTVM_DIR/kept-logs"
said="$(with_fake agentvm_box_delete s3)"
check "  none could be kept: no folder, and why" "0|-${TAB}network.jsonl: No space left on device" "$?|$said"
/bin/rm -f "$FAKE_AGENTVM_DIR/kept-logs-problem"
printf 'box s3 is running; stop it first\n' > "$FAKE_AGENTVM_DIR/fail-box-delete"
said="$(with_fake agentvm_box_delete s3)"
check "  a delete that is refused says nothing of logs" "1|" "$?|$said"
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

section "a box's programs (box-execlog.json)"
rows="$( TZ=UTC; export TZ; lib agentvm_execlog_rows < "$FIXTURES_AGENTVM/box-execlog.json")"
check "eight fields in every row"    "8" "$(printf '%s\n' "$rows" | field_count)"
check "newest first"                 "claude|/usr/bin/true" \
    "$(printf '%s\n' "$rows" | /usr/bin/sed -n '1p;$p' | col 5 | /usr/bin/paste -sd '|' -)"
check "started, in this Mac's time zone (UTC here); whole seconds; the status; the user" \
    "Sep 30 09:01:00${TAB}47${TAB}1${TAB}agent" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '5p' | col 1-4)"
check "an argument quoted only when it needs it" "/bin/sh -lc 'npm test'" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '5p' | col 5)"
check "  quotes inside one kept" "/bin/sh -c 'exec \"\$SHELL\" -l'" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '3p' | col 5)"
check "no end recorded: no seconds, no status; its client" "-${TAB}-${TAB}70002" \
    "$(printf '%s\n' "$rows" | /usr/bin/sed -n '1p' | /usr/bin/cut -f2,3,6)"
check "the prompts it waited on"     "the Downloads folder; the Desktop folder${TAB}false" \
    "$(printf '%s\n' "$rows" | /usr/bin/sed -n '3p' | col 7-8)"
check "stopped at a prompt"          "true" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '2p' | col 8)"
fake_reset
with_fake agentvm_box_execlog s3 200 >/dev/null
check "what reaches agent-vm"        "box execlog s3 --last 200 --json" "$(fake_log)"
with_fake agentvm_box_execlog s3 "all" >/dev/null
check "a count that is not one is refused" "2" "$?"
with_fake agentvm_box_execlog "-rf" 200 >/dev/null
check "  and a name agent-vm would refuse" "2" "$?"

section "the virtual machine row"
check "none running, two macOS guests at most, no Linux box or image among them" "0${TAB}2${TAB}0${TAB}0" \
    "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status.json")"
check "one running"                  "1${TAB}2${TAB}0${TAB}0" "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status-variety.json")"
check "a count agent-vm could not take is -, and what it does not say of Linux is 0" "-${TAB}2${TAB}0${TAB}0" \
    "$(printf '{"boxes": [], "images": [], "runningVMs": {"limit": 2}}\n' | lib agentvm_status_vm_row)"
check "the Linux boxes among them"   "3${TAB}2${TAB}2${TAB}0" \
    "$(printf '{"runningVMs": {"count": 3, "limit": 2, "linuxBoxes": 2}}\n' | lib agentvm_status_vm_row)"
check "  and the Linux images being built or updated, once agent-vm says them" "4${TAB}2${TAB}2${TAB}1" \
    "$(printf '{"runningVMs": {"count": 4, "limit": 2, "linuxBoxes": 2, "linuxImages": 1}}\n' | lib agentvm_status_vm_row)"

section "the logs of deleted boxes"
check "none kept, held for 30 days, and the folder they would be in" "0${TAB}0${TAB}30${TAB}/Users/you/Library/Application Support/agent-vm/Logs" \
    "$(lib agentvm_status_kept_logs_row < "$FIXTURES_AGENTVM/status.json")"
check "fourteen boxes' logs, what they take, and a store that holds them for a week" "14${TAB}3355443${TAB}7${TAB}/x/Logs" \
    "$(printf '{"keptLogs": {"count": 14, "bytes": 3355443, "holdDays": 7, "directory": "/x/Logs"}}\n' | lib agentvm_status_kept_logs_row)"
check "a store that keeps none"      "0${TAB}0${TAB}0${TAB}/x/Logs" \
    "$(printf '{"keptLogs": {"count": 0, "bytes": 0, "holdDays": 0, "directory": "/x/Logs"}}\n' | lib agentvm_status_kept_logs_row)"
check "an agent-vm that says nothing of them: none, and neither a number of days nor a folder" "0${TAB}0${TAB}-${TAB}-" \
    "$(printf '{"boxes": [], "images": []}\n' | lib agentvm_status_kept_logs_row)"

section "an empty store (status-empty.json)"
check "no box rows"                  "" "$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "no image rows"                "" "$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "no update rows"               "" "$(lib agentvm_status_update_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "and the virtual machines"     "0${TAB}2${TAB}0${TAB}0" "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status-empty.json")"

# -----------------------------------------------------------------------------------------------
section "what agent-vm builds: the Linux systems, and a new image's sizes (version.json)"
check "version --json is asked"      "version --json" "$(fake_reset; with_fake agentvm_version_info >/dev/null; fake_log | /usr/bin/tail -1)"
rows="$(printf '%s\n' '{"linuxReleases": [{"distribution": "debian", "id": "debian-13", "name": "Debian 13", "version": "13"},
    {"distribution": "ubuntu", "id": "ubuntu-26.04", "name": "Ubuntu 26.04", "version": "26.04"}]}' | lib agentvm_linux_release_rows)"
check "a row per Linux system, in agent-vm's order: its id, name, distribution and version" \
    "debian-13${TAB}Debian 13${TAB}debian${TAB}13|ubuntu-26.04${TAB}Ubuntu 26.04${TAB}ubuntu${TAB}26.04" "$(printf '%s\n' "$rows" | /usr/bin/paste -sd '|' -)"
check "the fixture: every system agent-vm says it builds gets a row" "$(/usr/bin/jq -r '.linuxReleases | length' "$FIXTURES_AGENTVM/version.json")" \
    "$(lib agentvm_linux_release_rows < "$FIXTURES_AGENTVM/version.json" | /usr/bin/grep -c .)"
check "an agent-vm that lists none: no rows" "" "$(printf '{"version": "0.7.13"}\n' | lib agentvm_linux_release_rows)"
check "an entry whose id could not be an argument is left out; one with no name is listed under its id" \
    "fedora-42${TAB}fedora-42${TAB}fedora${TAB}-|a.b${TAB}Named${TAB}-${TAB}-" \
    "$(printf '%s\n' '{"linuxReleases": [{"id": "--force", "name": "Option"}, {"id": "Debian 13"}, {"id": "a/b"}, {"id": 13}, {"name": "No id"},
        {"id": "fedora-42", "distribution": "fedora"}, {"id": "a.b", "name": "Named"}, {"id": ""}]}' | lib agentvm_linux_release_rows | /usr/bin/paste -sd '|' -)"
check "  nor one whose id is too long" "" \
    "$(/usr/bin/jq -n '{linuxReleases: [{id: ("a" * 64)}]}' | lib agentvm_linux_release_rows)"
ids=""
for id in debian-13 ubuntu-26.04 a 9 "" -x --linux "debian 13" Debian a_b a/b "a${TAB}b"; do
    lib agentvm_valid_linux_release "$id" && ids="$ids[$id]"
done
check "what can be a Linux system's id: lower-case letters, digits, \".\" and \"-\", not starting with \"-\"" "[debian-13][ubuntu-26.04][a][9]" "$ids"
check "  at most 63 characters"      "0|1" \
    "$(lib agentvm_valid_linux_release "$(printf '%063d' 0)"; echo $?)|$(lib agentvm_valid_linux_release "$(printf '%064d' 0)"; echo $?)"
rows="$(lib agentvm_image_size_rows < "$FIXTURES_AGENTVM/version.json")"
check "a new macOS image: 4 CPUs, 8 GB, a 64 GB disk, 40 GB the smallest, and a copy's disk grows by 8 GB or more" \
    "macos${TAB}4${TAB}8${TAB}64${TAB}40${TAB}8" "$(printf '%s\n' "$rows" | row_named macos)"
check "a new Linux image: 4 CPUs, 4 GB, a 32 GB disk, 8 GB the smallest, and a copy's disk grows by 1 GB or more" \
    "linux${TAB}4${TAB}4${TAB}32${TAB}8${TAB}1" "$(printf '%s\n' "$rows" | row_named linux)"
check "two rows, six fields each"    "2|6" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')|$(printf '%s\n' "$rows" | field_count)"
check "a size agent-vm does not say is \"-\", and one that is not a number too" "linux${TAB}2${TAB}-${TAB}-${TAB}16${TAB}-" \
    "$(printf '%s\n' '{"imageSizes": {"linux": {"cpuCount": 2, "memoryBytes": "4 GB", "minimumDiskBytes": 17179869184}, "macos": 3}}' | lib agentvm_image_size_rows)"
check "an agent-vm that says no sizes: no rows" "" "$(printf '{"version": "0.7.13"}\n' | lib agentvm_image_size_rows)"

section "the longest box name the store allows (version.json)"
check "the fixture's number, as agent-vm says it" "$(/usr/bin/jq -r .maxBoxNameLength "$FIXTURES_AGENTVM/version.json")" \
    "$(lib agentvm_max_box_name_length < "$FIXTURES_AGENTVM/version.json")"
maxes=""
for answer in '{"maxBoxNameLength": 31}' '{"maxBoxNameLength": 0}' '{"maxBoxNameLength": 63}' '{"maxBoxNameLength": 80}' \
        '{"maxBoxNameLength": -1}' '{"maxBoxNameLength": "31"}' '{"version": "0.7.52"}'; do
    maxes="$maxes[$(printf '%s\n' "$answer" | lib agentvm_max_box_name_length)]"
done
check "31 and 0 as said; never more than 63; 63, every name's limit, when agent-vm says none or no number" \
    "[31][0][63][63][63][63][63]" "$maxes"
check "an answer that is not JSON: nothing" "" "$(printf 'not json\n' | lib agentvm_max_box_name_length)"

section "drift: every field the library reads is in the real capture"
# The checks the fixture refresh exists for. A field agent-vm renamed or dropped comes out as
# "-", and these name it instead of letting the window show "-" as an answer. The running fields
# are absent from a capture with every box stopped; status-variety.json carries them, made by hand
# after agent-vm's BoxStatus.
missing="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 3:image 4:netMode 15:cpus 16:memoryGB 17:path 23:guest 24:system 25:systemShort", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no box field is absent" "" "$missing"
check "every box says what it needs, if only nothing" "true" \
    "$(/usr/bin/jq '[.boxes[] | has("needs")] | all' "$FIXTURES_AGENTVM/status.json")"
missing="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 4:macOS 5:macOSBuild 9:guestVersion 10:createdAt 11:path 12:guest 13:system 14:systemShort", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no image field is absent" "" "$missing"
check "no image info field is absent" "" "$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("12:guest 13:system 14:systemShort 16:guestFeatures 18:provisionSeconds 19:fullDiskAccess 20:checkedAt 21:commandLineTools 22:cpus 23:memoryGB 24:bytes 25:unsharedBytes 26:addedBytes", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no box info field is absent" "" "$(lib agentvm_box_info_row < "$FIXTURES_AGENTVM/box-info.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 3:image 15:cpus 16:memoryGB 17:path 23:guest 24:system 25:systemShort 27:bytes 28:unsharedBytes", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
# The same for the real Linux captures: what a Linux record has in place of the macOS fields.
missing="$(lib agentvm_status_image_rows < "$FIXTURES_AGENTVM/status-linux.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 9:guestVersion 10:createdAt 11:path 12:guest 13:system 14:systemShort", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no field of a Linux image is absent" "" "$missing"
missing="$(lib agentvm_status_box_rows < "$FIXTURES_AGENTVM/status-linux.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:name 2:state 3:image 4:netMode 15:cpus 16:memoryGB 17:path 23:guest 24:system 25:systemShort", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "no field of a Linux box is absent" "" "$missing"
check "no field of a Linux image's info is absent" "" "$(lib agentvm_image_info_row < "$FIXTURES_AGENTVM/image-info-linux.json" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("16:guestFeatures 18:provisionSeconds 21:commandLineTools 22:cpus 23:memoryGB 24:bytes 25:unsharedBytes 26:addedBytes 27:release 29:file", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "every Linux image says when its system was last looked at" "true" \
    "$(/usr/bin/jq '[.images[] | has("systemCheckedAt")] | all' "$FIXTURES_AGENTVM/status-linux.json")"
# The update fields are each absent from an image they do not apply to, so the capture is asked
# whether any image has them: it was taken after `status --check-updates` and one `image update`.
check "the update fields are there" "revision updatedAt macOSCheckedAt toolsCheckedAt macOSUpdate recipes " \
    "$(/usr/bin/jq -r '[.images[] | keys[]] | unique as $have
        | ["revision", "updatedAt", "macOSCheckedAt", "toolsCheckedAt", "macOSUpdate", "recipes"][] | select(. as $key | $have | index($key))' \
        "$FIXTURES_AGENTVM/status.json" | /usr/bin/tr '\n' ' ')"
check "the newest macOS is there"    "version build checkedAt " \
    "$(/usr/bin/jq -r '.newestMacOS | keys_unsorted | sort_by(if . == "version" then 0 elif . == "build" then 1 else 2 end)[]' "$FIXTURES_AGENTVM/status.json" | /usr/bin/tr '\n' ' ')"
check "the virtual machine count is there" "0" \
    "$(lib agentvm_status_vm_row < "$FIXTURES_AGENTVM/status.json" | col 1)"
check "what agent-vm keeps of deleted boxes is there" "bytes count directory holdDays " \
    "$(/usr/bin/jq -r '.keptLogs | keys[]' "$FIXTURES_AGENTVM/status.json" | /usr/bin/tr '\n' ' ')"
check "doctor has the checks the window reads" "virtualization disk space running VMs " \
    "$(lib agentvm_doctor_rows < "$FIXTURES_AGENTVM/doctor.json" | col 1 \
        | /usr/bin/grep -x -e virtualization -e 'disk space' -e 'running VMs' | /usr/bin/tr '\n' ' ')"
check "a recipe check has what the New Image window reads: the name, what is asked for, the path, no mistake, the warnings" \
    "xcode${TAB}1${TAB}0${TAB}recipes/xcode/recipe.json${TAB}-${TAB}1|xcode-platforms${TAB}0${TAB}2${TAB}recipes/xcode-platforms/recipe.json${TAB}-${TAB}2|" \
    "$(lib agentvm_recipe_check_rows < "$FIXTURES_AGENTVM/recipe-check.json" | /usr/bin/cut -f1,3-7 | /usr/bin/tr '\n' '|')"
check "  a warning has its place and its message" "input xcode: no step uses AGENT_VM_INPUT_XCODE, yet every build must give the file" \
    "$(lib agentvm_recipe_check_rows < "$FIXTURES_AGENTVM/recipe-check.json" | /usr/bin/sed -n '1p' | col 8)"
check "  and the guest each recipe is for" "macos macos" \
    "$(lib agentvm_recipe_check_rows < "$FIXTURES_AGENTVM/recipe-check.json" | col 9 | /usr/bin/paste -sd ' ' -)"

section "the version rule"
fixture_version="$(/usr/bin/jq -r '.version' "$FIXTURES_AGENTVM/version.json")"
# When this fails after an agent-vm update, refresh the fixtures from the new agent-vm with
# Tests/helpers/refresh_agentvm_fixtures.sh: the app requires exactly the agent-vm it was tested with.
check "AGENTVM_MIN_VERSION is the fixtures' agent-vm (refresh them after an update)" "$fixture_version" "$MIN_VERSION"

omctest_end
