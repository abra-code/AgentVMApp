#!/bin/sh
# Tests/helpers/fake_df.sh - stands in for /bin/df (AGENTVM_APP_DF): `df -k <folder>` answers with
# the free space of the first line of FAKE_DF_FILE, in KB, and that line is used up, so a test
# gives the free space before and after a discard as two lines. The folder asked about is logged
# in FAKE_DF_LOG. With no line left it fails, as df does for a folder it cannot read.
#
# POSIX sh only.
printf '%s\n' "$2" >> "${FAKE_DF_LOG:?fake_df: FAKE_DF_LOG is not set}"
file="${FAKE_DF_FILE:?fake_df: FAKE_DF_FILE is not set}"
free="$(/usr/bin/head -1 "$file" 2>/dev/null)"
[ -n "$free" ] || exit 1
/usr/bin/tail -n +2 "$file" > "$file.rest"
/bin/mv -f "$file.rest" "$file"
printf 'Filesystem 1024-blocks Used Available Capacity iused ifree %%iused Mounted on\n'
printf '/dev/disk3s5 971350180 900000000 %s 96%% 1 1 1%% /System/Volumes/Data\n' "$free"
