# VpnMania WireGuard server (Ubuntu)

Bootstrap **one** WireGuard peer on a fresh Ubuntu 22.04/24.04 VPS so Windows VpnMania can reach Discord.

## 1. Create a VPS

1. Sign up with any provider (Hetzner, DigitalOcean, Linode, etc.).
2. Create a droplet/VPS: **Ubuntu 22.04 or 24.04**, 1 vCPU / 1 GB RAM is enough.
3. Pick a region where Discord is reachable (uncensored).
4. Note the public IPv4 and SSH as root (or a sudo user).

## 2. Run the bootstrap script

From your PC (PowerShell), copy the script and run it:

```powershell
scp server/setup-wireguard.sh root@YOUR_VPS_IP:/root/
ssh root@YOUR_VPS_IP "bash /root/setup-wireguard.sh"
```

Or on the VPS after pasting the file:

```bash
sudo bash setup-wireguard.sh
```

The script:

- installs WireGuard
- enables IPv4 forwarding + NAT
- opens UDP `51820` (and SSH if `ufw` is active)
- starts `wg-quick@wg0`
- prints a **client** config and a ready-to-paste `servers.local.json`

Treat the printed private keys as secrets.

## 3. Wire into VpnMania (Windows)

1. Copy the JSON block from the script output into:

   `assets/config/servers.local.json`

   (This path is gitignored — never commit it.)

2. From the repo root on Windows:

   ```powershell
   flutter pub get
   flutter build windows --debug
   ```

3. Run elevated:

   ```powershell
   Start-Process -FilePath "build\windows\x64\runner\Debug\vpnmania.exe" -Verb RunAs
   ```

4. Tap **Connect**, then confirm:
   - Status shows **Connected**
   - Your public IP matches the VPS (e.g. https://ifconfig.me)
   - Discord loads / voice works
   - After **Disconnect**, your normal IP returns

See also the root [README](../README.md#first-live-tunnel-windows).

## Re-running

The script is idempotent: keys under `/etc/wireguard/vpnmania/` are reused. Re-run to reprint the client JSON or restart the interface.

## Env overrides (optional)

| Variable | Default | Meaning |
|----------|---------|---------|
| `WG_PORT` | `51820` | UDP listen port |
| `WG_DNS` | `1.1.1.1` | Client DNS |

```bash
WG_PORT=51821 bash setup-wireguard.sh
```
