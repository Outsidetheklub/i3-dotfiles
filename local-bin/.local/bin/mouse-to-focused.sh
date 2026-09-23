#!/bin/sh
# Move cursor to the centre of the currently focused window.
# Bound to $mod+Left / $mod+Right (focus left/right, then recentre the pointer).
#
# The original used `xdotool getrootwindow`, which is not an xdotool command —
# the "skip the desktop" guard silently did nothing and printed an error every
# time. The root/desktop window has no _NET_WM_PID, so we detect it that way.

wid=$(xdotool getactivewindow 2>/dev/null) || exit 0

# Root/desktop window (nothing focused) → nothing to recentre.
xdotool getwindowpid "$wid" >/dev/null 2>&1 || exit 0

eval "$(xdotool getwindowgeometry --shell "$wid" 2>/dev/null)"
[ -n "${WIDTH:-}" ] && [ -n "${HEIGHT:-}" ] || exit 0

xdotool mousemove "$((X + WIDTH / 2))" "$((Y + HEIGHT / 2))"
