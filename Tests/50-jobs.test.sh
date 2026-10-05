#!/bin/sh
# Tests/50-jobs.test.sh - the library's job functions: starting and stopping a box as a job, the
# rows read from `status`, `job list` and `job log`, a job's events, cancel and forget, and what
# never reaches agent-vm.
#
# The row filter is run on the fixtures directly: job-list.json, a real record (one job that
# failed, captured against an empty store), and jobs-variety.json, made by hand with a job in each
# state. The commands go through the fake, which keeps the jobs it was asked to start.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

REAL="$FIXTURES_AGENTVM/job-list.json"
VARIETY="$FIXTURES_AGENTVM/jobs-variety.json"

# job <id suffix>  ->  the variety's row of the job whose id ends with it.
job() {
    lib agentvm_job_rows < "$VARIETY" | /usr/bin/awk -F'\t' -v s="$1" 'substr($1, length($1) - length(s) + 1) == s'
}

# fake_jobs <jq filter>  ->  that, of the jobs the fake holds.
fake_jobs() {
    /usr/bin/jq -r "$1" "$FAKE_AGENTVM_DIR/jobs.json"
}

# -----------------------------------------------------------------------------------------------
section "a job id"
for id in 20261001-094934-164111 20261001-101504-fc7691 20260930-120001-000001 1; do
    lib agentvm_valid_job_id "$id"
    check "accepted: $id"            "0" "$?"
done
for id in "" "-rf" "--json" "abc" "2026 1" "20261001-094934-164111/.." "20261001_094934" "20261001-101504-FC7691" "20261001-101504-fg7691" "$(printf '2026\n1')" \
    "12345678901234567890123456789012345678901"; do
    lib agentvm_valid_job_id "$id"
    check "refused: [$id]"           "1" "$?"
done

section "job rows: a real record (job-list.json)"
rows="$(lib agentvm_job_rows < "$REAL")"
check "one row"                      "1" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')"
check "sixteen fields"               "16" "$(printf '%s\n' "$rows" | field_count)"
check "its id is a job id"           "0" "$(lib agentvm_valid_job_id "$(printf '%s\n' "$rows" | col 1)"; echo $?)"
check "state, target, what it does, status" "failed${TAB}box:nosuch${TAB}box start${TAB}1" "$(printf '%s\n' "$rows" | col 2-5)"
check "its error, in agent-vm's words" 'no box nosuch; `agent-vm box list` shows the existing ones' "$(printf '%s\n' "$rows" | col 15)"
check "no progress, no notice, nothing it waits for" "-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-${TAB}-" "$(printf '%s\n' "$rows" | /usr/bin/cut -f9-14,16)"

section "job rows: every state (jobs-variety.json)"
rows="$(lib agentvm_job_rows < "$VARIETY")"
check "seven rows, oldest first"     "7|000101|000107" \
    "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')|$(printf '%s\n' "$rows" | /usr/bin/sed -n '1p' | col 1 | /usr/bin/sed 's/.*-//')|$(printf '%s\n' "$rows" | /usr/bin/sed -n '$p' | col 1 | /usr/bin/sed 's/.*-//')"
check "sixteen fields in every row"  "16" "$(printf '%s\n' "$rows" | field_count)"
check "done: the status and when it ended" "done${TAB}box:s3${TAB}box stop${TAB}0${TAB}2026-09-30T11:40:00Z${TAB}2026-09-30T11:40:00Z${TAB}2026-09-30T11:40:09Z" \
    "$(job 000101 | col 2-8)"
check "failed for want of a slot: status 75 and the reason" "failed${TAB}75${TAB}yes" \
    "$(job 000102 | /usr/bin/cut -f2,5)${TAB}$(job 000102 | col 15 | /usr/bin/grep -q 'two virtual machines are running already' && echo yes)"
check "canceled: a download, with no status" "canceled${TAB}ipsw${TAB}image fetch-ipsw${TAB}-" "$(job 000103 | col 2-5)"
check "  and the progress it had reached" "download${TAB}0.31" "$(job 000103 | col 9-10)"
check "lost: agent-vm's words for it" "lost${TAB}the job ended without recording a result: its runner was stopped" "$(job 000104 | /usr/bin/cut -f2,15)"
check "running, a build: step, fraction, index and count" "running${TAB}image:dev-new${TAB}image create${TAB}provision${TAB}0.45${TAB}2${TAB}5" \
    "$(job 000105 | /usr/bin/cut -f2-4,9-12)"
