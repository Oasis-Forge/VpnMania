#!/usr/bin/env bash
# Bootstrap a single WireGuard interface (wg0) on Ubuntu 22.04/24.04 for VpnMania.
# Run as root on a fresh VPS. Idempotent for keys under /etc/wireguard/vpnmania/.

set -euo pipefail

WG_DIR="/etc/wireguard"
STATE_DIR="${WG_DIR}/vpnmania"
INTERFACE="wg0"
PORT="${WG_PORT:-51820}"
SERVER_ADDR="${WG_SERVER_ADDR:-10.8.0.1/24}"
CLIENT_ADDR="${WG_CLIENT_ADDR:-10.8.0.2/32}"
DNS="${WG_DNS:-1.1.1.1}"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root: sudo bash $0" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y wireguard wireguard-tools qrencode iptables

mkdir -p "${STATE_DIR}"
chmod 700 "${STATE_DIR}"

if [[ ! -f "${STATE_DIR}/server_private.key" ]]; then
  umask 077
  wg genkey | tee "${STATE_DIR}/server_private.key" | wg pubkey > "${STATE_DIR}/server_public.key"
  wg genkey | tee "${STATE_DIR}/client_private.key" | wg pubkey > "${STATE_DIR}/client_public.key"
fi

SERVER_PRIVATE="$(cat "${STATE_DIR}/server_private.key")"
SERVER_PUBLIC="$(cat "${STATE_DIR}/server_public.key")"
CLIENT_PRIVATE="$(cat "${STATE_DIR}/client_private.key")"
CLIENT_PUBLIC="$(cat "${STATE_DIR}/client_public.key")"

# Detect primary public IPv4 and outbound interface
PUBLIC_IP="$(curl -4 -fsS ifconfig.me || curl -4 -fsS icanhazip.com || true)"
PUBLIC_IP="$(echo -n "${PUBLIC_IP}" | tr -d '[:space:]')"
if [[ -z "${PUBLIC_IP}" ]]; then
  PUBLIC_IP="$(hostname -I | awk '{print $1}')"
fi

OUT_IF="$(ip -4 route show default | awk '{print $5; exit}')"
if [[ -z "${OUT_IF}" ]]; then
  OUT_IF="eth0"
fi

cat > "${WG_DIR}/${INTERFACE}.conf" <<EOF
[Interface]
Address = ${SERVER_ADDR}
ListenPort = ${PORT}
PrivateKey = ${SERVER_PRIVATE}
PostUp = iptables -A FORWARD -i ${INTERFACE} -j ACCEPT; iptables -A FORWARD -o ${INTERFACE} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${OUT_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${INTERFACE} -j ACCEPT; iptables -D FORWARD -o ${INTERFACE} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${OUT_IF} -j MASQUERADE

[Peer]
PublicKey = ${CLIENT_PUBLIC}
AllowedIPs = ${CLIENT_ADDR}
EOF
chmod 600 "${WG_DIR}/${INTERFACE}.conf"

# IP forwarding
if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf 2>/dev/null; then
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
fi
sysctl -w net.ipv4.ip_forward=1 >/dev/null

# Firewall
if command -v ufw >/dev/null 2>&1; then
  ufw allow "${PORT}/udp" || true
  ufw allow OpenSSH || true
  # Do not force-enable ufw (may lock out if misconfigured); only open the port if active
  if ufw status | grep -qi 'Status: active'; then
    ufw reload || true
  fi
fi

systemctl enable "wg-quick@${INTERFACE}"
systemctl restart "wg-quick@${INTERFACE}"

ENDPOINT="${PUBLIC_IP}:${PORT}"
CLIENT_CONF="[Interface]
PrivateKey = ${CLIENT_PRIVATE}
Address = ${CLIENT_ADDR}
DNS = ${DNS}

[Peer]
PublicKey = ${SERVER_PUBLIC}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
Endpoint = ${ENDPOINT}"

# Escape for JSON string
json_escape() {
  python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1])[1:-1])
PY
}

WG_QUICK_ESCAPED="$(json_escape "${CLIENT_CONF}")"

echo
echo "==================== WireGuard is up ===================="
echo "Server public IP : ${PUBLIC_IP}"
echo "Listen UDP       : ${PORT}"
echo "Interface        : ${INTERFACE}"
echo
echo "---------- Client wg-quick config (keep secret) ----------"
echo "${CLIENT_CONF}"
echo
echo "---------- Paste into assets/config/servers.local.json ----------"
cat <<EOF
{
  "servers": [
    {
      "id": "discord-primary",
      "name": "Discord Access",
      "region": "VPS",
      "serverAddress": "${ENDPOINT}",
      "wgQuickConfig": "${WG_QUICK_ESCAPED}"
    }
  ]
}
EOF
echo
echo "Then on Windows: copy that JSON to assets/config/servers.local.json"
echo "(gitignored), rebuild, run vpnmania.exe as Administrator, Connect."
echo "=========================================================="
