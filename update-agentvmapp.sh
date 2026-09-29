#!/bin/bash
# update-agentvmapp.sh - make AgentVM.app runnable and signed from this working tree.
#
# The repository holds the applet's own files only. The OMC engine (Contents/Frameworks and the
# executable in Contents/MacOS) is not committed: AppletBuilder installs it. This script:
#   1. sets AGENTVM_MIN_VERSION in lib.agentvm.sh to the version of the agent-vm working tree
#      beside this repository: the app requires the agent-vm it is built and tested with;
#   2. removes tool residue from the bundle (a .claude folder left by a coding agent whose
#      working directory was inside it makes codesign refuse the whole bundle);
#   3. runs `appletbuilder build`, which validates the bundle, installs or refreshes the engine,
#      thins every binary to arm64, runs the test suite (unless --skip-tests), and signs;
#   4. verifies the result: a valid signature, arm64 only, and macOS 27 as the minimum.
#
# AgentVM.app carries no agent-vm. It runs the agent-vm installed in ~/.local/bin (or a
# developer override), so nothing of agent-vm is built or copied here, and the app needs no
# virtualization entitlement: agent-vm, a separate program with its own signature, is what runs
# virtual machines.
#
# Usage: ./update-agentvmapp.sh [--identity <codesign identity>] [--skip-tests] [--keep-min-version]
#   --identity          passed to codesign (default "-", ad hoc: runs on this Mac only)
#   --skip-tests        build and sign without running Tests/ (for a quick rebuild mid-change)
#   --keep-min-version  leave AGENTVM_MIN_VERSION as committed (no agent-vm working tree here)
#
# Environment: APPLETBUILDER, the appletbuilder command line tool, when it is not in
# ../OMC/Distribution/AppletBuilder.app or /Applications/AppletBuilder.app; AGENTVM_REPO, the
# agent-vm working tree, when it is not ../agent-vm.
#
# When a coding agent runs this script, the tests need its sandbox off (see Tests/README.md):
# the contract test runs the real agent-vm, whose doctor asks the virtualization framework.

script_dir="$(cd "$(/usr/bin/dirname "$0")" && pwd -P)"
app="$script_dir/AgentVM.app"
identity="-"
run_tests="yes"
set_min_version="yes"

fail() {
    printf 'update-agentvmapp.sh: %s\n' "$*" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --identity)
            [ "$#" -ge 2 ] || fail "--identity needs a value"
            identity="$2"
            shift 2 ;;
        --skip-tests)
            run_tests="no"
            shift ;;
        --keep-min-version)
            set_min_version="no"
            shift ;;
        -h|--help)
            /usr/bin/sed -n '2,/^$/p' "$0"
            exit 0 ;;
        *)
            fail "unknown argument: $1 (see --help)" ;;
    esac
done

[ -d "$app" ] || fail "no AgentVM.app beside this script, in $script_dir"

# -- The appletbuilder tool ------------------------------------------------------------------
appletbuilder=""
for candidate in "${APPLETBUILDER:-}" \
        "$script_dir/../OMC/Distribution/AppletBuilder.app/Contents/Resources/Agents/appletbuilder" \
        "/Applications/AppletBuilder.app/Contents/Resources/Agents/appletbuilder"; do
    if [ -n "$candidate" ] && [ -f "$candidate" ] && [ -x "$candidate" ]; then
        appletbuilder="$candidate"
        break
    fi
done
[ -n "$appletbuilder" ] || fail "cannot find appletbuilder: set APPLETBUILDER to its path, or put AppletBuilder.app in /Applications or ../OMC/Distribution"

