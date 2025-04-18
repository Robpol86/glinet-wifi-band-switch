#!/bin/sh

# TODO save to /etc/hotplug.d/iface/10-wifi-band
# TODO ln -s /etc/hotplug.d/iface/10-wifi-band /etc/gl-switch.d/wifi-band.sh

set -o errexit  # Exit script if a command fails.
set -o nounset  # Treat unset variables as errors and exit immediately.

INPUT_IFUP_ACTION="${ACTION:-}"
INPUT_IFUP_DEVICE="${DEVICE:-}"
INPUT_IFUP_INTERFACE="${INTERFACE:-}"
INPUT_TOGGLE="${1:-}"

# Log and print messages to stderr.
_log() {
    level="$1";
    shift;
    logger -s -t "$(basename "$0")[$$]" -p "$level" "$*"
}
error() { _log err "$*"; }
warning() { _log warn "$*"; }
info() { _log notice "$*"; }
debug() { _log debug "$*"; }

# Main.
if [ -n "$INPUT_TOGGLE" ]; then
    debug "Toggle switch action: $1"
elif [ "$INPUT_IFUP_ACTION" = "ifup" ]; then
    debug "ifup: ACTION=$INPUT_IFUP_ACTION DEVICE=$INPUT_IFUP_DEVICE INTERFACE=$INPUT_IFUP_INTERFACE"
else
    debug "Unknown action"
    env > /tmp/dump.txt
fi
