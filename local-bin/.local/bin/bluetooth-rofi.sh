#!/bin/sh
# Bluetooth menu — rofi front-end for bluetoothctl.
# Bound to $mod+Shift+b in the i3 config.
#
# Recovered from the old polybar setup (polybar/scripts/bluetooth-rofi.sh),
# with the Nerd-Font glyphs removed so it renders with the plain monospace
# font this desktop uses.
#
# Controls: paired devices (connect/disconnect toggle), scan+pair for new
# devices, power on/off.

set -u

pick() { rofi -dmenu -i -p "Bluetooth"; }
notify() { notify-send -a Bluetooth "$1"; }
mac_of() { printf '%s' "$1" | grep -oE '\(([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}\)' | tr -d '()'; }

powered=$(bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2}')

# ── Controller off → offer to turn it on ──────────────────────────────
if [ "$powered" != "yes" ]; then
    choice=$(printf 'Turn Bluetooth on\n' | pick)
    if [ "$choice" = "Turn Bluetooth on" ]; then
        bluetoothctl power on >/dev/null 2>&1
        notify "Bluetooth powered on"
    fi
    exit 0
fi

# ── Build the menu ────────────────────────────────────────────────────
menu=""
paired=$(bluetoothctl devices Paired 2>/dev/null)
if [ -n "$paired" ]; then
    paired_menu=$(printf '%s\n' "$paired" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        mac=$(printf '%s' "$line" | awk '{print $2}')
        name=$(printf '%s' "$line" | cut -d' ' -f3-)
        if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            printf 'Disconnect %s (%s)\n' "$name" "$mac"
        else
            printf 'Connect %s (%s)\n' "$name" "$mac"
        fi
    done)
    menu="${menu}--- Paired devices ---\n${paired_menu}\n"
fi
menu="${menu}--- Actions ---\nScan for new devices\nPower off\n"

choice=$(printf '%b' "$menu" | pick)
[ -z "${choice:-}" ] && exit 0

# ── Act on the choice ─────────────────────────────────────────────────
case "$choice" in
    "Power off")
        bluetoothctl power off >/dev/null 2>&1
        notify "Bluetooth powered off"
        ;;
    "Scan for new devices")
        notify "Scanning for devices (~10s)…"
        bluetoothctl pairable on >/dev/null 2>&1
        scan=$(bluetoothctl --timeout 10 scan on 2>&1)
        found=$(printf '%s\n' "$scan" \
            | perl -pe 's/\e\[[0-9;]*[a-zA-Z]//g' \
            | awk '/^\[NEW\] Device / {
                       mac=$3; $1=$2=$3=""; sub(/^ +/,"");
                       if (!seen[mac]++) print mac "|" $0
                   }')
        if [ -z "$found" ]; then
            bluetoothctl pairable off >/dev/null 2>&1
            notify "No devices found"
            exit 0
        fi
        display=$(printf '%s\n' "$found" | awk -F'|' '{print $2}')
        dev=$(printf '%s\n' "$display" | pick)
        if [ -n "${dev:-}" ]; then
            mac=$(printf '%s\n' "$found" | grep -F "|$dev" | head -1 | awk -F'|' '{print $1}')
            if [ -n "${mac:-}" ]; then
                notify "Pairing with $dev…"
                bluetoothctl pair "$mac" >/dev/null 2>&1
                bluetoothctl trust "$mac" >/dev/null 2>&1   # auto-reconnect later
                sleep 1
                notify "Connecting to $dev…"
                bluetoothctl connect "$mac" >/dev/null 2>&1 \
                    && notify "Connected to $dev" \
                    || notify "Could not connect to $dev"
            fi
        fi
        bluetoothctl pairable off >/dev/null 2>&1
        ;;
    "Connect "*)
        ac=$(mac_of "$choice")
        nm=$(printf '%s' "$choice" | sed 's/^Connect //; s/ *([^)]*)$//')
        notify "Connecting to $nm…"
        bluetoothctl connect "$ac" >/dev/null 2>&1 \
            && notify "Connected to $nm" \
            || notify "Could not connect to $nm"
        ;;
    "Disconnect "*)
        ac=$(mac_of "$choice")
        nm=$(printf '%s' "$choice" | sed 's/^Disconnect //; s/ *([^)]*)$//')
        bluetoothctl disconnect "$ac" >/dev/null 2>&1 && notify "Disconnected $nm"
        ;;
esac
