#!/bin/sh
# Tests/81-install.test.sh - the Install agent-vm window: the two buttons that open it, one
# window at a time and only when this run of the app asked for it, what it says for an agent-vm
# that is missing, too old, behind the newest release or the newest, and Download and Install:
# the newest release found, its package downloaded, its signature and its parts checked, the
# installation, the check afterwards, and everything that stops it before anything is
# installed.
#
# Nothing reaches the network, Gatekeeper or the real installer: curl, spctl, pkgutil and
# installer are helpers/fake_install_tools.sh, under those names. No agent-vm is set by the test
# seam, so the app looks for the installed one, in this file's own home folder, where the fake
# installer puts helpers/fake_agent_vm.sh.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.install.sh"
STAGE_BUTTON="$(/usr/bin/sed -n 's/^MAIN_STAGE_BUTTON_BASE=\([0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.main.sh")"
STAGE_SYMBOL="$(/usr/bin/sed -n 's/^MAIN_STAGE_SYMBOL_BASE=\([0-9]*\)$/\1/p' "$APP_SCRIPTS/lib.agentvm.main.sh")"
[ -n "$INSTALL_HEAD_ID" ] && [ -n "$INSTALL_BUTTON_ID" ] && [ -n "$INSTALL_PATH_ID" ] && [ -n "$STAGE_BUTTON" ] && [ -n "$STAGE_SYMBOL" ] || {
    printf '81-install: no view ids imported from the libraries\n' >&2
    exit 1
}
MIN_VERSION="$(lib_value AGENTVM_MIN_VERSION)"

TOOLS="$OMCTEST_WORK/tools"
/bin/mkdir -p "$TOOLS"
for tool in curl spctl pkgutil installer; do
    /bin/ln -s "$TEST_HELPERS/fake_install_tools.sh" "$TOOLS/$tool"
done
FAKE_INSTALL_DIR="$OMCTEST_WORK/fakeinstall"
AGENTVM_APP_CURL="$TOOLS/curl"
AGENTVM_APP_SPCTL="$TOOLS/spctl"
AGENTVM_APP_PKGUTIL="$TOOLS/pkgutil"
AGENTVM_APP_INSTALLER="$TOOLS/installer"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
export FAKE_INSTALL_DIR AGENTVM_APP_CURL AGENTVM_APP_SPCTL AGENTVM_APP_PKGUTIL AGENTVM_APP_INSTALLER
export AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG FAKE_AGENTVM
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?81-install: OMC_APP_PROCESS_ID is not set}"
UUID="OMCTEST-install-$$"
OTHER_UUID="OMCTEST-other-install-$$"
LINK="$HOME/.local/bin/agent-vm"
RELEASES="https://github.com/abra-code/agent-vm/releases"
AGENTVM_CHOICE="com_abracode_pkg_agent_vm_choice"
PATH_CHOICE="com_abracode_pkg_agent_vm_path_choice"

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

request() {
    "$PB" agentvm_open_request_install get
}

# tools_reset  ->  the fake tools with their defaults and an empty log.
tools_reset() {
    /bin/rm -rf "$FAKE_INSTALL_DIR"
    /bin/mkdir -p "$FAKE_INSTALL_DIR"
}
tools_log() {
    /bin/cat "$FAKE_INSTALL_DIR/log" 2>/dev/null
}

# nothing_installed  ->  a home folder with no agent-vm. installed_old <version>  ->  one whose
# agent-vm only reports that version.
nothing_installed() {
    /bin/rm -rf "$HOME/.local"
}
installed_old() {
    nothing_installed
    /bin/mkdir -p "$HOME/.local/share/agent-vm/versions/$1" "$HOME/.local/bin"
    printf '#!/bin/sh\necho %s\n' "$1" > "$HOME/.local/share/agent-vm/versions/$1/agent-vm"
    /bin/chmod +x "$HOME/.local/share/agent-vm/versions/$1/agent-vm"
    /bin/ln -s "../share/agent-vm/versions/$1/agent-vm" "$LINK"
}