check "  a tab inside its message is a space, so the row keeps its fields" "Running the recipe acp-agents" "$(job 000105 | col 13)"
check "  its notice"                 "Homebrew is already installed in the base image" "$(job 000105 | col 14)"
check "  not ended: no status, no end" "-${TAB}-" "$(job 000105 | /usr/bin/cut -f5,8)"
check "queued: what it waits for, and not started" "queued${TAB}-${TAB}20260930-115800-000105" "$(job 000106 | /usr/bin/cut -f2,7,16)"
check "running, a box starting"      "running${TAB}box:cadabra-spike${TAB}box start${TAB}starting" "$(job 000107 | /usr/bin/cut -f2-4,9)"

section "job rows: from status"
check "status carries the same jobs: the same rows" "$rows" \
    "$(/usr/bin/jq --slurpfile jobs "$VARIETY" '.jobs = $jobs[0]' "$FIXTURES_AGENTVM/status.json" | lib agentvm_job_rows)"
# status.json is a real capture: it carries the jobs that ended within the hour before it, or none.
check "a real status: the field is there, and a row for each of its jobs" \
    "array|$(/usr/bin/jq -r '.jobs | length' "$FIXTURES_AGENTVM/status.json")" \
    "$(/usr/bin/jq -r '.jobs | type' "$FIXTURES_AGENTVM/status.json")|$(lib agentvm_job_rows < "$FIXTURES_AGENTVM/status.json" | /usr/bin/grep -c .)"
check "an empty store: no rows"      "" "$(lib agentvm_job_rows < "$FIXTURES_AGENTVM/status-empty.json")"
check "  nor from a status without the field" "" "$(printf '{"boxes": []}\n' | lib agentvm_job_rows)"
check "no jobs: no rows"             "" "$(printf '[]\n' | lib agentvm_job_rows)"

section "drift: every field the library reads is in the real capture"
# A finished, failed job has no progress, notice or after; the rest must be there, or the windows
# would show "-" as an answer.
check "no job field is absent" "" "$(lib agentvm_job_rows < "$REAL" | /usr/bin/awk -F'\t' '
    BEGIN { n = split("1:id 2:state 3:targets 4:command 5:status 6:createdAt 7:startedAt 8:endedAt 15:error", f, " ") }
    { for (i = 1; i <= n; i++) { split(f[i], p, ":"); if ($p[1] == "-") printf "%s ", p[2] } }')"
check "the hand-made jobs have no field a real job lacks, but those of a job that runs or waits" "after notice progress" \
    "$(/usr/bin/jq -r --slurpfile real "$REAL" '[.[] | keys[]] | unique - ($real[0][0] | keys) | join(" ")' "$VARIETY")"
check "status has jobs"              "true" "$(/usr/bin/jq 'has("jobs")' "$FIXTURES_AGENTVM/status.json")"

# -----------------------------------------------------------------------------------------------
section "starting and stopping a box: what reaches agent-vm"
fake_reset
id="$(with_fake agentvm_job_box_start s3)"
check "start succeeds"              "0" "$?"
check "one call, --json before the --, the command after it" "job start --json -- box start s3" "$(fake_log)"
check "the job's id comes back"      "20260930-120001-000001" "$id"
check "the job runs, for that box"   "running|box:s3|box start s3 --json" "$(fake_jobs '.[0] | [.state, .targets[0], (.command | join(" "))] | join("|")')"
: > "$FAKE_AGENTVM_DIR/log"
id="$(with_fake agentvm_job_box_stop s3)"
check "stop: the call, and a second job" "job start --json -- box stop s3|20260930-120002-000002" "$(fake_log)|$id"

section "names agent-vm would refuse are refused first"
fake_reset
for function in agentvm_job_box_start agentvm_job_box_stop; do
    for name in "-rf" "S3" "a b" "--after"; do
        with_fake "$function" "$name" >/dev/null
        check "$function [$name]"    "2" "$?"
    done
done
check "  with the reason"            "yes" "$(with_fake agentvm_job_box_start "-rf" 2>/dev/null; lib agentvm_last_error 2 | /usr/bin/grep -q -F '"-rf" is not a valid box name' && echo yes)"
check "  and agent-vm never ran"     "" "$(fake_log)"

