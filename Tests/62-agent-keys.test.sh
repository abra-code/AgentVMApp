#!/bin/sh
# Tests/62-agent-keys.test.sh - the Agent Keys window: the library functions under it (the
# agents' keys as rows, a key's name, storing and deleting), the button that opens it, one window
# at a time and only when this run of the app asked for it, what it says for a key that is
# stored, stored by another agent-vm, or not stored, Store and Remove..., and where a typed
# key goes: to agent-vm's stdin, and nowhere else.
#
# agent-vm is the fake: the agents from fixtures/agentvm/connect-agents.json, where no key is
# stored; a key stored in the fake reads as stored. The key typed in these tests is made up.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.keys.sh"
[ -n "$KEYS_TABLE_ID" ] && [ -n "$KEYS_TITLE_ID" ] && [ -n "$KEYS_FIELD_ID" ] && [ -n "$KEYS_STORE_ID" ] \
    && [ -n "$KEYS_REMOVE_ID" ] && [ -n "$KEYS_NOTE_ID" ] && [ -n "$KEYS_HINT_ID" ] || {
    printf '62-agent-keys: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?62-agent-keys: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-agent-keys-$$"
OTHER_UUID="OMCTEST-other-agent-keys-$$"
AGENTS_BUTTON_ID=521
TYPED="sk-made-up-for-the-test-0123456789"
API="ANTHROPIC_API_KEY"
TOKEN="CLAUDE_CODE_OAUTH_TOKEN"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# agents <jq edit of connect-agents.json>  ->  the fake answers `connect agents` with that.
agents() {
    /usr/bin/jq "$1" "$FIXTURES_AGENTVM/connect-agents.json" > "$FAKE_AGENTVM_DIR/connect-agents.json"
}

request() {
    "$PB" agentvm_open_request_keys get
}

registered() {
    "$PB" agentvm_window_keys_window get
}

# open_window [uuid]  ->  the window opened the way the button opens it: the request, then the
# window's init handler, in a window of its own.
open_window() {
    "$PB" agentvm_open_request_keys set "$APP_PID keys:window"
    in_window "${1:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.keys
    omc_run AgentVM.keys.init
}

# select_key <key name> <agent id>  ->  that row selected, as the table reports it.
select_key() {
    omc_table_cell "$KEYS_TABLE_ID" 2 "$1"
    omc_table_cell "$KEYS_TABLE_ID" 5 "$2"
    omc_trigger "$KEYS_TABLE_ID"
    omc_run AgentVM.keys.selected
}

# type_key <text>  ->  the field holds that, as the engine reports it to every handler.
type_key() {
    omc_control "$KEYS_FIELD_ID" "$1"
}

enabled() {
    [ "$(ui_enabled "$1")" = "1" ] && echo 1 || echo 0
}

# said  ->  the line naming the key, what its state means, the note, and whether Store and
# Remove... are on.
said() {
    printf '%s|%s|%s|%s%s\n' "$(ui_value "$KEYS_TITLE_ID")" "$(ui_value "$KEYS_HINT_ID")" "$(ui_value "$KEYS_NOTE_ID")" \
        "$(enabled "$KEYS_STORE_ID")" "$(enabled "$KEYS_REMOVE_ID")"
}

# stored <key name>  ->  what the fake's Keychain holds under that name, or "(none)".
stored() {
    if [ -f "$FAKE_AGENTVM_DIR/secret-value-$1" ]; then
        /bin/cat "$FAKE_AGENTVM_DIR/secret-value-$1"
    else
        printf '(none)\n'
    fi
}

# leaks  ->  the places the typed key must never be in: agent-vm's arguments, the calls made to
# the window, the pasteboards, the window's cache files. A count of the places that have it.
leaks() {
    {
        /usr/bin/grep -l -- "$TYPED" "$FAKE_AGENTVM_DIR/log" 2>/dev/null
        /usr/bin/grep -rl -- "$TYPED" "$OMCTEST_UI" 2>/dev/null
        /usr/bin/grep -rl -- "$TYPED" "$TMPDIR/AgentVM" 2>/dev/null
    } | /usr/bin/awk 'END { print NR }'
}

# inherited  ->  the window values agent-vm's calls inherited, each once.
inherited() {
    /usr/bin/sort -u "$FAKE_AGENTVM_DIR/inherited" 2>/dev/null | /usr/bin/paste -sd ' ' -
}

fake_reset
"$PB" agentvm_window_keys_window set ""
"$PB" agentvm_open_request_keys set ""

# -----------------------------------------------------------------------------------------------
section "the library: the agents' keys, a key's name, storing and deleting"
check "one row per key: name, state, label, agent, its name, how many it needs" \
    "$TOKEN${TAB}missing${TAB}claude${TAB}Claude Code${TAB}one|$API${TAB}missing${TAB}claude${TAB}Claude Code${TAB}one|OPENAI_API_KEY${TAB}missing${TAB}codex${TAB}Codex${TAB}optional|-${TAB}none${TAB}opencode${TAB}opencode${TAB}optional" \
    "$(lib agentvm_agent_secret_rows < "$FIXTURES_AGENTVM/connect-agents.json" | col 1,2,4,5,6 | /usr/bin/paste -sd '|' -)"
check "every row has eight fields" "8" "$(lib agentvm_agent_secret_rows < "$FIXTURES_AGENTVM/connect-agents.json" | field_count)"
check "the list is a query" "connect agents --json" "$(with_fake agentvm_agents_list >/dev/null; fake_log | /usr/bin/tail -1)"
names_ok=""
for name in ANTHROPIC_API_KEY a_1 X; do
    lib agentvm_valid_secret_name "$name" || names_ok="$names_ok [$name refused]"
done
for name in "" "--help" "A B" "A-B" "A.B" 'A$B' "A/B" "$(printf 'A\nB')" "$(printf '%0101d' 0)"; do
    lib agentvm_valid_secret_name "$name" && names_ok="$names_ok [$name accepted]"
done
check "a key's name: letters, digits and _ only, and not too long" "" "$names_ok"
: > "$FAKE_AGENTVM_DIR/log"
printf '%s' "$TYPED" | with_fake agentvm_secret_set "$API"
check "storing: the value goes to agent-vm's stdin, whole, and its arguments are the name only" \
    "0|$TYPED|secret set $API" "$?|$(stored "$API")|$(fake_log)"
: > "$FAKE_AGENTVM_DIR/log"
printf '%s' "$TYPED" | with_fake agentvm_secret_set "--help"
check "a name agent-vm would read as an option: refused, agent-vm not run" "2|" "$?|$(fake_log)"
with_fake agentvm_secret_delete "$API"
check "deleting: by name" "0|(none)|secret delete $API" "$?|$(stored "$API")|$(fake_log)"
: > "$FAKE_AGENTVM_DIR/log"
with_fake agentvm_secret_delete "-x"
check "  and not a name that is not one" "2|" "$?|$(fake_log)"

# -----------------------------------------------------------------------------------------------
section "the button that opens it"
fake_reset
/bin/cp "$FIXTURES_AGENTVM/status-variety.json" "$FAKE_AGENTVM_DIR/status.json"
in_window "$MAIN_UUID"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
omc_trigger "$AGENTS_BUTTON_ID"
omc_run AgentVM.keys.open
check "Agent Keys... in Settings asks for the window, with a request of this run, and asks agent-vm nothing" \
    "1|$APP_PID keys:window|" "$(chain_asked AgentVM.keys)|$(request)|$(fake_log)"
check "the button runs that handler" "AgentVM.keys.open" \
    "$(/usr/bin/jq -r --argjson id "$AGENTS_BUTTON_ID" '.. | objects | select(.id? == $id) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.json")"

