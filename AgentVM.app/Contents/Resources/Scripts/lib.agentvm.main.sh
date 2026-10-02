#!/bin/sh
# lib.agentvm.main.sh
#
# The main window (AgentVM.json): its view ids, what it reads from agent-vm, and how it paints.
#
# TWO FACES in one ZStack, one visible at a time: Get started while agent-vm cannot be used,
# doctor reports a failure, or there is no ready image or no box; Status otherwise. Every refresh
# picks again, so the window moves between them by itself as the store fills or agent-vm goes
# missing. No face is ever remembered: it is computed from what agent-vm answers.
#
# THE STATUS FACE is a TabView: Boxes, Images and Settings. Boxes and Images are each a split
# view with a list of cards in the sidebar and the selected card's details beside it. A card
# carries what is checked at a glance (name, state, image or macOS, and a "Needs maintenance"
# mark); the detail pane has the rest, including what the maintenance is. Settings shows which
# agent-vm runs and what this Mac has room for.
#
# A DETAIL PANE IS AN OVERVIEW. What has work of its own opens in a window of its own, one per
# box, from a Details... button on the pane's row (lib.agentvm.ui.sh, "Box windows"): a box's
# network is lib.agentvm.network.sh, and what ran in it lib.agentvm.programs.sh. A job that holds
# a box or an image has a window too, one per job, from the Progress... button beside the pane's
# state line (lib.agentvm.progress.sh). Updating an image is asked for in a window per image, from
# Update... in the image pane (lib.agentvm.update.sh).
#
# READING AND PAINTING ARE SEPARATE. main_read_* run agent-vm and leave its answers in the
# window's cache folder (lib.agentvm.ui.sh); main_paint_* only read the caches. So a handler that
# repaints runs no agent-vm, and the poll loop reads only `status`, the one cheap call (doctor asks
# the virtualization framework, and `box info` and `image info` measure a disk: they are read on
# opening and activation, and `box info` and `image info` for the selected box or image also on
# selecting it).
#
# THE POLL LOOP keeps the lists current while the window is open, so boxes started from
# Terminal or Cadabra appear without a click: every MAIN_POLL_IDLE_SECONDS, or every
# MAIN_POLL_BUSY_SECONDS while something moves (a box starting or stopping, an image being
# built). A token on the pasteboard makes the newest loop the only one that paints, and the
# close handler's "closed" ends it. It also ends when the app is gone. AGENTVM_APP_POLL_PASSES,
# for the tests, ends it after that many passes.
#
# THE SELECTIONS, one per list, are kept by name in the window's pasteboard values "box" and
# "image". Name is the FIRST column of both lists' rows on purpose: a list keeps its selection
# across new rows only by the first column. Every repaint selects the row again by name, since a
# card whose text changed loses its highlight, and paints the detail pane from the new rows.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_MAIN_LIB:-}" ] && return 0
__AGENTVM_APP_MAIN_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

MAIN_GETSTARTED_ID=200
MAIN_GETSTARTED_TEXT_ID=201
MAIN_GETSTARTED_NOTE_ID=202
MAIN_STATUS_ID=300

MAIN_BOXES_ID=311
MAIN_BOXES_FOOTER_ID=312
MAIN_BOXES_NOTE_ID=313
MAIN_NEW_BOX_ID=314
MAIN_BOX_NONE_ID=319
MAIN_BOX_DETAIL_ID=320
MAIN_BOX_NAME_ID=321
MAIN_BOX_STATE_ID=322
MAIN_BOX_MAINTENANCE_ID=323
MAIN_BOX_PROGRESS_ID=324
MAIN_RUNNING_BOX_ACTIONS_ID=330
MAIN_STOPPED_BOX_ACTIONS_ID=340
MAIN_BOX_STOP_ID=331
MAIN_BOX_VIEW_ID=332
MAIN_BOX_CONTROL_ID=333
MAIN_BOX_SHELL_ID=334
MAIN_BOX_START_ID=341
MAIN_BOX_SHOW_ID=342
MAIN_BOX_AGENT_ID=343
MAIN_BOX_RECREATE_ID=344
MAIN_BOX_DELETE_ID=345
MAIN_BOX_IMAGE_ID=351
MAIN_BOX_NETWORK_ID=352
MAIN_BOX_NETWORK_DETAILS_ID=361
MAIN_BOX_PROJECT_ID=353
MAIN_BOX_PROGRAMS_ID=354
MAIN_BOX_PROGRAMS_DETAILS_ID=362
MAIN_BOX_OWNER_ID=355
MAIN_BOX_HARDWARE_ID=356
MAIN_BOX_KEPT_ID=357
MAIN_BOX_CREATED_ID=358
MAIN_BOX_FOLDER_ID=359
MAIN_BOX_SPACE_ID=360

MAIN_IMAGES_ID=411
MAIN_IMAGES_FOOTER_ID=412
MAIN_IMAGES_NOTE_ID=413
MAIN_NEW_IMAGE_ID=414
MAIN_IMAGE_NONE_ID=419
MAIN_IMAGE_DETAIL_ID=420
MAIN_IMAGE_NAME_ID=421
MAIN_IMAGE_STATE_ID=422
MAIN_IMAGE_MAINTENANCE_ID=423
MAIN_IMAGE_PROGRESS_ID=424
MAIN_IMAGE_SHOW_ID=433
MAIN_IMAGE_DELETE_ID=434
MAIN_IMAGE_UPDATE_ID=435
MAIN_IMAGE_ACCESS_ID=462
MAIN_IMAGE_MACOS_ID=451
MAIN_IMAGE_BASE_ID=452
MAIN_IMAGE_TOOLS_ID=453
MAIN_IMAGE_GUEST_ID=454
MAIN_IMAGE_CREATED_ID=455
MAIN_IMAGE_BOXES_ID=456
MAIN_IMAGE_DERIVED_ID=457
MAIN_IMAGE_FOLDER_ID=458
MAIN_IMAGE_FDA_ID=459
MAIN_IMAGE_HARDWARE_ID=460
MAIN_IMAGE_SPACE_ID=461

MAIN_AGENTVM_VERSION_ID=501
MAIN_AGENTVM_LOCATION_ID=502
MAIN_VMS_ID=511
MAIN_DISK_ID=512

MAIN_POLL_IDLE_SECONDS=15
MAIN_POLL_BUSY_SECONDS=2

# -- Reading ------------------------------------------------------------------------------------

# main_read_agentvm <uuid>  ->  agentvm_available's status, with the cache file "agentvm" holding
# four lines: that status, its one line (the version, or why not), the origin, the binary.
main_read_agentvm() {
    local _out
    _out="$(agentvm_available)"
    local _status=$?
    {
        printf '%s\n' "$_status"
        printf '%s\n' "$_out"
        agentvm_origin
        agentvm_bin
    } | ui_store "$(ui_cache "$1" agentvm)"
    return "$_status"
}

# main_agentvm_line <uuid> <n>  ->  line n of the "agentvm" cache file.
main_agentvm_line() {
    local _file="$(ui_cache "$1" agentvm)"
    [ -f "$_file" ] || return 0
    /usr/bin/sed -n "${2}p" "$_file"
}

# main_read_doctor <uuid>  ->  the cache file "doctor.tsv": agentvm_doctor's rows, or, when
# doctor itself failed, one failure row named "doctor" with agent-vm's message.
main_read_doctor() {
    local _rows
    _rows="$(agentvm_doctor)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        _rows="doctor${ui_tab}failure${ui_tab}$(ui_one_line "$(agentvm_last_error "$_status")")"
    fi
    printf '%s\n' "$_rows" | ui_store "$(ui_cache "$1" doctor.tsv)"
}

# main_read_status <uuid> [check]  ->  0, with the cache files boxes.tsv, images.tsv, updates.tsv,
# newest.tsv, vm.tsv and jobs.tsv holding the rows lib.agentvm.sh documents; or agent-vm's status,
# with the previous rows kept and its message in the cache file "status-error" (empty after a
# success). "check" has agent-vm ask Apple for the newest macOS first (agentvm_status_checked).
main_read_status() {
    local _error="$(ui_cache "$1" status-error)"
    local _json _status
    if [ "${2:-}" = "check" ]; then
        _json="$(agentvm_status_checked)"
        _status=$?
    else
        _json="$(agentvm_status)"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_status_box_rows | ui_store "$(ui_cache "$1" boxes.tsv)"
    printf '%s\n' "$_json" | agentvm_status_image_rows | ui_store "$(ui_cache "$1" images.tsv)"
    printf '%s\n' "$_json" | agentvm_status_update_rows | ui_store "$(ui_cache "$1" updates.tsv)"
    printf '%s\n' "$_json" | agentvm_status_newest_row | ui_store "$(ui_cache "$1" newest.tsv)"
    printf '%s\n' "$_json" | agentvm_status_vm_row | ui_store "$(ui_cache "$1" vm.tsv)"
    printf '%s\n' "$_json" | agentvm_job_rows | ui_store "$(ui_cache "$1" jobs.tsv)"
    : | ui_store "$_error"
    return 0
}

