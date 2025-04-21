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

BASENAME="$(basename "${0%.*}")"
HOTPLUG_SCRIPT="/etc/hotplug.d/iface/10-$BASENAME"
LOCKFILE="/var/lock/$BASENAME.lock"
PIDFILE="/var/run/$BASENAME.pid"
LOCKTIMEOUT=10

repeater_status_device=
repeater_status_portal=
repeater_status_state_s=

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

# Kill a running instance and run this one exclusively.
single_instance() {
    starttime="$(date +%s)"
    killattempt=
    # Release any inherited locks.
    grep -lE "FLOCK\s*ADVISORY" /proc/self/fdinfo/* |while read -r fdinfo; do
        num="${fdinfo##*/}"
        debug "Releasing lock on fd $num"
        flock -u "$num"
    done
    # Open lock file.
    exec 9>"$LOCKFILE"
    # Obtain the lock.
    until flock -n 9; do
        # Priority instances can kill all but non-priority exit if priority is running.
        if [ "${1:-}" != priority ] && grep -q priority "$PIDFILE"; then
            errex "Priority instance running"
        fi
        # Get other instance PID and kill it.
        if [ -z "$killattempt" ] && target_pid="$(grep -Eo "^\d+" "$PIDFILE")"; then
            lockfile_id="$(grep ^lock: "/proc/$target_pid/fdinfo/9" 2>/dev/null |awk '{print $7}')"
            if [ -n "$lockfile_id" ]; then
                killattempt=1
                debug "Killing other instance $target_pid"
                { kill -9 "-$target_pid" || kill -9 "$target_pid" || true; } 2>/dev/null
                # Kill all processes holding the lock.
                grep -lE "^lock:.+\s$lockfile_id\s" /proc/[0-9]*/fdinfo/* 2>/dev/null |awk -F/ '{print $3}' |while read -r child_pid; do
                    debug "Killing child process $child_pid"
                    kill -9 "$child_pid" 2>/dev/null || true
                done
            fi
        fi
        # Timeout.
        now="$(date +%s)"
        if [ $(( now - starttime )) -gt "$LOCKTIMEOUT" ]; then
            errex "Timed out waiting for lock"
        fi
        # Sleep.
        usleep 250000
    done
    debug "Obtained lock"
    [ "${1:-}" = priority ] && echo "$$:priority" >"$PIDFILE" || echo "$$" >"$PIDFILE"
}

update_repeater_status() {
    debug "Updating repeater status"
    out="$(ubus call repeater status |jsonfilter -e @)"
    repeater_status_device="$(echo "$out" |jsonfilter -e @.device)"
    repeater_status_portal="$(echo "$out" |jsonfilter -e @.portal)"
    repeater_status_state_s="$(echo "$out" |jsonfilter -e @.state_s)"
}

# Enable/disable repeater bands.
toggle_bands() {
    if printf '%s\n' "$@" |grep -qE '^(enable_2g)$'; then
        info "Enabling wifi2g"
        uci set wireless.wifi2g.disabled=0
    fi
    if printf '%s\n' "$@" |grep -qE '^(disable_2g)$'; then
        info "Disabling wifi2g"
        uci set wireless.wifi2g.disabled=1
    fi
    if printf '%s\n' "$@" |grep -qE '^(enable_5g)$'; then
        info "Enabling wifi5g"
        uci set wireless.wifi5g.disabled=0
    fi
    if printf '%s\n' "$@" |grep -qE '^(disable_5g)$'; then
        info "Disabling wifi5g"
        uci set wireless.wifi5g.disabled=1
    fi
    uci commit wireless
    wifi
}

# Wait for repeater to connect and then get the band it's using.
get_current_band() {
    until update_repeater_status && echo "$repeater_status_state_s" |grep -q '^connected$'; do
        debug "Waiting for repeater to connect"
        sleep 1
    done
    band="$(uci get "wireless.$repeater_status_device.band")"
    info "Connected on band $band"
    echo "$band"
}

# Wait until there is internet available or if portal detected.
is_online() {
    if uci get vpnpolicy.global.kill_switch |grep -q '^1$'; then
        timeout 1 ping -I ovpnclient -c1 google.com >/dev/null 2>&1
    else
        timeout 1 ping -c1 google.com >/dev/null 2>&1
    fi
}
is_portal() {
    update_repeater_status && [ "$repeater_status_portal" = "true" ]
}
wait_for_portal_or_online() {
    while true; do
        if is_online; then
            info "Internet detected"
            break
        elif is_portal; then
            info "Portal detected"
            break
        else
            debug "Waiting for internet"
            sleep 1
        fi
    done
}

# Enable/disable being called when the WWAN interface connects or disconnects.
enable_hotplug() {
    debug "Creating $HOTPLUG_SCRIPT"
    { cat > "$HOTPLUG_SCRIPT" <<EOF
#!/bin/sh
"$0" \$@ &
EOF
    } || errex "Failed to create $HOTPLUG_SCRIPT"
    chmod +x "$HOTPLUG_SCRIPT" || errex "Failed to make $HOTPLUG_SCRIPT executable"
}
disable_hotplug() {
    if [ -e "$HOTPLUG_SCRIPT" ]; then
        debug "Removing $HOTPLUG_SCRIPT"
        rm -f "$HOTPLUG_SCRIPT"
    fi
}
is_hotplug_enabled() {
    [ -e "$HOTPLUG_SCRIPT" ]
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
        toggle_bands enable_5g disable_2g
        ;;
    5g)
        toggle_bands enable_2g disable_5g
        ;;
    *)
        error "Unexpected band: $band"
        toggle_bands enable_2g enable_5g
        ;;
    esac
}

# Main action when user toggles the switch OFF (also called on boot with the initial switch state of OFF).
do_toggled_off() {
    toggle_bands enable_2g enable_5g
}

# Main action when user toggles the switch ON (also called on boot with the initial switch state of ON).
do_toggled_on() {
    if is_online; then
        info "Internet detected"
    elif is_portal; then
        info "Portal detected"
    else
        info "No internet, stopping wifi"
        toggle_bands disable_2g disable_5g
        wait_for_portal_or_online
    fi
    great_decider
}

# Main action when the repeater connects to a WiFi network.
do_wwan_connected() {
    wait_for_portal_or_online
    great_decider
}

# Main action when the repeater loses connection.
do_wwan_disconnected() {
    toggle_bands disable_2g disable_5g
}

# Bad arguments.
if printf '%s\n' "$@" |grep -qE '^(-h|--help|help|[/-][?])$'; then
    errex "more info: https://github.com/Robpol86/glinet-wifi-band-switch"
elif [ $# -ne 1 ]; then
    errex "requires exactly 1 argument"
elif [ "$1" != on ] && [ "$1" != do_toggled_on ] && [ "$1" != off ] && [ "$1" != iface ]; then
    errex "bad argument, expected on|off|iface but got $1"
elif [ "$1" = iface ]; then
    [ -n "${ACTION:-}" ] || errex "Missing ACTION variable"
    [ -n "${INTERFACE:-}" ] || errex "Missing INTERFACE variable"
    if [ "$INTERFACE" != wwan ]; then
        debug "INTERFACE=$INTERFACE not wwan, ignoring"
        exit 0
    fi
fi

# Single instance.
if [ "$1" = off ]; then
    single_instance priority # In case hotplug runs at the same time switch is toggled off
else
    single_instance
fi

# Main
if ! is_assigned_to_switch; then
    disable_hotplug
    errex "Not enabled. In the web UI go to System > Toggle Button Settings to enable."
fi
if [ "$1" = off ]; then
    info "Toggle switch OFF"
    disable_hotplug
    do_toggled_off
elif [ "$1" = on ]; then
    info "Toggle switch ON"
    enable_hotplug
    "$0" do_toggled_on &
    info "Continuing in process $!"
    exit 0
elif [ "$1" = do_toggled_on ]; then
    do_toggled_on
elif [ "$ACTION" = ifup ]; then
    info "WWAN interface connected"
    is_hotplug_enabled || errex "Hotplug no longer enabled" # In case hotplug-call queued instances after toggled off
    do_wwan_connected
elif [ "$ACTION" = ifdown ]; then
    info "WWAN interface disconnected"
    is_hotplug_enabled || errex "Hotplug no longer enabled"
    do_wwan_disconnected
else
    debug "ACTION=$ACTION not ifup|ifdown, ignoring"
    exit 0
fi
info Done

# TODOs:
#   - ping 4.2.2.1
