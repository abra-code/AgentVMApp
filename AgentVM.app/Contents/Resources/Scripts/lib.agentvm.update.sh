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
# THE THREE PARTS are agent-vm's: macOS (the update Apple offers within the image's major
# version, and newer Command Line Tools), the tools (the update steps of the recipes the image
# keeps), and the guest daemon (this agent-vm's agent-vm-guest, when the image has another). A
# part is ticked at opening when something is known to need doing: a newer macOS is known, or
# Apple was never asked; the image keeps recipes; its guest daemon is another version or lacks a
# feature. The ticks are the window's pasteboard value "choices" ("1 0 1": macOS, tools, guest),
# kept by the handlers, since a handler's view of the checkboxes is a snapshot.
#
# THE WINDOW STARTS ONE JOB AND CLOSES. Update starts `image update <name>` with the parts ticked
# as an agent-vm job, opens that job's progress window (lib.agentvm.progress.sh), has the main
# window read the jobs again, and closes. The update goes on whether or not the app is open.
#
# WHAT IT READS: `status`, into its own cache, on opening, on activation and before Update; and
# `status --check-updates` for Check Now, which asks Apple for the newest macOS and installs
# nothing. It has no poll loop.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_UPDATE_LIB:-}" ] && return 0
__AGENTVM_APP_UPDATE_LIB=1

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.main.sh"

UPDATE_TITLE_ID=801
UPDATE_STATE_ID=802
UPDATE_MACOS_ID=811
UPDATE_MACOS_TEXT_ID=812
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
    local _macos=0 _tools=0 _guest=0
    [ "$(update_field "$1" updates "$2" 6)" != "-" ] && _macos=1
    [ "$(update_newest "$1" 1)" = "-" ] && _macos=1
    [ "$(update_field "$1" updates "$2" 9)" != "-" ] && _tools=1
    update_guest_differs "$1" "$2" && _guest=1
    printf '%s %s %s\n' "$_macos" "$_tools" "$_guest"
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

# update_flags <uuid> <name>  ->  the options of the parts ticked ("--macos --guest"), or nothing.
update_flags() {
    # Unquoted on purpose: three words, each 0 or 1.
    agentvm_image_update_flags $(update_choices "$1" "$2")
}

# update_blocker <uuid> <name>  ->  why the image cannot be updated now, or nothing: agent-vm
# cannot be used or read, the image is gone or not ready, a job holds it, or another agent-vm
# command is changing it.
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
            "$(main_image_state_text "$_state" "$(printf '%s\n' "$_row" | /usr/bin/cut -f3)")"
        return 0
    fi
    if main_image_busy "$1" "$2"; then
        printf 'Another agent-vm command is changing this image now. It can be updated when that ends.\n'
    fi
    return 0
}

# update_warning <uuid>  ->  what may make an update fail at once, or nothing: no virtual machine
# slot is free (an update boots the image, and agent-vm waits for no slot).
update_warning() {
    main_rows "$1" vm | /usr/bin/awk -F'\t' 'NR == 1 && $1 != "-" && $2 != "-" && $1 + 0 >= $2 + 0 {
        printf "No virtual machine slot is free now (%s of %s running), and an update needs one: it fails at once until a box or a build stops.\n", $1, $2 }'
}

# update_state_text <uuid> <name>  ->  the line under the title: the image's macOS, and when it
# was last updated.
update_state_text() {
    local _macos="$(update_field "$1" images "$2" 4)"
    local _build="$(update_field "$1" images "$2" 5)"
    local _text="macOS $_macos"
    [ "$_build" != "-" ] && _text="$_text ($_build)"
    # An image whose record lacks its version.
    [ "$_macos" = "-" ] && _text="Its macOS version is not known"
    local _updated="$(ui_date_text "$(update_field "$1" updates "$2" 3)")"
    if [ -n "$_updated" ]; then
        printf '%s. Last updated on %s.\n' "$_text" "$_updated"
    else
        printf '%s. Not updated since it was built.\n' "$_text"
    fi
}

