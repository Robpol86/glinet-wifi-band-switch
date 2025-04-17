# glinet-wifi-band-switch

Switch off the wireless AP on the band used to access the internet in repeater mode

## TODOs

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

### Connect to internet WiFi event

- [ ] Fire immediately when the router connects to a wireless network
- [ ] Find out which band is used
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
