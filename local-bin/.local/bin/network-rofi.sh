#!/bin/sh
# Network menu — rofi front-end for NetworkManager (nmcli).
# Bound to $mod+Shift+n in the i3 config.
#
# Wi-Fi on this box runs through NetworkManager with the iwd backend
# (/etc/NetworkManager/conf.d/wifi_backend.conf), but everything here talks to
# nmcli only, so it works on a wpa_supplicant install too. No iwctl needed.
#
# What it does:
#   • live status header (Wi-Fi connection + Ethernet state)
#   • rescan, Wi-Fi radio on/off
#   • connect to saved profiles, hot-connect to any visible AP (prompts for the
#     password when the AP is secured), connect to a hidden SSID
#   • disconnect the current network, forget saved profiles
#   • read-only "IP details" panel
#
# Plain-text labels only — no Nerd Font glyphs (this desktop runs a stock
# monospace font, so glyphs render as boxes; same rule as bluetooth-rofi.sh).

set -u

ROFI_BIN=${ROFI_BIN:-rofi}
IFACE=${WLAN_IFACE:-wlan0}

notify() {
    if [ -n "${2:-}" ]; then
        notify-send -a Network "$1" "$2"
    else
        notify-send -a Network "$1"
    fi
}

# -no-custom in the main menu: typing a non-matching filter + Enter does nothing.
pick() { "$ROFI_BIN" -dmenu -i -no-custom "$@"; }
# Free-text (and password) input: custom entries must be allowed.
ask()  { "$ROFI_BIN" -dmenu -i "$@"; }

# ── data gatherers ────────────────────────────────────────
# one row per visible AP: "signal% \t security \t ssid" (security empty = open)
wifi_rows() {
    nmcli -t -e no -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no 2>/dev/null |
        awk -F: '{n=NF; sec=$n; sig=$(n-1); use=$1; ssid=$2;
                  for(i=3;i<=n-2;i++) ssid=ssid ":" $i;
                  if (ssid=="") next;
                  print sig "\t" sec "\t" ssid}'
}

# names of saved Wi-Fi connection profiles, one per line
saved_names() {
    nmcli -t -e no -f TYPE,NAME connection show 2>/dev/null |
        awk -F: -v want="$1" '{type=$1; name="";
                               for(i=2;i<=NF;i++) name=name (i>2?":":"") $i;
                               if (type==want) print name}'
}

wifi_field() { # $1=ssid  $2=column (1=signal, 2=security)
    printf '%s\n' "$WIFI_ROWS" | awk -F'\t' -v s="$1" -v c="$2" '$3==s{print $c; exit}'
}

# ── main loop ─────────────────────────────────────────────
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
: > "$tmp/i"; : > "$tmp/a"      # menu display lines / actions, same order

item() { printf '%s\n' "$1" >> "$tmp/i"; printf '%s\n' "${2:-NONE}" >> "$tmp/a"; }
# for sections built in a pipeline subshell: write pairs, append after the pipe
pair() { printf '%s\t%s\n' "$1" "$2" >> "$tmp/p"; }
flush_pairs() {
    [ -s "$tmp/p" ] || return 0
    cut -f1 "$tmp/p" >> "$tmp/i"
    cut -f2- "$tmp/p" >> "$tmp/a"
    : > "$tmp/p"
}

