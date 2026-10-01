#!/bin/sh
# Tests/91-no-window.test.sh - a handler run without its window does nothing.
#
# The engine lets a URL run any command of the app by name (agentvm://exe?commandID=<id>&text=...),
# and offers no way to turn that off. A command started that way gets no window: not even the key
# window's. So the rule for every handler is that it needs its window's uuid before it reads,
# changes, asks or opens anything, and this file runs each one without a window, in the state
# where it would do the most harm: the main window open on a stopped box with Delete and Recreate
# already asked, a network window with edits waiting and an Allow already asked, a job that
# runs, whose Stop was already asked, and an image's update with its parts ticked. The same state is
# then planted under the empty uuid (the pasteboard keys and the cache folder a handler without
# its guard would compute), so that a handler missing the guard acts, and is seen, rather than
# finding nothing to act on.
#
# The one handler meant to run without a window is omc.app.handle-url, which only shows
# (90-url-scheme.test.sh). A window command run by name opens a window that closes itself
# (32-box-network.test.sh, 33-box-programs.test.sh, 54-progress-window.test.sh,
# 55-update-window.test.sh).
#
# POSIX sh only. Validate with "sh -n", never "bash -n".
. "${OMCTEST_LIB:?set OMCTEST_LIB, or run via: appletbuilder test}"
. "$OMCTEST_TESTS/lib.test.agentvm.sh"

import_view_ids "$APP_SCRIPTS/lib.agentvm.main.sh" "$APP_SCRIPTS/lib.agentvm.network.sh"
[ -n "$MAIN_BOXES_ID" ] && [ -n "$MAIN_IMAGES_ID" ] && [ -n "$NET_PACKS_ID" ] && [ -n "$NET_CONNECTIONS_ID" ] || {
    printf '91-no-window: no view ids imported from the libraries\n' >&2
    exit 1
}

AGENTVM_APP_AGENT_VM="$FAKE_AGENTVM"
AGENTVM_APP_PS="$TEST_HELPERS/fake_ps.sh"
AGENTVM_APP_SLEEP="$TEST_HELPERS/fake_sleep.sh"
AGENTVM_APP_OPEN="$TEST_HELPERS/fake_open.sh"
FAKE_SLEEP_LOG="$OMCTEST_WORK/sleeps"
FAKE_OPEN_LOG="$OMCTEST_WORK/opened"
TZ=UTC
export AGENTVM_APP_AGENT_VM AGENTVM_APP_PS AGENTVM_APP_SLEEP AGENTVM_APP_OPEN FAKE_SLEEP_LOG FAKE_OPEN_LOG TZ
PB="$OMC_OMC_SUPPORT_PATH/pasteboard"
MAIN_UUID="$OMC_ACTIONUI_WINDOW_UUID"
APP_PID="${OMC_APP_PROCESS_ID:?91-no-window: OMC_APP_PROCESS_ID is not set}"
NET_UUID="OMCTEST-network-window-$$"
BOX=cadabra-spike
# A job that runs, holding the box: what Progress... would open a window for, and Stop would cancel.
JOB=20260930-120000-0000d1

in_window() {
    OMC_ACTIONUI_WINDOW_UUID="$1"
    ACTIONUI_WINDOW_UUID="$1"
    export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID
}

# handlers  ->  the stem of every handler script but the URL handler.
handlers() {
    local _file
    for _file in "$APP_SCRIPTS"/*.sh; do
        _file="${_file##*/}"
        case "$_file" in
            lib.*|omc.app.handle-url.sh) ;;
            *) printf '%s\n' "${_file%.sh}" ;;
        esac
    done
}