# main_rows <uuid> <boxes|images|updates|newest|doctor|vm|jobs>  ->  that cache file's rows, nothing when it is missing.
main_rows() {
    local _file="$(ui_cache "$1" "$2.tsv")"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# main_row <uuid> <boxes|images|updates> <name>  ->  the cached row of that box or image, or nothing.
main_row() {
    main_rows "$1" "$2" | /usr/bin/awk -F'\t' -v name="$3" '$1 == name { print; exit }'
}

# main_face <uuid>  ->  getstarted or status (see the header).
main_face() {
    local _available="$(main_agentvm_line "$1" 1)"
    if [ "$_available" != "0" ]; then
        echo "getstarted"
        return 0
    fi
    local _failures="$(main_rows "$1" doctor | /usr/bin/awk -F'\t' '$2 == "failure"')"
    local _ready="$(main_rows "$1" images | /usr/bin/awk -F'\t' '$2 == "ready"')"
    local _boxes="$(main_rows "$1" boxes)"
    if [ -n "$_failures" ] || [ -z "$_ready" ] || [ -z "$_boxes" ]; then
        echo "getstarted"
        return 0
    fi
    echo "status"
}

# main_moving <uuid>  ->  0 while a box starts or stops, an image is being built or changed, or a
# job runs or waits, when the poll loop looks more often.
main_moving() {
    local _moving="$( { main_rows "$1" jobs | /usr/bin/awk -F'\t' '$2 == "running" || $2 == "queued"'
        main_rows "$1" boxes | /usr/bin/awk -F'\t' '$2 == "starting" || $2 == "stopping"'
        main_rows "$1" updates | /usr/bin/awk -F'\t' '$10 == "true"'
        main_rows "$1" images | /usr/bin/awk -F'\t' '$2 == "installing" || $2 == "installed" || $2 == "provisioning"'; } )"
    [ -n "$_moving" ]
}

# -- Jobs ----------------------------------------------------------------------------------------
# What takes long (starting or stopping a box, building or updating an image) is an agent-vm job
# (lib.agentvm.sh, "Jobs"), and `status` carries the jobs, so the window learns of them wherever
# they were started: here, in Cadabra or in Terminal. A job that runs or waits holds its box or
# image: the card and the pane say what it does, the pane's buttons that would change it are off,
# and the poll loop looks every MAIN_POLL_BUSY_SECONDS. When a
# job the window saw running ends, the window says so, once: a toast when it did what it was asked,
# an alert in agent-vm's words when it failed.

# main_job <uuid> <box|image> <name>  ->  the row of the job that holds that box or image now, or
# nothing: the one that runs (the newest, should there be several), and only when none runs, the
# newest that waits. A build with a setup queued after it is shown as the build.
main_job() {
    main_rows "$1" jobs | /usr/bin/awk -F'\t' -v target="$2:$3" '
        $2 == "running" && $3 == target { running = $0 }
        $2 == "queued" && $3 == target { queued = $0 }
        END { if (running != "") print running; else if (queued != "") print queued }'
}

# main_job_verb <what it does> <state>  ->  the job in a word or two, for a card and a pane:
# "Starting", "Stopping", "Building", "Updating", "Building again", "Setting up", and for a job that waits for
# another, "Waiting to start" and the like. Other jobs are named by their command.
main_job_verb() {
    if [ "$2" = "queued" ]; then
        case "$1" in
            "box start")          echo "Waiting to start" ;;
            "box stop")           echo "Waiting to stop" ;;
            "image create")       echo "Waiting to be built" ;;
            "image update"|"image update-guest")
                                  echo "Waiting to be updated" ;;
            "image rebuild")      echo "Waiting to be built again" ;;
            "image setup")        echo "Waiting to be set up" ;;
            *)                    printf 'Waiting: %s\n' "$1" ;;
        esac
        return 0
    fi
    case "$1" in
        "box start")          echo "Starting" ;;
        "box stop")           echo "Stopping" ;;
        "image create")       echo "Building" ;;
        "image update"|"image update-guest")
                              echo "Updating" ;;
        "image rebuild")      echo "Building again" ;;
        "image setup")        echo "Setting up" ;;
        *)                    printf 'Busy: %s\n' "$1" ;;
    esac
}

# main_job_text <job row>  ->  what the job does, for a pane's state line: main_job_verb's words,
# with how long it has run so far, when agent-vm says when it started, and for an image's job the
# step it is at, in agent-vm's words ("Building, 4 min so far: [2/3] Node"). A box's steps are
# what the verb already says.
main_job_text() {
    local _state="$(printf '%s\n' "$1" | /usr/bin/cut -f2)"
    local _what="$(printf '%s\n' "$1" | /usr/bin/cut -f4)"
    local _text="$(main_job_verb "$_what" "$_state")"
    if [ "$_state" = "queued" ]; then
        printf '%s\n' "$_text"
        return 0
    fi
    local _since="$(ui_seconds_since_epoch "$(printf '%s\n' "$1" | /usr/bin/cut -f7)")"
    if [ -n "$_since" ]; then
        local _seconds=$(( $(main_now) - _since ))
        [ "$_seconds" -ge 0 ] && _text="$_text, $(ui_duration_text "$_seconds") so far"
    fi
    local _message="$(printf '%s\n' "$1" | /usr/bin/cut -f13)"
    case "$_what" in
        box\ *) ;;
        *) [ "$_message" != "-" ] && [ -n "$_message" ] && _text="$_text: $_message" ;;
    esac
    printf '%s\n' "$_text"
}

# main_note_jobs <uuid>  ->  the rows of the jobs this window saw running or waiting that have
# ended since, each printed once; and the jobs that run or wait now are remembered for next time.
# A job that had already ended when the window first read it is never printed.
main_note_jobs() {
    local _jobs="$(ui_cache "$1" jobs.tsv)"
    local _watched="$(ui_cache "$1" jobs-watched)"
    [ -f "$_jobs" ] || return 0
    if [ -s "$_watched" ]; then
        /usr/bin/awk -F'\t' 'FILENAME == ARGV[1] { watched[$1] = 1; next }
            ($1 in watched) && $2 != "running" && $2 != "queued"' "$_watched" "$_jobs"
    fi
    /usr/bin/awk -F'\t' '$2 == "running" || $2 == "queued" { print $1 }' "$_jobs" | ui_store "$_watched"
}

# main_job_outcome <job row>  ->  how the job ended, as a sentence without its period: for one that
# did what it was asked, what is so now ("Box s3 is running"); for one that failed or was lost,
# what did not happen ("Box s3 did not start"). A job names its first target only.
main_job_outcome() {
    local _state="$(printf '%s\n' "$1" | /usr/bin/cut -f2)"
    local _target="$(printf '%s\n' "$1" | /usr/bin/cut -f3)"
    local _what="$(printf '%s\n' "$1" | /usr/bin/cut -f4)"
    local _name="${_target#*:}"
    if [ "$_state" = "done" ]; then
        case "$_what" in
            "box start")          printf 'Box %s is running\n' "$_name" ;;
            "box stop")           printf 'Box %s is stopped\n' "$_name" ;;
            "image create")       printf 'Image %s is ready\n' "$_name" ;;
            "image update"|"image update-guest")
                                  printf 'Image %s is up to date\n' "$_name" ;;
            "image rebuild")      printf 'Image %s was built again\n' "$_name" ;;
            "image setup")        printf 'The setup of image %s is done\n' "$_name" ;;
            "image fetch-ipsw")   printf 'The macOS restore file is downloaded\n' ;;
            *)                    printf '%s is done (%s)\n' "$_what" "$_target" ;;
        esac
        return 0
    fi
    case "$_what" in
        "box start")          printf 'Box %s did not start\n' "$_name" ;;
        "box stop")           printf 'Box %s did not stop\n' "$_name" ;;
        "image create")       printf 'Image %s was not built\n' "$_name" ;;
        "image update"|"image update-guest")
                              printf 'Image %s was not updated\n' "$_name" ;;
        "image rebuild")      printf 'Image %s was not built again, and is as it was\n' "$_name" ;;
        "image setup")        printf 'The setup of image %s did not finish\n' "$_name" ;;
        "image fetch-ipsw")   printf 'The macOS restore file was not downloaded\n' ;;
        *)                    printf '%s failed (%s)\n' "$_what" "$_target" ;;
    esac
}

# main_job_lines <job rows>  ->  one line per job: its outcome, and for one that failed, why.
main_job_lines() {
    local _row _error
    while IFS= read -r _row; do
        [ -n "$_row" ] || continue
        case "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" in
            done) printf '%s.\n' "$(main_job_outcome "$_row")" ;;
            *)
                _error="$(printf '%s\n' "$_row" | /usr/bin/cut -f15)"
                [ "$_error" = "-" ] && _error="agent-vm gave no reason."
                printf '%s: %s\n' "$(main_job_outcome "$_row")" "$_error" ;;
        esac
    done <<ROWS
$1
ROWS
}

# How long a toast about a job that ended well stays.
MAIN_TOAST_SECONDS=5

# main_report_jobs <uuid>  ->  what main_note_jobs says has ended is said: a job that failed, or
# was lost (its runner was stopped), in an alert with agent-vm's reason, one alert whatever their
# number; a job that did what it was asked, in a toast that goes by itself. A job that was
# canceled says nothing: someone asked for that.
main_report_jobs() {
    local _ended="$(main_note_jobs "$1")"
    [ -n "$_ended" ] || return 0
    local _done="$(printf '%s\n' "$_ended" | /usr/bin/awk -F'\t' '$2 == "done"')"
    if [ -n "$_done" ]; then
        "$dialog" "$1" omc_window omc_present_toast "$(main_job_lines "$_done" | /usr/bin/paste -sd ' ' -)" "$MAIN_TOAST_SECONDS"
        # Asked before a failure's alert is raised: a window shows one alert, the newest, and a
        # failure must not be the one lost. The image's maintenance line says it either way.
        main_offer_access "$1" "$_done"
    fi
    local _failed="$(printf '%s\n' "$_ended" | /usr/bin/awk -F'\t' '$2 == "failed" || $2 == "lost"')"
    [ -n "$_failed" ] || return 0
    local _count="$(printf '%s\n' "$_failed" | /usr/bin/awk 'END { print NR }')"
    if [ "$_count" -eq 1 ]; then
        local _error="$(printf '%s\n' "$_failed" | /usr/bin/cut -f15)"
        [ "$_error" = "-" ] && _error="agent-vm gave no reason."
        main_alert "$1" "$(main_job_outcome "$_failed")" "$_error"
        return 0
    fi
    main_alert "$1" "$_count jobs failed" "$(main_job_lines "$_failed")"
}