# open_main  ->  the main window, opened anew. open_window [uuid]  ->  the install window opened
# the way its buttons open it: the request, then its init handler, in a window of its own.
open_main() {
    in_window "$MAIN_UUID"
    ui_reset
    chains_reset
    /bin/rm -rf "$TMPDIR/AgentVM/$MAIN_UUID"
    omc_control_defaults AgentVM
    omc_run AgentVM.main.init
}
open_window() {
    "$PB" agentvm_open_request_install set "$APP_PID install:window"
    in_window "${1:-$UUID}"
    ui_reset
    omc_control_defaults AgentVM.install
    omc_run AgentVM.install.init
}
close_window() {
    in_window "${1:-$UUID}"
    omc_run AgentVM.install.close
}

# start  ->  a click on Download and Install. head, status, note  ->  the window's three lines.
# button  ->  1 when Download and Install is on.
start() {
    in_window "$UUID"
    omc_trigger "$INSTALL_BUTTON_ID"
    omc_run AgentVM.install.start
}
head() { ui_value "$INSTALL_HEAD_ID"; }
status() { ui_value "$INSTALL_STATUS_ID"; }
note() { ui_value "$INSTALL_NOTE_ID"; }
button() { ui_enabled "$INSTALL_BUTTON_ID"; }

# installs  ->  how many times installer was asked to install (not to list or confirm parts).
installs() {
    tools_log | /usr/bin/grep -c '^package-present '
}
# leftovers  ->  the temporary folders a download left behind.
leftovers() {
    /bin/ls -d "$TMPDIR"/AgentVM-install.* 2>/dev/null | /usr/bin/wc -l | /usr/bin/tr -d ' '
}

fake_reset
tools_reset
nothing_installed
"$PB" agentvm_window_install_window set ""
"$PB" agentvm_open_request_install set ""

# -----------------------------------------------------------------------------------------------
section "the buttons that open it"
open_main
check "no agent-vm: the first step failed, and its button is on, as Install..." "xmark.circle.fill|1|Install..." \
    "$(ui_prop $((STAGE_SYMBOL + 1)) systemName)|$(ui_enabled $((STAGE_BUTTON + 1)))|$(ui_prop $((STAGE_BUTTON + 1)) title)"
omc_trigger "$((STAGE_BUTTON + 1))"
omc_run AgentVM.install.open
check "the button asks for the window, with a request of this run, and asks GitHub nothing" \
    "1|$APP_PID install:window|" "$(chain_asked AgentVM.install)|$(request)|$(tools_log)"
check "both buttons run that handler" "AgentVM.install.open|AgentVM.install.open|Check for Updates...|null" \
    "$(/usr/bin/jq -r --argjson stage "$((STAGE_BUTTON + 1))" '[.. | objects | select(.id? == $stage or .id? == 503)] | sort_by(.id) | "\(.[0].properties.actionID)|\(.[1].properties.actionID)|\(.[1].properties.title)|\(.[1].properties.disabled)"' "$APP_RESOURCES/Base.lproj/AgentVM.json")"
"$PB" agentvm_open_request_install set ""
installed_old 0.5.0
open_main
check "an agent-vm too old for the app: the button is on, as Update..." "1|Update..." \
    "$(ui_enabled $((STAGE_BUTTON + 1)))|$(ui_prop $((STAGE_BUTTON + 1)) title)"
nothing_installed

section "the window opens: no agent-vm"
open_main
open_window
check_status "the init handler exits cleanly" 0
check "takes the request, once, and is the one such window" "|$UUID" "$(request)|$("$PB" agentvm_window_install_window get | /usr/bin/cut -d' ' -f2)"
check "GitHub is asked once where its newest release is, and nothing else runs" "1|1" \
    "$(tools_log | /usr/bin/grep -c "^curl .*--head .*$RELEASES/latest\$")|$(tools_log | /usr/bin/awk 'END { print NR }')"
check "what would be installed, and that nothing is" "agent-vm 0.6.12 is the newest. agent-vm is not installed.||" "$(head)|$(status)|$(note)"
check "Download and Install is on, the checkbox ticked and on, the bar hidden" "1|true|1|0" \
    "$(button)|$(ui_value "$INSTALL_PATH_ID")|$(ui_enabled "$INSTALL_PATH_ID")|$(ui_visible "$INSTALL_BAR_ID")"
check "the title"                    "Install agent-vm" "$(command_value '.COMMAND_LIST[] | select(.COMMAND_ID == "AgentVM.install") | .ACTIONUI_WINDOW.WINDOW_TITLE')"

