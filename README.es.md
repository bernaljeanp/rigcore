<p align="center">
  <img src="docs/icono.svg" width="104" alt="Rigcore">
</p>

<h1 align="center">Rigcore</h1>

<p align="center"><a href="README.md">English</a> · <b>Español</b></p>

<p align="center">
  <b>El centro de control para portátiles gaming en Linux.</b><br>
  Temperaturas, ventiladores, modos de rendimiento, batería, luces del teclado y perfiles por juego<br>
  en una sola app, diseñada como un instrumento de medición y con un consumo mínimo.
</p>

<p align="center">
  <img src="docs/panel.png" alt="Panel de Rigcore" width="900">
</p>

> **Estado: beta.** Probado a fondo en un Alienware 16X Aurora con Bazzite (KDE Plasma, Wayland).
> El soporte de otras marcas sigue la documentación del kernel y de los proyectos de cada marca y
> está probado con sysfs simulados, pero no en esos equipos: tu informe es lo que más ayuda (ver *Contribuir*).

**Seguridad en el control manual:** en los ventiladores con velocidad manual (ThinkPad, Dell, HP
Victus S), Rigcore fuerza el máximo a partir de 90 °C, devuelve el control al firmware con el valor 0
y siempre al detener el servicio.

## Por qué Rigcore

Los fabricantes no publican sus apps de control para Linux, y la comunidad ha
respondido con decenas de herramientas sueltas: una por marca, a veces una por
modelo, muchas abandonadas. Rigcore quiere ser **una sola app para todas las marcas**.

En lugar de escribir un driver por modelo, Rigcore usa las **interfaces estándar
del kernel** (`hwmon`, `platform-profile`, `firmware-attributes`, `power_supply`,
`hidraw`) y servicios estándar (`power-profiles-daemon` / `tuned-ppd`, NVML). Cada vez
que el kernel añade soporte para un portátil, Rigcore lo aprovecha.

## Funciones

| | |
|---|---|
| **Panel** | Temperatura de CPU y GPU con indicadores de escala, uso, frecuencia, consumo, historial de 90 s, ventiladores y batería |
| **Modos de rendimiento** | Silencioso · Equilibrado · Rendimiento por D-Bus; respeta a `tuned` y al escritorio. Teclas 1, 2, 3 |
| **Perfiles por juego** | Modo y boost por juego (Steam con sus carátulas, o cualquier proceso). Un agente ligero los aplica al abrir el juego y restaura todo al cerrarlo |
| **Curvas de ventilador** | Boost según la temperatura, con editor de puntos, histéresis y presets; las aplica el servicio aunque la app esté cerrada |
| **Iluminación** | Color fijo, respirar, aurora y brillo del teclado (Alienware AW-ELC); se reaplica al arrancar y al volver de la suspensión |
| **Batería** | Modos y umbrales de carga guardados en el firmware (Dell/Alienware y la interfaz estándar `charge_control_*`) |
| **Bandeja y teclas** | Icono con el color del panel, menú rápido y teclas especiales (en Alienware: F6 Boost, F7 Sigilo, F9 Luces) |
| **Gráficas** | NVIDIA (NVML), AMD (`amdgpu`) e Intel (`i915`/`xe`). En portátiles híbridos no despierta la gráfica dedicada en reposo |
| **Identidad de marca** | El color de acento sigue la marca del portátil (cian en Alienware, rojo en ROG/MSI…), las luces del teclado o el ámbar; insignias de fabricante propias (sin logos oficiales) |
| **Ligera** | ~3 % de un núcleo con la ventana abierta; en la bandeja ~0,25 %. La ventana corre en su propio proceso y devuelve toda su memoria al cerrarse |

<table>
  <tr>
    <td><img src="docs/juegos.png" alt="Perfiles por juego"></td>
    <td><img src="docs/curvas.png" alt="Curvas de ventilador"></td>
  </tr>
  <tr>
    <td><img src="docs/luces.png" alt="Iluminación"></td>
    <td><img src="docs/ajustes.png" alt="Ajustes"></td>
  </tr>
</table>

## Compatibilidad

| Función | Dónde funciona hoy |
|---|---|
| Temperatura de CPU | Cualquier Intel o AMD |
| Gráfica | NVIDIA, AMD, Intel |
| Leer ventiladores | La mayoría de portátiles con driver en el kernel; MSI con msi-ec (en %) |
| Control de ventiladores y curvas | **Alienware / Dell G** (boost sobre el firmware) · **ThinkPad** (manual, con `thinkpad_acpi fan_control=1`) · **ASUS** (automático/máximo y curva guardada en el firmware) · **HP Omen/Victus** (automático/máximo; manual en Victus S) · **MSI** con msi-ec (Cooler Boost) · **Acer Predator/Nitro** con Linuwu-Sense · otros Dell y sobremesas (`pwmN` estándar) |
| Límite de batería | Dell / Alienware (`dell-wmi-sysman`), interfaz estándar `charge_control_*` (ThinkPad, ASUS, Framework, MSI…), **Lenovo** (modo conservación) y **Acer** (límite al 80 %) |
| Luces del teclado | **Alienware / Dell G** (AW-ELC: color, respirar, aurora) · **ASUS TUF/ROG** (`kbd_rgb_mode`: color, respirar, ciclo) · **Lenovo Legion 5/Pro, IdeaPad Gaming, LOQ** 2020–2024 (4 zonas: color, respirar, ciclo) · **Acer Predator/Nitro** con Linuwu-Sense (4 zonas: color, respirar, onda) · teclados **RGB estándar** (LED multicolor: Tuxedo/Clevo, System76…) · **brillo** de cualquier teclado retroiluminado |
| Teclas especiales | Alienware 16X Aurora (otros modelos: aporta tus códigos con `tools/scan_keys.py`) |
| Modos de rendimiento | Distros con `power-profiles-daemon` o `tuned-ppd` (si usas TLP, Rigcore lo indica) |
| Distros | Con systemd. Probado en Bazzite (Fedora) |

