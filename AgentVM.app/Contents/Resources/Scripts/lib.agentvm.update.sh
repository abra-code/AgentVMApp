#!/bin/sh
# lib.agentvm.update.sh
#
# An image's update window (AgentVM.update.json, the views 801-872): what `agent-vm image update`
# can bring up to date in the image, each part with a checkbox and what is known about it, what
# the update means for the boxes and images made from it, the command it runs, and Update. One
# window per image (lib.agentvm.ui.sh, "Box windows", with the kind "update" and the image's name);
# the name is the window's pasteboard value "image", set by the init handler from the open
# request. It is opened by Update... in the main window's image pane. Sources lib.agentvm.main.sh
# for the status rows and the words that name a job.
#
# THE THREE PARTS are agent-vm's: the system (for a macOS image the update Apple offers within its
# major version, and newer Command Line Tools; for a Linux image the package updates of its
# distribution), the tools (the update steps of the recipes the image keeps), and the guest daemon
# (this agent-vm's agent-vm-guest, when the image has another). A part is ticked at opening when
# something is known to need doing: a newer macOS is known, or Apple was never asked; the image
# keeps recipes; its guest daemon is another version or lacks a feature. The system of a Linux
# image is always ticked: nobody can be asked beforehand whether its packages have updates, and
# looking takes seconds. The ticks are the window's pasteboard value "choices" ("1 0 1": system,
# tools, guest), kept by the handlers, since a handler's view of the checkboxes is a snapshot.
#
# EACH PART IS agent-vm's TO ORDER. A tools update first replaces a kept recipe that is an older
# version of one that came with agent-vm by the installed one. A guest daemon asked for with
# another part is updated first, as an update of its own that is put in place before the rest
# begins: the job then boots and puts a disk in place twice, and a failure in the rest leaves the
# image with the new daemon. The window says both, and computes neither.
#
# TWO STEPS. The first has the three parts and what an update means afterwards. With the tools
# ticked its button is Continue, to the second step, which lists the recipes the image keeps
# (agentvm_status_recipe_rows), in the order they run, each in a slot with its description and
# its input files; Update is the second step's button then. Without the tools the first step is
# the only one, and its button is Update. The command line, the note line and the buttons are
# below both steps. The step shown is the pasteboard value "step" (1 or 2); the second step is
# shown only while the tools are ticked.
#
# A NEW FILE FOR A RECIPE'S INPUT (agent-vm 0.7.57) is part of the tools update: a newer Xcode
# .xip for the xcode recipe. In the second step, the slot of the recipe that takes a new file for
# an input (agentvm_status_input_rows: the last kept one that has it) has a Choose <input>...
# button, and Clear while a file is chosen; the file is kept in the window's cache file
# chosen.tsv ("<input> TAB <path>"), and the input each slot's button was last laid out for in
# the pasteboard value "inputs". Unticking the tools forgets every file chosen, so the command
# shown is always the one Update runs: `image update <name> --tools --input <input>=<path>`. The
# recipe's steps and checks then run again with the new file instead of its update steps. One
# button per slot: a recipe with a second input, or a recipe past the slots, is told to give its
# file in Terminal.
#
# THE WINDOW STARTS ONE JOB AND CLOSES. Update starts `image update <name>` with the parts ticked
# as an agent-vm job, opens that job's progress window (lib.agentvm.progress.sh), has the main
# window read the jobs again, and closes. The update goes on whether or not the app is open.
#
# WHAT IT READS: `status`, into its own cache, on opening, on activation and before Update; and
# `status --check-updates` for Check Now, which asks Apple for the newest macOS and installs
# nothing; Check Now is not shown for a Linux image, since Apple has nothing to say of one. It has
# no poll loop.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_UPDATE_LIB:-}" ] && return 0
__AGENTVM_APP_UPDATE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"
. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.wizard.sh"

UPDATE_TITLE_ID=801
UPDATE_STATE_ID=802
# The panels of the two steps.
UPDATE_PARTS_ID=803
UPDATE_RECIPES_ID=804
UPDATE_SYSTEM_ID=811
UPDATE_SYSTEM_TEXT_ID=812
UPDATE_CHECK_ID=813
UPDATE_TOOLS_ID=821
UPDATE_TOOLS_TEXT_ID=822
UPDATE_GUEST_ID=831
UPDATE_GUEST_TEXT_ID=832
UPDATE_AFTER_ID=841
UPDATE_COMMAND_ID=851
UPDATE_NOTE_ID=861
UPDATE_CANCEL_ID=871
UPDATE_START_ID=872
UPDATE_BACK_ID=873
UPDATE_NEXT_ID=874
UPDATE_RECIPES_TEXT_ID=881
# Recipe slot n: its rows 900 + n, name 920 + n, text 940 + n, Choose... 960 + n, Clear 980 + n.
UPDATE_SLOT_BASE=900
UPDATE_SLOT_NAME_BASE=920
UPDATE_SLOT_TEXT_BASE=940
UPDATE_CHOOSE_BASE=960
UPDATE_CLEAR_BASE=980
UPDATE_SLOTS=12

