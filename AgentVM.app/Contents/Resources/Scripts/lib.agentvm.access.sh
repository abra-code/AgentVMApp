#!/bin/sh
# lib.agentvm.access.sh
#
# An image's Full Disk Access guide (AgentVM.access.json, the views 901-953): why the guest daemon
# needs Full Disk Access, the four steps of granting it, where the image is in them, what the
# grant means for the boxes and images made from the image, the command it runs, and Open the
# Image. One window per image (lib.agentvm.ui.sh, "Box windows", with the kind "access" and the
# image's name); the name is the window's pasteboard value "image", set by the init handler from
# the open request. It is opened by Set Up... in the main window's image pane, and from the
# question the main window asks when an update took an image's grant away. Sources
# lib.agentvm.main.sh for the status rows and the words that name a job.
#
# ONLY A PERSON CAN GRANT IT, on the image's own screen. Open the Image starts `agent-vm image
# setup <name>` as an agent-vm job: agent-vm boots the image and shows its screen in a window of
# its own, with System Settings on Full Disk Access; the person does the rest there, and closing
# that window shuts the image down and records whether the grant was made. This window stays
# open beside it and says where things are.
#
# WHERE THINGS ARE comes from `status` alone: the image's needs (it needs Full Disk Access, or it
# does not), and the setup job that holds the image, whose last step is one of agent-vm's three:
# boot, full-disk-access (the window is open) and shutdown. agent-vm's messages are not read:
# its step names are stable and its messages are not. So the guide does not know the moment of
# the grant; the image's window says it, in a note at its top.
#
# THE JOB IT FOLLOWS is the window's pasteboard value "job": the one Open the Image started, or a
# setup job found on the image at a reading (started in Terminal, or before this window opened).
# When it has ended, the window says how, for as long as `status` carries it (an hour).
#
# WHEN IT READS: on opening, on every activation, before Open the Image, and every
# ACCESS_POLL_SECONDS in a poll loop of its own while a setup job holds the image. The loop ends
# with the job (after one last reading), with the window, and with the app; a token on the
# pasteboard makes the newest loop the only one that paints, as in the main window.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_ACCESS_LIB:-}" ] && return 0
__AGENTVM_APP_ACCESS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

ACCESS_TITLE_ID=901
ACCESS_STATE_ID=902
# A step's three marks are these plus the step's number (1-4): 911 is step 1 still to do, 921
# step 1 being done now, 931 step 1 done. One of the three is shown.
ACCESS_PENDING_ID=910
ACCESS_NOW_ID=920
ACCESS_DONE_ID=930
ACCESS_STATUS_ID=941
ACCESS_AFTER_ID=942
ACCESS_COMMAND_ID=943
ACCESS_NOTE_ID=944
ACCESS_PROGRESS_ID=951
ACCESS_CLOSE_ID=952
ACCESS_OPEN_ID=953

ACCESS_POLL_SECONDS=2

# access_image <uuid>  ->  the window's image, or nothing when it has none or the value is not a
# name (it comes back from a pasteboard).
access_image() {
    local _name="$(ui_get image "$1")"
    agentvm_valid_name "$_name" || return 0
    printf '%s\n' "$_name"
}

# access_read <uuid> [full]  ->  0 with `status` in the window's cache (main_read_status's files);
# "full" first checks which agent-vm runs (on opening). An agent-vm that cannot be used is not run.
access_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    main_read_status "$1"
}

# access_needed <uuid> <name>  ->  0 when the image needs Full Disk Access, as of the last reading.
access_needed() {
    case ",$(main_row "$1" images "$2" | /usr/bin/cut -f8)," in
        *,full-disk-access,*) return 0 ;;
    esac
    return 1
}

# access_job <uuid> <name>  ->  the row of the setup job that holds the image now (it runs, or
# waits for another job), or nothing.
access_job() {
    main_job "$1" image "$2" | /usr/bin/awk -F'\t' '$4 == "image setup"'
}

