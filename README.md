# dashbash-installer

Instalador reproducible del dashboard de monitoreo **`dashbash`**: un comando que abre
[kitty](https://sw.kovidgoyal.net/kitty/) maximizado con una sesión de 8 pestañas de
herramientas TUI para vigilar el sistema completo.

```bash
dashbash
```

---

## Qué es `dashbash`

`dashbash` es un launcher de una línea:

```bash
exec kitty --start-as=maximized --session "$HOME/.config/kitty/dashboard.conf"
```

Toda la inteligencia está en la sesión de kitty, que reparte las herramientas en pestañas:

| # | Pestaña    | Herramientas                  | Para qué sirve                              |
|---|------------|-------------------------------|---------------------------------------------|
| 1 | `Home`     | `tclock` · `cava`             | Reloj grande (locale es_CL) + visualizador de audio |
| 2 | `System`   | `btop`                        | CPU, RAM, procesos                          |
| 3 | `Network`  | `bmon` · `watch ss -tulpn`    | Ancho de banda + puertos en escucha          |
| 4 | `Hardware` | `nvtop`                       | GPU (uso, memoria, temperatura)              |
| 5 | `Disks`    | `gdu -d`                      | Uso de disco navegable                       |
| 6 | `Monitor`  | `btm` (bottom)                | Vista consolidada alternativa                |
| 7 | `Files`    | `ranger`                      | Explorador de archivos                       |
| 8 | `Logs`     | `journalctl -f`               | Logs del sistema en vivo                     |

---

## Instalación

```bash
git clone <este-repo> dashbash-installer
cd dashbash-installer
./install-dashbash.sh
```

El script es **idempotente**: puedes correrlo las veces que quieras, salta lo que ya está
instalado y respalda con timestamp cualquier archivo de configuración que reemplace.

### Modos de uso

| Comando | Efecto |
|---|---|
| `./install-dashbash.sh` | Instala dependencias, locale, configuración y el launcher |
| `./install-dashbash.sh --check` | Solo diagnostica qué falta. No instala ni modifica nada |
| `./install-dashbash.sh --no-config` | Solo dependencias; no toca `~/.config/kitty` ni `~/bin` |
| `./install-dashbash.sh --help` | Ayuda |

Al terminar imprime una tabla de verificación y sale con código ≠ 0 si algo quedó pendiente,
así que sirve tal cual dentro de un flujo de provisioning automatizado.

---

## Qué instala

### Paquetes del sistema (apt)

`kitty` · `cava` · `btop` · `bmon` · `nvtop` · `gdu` · `ranger` ·
`iproute2` (aporta `ss`) · `procps` (aporta `watch`) · `systemd` (aporta `journalctl`) ·
`locales` · `fontconfig` · `fonts-jetbrains-mono` · `build-essential` · `pkg-config` ·
`curl` · `ca-certificates`

### Crates de Rust (cargo)

Dos herramientas no están empaquetadas en Ubuntu y se compilan desde crates.io. Si `cargo`
no existe, el script instala `rustup` en modo no interactivo (perfil mínimo, sin modificar
tu PATH por su cuenta).

| Crate | Binario | Usado en |
|---|---|---|
| `clock-tui` | `tclock` | Pestaña Home |
| `bottom` | `btm` | Pestaña Monitor |

> La compilación de estos dos crates puede tardar varios minutos en la primera corrida.

### Locale

Genera **`es_CL.UTF-8`**, requerido por el reloj de la pestaña Home
(`LC_TIME=es_CL.UTF-8 tclock`).

### Archivos de configuración

| Destino | Origen en el repo | Nota |
|---|---|---|
| `~/.config/kitty/dashboard.conf` | `config/dashboard.conf` | Respalda el anterior si difiere |
| `~/bin/dashbash` | `bin/dashbash` | Launcher ejecutable |
| `~/.config/kitty/kitty.conf` | — | Se crea **solo si no existe** (JetBrains Mono 14). Nunca pisa tu configuración |

---

## Estructura del repo

```
dashbash-installer/
├── install-dashbash.sh    # Instalador principal
├── bin/
│   └── dashbash           # Launcher: kitty + sesión del dashboard
├── config/
│   └── dashboard.conf     # Sesión de kitty con las 8 pestañas
├── tests/
│   ├── run.sh             # Suite de integración aislada (sin instalar paquetes reales)
│   └── support/
│       └── mock-command   # Simulador de dependencias y gestores de paquetes
└── README.md
```

## Pruebas

La suite usa un `HOME` temporal y comandos simulados, por lo que no ejecuta instalaciones
reales ni modifica la configuración del usuario:

```bash
bash tests/run.sh
```

---

Si `$HOME/bin` no estaba en el `PATH`, el script añade la línea correspondiente a
`~/.bashrc`; abre una shell nueva o ejecuta `source ~/.bashrc` para activarla.

---

## Requisitos y limitaciones

- **Distro:** pensado y probado en **Ubuntu 24.04 LTS (noble) / amd64**. Debería funcionar
  en cualquier Debian/Ubuntu reciente; en otras distros el script se detiene porque asume
  `apt-get`.
- **Privilegios:** necesita `sudo` (o root) para los paquetes del sistema y el locale.
  La parte de cargo y la configuración se instalan en tu `$HOME`, sin privilegios.
- **`nvtop`** se instala siempre, pero solo muestra datos si hay drivers de GPU cargados
  (NVIDIA, AMD o Intel).
- **`journalctl`** requiere systemd: no funcionará en WSL1 ni en contenedores sin init.
- **Sesión gráfica:** `dashbash` abre una ventana de kitty, así que necesita un entorno gráfico.
  Por SSH sin X11 forwarding no aplica.

---

## Personalizar el dashboard

Edita `config/dashboard.conf` y vuelve a correr `./install-dashbash.sh` (o copia el archivo
directamente a `~/.config/kitty/dashboard.conf`). La sintaxis es la de las
[sesiones de kitty](https://sw.kovidgoyal.net/kitty/overview/#startup-sessions):

```conf
new_tab NombreDeLaPestaña
layout tall              # tall | grid | horizontal | vertical | stack
launch <comando>         # una ventana por cada 'launch'
```

Si agregas una herramienta nueva, añádela también a `APT_DEPS` o `CARGO_DEPS` dentro de
`install-dashbash.sh` para que quede cubierta por la instalación y el diagnóstico.
