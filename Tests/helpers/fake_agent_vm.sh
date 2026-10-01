#!/bin/sh
# Tests/helpers/fake_agent_vm.sh - agent-vm, answered from files.
#
# Copied from Cadabra's Tests/helpers/fake_agent_vm.sh (AIChatApp, 2026-09-29) and cut down to
# the commands AgentVM.app runs so far; the long commands and their progress events come back
# with the jobs. The same state-directory conventions, so a test written against one reads
# naturally against the other.
#
# lib.agentvm.sh runs agent-vm through agentvm_bin, and AGENTVM_APP_AGENT_VM points that here.
# The real agent-vm needs macOS 27, a store of multi-GB images and virtual machines, and answers
# differently on every Mac; this answers the same way every time, from JSON captured from a real
# agent-vm (Tests/fixtures/agentvm/, see the README there), and it can fail on request.
#
# -- The state directory ($FAKE_AGENTVM_DIR) ----------------------------------------------------
#   log        APPENDED to, one line per invocation: the arguments, space-joined.
#   home       REWRITTEN each invocation: AGENT_VM_HOME as the fake saw it, or "(unset)".
#   exit       when present, every invocation prints the file "stderr" (if any) to stderr and
#              exits with this status, before looking at its arguments.
#   fail-<a>   when present, the command "<a>" (fail-status, fail-doctor) prints "Error: " and
#              the file's text to stderr and exits 1, or with the status in fail-<a>-status
#              when that is present. fail-<a>-<b> does the same for a two-word command only
#              (fail-image-delete), and is looked at first.
#   version    what --version prints (default: AGENTVM_MIN_VERSION from the library, the oldest
#              version the app accepts, so raising it needs no change here).
#   <key>.json the answer to one query, overriding the fixture of that name: version, doctor,
#              status, image-info-<name>, box-info-<name>. The fixtures image-info.json and
#              box-info.json answer `image info` and `box info` for the one image or box each
#              describes; any other name is not found, as agent-vm says it.
#   jobs.json  the jobs: what `job list` answers and what `status` carries as its `jobs`. `job start`
#              appends a running job (queued with --after a job that has not ended), with ids
#              20260930-120001-000001, -120002-000002 and so on; `job cancel` and `job forget`
#              change it as agent-vm would. A job never ends by itself: the test edits jobs.json
#              (and status.json, for what the job did) to move it on.
#   job-start-state  when present, the state a job is in as `job start` returns ("failed"), with
#              the text of job-start-error as its error: a job that fails within the moment.
#
# -- What it implements -------------------------------------------------------------------------
#   --version, version --json, doctor --json, status --json, image info <name> --json,
#   image delete <name> --json, box delete <name> --json and box recreate <name> --json (which
#   change nothing: the test changes status.json to match), box info <name> --json, and
#   box view <name> [--interactive] --json (which shows nothing), box packs --json,
#   box network <name> [--net <mode>] [--allow <rule> ...] [--disallow <rule> ...] --json (the
#   rules from box-network-<name>.json in the state directory, else the fixture box-network.json;
#   a change is applied to them and written to box-network-<name>.json, as agent-vm would keep
#   it), box netlog <name> --last <n> --json (box-netlog-<name>.json in the state directory,
#   else the fixture box-netlog.json), and box execlog <name> --last <n> --json
#   (box-execlog-<name>.json in the state directory, else the fixture box-execlog.json), and
#   job start [--after <id>] --json -- <command...>, job list --json, job cancel <id> --json and
#   job forget <id> --json (see jobs.json above).
# Anything else fails with status 64, so a test that reaches an unimplemented command finds out.

state="${FAKE_AGENTVM_DIR:?fake_agent_vm: FAKE_AGENTVM_DIR is not set}"
fixtures="${FAKE_AGENTVM_FIXTURES:-$(/usr/bin/dirname "$0")/../fixtures/agentvm}"
agentvm_library="${OMC_APP_BUNDLE_PATH:-$(/usr/bin/dirname "$0")/../../AgentVM.app}/Contents/Resources/Scripts/lib.agentvm.sh"
[ -d "$state" ] || /bin/mkdir -p "$state"

printf '%s\n' "$*" >> "$state/log"
if [ -n "${AGENT_VM_HOME+set}" ]; then
    printf '%s\n' "$AGENT_VM_HOME" > "$state/home"
else
    printf '(unset)\n' > "$state/home"
fi

if [ -f "$state/exit" ]; then
    [ -f "$state/stderr" ] && /bin/cat "$state/stderr" >&2
    exit "$(/bin/cat "$state/exit")"
