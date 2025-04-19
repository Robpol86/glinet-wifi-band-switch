#!/bin/sh

# Prevent GL.iNet GL-MT3000 from repeating on the same band and only bring up
# WiFi when there is internet available.
#
# To install:
#   1. Save this script to /etc/gl-switch.d/wifi-band.sh (don't forget to chmod +x)
#       a. scp -O ./wifi-band.sh root@192.168.8.1:/etc/gl-switch.d/wifi-band.sh
#   2. In the GL.iNet web UI go to System > Toggle Button Settings and select this script
#   3. Set switch to ON (or if already on set it to OFF then ON)
# To view logging run:
#   logread -e wifi-band

set -o errexit  # Exit script if a command fails.
set -o nounset  # Treat unset variables as errors and exit immediately.

BASENAME=wifi-band  # Hardcoding because $0 is /sbin/hotplug-call when called from hotplug.d symlink.
HOTPLUG_D_IFACE_SYMLINK="/etc/hotplug.d/iface/10-$BASENAME"

# Log and print messages to stderr.
_log() {
    level="$1";
    shift;
    logger -s -t "$BASENAME""[$$]" -p "$level" "$*"
}
error() { _log err "$*"; }
errex() { _log err "$*"; exit 1; }
warning() { _log warn "$*"; }
info() { _log notice "$*"; }
debug() { _log debug "$*"; }

# Ensure script runs once at a time.
single_instance() {
    : # TODO if priority is running kill self, else kill other instance
}
single_instance_priority() {
    : # TODO kill all other instances and run this one
}

# Enable/disable repeater bands.
enable_2g() {
    info "Enabling wifi2g"
    uci set wireless.wifi2g.disabled='0' && uci commit
}
enable_5g() {
    info "Enabling wifi5g"
    uci set wireless.wifi5g.disabled='0' && uci commit
}
disable_2g() {
    info "Disabling wifi2g"
    uci set wireless.wifi2g.disabled='1' && uci commit
}
disable_5g() {
    info "Disabling wifi5g"
    uci set wireless.wifi5g.disabled='1' && uci commit
}

# Wait for repeater to connect and then get the band it's using.
get_current_band() {
    until ubus call repeater status |jsonfilter -e @.state_s |grep -q '^connected$'; do
        debug "Waiting for repeater to connect"
        sleep 1
    done
    device="$(ubus call repeater status |jsonfilter -e @.device)"
    debug "Conencted using $device"
    band="$(uci get "wireless.$device.band")"
    info "Connected on band $band"
    echo "$band"
}

# Wait until there is internet available. Blocks indefinitely on portal.
is_online() {
    timeout 1 ping -c1 google.com >/dev/null 2>&1
}
wait_for_online() {
    until is_online; do
        debug "Waiting for internet"
        sleep 1
    done
}

# Enable/disable being called when the WWAN interface connects or disconnects.
enable_hotplug() {
    debug "Creating $HOTPLUG_D_IFACE_SYMLINK symlink"
    ln -f -s "$0" "$HOTPLUG_D_IFACE_SYMLINK" || errex "Failed to create symlink $HOTPLUG_D_IFACE_SYMLINK"
}
disable_hotplug() {
    if [ -e "$HOTPLUG_D_IFACE_SYMLINK" ]; then
        debug "Removing $HOTPLUG_D_IFACE_SYMLINK symlink"
        rm -f "$HOTPLUG_D_IFACE_SYMLINK"
    fi
}
is_hotplug_enabled() {
    [ -e "$HOTPLUG_D_IFACE_SYMLINK" ]
}

# Returns 0 if script enabled in web UI.
is_assigned_to_switch() {
    uci get switch-button.@main[0].func 2>/dev/null |grep -q "^$BASENAME$"
}

# Toggles on/off the same band used to connect to the internet.
great_decider() {
    band="$(get_current_band)"  # Blocks until WiFi connected.
    case "$band" in
    2g)
        enable_5g
        disable_2g
        ;;
    5g)
        enable_2g
        disable_5g
        ;;
    *)
        error "Unexpected band: $band"
        enable_2g
        enable_5g
        ;;
    esac
}

# Main action when user toggles the switch OFF (also called on boot with the initial switch state of OFF).
do_toggled_off() {
    info "Toggle switch OFF"
    enable_2g
    enable_5g
}

# Main action when user toggles the switch ON (also called on boot with the initial switch state of ON).
do_toggled_on() {
    info "Toggle switch ON"
    if ! is_online; then
        info "No internet, stopping wifi"
        disable_2g
        disable_5g
        wait_for_online
    fi
    great_decider
}

# Main action when the repeater connects to a WiFi network.
do_wwan_connected() {
    info "WWAN interface connected"
    wait_for_online
    great_decider
}

# Main action when the repeater loses connection.
do_wwan_disconnected() {
    info "WWAN interface disconnected"
    disable_2g
    disable_5g
}

# Bad arguments.
if printf '%s\n' "$@" |grep -qE '^(-h|--help|help|[/-][?])$'; then
    errex "more info: https://github.com/Robpol86/glinet-wifi-band-switch"
elif [ $# -ne 1 ]; then
    errex "requires exactly 1 argument"
elif [ "$1" != on ] && [ "$1" != off ] && [ "$1" != iface ]; then
    errex "bad argument, expected on|off|iface but got $1"
elif [ "$1" = iface ]; then
    [ -n "${ACTION:-}" ] || errex "Missing ACTION variable"
    [ -n "${INTERFACE:-}" ] || errex "Missing INTERFACE variable"
    if [ "$INTERFACE" != wwan ]; then
        debug "INTERFACE=$INTERFACE not wwan, ignoring"
        exit 0
    fi
fi

# Main
if ! is_assigned_to_switch; then
    disable_hotplug
    errex "Not enabled. In the web UI go to System > Toggle Button Settings to enable."
fi
if [ "$1" = off ]; then
    single_instance_priority # In case hotplug runs at the same time switch is toggled off
    disable_hotplug
    do_toggled_off
elif [ "$1" = on ]; then
    single_instance
    enable_hotplug
    do_toggled_on
elif [ "$ACTION" = ifup ]; then
    single_instance
    is_hotplug_enabled || errex "Hotplug no longer enabled" # In case hotplug-call queued instances after toggled off
    do_wwan_connected
elif [ "$ACTION" = ifdown ]; then
    single_instance
    is_hotplug_enabled || errex "Hotplug no longer enabled"
    do_wwan_disconnected
else
    debug "ACTION=$ACTION not ifup|ifdown, ignoring"
    exit 0
fi
