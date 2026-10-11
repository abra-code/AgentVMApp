#!/bin/sh
# lib.agentvm.progress.sh
#
# A job's progress window (AgentVM.progress.json, the views 701-710): what the job does, the steps
# it went through, the end of its log with two buttons that show all of it, and Stop. One window per job (lib.agentvm.ui.sh, "Box
# windows", with the kind "progress" and the job's id as the name); the id is the window's
# pasteboard value "job", set by the init handler from the open request. It is opened by
# Progress... in the main window's box and image panes while a job holds the box or image.
# Sources lib.agentvm.main.sh for the words that name a job and its outcome.
#
# THE WINDOW ONLY READS THE JOB. The job runs in agent-vm, whether or not this window, or the
# app, is open: closing the window leaves it running, and opening the window again shows where it
# is. Everything shown comes from one call, `job log`: the job's record, its events and its lines.
#
# WHEN IT READS: on opening, on every activation, and every PROGRESS_POLL_SECONDS in a poll loop
# of its own while the job runs or waits. The loop ends with the job (after one last reading),
# with the window, and with the app; a token on the pasteboard makes the newest loop the only one
# that paints, as in the main window.
#
# A STEP is a progress event's step name with its index: agent-vm's names are stable and its
# messages are not, so rows are told apart by name, and shown in the message's words.
#
# THE LOG is short on purpose: the last PROGRESS_LOG_LINES lines, each cut to
# PROGRESS_LOG_WIDTH characters, so that the newest line is always in view without scrolling (a
# text view cannot be scrolled to its end from a script). The whole log is the file "log" in the
# job's folder in the store, where agent-vm keeps it on this Mac: Show Log in Finder selects it
# and Open in Console opens it, while the job runs and after it ended, for as long as agent-vm
# keeps the job. It is also `agent-vm job log <id>` in Terminal, and the window shows the id.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_PROGRESS_LIB:-}" ] && return 0
__AGENTVM_APP_PROGRESS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

PROGRESS_STATUS_ID=701
PROGRESS_ELAPSED_ID=702
PROGRESS_BAR_ID=703
PROGRESS_STEPS_ID=704
PROGRESS_LOG_ID=705
PROGRESS_NOTICE_ID=706
PROGRESS_FOOTER_ID=707
PROGRESS_STOP_ID=708
PROGRESS_LOG_SHOW_ID=709
PROGRESS_LOG_CONSOLE_ID=710

PROGRESS_POLL_SECONDS=2
PROGRESS_LOG_LINES=12
PROGRESS_LOG_WIDTH=100

# progress_job_id <uuid>  ->  the window's job, or nothing when it has none or the value is not a
# job id (it comes back from a pasteboard).
progress_job_id() {
    local _id="$(ui_get job "$1")"
    agentvm_valid_job_id "$_id" || return 0
    printf '%s\n' "$_id"
}

# progress_read <uuid> <id>  ->  0 with the job in the window's cache: job.tsv (agentvm_job_rows'
# row), events.tsv (agentvm_job_event_rows) and lines.txt; or agent-vm's status, with its message
# in the cache file "error" (empty after a success) and what was read before left as it was.
progress_read() {
    local _json
    _json="$(agentvm_job_log "$2")"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$(ui_cache "$1" error)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_job_rows | ui_store "$(ui_cache "$1" job.tsv)"
    printf '%s\n' "$_json" | agentvm_job_event_rows | ui_store "$(ui_cache "$1" events.tsv)"
    printf '%s\n' "$_json" | agentvm_job_lines | ui_store "$(ui_cache "$1" lines.txt)"
    : | ui_store "$(ui_cache "$1" error)"
    return 0
}

# progress_job <uuid>  ->  the job's cached row, or nothing before the first reading.
progress_job() {
    local _file="$(ui_cache "$1" job.tsv)"
    [ -f "$_file" ] || return 0
    /usr/bin/sed -n '1p' "$_file"
}