# update_image <uuid>  ->  the window's image, or nothing when it has none or the value is not a
# name (it comes back from a pasteboard).
update_image() {
    local _name="$(ui_get image "$1")"
    agentvm_valid_name "$_name" || return 0
    printf '%s\n' "$_name"
}

# update_read <uuid> [full|check]  ->  0 with `status` in the window's cache (main_read_status's
# files); "full" first checks which agent-vm runs (on opening), and "check" has agent-vm ask Apple
# for the newest macOS as it reads. An agent-vm that cannot be used is not run.
update_read() {
    if [ "${2:-}" = "full" ]; then
        main_read_agentvm "$1" >/dev/null
    fi
    [ "$(main_agentvm_line "$1" 1)" = "0" ] || return 1
    if [ "${2:-}" = "check" ]; then
        main_read_status "$1" check
        return $?
    fi
    main_read_status "$1"
}

# update_field <uuid> <images|updates> <name> <n>  ->  field n of the image's cached row, or "-".
update_field() {
    local _value="$(main_row "$1" "$2" "$3" | /usr/bin/cut -f"$4")"
    printf '%s\n' "${_value:--}"
}

# update_linux <uuid> <name>  ->  0 when the image runs Linux, from its cached row.
update_linux() {
    [ "$(main_guest "$1" images "$2")" = "linux" ]
}

# update_newest <uuid> <n>  ->  field n of the newest macOS row (version, build, checkedAt,
# error), or "-".
update_newest() {
    local _value="$(main_rows "$1" newest | /usr/bin/sed -n '1p' | /usr/bin/cut -f"$2")"
    printf '%s\n' "${_value:--}"
}

# update_guest_differs <uuid> <name>  ->  0 when the image's guest daemon is known to be another
# than this agent-vm's: another version, or one that lacks a feature.
update_guest_differs() {
    [ "$(update_field "$1" updates "$2" 11)" = "-" ] || return 0
    local _guest="$(update_field "$1" images "$2" 9)"
    [ "$_guest" != "$(main_agentvm_line "$1" 2)" ]
}

# update_defaults <uuid> <name>  ->  "1 0 1": the parts ticked at opening (see the header).
update_defaults() {
    local _system=0 _tools=0 _guest=0
    if update_linux "$1" "$2"; then
        _system=1
    else
        [ "$(update_field "$1" updates "$2" 6)" != "-" ] && _system=1
        [ "$(update_newest "$1" 1)" = "-" ] && _system=1
    fi
    [ "$(update_field "$1" updates "$2" 9)" != "-" ] && _tools=1
    update_guest_differs "$1" "$2" && _guest=1
    printf '%s %s %s\n' "$_system" "$_tools" "$_guest"
}

# update_first_choices <uuid>  ->  0 after keeping the parts ticked at opening (update_defaults), when
# the window keeps none yet and the image's row is known: on opening, or at the first reading that
# succeeds when agent-vm could not be read on opening. Until then nothing is known to tick, so
# nothing is kept, and the checkboxes are as the window document has them. 1 otherwise, and for a
# window that closed.
update_first_choices() {
    local _name="$(update_image "$1")"
    [ -n "$_name" ] || return 1
    [ -z "$(ui_get choices "$1")" ] || return 1
    [ -n "$(main_row "$1" images "$_name")" ] || return 1
    ui_set choices "$1" "$(update_defaults "$1" "$_name")"
}

# update_choices <uuid> <name>  ->  the parts ticked now, as "1 0 1"; a value that is not three
# of 0 and 1 is nothing ticked. The tools are never ticked for an image that keeps no recipes.
update_choices() {
    local _choices="$(ui_get choices "$1")"
    case "$_choices" in
        [01]\ [01]\ [01]) ;;
        *) _choices="0 0 0" ;;
    esac
    if [ "$(update_field "$1" updates "$2" 9)" = "-" ]; then
        _choices="${_choices%% *} 0 ${_choices##* }"
    fi
    printf '%s\n' "$_choices"
}

# update_flags <uuid> <name>  ->  the options of the parts ticked ("--system --guest"), or nothing.
update_flags() {
    # Unquoted on purpose: three words, each 0 or 1.
    agentvm_image_update_flags $(update_choices "$1" "$2")
}