# access_followed <uuid>  ->  the row of the job the window follows (see the header), or nothing:
# when it follows none, or `status` no longer carries it.
access_followed() {
    local _id="$(ui_get job "$1")"
    agentvm_valid_job_id "$_id" || return 0
    main_rows "$1" jobs | /usr/bin/awk -F'\t' -v id="$_id" '$1 == id { print; exit }'
}

# access_phase <uuid> <name>  ->  where the image is, in a word:
#   gone      no image of that name      unready   it is not a ready image
#   queued    its setup job waits for another job
#   boot      the setup job is starting the image
#   window    the image's window is open, and agent-vm waits for the person
#   shutdown  the window was closed, and the image is shutting down
#   needed    no setup job holds it, and it needs Full Disk Access
#   granted   no setup job holds it, and it does not
access_phase() {
    local _row="$(main_row "$1" images "$2")"
    if [ -z "$_row" ]; then
        echo "gone"
        return 0
    fi
    local _job="$(access_job "$1" "$2")"
    if [ -n "$_job" ]; then
        if [ "$(printf '%s\n' "$_job" | /usr/bin/cut -f2)" = "queued" ]; then
            echo "queued"
            return 0
        fi
        case "$(printf '%s\n' "$_job" | /usr/bin/cut -f9)" in
            full-disk-access) echo "window" ;;
            shutdown)         echo "shutdown" ;;
            *)                echo "boot" ;;
        esac
        return 0
    fi
    if [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" != "ready" ]; then
        echo "unready"
        return 0
    fi
    if access_needed "$1" "$2"; then
        echo "needed"
    else
        echo "granted"
    fi
}

# access_marks <phase>  ->  the four steps' marks, as four words of pending, now and done. While the
# image's window is open, steps 2 to 4 are all the person's and all "now": which of them is done
# is not known here. After the window closed, only the last is known to be happening.
access_marks() {
    case "$1" in
        boot)     echo "now pending pending pending" ;;
        window)   echo "done now now now" ;;
        shutdown) echo "done pending pending now" ;;
        granted)  echo "done done done done" ;;
        *)        echo "pending pending pending pending" ;;
    esac
}

# access_blocker <uuid> <name>  ->  why the image cannot be opened now, or nothing: agent-vm cannot
# be used or read, the image is gone or not ready, a job of another kind holds it, another
# agent-vm command is changing it, or no virtual machine slot is free (agent-vm waits for none).
# A setup job that holds it is not said here: the steps show it.
access_blocker() {
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        main_agentvm_line "$1" 2
        return 0
    fi
    local _error="$(main_status_error "$1")"
    if [ -n "$_error" ]; then
        printf 'agent-vm could not list the images: %s\n' "$_error"
        return 0
    fi
    local _row="$(main_row "$1" images "$2")"
    if [ -z "$_row" ]; then
        printf 'There is no image named %s any more.\n' "$2"
        return 0
    fi
    [ -z "$(access_job "$1" "$2")" ] || return 0
    local _job="$(main_job "$1" image "$2")"
    if [ -n "$_job" ]; then
        printf 'A job holds this image now (%s). It can be opened when the job ends.\n' "$(main_job_text "$_job")"
        return 0
    fi
    local _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    if [ "$_state" != "ready" ]; then
        printf 'Only a ready image can be opened, and this one is not: %s\n' \
            "$(main_image_state_text "$_state" "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)")"
        return 0
    fi
    if main_image_busy "$1" "$2"; then
        printf 'Another agent-vm command is changing this image now. It can be opened when that ends.\n'
        return 0
    fi
    main_rows "$1" vm | /usr/bin/awk -F'\t' 'NR == 1 && $1 != "-" && $2 != "-" && $1 + 0 >= $2 + 0 {
        printf "%s of %s virtual machines are running, and the image needs one to start: stop a box, or wait for a build to end.\n", $1, $2 }'
}

# access_state_text <uuid> <name> <phase>  ->  the line under the title: whether the guest daemon
# has Full Disk Access in the image, by agent-vm's record.
access_state_text() {
    case "$3" in
        gone) return 0 ;;
        unready)
            local _row="$(main_row "$1" images "$2")"
            main_image_state_text "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)"
            return 0 ;;
    esac
    if access_needed "$1" "$2"; then
        echo "agent-vm-guest does not have Full Disk Access in this image yet."
    else
        echo "agent-vm-guest has Full Disk Access in this image."
    fi
}