# state  ->  everything a handler could have touched, as one text: what agent-vm was asked, what
# Finder or Terminal was asked to open, the files written for Terminal, the windows' recorded
# calls, the commands chained, the alerts, and the pending questions and edits.
state() {
    printf 'agent-vm: %s\n' "$(fake_log | /usr/bin/awk 'END { print NR }')"
    printf 'opened: %s\n' "$(/usr/bin/awk 'END { print NR }' "$FAKE_OPEN_LOG")"
    printf 'terminal files: %s\n' "$(/bin/ls "$HOME/Library/Application Support/AgentVM/Terminal" 2>/dev/null | /usr/bin/awk 'END { print NR }')"
    printf 'window calls: %s\n' "$(ui_calls '.')"
    printf 'chained: %s %s %s %s %s %s\n' "$(chain_asked AgentVM.main)" "$(chain_asked AgentVM.network)" "$(chain_asked AgentVM.programs)" \
        "$(chain_asked AgentVM.progress)" "$(chain_asked AgentVM.progress.poll)" "$(chain_asked AgentVM.update)"
    printf 'alert: %s\n' "$(ui_alert_title)"
    printf 'pending: %s|%s|%s|%s\n' "$("$PB" "agentvm_box_delete_$MAIN_UUID" get)" "$("$PB" "agentvm_box_recreate_$MAIN_UUID" get)" \
        "$("$PB" "agentvm_image_delete_$MAIN_UUID" get)" "$("$PB" "agentvm_net_allow_$NET_UUID" get)"
    printf 'selected: %s|%s|%s\n' "$("$PB" "agentvm_box_$MAIN_UUID" get)" "$("$PB" "agentvm_image_$MAIN_UUID" get)" "$("$PB" "agentvm_box_$NET_UUID" get)"
    printf 'edits: %s\n' "$(/bin/cat "$TMPDIR/AgentVM/$NET_UUID/net-$BOX.desired" 2>/dev/null | /usr/bin/paste -sd ' ' -)"
    printf 'requests: %s|%s|%s|%s|%s\n' "$("$PB" agentvm_open_request_network get)" "$("$PB" agentvm_open_request_programs get)" \
        "$("$PB" agentvm_open_request_progress get)" "$("$PB" agentvm_open_request_update get)" "$("$PB" agentvm_goto get)"
    printf 'jobs: %s\n' "$(/usr/bin/jq -r 'map(.id + " " + .state) | join(",")' "$FAKE_AGENTVM_DIR/jobs.json" 2>/dev/null)"
    printf 'no-window job keys: %s|%s|%s\n' "$("$PB" agentvm_job_ get)" "$("$PB" agentvm_job_stop_ get)" "$("$PB" agentvm_choices_ get)"
    printf 'no-window keys: %s|%s|%s|%s|%s|%s|%s\n' "$("$PB" agentvm_poll_ get)" "$("$PB" agentvm_box_ get)" "$("$PB" agentvm_image_ get)" \
        "$("$PB" agentvm_box_delete_ get)" "$("$PB" agentvm_box_recreate_ get)" "$("$PB" agentvm_image_delete_ get)" "$("$PB" agentvm_net_allow_ get)"
    printf 'pasteboards: %s\n' "$(/usr/bin/find "$OMCTEST_UI/pb" -type f -exec /usr/bin/cksum {} + | /usr/bin/sort | /usr/bin/cksum)"
    printf 'cache files: %s\n' "$(/usr/bin/find "$TMPDIR/AgentVM" -type f -exec /usr/bin/cksum {} + | /usr/bin/sort | /usr/bin/cksum)"
}

# without_window <handler>  ->  the handler run as a URL runs it: no window, the URL's text, and,
# to be strict, the values a window would have exported for the rows the user had selected.
without_window() {
    ( OMC_ACTIONUI_WINDOW_UUID=""; ACTIONUI_WINDOW_UUID=""; OMC_OBJ_TEXT="$BOX"
      OMC_ACTIONUI_TABLE_311_COLUMN_1_VALUE="$BOX"; OMC_ACTIONUI_TABLE_411_COLUMN_1_VALUE="dev-xcode"
      OMC_ACTIONUI_TABLE_604_COLUMN_1_VALUE="opencode.ai"; OMC_ACTIONUI_VIEW_605_VALUE="example.com"
      OMC_ACTIONUI_VIEW_601_VALUE="3"; OMC_ACTIONUI_TRIGGER_VIEW_PART_ID="0"
      OMC_ACTIONUI_TABLE_613_COLUMN_1_VALUE="registry.yarnpkg.com"; OMC_ACTIONUI_TABLE_613_COLUMN_2_VALUE="443"
      OMC_ACTIONUI_TABLE_613_COLUMN_6_VALUE="registry.yarnpkg.com"; OMC_ACTIONUI_TABLE_613_COLUMN_7_VALUE="denied"
      OMC_DLG_CHOOSE_FOLDER_PATH="$OMCTEST_WORK"; AGENTVM_APP_POLL_PASSES=1
      OMC_ACTIONUI_VIEW_811_VALUE="true"; OMC_ACTIONUI_VIEW_821_VALUE="true"; OMC_ACTIONUI_VIEW_831_VALUE="true"
      export OMC_ACTIONUI_WINDOW_UUID ACTIONUI_WINDOW_UUID OMC_OBJ_TEXT OMC_ACTIONUI_TABLE_311_COLUMN_1_VALUE \
          OMC_ACTIONUI_TABLE_411_COLUMN_1_VALUE OMC_ACTIONUI_TABLE_604_COLUMN_1_VALUE OMC_ACTIONUI_VIEW_605_VALUE \
          OMC_ACTIONUI_VIEW_601_VALUE OMC_ACTIONUI_TRIGGER_VIEW_PART_ID OMC_ACTIONUI_TABLE_613_COLUMN_1_VALUE \
          OMC_ACTIONUI_TABLE_613_COLUMN_2_VALUE OMC_ACTIONUI_TABLE_613_COLUMN_6_VALUE OMC_ACTIONUI_TABLE_613_COLUMN_7_VALUE \
          OMC_DLG_CHOOSE_FOLDER_PATH AGENTVM_APP_POLL_PASSES OMC_ACTIONUI_VIEW_811_VALUE OMC_ACTIONUI_VIEW_821_VALUE \
          OMC_ACTIONUI_VIEW_831_VALUE
      omc_run "$1" )
}