# update_macos_text <uuid> <name>  ->  what is known about a newer macOS for the image.
update_macos_text() {
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

# update_tools_text <uuid> <name>  ->  what a tools update runs in the image.
update_tools_text() {
    local _recipes="$(update_field "$1" updates "$2" 9)"
    if [ "$_recipes" = "-" ]; then
        printf 'This image keeps no recipes, so it has no tools an update can refresh.\n'
        return 0
    fi
    local _ran="$(ui_date_text "$(update_field "$1" updates "$2" 5)")"
    local _when="Not run since the image was built."
    [ -n "$_ran" ] && _when="Last run on $_ran."
    printf "Runs the update steps of the recipes this image keeps (%s), then every recipe's checks. %s\n" \
        "$(printf '%s' "$_recipes" | /usr/bin/sed 's/,/, /g')" "$_when"
}

# update_guest_text <uuid> <name>  ->  what replacing the guest daemon would do.
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
    printf "%s is replaced by this agent-vm's, %s%s. Its Full Disk Access may have to be granted again afterwards; the image's pane says so then.\n" \
        "$_theirs" "$_mine" "$_adds"
}

# update_after_text <uuid> <name>  ->  what an update means for what was made from the image, and
# what a failure leaves, one line each.
update_after_text() {
    local _boxes="$(main_rows "$1" boxes | /usr/bin/awk -F'\t' -v name="$2" '$3 == name && $13 != "true" { print $1 }')"
    [ -n "$_boxes" ] && printf 'Boxes made from it (%s) keep what they have until they are recreated.\n' "$(ui_lines_text "$_boxes")"
    local _derived="$(main_rows "$1" images | /usr/bin/awk -F'\t' -v name="$2" '$6 == name { print $1 }')"
    [ -n "$_derived" ] && printf 'Images built from it (%s) are not updated with it: each is updated by itself.\n' "$(ui_lines_text "$_derived")"
    printf 'The image can be used meanwhile: a box made during the update gets the image as it was.\n'
    printf 'An update that fails or is stopped leaves the image as it is now.\n'
}

# update_command_text <uuid> <name>  ->  the command Update runs, as it would be typed in Terminal.
update_command_text() {
    local _flags="$(update_flags "$1" "$2")"
    if [ -z "$_flags" ]; then
        printf 'Tick what to update.\n'
        return 0
    fi
    printf 'agent-vm image update %s %s\n' "$2" "$_flags"
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
        # Nothing is known of the image: only why.
        "$dialog" "$_uuid" "$UPDATE_NOTE_ID" "$_blocker"
        ui_enable "$_uuid" "$UPDATE_START_ID" 0
        return 0
    fi
    "$dialog" "$_uuid" "$UPDATE_STATE_ID" "$(update_state_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_MACOS_TEXT_ID" "$(update_macos_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_TOOLS_TEXT_ID" "$(update_tools_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_GUEST_TEXT_ID" "$(update_guest_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_AFTER_ID" "$(update_after_text "$_uuid" "$_name")"
    "$dialog" "$_uuid" "$UPDATE_COMMAND_ID" "$(update_command_text "$_uuid" "$_name")"
    if [ "$(update_field "$_uuid" updates "$_name" 9)" = "-" ]; then
        ui_enable "$_uuid" "$UPDATE_TOOLS_ID" 0
    else
        ui_enable "$_uuid" "$UPDATE_TOOLS_ID" 1
    fi
    if [ "${2:-}" = "toggles" ]; then
        local _choices="$(update_choices "$_uuid" "$_name")"
        local _id _on
        for _id in "$UPDATE_MACOS_ID" "$UPDATE_TOOLS_ID" "$UPDATE_GUEST_ID"; do
            _on="false"
            [ "${_choices%% *}" = "1" ] && _on="true"
            "$dialog" "$_uuid" "$_id" "$_on"
            _choices="${_choices#* }"
        done
    fi
    # Why Apple could not be asked, when Check Now failed; else what stands in the way, or may.
    local _note="$_blocker"
    local _lookup="$(update_newest "$_uuid" 4)"
    [ -z "$_note" ] && [ "$_lookup" != "-" ] && _note="Apple could not be asked for the newest macOS: $_lookup"
    [ -z "$_note" ] && _note="$(update_warning "$_uuid")"
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

# update_tell_main <job id>  ->  the open main window, if there is one, watches the job and reads
# the lists again, so its card and pane follow the update from now and not from its next poll.
update_tell_main() {
    local _main="$(ui_item_window main window)"
    [ -n "$_main" ] || return 0
    printf '%s\n' "$1" >> "$(ui_cache "$_main" jobs-watched)"
    main_refresh "$_main" status
}
