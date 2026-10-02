#!/bin/sh
# lib.agentvm.wizard.sh
#
# What the windows that work in steps share (New Image, lib.agentvm.newimage.sh; New Box,
# lib.agentvm.newbox.sh): a rail of steps on the left with a mark per step, one panel shown at a
# time, a note line, and Cancel, Back, and Continue or the last step's own button.
#
# THE VIEW IDS of such a window are a base (1000, 2000) plus: 1 the header; 10 + n, 20 + n and
# 30 + n the rail's marks of step n (to do, now, done); 40 + n its panel; 91 the note line; 93
# Back; 94 Continue; 95 the last step's button.
#
# ONE CLICK AT A TIME (wizard_enter). A handler's view of the fields is a snapshot from the moment
# of its click, and the fields of a step are filled before the step is shown. A second click made
# while the first one's step is being filled carries fields from before the filling, so it is
# dropped.
#
# Sources lib.agentvm.ui.sh. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_WIZARD_LIB:-}" ] && return 0
__AGENTVM_APP_WIZARD_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.ui.sh"

# wizard_enter <uuid>  ->  0 when the handler that runs may act on a click: no other click of
# the window is still being worked on. The mark is the window's value "busy", as
# "click-<the handler's process>", and goes when the handler exits; one whose process is gone (a
# handler that was killed) holds nothing.
wizard_enter() {
    local _holder="$(ui_get busy "$1")"
    case "$_holder" in
        click-|click-0*|click-*[!0123456789]*) ;;
        click-*)
            kill -0 "${_holder#click-}" 2>/dev/null && return 1 ;;
    esac
    ui_set busy "$1" "click-$$"
    wizard_busy_uuid="$1"
    trap 'wizard_leave' EXIT
    return 0
}

# wizard_leave  ->  the mark of wizard_enter goes, if this handler's it still is.
wizard_leave() {
    [ -n "${wizard_busy_uuid:-}" ] || return 0
    [ "$(ui_get busy "$wizard_busy_uuid")" = "click-$$" ] || return 0
    ui_set busy "$wizard_busy_uuid" ""
}

# wizard_listed <word> <lines>  ->  0 when the word is one of the lines.
wizard_listed() {
    case "
$2
" in
        *"
$1
"*) return 0 ;;
    esac
    return 1
}

# wizard_number <text>  ->  0 when it is a whole number, 1 or more, of at most 5 digits.
wizard_number() {
    case "$1" in
        ''|*[!0123456789]*|0*) return 1 ;;
    esac
    [ "${#1}" -le 5 ]
}

# wizard_paint_frame <uuid> <base> <steps> <step> <title> [note]  ->  what every step has: the
# header, the rail's marks, the panel of the step shown, Back, Continue or the last step's
# button, and the note line.
wizard_paint_frame() {
    local _base="$2"
    local _steps="$3"
    local _step="$4"
    "$dialog" "$1" "$((_base + 1))" "Step $_step of $_steps - $5"
    local _n=0 _todo _now _done
    while [ "$_n" -lt "$_steps" ]; do
        _n=$((_n + 1))
        _todo=0
        _now=0
        _done=0
        if [ "$_n" -lt "$_step" ]; then
            _done=1
        elif [ "$_n" -eq "$_step" ]; then
            _now=1
        else
            _todo=1
        fi
        ui_show "$1" "$((_base + 10 + _n))" "$_todo"
        ui_show "$1" "$((_base + 20 + _n))" "$_now"
        ui_show "$1" "$((_base + 30 + _n))" "$_done"
        ui_show "$1" "$((_base + 40 + _n))" "$_now"
    done
    if [ "$_step" -gt 1 ]; then
        ui_enable "$1" "$((_base + 93))" 1
    else
        ui_enable "$1" "$((_base + 93))" 0
    fi
    if [ "$_step" -eq "$_steps" ]; then
        ui_show "$1" "$((_base + 94))" 0
        ui_show "$1" "$((_base + 95))" 1
    else
        ui_show "$1" "$((_base + 95))" 0
        ui_show "$1" "$((_base + 94))" 1
    fi
    "$dialog" "$1" "$((_base + 91))" "${6:-}"
}
