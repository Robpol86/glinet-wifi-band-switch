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
TOGGLE_BAND_ONLY=false  # Set to true if you don't want to bring WiFi down until internet is available.

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

# Enable/disable being called when the WWAN interface connects or disconnects.
enable_hotplug() {
    debug "Creating $HOTPLUG_D_IFACE_SYMLINK symlink"
    ln -f -s "$0" "$HOTPLUG_D_IFACE_SYMLINK" || errex "Failed to create symlink $HOTPLUG_D_IFACE_SYMLINK"
}
disable_hotplug() {
    if [ -L "$HOTPLUG_D_IFACE_SYMLINK" ]; then
        debug "Removing $HOTPLUG_D_IFACE_SYMLINK symlink"
        rm -f "$HOTPLUG_D_IFACE_SYMLINK"
    fi
}

# Returns 0 if script enabled in web UI.
is_assigned_to_switch() {
    uci get switch-button.@main[0].func 2>/dev/null |grep -q "^$BASENAME$"
}

# TODO
do_toggled_on() {
    info "Toggle switch ON"
    enable_hotplug
}

# TODO
do_toggled_off() {
    info "Toggle switch OFF"
    disable_hotplug
}

# TODO
do_wwan_connected() {
    debug "ifup: ACTION=$ACTION DEVICE=${DEVICE:-} INTERFACE=$INTERFACE"
    if [ $TOGGLE_BAND_ONLY != true ]; then
        debug "TODO Wait for internet"
    fi
}

# TODO
do_wwan_disconnected() {
    debug "ifdown: ACTION=$ACTION DEVICE=${DEVICE:-} INTERFACE=$INTERFACE"
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
if [ "$1" = on ]; then
    do_toggled_on
elif [ "$1" = off ]; then
    do_toggled_off
elif [ "$ACTION" = ifup ]; then
    do_wwan_connected
elif [ "$ACTION" = ifdown ]; then
    do_wwan_disconnected
else
    debug "ACTION=$ACTION not ifup|ifdown, ignoring"
    exit 0
fi

# TODOs:
#   - Single instance, new instance always instantly kills the old instance
#       - Except when toggling OFF, that takes priority
#       - gl-switch and hotplug both block and queue, so max of 2 instances expected
#   - trap set -e with error to logger