# main_access_lost <uuid> <job rows>  ->  the images among those jobs' whose update ended well and
# left them needing Full Disk Access that they did not need at the reading before (the cache file
# "access-needed", which main_note_access keeps): macOS ties the grant to the daemon it was made
# for, and an update may replace it. An image that needed it before is not named: nothing
# was lost. Nothing before the window's first reading.
main_access_lost() {
    local _before="$(ui_cache "$1" access-needed)"
    local _images="$(ui_cache "$1" images.tsv)"
    [ -f "$_before" ] && [ -f "$_images" ] || return 0
    printf '%s\n' "$2" | /usr/bin/awk -F'\t' -v before="$_before" -v images="$_images" '
        BEGIN {
            while ((getline line < before) > 0) needed[line] = 1
            while ((getline line < images) > 0) {
                split(line, cell, "\t")
                if ((","cell[8]",") ~ /,full-disk-access,/) needs[cell[1]] = 1
            }
        }
        $2 == "done" && ($4 == "image update" || $4 == "image update-guest") && $3 ~ /^image:/ {
            name = substr($3, 7)
            if ((name in needs) && !(name in needed)) print name
        }'
}

# main_note_access <uuid>  ->  keeps the images that need Full Disk Access as of this reading (the
# cache file "access-needed"), for main_access_lost at the next one. An image that an update job
# holds is left as it was noted before: agent-vm writes the updated image's record a moment before
# the job ends, and a reading in between would otherwise note the need as one from before the
# update, and the question would never be asked.
main_note_access() {
    local _before="$(ui_cache "$1" access-needed)"
    local _jobs="$(ui_cache "$1" jobs.tsv)"
    [ -f "$_before" ] || _before="/dev/null"
    [ -f "$_jobs" ] || _jobs="/dev/null"
    main_rows "$1" images | /usr/bin/awk -F'\t' -v before="$_before" -v jobs="$_jobs" '
        BEGIN {
            while ((getline line < before) > 0) needed[line] = 1
            while ((getline line < jobs) > 0) {
                split(line, cell, "\t")
                if ((cell[2] == "running" || cell[2] == "queued") && (cell[4] == "image update" || cell[4] == "image update-guest") && cell[3] ~ /^image:/)
                    held[substr(cell[3], 7)] = 1
            }
        }
        ($1 in held) { if ($1 in needed) print $1; next }
        (","$8",") ~ /,full-disk-access,/ { print $1 }' | ui_store "$(ui_cache "$1" access-needed)"
}

# main_offer_access <uuid> <job rows>  ->  asks whether to open the Full Disk Access guide of the
# first image main_access_lost names, which is kept as the window's pending offer; Grant It
# Again... in the question runs AgentVM.main.image.access.offered. Nothing when no image lost it.
main_offer_access() {
    local _name="$(main_access_lost "$1" "$2" | /usr/bin/sed -n '1p')"
    agentvm_valid_name "$_name" || return 0
    ui_set access_offer "$1" "$_name"
    "$dialog" "$1" omc_window omc_present_alert "Image $_name lost Full Disk Access in its update" \
        "agent-vm-guest had the grant in this image before the update, and does not have it now: macOS ties the grant to the daemon it was made for. Until it is granted again, programs in boxes made from $_name from now on wait, when they open Desktop, Documents or Downloads, on a question nobody sees." \
        "Later:cancel:" "Grant It Again...::AgentVM.main.image.access.offered"
}

# main_follow_job <job id>  ->  the open main window, if there is one, watches the job and reads
# the lists again, so its card and pane follow the job from now and not from its next poll: for
# a window that started a job (an image's update window, its Full Disk Access guide).
main_follow_job() {
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    printf '%s\n' "$1" >> "$(ui_cache "$_main" jobs-watched)"
    main_refresh "$_main" status
}

# -- What ended while the app was closed -----------------------------------------------------------
# A build or an update takes minutes to hours, and the app may be quit meanwhile: the job goes on.
# The app keeps the time it last read `status` (the file jobs-seen in its support folder, written
# at every reading), and a main window that opens reports, once, the image jobs and downloads that
# ended after that time: what was built, what failed and why. `job list` is read for it, since
# `status` carries finished jobs for an hour only. Boxes started and stopped meanwhile are not
# reported: the lists show how they are now, and Cadabra starts and stops boxes all day.

main_jobs_seen_file="$agentvm_support_dir/jobs-seen"

# main_time_text  ->  the time now as agent-vm writes times (2026-10-01T10:52:08Z), which sort as text.
main_time_text() {
    /bin/date -u -r "$(main_now)" '+%Y-%m-%dT%H:%M:%SZ'
}

# main_jobs_seen  ->  when the app last read `status`, or nothing when it never did.
main_jobs_seen() {
    [ -f "$main_jobs_seen_file" ] || return 0
    /usr/bin/sed -n '1p' "$main_jobs_seen_file"
}

# main_mark_jobs_seen [time]  ->  the app has looked until that time (now, when none is given). A
# time that is not one is not kept: an empty file would make the next launch a first launch.
main_mark_jobs_seen() {
    local _time="${1:-$(main_time_text)}"
    case "$_time" in
        [0123456789][0123456789][0123456789][0123456789]-*T*Z) ;;
        *) return 0 ;;
    esac
    [ -d "$agentvm_support_dir" ] || /bin/mkdir -p "$agentvm_support_dir"
    printf '%s\n' "$_time" | ui_store "$main_jobs_seen_file"
}

# main_launch_report <uuid> <when the app last read status>  ->  an alert naming the image jobs and
# downloads that ended after that time, well or not; nothing when there are none, when the app
# never read `status` before (a first launch reports no history), when agent-vm cannot be used
# (main_refresh found it missing or too old: nothing runs it then, and the time has not moved, so
# the report would come back at every launch), or when agent-vm cannot list the jobs. Canceled
# jobs are left out. Called after main_refresh.
main_launch_report() {
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 0
    case "$2" in
        [0123456789][0123456789][0123456789][0123456789]-*T*Z) ;;
        *) return 0 ;;
    esac
    local _json
    _json="$(agentvm_job_list)"
    local _status=$?
    [ "$_status" -eq 0 ] || return 0
    local _rows="$(printf '%s\n' "$_json" | agentvm_job_rows | /usr/bin/awk -F'\t' -v seen="$2" '
        ($3 ~ /^image:/ || $3 == "ipsw") && ($2 == "done" || $2 == "failed" || $2 == "lost") && $8 != "-" && $8 > seen')"
    [ -n "$_rows" ] || return 0
    main_alert "$1" "While AgentVM was closed" "$(main_job_lines "$_rows")"
    # Said, so it is not said again: `status` may be failing while `job list` answers, and then no
    # reading would move the time.
    main_mark_jobs_seen
}

# -- Painting -----------------------------------------------------------------------------------

# main_agentvm_origin_text <uuid>  ->  where the agent-vm in use comes from, for Get started.
main_agentvm_origin_text() {
    local _bin="$(agentvm_display_path "$(main_agentvm_line "$1" 4)")"
    case "$(main_agentvm_line "$1" 3)" in
        installed) printf 'in %s\n' "${_bin%/agent-vm}" ;;
        developer) printf 'developer build at %s\n' "$_bin" ;;
        *)         printf 'test agent-vm at %s\n' "$_bin" ;;
    esac
}

# main_agentvm_location_text <uuid>  ->  the agent-vm in use, for Settings: its path, and what
# kind it is when it is not the installed one, so a forgotten override is visible.
main_agentvm_location_text() {
    local _bin="$(agentvm_display_path "$(main_agentvm_line "$1" 4)")"
    case "$(main_agentvm_line "$1" 3)" in
        installed) printf '%s\n' "$_bin" ;;
        developer) printf '%s (developer build)\n' "$_bin" ;;
        *)         printf '%s (test agent-vm)\n' "$_bin" ;;
    esac
}

# main_vms_text <uuid> [short]  ->  "1 of 2 virtual machines running", or "1 of 2 running" when
# short (beside a "Virtual machines" label); nothing before status answered.
main_vms_text() {
    local _what="virtual machines "
    [ "${2:-}" = "short" ] && _what=""
    main_rows "$1" vm | /usr/bin/awk -F'\t' -v what="$_what" '
        NR == 1 && $1 == "-" { printf "at most %s %sat once\n", $2, what }
        NR == 1 && $1 != "-" { printf "%s of %s %srunning\n", $1, $2, what }'
}

# main_disk_text <uuid>  ->  doctor's free space ("67 GB free"), or nothing.
main_disk_text() {
    main_rows "$1" doctor | /usr/bin/awk -F'\t' '
        $1 == "disk space" && $3 != "-" { sub(/ on the volume.*/, "", $3); print $3; exit }'
}

# main_status_error <uuid>  ->  agent-vm's message when the last `status` failed, or nothing.
main_status_error() {
    local _file="$(ui_cache "$1" status-error)"
    [ -f "$_file" ] || return 0
    /bin/cat "$_file"
}

