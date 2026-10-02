#!/bin/sh
# lib.agentvm.sh
#
# The only file in AgentVM.app that runs agent-vm. Every window reads images, boxes and their
# state through the functions here, so there is one place that knows which agent-vm is in use,
# how to read its answers, and how its failures reach the user.
#
# WHICH agent-vm. Three candidates, the first one set wins:
#   - AGENTVM_APP_AGENT_VM in the environment: the test seam, pointed at
#     Tests/helpers/fake_agent_vm.sh;
#   - "developerAgentVM" in the app's settings.json: a developer override, typically
#     ~/Development/agent-vm/.build/signed/release/agent-vm, so the app can follow an agent-vm
#     working tree while the two change together;
#   - the installed ~/.local/bin/agent-vm. The app carries no agent-vm of its own. agent-vm's
#     installer puts each version in a folder of its own (~/.local/share/agent-vm/versions/<v>/,
#     with agent-vm-guest, the network packs and the image recipes beside it) and points the
#     link in ~/.local/bin at the newest. Terminal (agent-vm, avm), Cadabra and this app all run
#     that one.
# Nothing else: not $PATH, which a Finder-launched app does not share with Terminal.
# "agentVMHome" in settings.json, when set, becomes AGENT_VM_HOME for every run: agent-vm's
# store root. It applies to whichever binary runs, so switching binaries never switches stores.
#
# READING ITS ANSWERS. Only --json output is read, with /usr/bin/jq, into tab-separated rows in
# which no field is empty (an absent value is "-"), because `read` with a tab IFS collapses
# empty fields and shifts every column after them. agent-vm's human text changes freely; its
# JSON is a contract with this library. A failed call leaves agent-vm's own message (written for
# people, naming the fix) for agentvm_last_error.
#
# THE VERSION RULE. AGENTVM_MIN_VERSION is the agent-vm version the app is built and tested
# against, always the newest: there is one development stream, so an older agent-vm is refused
# rather than guessed at. update-agentvmapp.sh rewrites the line from the agent-vm working tree
# at every build, and the tests compare it with the fixtures' version.
#
# POSIX sh (bash 3.2 in POSIX mode) only. Validate with "sh -n".
[ -n "${__AGENTVM_APP_LIB:-}" ] && return 0
__AGENTVM_APP_LIB=1

AGENTVM_MIN_VERSION="0.5.13"

# The app's own state, and where agent-vm's installer puts the link to the newest agent-vm.
agentvm_support_dir="$HOME/Library/Application Support/AgentVM"
agentvm_settings="$agentvm_support_dir/settings.json"
agentvm_installed="$HOME/.local/bin/agent-vm"

# Where agentvm_json leaves agent-vm's stderr for agentvm_last_error. Named after the handler's
# pid: $$ is the handler's own pid inside every subshell of it too, so a call made in $( ) - the
# usual way to call it - still leaves the message where the caller can find it afterwards.
agentvm_err_file="${TMPDIR:-/tmp}/AgentVM.agentvm.$$.stderr"

# The codes agentvm_available returns when agent-vm cannot be used, besides 1 (installing would
# not help: a broken developer override or test seam).
agentvm_not_installed=2
agentvm_too_old=3

# The jq definitions every row filter uses. cell: null becomes "-", tabs and line breaks inside
# a value become spaces, and an empty string becomes "-", so every row has all its fields.
# false stays "false": `// "-"` would replace it too.
agentvm_jq_defs='def cell: if . == null then "-" else tostring | gsub("[\t\n\r]"; " ") | if . == "" then "-" else . end end;
def row: map(cell) | join("\t");'

# agentvm_setting <key>  ->  that string from settings.json, or nothing.
# Reads only: a missing or malformed file, or a value that is not a string, is nothing.
agentvm_setting() {
    [ -f "$agentvm_settings" ] || return 0
    /usr/bin/jq -r --arg key "$1" '.[$key] | strings' "$agentvm_settings" 2>/dev/null
}