# update_step <uuid> <name>  ->  the step shown: 2 while the window keeps it and the tools are
# ticked, 1 otherwise.
update_step() {
    [ "$(ui_get step "$1")" = "2" ] || { printf '1\n'; return 0; }
    case "$(update_choices "$1" "$2")" in
        [01]" 1 "[01]) printf '2\n' ;;
        *) printf '1\n' ;;
    esac
}

# update_recipe_rows <uuid> <name>  ->  the recipes the image keeps, from the cache: place, name,
# description, inputs (agentvm_status_recipe_rows without the image's name).
update_recipe_rows() {
    main_rows "$1" recipes | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name' | /usr/bin/cut -f2-
}

# update_input_rows <uuid> <name>  ->  the input files of the recipes the image keeps, from the
# cache: input, recipe, the file it was built with, where that was, the place of the recipe that
# takes a new file for it (agentvm_status_input_rows without the image's name).
update_input_rows() {
    main_rows "$1" inputs | /usr/bin/awk -F'\t' -v name="$2" '$1 "" == name' | /usr/bin/cut -f2-
}

# update_chosen <uuid> <input>  ->  the file chosen for that input, or nothing.
update_chosen() {
    local _file="$(ui_cache "$1" chosen.tsv)"
    [ -f "$_file" ] || return 0
    /usr/bin/awk -F'\t' -v input="$2" '$1 "" == input { print $2; exit }' "$_file"
}

# update_choose <uuid> <input> <path>  ->  that file is kept for the input, in place of one chosen
# before.
update_choose() {
    local _file="$(ui_cache "$1" chosen.tsv)"
    local _others=""
    if [ -f "$_file" ]; then
        _others="$(/usr/bin/awk -F'\t' -v input="$2" '$1 "" != input' "$_file")"
    fi
    { [ -n "$_others" ] && printf '%s\n' "$_others"; printf '%s\t%s\n' "$2" "$3"; } | ui_store "$_file"
}

# update_unchoose <uuid> [input]  ->  the file chosen for that input is forgotten; without one,
# every file chosen.
update_unchoose() {
    local _file="${TMPDIR:-/tmp}/AgentVM/$1/chosen.tsv"
    if [ -z "${2:-}" ]; then
        /bin/rm -f "$_file"
        return 0
    fi
    [ -f "$_file" ] || return 0
    local _others="$(/usr/bin/awk -F'\t' -v input="$2" '$1 "" != input' "$_file")"
    if [ -z "$_others" ]; then
        /bin/rm -f "$_file"
        return 0
    fi
    printf '%s\n' "$_others" | ui_store "$(ui_cache "$1" chosen.tsv)"
}

# update_inputs_given <uuid> <name>  ->  "<input>=<path>", one per line, for each input of the image
# a file was chosen for, while the tools are ticked: what Update passes. A file chosen for an
# input the image no longer has is not passed.
update_inputs_given() {
    case "$(update_choices "$1" "$2")" in
        [01]" 1 "[01]) ;;
        *) return 0 ;;
    esac
    local _input _path
    # Unquoted on purpose: input names are letters, digits and "_" (agentvm_status_input_rows).
    for _input in $(update_input_rows "$1" "$2" | /usr/bin/cut -f1); do
        _path="$(update_chosen "$1" "$_input")"
        [ -n "$_path" ] && printf '%s=%s\n' "$_input" "$_path"
    done
    return 0
}

# update_run <uuid> <name> <function>  ->  what that function prints, given the image's name, the
# parts ticked and the input files given: agentvm_image_update_args for the command shown, and
# agentvm_job_image_update for Update, so the two cannot differ.
update_run() {
    local _uuid="$1" _name="$2" _function="$3"
    local _choices="$(update_choices "$_uuid" "$_name")"
    local _given="$(update_inputs_given "$_uuid" "$_name")"
    local _line
    set --
    while IFS= read -r _line; do
        [ -n "$_line" ] && set -- "$@" "$_line"
    done <<EOF
$_given
EOF
    # Unquoted on purpose: three words, each 0 or 1.
    "$_function" "$_name" $_choices "$@"
}

# update_slot_input <uuid> <slot>  ->  the input whose Choose... button that recipe slot showed at
# the last painting, or nothing.
update_slot_input() {
    local _input="$(ui_get inputs "$1" | /usr/bin/awk -v n="$2" '{ print $n }')"
    case "$_input" in
        ''|-|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_]*) return 0 ;;
    esac
    printf '%s\n' "$_input"
}

