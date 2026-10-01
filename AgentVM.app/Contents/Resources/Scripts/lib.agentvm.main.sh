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
# network is lib.agentvm.network.sh, and what ran in it lib.agentvm.programs.sh.
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
MAIN_RUNNING_BOX_ACTIONS_ID=330
MAIN_STOPPED_BOX_ACTIONS_ID=340
MAIN_BOX_VIEW_ID=332
MAIN_BOX_CONTROL_ID=333
MAIN_BOX_SHELL_ID=334
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
MAIN_IMAGE_SHOW_ID=433
MAIN_IMAGE_DELETE_ID=434
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

# main_read_status <uuid>  ->  0, with the cache files boxes.tsv, images.tsv and vm.tsv holding
# the rows lib.agentvm.sh documents; or agent-vm's status, with the previous rows kept and its
# message in the cache file "status-error" (empty after a success).
main_read_status() {
    local _error="$(ui_cache "$1" status-error)"
    local _json
    _json="$(agentvm_status)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_status_box_rows | ui_store "$(ui_cache "$1" boxes.tsv)"
    printf '%s\n' "$_json" | agentvm_status_image_rows | ui_store "$(ui_cache "$1" images.tsv)"
    printf '%s\n' "$_json" | agentvm_status_vm_row | ui_store "$(ui_cache "$1" vm.tsv)"
    : | ui_store "$_error"
    return 0
}

# main_rows <uuid> <boxes|images|doctor|vm>  ->  that cache file's rows, nothing when it is missing.
main_rows() {
    local _file="$(ui_cache "$1" "$2.tsv")"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# main_row <uuid> <boxes|images> <name>  ->  the cached row of that box or image, or nothing.
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

# main_moving <uuid>  ->  0 while a box starts or stops or an image is being built, when the poll
# loop looks more often.
main_moving() {
    local _moving="$( { main_rows "$1" boxes | /usr/bin/awk -F'\t' '$2 == "starting" || $2 == "stopping"'
        main_rows "$1" images | /usr/bin/awk -F'\t' '$2 == "installing" || $2 == "installed" || $2 == "provisioning"'; } )"
    [ -n "$_moving" ]
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
#   - a box made before its image's guest update keeps the old guest daemon until it is made
#     again (agent-vm's recreate need); a disposable box is left out, since it is deleted when it
#     stops;
#   - a running box whose supervisor is another agent-vm version: each version is installed in
#     a folder of its own, so a box keeps the version it started with until it is stopped;
#   - an image that needs a guest update (after an agent-vm update), or Full Disk Access.
# A failed image is not maintenance: its card is red and says Failed.
main_maintenance() {
    local _version="$(main_agentvm_line "$1" 2)"
    case "$2" in
        boxes)
            main_rows "$1" boxes | /usr/bin/awk -F'\t' -v current="$_version" '
                $13 != "true" && (","$18",") ~ /,recreate,/ {
                    printf "%s\tMade before image %s had its guest update. Recreate it to get the update; what was changed inside it is lost.\n", $1, $3 }
                ($2 == "running" || $2 == "unresponsive") && $12 != "-" && $12 != current {
                    printf "%s\tRuns agent-vm %s. Stop it and start it again to move it to %s.\n", $1, $12, current }' ;;
        images)
            main_rows "$1" images | /usr/bin/awk -F'\t' -v current="$_version" '
                $2 == "failed" { next }
                (","$8",") ~ /,guest-update,/ {
                    printf "%s\tNeeds a guest update for agent-vm %s.\n", $1, current }
                (","$8",") ~ /,full-disk-access,/ {
                    printf "%s\tNeeds Full Disk Access, or programs in its boxes cannot open Desktop, Documents or Downloads.\n", $1 }' ;;
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
main_box_card_rows() {
    main_rows "$1" boxes | /usr/bin/awk -F'\t' -v flagged="$(main_flagged "$1" boxes)" '
        {
            symbol = "questionmark.circle"; color = "#8E8E93"
            if ($2 == "running")                           { symbol = "play.circle.fill"; color = "#2E9E4F" }
            else if ($2 == "stopped")                      { symbol = "stop.circle" }
            else if ($2 == "starting" || $2 == "stopping") { symbol = "circle.dotted"; color = "#0A84FF" }
            else if ($2 == "unresponsive")                 { symbol = "exclamationmark.circle.fill"; color = "#E8861A" }
            caption = $3
            if ($19 != "-") caption = caption " - macOS " $19
            mark = ""; mark_symbol = ""
            if (index(flagged, " " $1 " ")) { mark = "Needs maintenance"; mark_symbol = "exclamationmark.triangle.fill" }
            printf "%s\t%s\t%s\t%s\t%s\t%s\n", $1, symbol, caption, mark, mark_symbol, color
        }'
}

