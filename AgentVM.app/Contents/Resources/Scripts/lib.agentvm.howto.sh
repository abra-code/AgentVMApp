#!/bin/sh
# lib.agentvm.howto.sh
#
# The How to Use a Box window (AgentVM.howto.json, the views 4102 and 4111-4135): the ways into
# a box, as lines to copy for Terminal (avm), and where an agent's key is stored. One window at
# a time (lib.agentvm.ui.sh, "Box windows", with the kind "howto" and the name "window"), opened
# by the question mark under the main window's box list.
#
# THE LINES name what exists: the first ready image and the first kept box of `status`, read
# on opening and when the window comes to the front, or the names "dev" and "work" when there
# is none. They are the cache file lines.tsv: number, command, what it does. Copy puts the
# command of its line on the clipboard, as the window shows it: the text goes to pbcopy's stdin.
#
# It changes nothing and runs no box: it only says how.
#
# Sources lib.agentvm.main.sh. POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_HOWTO_LIB:-}" ] && return 0
__AGENTVM_APP_HOWTO_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

pbcopy_tool="${AGENTVM_APP_PBCOPY:-/usr/bin/pbcopy}"

HOWTO_NOTE_ID=4102
# Line n has its command in HOWTO_COMMAND_BASE + n, its Copy button in HOWTO_COPY_BASE + n and
# what it does in HOWTO_WHAT_BASE + n.
HOWTO_COMMAND_BASE=4110
HOWTO_COPY_BASE=4120
HOWTO_WHAT_BASE=4130
HOWTO_LINES=5

# howto_is <uuid>  ->  0 while that window is an open How to Use a Box window.
howto_is() {
    [ "$(ui_get howto "$1")" = "1" ]
}

# howto_avm  ->  where agent-vm's installer puts avm.
howto_avm() {
    printf '%s/.local/bin/avm\n' "$HOME"
}

# howto_read <uuid> [full]  ->  `status` read anew for the names the lines use; "full" first
# checks which agent-vm runs (on opening). An agent-vm that cannot be used is not run: the
# lines then use the example names.
howto_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    main_read_status "$1"
}

# howto_line_rows <uuid>  ->  the lines: number, command, what it does.
howto_line_rows() {
    local _image="$(main_rows "$1" images | /usr/bin/awk -F'\t' '$2 == "ready" { print $1; exit }')"
    local _box="$(main_rows "$1" boxes | /usr/bin/awk -F'\t' '$13 != "true" { print $1; exit }')"
    local _image_note="" _box_note=""
    if [ -z "$_image" ]; then
        _image="dev"
        _image_note=" No image is ready yet: dev stands for the one you build."
    fi
    if [ -z "$_box" ]; then
        _box="work"
        _box_note=" No kept box exists yet: work stands for one you make."
    fi
    printf '1\tavm\tChoose a box, then what to run in it: an agent, a shell or a command. Current working directory is shared into the box and any changes there can be undone afterwards.\n'
    printf '2\tavm new %s\tRun in a new temporary box from the image "%s", used once and deleted when you leave it.%s\n' "$_image" "$_image" "$_image_note"
    printf '3\tavm new %s --name work\tRun in a new box named "work" from the image "%s". The box is preserved.%s\n' "$_image" "$_image" "$_image_note"
    printf '4\tavm %s\tRun avm in existing box "%s". It is started if needed and runs on afterwards.%s\n' "$_box" "$_box" "$_box_note"
    printf '5\t~/.local/bin/avm\tFull path to avm tool.\n'
}

# howto_note_text  ->  whether avm is where the installer puts it.
howto_note_text() {
    if [ -x "$(howto_avm)" ]; then
        printf 'avm is installed in ~/.local/bin/. If Terminal cannot find it, that directory is not in your shell'"'"'s PATH list: use the full path.\n'
    else
        printf 'avm is not in ~/.local/bin/ on this Mac. It comes with agent-vm'"'"'s installer, beside agent-vm.\n'
    fi
}

# howto_paint <uuid>  ->  the lines, kept as lines.tsv for Copy, and the note about avm.
howto_paint() {
    howto_line_rows "$1" | ui_store "$(ui_cache "$1" lines.tsv)"
    main_rows "$1" lines | {
        local _n _command _what
        while IFS="$ui_tab" read -r _n _command _what; do
            "$dialog" "$1" "$(( HOWTO_COMMAND_BASE + _n ))" "$_command"
            "$dialog" "$1" "$(( HOWTO_WHAT_BASE + _n ))" "$_what"
        done
    }
    "$dialog" "$1" "$HOWTO_NOTE_ID" "$(howto_note_text)"
}

# howto_refresh <uuid> [full]  ->  reads and paints. For the window that closed while agent-vm
# was read, or while this painted (painting reads the cache, which makes its folder again), the
# cache folder goes: so whether the window is still there is asked once more, last.
howto_refresh() {
    howto_read "$1" "${2:-}"
    if ! howto_is "$1"; then
        ui_cache_clear "$1"
        return 0
    fi
    howto_paint "$1"
    howto_is "$1" || ui_cache_clear "$1"
    return 0
}

# howto_copy <uuid> <line number>  ->  0 with that line's command on the clipboard; 1 when there
# is no such line, or the clipboard could not be written.
howto_copy() {
    case "$2" in
        1|2|3|4|5) ;;
        *) return 1 ;;
    esac
    local _command="$(main_rows "$1" lines | /usr/bin/awk -F'\t' -v n="$2" '$1 "" == n { print $2; exit }')"
    [ -n "$_command" ] || return 1
    printf '%s' "$_command" | "$pbcopy_tool"
    local _status=$?
    [ "$_status" -eq 0 ] || return 1
    "$dialog" "$1" "$HOWTO_NOTE_ID" "Copied: $_command"
    return 0
}