## Instalación

**Cualquier distro, incluidas Bazzite, Silverblue y SteamOS** (instalador universal: la app
va en tu usuario y, si quieres, instala el servicio de hardware pidiendo tu contraseña):

```sh
git clone https://github.com/bernaljeanp/rigcore.git
cd rigcore
./install.sh            # ./install.sh --uninstall para quitarlo
```

**Arch, CachyOS, EndeavourOS, Garuda:** paquete `rigcore-git` (AUR, próximamente).
**Fedora:** repositorio COPR (próximamente). Detalles en [packaging/](packaging/README.md).

**Idioma:** español o inglés según el sistema; se puede cambiar en *Ajustes*.

### Desde el código (desarrollo)

```sh
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
./rigcore.sh               # ventana
./rigcore.sh --bandeja     # en la bandeja (se puede activar al iniciar sesión desde Ajustes)
```

### Servicio para ventiladores, batería y luces

Cambiar el boost, las curvas, el límite de carga, la iluminación persistente o el
bloqueo de Fn requiere permisos de administrador. Rigcore usa un servicio mínimo que
**solo** expone esas operaciones, valida cada valor y solo acepta a administradores
del sistema (grupo `wheel`, `sudo` o `admin`):

```sh
pkexec "$PWD/helper/install.sh"              # instalar
pkexec "$PWD/helper/install.sh" --uninstall  # desinstalar
```

El código privilegiado se copia a una carpeta de root (`/usr/local/libexec/rigcore/`, o la del paquete)
y corre aislado por systemd: sin red, sin acceso a `/home`, con el sistema en solo
lectura salvo `/sys`, y acceso solo a dispositivos `hidraw`. Al detenerse, devuelve los
ventiladores a automático. De la BIOS solo puede cambiar las opciones de una lista
blanca (bloqueo de Fn). En equipos Alienware instala además una regla `hwdb`, limitada
al modelo, que reasigna las teclas especiales que el escritorio no puede usar.

Requiere PyGObject del sistema (`python3-gobject` en Fedora, `python3-gi` en
Debian/Ubuntu, `python-gobject` en Arch).

## Desarrollo

```sh
.venv/bin/python -m unittest discover -s tests -v   # pruebas
tools/measure.sh 20                                  # consumo de CPU de la ventana
RIGCORE_SHOT=captura.png ./rigcore.sh --ventana      # captura automática
./rigcore.sh --ventana --pagina 2                    # abrir en una página

# Simular hardware ausente para probar los avisos:
RIGCORE_SIMULATE="no-gpu,gpu-asleep,no-ppd,tlp,no-fans,no-battery" ./rigcore.sh --ventana

tools/build_shaders.sh                          # recompilar shaders (requirements-dev.txt)
pkexec /usr/bin/python3 -I tools/scan_keys.py   # códigos de las teclas especiales
.venv/bin/python tools/i18n_update.py --check   # traducción al inglés (rigcore/i18n/rigcore_en.ts)
```

Estructura:

```
rigcore/hardware.py   detección y lectura de sensores (interfaces estándar)
rigcore/gpu.py        NVIDIA / AMD / Intel
rigcore/lights.py     luces del teclado por marca
rigcore/fans.py       control de ventiladores por marca (boost, pwm, auto/máximo...)
rigcore/fancurve.py   curvas de ventilador
rigcore/agent.py      agente de perfiles por juego (servicio de usuario)
rigcore/games.py      biblioteca de juegos y configuración
rigcore/tray.py       bandeja, instancia única, teclas
rigcore/i18n.py       idioma (traducción al inglés en rigcore/i18n/)
rigcore/app.py        puente Python ↔ QML
rigcore/qml/          interfaz (Qt Quick)
rigcore/shaders/      indicadores en GLSL
helper/               servicio privilegiado, regla de teclas e instalador
tests/                pruebas con sysfs simulado
```

## Contribuir

Lo más valioso ahora mismo: **probar Rigcore en tu portátil** y abrir un *issue* con
tu modelo, distro y qué funciona o no (hay una plantilla de *Informe de compatibilidad*).
Ejecuta `.venv/bin/python -m rigcore.hardware` y adjunta la salida.

## Licencia

[GPL-3.0](LICENSE). Iconos de interfaz derivados de [Lucide](https://lucide.dev) (ISC).
Fuentes IBM Plex Sans Condensed, IBM Plex Mono y Oxanium (SIL Open Font License).
Protocolo de luces AW-ELC documentado por [alienfx-tools](https://github.com/T-Troll/alienfx-tools) (MIT);
protocolo de 4 zonas de Lenovo de [L5P-Keyboard-RGB](https://github.com/4JX/L5P-Keyboard-RGB) (GPL-3.0).
Interfaces de otras marcas estudiadas en la documentación del kernel y en
[msi-ec](https://github.com/BeardOverflow/msi-ec), [Linuwu-Sense](https://github.com/0x7375646F/Linuwu-Sense),
[LenovoLegionLinux](https://github.com/johnfanv2/LenovoLegionLinux) y [asusctl](https://gitlab.com/asus-linux/asusctl)
(sin copiar su código).
Las carátulas de juegos que aparecen en las capturas pertenecen a sus respectivos dueños.