# update_input_problem <uuid> <name>  ->  why a file chosen cannot be given to agent-vm now, or
# nothing: it is no longer a file that can be read.
update_input_problem() {
    local _given="$(update_inputs_given "$1" "$2")"
    [ -n "$_given" ] || return 0
    local _line _path
    while IFS= read -r _line; do
        _path="${_line#*=}"
        if [ ! -f "$_path" ] || [ ! -r "$_path" ]; then
            printf 'The file chosen for %s cannot be read any more: %s\n' "${_line%%=*}" "$_path"
            return 0
        fi
    done <<EOF
$_given
EOF
    # A recipe run again reads its other inputs from where they were (agent-vm fails the job,
    # after the image has booted, when one is gone): each must still be there. A second input of a
    # recipe has no button, so its file is given in Terminal.
    # Input names are letters, digits and "_", so a list of them on one line is safe for awk -v.
    local _names="$(printf '%s\n' "$_given" | /usr/bin/sed 's/=.*//' | /usr/bin/tr '\n' ' ')"
    local _places="$(update_input_rows "$1" "$2" | /usr/bin/awk -F'\t' -v names=" $_names" 'index(names, " " $1 " ") > 0 { print $5 }' | /usr/bin/sort -u)"
    local _input _recipe _was _where _at
    while IFS="$ui_tab" read -r _input _recipe _was _where _at; do
        [ -n "$_input" ] || continue
        printf '%s\n' "$_places" | /usr/bin/grep -qxF -- "$_at"
        [ $? -eq 0 ] || continue
        [ -n "$(update_chosen "$1" "$_input")" ] && continue
        if [ "$_where" = "-" ] || [ ! -f "$_where" ] || [ ! -r "$_where" ]; then
            printf 'The recipe %s runs again with its other files too, and the one for %s (%s) is not where it was. Give all of its files in Terminal: agent-vm image update %s --tools, with --input <name>=<path> for each.\n' \
                "$_recipe" "$_input" "$_was" "$2"
            return 0
        fi
    done <<EOF
$(update_input_rows "$1" "$2")
EOF
    return 0
}

# update_blocker <uuid> <name>  ->  why the image cannot be updated now, or nothing: agent-vm
# cannot be used or read, the image is gone or not ready, a job holds it, another agent-vm
# command is changing it, or a file chosen for an input cannot be read.
update_blocker() {
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
    local _state="$(printf '%s\n' "$_row" | /usr/bin/cut -f2)"
    local _job="$(main_job "$1" image "$2")"
    if [ -n "$_job" ]; then
        printf 'A job holds this image now (%s). It can be updated when the job ends.\n' "$(main_job_text "$_job")"
        return 0
    fi
    if [ "$_state" != "ready" ]; then
        printf 'Only a ready image can be updated, and this one is not: %s\n' \
            "$(main_image_state_text "$_state" "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)" "" "$(printf '%s\n' "$_row" | /usr/bin/cut -f12)")"
        return 0
    fi
    if main_image_busy "$1" "$2"; then
        printf 'Another agent-vm command is changing this image now. It can be updated when that ends.\n'
        return 0
    fi
    update_input_problem "$1" "$2"
}

# update_warning <uuid> <name>  ->  what may make an update fail at once, or nothing: the image is
# a macOS one and no place for a macOS virtual machine is free (an update boots the image, and
# agent-vm waits for no place). A Linux image needs none.
update_warning() {
    update_linux "$1" "$2" && return 0
    main_macos_vms "$1" | /usr/bin/awk -F'\t' '$1 >= $2 {
        printf "No virtual machine slot is free now (%s of %s macOS virtual machines running), and an update needs one: it fails at once until a macOS box or build stops.\n", $1, $2 }'
}

# update_state_text <uuid> <name>  ->  the line under the title: what the image runs (a macOS
# image its version and build, a Linux image its system in agent-vm's words), and when it was last
# updated.
update_state_text() {
    local _macos="$(update_field "$1" images "$2" 4)"
    local _build="$(update_field "$1" images "$2" 5)"
    local _text="macOS $_macos"
    [ "$_build" != "-" ] && _text="$_text ($_build)"
    # An image whose record lacks its version.
    [ "$_macos" = "-" ] && _text="Its macOS version is not known"
    if update_linux "$1" "$2"; then
        _text="$(update_field "$1" images "$2" 13)"
        [ "$_text" = "-" ] && _text="Its system is not known"
    fi
    local _updated="$(ui_date_text "$(update_field "$1" updates "$2" 3)")"
    if [ -n "$_updated" ]; then
        printf '%s. Last updated on %s.\n' "$_text" "$_updated"
    else
        printf '%s. Not updated since it was built.\n' "$_text"
    fi
}

