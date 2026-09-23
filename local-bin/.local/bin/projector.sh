#!/usr/bin/env bash
# projector.sh — external display (projector/monitor) control for i3/X11
# Usage:
#   projector.sh          -> toggle (mirror ON if off, OFF if on)
#   projector.sh mirror   -> mirror laptop + external at a common resolution
#   projector.sh extend   -> external to the right of laptop (presenter notes mode)
#   projector.sh off      -> disable external, back to laptop only
#   projector.sh status   -> show what's connected
#
# Detects the connected output automatically (HDMI preferred, then DP).
# No external connected -> helpful error instead of silent failure.

MODE="${1:-toggle}"
INTERNAL="eDP-1"

# find first connected external output (HDMI preferred, then DP)
find_ext() {
    xrandr --query 2>/dev/null | awk '
        / connected/ && /^HDMI/ { print $1; exit }
    '
    # fall back to DP if no HDMI is connected
    if [ -z "${EXT:-}" ]; then
        xrandr --query 2>/dev/null | awk '
            / connected/ && /^DP/ { print $1; exit }
        '
    fi
}

EXT="$(find_ext)"

if [ -z "$EXT" ]; then
    echo "⚠ No external display detected."
    echo "   Connected outputs right now:"
    xrandr --query | grep -E ' connected' | sed 's/^/   - /'
    echo ""
    echo "   If you just plugged in a projector, check:"
    echo "     1. Cable fully seated in the laptop AND projector"
    echo "     2. Projector powered on"
    echo "     3. Projector input/source set to the right HDMI port"
    exit 1
fi

ext_is_on() {
    xrandr --query | awk -v o="$EXT" '$1==o && $2=="connected" && $3 !~ /^\(/ {found=1} END {exit !found}'
}

current_res() {
    xrandr --query | awk -v o="$EXT" '$1==o && $2=="connected" {r=$3; sub(/\+.*/,"",r); print r; exit}'
}

# modes a given output supports
modes_of() {
    xrandr --query | awk -v o="$1" '
        $0 ~ "^" o " " { on=1; next }
        on && / (connected|disconnected)/ { exit }
        on && $1 ~ /^[0-9]+x[0-9]+$/ { print $1 }
    '
}

mirror_on() {
    xrandr --output "$EXT" --auto 2>/dev/null
    RES="$(current_res)"
    PREFS="$RES 1920x1080 1600x900 1440x900 1366x768 1280x800 1280x720 1024x768 960x540 800x600 640x480"
    eModes="$(modes_of "$INTERNAL")"
    xModes="$(modes_of "$EXT")"

    PICK=""
    for r in $PREFS; do
        if printf '%s\n' "$eModes" | grep -qxF "$r" && printf '%s\n' "$xModes" | grep -qxF "$r"; then
            PICK="$r"
            break
        fi
    done

    if [ -z "$PICK" ]; then
        echo "✗ No common resolution between $INTERNAL and $EXT. Modes available:"
        echo "  $INTERNAL: $(echo $eModes | tr '\n' ' ')"
        echo "  $EXT:      $(echo $xModes | tr '\n' ' ')"
        exit 1
    fi

    xrandr --output "$INTERNAL" --mode "$PICK" --output "$EXT" --mode "$PICK" --same-as "$INTERNAL"
    if [ $? -eq 0 ]; then
        echo "✓ Mirroring $EXT ($PICK) — same picture on laptop and projector."
    else
        echo "✗ Failed to set mirror mode. Try 'projector.sh extend' instead."
        exit 1
    fi
}

mirror_off() {
    xrandr --output "$EXT" --off
    xrandr --output "$INTERNAL" --auto
    echo "✓ External display $EXT disabled. Back to laptop only."
}

case "$MODE" in
    off|stop|disable)
        ext_is_on && mirror_off || { echo "ℹ $EXT is not active — nothing to turn off."; exit 0; }
        ;;
    mirror|on)
        mirror_on
        ;;
    extend)
        xrandr --output "$EXT" --auto --right-of "$INTERNAL" \
            && echo "✓ $EXT enabled, extended to the right of the laptop." \
            || echo "✗ Failed to enable $EXT."
        ;;
    status)
        echo "Internal: $INTERNAL"
        echo "External: $EXT ($(ext_is_on && echo ON || echo OFF))"
        xrandr --query | grep -E ' connected'
        ;;
    *)
        # default: toggle
        if ext_is_on; then mirror_off; else mirror_on; fi
        ;;
esac