fi
if [ -n "$1" ] && [ -n "$2" ] && [ -f "$state/fail-$1-$2" ]; then
    printf 'Error: %s\n' "$(/bin/cat "$state/fail-$1-$2")" >&2
    if [ -f "$state/fail-$1-$2-status" ]; then
        exit "$(/bin/cat "$state/fail-$1-$2-status")"
    fi
    exit 1
fi
if [ -n "$1" ] && [ -f "$state/fail-$1" ]; then
    printf 'Error: %s\n' "$(/bin/cat "$state/fail-$1")" >&2
    if [ -f "$state/fail-$1-status" ]; then
        exit "$(/bin/cat "$state/fail-$1-status")"
    fi
    exit 1
fi

# answer <key> - the state directory's <key>.json, else the fixture of that name.
answer() {
    if [ -f "$state/$1.json" ]; then
        /bin/cat "$state/$1.json"
    else
        /bin/cat "$fixtures/$1.json"
    fi
}

# jobs  ->  the fake's jobs: jobs.json in the state directory, else none.
jobs() {
    if [ -f "$state/jobs.json" ]; then
        /bin/cat "$state/jobs.json"
    else
        printf '[]\n'
    fi
}

case "$*" in
    "--version")
        if [ -f "$state/version" ]; then
            /bin/cat "$state/version"
        else
            /usr/bin/sed -n 's/^AGENTVM_MIN_VERSION="\(.*\)"$/\1/p' "$agentvm_library"
        fi ;;
    "version --json")
        answer version ;;
    "doctor --json")
        answer doctor ;;
    "status --json")
        # The jobs the fake holds, when it holds any, are the store's jobs.
        if [ -f "$state/jobs.json" ]; then
            answer status | /usr/bin/jq --slurpfile jobs "$state/jobs.json" '.jobs = $jobs[0]'
        else
            answer status
        fi ;;
    "image info "*" --json")
        if [ -f "$state/image-info-$3.json" ]; then
            /bin/cat "$state/image-info-$3.json"
        else
            described="$(/usr/bin/jq -r .name "$fixtures/image-info.json")"
            if [ "$described" != "$3" ]; then
                printf 'Error: no image %s; `agent-vm image list` shows the existing ones\n' "$3" >&2
                exit 1
            fi
            /bin/cat "$fixtures/image-info.json"
        fi ;;
    "image delete "*" --json")
        ;;
    "box info "*" --json")
        if [ -f "$state/box-info-$3.json" ]; then
            /bin/cat "$state/box-info-$3.json"
        else
            described="$(/usr/bin/jq -r .box.name "$fixtures/box-info.json")"
            if [ "$described" != "$3" ]; then
                printf 'Error: no box %s; `agent-vm box list` shows the existing ones\n' "$3" >&2
                exit 1
            fi
            /bin/cat "$fixtures/box-info.json"
        fi ;;
    "box packs --json")
        answer packs ;;
    "box network "*)
        box="$3"
        shift 3
        rules="$state/box-network-$box.json"
        [ -f "$rules" ] || /bin/cat "$fixtures/box-network.json" > "$rules"
        while [ "$#" -gt 1 ]; do
            case "$1" in
                --net)      edit='.mode = $v' ;;
                --allow)    edit='(.allow // []) as $a | .allow = (if ($a | any(. == $v)) then $a else $a + [$v] end)' ;;
                --disallow) edit='.allow = ((.allow // []) - [$v])' ;;
                *)          printf 'Error: fake_agent_vm does not implement box network %s\n' "$1" >&2
                            exit 64 ;;
            esac
            /usr/bin/jq --arg v "$2" "$edit" "$rules" > "$rules.new" && /bin/mv "$rules.new" "$rules"
            shift 2
        done
        [ "$1" = "--json" ] || exit 64
        /bin/cat "$rules" ;;
    "box netlog "*" --last "*" --json")
        if [ -f "$state/box-netlog-$3.json" ]; then
            /bin/cat "$state/box-netlog-$3.json"
        else
            /bin/cat "$fixtures/box-netlog.json"
        fi ;;
    "box execlog "*" --last "*" --json")
        if [ -f "$state/box-execlog-$3.json" ]; then
            /bin/cat "$state/box-execlog-$3.json"
        else
            /bin/cat "$fixtures/box-execlog.json"
        fi ;;
    "box delete "*" --json"|"box recreate "*" --json"|"box view "*" --json"|"box view "*" --interactive --json")
        ;;
    "job start "*)
        shift 2
        after=""
        [ "$1" = "--json" ] && shift
        if [ "$1" = "--after" ]; then
            after="$2"
            shift 2
        fi
        [ "$1" = "--json" ] && shift
        [ "$1" = "--" ] || exit 64
        shift
        case "$1 $2" in
            "image create"|"image update"|"image update-guest"|"image setup"|"image fetch-ipsw"|"box start"|"box stop") ;;
            *)  printf 'Error: a job runs image create, image update, image update-guest, image setup, image fetch-ipsw, box start and box stop; not `%s`\n' "$*" >&2
                exit 64 ;;
        esac
        job_state="running"
        # job-start-state, when present: the state the new job is already in when `job start`
        # returns, with job-start-error as its error (a job that fails within the moment).
        [ -f "$state/job-start-state" ] && job_state="$(/bin/cat "$state/job-start-state")"
        if [ -n "$after" ]; then
            after_state="$(jobs | /usr/bin/jq -r --arg id "$after" '.[] | select(.id == $id) | .state')"
            case "$after_state" in
                "")     printf 'Error: %s is not a job id (`agent-vm job list` shows them)\n' "$after" >&2
                        exit 1 ;;
                failed|canceled|lost)
                        printf 'Error: job %s %s, so a job after it would never run\n' "$after" "$after_state" >&2
                        exit 1 ;;
                done)   ;;
                *)      job_state="queued" ;;
            esac
        fi
        count="$(/bin/cat "$state/job-count" 2>/dev/null)"
        count=$(( ${count:-0} + 1 ))
        printf '%s\n' "$count" > "$state/job-count"
        id="$(printf '20260930-1200%02d-%06d' "$count" "$count")"
        case "$1" in
            box)   target="box:$3" ;;
            image) target="image:$3"
                   [ "$2" = "fetch-ipsw" ] && target="ipsw" ;;
        esac
        printf '%s\n' "$@" | /usr/bin/jq -R . | /usr/bin/jq -s --arg id "$id" --arg state "$job_state" --arg target "$target" --arg after "$after" \
            --arg error "$(/bin/cat "$state/job-start-error" 2>/dev/null)" '
            { command: (if any(. == "--json") then . else . + ["--json"] end), createdAt: "2026-09-30T12:00:00Z", id: $id,
              path: ("/Users/you/Library/Application Support/agent-vm/Jobs/" + $id), state: $state, targets: [$target] }
            | if $state != "queued" then .startedAt = "2026-09-30T12:00:00Z" else . end
            | if $state == "failed" then . + {endedAt: "2026-09-30T12:00:01Z", status: 1, error: $error} else . end
            | if $after != "" then .after = $after else . end' > "$state/job-new.json"
        jobs | /usr/bin/jq --slurpfile new "$state/job-new.json" '. + $new' > "$state/jobs.json.new" \
            && /bin/mv "$state/jobs.json.new" "$state/jobs.json"
        /bin/cat "$state/job-new.json"
        /bin/rm -f "$state/job-new.json" ;;
    "job list --json")
        jobs ;;
    "job cancel "*" --json"|"job forget "*" --json")
        job_state="$(jobs | /usr/bin/jq -r --arg id "$3" '.[] | select(.id == $id) | .state')"
        if [ -z "$job_state" ]; then
            printf 'Error: %s is not a job id (`agent-vm job list` shows them)\n' "$3" >&2
            exit 1
        fi
        jobs | /usr/bin/jq --arg id "$3" '.[] | select(.id == $id)' > "$state/job-was.json"
        case "$2 $job_state" in
            "cancel running"|"cancel queued")
                # The job ends canceled, and so does every job queued after it.
                jobs | /usr/bin/jq --arg id "$3" '
                    def ended: . + {state: "canceled", endedAt: "2026-09-30T12:00:30Z", error: "canceled"};
                    map(if .id == $id then ended elif .after == $id and .state == "queued"
                        then ended + {error: ("job " + $id + " was canceled")} else . end)' > "$state/jobs.json.new" \
                    && /bin/mv "$state/jobs.json.new" "$state/jobs.json"
                jobs | /usr/bin/jq --arg id "$3" '.[] | select(.id == $id)' ;;
            "cancel "*)
                printf 'Error: job %s is not running\n' "$3" >&2
                exit 1 ;;
            "forget running"|"forget queued")
                printf 'Error: job %s still runs; cancel it first\n' "$3" >&2
                exit 1 ;;
            *)
                jobs | /usr/bin/jq --arg id "$3" 'map(select(.id != $id))' > "$state/jobs.json.new" \
                    && /bin/mv "$state/jobs.json.new" "$state/jobs.json"
                /bin/cat "$state/job-was.json" ;;
        esac
        /bin/rm -f "$state/job-was.json" ;;
    *)
        printf 'Error: fake_agent_vm does not implement: %s\n' "$*" >&2
        exit 64 ;;
esac