section "agent-vm refuses to start the job"
fake_reset
printf 'job 20260930-115800-000105 failed, so a job after it would never run\n' > "$FAKE_AGENTVM_DIR/fail-job-start"
id="$(with_fake agentvm_job_box_start s3)"
check "its status"                  "1" "$?"
check "no id"                        "" "$id"
check "its words"                    "job 20260930-115800-000105 failed, so a job after it would never run" "$(lib agentvm_last_error 1)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-job-start"
printf '{"state": "running"}\n' > "$OMCTEST_WORK/no-id.json"
/bin/cat > "$OMCTEST_WORK/agent-vm-no-id.sh" <<EOF
#!/bin/sh
/bin/cat "$OMCTEST_WORK/no-id.json"
EOF
/bin/chmod +x "$OMCTEST_WORK/agent-vm-no-id.sh"
id="$( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/agent-vm-no-id.sh"; export AGENTVM_APP_AGENT_VM; lib agentvm_job_box_start s3 )"
check "an answer with no job id is a failure" "1" "$?"
check "  with no id, and a reason"   "|agent-vm started a job and did not say which." "$id|$(lib agentvm_last_error 1)"
# agent-vm's ids end in six random hex digits; the fake's happen to be digits only.
printf '{"id": "20261001-101504-fc7691", "state": "running"}\n' > "$OMCTEST_WORK/no-id.json"
id="$( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/agent-vm-no-id.sh"; export AGENTVM_APP_AGENT_VM; lib agentvm_job_box_start s3 )"
check "an id with hex digits, as agent-vm makes them, comes back" "0|20261001-101504-fc7691" "$?|$id"

section "a job after another"
fake_reset
first="$(with_fake agentvm_job_box_start s3)"
: > "$FAKE_AGENTVM_DIR/log"
second="$(with_fake _agentvm_job_start "$first" box stop s3)"
check "--after and the id, before the --" "job start --after $first --json -- box stop s3" "$(fake_log)"
check "it waits"                     "queued|$first" "$(/usr/bin/jq -r --arg id "$second" '.[] | select(.id == $id) | [.state, .after] | join("|")' "$FAKE_AGENTVM_DIR/jobs.json")"
: > "$FAKE_AGENTVM_DIR/log"
with_fake _agentvm_job_start "--json" box stop s3 >/dev/null
check "something that is not a job id is not passed as one" "2|" "$?|$(fake_log)"

section "the list, cancel and forget"
check "agentvm_job_list is job list --json" "2" "$(with_fake agentvm_job_list | /usr/bin/jq length)"
check "status carries the jobs too"  "$first $second" "$(with_fake agentvm_status | lib agentvm_job_rows | col 1 | /usr/bin/paste -sd ' ' -)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_job_cancel "$first"
check "cancel succeeds"             "0" "$?"
check "the call"                     "job cancel $first --json" "$(fake_log)"
check "the job ends canceled, and so does the one waiting for it" "canceled canceled" "$(with_fake agentvm_job_list | lib agentvm_job_rows | col 2 | /usr/bin/paste -sd ' ' -)"
with_fake agentvm_job_cancel "$first"
check "cancel of a job that ended: agent-vm's status" "1" "$?"
check "  and its words"              "job $first is not running" "$(lib agentvm_last_error 1)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_job_forget "$first"
check "forget succeeds"             "0" "$?"
check "the call, and the record is gone" "job forget $first --json|$second" "$(fake_log)|$(with_fake agentvm_job_list | lib agentvm_job_rows | col 1)"
third="$(with_fake agentvm_job_box_start try1)"
with_fake agentvm_job_forget "$third"
check "forget of a job that runs: refused by agent-vm" "1|job $third still runs; cancel it first" "$?|$(lib agentvm_last_error 1)"
: > "$FAKE_AGENTVM_DIR/log"
for function in agentvm_job_cancel agentvm_job_forget; do
    for id in "-rf" "--json" "" "s3"; do
        with_fake "$function" "$id"
        check "$function [$id]: refused first" "2" "$?"
    done
done
check "  and agent-vm never ran"     "" "$(fake_log)"

section "a job's log: a real answer (job-log.json)"
LOG="$FIXTURES_AGENTVM/job-log.json"
LOG_VARIETY="$FIXTURES_AGENTVM/job-log-variety.json"
check "the keys the library reads"   "events,job,lines" "$(/usr/bin/jq -r 'keys | join(",")' "$LOG")"
rows="$(lib agentvm_job_rows < "$LOG")"
check "its record is one job row"    "1|16" "$(printf '%s\n' "$rows" | /usr/bin/awk 'END { print NR }')|$(printf '%s\n' "$rows" | field_count)"
check "  the same row job list gives" "$(lib agentvm_job_rows < "$REAL")" "$rows"
check "it failed before any step: no events, no lines" "|" "$(lib agentvm_job_event_rows < "$LOG")|$(lib agentvm_job_lines < "$LOG")"

