#!/bin/sh
# Tests/00-bundle.test.sh - what the bundle declares: where it runs, what it is called, the URL
# scheme it answers, and the main command's window.
#
# These are decisions that live in Info.plist and Command.json rather than in a script, so they
# are asserted there. The minimum macOS matters more than it looks: the app has no "cannot run"
# face, because macOS itself refuses to open it where agent-vm's boxes cannot run.
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

section "Info.plist"
check "the bundle identifier"                  "com.abracode.AgentVM" "$(plist_value CFBundleIdentifier)"
check "the name"                               "AgentVM"              "$(plist_value CFBundleName)"
check "macOS 27 or later, as agent-vm needs"   "27.0"                 "$(plist_value LSMinimumSystemVersion)"
check "the agentvm URL scheme is declared"     "1" \
    "$(/usr/bin/plutil -extract CFBundleURLTypes json -o - "$APP_INFO_PLIST" 2>/dev/null \
        | /usr/bin/jq '[.[].CFBundleURLSchemes[]] | map(select(. == "agentvm")) | length')"
# The template declares a viewer role for every file, which would list AgentVM under Open With
# for all of them. The app opens no documents.
check "no document types"                      "" \
    "$(/usr/bin/plutil -extract CFBundleDocumentTypes json -o - "$APP_INFO_PLIST" 2>/dev/null)"

section "Command.json"
check "one command so far, the main one"       "1"       "$(command_value '.COMMAND_LIST | length')"
check "its name, which names the scripts"      "AgentVM" "$(command_value '.COMMAND_LIST[0].NAME')"
check "its window is AgentVM.json"             "AgentVM" "$(command_value '.COMMAND_LIST[0].ACTIONUI_WINDOW.JSON_NAME')"
check_exists "and that file exists"            "$APP_RESOURCES/Base.lproj/AgentVM.json"
check "the window does not block the app"      "false"   "$(command_value '.COMMAND_LIST[0].ACTIONUI_WINDOW.IS_BLOCKING')"
check "the engine is told macOS 27 as well"    "27.0"    "$(command_value '.COMMAND_LIST[0].REQUIRED_MAC_OS_MIN_VERSION')"

section "the main command"
omc_run AgentVM.main
check_status "does nothing and exits cleanly" 0
check "writes nothing to the window" "0" "$(ui_calls '.')"

omctest_end
