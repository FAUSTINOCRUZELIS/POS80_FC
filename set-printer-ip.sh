#!/usr/bin/env bash
#
# Cambia la IP de la impresora en la cola CUPS POS80.
#
# Uso:
#   ./set-printer-ip.sh 192.168.1.107
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  if command -v pkexec >/dev/null 2>&1; then
    exec pkexec "$(readlink -f "$0")" "$@"
  fi
  echo "Ejecuta este script con sudo o pkexec." >&2
  exit 1
fi

IP="${1:-}"
QUEUE="${QUEUE:-POS80}"

if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  echo "Uso: $0 192.168.1.107" >&2
  exit 2
fi

IFS=. read -r a b c d <<< "$IP"
for octeto in "$a" "$b" "$c" "$d"; do
  if [ "$octeto" -gt 255 ]; then
    echo "IP inválida: $IP" >&2
    exit 2
  fi
done

lpadmin -p "$QUEUE" -v "socket://$IP:9100"
echo "Cola $QUEUE -> socket://$IP:9100"
