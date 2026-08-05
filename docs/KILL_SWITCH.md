# Kill switch (Windows, best-effort)

VpnMania’s kill switch is **not** a kernel/driver filter like ExpressVPN.

## Behavior

When **Kill switch** is enabled in Settings and the WireGuard tunnel drops
**unexpectedly** (not via Disconnect):

1. The app tries to **arm** a Windows Firewall outbound block rule named
   `VpnManiaKillSwitch`.
2. While armed, most outbound traffic is blocked until reconnect succeeds or
   you disconnect (which disarms the rule).
3. Auto-reconnect (if enabled) still attempts to restore the tunnel.

## Requirements

- Windows desktop
- App running **as Administrator** (needed to create/enable firewall rules)
- WireGuard peer already configured

## Limits

- Does not protect against leaks as thoroughly as a WFP/callout driver
- May block traffic needed to reach the VPN endpoint if left armed incorrectly
  (reconnect path disarms on successful connect)
- No-op on web / non-Windows builds
- Creating firewall rules can fail silently in restricted environments — check
  the home-screen error text

## Disable / clean up

Turn off Kill switch in Settings and Disconnect. To remove the rule manually:

```powershell
Remove-NetFirewallRule -DisplayName "VpnManiaKillSwitch" -ErrorAction SilentlyContinue
```