# progress_log_file <uuid>  ->  the job's whole log, the file "log" in the job's folder, when it is
# on this Mac; nothing before the first reading, or when agent-vm names no folder for the job.
progress_log_file() {
    local _folder="$(progress_job "$1" | /usr/bin/cut -f18)"
    [ -n "$_folder" ] && [ "$_folder" != "-" ] && [ -f "$_folder/log" ] && printf '%s\n' "$_folder/log"
    return 0
}

# progress_moving <uuid>  ->  0 while the job runs or waits, as of the last reading.
progress_moving() {
    case "$(progress_job "$1" | /usr/bin/cut -f2)" in
        running|queued) return 0 ;;
    esac
    return 1
}

# progress_title <job row>  ->  what the job is, for the window's title and the Stop question:
# "Starting box s3", "Updating image dev", "Downloading the macOS restore file".
progress_title() {
    local _target="$(printf '%s\n' "$1" | /usr/bin/cut -f3)"
    local _what="$(printf '%s\n' "$1" | /usr/bin/cut -f4)"
    local _name="${_target#*:}"
    case "$_what" in
        "box start")          printf 'Starting box %s\n' "$_name" ;;
        "box stop")           printf 'Stopping box %s\n' "$_name" ;;
        "image create")       printf 'Building image %s\n' "$_name" ;;
        "image update"|"image update-guest")
                              printf 'Updating image %s\n' "$_name" ;;
        "image setup")        printf 'Setting up image %s\n' "$_name" ;;
        "image view")         printf 'Viewing image %s\n' "$_name" ;;
        "image fetch-ipsw")   printf 'Downloading the macOS restore file\n' ;;
        *)                    printf 'agent-vm %s\n' "$_what" ;;
    esac
}

# progress_capital <text>  ->  the text with its first letter a capital: a box's steps are bare
# words in agent-vm ("starting", "running"). Only an ASCII letter is changed: awk's substr counts
# bytes, and in a UTF-8 locale its toupper stops awk at the first byte of a longer character.
progress_capital() {
    printf '%s\n' "$1" | /usr/bin/awk '{
        first = substr($0, 1, 1)
        if (index("abcdefghijklmnopqrstuvwxyz", first) > 0) first = toupper(first)
        print first substr($0, 2) }'
}

# progress_status_text <uuid>  ->  the window's headline: for a job that runs, its step now, and
# how long that step took last time when agent-vm knows; for one that waits, that it waits; for
# one that ended, how (main_job_outcome's words, with agent-vm's reason after a failure), and what
# an update that did not finish left in the image all the same (progress_kept_text).
progress_status_text() {
    local _job="$(progress_job "$1")"
    local _state="$(printf '%s\n' "$_job" | /usr/bin/cut -f2)"
    case "$_state" in
        queued)
            echo "Waiting for an earlier job to finish."
            return 0 ;;
        running)
            local _last="$(/usr/bin/awk -F'\t' '$1 == "progress" { row = $0 } END { if (row != "") print row }' "$(ui_cache "$1" events.tsv)" 2>/dev/null)"
            if [ -z "$_last" ]; then
                echo "Started; no step reported yet."
                return 0
            fi
            local _text="$(progress_capital "$(printf '%s\n' "$_last" | /usr/bin/cut -f6)")"
            local _expected="$(ui_duration_text "$(printf '%s\n' "$_last" | /usr/bin/cut -f8 | /usr/bin/cut -d. -f1)")"
            [ -n "$_expected" ] && _text="$_text (it took $_expected last time)"
            printf '%s\n' "$_text"
            return 0 ;;
        done)
            printf '%s.\n' "$(main_job_outcome "$_job")"
            return 0 ;;
        canceled)
            printf 'Stopped before it finished.%s\n' "$(progress_kept_text "$1")"
            return 0 ;;
    esac
    local _error="$(printf '%s\n' "$_job" | /usr/bin/cut -f15)"
    [ "$_error" = "-" ] && _error="agent-vm gave no reason."
    local _kept="$(progress_kept_text "$1")"
    # agent-vm's reason may or may not end its sentence.
    case "$_error" in
        *[.!?]) ;;
        *) [ -n "$_kept" ] && _error="$_error." ;;
    esac
    printf '%s: %s%s\n' "$(main_job_outcome "$_job")" "$_error" "$_kept"
}