# main_image_card_rows <uuid>  ->  the image list's rows, one card each:
#   1 name   2 the state's symbol   3 macOS version and what it was built from, or Building or
#   Failed   4 "Needs maintenance" or empty   5 its symbol or empty   6 the card's color
#   7 how many boxes were made from it
main_image_card_rows() {
    local _counts="$(main_rows "$1" boxes | /usr/bin/cut -f3 | /usr/bin/sort | /usr/bin/uniq -c | /usr/bin/awk '{ printf "%s=%s ", $2, $1 }')"
    main_rows "$1" images | /usr/bin/awk -F'\t' -v flagged="$(main_flagged "$1" images)" -v counts="$_counts" '
        BEGIN {
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
        local _cpus _memory _path _needs _macos _build _created _rest
        IFS="$ui_tab" read -r _n _state _image _mode _rules _pid _owner _project _ro _execs _started _version _disposable _error \
            _cpus _memory _path _needs _macos _build _created _rest
        "$dialog" "$_uuid" "$MAIN_BOX_STATE_ID" "$(main_box_state_text "$_state" "$_started" "$_owner" "$_execs" "$_error")"
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
            "$(main_space_text "$(printf '%s\n' "$_info" | /usr/bin/cut -f22)" "$(printf '%s\n' "$_info" | /usr/bin/cut -f23)" \
                "$(main_info_error "$_uuid" box "$_name")")"

        # The enable rules Cadabra's box window tested. The screen and a shell need a running box
        # (not a starting one, nor one whose supervisor does not answer); recreating and deleting
        # need a stopped one, and agent-vm refuses the others anyway. A disposable box belongs to
        # the chat window that made it and is deleted when it stops: it is neither recreated nor
        # given to avm. Recreating needs the image the box was made from, ready.
        local _running=0 _stopped=0 _kept=1 _image_ready=0
        [ "$_state" = "running" ] && _running=1
        [ "$_state" = "stopped" ] && _stopped=1
        [ "$_disposable" = "true" ] && _kept=0
        [ "$(main_row "$_uuid" images "$_image" | /usr/bin/cut -f2)" = "ready" ] && _image_ready=1
        ui_enable "$_uuid" "$MAIN_BOX_VIEW_ID" "$_running"
        ui_enable "$_uuid" "$MAIN_BOX_CONTROL_ID" "$_running"
        ui_enable "$_uuid" "$MAIN_BOX_SHELL_ID" "$_running"
        # avm starts a stopped box itself.
        ui_enable "$_uuid" "$MAIN_BOX_AGENT_ID" "$(( (_running + _stopped) * _kept ))"
        ui_enable "$_uuid" "$MAIN_BOX_RECREATE_ID" "$(( _stopped * _kept * _image_ready ))"
        ui_enable "$_uuid" "$MAIN_BOX_DELETE_ID" "$_stopped"
    }
}

# main_box_delete_question <uuid> <name>  ->  the confirmation's message: what deleting frees, and
# that the image it was made from stays.
main_box_delete_question() {
    local _text="The box's folder and disk are deleted, with everything installed or saved in it"
    local _size="$(ui_size_text "$(main_info "$1" box "$2" | /usr/bin/cut -f23)")"
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

# main_box_askable <uuid> <name> <recreate|delete>  ->  0 when the box can be asked about now, from
# the rows just read: it exists, it is stopped, and for recreate it is kept and its image ready
# (the rules main_paint_box_detail enables the buttons by).
main_box_askable() {
    local _row="$(main_row "$1" boxes "$2")"
    [ -n "$_row" ] || return 1
    [ "$(printf '%s\n' "$_row" | /usr/bin/cut -f2)" = "stopped" ] || return 1
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

# main_image_state_text <state> <failure>  ->  the image detail's state line.
main_image_state_text() {
    case "$1" in
        ready)        echo "Ready" ;;
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
        "$dialog" "$_uuid" "$MAIN_IMAGE_STATE_ID" "$(main_image_state_text "$_state" "$_failure")"

        # What a guest update adds, when image info said.
        if [ "$_missing" != "-" ]; then
            _maintenance="$(printf '%s\n' "$_maintenance" | /usr/bin/awk -v adds="$(printf '%s' "$_missing" | /usr/bin/sed 's/,/, /g')" '
                /^Needs a guest update for agent-vm .*\.$/ { sub(/\.$/, ", which adds " adds ".") } { print }')"
        fi
        "$dialog" "$_uuid" "$MAIN_IMAGE_MAINTENANCE_ID" "$_maintenance"

        local _text="$_macos"
        [ "$_macos" != "-" ] && [ "$_build" != "-" ] && _text="$_macos ($_build)"
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
    # agent-vm refuses to delete an image another agent-vm process uses, and says so; phase 3
    # disables Delete while one of this app's jobs holds the image.
    ui_enable "$_uuid" "$MAIN_IMAGE_DELETE_ID" 1
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
        main_read_status "$_uuid"
        _status=$?
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
