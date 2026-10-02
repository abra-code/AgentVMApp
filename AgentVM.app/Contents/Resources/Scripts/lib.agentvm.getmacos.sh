#!/bin/sh
# lib.agentvm.getmacos.sh
#
# The Get macOS window (AgentVM.getmacos.json, the views 3001-3008 and 3010): the newest macOS restore file
# Apple offers for this Mac, whether it is downloaded, partly downloaded or not, whether it
# fits, the restore files downloaded already, and Download, which starts `agent-vm image
# fetch-ipsw` as a job. One window at a time (lib.agentvm.ui.sh, "Box windows", with the kind
# "getmacos" and the name "window"), opened by the Get macOS button of the main window's image
# list and of the New Image window's first step.
#
# THE WINDOW STARTS ONE JOB AND CLOSES. Download starts the job, opens its progress window
# (lib.agentvm.progress.sh), which has the percentage and Stop, has the main window read the
# jobs again, and closes. A download that was stopped keeps what it got, and the next one goes
# on from there. While a download job runs, the window says so and Progress... shows it.
#
# WHAT IT READS: on opening, `status` (for a download that runs) and the restore files
# downloaded, both at once, and then what Apple offers (`image fetch-ipsw --check`, which asks
# Apple and downloads nothing; it takes a few seconds, and needs the network). Activation reads
# the first two again; Check Again reads all three. It has no poll loop. What Apple offers is
# the cache file check.tsv, or check-error with agent-vm's words when it could not be asked.
#
# Sources lib.agentvm.main.sh, and lib.agentvm.wizard.sh for the one-click-at-a-time mark of
# Download. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_GETMACOS_LIB:-}" ] && return 0
__AGENTVM_APP_GETMACOS_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

GETMACOS_LATEST_ID=3001
GETMACOS_STATE_ID=3002
GETMACOS_ROOM_ID=3003
GETMACOS_FILES_ID=3004
GETMACOS_COMMAND_ID=3005
GETMACOS_NOTE_ID=3006
GETMACOS_CHECK_ID=3007
GETMACOS_PROGRESS_ID=3008
GETMACOS_DOWNLOAD_ID=3010

# getmacos_is <uuid>  ->  0 while that window is an open Get macOS window.
getmacos_is() {
    [ "$(ui_get getmacos "$1")" = "1" ]
}

# -- Reading -------------------------------------------------------------------------------------

# getmacos_read <uuid> [full]  ->  0 with `status` (main_read_status's files, for the jobs) and
# the restore files downloaded (ipsw.tsv) read anew; "full" first checks which agent-vm runs (on
# opening). An agent-vm that cannot be used is not run. A failed restore file list keeps the
# previous one.
getmacos_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    main_read_status "$1"
    local _status=$?
    local _json _list_status
    _json="$(agentvm_ipsw_list)"
    _list_status=$?
    if [ "$_list_status" -eq 0 ]; then
        printf '%s\n' "$_json" | agentvm_ipsw_rows | ui_store "$(ui_cache "$1" ipsw.tsv)"
    fi
    return "$_status"
}

# getmacos_check <uuid>  ->  0 with what Apple offers in the cache file check.tsv
# (agentvm_ipsw_check_row); otherwise agent-vm's status, with its words in check-error and the
# previous answer removed: an old answer beside a new error would say two things.
getmacos_check() {
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    local _json _status
    _json="$(agentvm_ipsw_check)"
    _status=$?
    if [ "$_status" -ne 0 ]; then
        ui_one_line "$(agentvm_last_error "$_status")" | ui_store "$(ui_cache "$1" check-error)"
        : | ui_store "$(ui_cache "$1" check.tsv)"
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_ipsw_check_row | ui_store "$(ui_cache "$1" check.tsv)"
    : | ui_store "$(ui_cache "$1" check-error)"
    return 0
}

# getmacos_field <uuid> <n>  ->  field n of what Apple offers (agentvm_ipsw_check_row), or "-"
# when it is not known.
getmacos_field() {
    local _value="$(main_rows "$1" check | /usr/bin/sed -n '1p' | /usr/bin/cut -f"$2")"
    printf '%s\n' "${_value:--}"
}