# update_system_text <uuid> <name>  ->  what the system's part of an update does: for a macOS image
# what is known about a newer macOS for it; for a Linux image that its distribution's package
# updates are installed, which nobody can be asked about beforehand, and when they were last
# looked for.
update_system_text() {
    if update_linux "$1" "$2"; then
        local _short="$(update_field "$1" images "$2" 14)"
        local _of=""
        [ "$_short" != "-" ] && _of=" of $_short"
        local _looked="$(ui_date_text "$(update_field "$1" updates "$2" 4)")"
        printf 'Installs the package updates%s, which takes seconds to minutes. When they bring a new kernel, the image is started once more to check it before the update is kept.%s\n' \
            "$_of" "${_looked:+ Its packages were last looked at on $_looked.}"
        return 0
    fi
    local _version="$(update_field "$1" updates "$2" 6)"
    if [ "$_version" != "-" ]; then
        local _learned="$(ui_date_text "$(update_field "$1" updates "$2" 8)")"
        printf 'macOS %s (%s) is available%s. Installing it takes about 15 minutes, and about 15 GB of disk that the image then no longer shares with its older boxes. Newer Command Line Tools are installed with it.\n' \
            "$_version" "$(update_field "$1" updates "$2" 7)" "${_learned:+, as Apple said on $_learned}"
        return 0
    fi
    local _newest="$(update_newest "$1" 1)"
    local _major="$(update_field "$1" images "$2" 4)"
    _major="${_major%%.*}"
    # An image whose record lacks its version cannot be compared with the newest.
    local _within="macOS $_major"
    [ "$_major" = "-" ] && _within="the image's major version"
    if [ "$_newest" = "-" ]; then
        printf "Apple has not been asked which macOS is the newest: Check Now asks. The update asks too, and installs what Apple offers within %s.\n" "$_within"
        return 0
    fi
    local _asked="$(ui_date_text "$(update_newest "$1" 3)")"
    if [ "$_major" != "-" ] && [ "${_newest%%.*}" != "$_major" ]; then
        printf 'The newest macOS is %s%s, a new major version, which an update does not install: the image is built again for that. The update still asks Apple for what it offers within macOS %s.\n' \
            "$_newest" "${_asked:+ (as of $_asked)}" "$_major"
        return 0
    fi
    printf 'No newer macOS is known for this image: the newest is %s (%s)%s. The update asks Apple again, and installs what is offered.\n' \
        "$_newest" "$(update_newest "$1" 2)" "${_asked:+, as of $_asked}"
}

# update_tools_when <uuid> <name>  ->  when the recipes' update steps last ran.
update_tools_when() {
    local _ran="$(ui_date_text "$(update_field "$1" updates "$2" 5)")"
    if [ -n "$_ran" ]; then
        printf 'Last run on %s.\n' "$_ran"
    else
        printf 'Not run since the image was built.\n'
    fi
}

# update_tools_text <uuid> <name>  ->  what a tools update runs in the image, and what the second
# step adds: the list, and a newer file for an input of one of the recipes.
update_tools_text() {
    local _recipes="$(update_field "$1" updates "$2" 9)"
    if [ "$_recipes" = "-" ]; then
        printf 'This image keeps no recipes, so it has no tools an update can refresh.\n'
        return 0
    fi
    # The inputs the second step has a button for: the first of each recipe in a slot.
    local _inputs="$(update_input_rows "$1" "$2" | /usr/bin/awk -F'\t' -v slots="$UPDATE_SLOTS" '$5 + 0 <= slots + 0 && !seen[$5]++ { print $1 }')"
    local _given="$(update_inputs_given "$1" "$2" | /usr/bin/sed 's/=.*//')"
    local _lists="Ticking it adds a step that lists them"
    [ "$(update_choices "$1" "$2" | /usr/bin/cut -d' ' -f2)" = "1" ] && _lists="Continue lists them"
    local _next="$_lists."
    [ -n "$_inputs" ] && _next="$_lists, and takes a newer file for $(ui_lines_text "$_inputs")."
    if [ -n "$_given" ]; then
        _next="$_lists, with the new file for $(ui_lines_text "$_given")."
        [ "$(printf '%s\n' "$_given" | /usr/bin/awk 'END { print NR }')" -gt 1 ] \
            && _next="$_lists, with the new files for $(ui_lines_text "$_given")."
    fi
    printf "Runs the update steps of the recipes this image keeps (%s), then every recipe's checks. %s %s\n" \
        "$(printf '%s' "$_recipes" | /usr/bin/sed 's/,/, /g')" "$(update_tools_when "$1" "$2")" "$_next"
}

