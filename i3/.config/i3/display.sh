#!/bin/sh
# Machine-specific display setup — Dell Latitude 7490 (Intel i915), i3/X11.
# NOT tracked in the repo (machine-local).
#
# Why this file exists: i3 (and X itself) never enable extra outputs. Without an
# xrandr call here, a second monitor stays black no matter what the i3 config says.
# startup.sh runs it at i3 start. It is also safe to run by hand at any time:
#     ~/.config/i3/display.sh
# For manual switching (mirror / extend / off / status) use projector.sh.

INTERNAL="eDP-1"
# External candidates, in preference order (xrandr names):
EXTERNAL_PREF="HDMI-1 HDMI-2 DP-1 DP-2"

# Pick the first connected external output.
EXT=""
for o in $EXTERNAL_PREF; do
    if xrandr --query 2>/dev/null | grep -q "^$o connected"; then
        EXT="$o"
        break
    fi
done

# No external screen -> nothing to do (single-screen laptop).
[ -z "$EXT" ] && exit 0

# Turn the laptop panel on at its preferred mode and make it primary.
xrandr --output "$INTERNAL" --auto --primary 2>/dev/null

# Enable the external to the right of the laptop; fall back to a plain --auto
# if the "right-of" placement fails for any reason.
xrandr --output "$EXT" --auto --right-of "$INTERNAL" 2>/dev/null \
    || xrandr --output "$EXT" --auto 2>/dev/null

exit 0