# progress_elapsed_text <uuid>  ->  "Elapsed 2 min" for a job that runs, "took 2 min" for one that
# ended after starting, nothing for one that waits or never started.
progress_elapsed_text() {
    local _job="$(progress_job "$1")"
    local _since="$(ui_seconds_since_epoch "$(printf '%s\n' "$_job" | /usr/bin/cut -f7)")"
    [ -n "$_since" ] || return 0
    local _seconds
    case "$(printf '%s\n' "$_job" | /usr/bin/cut -f2)" in
        queued) return 0 ;;
        running)
            _seconds=$(( $(main_now) - _since ))
            [ "$_seconds" -ge 0 ] && printf 'Elapsed %s\n' "$(ui_duration_text "$_seconds")" ;;
        *)
            local _until="$(ui_seconds_since_epoch "$(printf '%s\n' "$_job" | /usr/bin/cut -f8)")"
            [ -n "$_until" ] || return 0
            _seconds=$(( _until - _since ))
            [ "$_seconds" -ge 0 ] && printf 'took %s\n' "$(ui_duration_text "$_seconds")" ;;
    esac
    return 0
}

# progress_step_rows <uuid>  ->  the steps table's rows, oldest first: the step in agent-vm's
# words, and how far it is. A step is a progress event's name with its index; events of the same
# step move its row on. Every step but the last is done; the last is where the job is ("40%",
# or "running"), or where it ended ("done", "failed", "stopped").
progress_step_rows() {
    local _events="$(ui_cache "$1" events.tsv)"
    [ -f "$_events" ] || return 0
    /usr/bin/awk -F'\t' -v state="$(progress_job "$1" | /usr/bin/cut -f2)" '
        $1 == "progress" {
            key = $2 "\t" $4
            if (n == 0 || key != last) { n++; last = key }
            # A capital for an ASCII letter only, as in progress_capital.
            first = substr($6, 1, 1)
            if (index("abcdefghijklmnopqrstuvwxyz", first) > 0) first = toupper(first)
            text[n] = first substr($6, 2)
            fraction[n] = $3
        }
        END {
            for (i = 1; i <= n; i++) {
                how = "done"
                if (i == n) {
                    if (state == "running") how = (fraction[i] != "-") ? sprintf("%d%%", fraction[i] * 100 + 0.5) : "running"
                    else if (state == "failed" || state == "lost") how = "failed"
                    else if (state == "canceled") how = "stopped"
                }
                printf "%s\t%s\n", text[i], how
            }
        }' "$_events"
}

# progress_daemon_kept <uuid>  ->  0 when the job's events show an image update whose first part
# is in place and whose second has begun: a disk put in place (commit), then a boot. agent-vm
# updates the guest daemon first, as an update of its own, when it was asked for with the system
# or the tools, so that is the daemon's update, and nothing that happens later takes it back.
progress_daemon_kept() {
    local _events="$(ui_cache "$1" events.tsv)"
    [ -f "$_events" ] || return 1
    /usr/bin/awk -F'\t' '
        $1 == "progress" && $2 == "commit" { placed = 1 }
        $1 == "progress" && $2 == "boot" && placed { kept = 1 }
        END { exit kept ? 0 : 1 }' "$_events"
}

# progress_kept_text <uuid>  ->  what a failed or stopped image update left in the image all the
# same, as a sentence with a space before it, or nothing.
progress_kept_text() {
    case "$(progress_job "$1" | /usr/bin/cut -f4)" in
        "image update") ;;
        *) return 0 ;;
    esac
    progress_daemon_kept "$1" && printf ' The guest daemon was updated before that, and stays.'
    return 0
}

