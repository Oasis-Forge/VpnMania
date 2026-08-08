# Windows Discord UX smoke notes

Date: 2026-08-05

## Automated / local checks

- [x] `flutter analyze` — no issues
- [x] `flutter test` — passed
- [x] `flutter build windows --debug` — succeeded
- [x] Elevated `vpnmania.exe` launches (UX smoke)

## UI visible without live peer

- Home shows “Optimized for Discord”
- Empty-state card points to `NEXT_ACTIONS.md`
- Connect blocked with SnackBar until live peer exists
- Settings: auto-connect, auto-reconnect, kill switch toggles
- Server picker (Recommended / All / search) available when multiple servers

## Live Discord path (requires your VPS)

Complete [`NEXT_ACTIONS.md`](../NEXT_ACTIONS.md), then:

- [ ] Smart connect selects lowest-latency server
- [ ] Connection timer ticks while Connected
- [ ] ifconfig.me shows VPS IP
- [ ] Discord loads / voice works
- [ ] Unexpected drop → reconnect and/or kill switch arm (Admin)