# getmacos_job <uuid>  ->  the row of the download job that runs or waits, or nothing.
getmacos_job() {
    main_rows "$1" jobs | /usr/bin/awk -F'\t' '
        $3 == "ipsw" && $2 == "running" { running = $0 }
        $3 == "ipsw" && $2 == "queued" { queued = $0 }
        END { if (running != "") print running; else if (queued != "") print queued }'
}

# -- What the window says ------------------------------------------------------------------------

# getmacos_unreadable <uuid>  ->  why agent-vm cannot be asked, or nothing.
getmacos_unreadable() {
    if [ "$(main_agentvm_line "$1" 1)" != "0" ]; then
        main_agentvm_line "$1" 2
    fi
    return 0
}

# getmacos_latest_text <uuid>  ->  the restore file Apple offers: "macOS 27.0.1 (26A434), 26.6 GB";
# or that Apple is being asked, could not be asked, or that agent-vm's answer says nothing.
getmacos_latest_text() {
    [ -z "$(getmacos_unreadable "$1")" ] || return 0
    local _error="$(/bin/cat "$(ui_cache "$1" check-error)" 2>/dev/null)"
    if [ -n "$_error" ]; then
        printf 'Apple could not be asked for the newest macOS: %s\n' "$_error"
        return 0
    fi
    # No answer yet (the window opens, and Apple is being asked), or an answer agent-vm gave that
    # says nothing: the second must not read as the first, which would stay for good.
    if [ ! -f "$(ui_cache "$1" check.tsv)" ]; then
        printf 'Asking Apple for the newest macOS this Mac can run...\n'
        return 0
    fi
    if [ -z "$(main_rows "$1" check)" ]; then
        printf 'agent-vm did not say which macOS Apple offers. Check Again asks once more.\n'
        return 0
    fi
    local _version="$(getmacos_field "$1" 2)"
    local _build="$(getmacos_field "$1" 3)"
    local _size="$(ui_size_text "$(getmacos_field "$1" 4)")"
    local _text="The newest restore file for this Mac"
    [ "$_version" != "-" ] && _text="macOS $_version"
    [ "$_version" != "-" ] && [ "$_build" != "-" ] && _text="$_text ($_build)"
    printf '%s%s\n' "$_text" "${_size:+, $_size}"
}

# getmacos_state_text <uuid>  ->  whether that file is here: downloaded, partly, or not.
getmacos_state_text() {
    local _total="$(getmacos_field "$1" 4)"
    local _partial="$(getmacos_field "$1" 5)"
    case "$(getmacos_field "$1" 1)" in
        ready)
            printf 'Downloaded. The New Image window lists it as a start.\n' ;;
        partial)
            # A percentage only of two numbers that can be one: a size that is known, and no more
            # got so far than the file has.
            local _percent=""
            case "$_total$_partial" in
                *[!0123456789]*) ;;
                *)  _percent="$(/usr/bin/awk -v p="$_partial" -v t="$_total" 'BEGIN { if (t > 0 && p <= t) printf "%d", p * 100 / t }')" ;;
            esac
            if [ -n "$_percent" ]; then
                printf '%s%% downloaded (%s of %s). Download goes on from there.\n' \
                    "$_percent" "$(ui_size_text "$_partial")" "$(ui_size_text "$_total")"
            else
                printf 'Partly downloaded. Download goes on from there.\n'
            fi ;;
        missing)
            printf 'Not downloaded yet.\n' ;;
    esac
}

# getmacos_room_text <uuid>  ->  whether the rest of the download fits; nothing once it is
# downloaded, or while it is not known.
getmacos_room_text() {
    case "$(getmacos_field "$1" 1)" in
        partial|missing) ;;
        *) return 0 ;;
    esac
    local _free="$(ui_size_text "$(getmacos_field "$1" 6)")"
    local _have=""
    [ -n "$_free" ] && _have="$_free free on the volume of the store: "
    case "$(getmacos_field "$1" 7)" in
        true)  printf '%sit fits.\n' "$_have" ;;
        false) printf '%snot enough. At least 10 GB must stay free after the download.\n' "$_have" ;;
    esac
}

