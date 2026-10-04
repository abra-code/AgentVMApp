#!/bin/sh
# Tests/11-agentvm-contract.test.sh - the library against a real agent-vm, on an empty store.
#
# The fake answers from fixtures, so it keeps answering the way agent-vm did when they were
# captured. This file runs the real agent-vm through the library, on an empty store in the
# scratch folder, with the commands that start no virtual machine and need no image (one job is started, of a
# box the store does not have, which can only fail): a JSON
# change shows up here before the fake hides it.
#
# Which agent-vm: AGENTVM_APP_CONTRACT_AGENT_VM when set, else the first build in the agent-vm
# working tree beside this repository (../agent-vm/.build/signed/release, then .../work) that is
# at least the library's AGENTVM_MIN_VERSION. The installed ~/.local/bin/agent-vm is out of reach
# on purpose: $HOME here is the scratch home. With none of them, the file fails and says where it
# looked; build agent-vm with its Scripts/build.sh.
#
# Needs the Claude Code sandbox off when an agent runs it: doctor asks the virtualization
# framework, which a sandbox refuses.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

MIN_VERSION="$(lib_value AGENTVM_MIN_VERSION)"
STORE="$OMCTEST_WORK/empty-store"
/bin/mkdir -p "$STORE"
worktree="$(cd "$OMCTEST_TESTS/../../agent-vm" 2>/dev/null && pwd -P)"

section "a real agent-vm, at least $MIN_VERSION"
real=""
tried=""
for candidate in "${AGENTVM_APP_CONTRACT_AGENT_VM:-}" \
        "${worktree:+$worktree/.build/signed/release/agent-vm}" \
        "${worktree:+$worktree/.build/signed/work/agent-vm}"; do
    [ -n "$candidate" ] || continue
    if [ ! -f "$candidate" ] || [ ! -x "$candidate" ]; then
        tried="$tried $candidate (none);"
        continue
    fi
    version="$("$candidate" --version 2>&1)"
    lib agentvm_version_at_least "$version" "$MIN_VERSION"
    new_enough=$?
    if [ "$new_enough" -eq 0 ]; then
        real="$candidate"
        break
    fi
    tried="$tried $candidate ($version);"
done
if [ -z "$real" ]; then
    check "found one (tried:$tried set AGENTVM_APP_CONTRACT_AGENT_VM, or build agent-vm)" "found" "none"
    omctest_end
fi
printf '   using %s\n' "$real" >&2

# real_lib <function> [args...]  ->  the library, running the real agent-vm on the empty store.
real_lib() {
    ( AGENTVM_APP_AGENT_VM="$real"; AGENT_VM_HOME="$STORE"; export AGENTVM_APP_AGENT_VM AGENT_VM_HOME
      lib "$@" )
}

# key_paths <file>  ->  every object key path in a JSON document, array positions left out, one
# per line, sorted. What a field rename or removal changes, and a new value does not.
key_paths() {
    /usr/bin/jq -r '[paths | map(select(type == "string"))] | unique | .[] | join(".")' "$1" | /usr/bin/sort -u
}

# missing_paths <fixture> <real answer>  ->  the key paths of the fixture the real answer lacks.
missing_paths() {
    key_paths "$1" > "$OMCTEST_WORK/fixture.paths"
    key_paths "$2" > "$OMCTEST_WORK/real.paths"
    /usr/bin/comm -23 "$OMCTEST_WORK/fixture.paths" "$OMCTEST_WORK/real.paths" | /usr/bin/tr '\n' ' '
}

section "agentvm_available"
out="$(real_lib agentvm_available)"
check "usable" "0" "$?"
check "  and its version is what --version says" "$("$real" --version 2>&1)" "$out"

section "version --json"
AGENT_VM_HOME="$STORE" "$real" version --json > "$OMCTEST_WORK/version.json" 2>/dev/null
check "answers" "0" "$?"
check "  with the same version" "$out" "$(/usr/bin/jq -r '.version' "$OMCTEST_WORK/version.json")"
check "  and every field the fixture has" "" "$(missing_paths "$FIXTURES_AGENTVM/version.json" "$OMCTEST_WORK/version.json")"

section "status --json on an empty store"
real_lib agentvm_status > "$OMCTEST_WORK/status.json"
check "answers" "0" "$?"
check "  images, boxes and runningVMs, whatever else it adds"   "boxes images runningVMs " \
    "$(/usr/bin/jq -r 'keys[] | select(. == "boxes" or . == "images" or . == "runningVMs")' "$OMCTEST_WORK/status.json" | /usr/bin/tr '\n' ' ')"
