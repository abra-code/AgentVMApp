#!/bin/sh
# Tests/98-command-wiring.test.sh - every command the engine can dispatch has the exact script
# it will look for, and every script is reachable.
#
# Adapted from Cadabra's Tests/98-command-wiring.test.sh. A missing script is not an error to
# the engine: it logs "unable to find script file" and returns, so a window opens with nothing
# in it, or a button does nothing, and every handler test still passes, because they dispatch
# handlers by name and walk straight past the binding the engine derives. These checks are about
# the wiring, not the behavior:
#   - the main command, which carries no COMMAND_ID, resolves to <NAME>.main.sh;
#   - every other exe_script_file command resolves to <COMMAND_ID>.sh;
#   - every subcommand a window declares (init, activate, close) and every actionID in a window
#     document resolves to a declared command or to a script of exactly that name, case
#     included (the engine dispatches case-sensitively; the harness's resolver does not);
#   - every handler script is named by something: a declared command, a subcommand, an actionID,
#     or an omc_next_command in another script. An unreachable script is dead code, or a
#     reference that was renamed on one side only.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

COMMANDS="$APP_RESOURCES/Command.json"
DOCUMENTS="$APP_RESOURCES/Base.lproj"

# declared_ids  ->  every COMMAND_ID in Command.json, and the main command as <NAME>.main.
declared_ids() {
    /usr/bin/jq -r '.COMMAND_LIST[] | (.COMMAND_ID // (.NAME + ".main"))' "$COMMANDS"
}

# referenced_ids  ->  every command id something refers to: the window subcommands in
# Command.json, every *actionID in the window documents, and every omc_next_command target
# written as a literal in the scripts.
referenced_ids() {
    /usr/bin/jq -r '.COMMAND_LIST[] | .ACTIONUI_WINDOW // {} | to_entries[]
        | select(.key | endswith("SUBCOMMAND_ID")) | .value' "$COMMANDS"
    /usr/bin/jq -r '.. | objects | to_entries[] | select(.key | test("[aA]ctionID$")) | .value | strings' \
        "$DOCUMENTS"/*.json
    /usr/bin/sed -n 's/.*"\$next_command" "\$OMC_CURRENT_COMMAND_GUID" "\([^"]*\)".*/\1/p' "$APP_SCRIPTS"/*.sh
}

# handler_scripts  ->  the stem of every script that is not a library.
handler_scripts() {
    local _file
    for _file in "$APP_SCRIPTS"/*.sh; do
        _file="${_file##*/}"
        case "$_file" in
            lib.*) ;;
            *) printf '%s\n' "${_file%.sh}" ;;
        esac
    done
}

section "the command table and the scripts are there to check"
# The positive control: every check below has the form "nothing is missing", which an empty or
# unreadable table answers without examining anything.
check "Command.json has commands"        "yes" "$(declared_ids | /usr/bin/awk 'END { if (NR >= 1) print "yes" }')"
check "the window documents name actions" "yes" "$(referenced_ids | /usr/bin/awk 'END { if (NR >= 5) print "yes" }')"
check "there are handler scripts"         "yes" "$(handler_scripts | /usr/bin/awk 'END { if (NR >= 5) print "yes" }')"

section "the main command"
# It must stay without a COMMAND_ID: one would change how its script is found.
check "has no COMMAND_ID"                "" "$(/usr/bin/jq -r '.COMMAND_LIST[0].COMMAND_ID // empty' "$COMMANDS")"
check "is named AgentVM"                 "AgentVM" "$(/usr/bin/jq -r '.COMMAND_LIST[0].NAME' "$COMMANDS")"
check_exists "AgentVM.main.sh exists"    "$APP_SCRIPTS/AgentVM.main.sh"
# The engine's fallback: a file literally named main.sh would answer for the main command
# whatever its NAME, and a rename would then seem to work while running the wrong script.
check_absent "no bare main.sh"           "$APP_SCRIPTS/main.sh"

section "every exe_script_file command has its script"
missing=""
for id in $(/usr/bin/jq -r '.COMMAND_LIST[] | select((.EXECUTION_MODE // "exe_script_file") == "exe_script_file")
        | (.COMMAND_ID // (.NAME + ".main"))' "$COMMANDS"); do
    [ -f "$APP_SCRIPTS/$id.sh" ] || missing="$missing $id.sh"
done
check "none missing" "" "$missing"

section "every reference resolves, case included"
declared="$(declared_ids)"
missing=""
for id in $(referenced_ids | /usr/bin/sort -u); do
    printf '%s\n' "$declared" | /usr/bin/grep -qxF -- "$id" && continue
    [ -f "$APP_SCRIPTS/$id.sh" ] && [ -n "$(handler_scripts | /usr/bin/grep -xF -- "$id")" ] && continue
    missing="$missing $id"
done
check "no reference to a command that is not there" "" "$missing"

section "every handler script is reachable"
referenced="$( { declared_ids; referenced_ids; } | /usr/bin/sort -u)"
orphans=""
for stem in $(handler_scripts); do
    printf '%s\n' "$referenced" | /usr/bin/grep -qxF -- "$stem" || orphans="$orphans $stem.sh"
done
check "no script nothing names" "" "$orphans"

omctest_end