# progress_percent <uuid>  ->  how far the step the job is at has come, 0-100, when the job runs
# and its last progress event says; nothing otherwise.
progress_percent() {
    [ "$(progress_job "$1" | /usr/bin/cut -f2)" = "running" ] || return 0
    /usr/bin/awk -F'\t' '$1 == "progress" { fraction = $3 }
        END { if (fraction != "" && fraction != "-") printf "%d\n", fraction * 100 + 0.5 }' "$(ui_cache "$1" events.tsv)" 2>/dev/null
}

# progress_notice_past <uuid>  ->  0 when the job has gone on to another step since its last
# notice was written. A step is a progress event's name with its index, as in progress_step_rows.
# A notice written before the job's first step is past once the second begins: agent-vm says
# such a one just before the step it is about. Steps are counted, not compared by name: a job
# comes to a step of the same name again (a second shutdown, a second boot), and that is not
# the step the notice was written in.
progress_notice_past() {
    local _events="$(ui_cache "$1" events.tsv)"
    [ -f "$_events" ] || return 1
    /usr/bin/awk -F'\t' '
        $1 == "progress" { step = $2 "\t" $4; if (step != last) { steps++; last = step } }
        $1 == "notice" { seen = 1; count = steps + 0 }
        END { exit (seen && steps + 0 != count && !(count == 0 && steps == 1)) ? 0 : 1 }' "$_events"
}

# progress_notice_now <uuid>  ->  the job's last notice, while the job is at the step it was
# written in, or nothing. A job whose events hold no notice (agent-vm keeps the record's notice
# apart from them) has the record's. Nothing for a job that ended well: its notices were of
# things that were overcome, and stay in the log.
progress_notice_now() {
    local _job="$(progress_job "$1")"
    local _notice="$(printf '%s\n' "$_job" | /usr/bin/cut -f14)"
    [ -n "$_notice" ] && [ "$_notice" != "-" ] || return 0
    [ "$(printf '%s\n' "$_job" | /usr/bin/cut -f2)" != "done" ] || return 0
    progress_notice_past "$1" && return 0
    printf '%s\n' "$_notice"
}

# progress_notice_text <uuid>  ->  the notice line: the job's last notice, until the job ends
# well. A notice says what the user may need to act on. Some are of the step they were written
# in ("this Mac is not letting agent-vm reach the guest... The build keeps trying"), and would
# read as something still wrong once the job has gone on; others are said before the steps they
# are about ("this Mac has about 3 GB of memory to spare... If it fails, quit programs that use
# much memory"), and must not be gone when the next step begins. The window cannot tell them
# apart, and agent-vm's words are not matched on, so a notice of a step the job has left stays,
# and is said to be from an earlier step. It is in the log as well then (progress_log_text).
progress_notice_text() {
    local _now="$(progress_notice_now "$1")"
    if [ -n "$_now" ]; then
        printf '%s\n' "$_now"
        return 0
    fi
    local _job="$(progress_job "$1")"
    local _notice="$(printf '%s\n' "$_job" | /usr/bin/cut -f14)"
    [ -n "$_notice" ] && [ "$_notice" != "-" ] || return 0
    [ "$(printf '%s\n' "$_job" | /usr/bin/cut -f2)" != "done" ] || return 0
    printf 'From an earlier step: %s\n' "$_notice"
}