check "  every field the empty-store fixture has" "" \
    "$(missing_paths "$FIXTURES_AGENTVM/status-empty.json" "$OMCTEST_WORK/status.json")"
check "  no box rows"   "" "$(lib agentvm_status_box_rows < "$OMCTEST_WORK/status.json")"
check "  no image rows" "" "$(lib agentvm_status_image_rows < "$OMCTEST_WORK/status.json")"
vm_row="$(lib agentvm_status_vm_row < "$OMCTEST_WORK/status.json")"
check "  a VM limit that is a number" "yes" \
    "$(printf '%s\n' "$vm_row" | col 2 | /usr/bin/awk '/^[0123456789]+$/ { print "yes" }')"
check "  a VM count that is a number, or - when processes cannot be listed" "yes" \
    "$(printf '%s\n' "$vm_row" | col 1 | /usr/bin/awk '/^([0123456789]+|-)$/ { print "yes" }')"

section "image info and image delete of an image the store does not have"
# The image detail pane reads the refusal as agent-vm's own message, from its "Error: " line.
real_lib agentvm_image_info nosuch > /dev/null
check "image info fails" "1" "$?"
check "  saying there is no such image" "no image nosuch" "$(lib agentvm_last_error | /usr/bin/cut -d';' -f1)"
real_lib agentvm_image_delete nosuch
check "image delete fails" "1" "$?"
check "  saying there is no such image" "no image nosuch" "$(lib agentvm_last_error | /usr/bin/cut -d';' -f1)"

section "a job, its record and its log"
# One job that can only fail: the empty store has no such box, so nothing starts.
id="$(real_lib agentvm_job_box_start nosuch)"
check "job start answers with a job id" "0|0" "$?|$(lib agentvm_valid_job_id "$id"; echo $?)"
# It ends within a second; its runner records the end a moment later.
state=""
tries=0
while [ "$tries" -lt 20 ]; do
    real_lib agentvm_job_list > "$OMCTEST_WORK/job-list.json"
    state="$(lib agentvm_job_rows < "$OMCTEST_WORK/job-list.json" | row_named "$id" | col 2)"
    [ "$state" = "failed" ] && break
    /bin/sleep 0.5
    tries=$((tries + 1))
done
check "job list shows it failed"  "failed" "$state"
check "  with every field the fixture has" "" "$(missing_paths "$FIXTURES_AGENTVM/job-list.json" "$OMCTEST_WORK/job-list.json")"
real_lib agentvm_status | lib agentvm_job_rows | row_named "$id" | col 2 > "$OMCTEST_WORK/status-job"
check "status carries it too"     "failed" "$(/bin/cat "$OMCTEST_WORK/status-job")"
real_lib agentvm_job_log "$id" > "$OMCTEST_WORK/job-log.json"
check "job log answers"           "0" "$?"
check "  with every field the fixture has" "" "$(missing_paths "$FIXTURES_AGENTVM/job-log.json" "$OMCTEST_WORK/job-log.json")"
check "  events and lines are lists" "array array" "$(/usr/bin/jq -r '[(.events | type), (.lines | type)] | join(" ")' "$OMCTEST_WORK/job-log.json")"
check "  its record is the job list's row" "$(lib agentvm_job_rows < "$OMCTEST_WORK/job-list.json" | row_named "$id")" \
    "$(lib agentvm_job_rows < "$OMCTEST_WORK/job-log.json")"
real_lib agentvm_job_cancel "$id"
check "cancel of a job that ended fails" "1" "$?"
real_lib agentvm_job_forget "$id"
check "forget succeeds"           "0" "$?"
real_lib agentvm_job_log "$id" > /dev/null
check "  and its log is gone"     "1|no job $id" "$?|$(lib agentvm_last_error 1 | /usr/bin/cut -d';' -f1)"

section "doctor --json"
rows="$(real_lib agentvm_doctor)"
check "answers" "0" "$?"
check "  three fields in every row" "3" "$(printf '%s\n' "$rows" | field_count)"
check "  the checks the window reads" "virtualization disk space running VMs " \
    "$(printf '%s\n' "$rows" | col 1 | /usr/bin/grep -x -e virtualization -e 'disk space' -e 'running VMs' | /usr/bin/tr '\n' ' ')"
check "  every status one the library knows" "" \
    "$(printf '%s\n' "$rows" | col 2 | /usr/bin/grep -v -x -e ok -e info -e warning -e failure | /usr/bin/tr '\n' ' ')"