section "the window opens: no key stored"
: > "$FAKE_AGENTVM_DIR/log"
open_window
check_status "the init handler exits cleanly" 0
check "takes the request, once"        "" "$(request)"
check "becomes the Agent Keys window"  "$APP_PID $UUID|1" "$(registered)|$("$PB" "agentvm_keys_$UUID" get)"
check "asks agent-vm which it is, then for the agents" "--version|connect agents --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "its title"                      "Agent Keys" "$(ui_title)"
check "a row per key, and one for the agent that needs none" \
    "Claude Code${TAB}$TOKEN${TAB}Not stored${TAB}claude|Claude Code${TAB}$API${TAB}Not stored${TAB}claude|Codex${TAB}OPENAI_API_KEY${TAB}Not stored${TAB}codex|opencode${TAB}-${TAB}No key needed${TAB}opencode" \
    "$(ui_rows "$KEYS_TABLE_ID" | col 1,2,3,5 | /usr/bin/paste -sd '|' -)"
check "what each key is" "Anthropic API key" "$(ui_rows "$KEYS_TABLE_ID" | /usr/bin/sed -n '2p' | col 4)"
check "nothing selected: Store and Remove... are off" "Select a key to store or remove it.|||00" "$(said)"
check "the field has no action of its own, and is the one the library unsets" "null|1" \
    "$(/usr/bin/jq -r --argjson id "$KEYS_FIELD_ID" '.. | objects | select(.id? == $id) | .properties.actionID' "$APP_RESOURCES/Base.lproj/AgentVM.keys.json")|$(/usr/bin/grep -c "^unset OMC_ACTIONUI_VIEW_${KEYS_FIELD_ID}_VALUE\$" "$APP_SCRIPTS/lib.agentvm.keys.sh")"

