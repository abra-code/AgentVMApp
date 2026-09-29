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
# READING AND PAINTING ARE SEPARATE. main_read_* run agent-vm and leave its answers in the
# window's cache folder (lib.agentvm.ui.sh); main_paint_* only read the caches. So a handler that
# repaints after a selection runs no agent-vm, and the poll loop reads only `status`, the one
# cheap call (doctor asks the virtualization framework; it is read on opening and activation).
#
# THE POLL LOOP keeps the lists current while the window is open, so boxes started from
# Terminal or Cadabra appear without a click: every MAIN_POLL_IDLE_SECONDS, or every
# MAIN_POLL_BUSY_SECONDS while something moves (a box starting or stopping, an image being
# built). A token on the pasteboard makes the newest loop the only one that paints, and the
# close handler's "closed" ends it. It also ends when the app is gone. AGENTVM_APP_POLL_PASSES,
# for the tests, ends it after that many passes.
#
# THE SELECTION is one across both tables, kept as "box:<name>" or "image:<name>". Name is the
# FIRST column of both tables on purpose: a Table keeps its selection across new rows only by
# the first column, and a column of state symbols would carry it to whichever row shares the
# symbol. It is highlighted again by name after every repaint, since a row whose text changed
# loses its highlight.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_MAIN_LIB:-}" ] && return 0
__AGENTVM_APP_MAIN_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

MAIN_HEADER_ID=100
MAIN_NOTE_ID=101
MAIN_NEW_IMAGE_ID=102
MAIN_NEW_BOX_ID=103
MAIN_SETUP_ID=104
MAIN_GETSTARTED_ID=200
MAIN_GETSTARTED_TEXT_ID=201
MAIN_STATUS_ID=300
MAIN_BOXES_ID=310
MAIN_IMAGES_ID=320
MAIN_SELECTED_ID=331
MAIN_RUNNING_BOX_ACTIONS_ID=340
MAIN_STOPPED_BOX_ACTIONS_ID=350
MAIN_IMAGE_ACTIONS_ID=360

MAIN_POLL_IDLE_SECONDS=15
MAIN_POLL_BUSY_SECONDS=2

# -- Reading ------------------------------------------------------------------------------------

# main_one_line <text>  ->  the text on one line: tabs and line breaks inside it become spaces.
# For agent-vm's messages, which go into a row of a cache file and into one Text.
main_one_line() {
    printf '%s' "$1" | /usr/bin/tr '\t\n' '  '
    printf '\n'
}

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
        _rows="doctor${ui_tab}failure${ui_tab}$(main_one_line "$(agentvm_last_error "$_status")")"
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
        main_one_line "$(agentvm_last_error "$_status")" | ui_store "$_error"
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

# main_agentvm_origin_text <uuid>  ->  where the agent-vm in use comes from, for the header.
main_agentvm_origin_text() {
    local _bin="$(agentvm_display_path "$(main_agentvm_line "$1" 4)")"
    case "$(main_agentvm_line "$1" 3)" in
        installed) printf 'in %s\n' "${_bin%/agent-vm}" ;;
        developer) printf 'developer build at %s\n' "$_bin" ;;
        *)         printf 'test agent-vm at %s\n' "$_bin" ;;
    esac
}

# main_header_text <uuid>  ->  the header line: which agent-vm, the virtual machines, the disk.
main_header_text() {
    local _uuid="$1"
    local _available="$(main_agentvm_line "$_uuid" 1)"
    local _text
    case "$_available" in
        0) _text="agent-vm $(main_agentvm_line "$_uuid" 2) ($(main_agentvm_origin_text "$_uuid"))" ;;
        "$agentvm_not_installed") _text="agent-vm is not installed" ;;
        "$agentvm_too_old")       _text="agent-vm is too old" ;;
        *)                        _text="agent-vm cannot be used" ;;
    esac
    if [ "$_available" = "0" ]; then
        local _vms="$(main_rows "$_uuid" vm | /usr/bin/awk -F'\t' '
            NR == 1 && $1 == "-" { printf "at most %s virtual machines at once", $2 }
            NR == 1 && $1 != "-" { printf "%s of %s virtual machines running", $1, $2 }')"
        [ -n "$_vms" ] && _text="$_text  -  $_vms"
        local _disk="$(main_rows "$_uuid" doctor | /usr/bin/awk -F'\t' '
            $1 == "disk space" && $3 != "-" { sub(/ on the volume.*/, "", $3); print $3; exit }')"
        [ -n "$_disk" ] && _text="$_text  -  $_disk"
    fi
    printf '%s\n' "$_text"
}

# main_paint_header <uuid>  ->  the header, and agent-vm's message when `status` failed.
main_paint_header() {
    "$dialog" "$1" "$MAIN_HEADER_ID" "$(main_header_text "$1")"
    local _error=""
    local _file="$(ui_cache "$1" status-error)"
    [ -f "$_file" ] && _error="$(/bin/cat "$_file")"
    "$dialog" "$1" "$MAIN_NOTE_ID" "$_error"
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

# main_box_display_rows <uuid>  ->  the boxes table's rows: Name, the state's symbol, State,
# Image, Network, project, programs and owner, and the row's button.
main_box_display_rows() {
    local _uuid="$1"
    local _name _state _image _mode _rules _pid _owner _project _ro _execs _started _version _disposable _error _cpus _memory _path
    local _symbol _network _details _owner_name _button
    main_rows "$_uuid" boxes | while IFS="$ui_tab" read -r _name _state _image _mode _rules _pid _owner _project _ro _execs _started _version _disposable _error _cpus _memory _path; do
        case "$_state" in
            running)           _symbol="play.circle.fill" ;;
            stopped)           _symbol="circle" ;;
            starting|stopping) _symbol="hourglass" ;;
            *)                 _symbol="exclamationmark.triangle" ;;
        esac
        case "$_state" in
            running|starting|unresponsive) _button="Stop" ;;
            *)                             _button="Start" ;;
        esac
        _network="$_mode"
        [ "$_mode" = "allowlist" ] && _network="allowlist ($_rules)"
        _details=""
        if [ "$_project" != "-" ]; then
            _details="$(agentvm_display_path "$_project")"
            [ "$_ro" = "true" ] && _details="$_details (read-only)"
        fi
        case "$_execs" in
            ''|-|0) ;;
            1) _details="${_details:+$_details, }1 program" ;;
            *) _details="${_details:+$_details, }$_execs programs" ;;
        esac
        if [ "$_owner" != "-" ]; then
            _owner_name="$(ui_process_name "$_owner")"
            _details="${_details:+$_details, }${_owner_name:-process $_owner}"
        fi
        [ "$_disposable" = "true" ] && _details="${_details:+$_details, }disposable"
        [ "$_error" != "-" ] && _details="${_details:+$_details, }$_error"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$_name" "$_symbol" "$_state" "$_image" "$_network" "${_details:--}" "$_button"
    done
}

