#!/bin/sh
# AgentVM.update.next.sh
# Continue, in an image's update window: with the tools ticked, the second step, which lists the
# recipes the image keeps; it is filled before it is shown. Without them there is no second step.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.update.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
image="$(update_image "$window_uuid")"
[ -n "$image" ] || exit 0
case "$(update_choices "$window_uuid" "$image")" in
    [01]" 1 "[01]) ;;
    *) exit 0 ;;
esac
ui_set step "$window_uuid" 2
update_paint "$window_uuid"
[ -n "$(update_image "$window_uuid")" ] || ui_cache_clear "$window_uuid"
exit 0
