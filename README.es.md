# POS80_FC — impresora térmica ESC/POS de 80 mm en Fedora

Fork de [`klirichek/zj-58`](https://github.com/klirichek/zj-58) adaptado para
Fedora 44 y para una impresora de tickets Ethernet de 80 mm con guillotina.

- Impresora: `192.168.1.107:9100` (MAC `0-71-80-87-115-180`)
- Cola CUPS: `POS80`
- Driver: filtro `rastertozj` + PPD `zj80.ppd`
- Red: la PC está en `192.168.0.0/24` (Xiaomi) y la impresora en
  `192.168.1.0/24` (router ISP). La ruta ya funciona; no hace falta abrir
  puertos ni configurar NAT.

## Qué cambia respecto al proyecto original

- `CMakeLists.txt` actualizado a CMake 3.5 (CMake 4 de Fedora 44 ya no acepta
  3.0).
- Corregido el manejador de `SIGTERM` para GCC 16
  (`void cancelJob(int sig)`).
- Añadido `install-fedora.sh`, que compila, instala el filtro/PPD, reinicia
  CUPS y crea la cola `POS80` con las opciones de 80 mm y corte.
- Añadidos `test-print.sh`, `diagnose.sh` y `set-printer-ip.sh`.
- Documentación en español y valores por defecto para esta impresora.

## Requisitos

- Fedora 44 (o similar) con CUPS.
- `cmake`, `cups-devel`, `gcc`, `make`, `ppdc` y `restorecon`.
- La impresora accesible por TCP en el puerto 9100.

El script de instalación instala `cmake` y `cups-devel` si faltan.

## Instalación

```bash
cd ~/Descargas/POS80_FC
./install-fedora.sh
```

El script se eleva solo con `pkexec` (aparece el diálogo de contraseña de KDE).
También se puede ejecutar directamente:

```bash
sudo ./install-fedora.sh
```

Define la IP o el nombre de la cola si hace falta:

```bash
PRINTER_IP=192.168.1.107 QUEUE=POS80 sudo ./install-fedora.sh
```

Al terminar, la cola queda habilitada, compartida en local y seleccionada por
defecto.

## Opciones de la cola

`install-fedora.sh` fija estos valores:

| Opción | Valor | Efecto |
|---|---|---|
| `OptionCutter` | `True` | La impresora tiene guillotina |
| `CutMedia` | `EndOfJob` | Corta al final de cada trabajo |
| `media` | `X70MMY297MM` | Papel de 80 × 297 mm |
| `FeedDist` | `6feed21mm` | Avance de 21 mm antes del corte (necesario para que la cuchilla pase el texto) |
| `FeedWhere` | `AfterJob` | El avance se hace al final |
| `BlankSpace` | `False` | No imprime el espacio en blanco final |

Se pueden cambiar desde la interfaz de CUPS
(`http://localhost:631/printers/POS80`) o con `lpadmin -o Opción=Valor`.

## Imprimir desde cualquier aplicación

1. Abre el diálogo de impresión de la aplicación.
2. Elige **POS80**.
3. Selecciona papel **80 mm × 297 mm** (o el tamaño de rollo de 3276 mm si el
   ticket es muy largo).
4. Imprime. El filtro rasteriza el contenido y envía ESC/POS por el puerto 9100;
   al terminar, envía el corte.

Funciona con Evince, LibreOffice, Firefox, GIMP, etc. No depende de la
codificación de caracteres de la aplicación: el texto se imprime como gráfico,
así que los acentos y símbolos salen como se ven en pantalla.

## Prueba rápida

```bash
./test-print.sh
```

Debe salir un ticket con acentos y, al final, el corte de la guillotina.

## Estado verificado

Probado el 2026-11-05 en Fedora 44 con la impresora `192.168.1.107`:

- `GS V 1` (corte parcial) dejaba el ticket unido en esta impresora; se cambió a
  **`GS V 0` (corte completo)**.
- Con `FeedDist=6feed21mm` el texto sale completo y la cuchilla corta después de
  la última línea. Con 9 mm la cuchilla cortaba parte del texto.
- El filtro ignora los bits de relleno del último byte de cada línea de CUPS; sin
  eso imprimía todo el rollo de 297 mm antes de cortar.
- El ancho de 560 px (70 mm) del PPD es suficiente para esta impresora; no hizo
  falta ampliarlo a 576 px.
- El texto se imprime como gráfico, así que los acentos y símbolos salen
  correctos.

## Orientación del texto

El driver imprime como un recibo normal: las líneas van **a lo ancho** del papel
de 80 mm y se apilan a lo largo. Si el papel se cuelga de la impresora, el texto
se lee de izquierda a derecha.

Si la aplicación envía una página **apaisada**, CUPS la gira para que quepa en el
rollo y el texto puede verse girado 90°. Para tickets, usa páginas verticales
(80 mm de ancho). Si necesitas que las líneas corran **a lo largo** del papel
(giradas 90° respecto al recibo normal), es una orientación distinta y habría que
añadir una opción de rotación al filtro.

Los primeros ~12 cm de papel en blanco antes del texto son el recorrido interno
entre el cabezal y la cuchilla; no los genera el driver. Si el ticket anterior
quedó unido, su cola se suma a ese blanco: arranca el papel viejo antes de la
prueba.

## Diagnóstico

```bash
./diagnose.sh
```

Comprueba ping, puerto 9100, estado web de la impresora, la cola CUPS y sus
opciones.

## Si el corte no es completo

El repositorio ya usa **`GS V 0` (corte completo)**. Si tu firmware necesita otra
variante, cambia el comando en `rastertozj.c` y vuelve a ejecutar
`./install-fedora.sh`:

```c
// alternativa Epson
static const char escCut[] = "\x1bi";
```

Si el papel queda unido o la cuchilla corta parte del texto, sube el avance antes
del corte:

```bash
sudo lpadmin -p POS80 -o FeedDist=7feed24mm
# o 8feed27mm, 9feed30mm...
```

Cada escalón añade 3 mm. En esta impresora `6feed21mm` fue suficiente para que el
texto salga completo y el ticket se separe.

## Si la impresora cambia de IP

La impresora usa DHCP. Si cambia de dirección:

```bash
./set-printer-ip.sh 192.168.1.107
```

Para que no cambie, crea una reserva DHCP en el router ISP
(`192.168.1.1`) para la MAC `0-71-80-87-115-180`, o fija la IP desde la web de
la impresora (`http://192.168.1.107/tcpip_cfg.htm`).

## Estado de la impresora

La web de la impresora muestra tapa, papel, cortador y conexión:

- `http://192.168.1.107/`
- `http://192.168.1.107/prn_stat.htm`
- `http://192.168.1.107/port_stat.htm`

## Solución de problemas

- **La cola no imprime:** `lpstat -p POS80 -l`, `lpoptions -p POS80 -l` y
  `sudo journalctl -u cups -n 100`.
- **Error de filtro:** comprueba que `/usr/lib/cups/filter/rastertozj` existe y
  tiene contexto SELinux correcto (`restorecon -v`).
- **La impresora no responde:** `ping 192.168.1.107`, puerto 9100 y la web de
  estado. Si la PC está en otra red, revisa la ruta al router ISP.
- **Papel cortado por la mitad:** cambia `CutMedia` a `EndOfPage` o ajusta
  `FeedDist`.
- **Sale muy angosto:** el PPD usa 560 px (70 mm). Se puede ajustar
  `cupsModelNumber` a 576 y el área imprimible a 72 mm si el cabezal lo permite.

## Licencia y créditos

El proyecto original es de Aleksey N. Vinogradov y colaboradores, licencia
BSD 2-Clause. Este fork conserva `LICENSE` y el README original. Los cambios de
integración para Fedora 44 y esta impresora están bajo la misma licencia.

- Upstream: <https://github.com/klirichek/zj-58>
- Fork: <https://github.com/FAUSTINOCRUZELIS/POS80_FC>
