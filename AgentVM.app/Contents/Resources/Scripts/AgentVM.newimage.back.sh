#!/bin/sh
# AgentVM.newimage.back.sh
# Back, in the New Image window: what the step shown holds is kept, as this click saw it and
# unchecked, and the step before it is shown; from Name and size that is Tools when the tools
# ticked ask for nothing.

. "$OMC_APP_BUNDLE_PATH/Contents/Resources/Scripts/lib.agentvm.newimage.sh"

window_uuid="$OMC_ACTIONUI_WINDOW_UUID"
[ -n "$window_uuid" ] || exit 0
newimage_is "$window_uuid" || exit 0
newimage_enter "$window_uuid" || exit 0
step="$(newimage_step "$window_uuid")"
case "$step" in
    1) exit 0 ;;
    2) newimage_take_ticks "$window_uuid" ;;
    3) newimage_take_options "$window_uuid" ;;
    4) newimage_take_sizes "$window_uuid" ;;
esac
previous=$((step - 1))
if [ "$step" -eq 4 ] && [ -z "$(newimage_option_rows "$window_uuid")" ]; then
    previous=2
fi
newimage_show "$window_uuid" "$previous"
exit 0
