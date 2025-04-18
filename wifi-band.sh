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

BASENAME=wifi-band  # Hardcoding because $0 is sometimes /sbin/hotplug-call
HOTPLUG_D_IFACE_SYMLINK=/etc/hotplug.d/iface/10-wifi-band
TOGGLE_BAND_ONLY=false  # Set to true if you don't want to bring WiFi down until internet is available.

# Log and print messages to stderr.
_log() {
    level="$1";
    shift;
    logger -s -t "$BASENAME[$$]" -p "$level" "10-wifi-band: $*"
}
error() { _log err "$*"; }
errex() { _log err "$*"; exit 1; }
warning() { _log warn "$*"; }
info() { _log notice "$*"; }
debug() { _log debug "$*"; }

# Print usage to stderr.
usage() {
cat >&2 <<EOF
usage: $BASENAME -h
       $BASENAME on
       $BASENAME off
       $BASENAME iface
EOF
}

# Enable/disable being called when the WWAN interface connects or disconnects.
enable() {
    # TODO conditional
    debug "Creating $HOTPLUG_D_IFACE_SYMLINK symlink"
    ln -f -s /etc/gl-switch.d/wifi-band.sh "$HOTPLUG_D_IFACE_SYMLINK"
}
disable() {
    if [ -L "$HOTPLUG_D_IFACE_SYMLINK" ]; then
        debug "Removing $HOTPLUG_D_IFACE_SYMLINK symlink"
        rm -f "$HOTPLUG_D_IFACE_SYMLINK"
    fi
}

# Returns 0 if script enabled in web UI.
is_enabled() {
    uci get switch-button.@main[0].func 2>/dev/null |grep -q "^$BASENAME$"
}

# Usage.
if printf '%s\n' "$@" |grep -qE '^(-h|--help)$'; then
    usage
    exit 0
elif [ $# -ne 1 ]; then
    echo "need exactly one argument" >&2
    exit 2
fi

# Main
if ! is_enabled; then
    error "Not enabled. In the web UI go to System > Toggle Button Settings to enable."
    exit 1
fi
if [ "$MODE" = on ]; then
    debug "Toggle switch ON"
    enable
elif [ "$MODE" = off ]; then
    debug "Toggle switch OFF"
    disable
elif [ -n "$MODE" ]; then
    error "Unknown toggle switch action: $1"
    usage
    exit 2
elif [ "$INPUT_IFUP_ACTION" = ifup ]; then
    debug "ifup: ACTION=$INPUT_IFUP_ACTION DEVICE=$INPUT_IFUP_DEVICE INTERFACE=$INPUT_IFUP_INTERFACE"
elif [ "$INPUT_IFUP_ACTION" = ifdown ]; then
    debug "ifdown: ACTION=$INPUT_IFUP_ACTION DEVICE=$INPUT_IFUP_DEVICE INTERFACE=$INPUT_IFUP_INTERFACE"
elif [ -n "$INPUT_IFUP_ACTION" ]; then
    set > "/tmp/$BASENAME.txt"  # TODO remove
    error "Unknown action: $INPUT_IFUP_ACTION"
    usage
    exit 2
else
    set > "/tmp/$BASENAME.txt"  # TODO remove
    usage
    exit 2
fi

# TODOs:
#   - Unknown toggle switch action: iface
#   - Single instance, new instance always instantly kills the old instance