# update_recipes_text <uuid> <name>  ->  the second step's line above the recipes: what the tools
# update does with them and when it last ran, the recipes past the slots, and what running a
# recipe again takes. Which kept recipes agent-vm would replace by newer ones of its own is not
# known beforehand: the job's log names them.
update_recipes_text() {
    printf "The tools update runs the update steps of these recipes, in this order, then every recipe's checks. A recipe that came with agent-vm is first replaced by the installed version, when that is newer. %s\n" \
        "$(update_tools_when "$1" "$2")"
    local _count="$(update_recipe_rows "$1" "$2" | /usr/bin/awk 'END { print NR }')"
    if [ "$_count" -gt "$UPDATE_SLOTS" ]; then
        printf 'The image keeps %s recipes, and the last %s are not listed: a newer file for one of them is given in Terminal.\n' \
            "$_count" "$((_count - UPDATE_SLOTS))"
    fi
    [ -n "$(update_inputs_given "$1" "$2")" ] && printf 'Running a recipe again needs about 10 GB free, as a build does.\n'
    return 0
}

# update_recipe_text <uuid> <name> <place> <description> <inputs>  ->  a recipe slot's text: the
# recipe's description, then a line for each input it was built with: the file, and the button
# that gives it a newer one, or the file chosen, which the recipe runs again with. The slot's
# button is for its first input (update_paint_recipes), so a second one's file is given in
# Terminal; an input a later recipe of the image takes the new file for says so.
update_recipe_text() {
    [ "$4" != "-" ] && printf '%s\n' "$4"
    [ "$5" != "-" ] || return 0
    local _names="$(printf '%s\n' "$5" | /usr/bin/tr ',' '\n')"
    local _rows="$(update_input_rows "$1" "$2")"
    local _first=1 _input _recipe _was _where _at _built _chosen
    while IFS="$ui_tab" read -r _input _recipe _was _where _at; do
        [ -n "$_input" ] || continue
        wizard_listed "$_input" "$_names" || continue
        if [ "$_at" != "$3" ]; then
            printf 'A newer file for %s goes to the %s recipe listed after this one.\n' "$_input" "$_recipe"
            continue
        fi
        _built="$_was"
        [ "$_was" = "-" ] && _built="a file not on record"
        if [ "$_first" -eq 0 ]; then
            printf 'Built with %s for %s. A newer one is given in Terminal: agent-vm image update %s --tools --input %s=<path>.\n' \
                "$_built" "$_input" "$2" "$_input"
            continue
        fi
        _first=0
        _chosen="$(update_chosen "$1" "$_input")"
        if [ -n "$_chosen" ]; then
            printf 'Runs again with %s in place of %s: what it installs is installed from the new file, instead of by its update steps.\n' \
                "${_chosen##*/}" "$_built"
        else
            printf 'Built with %s. Choose %s... gives it a newer file, and the recipe then runs again with it.\n' "$_built" "$_input"
        fi
    done <<EOF
$_rows
EOF
    return 0
}

# update_guest_text <uuid> <name>  ->  what replacing the guest daemon would do, and that it is
# done first when another part is ticked too.
update_guest_text() {
    local _guest="$(update_field "$1" images "$2" 9)"
    local _mine="$(main_agentvm_line "$1" 2)"
    if ! update_guest_differs "$1" "$2"; then
        printf 'The image has agent-vm-guest %s, as this agent-vm does. It is replaced only if the two still differ.\n' "$_guest"
        return 0
    fi
    local _missing="$(update_field "$1" updates "$2" 11)"
    local _adds=""
    [ "$_missing" != "-" ] && _adds=", which adds $(printf '%s' "$_missing" | /usr/bin/sed 's/,/, /g')"
    local _theirs="The image's agent-vm-guest $_guest"
    [ "$_guest" = "-" ] && _theirs="The image's agent-vm-guest, whose version is not on record,"
    # macOS ties a Full Disk Access grant to the daemon it was made for; a Linux image has none.
    local _access=" Its Full Disk Access may have to be granted again afterwards; the image's pane says so then."
    update_linux "$1" "$2" && _access=""
    printf "%s is replaced by this agent-vm's, %s%s.%s With another part ticked too, the daemon is replaced first, and stays even if that part fails.\n" \
        "$_theirs" "$_mine" "$_adds" "$_access"
}