section "Download and Install"
tools_reset
printf '0.6.12\n' > "$FAKE_INSTALL_DIR/installs"
omc_control "$INSTALL_PATH_ID" "true"
start
check_status "the handler exits cleanly" 0
check "the steps, in order: the newest release, the download, the signature, the parts, the installation" \
    "curl|curl|spctl|pkgutil|installer -showChoiceChangesXML|installer -showChoicesAfterApplyingChangesXML|installer -pkg" \
    "$(tools_log | /usr/bin/grep -v '^choice \|^package-present ' | /usr/bin/awk '{ printf "%s%s", (NR > 1 ? "|" : ""), ($1 == "installer" ? $1 " " $2 : $1) }')"
check "the package comes from the release of that version, over https only" "1" \
    "$(tools_log | /usr/bin/grep -c "^curl .*--proto =https --proto-redir =https .*--output .*/agent-vm_0.6.12.pkg $RELEASES/download/0.6.12/agent-vm_0.6.12.pkg\$")"
check "it is installed for this user only, with the parts chosen, and was there while installed" \
    "1|package-present yes|choice $AGENTVM_CHOICE 1|choice $PATH_CHOICE 1" \
    "$(tools_log | /usr/bin/grep -c '^installer -pkg .* -target CurrentUserHomeDirectory -applyChoiceChangesXML .*/choices.plist -verboseR$')|$(tools_log | /usr/bin/grep '^package-present \|^choice ' | /usr/bin/paste -sd '|' -)"
check "the window says so, and there is nothing more to install" \
    "agent-vm 0.6.12 is installed, and it is the newest.|Installed. Open a new Terminal window for avm and agent-vm to be found there.|0|0" \
    "$(head)|$(status)|$(button)|$(ui_visible "$INSTALL_BAR_ID")"
check "the installed agent-vm is the release" "0.6.12" "$("$LINK" --version)"
check "the download is gone"         "0" "$(leftovers)"
# The first question is the check after installing; the next three are the main window's.
check "the main window read the new agent-vm at once: its version, doctor and the lists" "--version|--version|doctor --json|status --json" \
    "$(fake_log | /usr/bin/sed -n '1,4p' | /usr/bin/paste -sd '|' -)"
tools_reset
start
check "the button is off now; a click that gets through anyway installs the same release again" "1" "$(installs)"
close_window

section "an agent-vm that is installed"
tools_reset
open_window
check "the newest: nothing to install" "agent-vm 0.6.12 is installed, and it is the newest.|0|Boxes that are running keep the agent-vm they were started with until they are stopped." "$(head)|$(button)|$(note)"
close_window
printf '0.7.0\n' > "$FAKE_INSTALL_DIR/newest"
open_window
check "a newer release: it is offered" "agent-vm 0.7.0 is available. agent-vm 0.6.12 is installed.|1" "$(head)|$(button)"
printf '0.7.0\n' > "$FAKE_INSTALL_DIR/installs"
omc_control "$INSTALL_PATH_ID" "false"
start
check "updated, with the PATH part left out as the checkbox says" "agent-vm 0.7.0 is installed, and it is the newest.|Installed.|choice $AGENTVM_CHOICE 1|choice $PATH_CHOICE 0|0.7.0" \
    "$(head)|$(status)|$(tools_log | /usr/bin/grep '^choice ' | /usr/bin/paste -sd '|' -)|$("$LINK" --version)"
close_window
tools_reset
printf '0.5.0\n' > "$FAKE_INSTALL_DIR/newest"
open_window
check "a newest release older than the app needs is not offered" \
    "agent-vm 0.7.0 is installed.|The newest agent-vm release is 0.5.0, and this AgentVM needs $MIN_VERSION or newer. It is not released yet: see $RELEASES.|0" "$(head)|$(status)|$(button)"
close_window

# -----------------------------------------------------------------------------------------------
section "GitHub cannot be asked"
nothing_installed
tools_reset
printf 'curl: (6) Could not resolve host: github.com\n' > "$FAKE_INSTALL_DIR/curl-fail"
open_window
check "the window says why, and the button stays: a click asks again" \
    "agent-vm is not installed.|GitHub could not be asked for the newest agent-vm: curl: (6) Could not resolve host: github.com|1" "$(head)|$(status)|$(button)"
start
check "a click with no network: the same, and nothing is downloaded or installed" \
    "GitHub could not be asked for the newest agent-vm: curl: (6) Could not resolve host: github.com|1|0|0" "$(status)|$(button)|$(installs)|$(leftovers)"
