#!/bin/bash
# Tests/helpers/refresh_agentvm_fixtures.sh - capture Tests/fixtures/agentvm/ from a real agent-vm.
#
# Usage: Tests/helpers/refresh_agentvm_fixtures.sh <path to agent-vm> [<part> ...]
#
# Runs only queries that start and stop nothing: `version`, `doctor`, `status` (which, unlike
# `box list`, deletes no stopped disposable box), `image info` of one image, `box info` and the
# rules (`box network` with no change) of one box, and `box packs`, against the
# store agent-vm finds by itself (AGENT_VM_HOME, or ~/Library/Application Support/agent-vm),
# and, against an empty store in a temporary folder, `status` again and one job that can only
# fail, for the shape of a job's record and of its log. Each answer is re-serialized
# with sorted keys, and the home folder in every string is replaced with /Users/you, so a capture
# names no real account.
#
# With parts named, only those are captured, and every other fixture is left as it is: version,
# doctor, status (with the image info, box info and rules that follow from it), packs,
# recipe-check, ipsw (the list and what Apple offers), empty (the empty store's status and the
# job), linux. The tests name the images and boxes of status.json, so after an agent-vm update
# that changed nothing in a store's entries the parts that did change are enough.
#
# The part linux needs AGENTVM_FIXTURE_LINUX_HOME: a store with a ready Linux image built from
# another and a Linux box, which the store agent-vm finds by itself need not have. Its `status`
# becomes status-linux.json, the `image info` of that image image-info-linux.json and the `box
# info` of that box box-info-linux.json, the store's folder written as the default store's; and
# status-mixed.json is made of status.json with that store's images and boxes added. It is
# refused while something in that store runs or is being changed: a capture holds what was
# there at that moment.
#
# status-variety.json is not captured: it is made by hand (see the README beside the fixtures)
# and this script leaves it alone.
#
# After a refresh, run the suite: the drift checks in Tests/10-agentvm-library.test.sh fail
# when a field the library reads is gone, and the version check fails until the library's
# AGENTVM_MIN_VERSION and version.json agree. A coding agent must run this with its sandbox
# off: doctor asks the virtualization framework, which a sandbox refuses.

fail() {
    printf 'refresh_agentvm_fixtures.sh: %s\n' "$*" >&2
    exit 1
}

[ "$#" -ge 1 ] || fail "usage: $0 <path to agent-vm> [<part> ...]"
agentvm="$1"
[ -f "$agentvm" ] && [ -x "$agentvm" ] || fail "$agentvm is not an executable file"
shift
parts=" $* "
for part in "$@"; do
    case "$part" in
        version|doctor|status|packs|recipe-check|ipsw|empty|linux) ;;
        *) fail "\"$part\" is not a part: version, doctor, status, packs, recipe-check, ipsw, empty, linux" ;;
    esac
done

# wanted <part>  ->  0 when that part is to be captured: every part when none was named.
wanted() {
    [ "$parts" = "  " ] && return 0
    case "$parts" in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

script_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd -P)"
fixtures="$script_dir/../fixtures/agentvm"
[ -d "$fixtures" ] || fail "no fixtures folder at $fixtures"

work="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/agentvm-fixtures.XXXXXX")"
status=$?
[ "$status" -eq 0 ] && [ -n "$work" ] || fail "cannot make a temporary folder"
trap '/bin/rm -rf "$work"' EXIT

# capture <fixture name> <agent-vm args...> - one answer, sanitized, into the fixtures folder.
# Written to the temporary folder first and moved into place only when agent-vm and jq both
# succeeded, so a failed capture leaves the old fixture as it was.
capture() {
    local name="$1"
    shift
    "$agentvm" "$@" > "$work/$name.raw" 2> "$work/$name.err"
    local status=$?
    if [ "$status" -ne 0 ]; then
        /bin/cat "$work/$name.err" >&2
        fail "agent-vm $* failed with status $status"
    fi
    /usr/bin/jq -S --arg home "$HOME" \
        'walk(if type == "string" then split($home) | join("/Users/you") else . end)' \
        "$work/$name.raw" > "$work/$name.json"
    status=$?
    [ "$status" -eq 0 ] || fail "agent-vm $* did not print JSON (see $work/$name.raw)"
    /bin/mv -f "$work/$name.json" "$fixtures/$name.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot write $fixtures/$name.json"
    printf '  %s.json  <-  agent-vm %s\n' "$name" "$*"
}

# The Linux store is looked at before anything is captured, so a refusal leaves every fixture as
# it was: a store with a job, an image being changed or a box that is not stopped would be
# captured as it is in that moment.
linux_home="${AGENTVM_FIXTURE_LINUX_HOME:-}"
linux_image=""
linux_box=""
if wanted linux && [ -z "$linux_home" ]; then
    case "$parts" in
        *" linux "*) fail "the part linux needs AGENTVM_FIXTURE_LINUX_HOME: a store with a ready Linux image built from another and a Linux box" ;;
    esac
