# Next actions: live WireGuard on Windows

The **app-side work is done**. Your next actions are all on **you + a VPS**. Follow this in order.

---

## Phase A — Buy and open an Ubuntu VPS

1. Pick a provider (Hetzner / DigitalOcean / Linode / etc.).
2. Create a droplet:
   - **OS:** Ubuntu 22.04 or 24.04
   - **Size:** 1 vCPU / 1 GB RAM is enough
   - **Region:** somewhere Discord works (EU/US, etc.)
3. Write down:
   - Public IPv4 (example: `203.0.113.10`)
   - Root password or SSH key
4. In the provider firewall / security group, allow:
   - **TCP 22** (SSH)
   - **UDP 51820** (WireGuard) — easy to forget; without this Connect will hang

---

## Phase B — Install WireGuard with the repo script

On your Windows PC, in PowerShell, from the project folder
`D:\Desktop\new projects\VpnMania`:

```powershell
# Replace YOUR_VPS_IP
scp ".\server\setup-wireguard.sh" root@YOUR_VPS_IP:/root/
ssh root@YOUR_VPS_IP "bash /root/setup-wireguard.sh"
```

If `scp`/`ssh` aren’t available, use PuTTY/WinSCP: upload `server/setup-wireguard.sh`, then on the VPS:

```bash
sudo bash /root/setup-wireguard.sh
```

**What you should see:** the script ends with:

- Server public IP + port
- A full client `[Interface]` / `[Peer]` block
- A JSON block for `servers.local.json`

**Keep that output private** (client private key is a secret).

On the VPS, confirm:

```bash
systemctl status wg-quick@wg0
wg show
```

Both should look healthy / active.

More detail: [server/README.md](server/README.md)

---

## Phase C — Put the live peer into VpnMania (secrets stay local)

1. Create the local config file:

```powershell
cd "D:\Desktop\new projects\VpnMania"
copy assets\config\servers.local.json.example assets\config\servers.local.json
```

2. Open `assets\config\servers.local.json` and **replace the whole file** with the JSON printed by the script
   (or fill in `serverAddress` + `wgQuickConfig` carefully).

3. Confirm Git will not commit it:

```powershell
git check-ignore -v assets\config\servers.local.json
```

You want a `.gitignore` hit. **Do not** `git add` this file.

4. Optional but recommended: also copy the same JSON next to the built exe:

```powershell
copy assets\config\servers.local.json build\windows\x64\runner\Debug\servers.local.json
```

(Do this again after every rebuild if you use that copy.)

More detail: [assets/config/APPLY_PEER.md](assets/config/APPLY_PEER.md)

---

## Phase D — Build and run Windows elevated

```powershell
cd "D:\Desktop\new projects\VpnMania"
$env:PATH = "C:\flutter\bin;$env:PATH"
flutter pub get
flutter build windows --debug
Start-Process -FilePath "build\windows\x64\runner\Debug\vpnmania.exe" -Verb RunAs
```

Approve the UAC prompt. The app **must** run as Administrator for WireGuard on Windows.

---

## Phase E — Verify Discord actually works

Checklist (same as [server/WINDOWS_VERIFY.md](server/WINDOWS_VERIFY.md)):

1. App shows your server (e.g. “Discord Access”).
2. Tap **Connect** → status **Connected**.
3. In a browser open https://ifconfig.me — IP should be your **VPS IP**, not your home ISP.
4. Open Discord (app or web) — login / servers / voice should work.
5. Tap **Disconnect** — ifconfig.me should return to your normal IP.

---

## If something fails

| Problem | What to do |
|--------|------------|
| SSH won’t connect | Provider firewall / wrong IP / root password |
| Script OK but Connect hangs | Open **UDP 51820** on provider firewall; on VPS run `wg show` |
| Connected but IP unchanged | Not elevated, or still on placeholder config — confirm `servers.local.json` exists and restart the app |
| Connected, IP = VPS, Discord still blocked | VPS region/network issue, or DNS — try another region / check `DNS = 1.1.1.1` in config |
| Accidental commit of secrets | Rotate keys: re-run script after deleting `/etc/wireguard/vpnmania/` keys on the VPS, update local JSON |

---

## What you do **not** need to do next

- Re-implement the Flutter app for this phase
- Finish iOS yet
- Latency / multi-server / billing

---

## Bottom line

Buy Ubuntu VPS → run `server/setup-wireguard.sh` → paste JSON into `assets/config/servers.local.json` → rebuild + run as Admin → confirm IP + Discord.