/bin/rm -f "$FAKE_INSTALL_DIR/curl-fail"
printf '%s' "$RELEASES" > "$FAKE_INSTALL_DIR/latest-url"
start
check "no release at all"            "GitHub names no newest agent-vm release (see $RELEASES).|0" "$(status)|$(installs)"
printf '%s/tag/v1;rm -rf x' "$RELEASES" > "$FAKE_INSTALL_DIR/latest-url"
start
check "a tag that is not a version never reaches an address or a file name" "The newest agent-vm release has a tag that is not a version (see $RELEASES).|0" \
    "$(status)|$(tools_log | /usr/bin/grep -c '/download/')"
/bin/rm -f "$FAKE_INSTALL_DIR/latest-url"

section "what stops it before anything is installed"
# refused <what the test changes>  ->  a click, and: the status line, whether the button is on
# again, how many installations ran, the temporary folders left.
refused() {
    start
    printf '%s|%s|%s|%s\n' "$(status)" "$(button)" "$(installs)" "$(leftovers)"
}
tools_reset
printf '0.5.0\n' > "$FAKE_INSTALL_DIR/newest"
check "a newest release older than the app needs" \
    "The newest agent-vm release is 0.5.0, and this AgentVM needs $MIN_VERSION or newer, so it was not installed.|1|0|0" "$(refused)"
tools_reset
printf 'curl: (22) The requested URL returned error: 404\n' > "$FAKE_INSTALL_DIR/download-fail"
check "a download that fails" "Could not download agent-vm_0.6.12.pkg: curl: (22) The requested URL returned error: 404|1|0|0" "$(refused)"
tools_reset
printf '0\n' > "$FAKE_INSTALL_DIR/package-bytes"
check "a download that leaves nothing" "The download of agent-vm_0.6.12.pkg left no file.|1|0|0" "$(refused)"
tools_reset
printf 'agent-vm_0.6.12.pkg: rejected\nsource=no usable signature\n' > "$FAKE_INSTALL_DIR/spctl.out"
printf '3\n' > "$FAKE_INSTALL_DIR/spctl-status"
check "a package Gatekeeper rejects" \
    "agent-vm_0.6.12.pkg is not notarized Developer ID software, so it was not installed (agent-vm_0.6.12.pkg: rejected source=no usable signature).|1|0|0" "$(refused)"
tools_reset
printf 'agent-vm_0.6.12.pkg: accepted\nsource=Developer ID\n' > "$FAKE_INSTALL_DIR/spctl.out"
check "a package that is signed and not notarized" \
    "agent-vm_0.6.12.pkg is not notarized Developer ID software, so it was not installed (agent-vm_0.6.12.pkg: accepted source=Developer ID).|1|0|0" "$(refused)"
tools_reset
printf '   Certificate Chain:\n    1. Developer ID Installer: Somebody Else (ABCDE12345)\n    2. Developer ID Certification Authority\n' > "$FAKE_INSTALL_DIR/pkgutil.out"
check "a notarized package of another team" \
    "agent-vm_0.6.12.pkg is signed by the Developer ID team ABCDE12345, not agent-vm's (T9NM2ZLDTY), so it was not installed.|1|0|0" "$(refused)"
tools_reset
printf '   Certificate Chain:\n    1. Apple Development: Somebody (T9NM2ZLDTY)\n    2. Developer ID Installer: Tomasz Kukielka (T9NM2ZLDTY)\n' > "$FAKE_INSTALL_DIR/pkgutil.out"
check "the team is read from the first certificate only, and that must be a Developer ID Installer one" \
    "agent-vm_0.6.12.pkg is not signed with a Developer ID Installer certificate, so it was not installed.|1|0|0" "$(refused)"
tools_reset
printf '5\n' > "$FAKE_INSTALL_DIR/parts-status"
check "a package whose parts installer cannot list" \
    "installer could not list the parts of agent-vm_0.6.12.pkg: installer: Error trying to locate CurrentUserHomeDirectory domain|1|0|0" "$(refused)"
tools_reset
printf '%s\n' "$PATH_CHOICE" > "$FAKE_INSTALL_DIR/parts"
check "a package with no agent-vm part" \
    "agent-vm_0.6.12.pkg has no agent-vm part, so AgentVM cannot tell what it would install. See $RELEASES.|1|0|0" "$(refused)"
