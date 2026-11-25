#!/bin/sh
# lib.agentvm.discard.sh
#
# The Discard Sessions window (AgentVM.discard.json, the views 5402-5406): discards the ended and
# undone sessions of every project at once, those that ended before a day or all of them. One
# window at a time (lib.agentvm.ui.sh, "Box windows", with the kind "discard" and the name
# "window"), opened by the button after the plus in the Sessions tab's toolbar.
#
# THE SESSIONS are those of the main window's cache (ses_session_rows), read again when the window
# opens; what they free is summed from its measurement (ses_space_phrase). The window's values are
# "discard" (set while it is an open Discard Sessions window), "discard-choice" (before or all),
# "discard-date" (the day, YYYY-MM-DD, as the date picker gives it) and "discard-ids" (the
# sessions the line above the buttons counts, as last painted). The day defaults to
# DSC_DEFAULT_DAYS ago. A session that ended before that day, at midnight on this Mac, is taken;
# one that never ended counts from its start, as `session discard --older-than` counts.
#
# Discard closes the window and discards through ses_discard in the main window, which leaves
# active sessions out, reads the list again, and says what it freed there. Projects keep their
# cards while their folders are there (lib.agentvm.sessions.sh).
#
# Sources lib.agentvm.main.sh and lib.agentvm.wizard.sh. POSIX sh (bash 3.2 in POSIX mode) only.
# Validate with "sh -n".
[ -n "${__AGENTVM_APP_DISCARD_LIB:-}" ] && return 0
__AGENTVM_APP_DISCARD_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

DSC_CHOICE_ID=5402
DSC_DATE_ID=5403
DSC_SUMMARY_ID=5404
DSC_GO_ID=5406
# The day the date picker starts at: this many days ago.
DSC_DEFAULT_DAYS=30

# dsc_is <uuid>  ->  0 while that window is an open Discard Sessions window.
dsc_is() {
    [ -n "$(ui_get discard "$1")" ]
}

# dsc_ask <command guid>  ->  the Discard Sessions window in front: the open one, or a new one.
dsc_ask() {
    ui_item_open discard window "$1"
}

# dsc_day <text>  ->  the day when the text is one (YYYY-MM-DD, or a date picker's ISO date and
# time, whose day is taken), or nothing.
dsc_day() {
    local _day="$(printf '%s' "$1" | /usr/bin/cut -c1-10)"
    case "$_day" in
        [0123456789][0123456789][0123456789][0123456789]-[0123456789][0123456789]-[0123456789][0123456789]) printf '%s\n' "$_day" ;;
    esac
}

# dsc_cutoff <YYYY-MM-DD>  ->  the last second before that day begins on this Mac, in seconds since
# the epoch, or nothing when the day is not one.
dsc_cutoff() {
    local _seconds
    _seconds="$(/bin/date -j -f '%Y-%m-%d %H:%M:%S' "$1 00:00:00" '+%s' 2>/dev/null)"
    case "$_seconds" in
        ''|*[!0123456789]*) return 0 ;;
    esac
    printf '%s\n' "$((_seconds - 1))"
}

# dsc_day_text <YYYY-MM-DD>  ->  the day for a sentence: "Oct 26 2026".
dsc_day_text() {
    /bin/date -j -f '%Y-%m-%d' "$1" '+%b %e %Y' 2>/dev/null | /usr/bin/sed 's/  / /'
}

# dsc_ids <uuid> <main window uuid>  ->  the ids of the sessions the window has chosen, separated
# by spaces.
dsc_ids() {
    if [ "$(ui_get discard-choice "$1")" = "all" ]; then
        ses_session_rows "$2" | /usr/bin/awk -F'\t' '$3 != "active" { print $1 }' | /usr/bin/paste -sd ' ' -
        return 0
    fi
    local _cutoff="$(dsc_cutoff "$(ui_get discard-date "$1")")"
    [ -n "$_cutoff" ] || return 0
    ses_ended_by_ids "$2" "$_cutoff"
}

