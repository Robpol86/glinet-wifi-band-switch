# glinet-wifi-band-switch

Prevent GL.iNet Beryl AX (GL-MT3000) from repeating on the same band and only bring up WiFi when there is internet available.

To install read the top comment in the main script: [wifi-band.sh](wifi-band.sh)

## Purpose

This script solves two annoyances I had with my Beryl:

1. When I returned to my hotel room and powered it on, my laptop would connect to the Beryl hotspot WiFi but I had no
   internet. Sometimes internet wouldn't work until I had my laptop disconenct from the Beryl and then re-connect, which
   instantly gave me internet. I suspect this had something to do with DNS caching on my MacBook.
2. Every time I connected the Beryl to the hotel WiFI I would need to manually disable the 2.4g or 5g hotspot, depending on
   which band (frequency, 5 GHz or 2.4 GHz with the Beryl) the hotel WiFi was on. I did this to avoid repeating on the same
   WiFi band and thus halfing my internet speed. Some of these hotels gave me over 100 Mbit of internet over WiFi!

This script solves both problems. When enabled it detects which band the Beryl is connected to and then disables the same
frequency hotspot and ensures the other frequency is enabled. It also waits until internet is detected before enablin the
other frequency.

Of course when I go to a new hotel the Beryl won't have internet. For these situations the side switch on the device can be
set to OFF which disables this script and enables both hotspot bands. Once I get the device connected to hotel WiFi I can set
the switch back to ON to resume this script's functionality.

## Debugging Tips

I use this to read logs quickly since there's no `ctrl+r` in ASH. I put it in `~/.profile`.

```bash
lr () ( set -x; logread -e wifi-band -f; )
```
