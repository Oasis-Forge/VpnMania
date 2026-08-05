# Windows live-tunnel verification checklist

Use this after a VPS is bootstrapped and `assets/config/servers.local.json` exists.

## Preflight

- [ ] Ubuntu VPS: `systemctl status wg-quick@wg0` is active
- [ ] UDP `51820` reachable from Windows (provider firewall + ufw)
- [ ] `assets/config/servers.local.json` present and gitignored
- [ ] `vpnmania.exe` started **as Administrator**

## Connect

- [ ] App shows server name from local config (not only the bundled placeholder name if you changed it)
- [ ] Tap **Connect** → status **Connected** (not Denied / Disconnected with key errors)
- [ ] https://ifconfig.me (or similar) shows the **VPS public IP**
- [ ] Discord desktop/web loads; voice optional smoke test
- [ ] Tap **Disconnect** → public IP returns to normal ISP

## If Connect fails

| Symptom | Check |
|---------|--------|
| Permission denied / elevation | Re-run exe with UAC / Run as admin |
| Stuck connecting | VPS `wg show`, firewall UDP 51820, correct Endpoint IP |
| Connected but Discord blocked | Confirm full-tunnel AllowedIPs `0.0.0.0/0`, DNS, and Discord not blocked on the VPS itself |
| Still using placeholder endpoint | Ensure `servers.local.json` is loaded (restart app; check cwd / exe-side copy) |

## Without a VPS yet

You cannot complete Discord/egress verification. Finish [`server/README.md`](../server/README.md) first, then return here.
