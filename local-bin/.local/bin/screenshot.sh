#!/bin/sh
# Screenshots without a daemon: maim + slop (+ xclip for the clipboard).
# Replaced flameshot 2026-09-26 — no tray process, no Qt, no login-time retry loop.
#
# Usage: screenshot.sh [full|region|window|pick] [options]
#   full    (default)  every monitor, one image
#   region             drag a rectangle (slop gives the selection overlay)
#   window             whatever window has focus
#   pick               click the window you want (slop forced window selection)
#
# Options:
#   --clip-only        don't write a file, clipboard only
#   --no-clip          don't touch the clipboard
#   --no-toast         no confirmation popup
#   --dir DIR          where files go (default: ~/Pictures/Screenshots)
#   -h, --help         this text
#
# Files: ~/Pictures/Screenshots/2026-09-26_18-30-12_region.png
# Both file and clipboard by default, like flameshot did.

set -u

MODE=full
DIR=${SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}
CLIP=1
WRITE=1
TOAST=1
TOAST_TIMEOUT=${NOTIFY_TIMEOUT:-2}

while [ $# -gt 0 ]; do
    case "$1" in
        full|region|window|pick) MODE=$1 ;;
        --clip-only) WRITE=0 ;;
        --no-clip)   CLIP=0 ;;
        --no-toast)  TOAST=0 ;;
        --dir)       [ -n "${2:-}" ] || { echo "screenshot.sh: --dir needs a value" >&2; exit 2; }; DIR=$2; shift ;;
        -h|--help)   sed -n '2,21p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "screenshot.sh: unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done

for t in maim slop; do
    command -v "$t" >/dev/null 2>&1 || {
        echo "screenshot.sh: $t is not installed (sudo pacman -S --needed maim slop)" >&2
        exit 1
    }
done

# -u = leave the cursor out of the image (flameshot does the same)
case $MODE in
    full)   set -- maim -u ;;
    region) set -- maim -u -s ;;
    window) command -v xdotool >/dev/null 2>&1 || { echo "screenshot.sh: xdotool missing" >&2; exit 1; }
            set -- maim -u -i "$(xdotool getactivewindow)" ;;
    pick)   set -- maim -u -s -t 9999999 ;;   # tolerance 9999999 forces a window pick
esac

out=""
if [ "$WRITE" = 1 ]; then
    mkdir -p "$DIR" || exit 1
    out="$DIR/$(date +%F_%H-%M-%S)_$MODE.png"
    "$@" "$out" || exit 1
fi

if [ "$CLIP" = 1 ]; then
    if [ -n "$out" ]; then
        xclip -selection clipboard -t image/png -i "$out" || exit 1
    else
        "$@" | xclip -selection clipboard -t image/png || exit 1
    fi
fi

if [ "$TOAST" = 1 ] && [ "$TOAST_TIMEOUT" -gt 0 ] 2>/dev/null; then
    if [ -n "$out" ]; then
        msg="Screenshot saved
$(basename "$out")"
    else
        msg="Copied to clipboard"
    fi
    timeout "$TOAST_TIMEOUT" rofi -e "$msg" >/dev/null 2>&1 || true
fi
exit 0