# main_paint_settings <uuid>  ->  the Settings tab: which agent-vm, the virtual machines, the disk.
main_paint_settings() {
    local _uuid="$1"
    local _version="-"
    [ "$(main_agentvm_line "$_uuid" 1)" = "0" ] && _version="$(main_agentvm_line "$_uuid" 2)"
    "$dialog" "$_uuid" "$MAIN_AGENTVM_VERSION_ID" "$_version"
    "$dialog" "$_uuid" "$MAIN_AGENTVM_LOCATION_ID" "$(main_agentvm_location_text "$_uuid")"
    local _vms="$(main_vms_text "$_uuid" short)"
    "$dialog" "$_uuid" "$MAIN_VMS_ID" "${_vms:--}"
    local _disk="$(main_disk_text "$_uuid")"
    "$dialog" "$_uuid" "$MAIN_DISK_ID" "${_disk:--}"
}

# main_getstarted_text <uuid>  ->  what exists and what does not, one line each.
main_getstarted_text() {
    local _uuid="$1"
    local _available="$(main_agentvm_line "$_uuid" 1)"
    if [ "$_available" != "0" ]; then
        printf 'agent-vm: %s\n' "$(main_agentvm_line "$_uuid" 2)"
        # Only for the installed one: a broken developer override is fixed in the setting.
        local _origin="$(main_agentvm_line "$_uuid" 3)"
        [ "$_origin" = "installed" ] && printf 'AgentVM runs the agent-vm installed in ~/.local/bin, the one Terminal and Cadabra run.\n'
        return 0
    fi
    printf 'agent-vm: %s (%s)\n' "$(main_agentvm_line "$_uuid" 2)" "$(main_agentvm_origin_text "$_uuid")"
    local _failures="$(main_rows "$_uuid" doctor | /usr/bin/awk -F'\t' '$2 == "failure" { printf "This Mac cannot run boxes now: %s (%s)\n", $3, $1 }')"
    if [ -n "$_failures" ]; then
        printf '%s\n' "$_failures"
    else
        printf 'This Mac can run boxes.\n'
    fi
    main_rows "$_uuid" images | /usr/bin/awk -F'\t' '$2 == "ready" { n++ } END {
        if (n == 0) print "Images: none ready yet."; else if (n == 1) print "Images: 1 ready."; else printf "Images: %d ready.\n", n }'
    main_rows "$_uuid" boxes | /usr/bin/awk -F'\t' 'END {
        if (NR == 0) print "Boxes: none yet."; else if (NR == 1) print "Boxes: 1."; else printf "Boxes: %d.\n", NR }'
    printf '\nIn Terminal, agent-vm image create makes an image and agent-vm box create makes a box from it; this window shows them within seconds.\n'
}

# main_maintenance <uuid> <boxes|images>  ->  "name<TAB>what to do" for each thing that needs
# doing to a box or an image. A card with any of them is marked "Needs maintenance", and its
# detail pane lists them:
#   - a box whose image changed since the box was made keeps what it was made with until it is
#     made again (agent-vm's recreate need, with its reason: the image was updated, built again,
#     or had its guest daemon replaced); a disposable box is left out, since it is deleted when
#     it stops;
#   - a running box whose supervisor is another agent-vm version: each version is installed in
#     a folder of its own, so a box keeps the version it started with until it is stopped;
#   - an image that needs a guest update (after an agent-vm update), or Full Disk Access, or
#     for which a newer macOS is known (agent-vm learned it when it last asked Apple).
# A failed image is not maintenance: its card is red and says Failed.
main_maintenance() {
    local _version="$(main_agentvm_line "$1" 2)"
    case "$2" in
        boxes)
            main_rows "$1" boxes | /usr/bin/awk -F'\t' -v current="$_version" '
                $13 != "true" && (","$18",") ~ /,recreate,/ {
                    what = "changed"; gets = "the image as it is now"
                    if ($22 == "guest-update")  { what = "had its guest daemon replaced"; gets = "the new one" }
                    if ($22 == "image-updated") { what = "was updated"; gets = "the update" }
                    if ($22 == "image-rebuilt") { what = "was built again"; gets = "the new image" }
                    printf "%s\tMade before image %s %s. Recreate it to get %s; what was changed inside it is lost.\n", $1, $3, what, gets }
                ($2 == "running" || $2 == "unresponsive") && $12 != "-" && $12 != current {
                    printf "%s\tRuns agent-vm %s. Stop it and start it again to move it to %s.\n", $1, $12, current }' ;;
        images)
            main_rows "$1" images | /usr/bin/awk -F'\t' -v current="$_version" '
                $2 == "failed" { next }
                (","$8",") ~ /,guest-update,/ {
                    printf "%s\tNeeds a guest update for agent-vm %s.\n", $1, current }
                (","$8",") ~ /,full-disk-access,/ {
                    printf "%s\tNeeds Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads. Set Up... above is the guide.\n", $1 }'
            main_rows "$1" updates | /usr/bin/awk -F'\t' '
                $6 != "-" { printf "%s\tmacOS %s is available. Update... installs it, in about 15 minutes.\n", $1, $6 }' ;;
    esac
}

# main_maintenance_text <uuid> <boxes|images> <name>  ->  "Needs maintenance" and one line per
# thing to do, for the detail pane; nothing when there is none.
main_maintenance_text() {
    local _lines="$(main_maintenance "$1" "$2" | /usr/bin/awk -F'\t' -v name="$3" '$1 == name { print $2 }')"
    [ -n "$_lines" ] || return 0
    printf 'Needs maintenance\n%s\n' "$_lines"
}

# main_flagged <uuid> <boxes|images>  ->  " a b " : the names with maintenance, between spaces,
# for awk's index() (names never hold a space).
main_flagged() {
    printf ' %s\n' "$(main_maintenance "$1" "$2" | /usr/bin/cut -f1 | /usr/bin/sort -u | /usr/bin/tr '\n' ' ')"
}

# main_box_card_rows <uuid>  ->  the box list's rows, one card each:
#   1 name   2 the state's symbol   3 image and macOS version   4 "Needs maintenance" or empty
#   5 its symbol or empty   6 the card's color, from the state
# A box a job holds (it is being started or stopped, or waits to be) looks as a box in between
# does, and its caption begins with what the job does, or with "Waiting" for a job queued after
# another.
main_box_card_rows() {
    main_rows "$1" boxes | /usr/bin/awk -F'\t' -v flagged="$(main_flagged "$1" boxes)" -v jobs="$(ui_cache "$1" jobs.tsv)" '
        BEGIN {
            while ((getline line < jobs) > 0) {
                split(line, job, "\t")
                # A job that runs wins over one that waits, as in main_job.
                if (job[2] == "queued" && job[3] ~ /^box:/ && !(substr(job[3], 5) in held))
                    held[substr(job[3], 5)] = "Waiting"
                if (job[2] == "running" && job[3] ~ /^box:/)
                    held[substr(job[3], 5)] = (job[4] == "box start") ? "Starting" : (job[4] == "box stop") ? "Stopping" : "Busy"
            }
        }
        {
            symbol = "questionmark.circle"; color = "#8E8E93"
            if ($2 == "running")                           { symbol = "play.circle.fill"; color = "#2E9E4F" }
            else if ($2 == "stopped")                      { symbol = "stop.circle" }
            else if ($2 == "starting" || $2 == "stopping") { symbol = "circle.dotted"; color = "#0A84FF" }
            else if ($2 == "unresponsive")                 { symbol = "exclamationmark.circle.fill"; color = "#E8861A" }
            caption = $3
            if ($19 != "-") caption = caption " - macOS " $19
            if ($1 in held) { symbol = "circle.dotted"; color = "#0A84FF"; caption = held[$1] " - " caption }
            mark = ""; mark_symbol = ""
            if (index(flagged, " " $1 " ")) { mark = "Needs maintenance"; mark_symbol = "exclamationmark.triangle.fill" }
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, symbol, caption, mark, mark_symbol, color
        }'
}

# main_image_card_rows <uuid>  ->  the image list's rows, one card each:
#   1 name   2 the state's symbol   3 macOS version and what it was built from, or Building or
#   Failed   4 "Needs maintenance" or empty   5 its symbol or empty   6 the card's color
#   7 how many boxes were made from it
# A ready image a job holds (it is being updated or set up, or waits to be) looks as an image
# being built does, and its caption begins with what the job does, or with "Waiting". One that an
# agent-vm command started elsewhere without a job is changing (agent-vm's `updating`) says "Busy".
main_image_card_rows() {
    local _counts="$(main_rows "$1" boxes | /usr/bin/cut -f3 | /usr/bin/sort | /usr/bin/uniq -c | /usr/bin/awk '{ printf "%s=%s ", $2, $1 }')"
    main_rows "$1" images | /usr/bin/awk -F'\t' -v flagged="$(main_flagged "$1" images)" -v counts="$_counts" -v jobs="$(ui_cache "$1" jobs.tsv)" \
        -v updates="$(ui_cache "$1" updates.tsv)" '
        BEGIN {
            while ((getline line < updates) > 0) {
                split(line, update, "\t")
                if (update[10] == "true") busy[update[1]] = 1
            }
            while ((getline line < jobs) > 0) {
                split(line, job, "\t")
                # A job that runs wins over one that waits, as in main_job.
                if (job[2] == "queued" && job[3] ~ /^image:/ && !(substr(job[3], 7) in held))
                    held[substr(job[3], 7)] = "Waiting"
                if (job[2] == "running" && job[3] ~ /^image:/)
                    held[substr(job[3], 7)] = (job[4] == "image create") ? "Building" : (job[4] ~ /^image update/) ? "Updating" : (job[4] == "image rebuild") ? "Building again" : (job[4] == "image setup") ? "Setting up" : "Busy"
            }
            n = split(counts, pairs, " ")
            for (i = 1; i <= n; i++) {
                eq = index(pairs[i], "=")
                boxes[substr(pairs[i], 1, eq - 1)] = substr(pairs[i], eq + 1)
            }
        }
        {
            symbol = "hammer.fill"; color = "#0A84FF"; caption = "Building"
            macos = ($4 == "-") ? "" : "macOS " $4
            if ($2 == "ready") {
                symbol = "square.stack.3d.up.fill"; color = "#5E5CE6"
                caption = ($6 == "-") ? "from a restore file" : "from " $6
            } else if ($2 == "failed") {
                symbol = "xmark.octagon.fill"; color = "#D93025"; caption = "Failed"
            }
            if (macos != "") caption = ($2 == "ready") ? macos " - " caption : caption " - " macos
            if ($2 == "ready" && !($1 in held) && ($1 in busy)) held[$1] = "Busy"
            if ($2 == "ready" && ($1 in held)) { symbol = "hammer.fill"; color = "#0A84FF"; caption = held[$1] " - " caption }
            mark = ""; mark_symbol = ""
            if (index(flagged, " " $1 " ")) { mark = "Needs maintenance"; mark_symbol = "exclamationmark.triangle.fill" }
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, symbol, caption, mark, mark_symbol, color, (($1 in boxes) ? boxes[$1] : 0)
        }'
}