section "only one window, and only when this run asked"
: > "$FAKE_AGENTVM_DIR/log"
open_window "$OTHER_UUID"
check "a second window closes itself and brings the first to the front" "1|1|$APP_PID $UUID|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(ui_calls "^${UUID}${TAB}omc_window${TAB}omc_select")|$(registered)|$(fake_log)"
in_window "$OTHER_UUID"
omc_run AgentVM.keys.close
check "  and its closing leaves the first registered" "$APP_PID $UUID" "$(registered)"
in_window "$UUID"
omc_run AgentVM.keys.close
check "the window closes: it is no longer registered, and nothing of it stays" "||no" \
    "$(registered)|$("$PB" "agentvm_keys_$UUID" get)|$([ -d "$TMPDIR/AgentVM/$UUID" ] && echo yes || echo no)"
in_window "$UUID"
ui_reset
omc_control_defaults AgentVM.keys
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.init
check "a window nobody asked for closes itself and reads nothing" "1||" \
    "$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(fake_log)|$("$PB" "agentvm_keys_$UUID" get)"
"$PB" agentvm_open_request_keys set "1 keys:window"
omc_run AgentVM.keys.init
check "nor does a request another run of the app left open one" "" "$("$PB" "agentvm_keys_$UUID" get)"

# -----------------------------------------------------------------------------------------------
section "a key selected"
open_window
select_key "$API" claude
check "a key that is not stored: named, with what the agent needs and its other way in; Store is on" \
    "$API, for Claude Code|Not stored. Claude Code needs one of its keys. Or log in inside a kept box: /login in Claude Code, then open the address it prints in this Mac's browser. Your Claude login on this Mac is not visible in the box.||10" "$(said)"
select_key OPENAI_API_KEY codex
check "a key an agent can do without" "OPENAI_API_KEY, for Codex|10" "$(ui_value "$KEYS_TITLE_ID")|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")"
check "  says so" "1" "$(ui_value "$KEYS_HINT_ID" | /usr/bin/grep -c '^Not stored\. Codex can run without it\. Or log in inside a kept box')"
select_key - opencode
check "the agent that needs no key: nothing to store" "opencode needs no key.|00" \
    "$(ui_value "$KEYS_TITLE_ID")|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")"
select_key "$API" codex
check "a key the agent does not have is no selection" "Select a key to store or remove it.|00|" \
    "$(ui_value "$KEYS_TITLE_ID")|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")|$("$PB" "agentvm_key_$UUID" get)"
select_key "--help" claude
check "nor is a name agent-vm did not list" "" "$("$PB" "agentvm_key_$UUID" get)"

# -----------------------------------------------------------------------------------------------
section "Store"
select_key "$API" claude
type_key ""
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.store
check "an empty field: agent-vm is not asked, and the window says what to do" "|Type or paste the key into the field first." \
    "$(fake_log)|$(ui_value "$KEYS_NOTE_ID")"
type_key "   "
omc_run AgentVM.keys.store
check "  nor for a field of spaces" "" "$(fake_log)"
type_key "  $TYPED "
: > "$FAKE_AGENTVM_DIR/log"
/bin/rm -f "$FAKE_AGENTVM_DIR/inherited"
omc_run AgentVM.keys.store
check_status "Store exits cleanly" 0
check "the key is stored under the selected name, without the spaces around it" "$TYPED" "$(stored "$API")"
check "agent-vm's arguments are the name only, then the keys are read again" "secret set $API|connect agents --json" "$(fake_log | /usr/bin/paste -sd '|' -)"
check "no call of agent-vm inherited the field's value" "" "$(inherited | /usr/bin/tr ' ' '\n' | /usr/bin/grep "_${KEYS_FIELD_ID}_")"
check "the typed key is in no argument, window call, pasteboard or cache file" "0" "$(leaks)"
check "the field is emptied" "1" "$(ui_calls "^${UUID}${TAB}${KEYS_FIELD_ID}${TAB} \$")"
check "the row says Stored, and stays selected" "Stored|$API" "$(ui_rows "$KEYS_TABLE_ID" | /usr/bin/sed -n '2p' | col 3)|$("$PB" "agentvm_key_$UUID" get)"
check "the window says so, and Remove... is on" \
    "$API, for Claude Code|Stored $API in your login Keychain.|11" "$(ui_value "$KEYS_TITLE_ID")|$(ui_value "$KEYS_NOTE_ID")|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")"