tools_reset
printf '%s\n%s\ncom_example_extra_choice\n' "$AGENTVM_CHOICE" "$PATH_CHOICE" > "$FAKE_INSTALL_DIR/parts"
printf 'com_example_extra_choice\n' > "$FAKE_INSTALL_DIR/sticky"
check "a part the app does not know that cannot be left out" \
    "agent-vm_0.6.12.pkg does not let AgentVM install only the parts chosen (com_example_extra_choice), so nothing was installed. See $RELEASES.|1|0|0" "$(refused)"
tools_reset
printf '%s\n' "$PATH_CHOICE" > "$FAKE_INSTALL_DIR/sticky"
omc_control "$INSTALL_PATH_ID" "false"
check "the PATH part selected though the checkbox is not ticked" \
    "agent-vm_0.6.12.pkg does not let AgentVM install only the parts chosen ($PATH_CHOICE), so nothing was installed. See $RELEASES.|1|0|0" "$(refused)"
tools_reset
printf '3\n' > "$FAKE_INSTALL_DIR/spctl-status"
check "a package spctl ends badly on, whatever it prints" \
    "agent-vm_0.6.12.pkg is not notarized Developer ID software, so it was not installed|1|0|0" "$(refused | /usr/bin/sed 's/ (.*source=Notarized Developer ID)\.|1|0|0$/|1|0|0/')"
tools_reset
printf '1\n' > "$FAKE_INSTALL_DIR/pkgutil-status"
check "a package whose signature pkgutil cannot check, whatever it prints" \
    "The signature of agent-vm_0.6.12.pkg could not be checked, so it was not installed|1|0|0" "$(refused | /usr/bin/sed 's/: Package .*|1|0|0$/|1|0|0/')"
tools_reset
printf 'installer: a line that is no property list\n' > "$FAKE_INSTALL_DIR/confirm-banner"
check "an answer about the parts that cannot be read confirms nothing" \
    "installer's answer about the parts of agent-vm_0.6.12.pkg could not be read, so nothing was installed.|1|0|0" "$(refused)"
tools_reset
printf '%s\n%s\ncom_example_extra_choice\n' "$AGENTVM_CHOICE" "$PATH_CHOICE" > "$FAKE_INSTALL_DIR/parts"
printf 'com_example_extra_choice\n' > "$FAKE_INSTALL_DIR/sticky"
printf '%s\n' -1 > "$FAKE_INSTALL_DIR/sticky-setting"
check "a part selected in part (-1) counts as selected" \
    "agent-vm_0.6.12.pkg does not let AgentVM install only the parts chosen (com_example_extra_choice), so nothing was installed. See $RELEASES.|1|0|0" "$(refused)"
check "nothing was installed by any of these" "no" "$([ -e "$LINK" ] && echo yes || echo no)"

section "a part the app does not know is left out"
tools_reset
printf '%s\n%s\ncom_example_extra_choice\n' "$AGENTVM_CHOICE" "$PATH_CHOICE" > "$FAKE_INSTALL_DIR/parts"
printf '0.6.12\n' > "$FAKE_INSTALL_DIR/installs"
start
check "installed, with that part and the unticked PATH part off" "Installed.|choice com_abracode_pkg_agent_vm_choice 1|choice com_abracode_pkg_agent_vm_path_choice 0|choice com_example_extra_choice 0" \
    "$(status)|$(tools_log | /usr/bin/grep '^choice ' | /usr/bin/sort | /usr/bin/paste -sd '|' -)"
close_window

section "an installation that fails"
nothing_installed
tools_reset
open_window
printf '1\n' > "$FAKE_INSTALL_DIR/installer-status"
start
check "installer's own words, where to look, and the button on again" \
    "Could not install agent-vm_0.6.12.pkg: installer: Error - The Installer encountered an error that caused the installation to fail. (/var/log/install.log has the details).|1|0|0" \
    "$(status)|$(button)|$(ui_visible "$INSTALL_BAR_ID")|$(leftovers)"
tools_reset
start
check "an installation that reports success and installs nothing" \
    "The installation ended, and agent-vm 0.6.12 is not installed: there is no agent-vm at ~/.local/bin/agent-vm (/var/log/install.log has the details).|1" "$(status)|$(button)"
installed_old 0.6.1
tools_reset
start
check "one that leaves the old agent-vm in place" \
    "The installation ended, and agent-vm 0.6.12 is not installed: ~/.local/bin/agent-vm reports 0.6.1 (/var/log/install.log has the details).|1" "$(status)|$(button)"
