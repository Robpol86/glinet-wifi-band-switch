# glinet-wifi-band-switch

Prevent GL.iNet GL-MT3000 from repeating on the same band and only bring up WiFi when there is internet available.

## Hooks

Find these APIs, hooks, or entrypoints:

### Toggle switch state

- [x] Fire immediately when switch is toggled and get the on or off state.

```bash
# from https://github.com/AzulEterno/openwrt-nlbwmoncomitter/blob/main/etc/hotplug.d/button/10-buttons
# View log statements with: logread -l 10
mkdir /etc/hotplug.d/button
echo 'logger "button $BUTTON action $ACTION"' |tee /etc/hotplug.d/button/10-log

# Above fires immediately when toggled. Logs these messages:
# Thu Apr 17 12:57:37 2025 user.notice root: button switch action released
# Thu Apr 17 12:57:52 2025 user.notice root: button switch action pressed

tee /etc/gl-switch.d/wifi-band.sh <<'EOF'
#!/bin/sh
. /lib/functions/gl_util.sh

action=$1

logger "ACTION: $action"
EOF

# Above adds a new dropdown entry to /#/btnsettings automatically in the Web UI
# Thu Apr 17 13:44:58 2025 user.notice gl-switch: switch pressed
# Thu Apr 17 13:44:58 2025 user.notice root: ACTION: on
# Thu Apr 17 13:45:00 2025 user.notice gl-switch: switch released
# Thu Apr 17 13:45:00 2025 user.notice root: ACTION: off
```

- [ ] Read the state of the switch without needing to toggle it.

- [x] Check if toggle switch is set to wifi-band

```bash
uci get switch-button.@main[0].func |grep -q '^wifi-band$'
```

### Connect to internet WiFi event

- [x] Fire immediately when the router connects to a wireless network

```bash
tee /etc/hotplug.d/iface/10-wifi-band <<'EOF'
#!/bin/sh
logger "wifi-band INTERFACE='$INTERFACE' ACTION='$ACTION' DEVICE='$DEVICE'"
date >> /tmp/dump.txt
env >> /tmp/dump.txt
EOF
chmod +x /etc/hotplug.d/iface/10-wifi-band

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

- [ ] Change TX power settings per band for the access point side of the router
- [ ] Changes should reflect in the web UI immediately

### Enable/disable AP bands

- [ ] Enable or disable WiFi bands for the access point side of the router
- [ ] Changes should reflect in the web UI immediately

### Which files survive firmware upgrades?

- [ ] Project should be non-volatile
- [ ] Files and settings should survive firmware upgrades

## Proposed Flow

- Toggle switched OFF
    - Both repeater bands ENABLED
- Toggle switched ON
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
        - Both repeater bands ENABLED
    - Until internet
        - Both repeater bands DISABLED
    - If connected to 5 GHz
        - 2.4 GHz repeater band ENABLED
    - If connected to 2.4 GHz
        - 5 GHz repeater band ENABLED
- On disconnect:
    - Toggle switched OFF
        - Both repeater bands ENABLED
    - Else
        - Both repeater bands DISABLED

Single script that accepts both events as entrypoints. Implement single-instance with lock file. On new instance always kill
old instance.

TODO when portal is detected don't disable all interfaces.