fake_reset
# The stopped box is made a kept one, so that Recreate can be asked about it too.
/usr/bin/jq '(.boxes[] | select(.box.name == "cadabra-spike")).box.disposable = false' \
    "$FIXTURES_AGENTVM/status-variety.json" > "$FAKE_AGENTVM_DIR/status.json"
: > "$FAKE_OPEN_LOG"
: > "$FAKE_SLEEP_LOG"

# -----------------------------------------------------------------------------------------------
section "the state a stray command could do the most harm in"
ui_reset
omc_control_defaults AgentVM
omc_run AgentVM.main.init
omc_table_cell "$MAIN_BOXES_ID" 1 "$BOX"
omc_trigger "$MAIN_BOXES_ID"
omc_run AgentVM.main.box.selected
omc_table_cell "$MAIN_IMAGES_ID" 1 dev-xcode
omc_trigger "$MAIN_IMAGES_ID"
omc_run AgentVM.main.image.selected
omc_run AgentVM.main.box.delete
omc_run AgentVM.main.box.recreate
omc_run AgentVM.main.image.delete
"$PB" agentvm_open_request_network set "$APP_PID network:$BOX"
in_window "$NET_UUID"
omc_control_defaults AgentVM.network
omc_run AgentVM.network.init
omc_trigger "$NET_PACKS_ID" 0
omc_run AgentVM.network.pack
"$PB" "agentvm_net_allow_$NET_UUID" set "$BOX registry.yarnpkg.com"
in_window "$MAIN_UUID"
# The same state under the empty uuid: what a handler that lost its guard would read.
"$PB" agentvm_box_ set "$BOX"
"$PB" agentvm_image_ set dev-xcode
"$PB" agentvm_box_delete_ set "$BOX"
"$PB" agentvm_box_recreate_ set "$BOX"
"$PB" agentvm_image_delete_ set dev-xcode
"$PB" agentvm_net_allow_ set "$BOX registry.yarnpkg.com"
/bin/cp "$TMPDIR/AgentVM/$MAIN_UUID"/* "$TMPDIR/AgentVM/$NET_UUID"/* "$TMPDIR/AgentVM/"
# With folders that exist, so that Show in Finder would have something to show (the fixture's
# folders are not on this Mac): field 17 of a box's row, field 11 of an image's.
for planted in "boxes 17" "images 11"; do
    /usr/bin/awk -F'\t' -v OFS='\t' -v field="${planted#* }" -v folder="$OMCTEST_WORK" '{ $field = folder; print }' \
        "$TMPDIR/AgentVM/$MAIN_UUID/${planted% *}.tsv" > "$TMPDIR/AgentVM/${planted% *}.tsv"
done
# A job that runs and holds the box, as agent-vm and the empty-uuid caches would show it once it
# had started: the main window's job rows, and a progress window's job with its Stop asked.
/usr/bin/jq -n --arg id "$JOB" --arg box "$BOX" '[{id: $id, command: ["box", "start", $box, "--json"], targets: ["box:" + $box],
    state: "running", createdAt: "2026-09-30T12:00:00Z", startedAt: "2026-09-30T12:00:00Z"}]' > "$FAKE_AGENTVM_DIR/jobs.json"
"$FAKE_AGENTVM" job list --json | /usr/bin/jq -r '.[] | [.id, .state, .targets[0], (.command[0:2] | join(" ")), "-", .createdAt, .startedAt, "-", "-", "-", "-", "-", "-", "-", "-", "-"] | join("\t")' \
    > "$TMPDIR/AgentVM/jobs.tsv"
/bin/cp "$TMPDIR/AgentVM/jobs.tsv" "$TMPDIR/AgentVM/job.tsv"
"$PB" agentvm_job_ set "$JOB"
"$PB" agentvm_job_stop_ set "$JOB"
# An image's update with a part ticked, as its window would keep it: the image is the one planted
# as the selection (ready, held by no job), so that an Update without its guard starts a job.
"$PB" agentvm_choices_ set "1 0 1"
# Guards: without these the checks below would pass with nothing at stake.
check "a job runs, and holds the box, under the empty uuid" "$JOB${TAB}running${TAB}box:$BOX|$JOB|$JOB" \
    "$(/usr/bin/cut -f1-3 "$TMPDIR/AgentVM/jobs.tsv")|$("$PB" agentvm_job_ get)|$("$PB" agentvm_job_stop_ get)"
check "an update could start under the empty uuid: a ready image, its parts ticked, agent-vm usable" "dev-xcode${TAB}ready|1 0 1|0" \
    "$(/usr/bin/awk -F'\t' '$1 == "dev-xcode"' "$TMPDIR/AgentVM/images.tsv" | /usr/bin/cut -f1,2)|$("$PB" agentvm_choices_ get)|$(/usr/bin/sed -n '1p' "$TMPDIR/AgentVM/agentvm")"
check "Delete was asked about the box"   "$BOX" "$("$PB" "agentvm_box_delete_$MAIN_UUID" get)"
check "Recreate too"                     "$BOX" "$("$PB" "agentvm_box_recreate_$MAIN_UUID" get)"
check "an image's Delete was asked"      "dev-xcode" "$("$PB" "agentvm_image_delete_$MAIN_UUID" get)"
check "the network window has an edit waiting" "yes" \
    "$([ -n "$(/usr/bin/diff "$TMPDIR/AgentVM/$NET_UUID/net-$BOX.current" "$TMPDIR/AgentVM/$NET_UUID/net-$BOX.desired")" ] && echo yes)"
check "the same state is planted under the empty uuid" "$BOX|yes|yes" \
    "$("$PB" agentvm_box_delete_ get)|$(/usr/bin/awk -F'\t' -v name="$BOX" -v folder="$OMCTEST_WORK" '$1 == name && $17 == folder { print "yes" }' "$TMPDIR/AgentVM/boxes.tsv")|$([ -s "$TMPDIR/AgentVM/net-$BOX.desired" ] && echo yes)"
check "the pasteboards are files the state can see" "yes" "$([ -n "$(/bin/ls "$OMCTEST_UI/pb" 2>/dev/null)" ] && echo yes)"
check "there are handlers to run"        "yes" "$(handlers | /usr/bin/awk 'END { if (NR >= 30) print "yes" }')"

# -----------------------------------------------------------------------------------------------
section "every handler, run without a window"
alerts_reset
chains_reset
: > "$FAKE_AGENTVM_DIR/log"
: > "$FAKE_OPEN_LOG"
before="$(state)"
offenders=""
failed=""
for handler in $(handlers); do
    without_window "$handler"
    status=$?
    [ "$status" -eq 0 ] || failed="$failed $handler($status)"
    after="$(state)"
    if [ "$after" != "$before" ]; then
        offenders="$offenders $handler"
        printf '%s changed:\n%s\n' "$handler" "$(printf '%s\n%s\n' "$before" "$after" | /usr/bin/sort | /usr/bin/uniq -u)" >&2
        before="$after"
    fi
done
check "none asks agent-vm, opens, writes, chains, alerts, or touches a pending question" "" "$offenders"
check "each exits cleanly"               "" "$failed"

section "the same handlers act in their window"
# The positive control: the loop above is not quiet because the handlers are broken.
: > "$FAKE_AGENTVM_DIR/log"
omc_run AgentVM.main.box.delete.confirmed
check "Delete, confirmed in the main window, deletes" "1" "$(fake_log | /usr/bin/grep -c -x "box delete $BOX --json")"

section "no writes to views the windows do not have"
check "no undeclared ids" "" "$(ui_unknown_writes)"
check "no harness errors" "" "$(ui_errors)"

omctest_end
