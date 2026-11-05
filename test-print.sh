#!/usr/bin/env bash
#
# Imprime un ticket de prueba en la cola POS80.
#
set -euo pipefail

QUEUE="${QUEUE:-POS80}"
FECHA="$(date '+%Y-%m-%d %H:%M:%S')"

cat <<EOF | lp -d "$QUEUE" -o media=X70MMY297MM -o CutMedia=EndOfJob
================================
        POS80 - 80 mm
     Prueba de impresion
================================
Fecha: $FECHA
Cola:  $QUEUE
IP:    192.168.1.107:9100
--------------------------------
Acentos: áéíóú ÁÉÍÓÚ ñÑ ¿¡ üÜ €
--------------------------------
Si lees esto y el papel sale
cortado, la cola CUPS y la
guillotina funcionan.
================================



EOF

echo "Trabajo enviado a $QUEUE."
lpstat -o "$QUEUE" 2>/dev/null || true