elif wanted linux; then
    linux_home="$(cd "$linux_home" 2>/dev/null && pwd -P)"
    [ -n "$linux_home" ] || fail "AGENTVM_FIXTURE_LINUX_HOME is not a folder: $AGENTVM_FIXTURE_LINUX_HOME"
    AGENT_VM_HOME="$linux_home" "$agentvm" status --json > "$work/linux-look.json" 2> "$work/linux-look.err"
    status=$?
    if [ "$status" -ne 0 ]; then
        /bin/cat "$work/linux-look.err" >&2
        fail "agent-vm status failed with status $status for the store $linux_home"
    fi
    busy="$(/usr/bin/jq -r '[(.jobs // [] | .[] | select(.state == "running" or .state == "queued") | "job \(.id)"),
        (.images[] | select(.state != "ready" or .updating == true) | "image \(.name)"),
        (.boxes[] | select(.state != "stopped") | "box \(.box.name)")] | join(", ")' "$work/linux-look.json")"
    [ -z "$busy" ] || fail "the store $linux_home is not at rest ($busy): capture it when nothing in it runs or is being changed"
    linux_image="$(/usr/bin/jq -r '[.images[] | select(.guest == "linux" and .state == "ready" and .derivedFrom != null)][0].name // empty' "$work/linux-look.json")"
    linux_box="$(/usr/bin/jq -r '[.boxes[] | select(.guest == "linux")][0].box.name // empty' "$work/linux-look.json")"
    [ -n "$linux_image" ] || fail "the store $linux_home has no ready Linux image built from another"
    [ -n "$linux_box" ] || fail "the store $linux_home has no Linux box"
fi

printf 'Capturing from %s (%s)\n' "$agentvm" "$("$agentvm" --version 2>&1)"
if wanted version; then
    capture version version --json
fi
if wanted doctor; then
    capture doctor doctor --json
fi
if wanted status; then
    capture status status --json

    # The image detail pane reads `image info`: the first ready image built from another, which
    # has every field the pane shows (a recipe, the space added over its base).
    info_image="$(/usr/bin/jq -r '[.images[] | select(.state == "ready" and .derivedFrom != null)][0].name // empty' "$fixtures/status.json")"
    if [ -n "$info_image" ]; then
        capture image-info image info "$info_image" --json
    else
        printf '  image-info.json left as it was: no ready image built from another in this store\n'
    fi

    # The box detail pane reads `box info`: the first box, measured whether it runs or not.
    info_box="$(/usr/bin/jq -r '.boxes[0].box.name // empty' "$fixtures/status.json")"
    if [ -n "$info_box" ]; then
        capture box-info box info "$info_box" --json
        # The network window: the same box's rules (`box network` with no change only reads
        # them). Its connection log is not captured: it lists what programs in the box reached,
        # which does not belong in a public repository; box-netlog.json is made by hand (see the
        # README).
        capture box-network box network "$info_box" --json
    else
        printf '  box-info.json and box-network.json left as they were: no box in this store\n'
    fi
fi
if wanted packs; then
    capture packs box packs --json
fi
if wanted recipe-check; then
    # What agent-vm says about recipes: the New Image window asks before a recipe of the user's
    # own joins the list, and before a build. Asked about two of the test recipes (one with an
    # input file, one with parameters), which agent-vm accepts with warnings; nothing is built and
    # no store is read. Their folder is written as "recipes", so the capture names no folder of
    # this Mac.
    recipes="$(cd "$script_dir/../fixtures/recipes" && pwd -P)"
    [ -n "$recipes" ] || fail "no test recipes at $script_dir/../fixtures/recipes"
    capture recipe-check recipe check "$recipes/xcode/recipe.json" "$recipes/xcode-platforms/recipe.json" --json
    # capture has already written the home folder as /Users/you, in the recipes' paths too.
    /usr/bin/jq -S --arg dir "$recipes" --arg home "$HOME" \
        '($dir | split($home) | join("/Users/you")) as $shown
         | walk(if type == "string" and startswith($shown) then "recipes" + ltrimstr($shown) else . end)' \
        "$fixtures/recipe-check.json" > "$work/recipe-check.clean.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot rewrite the recipes folder in recipe-check.json"
    /bin/mv -f "$work/recipe-check.clean.json" "$fixtures/recipe-check.json"
fi
if wanted ipsw; then
    # The restore files agent-vm downloaded: the New Image window lists them. Only its cache
    # folder is read.
    capture ipsw-list image fetch-ipsw --list --json
    # What Apple offers now, and whether it is downloaded and fits: the Get macOS window shows it.
    # It asks Apple (the network) and downloads nothing.
    capture ipsw-check image fetch-ipsw --check --json
fi