# main_paint_lists <uuid>  ->  both lists from the caches, then the selections again.
main_paint_lists() {
    main_box_card_rows "$1" | "$dialog" "$1" "$MAIN_BOXES_ID" omc_table_set_rows_from_stdin
    main_image_card_rows "$1" | "$dialog" "$1" "$MAIN_IMAGES_ID" omc_table_set_rows_from_stdin
    main_reselect "$1"
}

# main_reselect <uuid>  ->  each list's selected card highlighted again, by name; a selection
# whose box or image is gone is dropped. The verb fires no action.
main_reselect() {
    local _uuid="$1"
    local _name="$(ui_get box "$_uuid")"
    if [ -n "$_name" ]; then
        if [ -n "$(main_row "$_uuid" boxes "$_name")" ]; then
            "$dialog" "$_uuid" "$MAIN_BOXES_ID" omc_select_row_with_content "$_name" 1
        else
            ui_set box "$_uuid" ""
        fi
    fi
    _name="$(ui_get image "$_uuid")"
    if [ -n "$_name" ]; then
        if [ -n "$(main_row "$_uuid" images "$_name")" ]; then
            "$dialog" "$_uuid" "$MAIN_IMAGES_ID" omc_select_row_with_content "$_name" 1
        else
            ui_set image "$_uuid" ""
        fi
    fi
}

# main_now  ->  the time as seconds since 1970. AGENTVM_APP_NOW, for the tests, fixes it.
main_now() {
    if [ -n "${AGENTVM_APP_NOW:-}" ]; then
        printf '%s\n' "$AGENTVM_APP_NOW"
        return 0
    fi
    /bin/date -u +%s
}

# main_box_state_text <state> <startedAt> <ownerPid> <activeExecs> <statusError>  ->  the box
# detail's state line. A running box nobody owns, with no program in it, started
# MAIN_IDLE_BOX_HOURS or more ago, says so: it holds one of the VM slots and its memory until it
# is stopped. agent-vm reports when a box started and how many programs run now, not how long it
# has been idle, and the words say only that.
MAIN_IDLE_BOX_HOURS=2
main_box_state_text() {
    case "$1" in
        running)
            local _text="Running"
            local _since="$(ui_seconds_since_epoch "$2")"
            local _seconds=""
            if [ -n "$_since" ]; then
                _seconds=$(( $(main_now) - _since ))
                [ "$_seconds" -ge 0 ] && _text="Running for $(ui_duration_text "$_seconds")"
            fi
            if [ -n "$_seconds" ] && [ "$3" = "-" ] && [ "$_seconds" -ge $((MAIN_IDLE_BOX_HOURS * 3600)) ]; then
                case "$4" in
                    -|0) _text="$_text. No program runs in it now." ;;
                esac
            fi
            printf '%s\n' "$_text" ;;
        starting)     echo "Starting" ;;
        stopping)     echo "Stopping" ;;
        stopped)      echo "Stopped" ;;
        unresponsive)
            if [ "$5" = "-" ]; then
                echo "Not responding"
            else
                printf 'Not responding: %s\n' "$5"
            fi ;;
        *)            printf '%s\n' "$1" ;;
    esac
}

# main_paint_box_detail <uuid>  ->  the selected box's detail pane, or the placeholder.
main_paint_box_detail() {
    local _uuid="$1"
    local _name="$(ui_get box "$_uuid")"
    local _row=""
    [ -n "$_name" ] && _row="$(main_row "$_uuid" boxes "$_name")"
    if [ -z "$_row" ]; then
        ui_show "$_uuid" "$MAIN_BOX_DETAIL_ID" 0
        ui_show "$_uuid" "$MAIN_BOX_NONE_ID" 1
        return 0
    fi
    ui_show "$_uuid" "$MAIN_BOX_NONE_ID" 0
    ui_show "$_uuid" "$MAIN_BOX_DETAIL_ID" 1
    "$dialog" "$_uuid" "$MAIN_BOX_NAME_ID" "$_name"
    "$dialog" "$_uuid" "$MAIN_BOX_MAINTENANCE_ID" "$(main_maintenance_text "$_uuid" boxes "$_name")"
    printf '%s\n' "$_row" | {
        local _n _state _image _mode _rules _pid _owner _project _ro _execs _started _version _disposable _error
        local _cpus _memory _path _needs _macos _build _created _reason _rest
        IFS="$ui_tab" read -r _n _state _image _mode _rules _pid _owner _project _ro _execs _started _version _disposable _error \
            _cpus _memory _path _needs _macos _build _created _reason _rest
        # A job that holds the box says what it does, in place of the state it has not left yet.
        local _job="$(main_job "$_uuid" box "$_name")"
        # Progress... opens the job's window (lib.agentvm.progress.sh).
        if [ -n "$_job" ]; then
            "$dialog" "$_uuid" "$MAIN_BOX_STATE_ID" "$(main_job_text "$_job")"
            ui_show "$_uuid" "$MAIN_BOX_PROGRESS_ID" 1
        else
            "$dialog" "$_uuid" "$MAIN_BOX_STATE_ID" "$(main_box_state_text "$_state" "$_started" "$_owner" "$_execs" "$_error")"
            ui_show "$_uuid" "$MAIN_BOX_PROGRESS_ID" 0
        fi
        case "$_state" in
            running|starting|unresponsive)
                ui_show "$_uuid" "$MAIN_STOPPED_BOX_ACTIONS_ID" 0
                ui_show "$_uuid" "$MAIN_RUNNING_BOX_ACTIONS_ID" 1 ;;
            *)
                ui_show "$_uuid" "$MAIN_RUNNING_BOX_ACTIONS_ID" 0
                ui_show "$_uuid" "$MAIN_STOPPED_BOX_ACTIONS_ID" 1 ;;
        esac

        local _text="$_image"
        if [ "${_macos:--}" != "-" ]; then
            _text="$_text (macOS $_macos"
            [ "${_build:--}" != "-" ] && _text="$_text, $_build"
            _text="$_text)"
        fi
        "$dialog" "$_uuid" "$MAIN_BOX_IMAGE_ID" "$_text"

        case "$_mode" in
            allowlist)
                if [ "$_rules" = "1" ]; then
                    _text="allowlist, 1 rule"
                else
                    _text="allowlist, $_rules rules"
                fi ;;
            *)  _text="$_mode" ;;
        esac
        "$dialog" "$_uuid" "$MAIN_BOX_NETWORK_ID" "$_text"

        _text="none"
        if [ "$_project" != "-" ]; then
            _text="$(agentvm_display_path "$_project")"
            [ "$_ro" = "true" ] && _text="$_text (read-only)"
        fi
        "$dialog" "$_uuid" "$MAIN_BOX_PROJECT_ID" "$_text"

        case "$_execs" in
            -|0) _text="none" ;;
            *)   _text="$_execs" ;;
        esac
        "$dialog" "$_uuid" "$MAIN_BOX_PROGRAMS_ID" "$_text"

        if [ "$_owner" != "-" ]; then
            local _owner_name="$(ui_process_name "$_owner")"
            _text="${_owner_name:-process} ($_owner)"
        elif [ "$_state" = "stopped" ]; then
            _text="-"
        else
            _text="nobody: it runs until it is stopped"
        fi
        "$dialog" "$_uuid" "$MAIN_BOX_OWNER_ID" "$_text"

        _text=""
        [ "$_cpus" != "-" ] && _text="$_cpus CPUs"
        [ "$_memory" != "-" ] && _text="${_text:+$_text, }$_memory GB"
        "$dialog" "$_uuid" "$MAIN_BOX_HARDWARE_ID" "${_text:--}"

        if [ "$_disposable" = "true" ]; then
            _text="no: it is deleted when it stops"
        else
            _text="yes, until it is deleted"
        fi
        "$dialog" "$_uuid" "$MAIN_BOX_KEPT_ID" "$_text"

        _text="$(ui_date_text "${_created:--}")"
        "$dialog" "$_uuid" "$MAIN_BOX_CREATED_ID" "${_text:--}"
        "$dialog" "$_uuid" "$MAIN_BOX_FOLDER_ID" "$(agentvm_display_path "$_path")"
        if [ -d "$_path" ]; then
            ui_enable "$_uuid" "$MAIN_BOX_SHOW_ID" 1
        else
            ui_enable "$_uuid" "$MAIN_BOX_SHOW_ID" 0
        fi

        # The cached `box info` adds the space, as of when it was last read, and only for this box.
        local _info="$(main_info "$_uuid" box "$_name")"
        "$dialog" "$_uuid" "$MAIN_BOX_SPACE_ID" \
            "$(main_space_text "$(printf '%s\n' "$_info" | /usr/bin/cut -f23)" "$(printf '%s\n' "$_info" | /usr/bin/cut -f24)" \
                "$(main_info_error "$_uuid" box "$_name")")"

        # The enable rules Cadabra's box window tested. The screen and a shell need a running box
        # (not a starting one, nor one whose supervisor does not answer); recreating and deleting
        # need a stopped one, and agent-vm refuses the others anyway. A disposable box belongs to
        # the chat window that made it and is deleted when it stops: it is neither recreated nor
        # given to avm. Recreating needs the image the box was made from, ready. Stop is for a box
        # that runs, answering or not; Start for a stopped one. A box a job holds gets none of
        # them until the job ends.
        local _running=0 _stopped=0 _kept=1 _image_ready=0 _free=1 _stoppable=0
        [ -n "$_job" ] && _free=0
        case "$_state" in
            running|unresponsive) _stoppable=1 ;;
        esac
        [ "$_state" = "running" ] && _running=1
        [ "$_state" = "stopped" ] && _stopped=1
        [ "$_disposable" = "true" ] && _kept=0
        [ "$(main_row "$_uuid" images "$_image" | /usr/bin/cut -f2)" = "ready" ] && _image_ready=1
        ui_enable "$_uuid" "$MAIN_BOX_STOP_ID" "$(( _stoppable * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_START_ID" "$(( _stopped * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_VIEW_ID" "$(( _running * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_CONTROL_ID" "$(( _running * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_SHELL_ID" "$(( _running * _free ))"
        # avm starts a stopped box itself.
        ui_enable "$_uuid" "$MAIN_BOX_AGENT_ID" "$(( (_running + _stopped) * _kept * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_RECREATE_ID" "$(( _stopped * _kept * _image_ready * _free ))"
        ui_enable "$_uuid" "$MAIN_BOX_DELETE_ID" "$(( _stopped * _free ))"
    }
}