# -- 1. The agent-vm version the app requires -------------------------------------------------
# One development stream: the app is tested against the newest agent-vm only, so it requires
# exactly that version or newer. The number lives on one line of the library, and the tests
# compare it with the fixtures' agent-vm, so after an agent-vm update they fail until the
# fixtures are refreshed from it (Tests/helpers/refresh_agentvm_fixtures.sh).
printf '==== agent-vm version\n'
library="$app/Contents/Resources/Scripts/lib.agentvm.sh"
current="$(/usr/bin/sed -n 's/^AGENTVM_MIN_VERSION="\(.*\)"$/\1/p' "$library")"
[ -n "$current" ] || fail "no AGENTVM_MIN_VERSION line in $library"
if [ "$set_min_version" = "yes" ]; then
    agentvm_repo="${AGENTVM_REPO:-$script_dir/../agent-vm}"
    version_file="$agentvm_repo/Sources/AgentVMKit/AgentVM.swift"
    [ -f "$version_file" ] || fail "no agent-vm working tree at $agentvm_repo (no $version_file): set AGENTVM_REPO, or pass --keep-min-version"
    wanted="$(/usr/bin/sed -n 's/^ *public static let version = "\([0123456789.]*\)"$/\1/p' "$version_file")"
    [ -n "$wanted" ] || fail "cannot read agent-vm's version from $version_file"
    if [ "$current" != "$wanted" ]; then
        /usr/bin/sed -i '' "s/^AGENTVM_MIN_VERSION=\".*\"\$/AGENTVM_MIN_VERSION=\"$wanted\"/" "$library"
        status=$?
        [ "$status" -eq 0 ] || fail "cannot rewrite AGENTVM_MIN_VERSION in $library"
        printf '  AGENTVM_MIN_VERSION changed from %s to %s, the version in %s\n' "$current" "$wanted" "$agentvm_repo"
        printf '  the tests fail until Tests/fixtures/agentvm is refreshed from agent-vm %s\n' "$wanted"
    else
        printf '  AGENTVM_MIN_VERSION is %s, the version in %s\n' "$current" "$agentvm_repo"
    fi
else
    printf '  AGENTVM_MIN_VERSION kept at %s\n' "$current"
fi

# -- 2. Tool residue ---------------------------------------------------------------------------
# Only names that no part of this app ever creates. Anything else starting with a dot is named,
# not deleted: it may be residue of a tool this list does not know yet.
printf '==== Residue\n'
residue="$(/usr/bin/find "$app" -type d -name '.claude' -prune -print)"
if [ -n "$residue" ]; then
    printf '  removing tool residue before signing:\n%s\n' "$residue"
    /usr/bin/find "$app" -type d -name '.claude' -prune -exec /bin/rm -rf {} +
    status=$?
    [ "$status" -eq 0 ] || fail "cannot remove the .claude folders listed above"
fi
unknown="$(/usr/bin/find "$app" -path "$app/Contents/Frameworks" -prune -o -name '.*' -not -name '.DS_Store' -print)"
if [ -n "$unknown" ]; then
    printf '  warning: unexpected dot-files in the bundle, which codesign may refuse:\n%s\n' "$unknown"
fi
/usr/bin/find "$app" -name '.DS_Store' -delete

# -- 3. Build ----------------------------------------------------------------------------------
printf '==== appletbuilder build\n'
# The arguments were parsed above, so the positional parameters are free to hold the command.
# appletbuilder signs ad hoc by default and reads "-" as an option, so the identity is passed
# only when it is a real one.
set -- build "$app" --thin arm64
if [ "$run_tests" = "yes" ]; then
    set -- "$@" --test
fi
if [ "$identity" != "-" ]; then
    set -- "$@" --identity "$identity"
fi
"$appletbuilder" "$@"
status=$?
[ "$status" -eq 0 ] || fail "appletbuilder build failed (status $status); its output above says why"

# -- 4. Verify ---------------------------------------------------------------------------------
printf '==== Verify\n'
/usr/bin/codesign --verify --deep --strict "$app"
status=$?
[ "$status" -eq 0 ] || fail "the signature of $app does not verify (status $status)"

archs="$(/usr/bin/lipo -archs "$app/Contents/MacOS/AgentVM")"
status=$?
[ "$status" -eq 0 ] || fail "cannot read the architectures of $app/Contents/MacOS/AgentVM"
[ "$archs" = "arm64" ] || fail "the executable is built for \"$archs\", not arm64 only"

minimum="$(/usr/bin/plutil -extract LSMinimumSystemVersion raw "$app/Contents/Info.plist")"
status=$?
[ "$status" -eq 0 ] || fail "Info.plist has no LSMinimumSystemVersion"
[ "$minimum" = "27.0" ] || fail "Info.plist says LSMinimumSystemVersion $minimum, not 27.0"

printf '  signed (%s), arm64 only, macOS %s or later\n' "$identity" "$minimum"
printf 'AgentVM.app is ready: %s\n' "$app"
