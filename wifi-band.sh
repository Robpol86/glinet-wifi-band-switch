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

BASENAME="$(basename "$0")"
INPUT_IFUP_ACTION="${ACTION:-}"
INPUT_IFUP_DEVICE="${DEVICE:-}"
INPUT_IFUP_INTERFACE="${INTERFACE:-}"
INPUT_TOGGLE="${1:-}"
TOGGLE_BAND_ONLY=false  # Set to true if you don't want to bring WiFi down until internet is available.

# Log and print messages to stderr.
_log() {
    level="$1";
    shift;
    logger -s -t "$BASENAME[$$]" -p "$level" "$*"
}
error() { _log err "$*"; }
errex() { _log err "$*"; exit 1; }
warning() { _log warn "$*"; }
info() { _log notice "$*"; }
debug() { _log debug "$*"; }

# Print usage to stderr and exit.
usage() {
    echo "Usage: $BASENAME [on|off]" >&2
    echo "Usage: ACTION=[ifup|ifdown] $BASENAME" >&2
}

# Finish installing script.
install() {
    # TODO conditional
    debug "Creating /etc/hotplug.d/iface/10-wifi-band symlink"
    ln -f -s /etc/gl-switch.d/wifi-band.sh /etc/hotplug.d/iface/10-wifi-band
}

# Main.
if printf '%s\n' "$@" |grep -qE '^(-h|--help)$'; then
    usage
    exit 0
fi
install
if [ "$INPUT_TOGGLE" = on ]; then
    debug "Toggle switch ON"
elif [ "$INPUT_TOGGLE" = off ]; then
    debug "Toggle switch OFF"
elif [ -n "$INPUT_TOGGLE" ]; then
    error "Unknown toggle switch action: $1"
    usage
    exit 2
elif [ "$INPUT_IFUP_ACTION" = ifup ]; then
    debug "ifup: ACTION=$INPUT_IFUP_ACTION DEVICE=$INPUT_IFUP_DEVICE INTERFACE=$INPUT_IFUP_INTERFACE"
elif [ "$INPUT_IFUP_ACTION" = ifdown ]; then
    debug "ifdown: ACTION=$INPUT_IFUP_ACTION DEVICE=$INPUT_IFUP_DEVICE INTERFACE=$INPUT_IFUP_INTERFACE"
elif [ -n "$INPUT_IFUP_ACTION" ]; then
    error "Unknown action: $INPUT_IFUP_ACTION"
    usage
    exit 2
else
    set > "/tmp/$BASENAME.txt"  # TODO remove
    usage
    exit 2
fi

# TODOs:
#   - hotplug-call instead of BASENAME
#   - Unknown toggle switch action: iface
