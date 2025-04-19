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

# Ensure script runs once at a time.
single_instance() {
    : # TODO if priority is running kill self, else kill other instance
}
single_instance_priority() {
    : # TODO kill all other instances and run this one
}

# Returns 0 if $TOGGLE_BAND_ONLY == true
toggle_band_only() {
    [ $TOGGLE_BAND_ONLY = true ]
}

# Wrapper for `uci set`.
uci_set() {
    debug "uci set $1"
    uci set "$1"
    debug "uci commit"
    uci commit
}

# Enable/disable repeater bands.
enable_2g() {
    info "Enabling wifi2g"
    uci_set "wireless.wifi2g.disabled='0'"
}
enable_5g() {
    info "Enabling wifi5g"
    uci_set "wireless.wifi5g.disabled='0'"
}
disable_2g() {
    info "Disabling wifi2g"
    uci_set "wireless.wifi2g.disabled='1'"
}
disable_5g() {
    info "Disabling wifi5g"
    uci_set "wireless.wifi5g.disabled='1'"
}

# Wrapper for `ubus call`.
ubus_call() {
    output="$(ubus call "$@" |jsonfilter -e @)"
    debug "ubus call $*: $output"
    echo "$output"
}

# Wait for repeater to connect and then get the band it's using.
get_current_band() {
    until ubus_call repeater status |jsonfilter -e @.state_s |grep -q '^connected$'; do
        sleep 1
    done
    # TODO wireless.mt798112.band |grep -E '^(2g|5g)$' || true
}

# TODO
wait_for_online() {
    : # TODO until timeout ping; do sleep; done
}

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
    # TODO uci_get wrapper with debug logging
    uci get switch-button.@main[0].func 2>/dev/null |grep -q "^$BASENAME$"
}

# TODO
do_toggled_off() {
    info "Toggle switch OFF"
    disable_hotplug
    enable_2g
    enable_5g
}

# TODO
do_toggled_on() {
    info "Toggle switch ON"
    enable_hotplug
}

# TODO
do_wwan_connected() {
    debug "ifup: ACTION=$ACTION DEVICE=${DEVICE:-} INTERFACE=$INTERFACE"
    if ! toggle_band_only; then
        debug "TODO Wait for internet"
    fi
}

# If wwan disconnected
do_wwan_disconnected() {
    if ! toggle_band_only; then
        disable_2g
        disable_5g
    fi
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
    do_toggled_off
elif [ "$1" = on ]; then
    single_instance
    do_toggled_on
elif [ "$ACTION" = ifup ]; then
    single_instance
    do_wwan_connected
elif [ "$ACTION" = ifdown ]; then
    single_instance
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