while :; do
    : > "$tmp/i"; : > "$tmp/a"; : > "$tmp/p"

    WIFI_ROWS=$(wifi_rows)
    radio=$(nmcli -t -e no radio wifi 2>/dev/null)                       # enabled|disabled
    dev=$(nmcli -t -e no -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null |
              awk -F: -v d="$IFACE" '$1==d{print; exit}')
    wifi_state=$(printf '%s' "$dev" | cut -d: -f3)
    active_ssid=$(printf '%s' "$dev" | cut -d: -f4-)
    eth=$(nmcli -t -e no -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null |
              awk -F: '$2=="ethernet"{print; exit}')
    eth_state=$(printf '%s' "$eth" | cut -d: -f3)
    eth_name=$(printf '%s' "$eth" | cut -d: -f4-)
    SAVED=$(saved_names 802-11-wireless)

    # ── status ────────────────────────────────────────────
    item "-- Status --"
    if [ "$radio" = enabled ]; then
        if [ "$wifi_state" = connected ]; then
            sig=$(wifi_field "$active_ssid" 1)
            item "Wi-Fi: connected to $active_ssid${sig:+ ($sig%)}"
        else
            item "Wi-Fi: on, not connected"
        fi
    else
        item "Wi-Fi: off (radio disabled)"
    fi
    case "$eth_state" in
        connected)    item "Ethernet: connected${eth_name:+ ($eth_name)}" ;;
        disconnected) item "Ethernet: not connected" ;;
        unavailable)  item "Ethernet: no cable" ;;
    esac

    # ── actions ───────────────────────────────────────────
    item "-- Actions --"
    item "Rescan networks" RESCAN
    if [ "$radio" = enabled ]; then
        item "Turn Wi-Fi off" WIFI_OFF
        item "Connect to hidden network..." HIDDEN
    else
        item "Turn Wi-Fi on" WIFI_ON
    fi
    [ "$eth_state" = disconnected ] && item "Connect Ethernet" ETH_UP
    item "IP details" IP_INFO
    item "Forget a saved network..." FORGET
    item "Close menu" CLOSE

    # ── saved profiles ────────────────────────────────────
    if [ "$radio" = enabled ] && [ -n "$SAVED" ]; then
        item "-- Saved networks --"
        printf '%s\n' "$SAVED" | while IFS= read -r sname; do
            [ -z "$sname" ] && continue
            sig=$(wifi_field "$sname" 1)
            if [ "$wifi_state" = connected ] && [ "$sname" = "$active_ssid" ]; then
                pair "  $sname  (connected)" "DISCONNECT"
            elif [ -n "$sig" ]; then
                pair "  $sname  [$sig%]" "CONNECT_SAVED|$sname"
            else
                pair "  $sname  (out of range)" "CONNECT_SAVED|$sname"
            fi
        done
        flush_pairs
    fi

    # ── visible networks that aren't saved profiles ───────
    if [ "$radio" = enabled ]; then
        item "-- Available networks --"
        printf '%s\n' "$WIFI_ROWS" | cut -f3 | while IFS= read -r ssid; do
            [ -z "$ssid" ] && continue
            printf '%s\n' "$SAVED" | grep -Fxq -- "$ssid" && continue
            sig=$(wifi_field "$ssid" 1)
            sec=$(wifi_field "$ssid" 2)
            pair "  $ssid  [${sig}% ${sec:-open}]" "CONNECT_NEW|$ssid|$sec"
        done
        flush_pairs
    fi

    # ── present ───────────────────────────────────────────
    choice=$(pick -p "Network" < "$tmp/i") || exit 0
    [ -z "${choice:-}" ] && exit 0
    idx=$(grep -n -F -x -- "$choice" "$tmp/i" | head -1 | cut -d: -f1)
    [ -z "$idx" ] && exit 0
    act=$(sed -n "${idx}p" "$tmp/a")

    # ── act ───────────────────────────────────────────────
    case "$act" in
        NONE)      continue ;;                              # header row → redraw
        CLOSE)     exit 0 ;;
        RESCAN)
            nmcli device wifi rescan >/dev/null 2>&1
            sleep 2
            continue ;;
        WIFI_ON)
            nmcli radio wifi on >/dev/null 2>&1
            sleep 1
            continue ;;
        WIFI_OFF)
            nmcli radio wifi off >/dev/null 2>&1
            notify "Wi-Fi turned off"
            continue ;;
        ETH_UP)
            if nmcli device connect "$(printf '%s' "$eth" | cut -d: -f1)" >/dev/null 2>&1; then
                notify "Ethernet connected"
            else
                notify "Could not bring up Ethernet"
            fi
            exit 0 ;;
        DISCONNECT)
            if nmcli device disconnect "$IFACE" >/dev/null 2>&1; then
                notify "Disconnected from $active_ssid"
            else
                notify "Could not disconnect $active_ssid"
            fi
            exit 0 ;;
        CONNECT_SAVED\|*)
            ssid=${act#CONNECT_SAVED|}
            # stored secrets first; fall back to asking for the password
            if nmcli connection up id "$ssid" >/dev/null 2>&1; then
                notify "Connected to $ssid"
                exit 0
            fi
            pass=$("$ROFI_BIN" -dmenu -password -i -p "$ssid password") || exit 0
            if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
                notify "Connected to $ssid"
            else
                notify "Could not connect to $ssid" "Wrong password, or out of range."
            fi
            exit 0 ;;
        CONNECT_NEW\|*)
            rest=${act#CONNECT_NEW|}
            ssid=${rest%%|*}
            sec=${rest#*|}
            if [ -z "$sec" ]; then
                if nmcli device wifi connect "$ssid" >/dev/null 2>&1; then
                    notify "Connected to $ssid"
                else
                    notify "Could not connect to $ssid"
                fi
                exit 0
            fi
            pass=$("$ROFI_BIN" -dmenu -password -i -p "$ssid password") || exit 0
            if nmcli device wifi connect "$ssid" password "$pass" >/dev/null 2>&1; then
                notify "Connected to $ssid"
            else
                notify "Could not connect to $ssid" "Wrong password, or out of range."
            fi
            exit 0 ;;
        HIDDEN)
            ssid=$(ask -p "Hidden network SSID") || continue
            [ -z "${ssid:-}" ] && continue
            pass=$(ask -password -p "$ssid password (empty = open)") || continue
            if [ -n "${pass:-}" ]; then
                nmcli device wifi connect "$ssid" hidden yes password "$pass" >/dev/null 2>&1
            else
                nmcli device wifi connect "$ssid" hidden yes >/dev/null 2>&1
            fi
            if [ $? -eq 0 ]; then
                notify "Connected to $ssid"
            else
                notify "Could not connect to $ssid"
            fi
            exit 0 ;;
        FORGET)
            name=$(printf '%s\n' "$SAVED" | pick -p "Forget which network?") || continue
            [ -z "${name:-}" ] && continue
            confirm=$(printf 'No\nYes\n' | pick -p "Forget $name?")
            [ "$confirm" = Yes ] || continue
            if nmcli connection delete id "$name" >/dev/null 2>&1; then
                notify "Forgot $name"
            else
                notify "Could not forget $name"
            fi
            continue ;;
        IP_INFO)
            mac=$(cat "/sys/class/net/$IFACE/address" 2>/dev/null)
            {
                printf 'Device: %s (%s)\n' "$IFACE" "${wifi_state:-unknown}"
                printf 'Network: %s\n' "${active_ssid:-(none)}"
                printf 'MAC: %s\n' "${mac:-(unknown)}"
                printf 'IPv4: %s\n' "$(nmcli -g IP4.ADDRESS device show "$IFACE" 2>/dev/null | head -1)"
                printf 'Gateway: %s\n' "$(nmcli -g IP4.GATEWAY device show "$IFACE" 2>/dev/null | head -1)"
                printf 'DNS: %s\n' "$(nmcli -g IP4.DNS device show "$IFACE" 2>/dev/null | tr -d '\134' | paste -sd' ' -)"
                printf 'IPv6: %s\n' "$(nmcli -g IP6.ADDRESS device show "$IFACE" 2>/dev/null | tr -d '\134' | head -1)"
            } | pick -p "IP details" >/dev/null
            continue ;;
        *)
            continue ;;
    esac
done