# getmacos_file_rows <uuid>  ->  the rows of the table of restore files downloaded: name, macOS
# and build, size, and "newest" for the one `image create --ipsw latest` uses.
getmacos_file_rows() {
    main_rows "$1" ipsw | /usr/bin/awk -F'\t' '{
        size = ($4 ~ /^[0-9]+$/) ? sprintf("%.1f GB", $4 / 1000000000) : "-"
        macos = $2
        if ($3 != "-") macos = macos " (" $3 ")"
        printf "%s\t%s\t%s\t%s\n", $1, macos, size, ($5 == "true") ? "newest here" : "" }'
}

# getmacos_blocker <uuid>  ->  why Download cannot start now, or nothing: agent-vm cannot be
# used, a download already runs, the file is here, or it does not fit.
getmacos_blocker() {
    local _why="$(getmacos_unreadable "$1")"
    if [ -n "$_why" ]; then
        printf '%s\n' "$_why"
        return 0
    fi
    local _error="$(main_status_error "$1")"
    if [ -n "$_error" ]; then
        printf 'agent-vm could not be read: %s\n' "$_error"
        return 0
    fi
    if [ -n "$(getmacos_job "$1")" ]; then
        printf 'A download is running. Progress... shows how far it is, and has Stop.\n'
        return 0
    fi
    case "$(getmacos_field "$1" 1)" in
        ready) printf 'The newest macOS is downloaded already.\n' ;;
        partial|missing)
            [ "$(getmacos_field "$1" 7)" = "false" ] && printf 'There is not enough room for the download. Free some space on the volume of the store, then Check Again.\n' ;;
    esac
    return 0
}

# -- Painting ------------------------------------------------------------------------------------

# getmacos_paint <uuid>  ->  the window from its cache. Download is on when nothing stands in
# the way (also when Apple could not be asked: the job asks again, and says why it fails);
# Progress... is on while a download runs.
getmacos_paint() {
    "$dialog" "$1" "$GETMACOS_LATEST_ID" "$(getmacos_latest_text "$1")"
    "$dialog" "$1" "$GETMACOS_STATE_ID" "$(getmacos_state_text "$1")"
    "$dialog" "$1" "$GETMACOS_ROOM_ID" "$(getmacos_room_text "$1")"
    getmacos_file_rows "$1" | "$dialog" "$1" "$GETMACOS_FILES_ID" omc_table_set_rows_from_stdin
    "$dialog" "$1" "$GETMACOS_COMMAND_ID" "agent-vm image fetch-ipsw"
    local _blocker="$(getmacos_blocker "$1")"
    "$dialog" "$1" "$GETMACOS_NOTE_ID" "$_blocker"
    if [ -z "$_blocker" ]; then
        ui_enable "$1" "$GETMACOS_DOWNLOAD_ID" 1
    else
        ui_enable "$1" "$GETMACOS_DOWNLOAD_ID" 0
    fi
    if [ -n "$(getmacos_job "$1")" ]; then
        ui_enable "$1" "$GETMACOS_PROGRESS_ID" 1
    else
        ui_enable "$1" "$GETMACOS_PROGRESS_ID" 0
    fi
    if [ -z "$(getmacos_unreadable "$1")" ]; then
        ui_enable "$1" "$GETMACOS_CHECK_ID" 1
    else
        ui_enable "$1" "$GETMACOS_CHECK_ID" 0
    fi
}

# getmacos_refresh <uuid> [check]  ->  reads `status` and the files, and with "check" what Apple
# offers, then paints. For the window that closed while agent-vm was read, or while this painted
# (painting reads the cache, which makes its folder again), the cache folder goes: so whether the
# window is still there is asked once more, last.
getmacos_refresh() {
    getmacos_read "$1"
    [ "${2:-}" = "check" ] && getmacos_check "$1"
    if ! getmacos_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    getmacos_paint "$1"
    getmacos_is "$1" || ui_cache_clear "$1"
    return 0
}
