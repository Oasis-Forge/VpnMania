# iOS Network Extension setup

VpnMania uses a Packet Tunnel Network Extension for WireGuard on iOS.
The Dart layer already passes `providerBundleIdentifier: com.vpnmania.vpnmania.WGExtension`.

## Steps (macOS + Xcode required)

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target → Network Extension → Packet Tunnel Provider**.
3. Product Name: `WGExtension`
4. Bundle Identifier: `com.vpnmania.vpnmania.WGExtension`
5. Replace the generated Swift file with [`PacketTunnelProvider.swift`](PacketTunnelProvider.swift).
6. Set the extension’s Info.plist / entitlements to the files in this folder
   (`Info.plist`, `WGExtension.entitlements`).
7. Enable **App Groups** (`group.com.vpnmania.vpnmania`) and **Network Extensions → Packet Tunnel**
   on both the Runner and WGExtension targets (Apple Developer portal + Xcode Signing).
8. Add [WireGuardKit](https://git.zx2c4.com/wireguard-apple) to the WGExtension target
   (Swift Package Manager).
9. Attach Runner entitlements from [`../Runner/Runner.entitlements`](../Runner/Runner.entitlements)
   via **Signing & Capabilities**.
10. Build and run on a physical device (Network Extensions do not work fully on Simulator for VPN).

The `TunnelConfiguration(fromWgQuickConfig:)` helper used by the official WireGuard iOS apps
must be available (copy from wireguard-apple / the `wireguard_flutter` example if your
WireGuardKit build does not include the wg-quick parser).