# progress_log_text <uuid>  ->  the end of the job's log: its log events (agent-vm's own lines and
# what programs in the guest printed) with the notices among them, where they were written,
# except the last notice while the job is at its step and the notice line shows it
# (progress_notice_now); then the lines
# that were neither an event nor the error,
# then the error of a job that failed, as `job log` prints them; the last PROGRESS_LOG_LINES, each
# cut to PROGRESS_LOG_WIDTH characters. jq makes the cut, since it counts characters: awk counts
# bytes, and a line cut inside a character is not valid text, which the window is never given.
progress_log_text() {
    local _job="$(progress_job "$1")"
    {
        /usr/bin/awk -F'\t' -v shown="$(progress_notice_now "$1")" '
            $1 == "log" || $1 == "notice" { line[++n] = $6; if ($1 == "notice") last = n }
            END { for (i = 1; i <= n; i++) if (!(i == last && shown != "")) print line[i] }' \
            "$(ui_cache "$1" events.tsv)" 2>/dev/null
        /bin/cat "$(ui_cache "$1" lines.txt)" 2>/dev/null
        case "$(printf '%s\n' "$_job" | /usr/bin/cut -f2)" in
            failed|lost|canceled)
                local _error="$(printf '%s\n' "$_job" | /usr/bin/cut -f15)"
                [ "$_error" != "-" ] && [ -n "$_error" ] && printf 'Error: %s\n' "$_error" ;;
        esac
    } | /usr/bin/tail -n "$PROGRESS_LOG_LINES" | /usr/bin/jq -Rr --argjson width "$PROGRESS_LOG_WIDTH" '
        if length > $width then .[0:$width - 3] + "..." else . end'
}

# progress_paint <uuid>  ->  the window from its cache. Before the first reading succeeded there
# is nothing to show but why (agent-vm keeps a finished job for a week, and one may be forgotten).
progress_paint() {
    local _uuid="$1"
    local _id="$(progress_job_id "$_uuid")"
    [ -n "$_id" ] || return 0
    local _job="$(progress_job "$_uuid")"
    local _error="$(/bin/cat "$(ui_cache "$_uuid" error)" 2>/dev/null)"
    if [ -z "$_job" ]; then
        "$dialog" "$_uuid" "$PROGRESS_STATUS_ID" "${_error:-The job has not been read yet.}"
        "$dialog" "$_uuid" "$PROGRESS_ELAPSED_ID" ""
        ui_show "$_uuid" "$PROGRESS_BAR_ID" 0
        ui_enable "$_uuid" "$PROGRESS_STOP_ID" 0
        ui_enable "$_uuid" "$PROGRESS_LOG_SHOW_ID" 0
        ui_enable "$_uuid" "$PROGRESS_LOG_CONSOLE_ID" 0
        "$dialog" "$_uuid" "$PROGRESS_FOOTER_ID" "Job $_id"
        return 0
    fi
    "$dialog" "$_uuid" omc_window "$(progress_title "$_job")"
    "$dialog" "$_uuid" "$PROGRESS_STATUS_ID" "$(progress_status_text "$_uuid")"
    "$dialog" "$_uuid" "$PROGRESS_ELAPSED_ID" "$(progress_elapsed_text "$_uuid")"
    local _percent="$(progress_percent "$_uuid")"
    if [ -n "$_percent" ]; then
        "$dialog" "$_uuid" "$PROGRESS_BAR_ID" "$_percent"
        ui_show "$_uuid" "$PROGRESS_BAR_ID" 1
    else
        ui_show "$_uuid" "$PROGRESS_BAR_ID" 0
    fi
    progress_step_rows "$_uuid" | "$dialog" "$_uuid" "$PROGRESS_STEPS_ID" omc_table_set_rows_from_stdin
    "$dialog" "$_uuid" "$PROGRESS_LOG_ID" "$(progress_log_text "$_uuid")"
    # The whole log, in Finder and in Console, once its file is on this Mac.
    if [ -n "$(progress_log_file "$_uuid")" ]; then
        ui_enable "$_uuid" "$PROGRESS_LOG_SHOW_ID" 1
        ui_enable "$_uuid" "$PROGRESS_LOG_CONSOLE_ID" 1
    else
        ui_enable "$_uuid" "$PROGRESS_LOG_SHOW_ID" 0
        ui_enable "$_uuid" "$PROGRESS_LOG_CONSOLE_ID" 0
    fi
    # The last notice, until the job ends well, and under it why the job could
    # not be read this time, if it could not: what is shown is then from the reading before.
    local _notice="$(progress_notice_text "$_uuid")"
    if [ -n "$_error" ]; then
        if [ -n "$_notice" ]; then
            _notice="$(printf '%s\n%s' "$_notice" "$_error")"
        else
            _notice="$_error"
        fi
    fi
    "$dialog" "$_uuid" "$PROGRESS_NOTICE_ID" "$_notice"
    if progress_moving "$_uuid"; then
        ui_enable "$_uuid" "$PROGRESS_STOP_ID" 1
        "$dialog" "$_uuid" "$PROGRESS_FOOTER_ID" "Job $_id. You can close this window: the job goes on."
    else
        ui_enable "$_uuid" "$PROGRESS_STOP_ID" 0
        "$dialog" "$_uuid" "$PROGRESS_FOOTER_ID" "Job $_id"
    fi
}