section "a job's log: a build (job-log-variety.json)"
check "the same keys as the real answer" "$(/usr/bin/jq -r 'keys | join(",")' "$LOG")" "$(/usr/bin/jq -r 'keys | join(",")' "$LOG_VARIETY")"
check "its job row: a build that runs, at its last step" "running${TAB}image:dev-new${TAB}image create${TAB}recipe-step${TAB}3${TAB}3" \
    "$(lib agentvm_job_rows < "$LOG_VARIETY" | /usr/bin/cut -f2-4,9,11,12)"
events="$(lib agentvm_job_event_rows < "$LOG_VARIETY")"
check "thirteen events, eight fields each" "13|8" "$(printf '%s\n' "$events" | /usr/bin/awk 'END { print NR }')|$(printf '%s\n' "$events" | field_count)"
check "the steps, oldest first"      "clone boot recipe recipe-step recipe-step recipe-step" \
    "$(printf '%s\n' "$events" | /usr/bin/awk -F'\t' '$1 == "progress" { print $2 }' | /usr/bin/paste -sd ' ' -)"
check "a step with its fraction, index, count and message" "progress${TAB}recipe-step${TAB}0.3333333333333333${TAB}2${TAB}3${TAB}[2/3] Node${TAB}-${TAB}-" \
    "$(printf '%s\n' "$events" | /usr/bin/sed -n '9p')"
check "a log line of agent-vm's own" "log${TAB}-${TAB}-${TAB}-${TAB}-${TAB}agent-vm-guest 0.6.13 answers over vsock${TAB}-${TAB}-" \
    "$(printf '%s\n' "$events" | /usr/bin/sed -n '3p')"
check "a guest program's line is marked" "==> Installation successful!${TAB}true" "$(printf '%s\n' "$events" | /usr/bin/sed -n '7p' | col 6-7)"
check "a tab inside a line is a space" "a line with a tab in it" "$(printf '%s\n' "$events" | /usr/bin/sed -n '11p' | col 6)"
check "the notice"                   "notice${TAB}Homebrew is already installed in the base image" "$(printf '%s\n' "$events" | /usr/bin/sed -n '8p' | /usr/bin/cut -f1,6)"
check "the other lines"              "warning: a line that is neither an event nor the error" "$(lib agentvm_job_lines < "$LOG_VARIETY")"
check "an answer without events or lines: nothing" "|" "$(printf '{"job": {}}\n' | lib agentvm_job_event_rows)|$(printf '{"job": {}}\n' | lib agentvm_job_lines)"

section "reading a job's log"
fake_reset
id="$(with_fake agentvm_job_box_start s3)"
: > "$FAKE_AGENTVM_DIR/log"
json="$(with_fake agentvm_job_log "$id")"
check "it succeeds"                  "0" "$?"
check "the call"                     "job log $id --json" "$(fake_log)"
check "the job, with no events yet"  "$id${TAB}running|" "$(printf '%s\n' "$json" | lib agentvm_job_rows | col 1-2)|$(printf '%s\n' "$json" | lib agentvm_job_event_rows)"
/usr/bin/jq '{events, lines}' "$LOG_VARIETY" > "$FAKE_AGENTVM_DIR/job-log-$id.json"
json="$(with_fake agentvm_job_log "$id")"
check "a job with a log: its events" "13" "$(printf '%s\n' "$json" | lib agentvm_job_event_rows | /usr/bin/awk 'END { print NR }')"
check "  its record carries the last step and notice, here and in status" \
    "recipe-step${TAB}Homebrew is already installed in the base image|recipe-step${TAB}Homebrew is already installed in the base image" \
    "$(printf '%s\n' "$json" | lib agentvm_job_rows | /usr/bin/cut -f9,14)|$(with_fake agentvm_status | lib agentvm_job_rows | /usr/bin/cut -f9,14)"
with_fake agentvm_job_log 20261001-000000-aaaaaa >/dev/null
check "a job agent-vm no longer keeps: its status" "1" "$?"
check "  and its words"              "yes" "$(lib agentvm_last_error 1 | /usr/bin/grep -q -F 'no job 20261001-000000-aaaaaa' && echo yes)"
: > "$FAKE_AGENTVM_DIR/log"
for bad in "-rf" "--follow" "" "s3" "20261001-000000-aaaaaa/.."; do
    with_fake agentvm_job_log "$bad" >/dev/null
    check "agentvm_job_log [$bad]: refused first" "2" "$?"
done
check "  and agent-vm never ran"     "" "$(fake_log)"

section "the fake refuses what agent-vm refuses"
fake_reset
with_fake _agentvm_job_start - box delete s3 >/dev/null
check "a command that is not a job's: status 64" "64" "$?"
check "  in agent-vm's words"        "yes" "$(lib agentvm_last_error 64 | /usr/bin/grep -q -F 'a job runs image create' && echo yes)"

omctest_end
