#!/usr/bin/env bash
#
# Diagnóstico rápido de la impresora y de la cola CUPS POS80.
#
set -u

IP="${PRINTER_IP:-192.168.1.107}"
QUEUE="${QUEUE:-POS80}"

echo "== Red =="
if ping -c1 -W2 "$IP" >/dev/null 2>&1; then
  echo "  ping $IP: OK"
else
  echo "  ping $IP: FALLA (revisa la ruta Xiaomi -> router ISP)"
fi

if timeout 3 bash -c "echo > /dev/tcp/$IP/9100" 2>/dev/null; then
  echo "  puerto 9100: OK"
else
  echo "  puerto 9100: FALLA"
fi

echo "== Estado web de la impresora =="
python3 - "$IP" <<'PY'
import re
import sys
import urllib.request

ip = sys.argv[1]
for page in ("prn_stat.htm", "port_stat.htm"):
    try:
        html = urllib.request.urlopen(
            f"http://{ip}/{page}", timeout=3
        ).read().decode("latin-1")
    except Exception as exc:
        print(f"  {page}: no se pudo leer ({exc})")
        continue
    print(f"  -- {page} --")
    rows = re.findall(r"<TD>(.*?)</TD>\s*<TD>(.*?)</TD>", html, re.S)
    for key, value in rows:
        key = re.sub(r"&nbsp;", " ", key).strip()
        value = re.sub(r"&nbsp;", " ", value).strip()
        if key:
            print(f"     {key}: {value}")
PY

echo "== CUPS =="
lpstat -r 2>&1 || true
lpstat -p "$QUEUE" -l 2>&1 || true
echo "== Opciones de $QUEUE =="
lpoptions -p "$QUEUE" -l 2>&1 || true
