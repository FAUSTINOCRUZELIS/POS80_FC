# Estado del proyecto (pausa 2026-11-05)

## Lo que sí funciona

- Impresora `192.168.1.107`: ping, puerto 9100 y web de estado OK.
- Prueba directa ESC/POS por el puerto 9100 (sin CUPS):
  - texto + `ESC d` + `GS V 0`: imprime y corta.
  - raster `GS v 0` + `ESC d` + `GS V 0`: banda ancha y corte.
  - el ESC/POS que genera `rastertozj` enviado directo: imprime bien
    («LINEA UNICA» upright), pero **no corta**.
- El filtro `rastertozj` genera el raster correcto; el problema está en el
  corte/avances, no en la imagen.

## Lo que falla

- CUPS + backend `socket`: texto girado/incompleto y corte antes de tiempo.
- Backend propio `pos80` con espera de 2 s: no resolvió.
- La cola `POS80` está **deshabilitada** para no gastar papel.

## Hipótesis para retomar

- Los avances del filtro usan `ESC J`; el `GS V 0` que va justo después no se
  ejecuta. La prueba directa usa `ESC d 4` + `GS V 0` y sí corta.
- Probar, en este orden:
  1. Cambiar el avance previo al corte por `ESC d` (con la equivalencia
     correcta) y dejar `GS V 0` inmediatamente después.
  2. Probar `GS V 0`, `ESC i`, `GS V 65 0` y `GS V 1` por separado.
  3. Enviar el corte en una **segunda conexión** al 9100, después de los datos
     (como la prueba directa), desde un backend propio.
  4. Revisar si el servidor lwIP corta el flujo cuando el socket se cierra;
     el backend `pos80` de la rama WIP ya espera 2 s.
- El backend experimental y las opciones largas de `FeedDist` están en la rama
  `wip/cut-backend`.

## Comandos útiles

```bash
# Estado
./diagnose.sh
lpstat -p POS80 -l
lpstat -v POS80

# Reanudar la cola
sudo cupsenable POS80

# Pausar de nuevo
sudo cupsdisable POS80

# Probar el ESC/POS del filtro sin CUPS
python3 - <<'PY'
import socket
data = open('/tmp/linea.escpos','rb').read()
s = socket.create_connection(('192.168.1.107', 9100), timeout=5)
s.sendall(data); s.shutdown(socket.SHUT_WR)
import time; time.sleep(2); s.close()
PY
```

## Repositorio

- `master`: driver `rastertozj` con corte completo `GS V 0`, corrección del
  padding de CUPS y `FeedDist` de 21 mm.
- `wip/cut-backend`: backend `pos80` con espera de 2 s y opciones de avance
  largas (60–129 mm) para seguir depurando.
