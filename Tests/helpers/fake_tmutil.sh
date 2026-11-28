#!/bin/sh
# Tests/helpers/fake_tmutil.sh - stands in for /usr/bin/tmutil (AGENTVM_APP_TMUTIL): isexcluded,
# addexclusion and removeexclusion of one folder, kept as a line per excluded path in
# FAKE_TMUTIL_EXCLUDED instead of the folder's attribute. Each call is logged in FAKE_TMUTIL_LOG,
# as its verb and path. A path whose last part is FAKE_TMUTIL_REFUSE is refused by addexclusion
# and removeexclusion with a message and status 1, as tmutil refuses a folder it cannot change.
#
# POSIX sh only.
state="${FAKE_TMUTIL_EXCLUDED:?fake_tmutil: FAKE_TMUTIL_EXCLUDED is not set}"
printf '%s %s\n' "$1" "$2" >> "${FAKE_TMUTIL_LOG:?fake_tmutil: FAKE_TMUTIL_LOG is not set}"
[ -f "$state" ] || : > "$state"
found="$(/usr/bin/grep -cxF -- "$2" "$state")"
case "$1" in
    isexcluded)
        if [ "$found" = "0" ]; then
            printf '[Included]  %s\n' "$2"
        else
            printf '[Excluded]  %s\n' "$2"
        fi
        exit 0 ;;
    addexclusion|removeexclusion)
        if [ -n "${FAKE_TMUTIL_REFUSE:-}" ] && [ "${2##*/}" = "$FAKE_TMUTIL_REFUSE" ]; then
            printf '%s: Operation not permitted\n' "$2" >&2
            exit 1
        fi
        /usr/bin/grep -vxF -- "$2" "$state" > "$state.new"
        [ "$1" = "addexclusion" ] && printf '%s\n' "$2" >> "$state.new"
        /bin/mv -f "$state.new" "$state"
        exit 0 ;;
esac
printf 'fake_tmutil: %s is not faked\n' "$1" >&2
exit 2