# agentvm_display_path <path>  ->  the path with the home folder written as "~", for the window.
agentvm_display_path() {
    case "$1" in
        "$HOME"/*) printf '~/%s\n' "${1#"$HOME"/}" ;;
        *)         printf '%s\n' "$1" ;;
    esac
}

# agentvm_origin  ->  test, developer or installed: where agentvm_bin's answer comes from.
# The window names it next to the version, so a forgotten override is visible.
agentvm_origin() {
    if [ -n "${AGENTVM_APP_AGENT_VM:-}" ]; then
        echo "test"
        return 0
    fi
    local _override="$(agentvm_setting developerAgentVM)"
    if [ -n "$_override" ]; then
        echo "developer"
        return 0
    fi
    echo "installed"
}

# agentvm_bin  ->  the agent-vm this library runs (see the header for the order).
agentvm_bin() {
    if [ -n "${AGENTVM_APP_AGENT_VM:-}" ]; then
        printf '%s\n' "$AGENTVM_APP_AGENT_VM"
        return 0
    fi
    local _override="$(agentvm_setting developerAgentVM)"
    if [ -n "$_override" ]; then
        printf '%s\n' "$_override"
        return 0
    fi
    printf '%s\n' "$agentvm_installed"
}

# agentvm_run <args...>  ->  agent-vm's output and status, run with the app's store setting.
agentvm_run() {
    local _bin="$(agentvm_bin)"
    local _home="$(agentvm_setting agentVMHome)"
    if [ -n "$_home" ]; then
        AGENT_VM_HOME="$_home" "$_bin" "$@"
        return $?
    fi
    "$_bin" "$@"
}

# agentvm_json <args...>  ->  agent-vm's JSON on stdout, and agent-vm's status.
# --json goes last, after the caller's arguments; callers pass names that agentvm_valid_name
# accepted, so nothing after them can be read as an option or a program's argv.
# stderr is kept apart for agentvm_last_error and removed when the call succeeds.
agentvm_json() {
    /bin/rm -f "$agentvm_err_file"
    agentvm_run "$@" --json 2>"$agentvm_err_file"
    local _status=$?
    if [ "$_status" -eq 0 ]; then
        /bin/rm -f "$agentvm_err_file"
    fi
    return "$_status"
}

# agentvm_last_error [status]  ->  the message of the last failed call, for an alert.
# agent-vm writes "Error: <what failed and the fix>" to stderr, sometimes followed by more lines
# (a guest program's output, say). The message is everything from that line on, less the
# "Error: " prefix. Without such a line - a crash, say - it is every line that is not a progress
# event (a JSON line, from long commands). The message is forgotten once read.
agentvm_last_error() {
    local _message
    _message="$(/usr/bin/awk '
        found           { print; next }
        /^Error: /      { found = 1; sub(/^Error: /, ""); print; next }
        !/^\{/          { other = other $0 "\n" }
        END             { if (!found) printf "%s", other }' "$agentvm_err_file" 2>/dev/null)"
    /bin/rm -f "$agentvm_err_file"
    if [ -z "$_message" ]; then
        _message="agent-vm failed (status ${1:-unknown}) and gave no reason."
    fi
    printf '%s\n' "$_message"
}

# _agentvm_refuse <status> <message>  ->  leaves the message for agentvm_last_error, returns status.
# For arguments refused before agent-vm runs, so every failure is read the same way.
_agentvm_refuse() {
    printf 'Error: %s\n' "$2" > "$agentvm_err_file"
    return "$1"
}

# agentvm_valid_name <name>  ->  0 when agent-vm accepts it as an image or box name.
# agent-vm's own rule (ImageStore.isValidName): lower-case letters, digits, ".", "_" and "-",
# starting with a letter or digit, at most 63 characters. Checked here as well because a name
# is an argv element: one that starts with "-" would be read as an option.
# The letters are spelled out because a bracket RANGE follows the locale's collation order: in
# en_US.UTF-8, [a-z] also matches "B" through "Z".
agentvm_valid_name() {
    case "$1" in
        [abcdefghijklmnopqrstuvwxyz0123456789]*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        *[!abcdefghijklmnopqrstuvwxyz0123456789._-]*) return 1 ;;
    esac
    [ "${#1}" -le 63 ]
}

# _agentvm_need_name <image|box> <name>  ->  0, or 2 with the reason left for agentvm_last_error.
_agentvm_need_name() {
    agentvm_valid_name "$2" && return 0
    _agentvm_refuse 2 "\"$2\" is not a valid $1 name: agent-vm accepts lower-case letters, digits, \".\", \"_\" and \"-\", starting with a letter or digit, at most 63 characters."
}

# agentvm_version_at_least <have> <want>  ->  0 when have >= want, compared as dotted numbers.
# Anything that is not digits and dots is not at least anything.
agentvm_version_at_least() {
    case "$1" in ''|*[!0123456789.]*|.*|*.|*..*) return 1 ;; esac
    case "$2" in ''|*[!0123456789.]*|.*|*.|*..*) return 1 ;; esac
    local _have="$1." _want="$2."
    local _h _w
    while [ -n "$_have" ] || [ -n "$_want" ]; do
        _h="${_have%%.*}"
        _w="${_want%%.*}"
        _have="${_have#*.}"
        _want="${_want#*.}"
        [ -n "$_h" ] || _h=0
        [ -n "$_w" ] || _w=0
        if [ "$_h" -gt "$_w" ]; then
            return 0
        fi
        if [ "$_h" -lt "$_w" ]; then
            return 1
        fi
    done
    return 0
}

# agentvm_bin_reason <path> <origin>  ->  why that agent-vm cannot be run, or nothing.
# -f as well as -x, because -x is also true of a directory.
agentvm_bin_reason() {
    local _shown="$(agentvm_display_path "$1")"
    case "$2" in
        developer)
            case "$1" in
                /*) ;;
                *)  printf 'The developer agent-vm in Settings is "%s", which is not an absolute path. Fix it, or clear it to use the installed agent-vm.\n' "$1"
                    return 0 ;;
            esac
            if [ ! -f "$1" ] || [ ! -x "$1" ]; then
                printf 'The developer agent-vm in Settings is %s, which is not an executable file. Build agent-vm there, or clear the setting to use the installed agent-vm.\n' "$_shown"
            fi ;;
        test)
            if [ ! -f "$1" ] || [ ! -x "$1" ]; then
                printf 'AGENTVM_APP_AGENT_VM is %s, which is not an executable file.\n' "$1"
            fi ;;
        *)
            if [ ! -f "$1" ] || [ ! -x "$1" ]; then
                printf 'agent-vm is not installed: there is nothing at %s.\n' "$_shown"
            fi ;;
    esac
}

# agentvm_version_reason <path> <origin> <output of --version> <its status>
#   ->  why that agent-vm is unusable, or nothing.
agentvm_version_reason() {
    local _shown="$(agentvm_display_path "$1")"
    # One line: the reason goes into a row of the window, and a crashing binary can print several.
    local _output="$(printf '%s' "$3" | /usr/bin/tr '\n' ' ')"
    local _fix=""
    if [ "$2" = "developer" ]; then
        _fix=" Rebuild it, or clear the developer agent-vm in Settings to use the installed one."
    fi
    if [ "$4" != "0" ]; then
        printf '%s did not report its version (status %s: %s).%s\n' "$_shown" "$4" "${_output:-no output}" "$_fix"
        return 0
    fi
    case "$3" in
        ''|*[!0123456789.]*)
            printf '%s did not report a version: "%s".%s\n' "$_shown" "$_output" "$_fix"
            return 0 ;;
    esac
    agentvm_version_at_least "$3" "$AGENTVM_MIN_VERSION"
    local _new_enough=$?
    if [ "$_new_enough" -ne 0 ]; then
        printf 'AgentVM needs agent-vm %s or newer; the one at %s is %s.%s\n' "$AGENTVM_MIN_VERSION" "$_shown" "$3" "$_fix"
    fi
}

# agentvm_available  ->  0 with agent-vm's version on stdout when it can be used; otherwise one
# line saying why, meant for the window, and a status saying what would fix it:
#   agentvm_not_installed (2)  nothing at ~/.local/bin/agent-vm: the install flow fixes it;
#   agentvm_too_old (3)        the installed one is older than AGENTVM_MIN_VERSION, or does not
#                              run: installing the newest fixes it;
#   1                          a developer override or the test seam is broken: installing
#                              would not help, the setting has to change.
# Called before anything else runs agent-vm.
agentvm_available() {
    local _bin="$(agentvm_bin)"
    local _origin="$(agentvm_origin)"
    local _reason="$(agentvm_bin_reason "$_bin" "$_origin")"
    if [ -n "$_reason" ]; then
        printf '%s\n' "$_reason"
        [ "$_origin" = "installed" ] && return "$agentvm_not_installed"
        return 1
    fi
    local _version
    _version="$(agentvm_run --version 2>&1)"
    local _status=$?
    _reason="$(agentvm_version_reason "$_bin" "$_origin" "$_version" "$_status")"
    if [ -n "$_reason" ]; then
        printf '%s\n' "$_reason"
        [ "$_origin" = "installed" ] && return "$agentvm_too_old"
        return 1
    fi
    printf '%s\n' "$_version"
    return 0
}

# -- Reads ---------------------------------------------------------------------------------------
# Each runs agent-vm once and fails like agentvm_json: agent-vm's status, and its message waiting
# for agentvm_last_error. The *_rows filters read JSON on stdin, so a handler that needs several
# views of one answer (the boxes and the images of one `status`) runs agent-vm once, and the
# tests run the filters on the fixtures directly.

# agentvm_doctor  ->  one row per check: name, status (ok, info, warning, failure), detail.
agentvm_doctor() {
    local _json
    _json="$(agentvm_json doctor)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        return "$_status"
    fi
    printf '%s\n' "$_json" | agentvm_doctor_rows
}

# agentvm_doctor_rows  <  doctor JSON  ->  the rows agentvm_doctor documents.
agentvm_doctor_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .checks[] | [.name, .status, .detail] | row'
}

# agentvm_status  ->  `agent-vm status --json` as it is, for the *_rows filters below.
# It measures no disk and changes nothing (unlike `box list`, it deletes no stopped disposable
# box), so it is safe to poll; a box whose supervisor does not answer holds it up for about 7
# seconds (2 s for the socket, 5 s for the answer), so a button's handler never waits on it.
agentvm_status() {
    agentvm_json status
}

# agentvm_status_checked  ->  `agent-vm status --check-updates --json`: the same answer, after
# agent-vm asked Apple for the newest macOS (it needs the internet, and takes a few seconds) and
# kept what it learned in the store, so that this and every later `status` names the images that
# are behind. Nothing is installed. A lookup that failed is `newestMacOSError` in the answer, not
# a failure of the call.
agentvm_status_checked() {
    agentvm_json status --check-updates
}

# agentvm_status_box_rows  <  status JSON  ->  one row per box:
#    1 name        2 state (stopped, starting, running, stopping, unresponsive)   3 image
#    4 netMode (allowlist, off, open; a box made before network rules is open)
#    5 ruleCount   6 pid (the supervisor's)   7 ownerPid   8 project   9 projectReadOnly
#   10 activeExecs (programs running in it now)   11 startedAt   12 supervisorVersion
#   13 disposable (true or false)   14 statusError   15 cpus   16 memoryGB   17 path
#   18 needs (kinds, comma-joined: recreate, when its image is no longer what the box was made
#      from; agent-vm says nothing for a box made before it recorded what it compares)
#   19 macOSVersion   20 macOSBuild (what the box was made with)   21 createdAt
#   22 why it needs recreating: guest-update (the image's guest daemon was replaced),
#      image-updated (macOS or the tools in it were updated) or image-rebuilt (another image was
#      built under the name)
# The running fields (6-12) are "-" for a stopped box.
agentvm_status_box_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs$agentvm_jq_box_defs"' .boxes[] | box_cells | row'
}

# The 22 cells of a box, as agentvm_status_box_rows documents them: `status` gives each box's
# entry, and `box info` the same entry with its sizes.
agentvm_jq_box_defs='
def box_cells: [
    .box.name, .state, .box.image,
    (.box.network.mode // "open"), (.box.network.allow // [] | length),
    .pid, .ownerPid, .project, .projectReadOnly, .activeExecs, .startedAt, .supervisorVersion,
    (.box.disposable // false), .statusError,
    .box.cpuCount, (if .box.memoryBytes == null then null else .box.memoryBytes / 1073741824 | floor end),
    .path,
    (.needs // [] | map(.kind) | if length == 0 then null else join(",") end),
    .box.macOSVersion, .box.macOSBuild, .box.createdAt,
    ([.needs // [] | .[] | select(.kind == "recreate") | .reason][0]) ];'

# agentvm_box_info <name>  ->  `agent-vm box info <name> --json`: the box's status entry and what
# its disk takes, which agent-vm measures (about 0.1 s), so it is read for the selected box only
# and never in the poll loop. A running box's entry comes from its supervisor, so a box that does
# not answer holds this up for as long as it holds up `status`.
agentvm_box_info() {
    _agentvm_need_name box "$1" || return $?
    agentvm_json box info "$1"
}

# agentvm_box_info_row  <  box info JSON  ->  one row: fields 1-22 as agentvm_status_box_rows,
# then 23 bytes (the space the box takes)   24 unsharedBytes (what deleting it frees).
agentvm_box_info_row() {
    /usr/bin/jq -r "$agentvm_jq_defs$agentvm_jq_box_defs"' box_cells + [.diskUsage.bytes, .diskUsage.unsharedBytes] | row'
}

# agentvm_box_view <name> [interactive]  ->  0 once the box's supervisor shows its screen in a
# window, or brought that window to the front. The supervisor owns the window, so the command
# returns at once and closing the window leaves the box running. "interactive" lets keys and
# clicks reach the box. agent-vm refuses a box that does not run.
agentvm_box_view() {
    _agentvm_need_name box "$1" || return $?
    if [ "${2:-}" = "interactive" ]; then
        agentvm_json box view "$1" --interactive >/dev/null
        return $?
    fi
    agentvm_json box view "$1" >/dev/null
}

# agentvm_box_recreate <name>  ->  0 once the stopped box is made again as a fresh clone of its
# image as the image is now, with the same name, processors, memory, network rules and disposable
# flag. Everything written in the old box goes. agent-vm refuses a box that runs, and one whose
# image is gone. A clone, so it takes a moment, not a job.
agentvm_box_recreate() {
    _agentvm_need_name box "$1" || return $?
    agentvm_json box recreate "$1" >/dev/null
}

# agentvm_box_delete <name>  ->  0 once the box and its disk are gone. agent-vm refuses a box
# that runs. The image it was made from is not touched.
agentvm_box_delete() {
    _agentvm_need_name box "$1" || return $?
    agentvm_json box delete "$1" >/dev/null
}

# -- A box's network -----------------------------------------------------------------------------

# agentvm_box_packs  ->  `agent-vm box packs --json`: the host packs this agent-vm knows (its own,
# and any in the store's Packs/), for agentvm_packs_rows.
agentvm_box_packs() {
    agentvm_json box packs
}

# agentvm_packs_rows  <  box packs JSON  ->  one row per pack: name, description.
agentvm_packs_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .[] | [.name, .description] | row'
}

# agentvm_box_rules <name>  ->  `agent-vm box network <name> --json` with no change asked for:
# the box's mode and rules as they are now, for agentvm_rules_lines.
agentvm_box_rules() {
    _agentvm_need_name box "$1" || return $?
    agentvm_json box network "$1"
}

# agentvm_rules_lines  <  box network JSON  ->  the mode (allowlist, off or open; a box made before
# network rules is open) on the first line, then one rule per line, as agent-vm lists them.
agentvm_rules_lines() {
    /usr/bin/jq -r "$agentvm_jq_defs"' (.mode // "open"), (.allow // [] | .[] | cell)'
}

# _agentvm_need_rule <rule>  ->  0, or 2 with the reason left for agentvm_last_error. A rule is an
# argv element after --allow or --disallow, so one that is empty, starts with "-" or holds
# whitespace is refused here; agent-vm checks the rest.
_agentvm_need_rule() {
    case "$1" in
        ''|-*|*' '*|*"$(printf '\t')"*|*'
'*)
            _agentvm_refuse 2 "\"$1\" is not a network rule: a host, \"*.domain\", \"host:port\", \"pack:<name>\" or \"public\"."
            return 2 ;;
    esac
    return 0
}

# agentvm_box_network_change <name> <mode, or - to keep it> [+rule|-rule ...]  ->  0 once agent-vm
# changed the box's network in one call: --net for a new mode (agent-vm refuses it while the box
# runs: the mode decides the box's network card), --allow for each +rule, --disallow for each
# -rule. Rules apply at once, even while the box runs: its proxy rereads them.
agentvm_box_network_change() {
    _agentvm_need_name box "$1" || return $?
    local _box="$1"
    local _mode="$2"
    shift 2
    local _change
    case "$_mode" in
        -|allowlist|off|open) ;;
        *)  _agentvm_refuse 2 "\"$_mode\" is not a network mode: allowlist, off or open."
            return 2 ;;
    esac
    # Checked first, so nothing is changed when one of them is refused.
    for _change; do
        _agentvm_need_rule "${_change#?}" || return $?
        case "$_change" in
            +*|-*) ;;
            *) _agentvm_refuse 2 "\"$_change\" is not a change: +rule or -rule."
               return 2 ;;
        esac
    done
    # Each change is taken off the front and its options put on the back, once round.
    local _left=$#
    while [ "$_left" -gt 0 ]; do
        _change="$1"
        shift
        case "$_change" in
            +*) set -- "$@" --allow "${_change#+}" ;;
            -*) set -- "$@" --disallow "${_change#-}" ;;
        esac
        _left=$((_left - 1))
    done
    if [ "$_mode" != "-" ]; then
        set -- --net "$_mode" "$@"
    fi
    agentvm_json box network "$_box" "$@" >/dev/null
}

# agentvm_box_netlog <name> <last>  ->  `agent-vm box netlog <name> --last <last> --json`: the
# box's last connections, oldest first, for agentvm_netlog_rows. The whole log can hold a hundred
# thousand connections, so the window always asks for the last few hundred.
agentvm_box_netlog() {
    _agentvm_need_name box "$1" || return $?
    case "$2" in
        ''|*[!0123456789]*) _agentvm_refuse 2 "\"$2\" is not a count."
                            return 2 ;;
    esac
    agentvm_json box netlog "$1" --last "$2"
}

# agentvm_box_execlog <name> <last>  ->  `agent-vm box execlog <name> --last <last> --json`: the last
# programs `agent-vm exec` and `box shell` ran in the box, oldest first, for agentvm_execlog_rows.
agentvm_box_execlog() {
    _agentvm_need_name box "$1" || return $?
    case "$2" in
        ''|*[!0123456789]*) _agentvm_refuse 2 "\"$2\" is not a count."
                            return 2 ;;
    esac
    agentvm_json box execlog "$1" --last "$2"
}

# agentvm_execlog_rows  <  box execlog JSON  ->  one row per program, newest first:
#   1 started (this Mac's time zone: "Sep 26 11:04:39")   2 seconds it ran (whole; "-" while it runs
#   or when no end was recorded)   3 exit status ("-" likewise; 125-127 are exec's own failures)
#   4 user   5 the command, each argument quoted only when it needs it   6 hostPid (the client
#   on this Mac)   7 the permission prompts it waited on, "; "-joined   8 stoppedOnPrompt (true when
#   agent-vm stopped it at one)
# agent-vm leaves the status empty both while a program runs and when its client died without
# writing an end; the window tells them apart.
agentvm_execlog_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' reverse | .[] | [
        (.started | fromdateiso8601? // null | if . == null then null else strflocaltime("%b %e %H:%M:%S") end),
        (if .seconds == null then null else .seconds | floor end), .status, .user,
        (.argv // [] | map(if test("^[A-Za-z0-9_@%+=:,./-]+$") then . else @sh end) | join(" ")),
        .hostPid, (.prompts // [] | if length == 0 then null else join("; ") end),
        (.stoppedOnPrompt // false) ] | row'
}

# agentvm_netlog_rows  <  box netlog JSON  ->  one row per connection: time, decision (allowed,
# denied or failed), host, port, method, why (the rule that allowed it, else agent-vm's reason).
agentvm_netlog_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .[] | [.time, .decision, .host, .port, .method, (.rule // .reason)] | row'
}

# -- Terminal ------------------------------------------------------------------------------------
# A handler has no terminal to hand the user, so what runs in Terminal is written to a .command
# file, which Terminal runs when it opens one. Each file has a name of its own (the handler's
# pid) and deletes itself as it starts: the shell reading it keeps it open, and two quick clicks
# never rewrite a file Terminal has not read yet. The file names the agent-vm and the store in use
# now, so a changed setting applies to the next one.
agentvm_terminal_dir="$agentvm_support_dir/Terminal"

# _agentvm_quote <text>  ->  the text as one single-quoted shell word.
_agentvm_quote() {
    printf "'%s'\n" "$(printf '%s' "$1" | /usr/bin/sed "s/'/'\\\\''/g")"
}

# _agentvm_command_file <box> <what> <command line>  ->  the path of a new .command file that
# runs the command line (already quoted) against the store agentvm_run uses: the app's setting,
# else the app's own AGENT_VM_HOME, else none. "None" is written out as an unset, because Terminal
# runs the file from the user's login shell, whose profile may export an AGENT_VM_HOME the app
# never saw: the box would then be looked for in another store.
_agentvm_command_file() {
    /bin/mkdir -p "$agentvm_terminal_dir"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        _agentvm_refuse 1 "Could not make the folder $agentvm_terminal_dir."
        return 1
    fi
    local _file="$agentvm_terminal_dir/$1-$2-$$.command"
    local _home="$(agentvm_setting agentVMHome)"
    [ -n "$_home" ] || _home="${AGENT_VM_HOME:-}"
    {
        printf '#!/bin/sh\n'
        printf '# Written by AgentVM for box %s. It deletes itself as it starts.\n' "$1"
        printf '/bin/rm -f "$0"\n'
        if [ -n "$_home" ]; then
            printf 'AGENT_VM_HOME=%s\nexport AGENT_VM_HOME\n' "$(_agentvm_quote "$_home")"
        else
            printf 'unset AGENT_VM_HOME\n'
        fi
        printf '%s\n' "$3"
    } > "$_file"
    _status=$?
    if [ "$_status" -eq 0 ]; then
        /bin/chmod 700 "$_file"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        /bin/rm -f "$_file"
        _agentvm_refuse 1 "Could not write $_file."
        return 1
    fi
    printf '%s\n' "$_file"
}

# agentvm_shell_file <box>  ->  a .command file that opens a login shell in the running box.
agentvm_shell_file() {
    _agentvm_need_name box "$1" || return $?
    _agentvm_command_file "$1" shell "exec $(_agentvm_quote "$(agentvm_bin)") box shell $1"
}

# agentvm_avm  ->  the path to run avm as: agent-vm knows it is avm by the name it was started
# under. The installed one has its link beside it (~/.local/bin/avm); for a developer override or
# the test seam, the app keeps a link named avm to it in its own folder.
agentvm_avm() {
    local _bin="$(agentvm_bin)"
    local _installed_avm="${agentvm_installed%/*}/avm"
    if [ "$_bin" = "$agentvm_installed" ] && [ -f "$_installed_avm" ] && [ -x "$_installed_avm" ]; then
        printf '%s\n' "$_installed_avm"
        return 0
    fi
    local _link="$agentvm_support_dir/bin/avm"
    /bin/mkdir -p "$agentvm_support_dir/bin"
    local _status=$?
    if [ "$_status" -eq 0 ]; then
        /bin/ln -sfn "$_bin" "$_link"
        _status=$?
    fi
    if [ "$_status" -ne 0 ]; then
        _agentvm_refuse 1 "Could not make the link $_link to $_bin."
        return 1
    fi
    printf '%s\n' "$_link"
}

# agentvm_avm_file <box> <folder>  ->  a .command file that runs avm on the box from the folder:
# avm starts the box when it is stopped, shares the folder into it at the same path, snapshots
# it, asks what to run (an agent, or a shell), and afterwards reports what changed. The box goes
# in with --box: as a bare word, a box named like one of avm's subcommands (new, list, agents, to,
# help) would run that subcommand instead.
agentvm_avm_file() {
    _agentvm_need_name box "$1" || return $?
    case "$2" in
        /*) ;;
        *)  _agentvm_refuse 2 "\"$2\" is not a folder's full path."
            return 2 ;;
    esac
    if [ ! -d "$2" ]; then
        _agentvm_refuse 2 "There is no folder at $2."
        return 2
    fi
    local _avm
    _avm="$(agentvm_avm)"
    local _status=$?
    if [ "$_status" -ne 0 ]; then
        return "$_status"
    fi
    _agentvm_command_file "$1" agent "cd $(_agentvm_quote "$2") && exec $(_agentvm_quote "$_avm") --box $1"
}

# agentvm_status_image_rows  <  status JSON  ->  one row per image:
#    1 name   2 state (installing, installed, provisioning, ready, failed)   3 failure
#    4 macOS (its version)   5 macOSBuild   6 basedOn (the image it was built from; "-" for one
#    built from a restore file)   7 recipe (the recipe's description)   8 needs (kinds,
#    comma-joined: guest-update, full-disk-access)   9 guestVersion   10 createdAt   11 path
agentvm_status_image_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs$agentvm_jq_image_defs"' .images[] | image_cells | row'
}

# The first eleven cells of an image, as agentvm_status_image_rows documents them: `status`
# gives each image's record, and `image info` the same record with its sizes.
agentvm_jq_image_defs='
def image_cells: [
    .name, .state, .failure, .macOSVersion, .macOSBuild, .derivedFrom.image,
    .recipe.description,
    (.needs // [] | map(.kind) | if length == 0 then null else join(",") end),
    .guestVersion, .createdAt, .path ];'

# agentvm_status_update_rows  <  status JSON  ->  one row per image, with what an update of it
# would find and what the last one did:
#    1 name   2 revision (how often an update changed its disk; "-" for never)   3 updatedAt
#    4 macOSCheckedAt (when an update of the image last asked Apple)   5 toolsCheckedAt (when
#    one last ran its recipes' update steps)
#    6 the newer macOS it can take, by what `status --check-updates` last learned ("-" when it
#      is not behind, or nothing was learned)   7 that macOS's build   8 when that was learned
#    9 the recipes it keeps (names, comma-joined, in the order they ran; "-" for an image built
#      before agent-vm listed them, whose tools an update cannot refresh)
#   10 updating (true while an agent-vm command changes the image: an update or a setup, started
#      as a job or not)
#   11 what its guest daemon lacks (features, comma-joined; "-" when nothing)
agentvm_status_update_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .images[] | [
        .name, .revision, .updatedAt, .macOSCheckedAt, .toolsCheckedAt,
        .macOSUpdate.version, .macOSUpdate.build, .macOSUpdate.checkedAt,
        ([.recipes // [] | .[] | select(.folder != null) | .name // .folder] | if length == 0 then null else join(",") end),
        (.updating // false),
        ([.needs // [] | .[] | select(.kind == "guest-update") | .missing // [] | .[]]
            | if length == 0 then null else join(",") end) ] | row'
}

# agentvm_status_newest_row  <  status JSON  ->  version, build, checkedAt, error: the newest macOS
# this Mac's virtual machines can run, as `status --check-updates` last learned it and agent-vm
# kept it; all "-" when it was never asked. The error is why the lookup of this very call failed.
agentvm_status_newest_row() {
    /usr/bin/jq -r "$agentvm_jq_defs"' [.newestMacOS.version, .newestMacOS.build, .newestMacOS.checkedAt, .newestMacOSError] | row'
}

# agentvm_image_info <name>  ->  `agent-vm image info <name> --json`: the image's record and
# what its disk takes, which agent-vm measures (0.1-0.3 s), so it is read for the selected image
# only and never in the poll loop.
agentvm_image_info() {
    _agentvm_need_name image "$1" || return $?
    agentvm_json image info "$1"
}

# agentvm_image_info_row  <  image info JSON  ->  one row: fields 1-11 as agentvm_status_image_rows,
# then
#   12 guestFeatures (comma-joined)   13 missing (the features a guest update would add,
#      comma-joined)   14 provisionSeconds (how long the build took, whole seconds)
#   15 fullDiskAccess (granted, not-granted, or "-" when it was never checked)   16 its checkedAt
#   17 commandLineTools   18 cpus   19 memoryGB   20 bytes (the space the image takes)
#   21 unsharedBytes (what deleting it frees)   22 addedBytes (what it added over the image it
#      was built from)
agentvm_image_info_row() {
    /usr/bin/jq -r "$agentvm_jq_defs$agentvm_jq_image_defs"' image_cells + [
        (.guestFeatures // [] | if length == 0 then null else join(",") end),
        ([.needs // [] | .[] | select(.kind == "guest-update") | .missing // [] | .[]]
            | if length == 0 then null else join(",") end),
        (if .provisionSeconds == null then null else .provisionSeconds | floor end),
        (if .fullDiskAccess == null then null elif .fullDiskAccess.granted then "granted" else "not-granted" end),
        .fullDiskAccess.checkedAt, .commandLineTools,
        .cpuCount, (if .memoryBytes == null then null else .memoryBytes / 1073741824 | floor end),
        .diskUsage.bytes, .diskUsage.unsharedBytes, .addedOverBase.bytes ] | row'
}

# agentvm_image_delete <name>  ->  0 when agent-vm deleted the image and its disk. agent-vm
# refuses while another agent-vm process uses it (a build, an update, a box being made from it).
# Boxes and images made from it keep working: they are clones.
agentvm_image_delete() {
    _agentvm_need_name image "$1" || return $?
    agentvm_json image delete "$1" >/dev/null
}

# agentvm_status_vm_row  <  status JSON  ->  count, limit: the virtual machines running on this
# Mac (any application's, image builds included) and how many macOS guests can run at once.
# count is "-" when agent-vm could not list processes.
agentvm_status_vm_row() {
    /usr/bin/jq -r "$agentvm_jq_defs"' [.runningVMs.count, .runningVMs.limit] | row'
}

# -- Jobs ----------------------------------------------------------------------------------------
# What takes longer than a handler may wait (starting or stopping a box, building or updating an
# image, a download) runs as an agent-vm job: a detached process that outlives the handler, the
# window and the app, with its record in the store, where `status` and `job list` show it to this
# app, to Cadabra and to Terminal alike. These functions are the only place that knows how jobs
# are started and read; handlers and tests see nothing of `agent-vm job` itself.

# agentvm_valid_job_id <id>  ->  0 when it has the form of a job id (digits, the hex digits a to f
# and "-", starting with a digit, as in 20261001-094934-a1b2c3: the time and six random hex
# digits). Checked because an id is an argv element and comes back from a pasteboard or a table row.
agentvm_valid_job_id() {
    case "$1" in
        [0123456789]*) ;;
        *) return 1 ;;
    esac
    case "$1" in
        *[!0123456789abcdef-]*) return 1 ;;
    esac
    [ "${#1}" -le 40 ]
}

# _agentvm_need_job <id>  ->  0, or refuses an id agent-vm would not have given.
_agentvm_need_job() {
    agentvm_valid_job_id "$1" && return 0
    _agentvm_refuse 2 "\"$1\" is not a job id."
}

# _agentvm_job_start <after: a job id, or -> <agent-vm args...>  ->  the new job's id on stdout, and
# agent-vm's status. `job start` checks the command before the job starts, so a refusal (a
# command no job runs, a job to wait for that already failed) comes back here; what the command
# itself finds (an unknown box, no free slot) fails the job in the background.
# --json belongs before the "--": after it, everything is the job's command.
_agentvm_job_start() {
    local _after="$1"
    shift
    /bin/rm -f "$agentvm_err_file"
    local _json _status
    if [ "$_after" = "-" ]; then
        _json="$(agentvm_run job start --json -- "$@" 2>"$agentvm_err_file")"
        _status=$?
    else
        _agentvm_need_job "$_after" || return $?
        _json="$(agentvm_run job start --after "$_after" --json -- "$@" 2>"$agentvm_err_file")"
        _status=$?
    fi
    [ "$_status" -eq 0 ] || return "$_status"
    /bin/rm -f "$agentvm_err_file"
    local _id="$(printf '%s\n' "$_json" | /usr/bin/jq -r '.id // empty' 2>/dev/null)"
    if ! agentvm_valid_job_id "$_id"; then
        _agentvm_refuse 1 "agent-vm started a job and did not say which."
        return $?
    fi
    printf '%s\n' "$_id"
}

# agentvm_job_box_start <name>  ->  the id of a job that starts the box, with no owner: it runs
# until it is stopped, whether or not the app is running, as a box started in Terminal does.
# agentvm_job_box_stop <name>   ->  the id of a job that stops it.
agentvm_job_box_start() {
    _agentvm_need_name box "$1" || return $?
    _agentvm_job_start - box start "$1"
}
agentvm_job_box_stop() {
    _agentvm_need_name box "$1" || return $?
    _agentvm_job_start - box stop "$1"
}

# agentvm_image_update_flags <macos: 1 or 0> <tools> <guest>  ->  the options of `image update` for
# those parts ("--macos --guest"), or nothing when none is asked for. One function for the job and
# for the command line a window shows, so the two cannot differ.
agentvm_image_update_flags() {
    local _flags=""
    [ "${1:-}" = "1" ] && _flags="--macos"
    [ "${2:-}" = "1" ] && _flags="${_flags:+$_flags }--tools"
    [ "${3:-}" = "1" ] && _flags="${_flags:+$_flags }--guest"
    printf '%s\n' "$_flags"
}

# agentvm_job_image_update <name> <macos: 1 or 0> <tools> <guest>  ->  the id of a job that updates
# the ready image in place: the macOS update Apple offers within its major version, the update
# steps of the recipes it keeps, and this agent-vm's guest daemon, each when asked for. The update
# works on a copy and takes the image's place only when everything succeeded. With no part asked
# for, nothing is started: agent-vm would take that for all three.
agentvm_job_image_update() {
    _agentvm_need_name image "$1" || return $?
    local _flags="$(agentvm_image_update_flags "${2:-}" "${3:-}" "${4:-}")"
    if [ -z "$_flags" ]; then
        _agentvm_refuse 2 "Nothing was chosen to update in image $1."
        return 2
    fi
    # Unquoted on purpose: the flags are this library's own words, one option each.
    _agentvm_job_start - image update "$1" $_flags
}

# agentvm_job_image_setup <name>  ->  the id of a job that boots the ready image and shows its screen
# in a window of agent-vm's, with System Settings on Full Disk Access, for the one-time steps only
# a person can do there. Closing that window shuts the image down and ends the job; whether the
# guest daemon has Full Disk Access is then in the image's record (its `needs` in `status`). The
# job needs a login session on this Mac and one virtual machine slot.
agentvm_job_image_setup() {
    _agentvm_need_name image "$1" || return $?
    _agentvm_job_start - image setup "$1"
}

# agentvm_job_list  ->  the jobs as JSON: those that run, and those that ended in the last week.
# `status` carries those that run or wait and those that ended in the last hour, which is all a
# window that follows its jobs needs; the week is for a report of what ended while the app was
# closed.
agentvm_job_list() {
    agentvm_json job list
}

# agentvm_job_rows  <  status JSON, `job list` JSON or `job log` JSON  ->  one row per job, oldest
# first (the one job, for `job log`):
#    1 id   2 state (queued, running, done, failed, canceled, lost)
#    3 target, the first one ("box:<name>", "image:<name>" or "ipsw")
#    4 what it does, the command's first two words ("box start", "image create")
#    5 status (the exit status, once it ended)   6 createdAt   7 startedAt   8 endedAt
#    9 the last progress event's step   10 its fraction (0-1)   11 its index   12 its count
#   13 its message   14 the last notice   15 error (after it failed or was canceled)
#   16 after (the job it waits for)
agentvm_job_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' (if type == "array" then . elif has("job") then [.job] else (.jobs // []) end)[]
        | [.id, .state, (.targets // [])[0], ((.command // [])[0:2] | join(" ")), .status, .createdAt, .startedAt, .endedAt,
           .progress.step, .progress.fraction, .progress.index, .progress.count, .progress.message, .notice, .error, .after]
        | row'
}

# agentvm_job_log <id>  ->  everything agent-vm keeps of one job, as JSON: `job` (its record, as
# `job list` gives it), `events` (every progress event its command wrote, oldest first) and
# `lines` (what the command wrote that is neither an event nor its error). agent-vm fails for a
# job it no longer keeps.
agentvm_job_log() {
    _agentvm_need_job "$1" || return $?
    agentvm_json job log "$1"
}

# agentvm_job_event_rows  <  `job log` JSON  ->  one row per event, oldest first:
#   1 event (progress: a step began or moved on; log: a line of the log; notice: something the
#     user may need to act on)
#   2 step (a progress event's; names are stable, messages are not)   3 fraction (0-1)
#   4 index   5 count   6 message   7 output ("true" for a line a program in the guest printed)
#   8 expectedSeconds (how long the step took last time, when agent-vm knows)
agentvm_job_event_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' (.events // [])[]
        | [.event, .step, .fraction, .index, .count, .message, .output, .expectedSeconds] | row'
}

# agentvm_job_lines  <  `job log` JSON  ->  the other lines the command wrote, one per line.
agentvm_job_lines() {
    /usr/bin/jq -r '(.lines // [])[] | strings | gsub("[\t\n\r]"; " ")'
}

# agentvm_job_cancel <id>  ->  0 once the job was asked to stop; it stops at its next safe point and
# ends canceled. agent-vm refuses a job that is not running or queued.
# agentvm_job_forget <id>  ->  0 once a finished job's record is gone. agent-vm refuses a running one.
agentvm_job_cancel() {
    _agentvm_need_job "$1" || return $?
    agentvm_json job cancel "$1" >/dev/null
}
agentvm_job_forget() {
    _agentvm_need_job "$1" || return $?
    agentvm_json job forget "$1" >/dev/null
}

# -- Building an image ---------------------------------------------------------------------------
# A new image starts from a ready image or from a macOS restore file agent-vm downloaded, and gets
# the tools of the recipes named, in the order given. The recipes offered are the ones that come
# with the agent-vm in use.

# agentvm_status_build_rows  <  status JSON  ->  one row per image, with what a build that starts
# from it needs to know:
#    1 name   2 state   3 updating (true while an agent-vm command changes it)   4 macOS
#    5 CPUs   6 memory, in GB   7 disk, in GB
#    8 the recipes it keeps (names, comma-joined, in the order they ran; "-" for none, and for an
#      image built before agent-vm listed them)
#    9 its recipe's description   10 its Command Line Tools   11 needs (kinds, comma-joined)
#   12 the descriptions of the recipes it keeps, joined with "; " ("-" for none)
agentvm_status_build_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .images[] | [
        .name, .state, (.updating // false), .macOSVersion, .cpuCount,
        (if .memoryBytes == null then null else .memoryBytes / 1073741824 | floor end),
        (if .diskBytes == null then null else .diskBytes / 1073741824 | floor end),
        ([.recipes // [] | .[] | select(.folder != null) | .name // empty] | if length == 0 then null else join(",") end),
        .recipe.description, .commandLineTools,
        (.needs // [] | map(.kind) | if length == 0 then null else join(",") end),
        ([.recipes // [] | .[] | .description // empty] | if length == 0 then null else join("; ") end) ] | row'
}

# agentvm_ipsw_list  ->  `agent-vm image fetch-ipsw --list --json`: the macOS restore files
# agent-vm downloaded, which only reads its cache folder.
agentvm_ipsw_list() {
    agentvm_json image fetch-ipsw --list
}

# agentvm_ipsw_rows  <  that JSON  ->  one row per restore file: name, macOS, build, bytes, latest
# (true for the newest), path.
agentvm_ipsw_rows() {
    /usr/bin/jq -r "$agentvm_jq_defs"' .[] | [.name, .macOSVersion, .macOSBuild, .bytes, (.latest // false), .path] | row'
}

# agentvm_recipes_dir  ->  the folder of the recipes that come with the agent-vm in use, or
# nothing: AGENTVM_APP_RECIPES (the tests' seam); else Recipes beside the real executable, where
# agent-vm's installer puts it (the link in ~/.local/bin resolved); else, for a developer's build
# inside an agent-vm working tree, the Recipes of the nearest folder above the executable that
# also holds Package.swift.
agentvm_recipes_dir() {
    if [ -n "${AGENTVM_APP_RECIPES:-}" ]; then
        printf '%s\n' "$AGENTVM_APP_RECIPES"
        return 0
    fi
    local _real
    _real="$(/bin/realpath "$(agentvm_bin)" 2>/dev/null)"
    local _status=$?
    if [ "$_status" -ne 0 ] || [ -z "$_real" ]; then
        return 0
    fi
    local _dir="${_real%/*}"
    if [ -d "$_dir/Recipes" ]; then
        printf '%s\n' "$_dir/Recipes"
        return 0
    fi
    local _up=0
    while [ "$_up" -lt 6 ] && [ -n "$_dir" ]; do
        _dir="${_dir%/*}"
        if [ -d "$_dir/Recipes" ] && [ -f "$_dir/Package.swift" ]; then
            printf '%s\n' "$_dir/Recipes"
            return 0
        fi
        _up=$((_up + 1))
    done
    return 0
}

# agentvm_recipe_rows  ->  one row per recipe in agentvm_recipes_dir, in the folder's order:
#    1 name (its folder's, as agent-vm names a kept recipe)   2 description   3 how many input
#    files it asks for   4 how many parameters it has   5 the path of its recipe.json
# A folder whose name agent-vm would not accept as a name, or whose recipe.json is not JSON, is
# left out: agent-vm reads the recipe itself, and refuses a broken one before anything is built.
agentvm_recipe_rows() {
    local _dir="$(agentvm_recipes_dir)"
    [ -n "$_dir" ] && [ -d "$_dir" ] || return 0
    local _file _name
    for _file in "$_dir"/*/recipe.json; do
        [ -f "$_file" ] || continue
        _name="${_file%/recipe.json}"
        _name="${_name##*/}"
        agentvm_valid_name "$_name" || continue
        /usr/bin/jq -r --arg name "$_name" --arg path "$_file" "$agentvm_jq_defs"'
            [$name, .description, (.inputs // {} | length), (.parameters // {} | length), $path] | row' "$_file" 2>/dev/null
    done
    return 0
}

# agentvm_recipe_name <path of a recipe file>  ->  what agent-vm calls the recipe: its folder's
# name when the file is recipe.json, else the file's name without its extension; only letters,
# digits, ".", "_" and "-" are kept (anything else becomes "-"), at most 40 characters, and
# "recipe" when nothing but dots and dashes is left. agent-vm's own rule, for display.
agentvm_recipe_name() {
    local _raw="${1##*/}"
    if [ "$_raw" = "recipe.json" ]; then
        _raw="${1%/*}"
        _raw="${_raw##*/}"
    else
        case "$_raw" in
            ?*.*) _raw="${_raw%.*}" ;;
        esac
    fi
    _raw="$(printf '%s' "$_raw" | LC_ALL=C /usr/bin/tr -c 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-' '-' | /usr/bin/cut -c1-40)"
    case "$_raw" in
        *[!.-]*) printf '%s\n' "$_raw" ;;
        *)       printf 'recipe\n' ;;
    esac
}

