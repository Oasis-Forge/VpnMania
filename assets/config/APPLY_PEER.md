# Apply a live WireGuard peer (no secrets in git)

After you run [`server/setup-wireguard.sh`](../server/setup-wireguard.sh) on your VPS:

## 1. Create the local config file

```powershell
copy assets\config\servers.local.json.example assets\config\servers.local.json
```

Or paste the JSON block printed by the bootstrap script directly into:

`assets/config/servers.local.json`

## 2. Confirm git will not commit it

```powershell
git check-ignore -v assets/config/servers.local.json
```

You should see a hit from `.gitignore`.

## 3. Rebuild Windows and run elevated

```powershell
flutter build windows --debug
Start-Process -FilePath "build\windows\x64\runner\Debug\vpnmania.exe" -Verb RunAs
```

The app prefers `servers.local.json` over the placeholder `servers.json` and over cached remote config.

## 4. Optional: copy beside the exe

If you launch the `.exe` from another working directory, also place:

`build\windows\x64\runner\Debug\servers.local.json`

(same JSON content). The loader checks next to the executable.