nothing_installed
tools_reset
printf '30\n' > "$FAKE_INSTALL_DIR/installer-sleep"
AGENTVM_APP_INSTALL_TIMEOUT=1
export AGENTVM_APP_INSTALL_TIMEOUT
start
check "one that does not finish is stopped" \
    "Installing agent-vm_0.6.12.pkg did not finish within 0 minutes, and AgentVM stopped waiting for it. /var/log/install.log shows what installer was waiting for; try again once that has ended.|1|0" "$(status)|$(button)|$(leftovers)"
unset AGENTVM_APP_INSTALL_TIMEOUT
close_window

# -----------------------------------------------------------------------------------------------
section "one click at a time, and a window that closes"
nothing_installed
tools_reset
open_window
tools_reset
"$PB" "agentvm_busy_$UUID" set "click-$$"
start
check "a click while another one is worked on does nothing" "" "$(tools_log)"
"$PB" "agentvm_busy_$UUID" set "click-999999"
printf '0.6.12\n' > "$FAKE_INSTALL_DIR/installs"
start
check "a click whose holder is gone is taken" "1|" "$(installs)|$("$PB" "agentvm_busy_$UUID" get)"
close_window
nothing_installed
open_window
tools_reset
printf '3\n' > "$FAKE_INSTALL_DIR/download-sleep"
printf '0.6.12\n' > "$FAKE_INSTALL_DIR/installs"
start &
start_pid=$!
/bin/sleep 1
close_window
wait "$start_pid"
check "a window closed during the download: the package is downloaded, nothing is installed, and the download goes" "1|0|0|no" \
    "$(tools_log | /usr/bin/grep -c '/download/')|$(installs)|$(leftovers)|$([ -e "$LINK" ] && echo yes || echo no)"
open_window
close_window
tools_reset
start
check "a click in a window that has closed does nothing" "" "$(tools_log)"
check "closing forgets the window"   "|" "$("$PB" agentvm_window_install_window get)|$("$PB" "agentvm_install_$UUID" get)"

section "one installation at a time, whichever window started it"
nothing_installed
tools_reset
open_window
tools_reset
"$PB" agentvm_install_running set "$$"
start
check "while another handler installs, a click says so and does nothing" \
    "agent-vm is being installed already. Wait for that to end, then look again.|1|" "$(status)|$(button)|$(tools_log)"
"$PB" agentvm_install_running set "999999"
printf '0.7.0\n' > "$FAKE_INSTALL_DIR/installs"
printf '0.7.0\n' > "$FAKE_INSTALL_DIR/newest"
start
check "an installing handler that is gone holds nothing, and the mark goes when installing ends" "Installed.|" "$(status | /usr/bin/cut -c1-10)|$("$PB" agentvm_install_running get)"
/bin/rm -f "$FAKE_INSTALL_DIR/newest"
close_window
open_window
check "an installed agent-vm newer than the newest release: said, and nothing to install" \
    "agent-vm 0.7.0 is installed, which is newer than the newest release, 0.6.12.|0" "$(head)|$(button)"
close_window

section "only one window, and only when this run asked"
tools_reset
open_window
open_window "$OTHER_UUID"
check "a second one closes, and the first comes to the front" "1|1|$UUID" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(ui_calls "${UUID}${TAB}omc_window${TAB}omc_select")|$("$PB" agentvm_window_install_window get | /usr/bin/cut -d' ' -f2)"
close_window "$OTHER_UUID"
check "  closing the second leaves the first registered" "$UUID" "$("$PB" agentvm_window_install_window get | /usr/bin/cut -d' ' -f2)"
close_window
tools_reset
in_window "$OTHER_UUID"
ui_reset
omc_run AgentVM.install.init
check "a window nobody asked for closes, and asks GitHub nothing" "1|" \
    "$(ui_calls "${OTHER_UUID}${TAB}omc_window${TAB}omc_terminate_cancel")|$(tools_log)"
"$PB" agentvm_open_request_install set "1 install:window"
omc_run AgentVM.install.init
check "nor one another run of the app asked for" "" "$(tools_log)"

section "nothing went wrong in the harness"
check "no write to a view no window has" "" "$(ui_unknown_writes)"
check "no harness errors"            "" "$(ui_errors)"

omctest_end
