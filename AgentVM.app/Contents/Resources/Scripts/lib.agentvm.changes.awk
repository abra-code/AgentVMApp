# lib.agentvm.changes.awk
# The ticks of a Session Changes window (lib.agentvm.changes.sh), from its rows.tsv: a tick, then
# the change rows of agentvm_report_change_rows (path in field 2, covered by an ancestor's change
# in field 9, plain path in field 12), in agent-vm's order, by path, so a folder comes before what
# is in it.
#
# An undo of a folder puts back what is under it too, so an entry under a ticked folder follows
# that folder: it shows ticked, and is not named to agent-vm on its own. An entry inside a folder
# added or deleted as a whole (covered) can only follow. Each row is printed with field 1 the tick
# it shows, then two fields more: whether it follows a ticked folder above it, and whether the
# undo names it (its own tick, on an entry that may be named and follows none).
BEGIN { FS = "\t"; OFS = "\t" }
{
    path = $2
    follows = "false"
    parent = path
    while (sub(/\/[^\/]*$/, "", parent)) {
        if (parent in named) { follows = "true"; break }
    }
    names = ($1 == "true" && $9 == "false" && $12 == "true" && follows == "false") ? "true" : "false"
    if (names == "true") named[path] = 1
    $1 = (names == "true" || follows == "true") ? "true" : "false"
    print $0, follows, names
}