# main_image_display_rows <uuid>  ->  the images table's rows: Name, the state's symbol, State,
# macOS, Built from, Tools (the recipe's description up to its first parenthesis), Needs, and the
# row's button.
main_image_display_rows() {
    main_rows "$1" images | /usr/bin/awk -F'\t' '
        {
            symbol = "hammer.circle"
            if ($2 == "ready") symbol = "checkmark.circle"
            if ($2 == "failed") symbol = "exclamationmark.triangle"
            state = $2
            if ($3 != "-") state = state ": " $3
            from = ($6 == "-") ? "restore file" : $6
            tools = $7
            sub(/ \(.*/, "", tools)
            needs = $8
            gsub(/guest-update/, "guest update", needs)
            gsub(/full-disk-access/, "Full Disk Access", needs)
            gsub(/,/, ", ", needs)
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, symbol, state, $4, from, tools, needs, "..."
        }'
}

# main_paint_tables <uuid>  ->  both tables from the caches, then the selection again.
main_paint_tables() {
    main_box_display_rows "$1" | "$dialog" "$1" "$MAIN_BOXES_ID" omc_table_set_rows_from_stdin
    main_image_display_rows "$1" | "$dialog" "$1" "$MAIN_IMAGES_ID" omc_table_set_rows_from_stdin
    main_reselect "$1"
}

# main_reselect <uuid>  ->  the selected row highlighted again, by name; a selection whose box or
# image is gone is dropped. The verb fires no action.
main_reselect() {
    local _selected="$(ui_get selected "$1")"
    local _row
    case "$_selected" in
        box:*)
            _row="$(main_row "$1" boxes "${_selected#box:}")"
            if [ -n "$_row" ]; then
                "$dialog" "$1" "$MAIN_BOXES_ID" omc_select_row_with_content "${_selected#box:}" 1
            else
                ui_set selected "$1" ""
            fi ;;
        image:*)
            _row="$(main_row "$1" images "${_selected#image:}")"
            if [ -n "$_row" ]; then
                "$dialog" "$1" "$MAIN_IMAGES_ID" omc_select_row_with_content "${_selected#image:}" 1
            else
                ui_set selected "$1" ""
            fi ;;
    esac
}

# main_paint_actions <uuid>  ->  the action row for the selection: a running box's, a stopped
# box's, an image's, or none.
main_paint_actions() {
    local _uuid="$1"
    local _selected="$(ui_get selected "$_uuid")"
    local _panel=""
    local _text="Select a box or an image."
    local _row _state
    case "$_selected" in
        box:*)
            _row="$(main_row "$_uuid" boxes "${_selected#box:}")"
            if [ -n "$_row" ]; then
                _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
                _text="Selected: box ${_selected#box:} ($_state)"
                case "$_state" in
                    running|starting|unresponsive) _panel="$MAIN_RUNNING_BOX_ACTIONS_ID" ;;
                    *)                             _panel="$MAIN_STOPPED_BOX_ACTIONS_ID" ;;
                esac
            fi ;;
        image:*)
            _row="$(main_row "$_uuid" images "${_selected#image:}")"
            if [ -n "$_row" ]; then
                _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
                _text="Selected: image ${_selected#image:} ($_state)"
                _panel="$MAIN_IMAGE_ACTIONS_ID"
            fi ;;
    esac
    "$dialog" "$_uuid" "$MAIN_SELECTED_ID" "$_text"
    local _id
    for _id in $MAIN_RUNNING_BOX_ACTIONS_ID $MAIN_STOPPED_BOX_ACTIONS_ID $MAIN_IMAGE_ACTIONS_ID; do
        if [ "$_id" = "$_panel" ]; then
            ui_show "$_uuid" "$_id" 1
        else
            ui_show "$_uuid" "$_id" 0
        fi
    done
}

# main_paint <uuid>  ->  the whole window from the caches: header, face, and the face's content.
main_paint() {
    local _uuid="$1"
    main_paint_header "$_uuid"
    local _face="$(main_face "$_uuid")"
    if [ "$_face" = "status" ]; then
        ui_show "$_uuid" "$MAIN_GETSTARTED_ID" 0
        ui_show "$_uuid" "$MAIN_STATUS_ID" 1
        main_paint_tables "$_uuid"
        main_paint_actions "$_uuid"
    else
        ui_show "$_uuid" "$MAIN_STATUS_ID" 0
        ui_show "$_uuid" "$MAIN_GETSTARTED_ID" 1
        "$dialog" "$_uuid" "$MAIN_GETSTARTED_TEXT_ID" "$(main_getstarted_text "$_uuid")"
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
