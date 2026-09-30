#!/bin/sh
# lib.agentvm.image.sh
#
# An image's window (AgentVM.image.json): its view ids, what it reads from agent-vm, and how it
# paints. One window per image (lib.agentvm.ui.sh, "Item windows"); the image's name is the
# window's pasteboard value "item", set by the init handler from the open request.
#
# WHAT IT READS, on opening and on every activation: agent-vm itself (which one runs, for the
# guest daemon line), `status` (the image's record, and the boxes and images made from it), and
# `image info` (the same record with what its disk takes, which agent-vm measures in 0.1-0.3 s).
# There is no poll loop: the window changes nothing by itself yet, and coming back to it
# refreshes it. An image that `status` no longer lists was deleted, from here or elsewhere.
#
# Reading and painting are separate, as in the main window: image_read leaves agent-vm's answers
# in the window's cache folder, image_paint reads only those.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_IMAGE_LIB:-}" ] && return 0
__AGENTVM_APP_IMAGE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

IMAGE_FACTS_ID=401
IMAGE_NOTE_ID=402
IMAGE_TOOLS_ID=403
IMAGE_GUEST_ID=404
IMAGE_FDA_ID=405
IMAGE_SPACE_ID=406
IMAGE_FOLDER_ID=407
IMAGE_SHOW_ID=408
IMAGE_BOXES_ID=410
IMAGE_DERIVED_ID=411
IMAGE_NEW_BOX_ID=420
IMAGE_NEW_IMAGE_ID=421
IMAGE_UPDATE_GUEST_ID=422
IMAGE_SETUP_ID=423
IMAGE_DELETE_ID=424

# -- Reading ------------------------------------------------------------------------------------

# image_read <uuid> <name>  ->  the window's cache files:
#   agentvm      two lines: agentvm_available's status and its line (the version, or why not)
#   images.tsv, boxes.tsv   status's rows (lib.agentvm.sh), kept from the last success
#   info.tsv     agentvm_image_info_row's row for this image, or empty
#   error        why agent-vm could not answer, on one line, or empty
# Returns 0; agentvm_available's status (1-3) when agent-vm cannot be used; 10 when `status`
# failed (the rows are the last ones read); 11 when only `image info` failed (the rows are current).
# The error line says which of the two failed.
image_read() {
    local _uuid="$1"
    local _name="$2"
    local _available
    _available="$(agentvm_available)"
    local _status=$?
    printf '%s\n%s\n' "$_status" "$(ui_one_line "$_available")" | ui_store "$(ui_cache "$_uuid" agentvm)"
    local _error="$(ui_cache "$_uuid" error)"
    : | ui_store "$(ui_cache "$_uuid" info.tsv)"
    if [ "$_status" -ne 0 ]; then
        : | ui_store "$_error"
        return "$_status"
    fi
    local _json
    _json="$(agentvm_status)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "agent-vm status failed: $(agentvm_last_error "$_status")" | ui_store "$_error"
        return 10
    fi
    printf '%s\n' "$_json" | agentvm_status_image_rows | ui_store "$(ui_cache "$_uuid" images.tsv)"
    printf '%s\n' "$_json" | agentvm_status_box_rows | ui_store "$(ui_cache "$_uuid" boxes.tsv)"
    : | ui_store "$_error"
    # Gone: nothing to measure, and `image info` would only say so.
    local _row="$(image_status_row "$_uuid" "$_name")"
    [ -n "$_row" ] || return 0
    _json="$(agentvm_image_info "$_name")"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "agent-vm could not measure it: $(agentvm_last_error "$_status")" | ui_store "$_error"
        return 11
    fi
    printf '%s\n' "$_json" | agentvm_image_info_row | ui_store "$(ui_cache "$_uuid" info.tsv)"
    return 0
}

# image_cached <uuid> <file>  ->  that cache file's non-empty lines, nothing when it is missing.
image_cached() {
    local _file="$(ui_cache "$1" "$2")"
    [ -f "$_file" ] || return 0
    /usr/bin/awk 'NF' "$_file"
}

# image_status_row <uuid> <name>  ->  status's row of that image, or nothing: it is gone.
image_status_row() {
    image_cached "$1" images.tsv | /usr/bin/awk -F'\t' -v name="$2" '$1 == name { print; exit }'
}

# image_boxes <uuid> <name>  ->  "box (state)" for each box made from the image, one per line.
image_boxes() {
    image_cached "$1" boxes.tsv | /usr/bin/awk -F'\t' -v name="$2" '$3 == name { printf "%s (%s)\n", $1, $2 }'
}

# image_derived <uuid> <name>  ->  each image built from the image, one per line.
image_derived() {
    image_cached "$1" images.tsv | /usr/bin/awk -F'\t' -v name="$2" '$6 == name { print $1 }'
}