# agentvm_recipe_row <path of a recipe file>  ->  its row, as agentvm_recipe_rows gives one (name,
# description, input files, parameters, path), for a recipe file anywhere on this Mac, under
# agent-vm's name for it. Nothing when the file is not there, is not JSON, or is not an object
# with steps: agent-vm reads the recipe itself, and says what is wrong with one it refuses.
agentvm_recipe_row() {
    [ -f "$1" ] || return 0
    /usr/bin/jq -r --arg name "$(agentvm_recipe_name "$1")" --arg path "$1" "$agentvm_jq_defs"'
        select(type == "object" and (.steps | type) == "array")
        | [$name, .description, (.inputs // {} | length), (.parameters // {} | length), $path] | row' "$1" 2>/dev/null
}

# agentvm_recipe_option_rows <path of a recipe.json>  ->  one row per thing the recipe asks for,
# its input files first:
#    1 kind (input: a file, given with --input; set: a parameter, given with --set)   2 name
#    3 default ("-" for an input, and for a parameter whose default is empty)   4 description
# A name that is not letters, digits and "_" is left out: it becomes part of an argument.
agentvm_recipe_option_rows() {
    [ -f "$1" ] || return 0
    /usr/bin/jq -r "$agentvm_jq_defs"'
        ((.inputs // {} | to_entries[] | ["input", .key, null, .value.description]),
         (.parameters // {} | to_entries[] | ["set", .key, .value.default, .value.description]))
        | select(.[1] | test("^[A-Za-z_][A-Za-z0-9_]*$")) | row' "$1" 2>/dev/null
}

# agentvm_args_text  <  arguments, one per line  ->  them on one line as they would be typed in
# Terminal: an argument with anything but plain characters in it is quoted.
agentvm_args_text() {
    local _text="" _line
    while IFS= read -r _line; do
        case "$_line" in
            ''|*[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_@%+=:,./-]*)
                _line="$(_agentvm_quote "$_line")" ;;
        esac
        _text="${_text:+$_text }$_line"
    done
    printf '%s\n' "$_text"
}

# agentvm_job_image_create  <  the arguments of `image create`, one per line: the new image's
# name, then options and their values (--from <image> or --ipsw <path> first, then any of
# --recipe <path>, --input <name=path>, --set <name=value>, --cpus, --memory-gb, --disk-gb <n>)
#   ->  the id of a job that builds the image. One list for the job and for the command line a
# window shows (agentvm_args_text), so the two cannot differ. Everything is checked again here,
# since each line becomes an argument: an option is one of those above, a name is one agent-vm
# accepts, a path is absolute, a number is digits, and no value begins with "-".
agentvm_job_image_create() {
    set --
    local _line
    while IFS= read -r _line; do
        set -- "$@" "$_line"
    done
    if [ "$#" -lt 3 ] || [ $(( $# % 2 )) -ne 1 ]; then
        _agentvm_refuse 2 "The build's arguments are not a name and options with their values."
        return 2
    fi
    _agentvm_need_name image "$1" || return $?
    case "$2" in
        --from|--ipsw) ;;
        *)  _agentvm_refuse 2 "A build starts from an image or from a restore file."
            return 2 ;;
    esac
    local _option="" _word _ok _count=0
    for _word; do
        _count=$((_count + 1))
        [ "$_count" -eq 1 ] && continue
        if [ -z "$_option" ]; then
            _option="$_word"
            continue
        fi
        _ok=1
        case "$_option" in
            --from)
                agentvm_valid_name "$_word" || _ok=0 ;;
            --ipsw|--recipe)
                case "$_word" in
                    /*) ;;
                    *) _ok=0 ;;
                esac ;;
            --input)
                case "$_word" in
                    [ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]*=/*) ;;
                    *) _ok=0 ;;
                esac ;;
            --set)
                case "$_word" in
                    [ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]*=*) ;;
                    *) _ok=0 ;;
                esac ;;
            --cpus|--memory-gb|--disk-gb)
                case "$_word" in
                    ''|*[!0123456789]*) _ok=0 ;;
                esac ;;
            *)  _ok=0 ;;
        esac
        if [ "$_ok" -ne 1 ]; then
            _agentvm_refuse 2 "\"$_option $_word\" is not something this app passes to image create."
            return 2
        fi
        _option=""
    done
    _agentvm_job_start - image create "$@"
}

# -- Making a box ----------------------------------------------------------------------------------
# A box is a copy of a ready image, made at once (the disk is cloned, not copied), with its own
# processors, memory and network rules.

# agentvm_agents_file  ->  the file of the agents that come with the agent-vm in use (what avm
# offers to run, and the hosts each needs), or nothing: AGENTVM_APP_AGENTS (the tests' seam); else
# agents.json beside the real executable, where agent-vm's installer puts it; else, for a
# developer's build inside an agent-vm working tree, Resources/agents.json of the nearest folder
# above the executable that also holds Package.swift.
agentvm_agents_file() {
    if [ -n "${AGENTVM_APP_AGENTS:-}" ]; then
        printf '%s\n' "$AGENTVM_APP_AGENTS"
        return 0
    fi
    local _real
    _real="$(/bin/realpath "$(agentvm_bin)" 2>/dev/null)"
    local _status=$?
    if [ "$_status" -ne 0 ] || [ -z "$_real" ]; then
        return 0
    fi
    local _dir="${_real%/*}"
    if [ -f "$_dir/agents.json" ]; then
        printf '%s\n' "$_dir/agents.json"
        return 0
    fi
    local _up=0
    while [ "$_up" -lt 6 ] && [ -n "$_dir" ]; do
        _dir="${_dir%/*}"
        if [ -f "$_dir/Resources/agents.json" ] && [ -f "$_dir/Package.swift" ]; then
            printf '%s\n' "$_dir/Resources/agents.json"
            return 0
        fi
        _up=$((_up + 1))
    done
    return 0
}

# agentvm_agent_rows  ->  one row per agent in agentvm_agents_file: its id, its name, and the
# network rules it needs, comma-joined ("-" for none). An id that is not lower-case letters,
# digits and "-" is left out. Nothing when there is no such file, or it is not JSON.
agentvm_agent_rows() {
    local _file="$(agentvm_agents_file)"
    [ -n "$_file" ] && [ -f "$_file" ] || return 0
    /usr/bin/jq -r "$agentvm_jq_defs"' .agents // [] | .[]
        | select((.id // "") | test("^[a-z0-9][a-z0-9-]*$"))
        | [.id, (.name // .id), (.allow // [] | if length == 0 then null else join(",") end)] | row' "$_file" 2>/dev/null
}

# agentvm_box_create  <  the arguments of `box create`, one per line: the new box's name, then
# options and their values (--image <image> first, then any of --cpus <n>, --memory-gb <n>,
# --net <mode>, --allow <rule>)
#   ->  0 once agent-vm made the box. One list for the call and for the command line a window
# shows (agentvm_args_text), so the two cannot differ. Everything is checked again here, since
# each line becomes an argument: an option is one of those above, a name is one agent-vm
# accepts, a number is digits, a mode is one of the three, and a rule is one word that does not
# begin with "-". A kept box only: --disposable is not passed.
agentvm_box_create() {
    set --
    local _line
    while IFS= read -r _line; do
        set -- "$@" "$_line"
    done
    if [ "$#" -lt 3 ] || [ $(( $# % 2 )) -ne 1 ]; then
        _agentvm_refuse 2 "The box's arguments are not a name and options with their values."
        return 2
    fi
    _agentvm_need_name box "$1" || return $?
    if [ "$2" != "--image" ]; then
        _agentvm_refuse 2 "A box is made from an image."
        return 2
    fi
    local _option="" _word _ok _count=0
    for _word; do
        _count=$((_count + 1))
        [ "$_count" -eq 1 ] && continue
        if [ -z "$_option" ]; then
            _option="$_word"
            continue
        fi
        _ok=1
        case "$_option" in
            --image)
                agentvm_valid_name "$_word" || _ok=0 ;;
            --cpus|--memory-gb)
                case "$_word" in
                    ''|*[!0123456789]*) _ok=0 ;;
                esac ;;
            --net)
                case "$_word" in
                    allowlist|off|open) ;;
                    *) _ok=0 ;;
                esac ;;
            --allow)
                _agentvm_need_rule "$_word" || return $? ;;
            *)  _ok=0 ;;
        esac
        if [ "$_ok" -ne 1 ]; then
            _agentvm_refuse 2 "\"$_option $_word\" is not something this app passes to box create."
            return 2
        fi
        _option=""
    done
    agentvm_json box create "$@" >/dev/null
}