# dsc_summary <uuid> <main window uuid> <ids>  ->  the line above the buttons: how many sessions of
# how many projects, and what discarding them frees; or that there are none.
dsc_summary() {
    if [ -z "$3" ]; then
        if [ "$(ui_get discard-choice "$1")" = "all" ]; then
            printf 'No session has ended: there is nothing to discard.\n'
        else
            printf 'No session ended before %s.\n' "$(dsc_day_text "$(ui_get discard-date "$1")")"
        fi
        return 0
    fi
    local _count="$(printf '%s\n' "$3" | /usr/bin/awk '{ print NF }')"
    local _projects="$(ses_session_rows "$2" | DSC_IDS=" $3 " /usr/bin/awk -F'\t' 'index(ENVIRON["DSC_IDS"], " " $1 " ") && !seen[$2]++' | /usr/bin/awk 'END { print NR }')"
    printf '%s of %s: %s.\n' "$(main_count_text "$_count" session)" "$(main_count_text "$_projects" project)" "$(ses_space_phrase "$2" "$3")"
}

# dsc_paint <uuid>  ->  the date picker on while the choice is a day, the line above the buttons,
# and Discard on while there is something to discard.
dsc_paint() {
    local _uuid="$1"
    local _main="$(ui_item_window main window)"
    if [ "$(ui_get discard-choice "$_uuid")" = "all" ]; then
        ui_enable "$_uuid" "$DSC_DATE_ID" 0
    else
        ui_enable "$_uuid" "$DSC_DATE_ID" 1
    fi
    local _ids=""
    [ -n "$_main" ] && _ids="$(dsc_ids "$_uuid" "$_main")"
    # What the line counts is what Discard may take (dsc_go).
    ui_set discard-ids "$_uuid" "$_ids"
    "$dialog" "$_uuid" "$DSC_SUMMARY_ID" "$(dsc_summary "$_uuid" "$_main" "$_ids")"
    if [ -n "$_ids" ]; then
        ui_enable "$_uuid" "$DSC_GO_ID" 1
    else
        ui_enable "$_uuid" "$DSC_GO_ID" 0
    fi
}

# dsc_open <uuid> <main window uuid>  ->  the window starts: a day DSC_DEFAULT_DAYS ago, the list
# read again, and painted.
dsc_open() {
    local _uuid="$1"
    local _day="$(/bin/date -r $(( $(main_now) - DSC_DEFAULT_DAYS * 86400 )) '+%Y-%m-%d')"
    ui_set discard-choice "$_uuid" before
    ui_set discard-date "$_uuid" "$_day"
    "$dialog" "$_uuid" "$DSC_CHOICE_ID" before
    "$dialog" "$_uuid" "$DSC_DATE_ID" "$_day"
    ses_read "$2"
    ses_paint "$2"
    dsc_paint "$_uuid"
}

# dsc_choose <uuid> <before|all>  ->  the choice kept, and the window painted.
dsc_choose() {
    case "$2" in
        before|all) ui_set discard-choice "$1" "$2" ;;
        *) return 0 ;;
    esac
    dsc_paint "$1"
}

# dsc_set_day <uuid> <date picker value>  ->  the day kept, and the window painted.
dsc_set_day() {
    local _day="$(dsc_day "$2")"
    [ -n "$_day" ] || return 0
    ui_set discard-date "$1" "$_day"
    dsc_paint "$1"
}

# dsc_go <uuid>  ->  Discard: the sessions chosen, as painted, are discarded in the main window,
# after this window closes. Only those the line counted: a session listed since (the main window
# read the list again) is not taken, and one gone since is left out. With none left, the window
# is painted again.
dsc_go() {
    local _uuid="$1"
    local _main="$(ui_item_window main window)"
    if [ -z "$_main" ]; then
        "$dialog" "$_uuid" omc_window omc_terminate_cancel
        return 0
    fi
    local _painted=" $(ui_get discard-ids "$_uuid") "
    local _ids="" _id
    for _id in $(dsc_ids "$_uuid" "$_main"); do
        case "$_painted" in
            *" $_id "*) _ids="$_ids $_id" ;;
        esac
    done
    _ids="${_ids# }"
    if [ -z "$_ids" ]; then
        dsc_paint "$_uuid"
        return 0
    fi
    "$dialog" "$_uuid" omc_window omc_terminate_cancel
    ses_discard "$_main" "$_ids"
}