# image_list_text <lines>  ->  the lines as "a", "a and b", "a, b and c", or "none".
image_list_text() {
    [ -n "$1" ] || {
        echo "none"
        return 0
    }
    local _saved="$IFS"
    IFS='
'
    set -- $1
    IFS="$_saved"
    ui_names_text "$@"
}

# -- Painting -----------------------------------------------------------------------------------

# image_facts_text <row>  ->  the first line: state, macOS, where it came from and when, and its
# processors and memory when `image info` gave them.
image_facts_text() {
    printf '%s\n' "$1" | {
        local _name _state _failure _macos _build _based _recipe _needs _guest _created _path
        local _features _missing _seconds _fda _checked _clt _cpus _memory _rest
        IFS="$ui_tab" read -r _name _state _failure _macos _build _based _recipe _needs _guest _created _path \
            _features _missing _seconds _fda _checked _clt _cpus _memory _rest
        local _text="$_state  -  macOS $_macos ($_build)"
        local _date="$(ui_date_text "$_created")"
        local _took="$(ui_duration_text "${_seconds:--}")"
        if [ "$_based" = "-" ]; then
            _text="$_text  -  made from a restore file${_date:+ on $_date}"
        else
            _text="$_text  -  built from $_based${_date:+ on $_date}${_took:+ in $_took}"
        fi
        local _hardware=""
        [ "${_cpus:--}" != "-" ] && _hardware="$_cpus CPUs"
        [ "${_memory:--}" != "-" ] && _hardware="${_hardware:+$_hardware, }$_memory GB"
        [ -n "$_hardware" ] && _text="$_text  -  $_hardware"
        printf '%s\n' "$_text"
    }
}

