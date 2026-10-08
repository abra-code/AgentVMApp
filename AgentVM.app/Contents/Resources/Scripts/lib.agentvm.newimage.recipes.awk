# lib.agentvm.newimage.recipes.awk - the recipes of the New Image window (lib.agentvm.newimage.sh):
# the ones the user added, every one the window knows, or the ones a start is offered.
#
#     NEW_START="image deb" /usr/bin/awk -F'\t' -v want=listed -v slots=10 -f lib.agentvm.newimage.recipes.awk \
#         role=build build.tsv role=shipped recipes.tsv role=own own.tsv
#     ... | /usr/bin/awk -F'\t' -v want=listed -v guest=linux -v slots=10 -v role=shipped -f lib.agentvm.newimage.recipes.awk
#
# The input is the window's cache files, each after the role it is read in (a file that does not
# exist is left out by the caller), in the order above: the start's system is then known before
# the first recipe is read, and the recipes that come with agent-vm are listed before the ones
# the user added. Recipe rows on standard input are read in the role given with -v.
#
#   role=build    agentvm_status_build_rows, one row per image: 1 its name, 13 its guest. Nothing
#                 is printed for them.
#   role=shipped  newimage_recipe_rows, one row per recipe: 1 its name, 5 the path of its file,
#                 6 the guest it is for (macos, linux, any for both, "-" when agent-vm did not say).
#   role=own      the recipes the user added, in the same fields. These rows come back from a
#                 file, so one without its six fields, a full path, a guest that is one of the
#                 four above, or a name of letters, digits, ".", "_" and "-" is left out.
#
# Wants:
#   own     the rows of role=own that are a recipe's.
#   all     every recipe, each name once: the first row of a name stays.
#   listed  of those, the ones a start is offered, at most `slots` of them: every recipe but one
#           for the other system than the start's. The system is `guest` when it is given. When
#           it is not, it is what the start runs: Linux when the start, the environment's
#           NEW_START, is "image <name>" and that image's guest is linux, and macOS for anything
#           else (a restore file, an image that is not listed). The start is read from the
#           environment because -v would read a backslash in it as an escape.

BEGIN {
    start = ENVIRON["NEW_START"]
    fixed = (guest != "")
    if (!fixed) guest = "macos"
}

role == "build" {
    # Compared as text: to awk, "1" and "1.0" are the same number, and both can be names.
    if (!fixed && start == ("image " $1) && $13 == "linux") guest = "linux"
    next
}

# The letters are spelled out because a bracket range follows the locale's collation order.
role == "own" && !(NF == 6 && $5 ~ /^\// && $6 ~ /^(macos|linux|any|-)$/ \
    && $1 ~ /^[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-]+$/) { next }

want == "own" {
    if (role == "own") print
    next
}

NF == 0 || seen[$1]++ { next }

want == "all" {
    print
    next
}

$6 != ((guest == "linux") ? "macos" : "linux") && ++n <= slots { print }