# main_box_delete_question <uuid> <name>  ->  the confirmation's message: what deleting frees, and
# that the image it was made from stays.
main_box_delete_question() {
    local _text="The box's folder and disk are deleted, with everything installed or saved in it"
    local _size="$(ui_size_text "$(main_info "$1" box "$2" | /usr/bin/cut -f24)")"
    [ -n "$_size" ] && _text="$_text, which frees about $_size"
    _text="$_text."
    local _image="$(main_row "$1" boxes "$2" | /usr/bin/cut -f3)"
    [ -n "$_image" ] && [ "$_image" != "-" ] && _text="$_text The image it was made from, $_image, is kept."
    printf '%s This cannot be undone.\n' "$_text"
}

# main_box_recreate_question <uuid> <name>  ->  the confirmation's message: what stays and what goes.
main_box_recreate_question() {
    local _image="$(main_row "$1" boxes "$2" | /usr/bin/cut -f3)"
    printf 'It is made again from image %s as the image is now, with the same name, processors, memory and network rules. Everything installed or saved in the box, logins included, is deleted. This cannot be undone.\n' "$_image"
}

# main_box_askable <uuid> <name> <recreate|delete|start|stop>  ->  0 when that can be done to the
# box now, from the rows just read: it exists and no job holds it; for stop it runs, answering or
# not; for the others it is stopped, and for recreate it is kept and its image ready (the rules
# main_paint_box_detail enables the buttons by).
main_box_askable() {
    local _row="$(main_row "$1" boxes "$2")"
    [ -n "$_row" ] || return 1
    [ -z "$(main_job "$1" box "$2")" ] || return 1
    local _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    if [ "$3" = "stop" ]; then
        [ "$_state" = "running" ] || [ "$_state" = "unresponsive" ]
        return
    fi
    [ "$_state" = "stopped" ] || return 1
    [ "$3" = "recreate" ] || return 0
    [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f13)" != "true" ] || return 1
    [ "$(main_row "$1" images "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)" | /usr/bin/cut -f2)" = "ready" ]
}

# main_alert <uuid> <title> <message>  ->  an alert on the window with an OK button.
main_alert() {
    "$dialog" "$1" omc_window omc_present_alert "$2" "$3" "OK::"
}

# main_open_terminal <uuid> <box> <.command file or nothing> <status of making it>  ->  Terminal
# opens the file; when the file could not be made or Terminal could not open it, an alert says why.
main_open_terminal() {
    if [ "$4" -ne 0 ]; then
        main_alert "$1" "Could not open Terminal for box $2" "$(agentvm_last_error "$4")"
        return 0
    fi
    "$open_tool" -a Terminal "$3"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        /bin/rm -f "$3"
        main_alert "$1" "Could not open Terminal for box $2" "Terminal could not open $3 (status $_status)."
    fi
    return 0
}

# main_show_folder <uuid> <boxes|images>  ->  the selected box's or image's folder, selected in a
# Finder window; nothing when there is no selection or the folder is not on this Mac.
main_show_folder() {
    local _key=box
    local _column=17
    if [ "$2" = "images" ]; then
        _key=image
        _column=11
    fi
    local _name="$(ui_get "$_key" "$1")"
    [ -n "$_name" ] || return 0
    local _folder="$(main_row "$1" "$2" "$_name" | /usr/bin/cut -f"$_column")"
    [ -n "$_folder" ] && [ -d "$_folder" ] || return 0
    "$open_tool" -R "$_folder"
}

# main_image_busy <uuid> <name>  ->  0 while an agent-vm command changes the image (agent-vm's
# `updating`): an update or a setup, whether a job runs it or a command in Terminal does.
main_image_busy() {
    [ "$(main_row "$1" updates "$2" | /usr/bin/cut -f10)" = "true" ]
}

# main_image_state_text <state> <failure> [busy]  ->  the image detail's state line. "busy" is for
# a ready image that a command no job runs is changing.
main_image_state_text() {
    case "$1" in
        ready)
            if [ "${3:-}" = "busy" ]; then
                echo "Ready, and being updated or set up by another agent-vm command"
            else
                echo "Ready"
            fi ;;
        installing)   echo "Building: installing macOS" ;;
        installed)    echo "Building: macOS is installed" ;;
        provisioning) echo "Building: setting up its tools" ;;
        failed)
            if [ "$2" = "-" ]; then
                echo "Failed, and agent-vm gave no reason."
            else
                printf 'Failed: %s.\n' "${2%.}"
            fi ;;
        *)            printf '%s\n' "$1" ;;
    esac
}

# main_read_info <uuid> <box|image> <name>  ->  agent-vm's status, with `box info` or `image info`
# for that box or image in the cache file <kind>-info-<name>.tsv (agentvm_box_info_row's or
# agentvm_image_info_row's row, or empty after a failure) and why it failed in
# <kind>-info-<name>.error (empty after a success). One pair of files per name: selections'
# handlers overlap, and a slow answer for one box (a running box's entry comes from its
# supervisor, which may take seconds not to answer) must not replace another's. Both measure a
# disk (0.1-0.3 s), so they are read for the selected box and image only: on selecting it, on
# activation and before a question about it; never in the poll loop, whose passes reuse the last
# answer. A name agent-vm would refuse is never part of a path.
main_read_info() {
    agentvm_valid_name "$3" || return 2
    local _error="$(ui_cache "$1" "$2-info-$3.error")"
    local _json
    _json="$(agentvm_"$2"_info "$3")"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        : | ui_store "$(ui_cache "$1" "$2-info-$3.tsv")"
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_"$2"_info_row | ui_store "$(ui_cache "$1" "$2-info-$3.tsv")"
    : | ui_store "$_error"
    return 0
}

