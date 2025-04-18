# glinet-wifi-band-switch

Prevent GL.iNet GL-MT3000 from repeating on the same band and only bring up WiFi when there is internet available.

## Proposed Flow

- Feature not enabled
    - Noop
- Toggled from ON to OFF
    - Both repeater bands ENABLED
- Toggled from OFF to ON
    - If no internet
        - Both repeater bands DISABLED
    - If connected to 5 GHz
        - 2.4 GHz repeater band ENABLED
        - 5 GHz repeater band DISABLED
    - If connected to 2.4 GHz
        - 5 GHz repeater band ENABLED
        - 2.4 GHz repeater band DISABLED
- On connect:
    - Toggle switched OFF
        - Noop
    - Until internet
        - Both repeater bands DISABLED
    - If connected to 5 GHz
        - 2.4 GHz repeater band ENABLED
        - 5 GHz repeater band DISABLED
    - If connected to 2.4 GHz
        - 5 GHz repeater band ENABLED
        - 2.4 GHz repeater band DISABLED
- On disconnect:
    - Toggle switched OFF
        - Noop
    - Else
        - Both repeater bands DISABLED
- On boot:
    - Toggle switched OFF
        - Noop
    - Else
        - TODO avoid race conditions

Single script that accepts both events as entrypoints. Implement single-instance with lock file. On new instance always kill
old instance.

## Hooks

Find these APIs, hooks, or entrypoints:

### Toggle switch state

- [x] Fire immediately when switch is toggled and get the on or off state.

```bash
# Adds a new dropdown entry to /#/btnsettings automatically in the Web UI
tee /etc/gl-switch.d/wifi-band.sh <<'EOF'
#!/bin/sh
. /lib/functions/gl_util.sh

action="$1"  # "on" or "off"

logger "wifi-band switch $action"
echo "$(date) switch $action" >> /tmp/wifi-band.log
EOF
chmod +x /etc/gl-switch.d/wifi-band.sh
# If feature enabled (in the dropdown) then /etc/gl-switch.d/wifi-band.sh runs on boot regardless of switch state
# If user enables the feature whilst the switch is ON nothing will happen
```

- [ ] Read the state of the switch without needing to toggle it.

Seems like there's no way to do this. Instead maybe `uci set myscript.switch_state=on`?

```
if [ "$ACTION" = "pressed" ]; then
    uci set myscript.switch_state=on
else
    uci set myscript.switch_state=off
fi
uci commit myscript
```

- [x] Check if toggle switch is set to wifi-band

```bash
uci get switch-button.@main[0].func |grep -q '^wifi-band$'
```

### Connect to internet WiFi event

- [x] Fire immediately when the router connects to a wireless network

```bash
tee /etc/hotplug.d/iface/11-wifi-band <<'EOF'
#!/bin/sh
logger "11-wifi-band INTERFACE='$INTERFACE' ACTION='$ACTION' DEVICE='$DEVICE'"
date >> /tmp/dump.txt
env >> /tmp/dump.txt
EOF
chmod +x /etc/hotplug.d/iface/11-wifi-band

# Above logged this when I manually reconnected to a coffee shop wifi network:
# Thu Apr 17 14:21:15 2025 user.notice root: wifi-band INTERFACE='wwan' ACTION='ifdown' DEVICE=''
# Thu Apr 17 14:21:23 2025 user.notice root: wifi-band INTERFACE='wwan' ACTION='ifup' DEVICE='apclix0'
# Thu Apr 17 14:21:42 2025 user.notice root: wifi-band INTERFACE='wwan' ACTION='ifdown' DEVICE=''
# Thu Apr 17 14:23:03 2025 user.notice root: wifi-band INTERFACE='wwan' ACTION='ifup' DEVICE='apclix0'
# It kept bringing down and up the repeater AP, probably because DFS is enabled
# This was also dumped:
# Thu Apr 17 14:21:15 CEST 2025
    # USER=root
    # ACTION=ifdown
    # SHLVL=1
    # HOME=/
    # HOTPLUG_TYPE=iface
    # LOGNAME=root
    # DEVICENAME=
    # TERM=linux
    # PATH=/usr/sbin:/usr/bin:/sbin:/bin
    # INTERFACE=wwan
    # PWD=/
# Thu Apr 17 14:21:23 CEST 2025
    # USER=root
    # ACTION=ifup
    # SHLVL=1
    # HOME=/
    # HOTPLUG_TYPE=iface
    # LOGNAME=root
    # DEVICENAME=
    # TERM=linux
    # PATH=/usr/sbin:/usr/bin:/sbin:/bin
    # INTERFACE=wwan
    # PWD=/
    # DEVICE=apclix0
# Thu Apr 17 14:21:42 CEST 2025
    # USER=root
    # ACTION=ifdown
    # SHLVL=1
    # HOME=/
    # HOTPLUG_TYPE=iface
    # LOGNAME=root
    # DEVICENAME=
    # TERM=linux
    # PATH=/usr/sbin:/usr/bin:/sbin:/bin
    # INTERFACE=wwan
    # PWD=/
# Thu Apr 17 14:23:03 CEST 2025
    # USER=root
    # ACTION=ifup
    # SHLVL=1
    # HOME=/
    # HOTPLUG_TYPE=iface
    # LOGNAME=root
    # DEVICENAME=
    # TERM=linux
    # PATH=/usr/sbin:/usr/bin:/sbin:/bin
    # INTERFACE=wwan
    # PWD=/
    # DEVICE=apclix0
# Seems to not fire the script when repeater bands are toggled on/off.
```