# image_paint <uuid>  ->  the whole window from the caches.
image_paint() {
    local _uuid="$1"
    local _name="$(ui_get item "$_uuid")"
    "$dialog" "$_uuid" omc_window "Image $_name"
    local _available="$(image_cached "$_uuid" agentvm | /usr/bin/sed -n 1p)"
    local _version="$(image_cached "$_uuid" agentvm | /usr/bin/sed -n 2p)"
    local _error="$(image_cached "$_uuid" error)"
    local _row="$(image_status_row "$_uuid" "$_name")"
    local _info="$(image_cached "$_uuid" info.tsv)"
    local _id
    if [ "$_available" != "0" ] || [ -z "$_row" ]; then
        if [ "$_available" != "0" ]; then
            "$dialog" "$_uuid" "$IMAGE_FACTS_ID" "agent-vm cannot be used"
            "$dialog" "$_uuid" "$IMAGE_NOTE_ID" "$_version"
        elif [ -n "$_error" ]; then
            "$dialog" "$_uuid" "$IMAGE_FACTS_ID" "agent-vm did not answer"
            "$dialog" "$_uuid" "$IMAGE_NOTE_ID" "$_error"
        else
            "$dialog" "$_uuid" "$IMAGE_FACTS_ID" "Image $_name no longer exists."
            "$dialog" "$_uuid" "$IMAGE_NOTE_ID" ""
        fi
        for _id in $IMAGE_TOOLS_ID $IMAGE_GUEST_ID $IMAGE_FDA_ID $IMAGE_SPACE_ID $IMAGE_FOLDER_ID $IMAGE_BOXES_ID $IMAGE_DERIVED_ID; do
            "$dialog" "$_uuid" "$_id" ""
        done
        ui_enable "$_uuid" "$IMAGE_SHOW_ID" 0
        ui_enable "$_uuid" "$IMAGE_DELETE_ID" 0
        return 0
    fi
    # `image info` has the status row's eleven fields and more; without it (it failed), the
    # status row serves and the fields after the eleventh read as absent.
    [ -n "$_info" ] && _row="$_info"
    "$dialog" "$_uuid" "$IMAGE_FACTS_ID" "$(image_facts_text "$_row")"
    printf '%s\n' "$_row" | {
        local _n _state _failure _macos _build _based _recipe _needs _guest _created _path
        local _features _missing _seconds _fda _checked _clt _cpus _memory _bytes _unshared _added _rest
        IFS="$ui_tab" read -r _n _state _failure _macos _build _based _recipe _needs _guest _created _path \
            _features _missing _seconds _fda _checked _clt _cpus _memory _bytes _unshared _added _rest
        # The note: a failed build's reason, or why the sizes are missing.
        local _text=""
        if [ "$_state" = "failed" ]; then
            if [ "$_failure" = "-" ]; then
                _text="The build failed, and agent-vm gave no reason."
            else
                _text="The build failed: ${_failure%.}."
            fi
        fi
        [ -n "$_error" ] && _text="${_text:+$_text }$_error"
        "$dialog" "$_uuid" "$IMAGE_NOTE_ID" "$_text"

        _text=""
        [ "$_recipe" != "-" ] && _text="$_recipe"
        [ "${_clt:--}" != "-" ] && _text="${_text:+$_text; }$_clt"
        "$dialog" "$_uuid" "$IMAGE_TOOLS_ID" "Tools: ${_text:-macOS only}"

        _text="Guest daemon $_guest"
        [ "${_features:--}" != "-" ] && _text="$_text: $(printf '%s' "$_features" | /usr/bin/sed 's/,/, /g')"
        case ",$_needs," in
            *,guest-update,*)
                if [ "${_missing:--}" != "-" ]; then
                    _text="$_text. Needs a guest update for agent-vm $_version, which adds $(printf '%s' "$_missing" | /usr/bin/sed 's/,/, /g')."
                else
                    _text="$_text. Needs a guest update for agent-vm $_version."
                fi ;;
            *)  _text="$_text. Has everything agent-vm $_version uses." ;;
        esac
        "$dialog" "$_uuid" "$IMAGE_GUEST_ID" "$_text"

        local _date="$(ui_date_text "${_checked:--}")"
        case "${_fda:--}" in
            granted)     _text="Full Disk Access: granted${_date:+ (checked $_date)}." ;;
            not-granted) _text="Full Disk Access: not granted, so programs in its boxes cannot open Desktop, Documents or Downloads${_date:+ (checked $_date)}." ;;
            *)
                case ",$_needs," in
                    *,full-disk-access,*) _text="Full Disk Access: not granted, so programs in its boxes cannot open Desktop, Documents or Downloads." ;;
                    *)                    _text="Full Disk Access: not checked yet." ;;
                esac ;;
        esac
        "$dialog" "$_uuid" "$IMAGE_FDA_ID" "$_text"

        local _size="$(ui_size_text "${_bytes:--}")"
        if [ -n "$_size" ]; then
            _text="Space: $_size"
            _size="$(ui_size_text "${_unshared:--}")"
            [ -n "$_size" ] && _text="$_text; $_size its own (what Delete frees)"
            _size="$(ui_size_text "${_added:--}")"
            [ -n "$_size" ] && [ "$_based" != "-" ] && _text="$_text; $_size added over $_based"
        else
            _text="Space: not measured."
        fi
        "$dialog" "$_uuid" "$IMAGE_SPACE_ID" "$_text"

        "$dialog" "$_uuid" "$IMAGE_FOLDER_ID" "Folder: $(agentvm_display_path "$_path")"
    }
    "$dialog" "$_uuid" "$IMAGE_BOXES_ID" "Boxes made from it: $(image_list_text "$(image_boxes "$_uuid" "$_name")")."
    "$dialog" "$_uuid" "$IMAGE_DERIVED_ID" "Images built from it: $(image_list_text "$(image_derived "$_uuid" "$_name")")."
    ui_enable "$_uuid" "$IMAGE_SHOW_ID" 1
    ui_enable "$_uuid" "$IMAGE_DELETE_ID" 1
}

# image_refresh <uuid>  ->  reads agent-vm for the window's image, then paints; image_read's
# status, or 1 when the window has no image.
image_refresh() {
    local _name="$(ui_get item "$1")"
    [ -n "$_name" ] || return 1
    image_read "$1" "$_name"
    local _status=$?
    image_paint "$1"
    return "$_status"
}

# image_delete_question <uuid>  ->  the confirmation's message: what deleting frees, and what it
# means for what was made from the image (they are clones and keep working; a box can no longer
# be recreated, since recreating makes it again from its image).
image_delete_question() {
    local _uuid="$1"
    local _name="$(ui_get item "$_uuid")"
    local _text="The image's folder and disk are deleted"
    local _unshared="$(image_cached "$_uuid" info.tsv | /usr/bin/cut -f21)"
    local _size="$(ui_size_text "$_unshared")"
    [ -n "$_size" ] && _text="$_text, which frees about $_size"
    _text="$_text."
    local _boxes="$(image_cached "$_uuid" boxes.tsv | /usr/bin/awk -F'\t' -v name="$_name" '$3 == name { print $1 }')"
    if [ -n "$_boxes" ]; then
        _text="$_text Boxes made from it ($(image_list_text "$_boxes")) keep working, but cannot be recreated."
    fi
    local _derived="$(image_derived "$_uuid" "$_name")"
    if [ -n "$_derived" ]; then
        _text="$_text Images built from it ($(image_list_text "$_derived")) keep working."
    fi
    printf '%s This cannot be undone.\n' "$_text"
}