# access_status_text <uuid> <name> <phase>  ->  the line under the steps: what happens now, or how
# the setup this window followed ended, or nothing.
access_status_text() {
    case "$3" in
        queued)   echo "Waiting for an earlier job to finish. The image opens after it."
                  return 0 ;;
        boot)     echo "Starting the image. Its window opens in about a minute."
                  return 0 ;;
        window)   echo "The image's window is open. Do steps 2 to 4 in it: a note at its top says when the grant is seen."
                  return 0 ;;
        shutdown) echo "The image is shutting down, and agent-vm records whether the grant was made."
                  return 0 ;;
        needed|granted) ;;
        *)        return 0 ;;
    esac
    local _last="$(access_followed "$1")"
    case "$(printf '%s\n' "$_last" | /usr/bin/cut -f2)" in
        failed|lost)
            local _error="$(printf '%s\n' "$_last" | /usr/bin/cut -f15)"
            [ "$_error" = "-" ] && _error="agent-vm gave no reason."
            printf 'The setup did not finish: %s\n' "$_error"
            return 0 ;;
        done|canceled)
            if [ "$3" = "granted" ]; then
                printf 'Granted. Boxes made from %s from now on have it.\n' "$2"
            else
                echo "Not granted yet. Open the Image starts again."
            fi
            return 0 ;;
    esac
    [ "$3" = "granted" ] && echo "Nothing is left to do. Open the Image still shows its screen, for any other one-time step."
    return 0
}

# access_after_text <uuid> <name> <phase>  ->  what the grant means for what is made from the
# image, one line each. Before the grant, the boxes and images the image has now are all made
# before it, and are named; once it is granted, which were made before is not known here.
access_after_text() {
    if [ "$3" = "granted" ]; then
        printf 'Boxes made from it since the grant have it. A box made earlier gets it when it is recreated.\n'
        printf 'Images built from it since the grant have it too. An image built earlier is set up by itself.\n'
    else
        printf 'Boxes and images made from it after the grant have it.\n'
        local _boxes="$(main_rows "$1" boxes | /usr/bin/awk -F'\t' -v name="$2" '$3 == name && $13 != "true" { print $1 }')"
        [ -n "$_boxes" ] && printf 'Boxes made from it so far (%s) get it when they are recreated.\n' "$(ui_lines_text "$_boxes")"
        local _derived="$(main_rows "$1" images | /usr/bin/awk -F'\t' -v name="$2" '$6 == name { print $1 }')"
        [ -n "$_derived" ] && printf 'Images built from it so far (%s) do not get it: each is set up by itself.\n' "$(ui_lines_text "$_derived")"
    fi
    printf "An update that replaces the image's guest daemon may take the grant away; the image then says that it needs it again.\n"
}

