# glinet-wifi-band-switch

Switch off the wireless AP on the band used to access the internet in repeater mode

## TODOs

Find these APIs, hooks, or entrypoints:

### Toggle switch state

- Fire immediately when switch is toggled and get the on or off state.
- Read the state of the switch without needing to toggle it.

### Connect to internet WiFi event

- Fire immediately when the router connects to a wireless network
- Find out which band is used.
- When the router reconnects this event should also fire

### Detect when there is internet available

- Fire event when internet is available and unavailable
- Wait for VPN and Adguard DNS to connect

### Change TX power

- Change TX power settings per band for the access point side of the router.
- Changes should reflect in the web UI immediately

### Enable/disable AP bands

- Enable or disable WiFi bands for the access point side of the router.
- Changes should reflect in the web UI immediately
