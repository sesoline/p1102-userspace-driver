# HP LaserJet P1102 / P1102w — Guía de instalación macOS + Notas Windows

**Créditos**: este driver proviene del proyecto [str4ngeMD/p1102-userspace-driver](https://github.com/str4ngeMD/p1102-userspace-driver). Todo el mérito técnico es de su autor; esta guía solo documenta la instalación verificada y aporta un parche corregido.

---

## Contenido de esta carpeta

| Archivo | Descripción |
|---|---|
| `install.sh` / `uninstall.sh` | Instalador y desinstalador (originales del proyecto) |
| `rastertozjs` | Filtro CUPS compilado **desde fuente** (OpenPrinting/foo2zjs + parche) para Apple Silicon (arm64) |
| `p1102_fw_uploader` | Uploader de firmware compilado **desde el código Swift** del proyecto (arm64) |
| `HP_LaserJet_Professional_P1102.ppd` | PPD nativo para CUPS |
| `firmware/sihpP1102.dl` | Firmware oficial de HP (extraído del paquete HPLIP de Linux) |
| `foo2zjs_cups_FIXED.patch` | **Parche corregido** — el `foo2zjs_cups.patch` original está malformado y no aplica; este sí (verificado contra upstream) |

> Nota de seguridad: los binarios incluidos aquí NO son los pre-compilados del repositorio original. Fueron compilados desde las fuentes (OpenPrinting + código Swift) en un Mac Apple Silicon y verificados contra los originales (tamaños y bibliotecas enlazadas coinciden).

---

## macOS — Instalación

### Requisitos previos
1. **Conectar la impresora por USB y encenderla** antes de instalar.
2. Este driver funciona por **USB** (la subida de firmware se hace por USB). La P1102w por WiFi no está cubierta por este proyecto.
3. Necesitas permisos de administrador (el script te pedirá la contraseña).

### Caso 1: Mac Apple Silicon (M1/M2/M3/M4) — recomendado

```bash
cd ~/Downloads/p1102-userspace-driver
./install.sh
```

Los binarios compilados funcionan tal cual. Al conectar la impresora, macOS creará la cola automáticamente.

### Caso 2: Mac Intel — hay que recompilar

Los binarios arm64 no funcionan en Intel. Recompila en el propio Mac:

```bash
cd ~/Downloads/p1102-userspace-driver

# 1. Eliminar binarios arm64
rm rastertozjs p1102_fw_uploader

# 2. Compilar el filtro desde la fuente oficial + parche corregido
git clone https://github.com/OpenPrinting/foo2zjs.git /tmp/foo2zjs-src
cd /tmp/foo2zjs-src
patch -p1 < ~/Downloads/p1102-userspace-driver/foo2zjs_cups_FIXED.patch
clang -O2 -Wall -DcupsFilter -I. -lcups foo2zjs.c jbig.c jbig_ar.c -o rastertozjs
cp rastertozjs ~/Downloads/p1102-userspace-driver/

# 3. Instalar (el script compila el uploader Swift automáticamente si no hay binario)
cd ~/Downloads/p1102-userspace-driver
./install.sh
```

(Requiere Command Line Tools: `xcode-select --install`)

---

## Verificación

```bash
# Ver colas de impresión
lpstat -p -d

# Seguir el log del uploader de firmware (en tiempo real)
tail -f ~/Library/Logs/com.str4ngemd.p1102-fw-uploader.log
```

Si la impresora no imprime, apaga y desenchufa la impresora 10 segundos, vuelve a enchufarla y enciéndela. El agente launchd sube el firmware cada vez que detecta la impresora.

---

## Desinstalación

```bash
cd ~/Downloads/p1102-userspace-driver
./uninstall.sh
```

---

## Windows — IMPORTANTE: no necesitas este driver

Windows **no usa CUPS**, por lo que este proyecto no aplica. La P1102/P1102w tiene soporte nativo en Windows:

1. **Vía Windows Update (lo más fácil)**: conecta la impresora por USB. Windows 10/11 descarga e instala el driver automáticamente.
2. **Driver oficial de HP**: "HP LaserJet Pro P1100, P1560, P1600 Printer series — Full Feature Software and Driver" (2015, compatible con Windows 10/11):
   https://support.hp.com/us-en/drivers/hp-laserjet-pro-p1102w-printer/model/4110394

En Windows el driver oficial de HP se encarga de la subida de firmware al encender la impresora, igual que hace aquí `p1102_fw_uploader`.

---

## Contribuir al proyecto original (fork + Pull Request)

El parche corregido (`foo2zjs_cups_FIXED.patch`) es un aporte valioso para el autor y la comunidad. El flujo recomendado:

1. **Fork**: desde https://github.com/str4ngeMD/p1102-userspace-driver → botón "Fork". Crea una copia en tu cuenta de GitHub; el proyecto queda vinculado al original y el autor conserva todo el crédito.
2. **Sube los cambios** a tu fork:
   - `foo2zjs_cups_FIXED.patch` (o mejor: corregir el `foo2zjs_cups.patch` original in-place)
   - Este `README_ES.md`
3. **Pull Request (PR)**: en GitHub → "Contribute" → "Open pull request". Le propones tus cambios al autor; si los aprueba, quedan en el repo oficial y todos los usuarios se benefician.

No hay que mandar nada a OpenPrinting/foo2zjs: el parche es específico de este proyecto (modifica el filtro para macOS), no del upstream.

**Ojo**: los binarios compilados (`rastertozjs`, `p1102_fw_uploader`) NO deberían incluirse en el PR (ya están en el repo original y no se pueden verificar cambios a binarios en un PR).

---

## Resumen de lo verificado (18/08/2026, macOS 26.5.2, arm64)

- [x] `install.sh` y `uninstall.sh` revisados: sin acciones maliciosas
- [x] Código Swift del uploader revisado: solo IOKit + CUPS, sin llamadas de red
- [x] Binarios del repo analizados: arm64, firma ad-hoc, solo librerías del sistema
- [x] Firmware `sihpP1102.dl` confirmado como el oficial de HP (HPLIP)
- [x] `rastertozjs` recompilado desde OpenPrinting + parche corregido
- [x] `p1102_fw_uploader` recompilado desde su código Swift
- [x] Parche corregido verificado: aplica limpio y compila en un clon fresco
- [x] Instalación y funcionamiento real comprobados en un Mac Apple Silicon