# access_paint <uuid>  ->  the window from its cache.
access_paint() {
    local _uuid="$1"
    local _name="$(access_image "$_uuid")"
    [ -n "$_name" ] || return 0
    "$dialog" "$_uuid" "$ACCESS_TITLE_ID" "Full Disk Access for image $_name"
    local _phase="$(access_phase "$_uuid" "$_name")"
    local _blocker="$(access_blocker "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$ACCESS_STATE_ID" "$(access_state_text "$_uuid" "$_name" "$_phase")"
    local _step=0
    local _mark
    # Unquoted on purpose: four words of this library's own.
    for _mark in $(access_marks "$_phase"); do
        _step=$((_step + 1))
        case "$_mark" in
            now)  ui_show "$_uuid" $((ACCESS_PENDING_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_DONE_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_NOW_ID + _step)) 1 ;;
            done) ui_show "$_uuid" $((ACCESS_PENDING_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_NOW_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_DONE_ID + _step)) 1 ;;
            *)    ui_show "$_uuid" $((ACCESS_NOW_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_DONE_ID + _step)) 0
                  ui_show "$_uuid" $((ACCESS_PENDING_ID + _step)) 1 ;;
        esac
    done
    "$dialog" "$_uuid" "$ACCESS_STATUS_ID" "$(access_status_text "$_uuid" "$_name" "$_phase")"
    if [ "$_phase" = "gone" ]; then
        "$dialog" "$_uuid" "$ACCESS_AFTER_ID" ""
    else
        "$dialog" "$_uuid" "$ACCESS_AFTER_ID" "$(access_after_text "$_uuid" "$_name" "$_phase")"
    fi
    "$dialog" "$_uuid" "$ACCESS_COMMAND_ID" "agent-vm image setup $_name"
    "$dialog" "$_uuid" "$ACCESS_NOTE_ID" "$_blocker"
    # Progress... opens the window of the job followed: its log, and Stop.
    if [ -n "$(access_followed "$_uuid")" ]; then
        ui_show "$_uuid" "$ACCESS_PROGRESS_ID" 1
    else
        ui_show "$_uuid" "$ACCESS_PROGRESS_ID" 0
    fi
    case "$_phase:$_blocker" in
        needed:|granted:) ui_enable "$_uuid" "$ACCESS_OPEN_ID" 1 ;;
        *)                ui_enable "$_uuid" "$ACCESS_OPEN_ID" 0 ;;
    esac
}

# access_refresh <uuid> [full]  ->  reads, then paints. A setup job found on the image is followed
# from now. The window closed while agent-vm was being read, or while this painted: its close
# handler removed the cache folder and the job followed, and the reading, or the painting (which
# reads the cache), made the folder again; a setup found may have been noted after it. So whether
# the window is still there is asked last, after everything that leaves something.
access_refresh() {
    access_read "$1" "${2:-}"
    local _name="$(access_image "$1")"
    if [ -n "$_name" ]; then
        local _job="$(access_job "$1" "$_name" | /usr/bin/cut -f1)"
        [ -n "$_job" ] && ui_set job "$1" "$_job"
        access_paint "$1"
    fi
    if [ -z "$(access_image "$1")" ]; then
        ui_set job "$1" ""
        ui_cache_clear "$1"
    fi
    return 0
}

# access_moving <uuid>  ->  0 while a setup job holds the window's image, as of the last reading.
access_moving() {
    local _name="$(access_image "$1")"
    [ -n "$_name" ] || return 1
    [ -n "$(access_job "$1" "$_name")" ]
}

# access_poll_running <uuid>  ->  0 when a poll loop holds the window's token and its process is
# alive (a loop that was killed leaves its token behind).
access_poll_running() {
    local _holder="$(ui_get poll "$1")"
    case "$_holder" in
        poll-[0123456789]*) kill -0 "${_holder#poll-}" 2>/dev/null ;;
        *) return 1 ;;
    esac
}

# access_poll <uuid>  ->  the poll loop (see the header). Returns when no setup job holds the image
# any more, a newer loop took over, the window closed, or the app is gone.
# AGENTVM_APP_POLL_PASSES, for the tests, ends it after that many passes.
access_poll() {
    local _uuid="$1"
    local _token="poll-$$"
    local _current="$(ui_get poll "$_uuid")"
    [ "$_current" = "closed" ] && return 0
    ui_set poll "$_uuid" "$_token"
    local _passes=0
    local _holder
    while ui_app_alive; do
        access_moving "$_uuid" || break
        # Wait first: whatever chained the loop has just painted.
        "$sleep_tool" "$ACCESS_POLL_SECONDS"
        _holder="$(ui_get poll "$_uuid")"
        [ "$_holder" = "$_token" ] || return 0
        ui_app_alive || break
        access_refresh "$_uuid"
        _passes=$((_passes + 1))
        if [ -n "${AGENTVM_APP_POLL_PASSES:-}" ] && [ "$_passes" -ge "$AGENTVM_APP_POLL_PASSES" ]; then
            break
        fi
    done
    _holder="$(ui_get poll "$_uuid")"
    [ "$_holder" = "$_token" ] && ui_set poll "$_uuid" ""
    return 0
}