# update_after_text <uuid> <name>  ->  what an update means for what was made from the image, and
# what a failure leaves, one line each. With the guest daemon ticked beside another part, a
# failure leaves the daemon's update, which agent-vm puts in place before the rest. Whether the
# daemon differs is agent-vm's to say at the update (it compares digests, and the window knows
# versions), so the line holds either way.
update_after_text() {
    local _boxes="$(main_rows "$1" boxes | /usr/bin/awk -F'\t' -v name="$2" '$3 "" == name && $13 != "true" { print $1 }')"
    [ -n "$_boxes" ] && printf 'Boxes made from it (%s) keep what they have until they are recreated.\n' "$(ui_lines_text "$_boxes")"
    local _derived="$(main_rows "$1" images | /usr/bin/awk -F'\t' -v name="$2" '$6 "" == name { print $1 }')"
    [ -n "$_derived" ] && printf 'Images built from it (%s) are not updated with it: each is updated by itself.\n' "$(ui_lines_text "$_derived")"
    printf 'The image can be used meanwhile: a box made during the update gets the image as it was.\n'
    case "$(update_choices "$1" "$2")" in
        "1 "[01]" 1"|[01]" 1 1")
            printf 'An update that fails or is stopped leaves the image as it is now, except for its guest daemon once that is replaced.\n' ;;
        *)
            printf 'An update that fails or is stopped leaves the image as it is now.\n' ;;
    esac
}

# update_command_text <uuid> <name>  ->  the command Update runs, as it would be typed in Terminal.
update_command_text() {
    local _flags="$(update_flags "$1" "$2")"
    if [ -z "$_flags" ]; then
        printf 'Tick what to update.\n'
        return 0
    fi
    printf 'agent-vm image update %s\n' "$(update_run "$1" "$2" agentvm_image_update_args | agentvm_args_text)"
}

# update_paint_recipes <uuid> <name>  ->  the second step's slots: the recipes the image keeps, one
# per slot in the order they run, the slots past them hidden. A slot's Choose... button is for the
# first input its recipe takes a new file for, and Clear is shown while a file is chosen for it;
# which input each slot's buttons are for is the pasteboard value "inputs", for their handlers.
update_paint_recipes() {
    local _rows="$(update_recipe_rows "$1" "$2")"
    local _inputs="$(update_input_rows "$1" "$2")"
    local _slots="" _slot=0 _row _place _recipe _text _names _input _chosen
    while [ "$_slot" -lt "$UPDATE_SLOTS" ]; do
        _slot=$((_slot + 1))
        _row="$(printf '%s\n' "$_rows" | /usr/bin/sed -n "${_slot}p")"
        if [ -z "$_row" ]; then
            ui_show "$1" "$((UPDATE_SLOT_BASE + _slot))" 0
            _slots="${_slots:+$_slots }-"
            continue
        fi
        IFS="$ui_tab" read -r _place _recipe _text _names <<ROW
$_row
ROW
        _input="$(printf '%s\n' "$_inputs" | /usr/bin/awk -F'\t' -v at="$_place" '$5 "" == at { print $1; exit }')"
        "$dialog" "$1" "$((UPDATE_SLOT_NAME_BASE + _slot))" "$_recipe"
        "$dialog" "$1" "$((UPDATE_SLOT_TEXT_BASE + _slot))" "$(update_recipe_text "$1" "$2" "$_place" "$_text" "$_names")"
        if [ -n "$_input" ]; then
            "$dialog" "$1" "$((UPDATE_CHOOSE_BASE + _slot))" omc_set_property title "Choose $_input..."
            ui_show "$1" "$((UPDATE_CHOOSE_BASE + _slot))" 1
            _chosen=0
            [ -n "$(update_chosen "$1" "$_input")" ] && _chosen=1
            ui_show "$1" "$((UPDATE_CLEAR_BASE + _slot))" "$_chosen"
        else
            _input="-"
            ui_show "$1" "$((UPDATE_CHOOSE_BASE + _slot))" 0
            ui_show "$1" "$((UPDATE_CLEAR_BASE + _slot))" 0
        fi
        ui_show "$1" "$((UPDATE_SLOT_BASE + _slot))" 1
        _slots="${_slots:+$_slots }$_input"
    done
    ui_set inputs "$1" "$_slots"
}

# update_paint_step <uuid> <step> <tools>  ->  the panel of the step shown, and its buttons: Back
# on the second step; Continue on the first with the tools ticked (1), Update otherwise.
update_paint_step() {
    local _first=0 _second=0
    if [ "$2" = "2" ]; then
        _second=1
    else
        _first=1
    fi
    ui_show "$1" "$UPDATE_PARTS_ID" "$_first"
    ui_show "$1" "$UPDATE_RECIPES_ID" "$_second"
    ui_enable "$1" "$UPDATE_BACK_ID" "$_second"
    if [ "$_first" -eq 1 ] && [ "$3" = "1" ]; then
        ui_show "$1" "$UPDATE_START_ID" 0
        ui_show "$1" "$UPDATE_NEXT_ID" 1
    else
        ui_show "$1" "$UPDATE_NEXT_ID" 0
        ui_show "$1" "$UPDATE_START_ID" 1
    fi
}