# main_read_selected <uuid> <box|image>  ->  main_read_info for the selected box or image, when it
# is still listed; 0 when there is nothing to read. A box whose supervisor does not answer is
# not measured here (on opening and activation, before the window is painted): `box info` would
# wait for it as long again as `status` just did. Selecting it measures it after painting.
main_read_selected() {
    local _name="$(ui_get "$2" "$1")"
    [ -n "$_name" ] || return 0
    local _list=images
    [ "$2" = "box" ] && _list=boxes
    local _row="$(main_row "$1" "$_list" "$_name")"
    [ -n "$_row" ] || return 0
    [ "$2" = "box" ] && [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" = "unresponsive" ] && return 0
    main_read_info "$1" "$2" "$_name"
}

# main_info <uuid> <box|image> <name>  ->  the cached `box info` or `image info` row of that box
# or image, or nothing.
main_info() {
    agentvm_valid_name "$3" || return 0
    local _file="$(ui_cache "$1" "$2-info-$3.tsv")"
    [ -f "$_file" ] || return 0
    /usr/bin/awk -F'\t' -v name="$3" '$1 == name { print; exit }' "$_file"
}

# main_info_error <uuid> <box|image> <name>  ->  why the last `box info` or `image info` of that
# box or image failed, or nothing.
main_info_error() {
    agentvm_valid_name "$3" || return 0
    [ -z "$(main_info "$1" "$2" "$3")" ] || return 0
    local _file="$(ui_cache "$1" "$2-info-$3.error")"
    [ -f "$_file" ] || return 0
    /bin/cat "$_file"
}

# main_space_text <bytes> <unshared bytes> <info error>  ->  the Space row of a detail pane: all
# of it and its own part (what Delete frees), or why it was not measured.
main_space_text() {
    local _size="$(ui_size_text "$1")"
    if [ -n "$_size" ]; then
        local _own="$(ui_size_text "$2")"
        if [ -n "$_own" ]; then
            printf '%s; %s its own (what Delete frees)\n' "$_size" "$_own"
        else
            printf '%s\n' "$_size"
        fi
    elif [ -n "$3" ]; then
        printf 'not measured: %s\n' "$3"
    else
        printf 'not measured\n'
    fi
}

# main_paint_image_detail <uuid>  ->  the selected image's detail pane, or the placeholder.
# `status` gives the image's state and record (fields 1-11), always current; the cached `image
# info` adds what only it has (fields 12-22: the guest daemon's features, Full Disk Access, the
# tools, processors and memory, the build's length and the space), as of when it was last read.
main_paint_image_detail() {
    local _uuid="$1"
    local _name="$(ui_get image "$_uuid")"
    local _row=""
    [ -n "$_name" ] && _row="$(main_row "$_uuid" images "$_name")"
    if [ -z "$_row" ]; then
        ui_show "$_uuid" "$MAIN_IMAGE_DETAIL_ID" 0
        ui_show "$_uuid" "$MAIN_IMAGE_NONE_ID" 1
        return 0
    fi
    ui_show "$_uuid" "$MAIN_IMAGE_NONE_ID" 0
    ui_show "$_uuid" "$MAIN_IMAGE_DETAIL_ID" 1
    "$dialog" "$_uuid" "$MAIN_IMAGE_NAME_ID" "$_name"
    local _boxes="$(main_rows "$_uuid" boxes | /usr/bin/awk -F'\t' -v name="$_name" '$3 == name { printf "%s (%s)\n", $1, $2 }')"
    "$dialog" "$_uuid" "$MAIN_IMAGE_BOXES_ID" "$(ui_lines_text "$_boxes")"
    local _derived="$(main_rows "$_uuid" images | /usr/bin/awk -F'\t' -v name="$_name" '$6 == name { print $1 }')"
    "$dialog" "$_uuid" "$MAIN_IMAGE_DERIVED_ID" "$(ui_lines_text "$_derived")"
    local _info="$(main_info "$_uuid" image "$_name")"
    local _info_error="$(main_info_error "$_uuid" image "$_name")"
    local _maintenance="$(main_maintenance_text "$_uuid" images "$_name")"
    # The status row's eleven fields, then image info's, or eleven "-" without it.
    local _extra="-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-${ui_tab}-"
    [ -n "$_info" ] && _extra="$(printf '%s\n' "$_info" | /usr/bin/cut -f12-22)"
    printf '%s\t%s\n' "$_row" "$_extra" | {
        local _n _state _failure _macos _build _based _recipe _needs _guest _created _path
        local _features _missing _seconds _fda _checked _clt _cpus _memory _bytes _unshared _added _rest
        IFS="$ui_tab" read -r _n _state _failure _macos _build _based _recipe _needs _guest _created _path \
            _features _missing _seconds _fda _checked _clt _cpus _memory _bytes _unshared _added _rest
        # A job that holds the image says what it does and where it is, in place of the state.
        local _job="$(main_job "$_uuid" image "$_name")"
        # Progress... opens the job's window (lib.agentvm.progress.sh).
        if [ -n "$_job" ]; then
            "$dialog" "$_uuid" "$MAIN_IMAGE_STATE_ID" "$(main_job_text "$_job")"
            ui_show "$_uuid" "$MAIN_IMAGE_PROGRESS_ID" 1
        else
            local _busy=""
            main_image_busy "$_uuid" "$_name" && _busy="busy"
            "$dialog" "$_uuid" "$MAIN_IMAGE_STATE_ID" "$(main_image_state_text "$_state" "$_failure" "$_busy")"
            ui_show "$_uuid" "$MAIN_IMAGE_PROGRESS_ID" 0
        fi

        # What a guest update adds, when image info said.
        if [ "$_missing" != "-" ]; then
            _maintenance="$(printf '%s\n' "$_maintenance" | /usr/bin/awk -v adds="$(printf '%s' "$_missing" | /usr/bin/sed 's/,/, /g')" '
                /^Needs a guest update for agent-vm .*\.$/ { sub(/\.$/, ", which adds " adds ".") } { print }')"
        fi
        "$dialog" "$_uuid" "$MAIN_IMAGE_MAINTENANCE_ID" "$_maintenance"

        local _text="$_macos"
        [ "$_macos" != "-" ] && [ "$_build" != "-" ] && _text="$_macos ($_build)"
        # When it was last updated, from status's update row.
        local _updated="$(ui_date_text "$(main_row "$_uuid" updates "$_name" | /usr/bin/cut -f3)")"
        [ -n "$_updated" ] && _text="$_text, updated $_updated"
        "$dialog" "$_uuid" "$MAIN_IMAGE_MACOS_ID" "$_text"
        _text="$_based"
        [ "$_based" = "-" ] && _text="a macOS restore file"
        "$dialog" "$_uuid" "$MAIN_IMAGE_BASE_ID" "$_text"

        # An image can have the Command Line Tools without a recipe (image create
        # --command-line-tools): "macOS only" is for neither.
        _text=""
        [ "$_recipe" != "-" ] && _text="$_recipe"
        [ "$_clt" != "-" ] && _text="${_text:+$_text; }$_clt"
        "$dialog" "$_uuid" "$MAIN_IMAGE_TOOLS_ID" "${_text:-macOS only}"

        _text="$_guest"
        [ "$_features" != "-" ] && _text="$_text: $(printf '%s' "$_features" | /usr/bin/sed 's/,/, /g')"
        "$dialog" "$_uuid" "$MAIN_IMAGE_GUEST_ID" "$_text"

        # status's need is current and wins over image info's answer, which may be older (access
        # granted or lost since it was read). Without either, only image info can say "not checked".
        local _date="$(ui_date_text "$_checked")"
        case ",$_needs,:$_fda" in
            *,full-disk-access,*:not-granted) _text="not granted${_date:+ (checked $_date)}" ;;
            *,full-disk-access,*)             _text="not granted" ;;
            *:granted)                        _text="granted${_date:+ (checked $_date)}" ;;
            *:not-granted)                    _text="not granted${_date:+ (checked $_date)}" ;;
            *)
                if [ -n "$_info" ]; then
                    _text="not checked yet"
                else
                    _text="-"
                fi ;;
        esac
        "$dialog" "$_uuid" "$MAIN_IMAGE_FDA_ID" "$_text"

        _text=""
        [ "$_cpus" != "-" ] && _text="$_cpus CPUs"
        [ "$_memory" != "-" ] && _text="${_text:+$_text, }$_memory GB"
        "$dialog" "$_uuid" "$MAIN_IMAGE_HARDWARE_ID" "${_text:--}"

        _text="$(main_space_text "$_bytes" "$_unshared" "$_info_error")"
        local _added_size="$(ui_size_text "$_added")"
        [ -n "$(ui_size_text "$_bytes")" ] && [ -n "$_added_size" ] && [ "$_based" != "-" ] && _text="$_text; $_added_size added over $_based"
        "$dialog" "$_uuid" "$MAIN_IMAGE_SPACE_ID" "$_text"

        _text="$(ui_date_text "$_created")"
        local _took="$(ui_duration_text "$_seconds")"
        [ -n "$_text" ] && [ -n "$_took" ] && _text="$_text, built in $_took"
        "$dialog" "$_uuid" "$MAIN_IMAGE_CREATED_ID" "${_text:--}"
        "$dialog" "$_uuid" "$MAIN_IMAGE_FOLDER_ID" "$(agentvm_display_path "$_path")"
        if [ -d "$_path" ]; then
            ui_enable "$_uuid" "$MAIN_IMAGE_SHOW_ID" 1
        else
            ui_enable "$_uuid" "$MAIN_IMAGE_SHOW_ID" 0
        fi
    }
    # Set Up... opens the image's Full Disk Access guide (lib.agentvm.access.sh): for a ready
    # image, also while a setup holds it, which the guide then follows.
    if [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" = "ready" ]; then
        ui_enable "$_uuid" "$MAIN_IMAGE_ACCESS_ID" 1
    else
        ui_enable "$_uuid" "$MAIN_IMAGE_ACCESS_ID" 0
    fi
    # Not while a job holds the image, or another command changes it. agent-vm also refuses to
    # delete an image another agent-vm process uses (a build started without a job, a box being
    # made from it), and says so.
    if [ -n "$(main_job "$_uuid" image "$_name")" ] || main_image_busy "$_uuid" "$_name"; then
        ui_enable "$_uuid" "$MAIN_IMAGE_DELETE_ID" 0
        ui_enable "$_uuid" "$MAIN_IMAGE_UPDATE_ID" 0
        return 0
    fi
    ui_enable "$_uuid" "$MAIN_IMAGE_DELETE_ID" 1
    # Update... opens the image's update window (lib.agentvm.update.sh): for a ready image only.
    if [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" = "ready" ]; then
        ui_enable "$_uuid" "$MAIN_IMAGE_UPDATE_ID" 1
    else
        ui_enable "$_uuid" "$MAIN_IMAGE_UPDATE_ID" 0
    fi
}

# main_image_delete_question <uuid> <name>  ->  the confirmation's message: what deleting frees,
# and what it means for what was made from the image (they are clones and keep working; a box
# can no longer be recreated, since recreating makes it again from its image).
main_image_delete_question() {
    local _text="The image's folder and disk are deleted"
    local _size="$(ui_size_text "$(main_info "$1" image "$2" | /usr/bin/cut -f21)")"
    [ -n "$_size" ] && _text="$_text, which frees about $_size"
    _text="$_text."
    local _boxes="$(main_rows "$1" boxes | /usr/bin/awk -F'\t' -v name="$2" '$3 == name { print $1 }')"
    [ -n "$_boxes" ] && _text="$_text Boxes made from it ($(ui_lines_text "$_boxes")) keep working, but cannot be recreated."
    local _derived="$(main_rows "$1" images | /usr/bin/awk -F'\t' -v name="$2" '$6 == name { print $1 }')"
    [ -n "$_derived" ] && _text="$_text Images built from it ($(ui_lines_text "$_derived")) keep working."
    printf '%s This cannot be undone.\n' "$_text"
}

# main_count_text <n> <thing>  ->  "1 image", "7 images".
main_count_text() {
    if [ "$1" = "1" ]; then
        printf '1 %s\n' "$2"
    else
        printf '%s %ss\n' "$1" "$2"
    fi
}

# main_paint <uuid>  ->  the whole window from the caches: the face, and the face's content.
main_paint() {
    local _uuid="$1"
    local _error="$(main_status_error "$_uuid")"
    local _face="$(main_face "$_uuid")"
    if [ "$_face" = "status" ]; then
        ui_show "$_uuid" "$MAIN_GETSTARTED_ID" 0
        ui_show "$_uuid" "$MAIN_STATUS_ID" 1
        "$dialog" "$_uuid" "$MAIN_BOXES_FOOTER_ID" "$(main_vms_text "$_uuid")"
        "$dialog" "$_uuid" "$MAIN_IMAGES_FOOTER_ID" "$(main_count_text "$(main_rows "$_uuid" images | /usr/bin/awk 'END { print NR }')" image)"
        "$dialog" "$_uuid" "$MAIN_BOXES_NOTE_ID" "$_error"
        "$dialog" "$_uuid" "$MAIN_IMAGES_NOTE_ID" "$_error"
        main_paint_settings "$_uuid"
        main_paint_lists "$_uuid"
        main_paint_box_detail "$_uuid"
        main_paint_image_detail "$_uuid"
    else
        ui_show "$_uuid" "$MAIN_STATUS_ID" 0
        ui_show "$_uuid" "$MAIN_GETSTARTED_ID" 1
        "$dialog" "$_uuid" "$MAIN_GETSTARTED_TEXT_ID" "$(main_getstarted_text "$_uuid")"
        "$dialog" "$_uuid" "$MAIN_GETSTARTED_NOTE_ID" "$_error"
    fi
}

# main_goto <uuid> <target>  ->  the window showing what a URL named (lib.agentvm.ui.sh, "The
# agentvm URL scheme"): "box <name>" or "image <name>" shows that tab with the card selected and
# its details read, as selecting it by hand does; "status" changes nothing. From the caches, so
# the caller reads `status` first. A name the lists do not hold is said in an alert, since the
# link came from somewhere that believed it existed. Nothing happens on the Get started face,
# which has no lists.
main_goto() {
    local _uuid="$1"
    local _kind="${2%% *}"
    local _name="${2#* }"
    local _tab _list
    case "$_kind" in
        box)   _tab=0; _list=boxes ;;
        image) _tab=1; _list=images ;;
        *)     return 0 ;;
    esac
    agentvm_valid_name "$_name" || return 0
    [ "$(main_face "$_uuid")" = "status" ] || return 0
    # A TabView's value is the 0-based index of its tab. Setting it fires nothing.
    "$dialog" "$_uuid" "$MAIN_STATUS_ID" "$_tab"
    if [ -z "$(main_row "$_uuid" "$_list" "$_name")" ]; then
        # When `status` failed the lists are old or empty, and the window's note says why: the
        # name may well exist.
        [ -z "$(main_status_error "$_uuid")" ] || return 0
        main_alert "$_uuid" "There is no $_kind named $_name" "It may have been deleted, or the link that named it is out of date."
        return 0
    fi
    ui_set "$_kind" "$_uuid" "$_name"
    main_reselect "$_uuid"
    if [ "$_kind" = "box" ]; then
        main_paint_box_detail "$_uuid"
        main_read_info "$_uuid" box "$_name"
        main_paint_box_detail "$_uuid"
    else
        main_read_info "$_uuid" image "$_name"
        main_paint_image_detail "$_uuid"
    fi
}