check "  and what Stored means" "1" "$(ui_value "$KEYS_HINT_ID" | /usr/bin/grep -c '^Stored in your login Keychain\. Store replaces it\.')"

section "Store while another Store is worked on, and just after the selection changed"
type_key "$TYPED"
"$PB" "agentvm_busy_$UUID" set "click-$$"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.store
check "a second click: agent-vm is not run, and the other click's mark stays" "|click-$$" "$(fake_log)|$("$PB" "agentvm_busy_$UUID" get)"
"$PB" "agentvm_busy_$UUID" set ""
# The table already shows another row; its selection handler has not run yet.
omc_table_cell "$KEYS_TABLE_ID" 2 OPENAI_API_KEY
omc_table_cell "$KEYS_TABLE_ID" 5 codex
omc_run AgentVM.keys.store
check "the table shows another key than the window works on: nothing is stored, and the window says so" \
    "|The selection was still changing. Nothing was stored: click Store again.|(none)" \
    "$(fake_log)|$(ui_value "$KEYS_NOTE_ID")|$(stored OPENAI_API_KEY)"
alerts_reset
omc_run AgentVM.keys.remove
check "  nor is a removal asked about" "|" "$(ui_alert_title)|$("$PB" "agentvm_key_remove_$UUID" get)"
select_key "$API" claude

section "Store that fails, and Store with nothing to store into"
printf 'the login Keychain is locked\n' > "$FAKE_AGENTVM_DIR/fail-secret-set"
type_key "$TYPED"
alerts_reset
omc_run AgentVM.keys.store
check "agent-vm's refusal is shown, in its words" "Could not store $API|the login Keychain is locked" "$(ui_alert_title)|$(ui_alert_message)"
check "  and the typed key is in none of it" "0" "$(leaks)"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-secret-set"
select_key - opencode
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.store
check "the agent that needs no key selected: nothing is stored" "" "$(fake_log)"
"$PB" "agentvm_key_$UUID" set "--help"
"$PB" "agentvm_keyagent_$UUID" set "claude"
omc_run AgentVM.keys.store
check "a name put on the pasteboard from outside is not passed on" "" "$(fake_log)"
"$PB" "agentvm_key_$UUID" set ""
"$PB" "agentvm_keyagent_$UUID" set ""

section "no handler of the window hands the field's value on"
type_key "$TYPED"
/bin/rm -f "$FAKE_AGENTVM_DIR/inherited"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.activated
select_key "$API" claude
omc_run AgentVM.keys.remove
omc_run AgentVM.keys.remove.confirmed
check "agent-vm ran, with other window values perhaps, never with the field's" "yes|" \
    "$([ -n "$(fake_log)" ] && echo yes)|$(inherited | /usr/bin/tr ' ' '\n' | /usr/bin/grep "_${KEYS_FIELD_ID}_")"
check "  and the typed key is nowhere" "0" "$(leaks)"
type_key ""

# -----------------------------------------------------------------------------------------------
section "Remove..."
fake_reset
printf '%s' "$TYPED" > "$FAKE_AGENTVM_DIR/secret-value-$API"
open_window
select_key "$TOKEN" claude
alerts_reset
omc_run AgentVM.keys.remove
check "a key that is not stored: no question" "|" "$(ui_alert_title)|$("$PB" "agentvm_key_remove_$UUID" get)"
select_key "$API" claude
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.remove
check "a stored key: the question, and nothing removed yet" "Remove $API?|$API|$TYPED|" \
    "$(ui_alert_title)|$("$PB" "agentvm_key_remove_$UUID" get)|$(stored "$API")|$(fake_log)"
check "  Remove in it runs the confirmation, Cancel nothing" "AgentVM.keys.remove.confirmed|" "$(ui_alert_action Remove)|$(ui_alert_action Cancel)"
select_key OPENAI_API_KEY codex
omc_run AgentVM.keys.remove.confirmed
check "confirmed: the key asked about is removed, whatever is selected by then" "(none)|secret delete $API|connect agents --json" \
    "$(stored "$API")|$(fake_log | /usr/bin/paste -sd '|' -)"
check "  the row says so, and the window too" "Not stored|Removed $API from your login Keychain." \
    "$(ui_rows "$KEYS_TABLE_ID" | /usr/bin/sed -n '2p' | col 3)|$(ui_value "$KEYS_NOTE_ID")"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.remove.confirmed