if wanted empty; then
    /bin/mkdir -p "$work/empty-store"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot make an empty store in $work"
    AGENT_VM_HOME="$work/empty-store" capture status-empty status --json

    # A job's record: one job started against the empty store, where it can only fail (there is
    # no such box), so nothing outside the temporary folder changes. It ends within a second; the
    # wait is for its runner to record the end. The store's path in the record is replaced like
    # the home folder, since the temporary folder has a new name every time.
    AGENT_VM_HOME="$work/empty-store" "$agentvm" job start -- box start nosuch > /dev/null 2> "$work/job-start.err"
    status=$?
    if [ "$status" -ne 0 ]; then
        /bin/cat "$work/job-start.err" >&2
        fail "agent-vm job start failed with status $status"
    fi
    /bin/sleep 2
    AGENT_VM_HOME="$work/empty-store" capture job-list job list --json
    /usr/bin/jq -S 'walk(if type == "string" then sub("^.*/empty-store"; "/Users/you/Library/Application Support/agent-vm") else . end)' \
        "$fixtures/job-list.json" > "$work/job-list.clean.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot rewrite the store path in job-list.json"
    /bin/mv -f "$work/job-list.clean.json" "$fixtures/job-list.json"

    # The same job's log: its record again, with its events and lines (none: it failed before any).
    job_id="$(/usr/bin/jq -r '.[0].id // empty' "$fixtures/job-list.json")"
    [ -n "$job_id" ] || fail "job-list.json names no job"
    AGENT_VM_HOME="$work/empty-store" capture job-log job log "$job_id" --json
    /usr/bin/jq -S 'walk(if type == "string" then sub("^.*/empty-store"; "/Users/you/Library/Application Support/agent-vm") else . end)' \
        "$fixtures/job-log.json" > "$work/job-log.clean.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot rewrite the store path in job-log.json"
    /bin/mv -f "$work/job-log.clean.json" "$fixtures/job-log.json"
fi

# -- Linux ---------------------------------------------------------------------------------------
# default_store <fixture name> <store folder> - that store's folder written as the default
# store's in a captured fixture, so a capture names no folder of this Mac. capture has already
# written the home folder as /Users/you, in the store's path too.
default_store() {
    /usr/bin/jq -S --arg store "$2" --arg home "$HOME" \
        '($store | split($home) | join("/Users/you")) as $shown
         | walk(if type == "string" then split($shown) | join("/Users/you/Library/Application Support/agent-vm") else . end)' \
        "$fixtures/$1.json" > "$work/$1.store.json"
    local status=$?
    [ "$status" -eq 0 ] || fail "cannot rewrite the store's folder in $1.json"
    /bin/mv -f "$work/$1.store.json" "$fixtures/$1.json"
    status=$?
    [ "$status" -eq 0 ] || fail "cannot write $fixtures/$1.json"
}

if [ -z "$linux_home" ]; then
    if wanted linux; then
        printf '  the Linux fixtures left as they were: AGENTVM_FIXTURE_LINUX_HOME names no store\n'
    fi
elif wanted linux; then
    AGENT_VM_HOME="$linux_home" capture status-linux status --json
    default_store status-linux "$linux_home"
    AGENT_VM_HOME="$linux_home" capture image-info-linux image info "$linux_image" --json
    default_store image-info-linux "$linux_home"
    AGENT_VM_HOME="$linux_home" capture box-info-linux box info "$linux_box" --json
    default_store box-info-linux "$linux_home"
    # The count is of this Mac's virtual machines, whoever runs them.
    running="$(/usr/bin/jq -r '.runningVMs.count // 0' "$fixtures/status-linux.json")"
    [ "$running" = "0" ] || printf '  note: %s virtual machines ran on this Mac during the capture, and status-linux.json says so\n' "$running"
fi

# A store with both kinds, for what the window shows side by side: status.json with the Linux
# store's images and boxes added, made whenever either was captured. A name the two stores share
# would be two entries of one name, which no store has.
if wanted status || wanted linux; then
    if [ -f "$fixtures/status-linux.json" ]; then
        shared="$(/usr/bin/jq -r -s '(.[0].images + .[1].images | map(.name)) + (.[0].boxes + .[1].boxes | map(.box.name))
            | group_by(.) | map(select(length > 1) | .[0]) | join(", ")' "$fixtures/status.json" "$fixtures/status-linux.json")"
        [ -z "$shared" ] || fail "status.json and status-linux.json both have $shared: status-mixed.json cannot hold both"
        /usr/bin/jq -S -s '.[1] as $linux | .[0] | .images += $linux.images | .boxes += $linux.boxes' \
            "$fixtures/status.json" "$fixtures/status-linux.json" > "$work/status-mixed.json"
        status=$?
        [ "$status" -eq 0 ] || fail "cannot make status-mixed.json of status.json and status-linux.json"
        /bin/mv -f "$work/status-mixed.json" "$fixtures/status-mixed.json"
        status=$?
        [ "$status" -eq 0 ] || fail "cannot write $fixtures/status-mixed.json"
        printf '  status-mixed.json  <-  status.json with the images and boxes of status-linux.json\n'
    fi
fi

printf 'Done. Run the suite; update the README beside the fixtures with the date and version.\n'