# progress_refresh <uuid>  ->  the job read again, and the window painted.
progress_refresh() {
    local _id="$(progress_job_id "$1")"
    [ -n "$_id" ] || return 0
    progress_read "$1" "$_id"
    progress_paint "$1"
    # The window closed while agent-vm was being read: the close handler has removed the cache
    # folder, and the reading above made it again.
    local _poll="$(ui_get poll "$1")"
    [ "$_poll" = "closed" ] && ui_cache_clear "$1"
    return 0
}

# progress_poll_running <uuid>  ->  0 when a poll loop holds the window's token and its process is
# alive (a loop that was killed leaves its token behind).
progress_poll_running() {
    local _holder="$(ui_get poll "$1")"
    case "$_holder" in
        poll-[0123456789]*) kill -0 "${_holder#poll-}" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

# progress_poll <uuid>  ->  the poll loop (see the header). Returns when the job has ended, a newer
# loop took over, the window closed, or the app is gone. AGENTVM_APP_POLL_PASSES, for the tests,
# ends it after that many passes.
progress_poll() {
    local _uuid="$1"
    local _token="poll-$$"
    local _current="$(ui_get poll "$_uuid")"
    [ "$_current" = "closed" ] && return 0
    ui_set poll "$_uuid" "$_token"
    local _passes=0
    local _holder
    while ui_app_alive; do
        progress_moving "$_uuid" || break
        # Wait first: whatever chained the loop has just painted.
        "$sleep_tool" "$PROGRESS_POLL_SECONDS"
        _holder="$(ui_get poll "$_uuid")"
        [ "$_holder" = "$_token" ] || return 0
        ui_app_alive || break
        progress_refresh "$_uuid"
        _passes=$((_passes + 1))
        if [ -n "${AGENTVM_APP_POLL_PASSES:-}" ] && [ "$_passes" -ge "$AGENTVM_APP_POLL_PASSES" ]; then
            break
        fi
    done
    _holder="$(ui_get poll "$_uuid")"
    [ "$_holder" = "$_token" ] && ui_set poll "$_uuid" ""
    return 0
}

# progress_stop_question <job row> [uuid]  ->  the Stop question's message: what stopping leaves
# behind. With the window's uuid, an update whose guest daemon is already in place says that it
# stays (progress_daemon_kept).
progress_stop_question() {
    local _text="agent-vm stops the job at its next safe point, which can take up to a minute."
    case "$(printf '%s\n' "$1" | /usr/bin/cut -f4)" in
        "image create")
            _text="$_text The image is left marked failed: it can be deleted, or built again." ;;
        "image update"|"image update-guest")
            if [ -n "${2:-}" ] && progress_daemon_kept "$2"; then
                _text="$_text The guest daemon is already updated, and stays; the rest of the image stays as it was."
            else
                _text="$_text The image stays as it was before the update."
            fi ;;
        "image fetch-ipsw")
            _text="$_text What was downloaded is kept for the next time." ;;
        "image view")
            _text="Closing the image's window does the same: the image shuts down, and what was done in it is kept." ;;
        "box start")
            _text="$_text The box is left stopped." ;;
    esac
    printf '%s\n' "$_text"
}
