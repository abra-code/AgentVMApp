#!/bin/sh
# Tests/helpers/fake_pbcopy.sh - stands in for /usr/bin/pbcopy (AGENTVM_APP_PBCOPY): what comes
# on stdin becomes the file FAKE_PBCOPY_FILE, and its arguments a line of FAKE_PBCOPY_FILE.args,
# so a test sees what would have reached the clipboard without touching the real one. With
# FAKE_PBCOPY_FAIL set it writes nothing and exits 1.
if [ -n "${FAKE_PBCOPY_FAIL:-}" ]; then
    exit 1
fi
printf '%s\n' "$*" >> "${FAKE_PBCOPY_FILE:?fake_pbcopy: FAKE_PBCOPY_FILE is not set}.args"
/bin/cat > "$FAKE_PBCOPY_FILE"