- [ ] Find out which band is used

```bash
ubus call repeater status
# Run the above to get JSON state of the repeater
# This is when it's not connected, state failed to connect
# {
# 	"config": {
# 		"ssid": "Le Cafe Fokus",
# 		"protocol": "dhcp",
# 		"key": "xxxx",
# 		"remember": true,
# 		"disguise": false,
# 		"manual": false,
# 		"auto_portal": false,
# 		"macaddr": {
# 			"mode": "random",
# 			"update": "none",
# 			"macaddr": "xxxx"
# 		}
# 	},
# 	"state": 3,
# 	"state_s": "failed",
# 	"running": false,
# 	"fail_type": "not-found"
# }
# When connecting:
	# "state": 1,
	# "state_s": "connecting",
	# "running": true,
	# "fail_type": ""
# When connected to 2g:
# {
# 	"ssid": "Le Cafe Fokus",
# 	"running": true,
# 	"config": {
# 		"ssid": "Le Cafe Fokus",
# 		"protocol": "dhcp",
# 		"key": "xxxx",
# 		"remember": true,
# 		"disguise": false,
# 		"manual": false,
# 		"auto_portal": false,
# 		"macaddr": {
# 			"mode": "random",
# 			"update": "none",
# 			"macaddr": "xxxx"
# 		}
# 	},
# 	"channel": 6,
# 	"state": 2,
# 	"fail_type": "",
# 	"device": "mt798111",
# 	"portal": false,
# 	"state_s": "connected",
# 	"macaddr": "xxxx",
# 	"connected": "1s",
# 	"network": "wwan",
# 	"ipv4": {
# 		"dns": [
# 			"192.168.1.1"
# 		],
# 		"gateway": "192.168.1.1",
# 		"ip": "192.168.1.168/24"
# 	},
# 	"signal": -48,
# 	"bare_mode": false,
# 	"htmode": "HE40",
# 	"dfs": false,
# 	"bssid": "xxxx"
# }
# When connected to 5g:
# {
# 	"ssid": "Le Cafe Fokus",
# 	"running": true,
# 	"config": {
# 		"ssid": "Le Cafe Fokus",
# 		"protocol": "dhcp",
# 		"key": "xxxx",
# 		"remember": true,
# 		"disguise": false,
# 		"manual": false,
# 		"auto_portal": false,
# 		"macaddr": {
# 			"mode": "random",
# 			"update": "none",
# 			"macaddr": "xxxx"
# 		}
# 	},
# 	"channel": 100,
# 	"state": 2,
# 	"fail_type": "",
# 	"device": "mt798112",
# 	"portal": false,
# 	"state_s": "connected",
# 	"macaddr": "xxxx",
# 	"connected": "20s",
# 	"network": "wwan",
# 	"ipv4": {
# 		"dns": [
# 			"192.168.1.1"
# 		],
# 		"gateway": "192.168.1.1",
# 		"ip": "192.168.1.168/24"
# 	},
# 	"signal": -67,
# 	"bare_mode": false,
# 	"htmode": "HE80",
# 	"dfs": true,
# 	"bssid": "xxxx"
# }

```

- [ ] When the router reconnects this event should also fire

### Detect when there is internet available

- [ ] Fire event when internet is available and unavailable
- [ ] Wait for VPN and Adguard DNS to connect

### Change TX power

> Do not implement, changing power even though the web UI won't nudge clients off the lower power SSID.

- [x] Change TX power settings per band for the access point side of the router

```bash
dev="$(uci get wireless.wifi5g.device)"
uci set "wireless.$dev.txpower=30" && uci commit  # 30 == low, 100 == max
# TODO store original value in custom uci variable.
```

- [ ] Changes should reflect in the web UI immediately

### Enable/disable AP bands

- [x] Enable or disable WiFi bands for the access point side of the router

```bash
# Enable 5g (s/5g/2g/ for 2g):
uci set wireless.wifi5g.disabled='0' && uci commit
# TODO Option for guest network toggling: wireless.guest5g.disabled='0'
# Disable s/0/1/
```

- [ ] Changes should reflect in the web UI immediately

Does not, user has to refresh. Even two browser windows it won't update the other without refreshing.

### Which files survive firmware upgrades?

- [ ] Project should be non-volatile
- [ ] Files and settings should survive firmware upgrades

## Debugging Tips

I use this to read logs quickly since there's no `ctrl+r` in ASH.

```bash
lr () ( set -x; logread -e wifi-band -f; )
```

## TODOs

- When portal is detected don't disable all interfaces (`grep portal /etc/rc.button/switch`)