check "a second confirmation removes nothing" "" "$(fake_log)"
"$PB" "agentvm_key_remove_$UUID" set "--help"
omc_run AgentVM.keys.remove.confirmed
check "a pending name agent-vm would read as an option is not passed on" "" "$(fake_log)"
printf 'made-up' > "$FAKE_AGENTVM_DIR/secret-value-SOME_OTHER_TOKEN"
"$PB" "agentvm_key_remove_$UUID" set "SOME_OTHER_TOKEN"
omc_run AgentVM.keys.remove.confirmed
check "nor is a pending name agent-vm did not list: that key stays" "|made-up" "$(fake_log)|$(stored SOME_OTHER_TOKEN)"
/bin/rm -f "$FAKE_AGENTVM_DIR/secret-value-SOME_OTHER_TOKEN"
printf '%s' "$TYPED" > "$FAKE_AGENTVM_DIR/secret-value-$API"
omc_run AgentVM.keys.activated
select_key "$API" claude
omc_run AgentVM.keys.remove
printf 'the login Keychain is locked\n' > "$FAKE_AGENTVM_DIR/fail-secret-delete"
alerts_reset
omc_run AgentVM.keys.remove.confirmed
check "a refusal is shown, and the key stays" "$API was not removed|the login Keychain is locked|$TYPED" \
    "$(ui_alert_title)|$(ui_alert_message)|$(stored "$API")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-secret-delete"

# -----------------------------------------------------------------------------------------------
section "a key another agent-vm stored, and reading again"
fake_reset
agents '(.[] | select(.id == "claude") | .secrets[0].state) = "asks"'
open_window
check "the row says macOS asks" "Stored, macOS asks" "$(ui_rows "$KEYS_TABLE_ID" | /usr/bin/sed -n '1p' | col 3)"
select_key "$TOKEN" claude
check "the window says why, and what to do; it can be stored again, or removed" "1|11" \
    "$(ui_value "$KEYS_HINT_ID" | /usr/bin/grep -c '^Stored by another copy of agent-vm, so macOS asks before this one reads it: answer Always Allow then, or store the key again here\.')|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")"
agents '.'
printf '%s' "$TYPED" > "$FAKE_AGENTVM_DIR/secret-value-$TOKEN"
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.keys.activated
check "the window comes to the front: the keys are read again" "connect agents --json|Stored" \
    "$(fake_log)|$(ui_rows "$KEYS_TABLE_ID" | /usr/bin/sed -n '1p' | col 3)"
check "  and the key selected stays selected, by its row" "$TOKEN|1" \
    "$("$PB" "agentvm_key_$UUID" get)|$(ui_calls "^${UUID}${TAB}${KEYS_TABLE_ID}${TAB}omc_select_row 0")"
agents 'map(select(.id != "claude"))'
omc_run AgentVM.keys.activated
check "a key that is no longer listed is no longer selected" "|Select a key to store or remove it.|00" \
    "$("$PB" "agentvm_key_$UUID" get)|$(ui_value "$KEYS_TITLE_ID")|$(enabled "$KEYS_STORE_ID")$(enabled "$KEYS_REMOVE_ID")"

section "agent-vm that cannot list, or cannot be used"
printf 'the agents file is not valid JSON\n' > "$FAKE_AGENTVM_DIR/fail-connect"
omc_run AgentVM.keys.activated
check "a failed list: no rows, and agent-vm's words" "0|agent-vm could not list the agents: the agents file is not valid JSON" \
    "$(ui_row_count "$KEYS_TABLE_ID")|$(ui_value "$KEYS_NOTE_ID")"
/bin/rm -f "$FAKE_AGENTVM_DIR/fail-connect"
in_window "$UUID"
omc_run AgentVM.keys.close
( AGENTVM_APP_AGENT_VM="$OMCTEST_WORK/no-such-agent-vm"; export AGENTVM_APP_AGENT_VM
  open_window
  printf '%s|%s\n' "$(ui_row_count "$KEYS_TABLE_ID")" "$([ -n "$(ui_value "$KEYS_NOTE_ID")" ] && echo said)" > "$OMCTEST_WORK/unusable" )
check "no agent-vm: no rows, and the window says why" "0|said" "$(/bin/cat "$OMCTEST_WORK/unusable")"
in_window "$UUID"
omc_run AgentVM.keys.close

section "handlers of a window that is not the Agent Keys window"
in_window "$OTHER_UUID"
ui_reset
type_key "$TYPED"
: > "$FAKE_AGENTVM_DIR/log"
for handler in activated selected store remove remove.confirmed; do
    omc_run "AgentVM.keys.$handler"
done
check "do nothing" "|0" "$(fake_log)|$(ui_calls "^$OTHER_UUID")"
in_window "$MAIN_UUID"

check "no harness errors"            "" "$(ui_errors)"

omctest_end
