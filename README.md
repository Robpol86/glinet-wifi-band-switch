# glinet-wifi-band-switch

Prevent GL.iNet GL-MT3000 from repeating on the same band and only bring up WiFi when there is internet available.

To install read the top comment in the main script: [wifi-band.sh](wifi-band.sh)

## Debugging Tips

I use this to read logs quickly since there's no `ctrl+r` in ASH.

```bash
lr () ( set -x; logread -e wifi-band -f; )
```