# update_paint <uuid> [toggles]  ->  the window from its cache. "toggles" also sets the three
# checkboxes from the choices kept (on opening, and when Check Now ticked macOS): a repaint does
# not, so that it never undoes a click made while it ran.
update_paint() {
    local _uuid="$1"
    local _name="$(update_image "$_uuid")"
    [ -n "$_name" ] || return 0
    "$dialog" "$_uuid" "$UPDATE_TITLE_ID" "Update image $_name"
    local _blocker="$(update_blocker "$_uuid" "$_name")"
    if [ -z "$(main_row "$_uuid" images "$_name")" ]; then
        # Nothing is known of the image: only why, on the first step.
        update_paint_step "$_uuid" 1 0
        "$dialog" "$_uuid" "$UPDATE_NOTE_ID" "$_blocker"
        ui_enable "$_uuid" "$UPDATE_START_ID" 0
        return 0
    fi
    local _tools="$(update_choices "$_uuid" "$_name" | /usr/bin/cut -d' ' -f2)"
    "$dialog" "$_uuid" "$UPDATE_STATE_ID" "$(update_state_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_SYSTEM_TEXT_ID" "$(update_system_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_TOOLS_TEXT_ID" "$(update_tools_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_GUEST_TEXT_ID" "$(update_guest_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_AFTER_ID" "$(update_after_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_COMMAND_ID" "$(update_command_text "$_uuid" "$_name")"
    if [ "$(update_field "$_uuid" updates "$_name" 9)" = "-" ]; then
        ui_enable "$_uuid" "$UPDATE_TOOLS_ID" 0
    else
        ui_enable "$_uuid" "$UPDATE_TOOLS_ID" 1
    fi
    # The second step's slots are filled before it is shown, and only for it. The step is read as
    # late as can be, and again after the slots: a Back clicked while a repaint (an activation's)
    # filled them has painted the first step already, and must not be undone by this one.
    local _step="$(update_step "$_uuid" "$_name")"
    if [ "$_step" = "2" ]; then
        "$dialog" "$_uuid" "$UPDATE_RECIPES_TEXT_ID" "$(update_recipes_text "$_uuid" "$_name")"
        update_paint_recipes "$_uuid" "$_name"
        _step="$(update_step "$_uuid" "$_name")"
    fi
    update_paint_step "$_uuid" "$_step" "$_tools"
    if [ "${2:-}" = "toggles" ]; then
        local _choices="$(update_choices "$_uuid" "$_name")"
        local _id _on
        for _id in "$UPDATE_SYSTEM_ID" "$UPDATE_TOOLS_ID" "$UPDATE_GUEST_ID"; do
            _on="false"
            [ "${_choices%% *}" = "1" ] && _on="true"
            "$dialog" "$_uuid" "$_id" "$_on"
            _choices="${_choices#* }"
        done
    fi
    # Check Now asks Apple, which has nothing to say of a Linux image: the button, last in its
    # row, is not shown for one.
    local _apple=1
    update_linux "$_uuid" "$_name" && _apple=0
    ui_show "$_uuid" "$UPDATE_CHECK_ID" "$_apple"
    # Why Apple could not be asked, when Check Now failed; else what stands in the way, or may.
    local _note="$_blocker"
    local _lookup="$(update_newest "$_uuid" 4)"
    [ -z "$_note" ] && [ "$_apple" -eq 1 ] && [ "$_lookup" != "-" ] && _note="Apple could not be asked for the newest macOS: $_lookup"
    [ -z "$_note" ] && _note="$(update_warning "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_NOTE_ID" "$_note"
    if [ -z "$_blocker" ] && [ -n "$(update_flags "$_uuid" "$_name")" ]; then
        ui_enable "$_uuid" "$UPDATE_START_ID" 1
    else
        ui_enable "$_uuid" "$UPDATE_START_ID" 0
    fi
}

# update_refresh <uuid> [full|check]  ->  reads, then paints; a first reading that succeeds ticks
# what needs updating (update_first_choices). The window closed while agent-vm was being read:
# its close handler removed the cache folder, and the read made it again.
update_refresh() {
    update_read "$1" "${2:-}"
    if update_first_choices "$1"; then
        update_paint "$1" toggles
    else
        update_paint "$1"
    fi
    [ -n "$(update_image "$1")" ] || ui_cache_clear "$1"
    return 0
}
