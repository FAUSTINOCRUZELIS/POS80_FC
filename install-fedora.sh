#!/usr/bin/env bash
#
# Instala el filtro rastertozj y crea/actualiza la cola CUPS POS80.
# Pensado para Fedora 44 y una impresora térmica ESC/POS de 80 mm.
#
# Uso:
#   ./install-fedora.sh
#   PRINTER_IP=192.168.1.107 QUEUE=POS80 ./install-fedora.sh
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  if command -v pkexec >/dev/null 2>&1; then
    exec pkexec "$(readlink -f "$0")" "$@"
  fi
  echo "Ejecuta este script con sudo o pkexec." >&2
  exit 1
fi

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRINTER_IP="${PRINTER_IP:-192.168.1.107}"
QUEUE="${QUEUE:-POS80}"
BUILD_DIR="${BUILD_DIR:-/tmp/pos80-build-root}"
PPD_INSTALL_DIR="/usr/share/cups/model/zjiang"
FILTER_INSTALL="/usr/lib/cups/filter/rastertozj"

echo "==> Dependencias de compilación"
dnf install -y gcc make cmake cups-devel

echo "==> Compilando rastertozj en $BUILD_DIR"
rm -rf "$BUILD_DIR"
cmake -S "$REPO_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BUILD_DIR" -j"$(nproc)"

echo "==> Instalando filtro, backend y PPD"
install -d "$PPD_INSTALL_DIR"
install -m 0755 "$BUILD_DIR/rastertozj" "$FILTER_INSTALL"
install -m 0755 "$REPO_DIR/backend/pos80" /usr/lib/cups/backend/pos80
if [ -f "$BUILD_DIR/ppd/zj80.ppd" ]; then
  install -m 0644 "$BUILD_DIR/ppd/zj80.ppd" "$PPD_INSTALL_DIR/zj80.ppd"
else
  install -m 0644 "$REPO_DIR/zj80.ppd" "$PPD_INSTALL_DIR/zj80.ppd"
fi
if command -v restorecon >/dev/null 2>&1; then
  restorecon -v "$FILTER_INSTALL" /usr/lib/cups/backend/pos80 \
    "$PPD_INSTALL_DIR/zj80.ppd" || true
fi

echo "==> Reiniciando CUPS"
systemctl restart cups

echo "==> Creando/actualizando cola $QUEUE -> pos80://$PRINTER_IP:9100"
lpadmin -p "$QUEUE" -E -v "pos80://$PRINTER_IP:9100" \
  -P "$PPD_INSTALL_DIR/zj80.ppd" \
  -o printer-is-shared=false

# Opciones por defecto: guillotina instalada, corte al final del trabajo,
# papel de 80 x 297 mm, 9 mm de avance antes del corte y sin cola en blanco.
lpadmin -p "$QUEUE" \
  -o OptionCutter=True \
  -o CutMedia=EndOfJob \
  -o media=X70MMY297MM \
  -o FeedDist=2feed9mm \
  -o FeedWhere=AfterJob \
  -o BlankSpace=False

lpadmin -d "$QUEUE"
lpadmin -p "$QUEUE" -E

echo "==> Estado de la cola"
lpstat -p "$QUEUE" -l || true
echo
lpoptions -p "$QUEUE" -l || true