# main_refresh <uuid> <full|status>  ->  reads agent-vm, then paints. "full" checks agent-vm
# itself and runs doctor too (opening, activation); "status" reads only the lists (the poll loop),
# unless agent-vm could not be used last time, when it checks again whether it can now.
main_refresh() {
    local _uuid="$1"
    local _mode="$2"
    local _last="$(main_agentvm_line "$_uuid" 1)"
    [ "$_last" = "0" ] || _mode="full"
    local _available=0
    if [ "$_mode" = "full" ]; then
        main_read_agentvm "$_uuid"
        _available=$?
    fi
    local _status
    if [ "$_available" -eq 0 ]; then
        [ "$_mode" = "full" ] && main_read_doctor "$_uuid"
        # The time is taken before the reading: a job that ends while agent-vm answers is then
        # reported at the next launch, perhaps a second time, rather than never.
        local _looked="$(main_time_text)"
        main_read_status "$_uuid"
        _status=$?
        # What ended among the jobs this window saw running is said once, whoever reads first; and
        # the app has looked until that time, for the report at the next launch.
        if [ "$_status" -eq 0 ]; then
            main_report_jobs "$_uuid"
            main_mark_jobs_seen "$_looked"
            main_note_access "$_uuid"
        fi
        # The selected box's and image's measurements: on opening and activation, not in the poll
        # loop.
        if [ "$_mode" = "full" ] && [ "$_status" -eq 0 ]; then
            main_read_selected "$_uuid" box
            main_read_selected "$_uuid" image
        fi
        # 126 and 127 are the shell's: the binary itself cannot be run any more (removed, or no
        # longer executable), so this pass asks again what can be used rather than showing the
        # shell's message as agent-vm's.
        if [ "$_status" -eq 126 ] || [ "$_status" -eq 127 ]; then
            main_read_agentvm "$_uuid"
            _available=$?
        fi
    fi
    # An agent-vm that cannot be used says why in Get started; a status error from before it
    # went away would be a second, stale explanation.
    [ "$_available" -eq 0 ] || : | ui_store "$(ui_cache "$_uuid" status-error)"
    main_paint "$_uuid"
    # The window closed while agent-vm was being read (a status call can take seconds): the
    # close handler has removed the cache folder, and the reads above made it again.
    local _poll="$(ui_get poll "$_uuid")"
    [ "$_poll" = "closed" ] && ui_cache_clear "$_uuid"
    return 0
}

# main_poll_running <uuid>  ->  0 when a poll loop holds the window's token and its process is
# alive. A loop that was killed leaves its token behind; without the process check, activation
# would never start another and the window would stop refreshing until it was reopened.
main_poll_running() {
    local _holder="$(ui_get poll "$1")"
    case "$_holder" in
        poll-[0123456789]*) kill -0 "${_holder#poll-}" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

# main_poll <uuid>  ->  the poll loop (see the header). Returns when a newer loop took over, the
# window closed, or the app is gone.
main_poll() {
    local _uuid="$1"
    local _token="poll-$$"
    # A loop chained by a handler that was still running when the window closed must not take
    # the token over "closed" and poll a window that is gone.
    local _current="$(ui_get poll "$_uuid")"
    [ "$_current" = "closed" ] && return 0
    ui_set poll "$_uuid" "$_token"
    local _passes=0
    local _holder _wait
    while ui_app_alive; do
        _wait="$MAIN_POLL_IDLE_SECONDS"
        main_moving "$_uuid" && _wait="$MAIN_POLL_BUSY_SECONDS"
        # Wait first: whatever chained the loop has just painted.
        "$sleep_tool" "$_wait"
        _holder="$(ui_get poll "$_uuid")"
        [ "$_holder" = "$_token" ] || return 0
        ui_app_alive || break
        main_refresh "$_uuid" status
        _passes=$((_passes + 1))
        if [ -n "${AGENTVM_APP_POLL_PASSES:-}" ] && [ "$_passes" -ge "$AGENTVM_APP_POLL_PASSES" ]; then
            break
        fi
    done
    _holder="$(ui_get poll "$_uuid")"
    [ "$_holder" = "$_token" ] && ui_set poll "$_uuid" ""
    return 0
}

# main_box_stop_question <uuid> <name>  ->  why stopping the box should be asked about first: another
# program started it and may be using it, or programs run in it. Nothing when neither holds.
main_box_stop_question() {
    local _row="$(main_row "$1" boxes "$2")"
    local _owner="$(printf '%s\n' "$_row" | /usr/bin/cut -f7)"
    local _execs="$(printf '%s\n' "$_row" | /usr/bin/cut -f10)"
    local _text=""
    if [ "$_owner" != "-" ] && [ -n "$_owner" ]; then
        local _owner_name="$(ui_process_name "$_owner")"
        _text="${_owner_name:-Another program} (process $_owner) started this box and may be using it."
    fi
    case "$_execs" in
        ''|-|0) ;;
        1) _text="${_text:+$_text }One program is running in it and will be ended." ;;
        *) _text="${_text:+$_text }$_execs programs are running in it and will be ended." ;;
    esac
    printf '%s' "$_text"
}

# main_box_job <uuid> <name> <start|stop> <command guid>  ->  the job started, the lists read again,
# and the poll loop begun anew, so that it looks every MAIN_POLL_BUSY_SECONDS from now rather than
# when the old loop next wakes. agent-vm's refusal is shown in its words.
main_box_job() {
    local _id _status
    if [ "$3" = "start" ]; then
        _id="$(agentvm_job_box_start "$2")"
        _status=$?
    else
        _id="$(agentvm_job_box_stop "$2")"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        local _verb="started"
        [ "$3" = "stop" ] && _verb="stopped"
        main_alert "$1" "Box $2 was not $_verb" "$(agentvm_last_error "$_status")"
        main_refresh "$1" status
        return "$_status"
    fi
    # The job is watched from now, not from the next reading: one that fails within the moment
    # before it (an unknown box, no free slot) would otherwise never have been seen running.
    printf '%s\n' "$_id" >> "$(ui_cache "$1" jobs-watched)"
    main_refresh "$1" status
    "$next_command" "$4" "AgentVM.main.poll"
    return 0
}