AGENT_VM_HOME="$STORE" "$real" doctor --json > "$OMCTEST_WORK/doctor.json" 2>/dev/null
check "  every field the fixture has" "" "$(missing_paths "$FIXTURES_AGENTVM/doctor.json" "$OMCTEST_WORK/doctor.json")"

section "recipe check --json"
TEST_RECIPES="$OMCTEST_TESTS/fixtures/recipes"
BAD="$OMCTEST_WORK/Bad Recipes"
/bin/mkdir -p "$BAD/team tools"
printf 'not json\n' > "$BAD/broken.json"
printf '%s\n' '{ "version": 1, "steps": [ { "run": "true", "timeout": 3 } ] }' > "$BAD/team tools/recipe.json"
answer="$(real_lib agentvm_recipe_check "$TEST_RECIPES/xcode/recipe.json" "$TEST_RECIPES/xcode-platforms/recipe.json")"
check "recipes it accepts: status 0" "0" "$?"
printf '%s\n' "$answer" > "$OMCTEST_WORK/recipe-check.json"
check "  every field the fixture has" "" "$(missing_paths "$FIXTURES_AGENTVM/recipe-check.json" "$OMCTEST_WORK/recipe-check.json")"
rows="$(printf '%s\n' "$answer" | lib agentvm_recipe_check_rows)"
check "  eight fields in every row"  "8" "$(printf '%s\n' "$rows" | field_count)"
check "  the name, what is asked for, the path as given, and no mistake" \
    "xcode${TAB}1${TAB}0${TAB}$TEST_RECIPES/xcode/recipe.json${TAB}-|xcode-platforms${TAB}0${TAB}2${TAB}$TEST_RECIPES/xcode-platforms/recipe.json${TAB}-|" \
    "$(printf '%s\n' "$rows" | /usr/bin/cut -f1,3-6 | /usr/bin/tr '\n' '|')"
check "  nothing refused in them together" "" "$(printf '%s\n' "$answer" | lib agentvm_recipe_check_error)"
answer="$(real_lib agentvm_recipe_check "$BAD/broken.json" "$BAD/team tools/recipe.json" "$BAD/none.json" "$TEST_RECIPES/node/recipe.json")"
check "recipes it refuses: status 1, with the answer" "1" "$?"
rows="$(printf '%s\n' "$answer" | lib agentvm_recipe_check_rows)"
check "  a row for every file, in the order given" "$BAD/broken.json|$BAD/team tools/recipe.json|$BAD/none.json|$TEST_RECIPES/node/recipe.json|" \
    "$(printf '%s\n' "$rows" | col 5 | /usr/bin/tr '\n' '|')"
check "  the refused ones have a reason and no name, the other its name" "-:why|-:why|-:why|node:-|" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk -F'\t' '{ printf "%s:%s|", $1, ($6 == "-" ? "-" : "why") }')"
check "  the reason names the mistake" "1" "$(printf '%s\n' "$rows" | /usr/bin/sed -n '2p' | col 6 | /usr/bin/grep -c 'unknown key "timeout"')"
# The window lists a recipe under agent-vm's name for it, and the other tests get that name from
# the fake: the two must name a file alike.
/bin/mkdir -p "$BAD/---"
for file in "$BAD/team tools/recipe.json" "$BAD/Extra Things.json" "$BAD/---/recipe.json" "$BAD/noext" "$BAD/a123456789b123456789c123456789d123456789e123456789.json"; do
    printf '{ "version": 1 }\n' > "$file"
done
real_names="$(real_lib agentvm_recipe_check "$BAD/team tools/recipe.json" "$BAD/Extra Things.json" "$BAD/---/recipe.json" "$BAD/noext" "$BAD/a123456789b123456789c123456789d123456789e123456789.json" | lib agentvm_recipe_check_rows | col 1 | /usr/bin/tr '\n' '|')"
check "  a recipe's name: its folder's or its file's, dashes for what cannot be in one, 40 characters" \
    "team-tools|Extra-Things|recipe|noext|a123456789b123456789c123456789d123456789|" "$real_names"
check "  the fake names them alike" "$real_names" \
    "$(with_fake agentvm_recipe_check "$BAD/team tools/recipe.json" "$BAD/Extra Things.json" "$BAD/---/recipe.json" "$BAD/noext" "$BAD/a123456789b123456789c123456789d123456789e123456789.json" | lib agentvm_recipe_check_rows | col 1 | /usr/bin/tr '\n' '|')"

omctest_end
