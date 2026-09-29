#!/bin/sh
# Tests/helpers/fake_ps.sh - `ps -p <pid> -o comm=`, answered for the fixtures' owner.
#
# lib.agentvm.ui.sh names a box's owner from the process list (AGENTVM_APP_PS points it here).
# The real ps needs the sandbox off and answers about whatever runs on the Mac; this answers
# for pid 812, the owner of box s3 in fixtures/agentvm/status-variety.json, as Cadabra, and for
# no other process, as ps does for a pid that is gone (status 1, nothing printed).
[ "$1" = "-p" ] || exit 64
case "$2" in
    812) printf '/Applications/Cadabra.app/Contents/MacOS/Cadabra\n' ;;
    *)   exit 1 ;;
esac
