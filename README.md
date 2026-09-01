# dashbash

[Español](#español) · [English](#english)

---

## Español

`dashbash` instala y abre un dashboard de monitoreo en
[kitty](https://sw.kovidgoyal.net/kitty/) con ocho pestañas de herramientas TUI.
El instalador está orientado a Debian/Ubuntu, es idempotente y puede ejecutarse desde un
clon local o directamente mediante `curl`.

### Vista general

| # | Pestaña | Herramientas | Función |
|---:|---|---|---|
| 1 | `Home` | `tclock`, `fastfetch` | Reloj e información del sistema |
| 2 | `System` | `btop` | CPU, memoria y procesos |
| 3 | `Network` | `bmon`, `watch`, `ss` | Tráfico de red y puertos en escucha |
| 4 | `Hardware` | `nvtop` | Uso, memoria y temperatura de GPU |
| 5 | `Disks` | `gdu` | Uso navegable del disco |
| 6 | `Monitor` | `btm` | Vista consolidada del sistema |
| 7 | `Files` | `ranger` | Explorador de archivos |
| 8 | `Logs` | `journalctl` | Logs del sistema en tiempo real |

### Requisitos

- Debian, Ubuntu o Kubuntu con `apt-get`.
- Acceso como `root` o mediante `sudo` para paquetes y locales.
- Entorno gráfico para abrir kitty.
- `systemd` para la pestaña de logs.
- Drivers de GPU compatibles para que `nvtop` muestre información.

El proyecto es compatible con Ubuntu y Kubuntu 24.04 LTS sobre amd64. Kubuntu usa la misma
base y los mismos repositorios de paquetes de Ubuntu; KDE Plasma no requiere cambios en el
instalador. Los componentes `universe` y `multiverse` deben estar habilitados porque varias
dependencias proceden de ellos. En otras versiones Debian/Ubuntu recientes debería
funcionar, aunque no están verificadas.

En Ubuntu 24.04, donde `fastfetch` todavía no forma parte del repositorio oficial, el
instalador añade `ppa:zhangsongcui3371/fastfetch`, recomendado en la
[documentación oficial de Fastfetch](https://github.com/fastfetch-cli/fastfetch#installation).

Antes de modificar paquetes o locales del sistema, el script anuncia la operación y
ejecuta `sudo -v`. Si hace falta autenticación, `sudo` solicita la contraseña directamente
en la terminal. Los archivos del directorio personal se administran sin `sudo`.

### Compatibilidad entre distribuciones

Comprobación realizada el **1 de septiembre de 2026**. “Probado” significa que se ejecutó
`install-dashbash.sh --check` en una imagen oficial limpia y se consultó la disponibilidad
de todos los paquetes APT. La apertura gráfica de kitty no puede validarse en un contenedor.

| Distribución | Estado | Evidencia y ajustes |
|---|---|---|
| Ubuntu 24.04 LTS | ✅ Compatible | `fastfetch` requiere el PPA recomendado por su proyecto, que el instalador añade automáticamente. Habilita `universe` y `multiverse`. |
| Kubuntu 24.04 LTS | ✅ Compatible | Usa la base Ubuntu Noble; el instalador añade automáticamente el PPA de `fastfetch`. Habilita `universe` y `multiverse`. |
| Linux Mint 22.x | 🟡 Compatible por base | Mint 22.x usa Ubuntu Noble. No se probó una imagen de escritorio completa. No aplica a LMDE. |
| Pop!_OS basado en Ubuntu | 🟡 Compatible por base | Usa APT y repositorios Ubuntu; no se probó una imagen de escritorio completa. |
| Debian 13 (Trixie) | ✅ Probado | El diagnóstico se ejecuta y todos los paquetes APT declarados están disponibles. |
| Debian 12 (Bookworm) | ⚠️ Requiere ajuste | `nvtop` requiere `contrib` y `fastfetch` no está en los repositorios oficiales; debe instalarse manualmente. |
| Fedora 42 | ❌ No soportado | Probado: se detiene de forma segura porque no existe `apt-get`; requeriría un backend DNF. |
| Arch Linux / Manjaro | ❌ No soportado | Probado en Arch: se detiene de forma segura; requeriría un backend pacman/AUR. |
| openSUSE Leap 15.6 | ❌ No soportado | Probado: se detiene de forma segura; requeriría un backend Zypper. |

Para Ubuntu, Kubuntu, Mint o Pop!_OS, si faltan los componentes del repositorio:

```bash
sudo add-apt-repository universe
sudo add-apt-repository multiverse
sudo apt update
```

En Debian 12, añade `contrib` a la lista `Components` de la fuente Debian en
`/etc/apt/sources.list` o `/etc/apt/sources.list.d/*.sources`, y ejecuta:

```bash
sudo apt update
```

En distribuciones marcadas como no soportadas no basta con cambiar un nombre de paquete:
el instalador necesita implementar su gestor, sus equivalencias de paquetes y sus pruebas.

### Instalación desde el repositorio

```bash
git clone https://github.com/jerpdev9/dashboardbash.git dashbash-installer
cd dashbash-installer
./install-dashbash.sh
```

### Instalación mediante `curl`

El instalador contiene copias embebidas de la sesión de kitty y del launcher, por lo que
funciona sin clonar el repositorio:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash
```

Para revisar el código antes de ejecutarlo:

```bash
curl --proto '=https' --tlsv1.2 -fsSLo install-dashbash.sh https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh
less install-dashbash.sh
chmod +x install-dashbash.sh
./install-dashbash.sh
```

### Modos de uso

El administrador maestro ofrece un menú interactivo al ejecutarlo sin argumentos:

```bash
./dashbash-manager.sh
```

También admite comandos directos, útiles para automatización:

```bash
./dashbash-manager.sh install
./dashbash-manager.sh uninstall
./dashbash-manager.sh update
```

`update` elimina los archivos administrados y ejecuta inmediatamente una instalación
nueva. Conserva las dependencias, los respaldos y cualquier `kitty.conf` personalizado.

| Comando | Resultado |
|---|---|
| `./install-dashbash.sh` | Instala dependencias, configuración y launcher |
| `./install-dashbash.sh --check` | Diagnostica sin cambios; devuelve `1` si falta algo |
| `./install-dashbash.sh --no-config` | Instala solo dependencias y omite `~/.config` y `~/bin` |
| `./install-dashbash.sh --help` | Muestra la ayuda |

### Desinstalación

Para retirar los archivos propios de dashbash sin eliminar programas compartidos:

```bash
./uninstall-dashbash.sh
```

Para previsualizar las acciones o realizar una desinstalación completa con dependencias:

```bash
./uninstall-dashbash.sh --dry-run
./uninstall-dashbash.sh --purge-deps
```

`--purge-deps` elimina los crates y las herramientas APT específicas del dashboard; úsalo
solo si no las necesitas para otros fines. Conserva dependencias fundamentales compartidas
como `systemd`, `procps`, `iproute2`, locales, certificados y toolchains. Los respaldos
`.bak.*` y un `kitty.conf` personalizado siempre se conservan.

Los argumentos también funcionan mediante stdin:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash -s -- --check
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash -s -- --no-config
```

### Qué instala

Paquetes APT:

`kitty`, `fastfetch`, `btop`, `bmon`, `iproute2`, `procps`, `nvtop`, `gdu`, `ranger`,
`systemd`, `locales`, `fontconfig`, `fonts-jetbrains-mono`, `ca-certificates`, `curl`,
`build-essential` y `pkg-config`.

Crates de Rust:

| Crate | Binario | Uso |
|---|---|---|
| `clock-tui` | `tclock` | Reloj de Home |
| `bottom` 0.13.0 | `btm` | Pestaña Monitor; compatible con Rust 1.85 o posterior |

El instalador garantiza que `rustup` esté disponible, actualiza Rust al canal estable más
reciente y lo establece como predeterminado. Esto instala o actualiza conjuntamente
`rustc` y `cargo`. La primera descarga y compilación puede tardar varios minutos. El
launcher añade `~/.cargo/bin` a su `PATH` para que siempre encuentre `tclock` y `btm`.
También genera `es_CL.UTF-8` para el reloj. `bottom` se fija en 0.13.0 como protección
adicional frente a cambios incompatibles en versiones futuras.

### Archivos administrados

| Destino | Comportamiento |
|---|---|
| `~/.config/kitty/dashboard.conf` | Se actualiza desde el repositorio o la copia embebida |
| `~/bin/dashbash` | Launcher ejecutable de kitty |
| `~/.config/kitty/kitty.conf` | Se crea solo si no existe; no reemplaza personalizaciones |
| `~/.bashrc` | Añade `~/bin` al `PATH` únicamente cuando hace falta |
| `~/.local/state/dashbash/fastfetch-ppa-added` | Registra si el instalador añadió el PPA de Fastfetch |

Antes de reemplazar un archivo administrado, se crea una copia `.bak.<timestamp>`. Una
reinstalación sin cambios no genera respaldos adicionales.

### Ejecutar y personalizar

Después de abrir una shell nueva:

```bash
dashbash
```

Si el comando todavía no aparece en el `PATH`:

```bash
source ~/.bashrc
command -v dashbash
```

Para personalizar las pestañas, edita `config/dashboard.conf` y vuelve a ejecutar el
instalador. Si agregas una herramienta, incorpórala también a `APT_DEPS` o `CARGO_DEPS` en
`install-dashbash.sh` para mantener sincronizados la instalación y `--check`.

### Pruebas

La suite usa un `HOME` temporal y simula APT, dpkg, cargo, sudo y locales. No instala
paquetes reales ni modifica la configuración del usuario:

```bash
bash tests/run.sh
```

Cubre CLI, diagnóstico, paquetes extra, instalación local y vía stdin, `--no-config`,
idempotencia, respaldos, launcher y las ocho pestañas.

### Estructura

```text
dashbash-installer/
├── dashbash-manager.sh
├── install-dashbash.sh
├── uninstall-dashbash.sh
├── bin/
│   └── dashbash
├── config/
│   └── dashboard.conf
├── tests/
│   ├── run.sh
│   └── support/
│       └── mock-command
└── README.md
```

[Volver al selector de idioma](#dashbash)

---

## English

`dashbash` installs and launches a system-monitoring dashboard in
[kitty](https://sw.kovidgoyal.net/kitty/) with eight tabs of TUI tools. The installer
targets Debian/Ubuntu, is idempotent, and can run from a local clone or directly through
`curl`.

### Overview

| # | Tab | Tools | Purpose |
|---:|---|---|---|
| 1 | `Home` | `tclock`, `fastfetch` | Clock and system information |
| 2 | `System` | `btop` | CPU, memory, and processes |
| 3 | `Network` | `bmon`, `watch`, `ss` | Network traffic and listening ports |
| 4 | `Hardware` | `nvtop` | GPU usage, memory, and temperature |
| 5 | `Disks` | `gdu` | Interactive disk usage |
| 6 | `Monitor` | `btm` | Consolidated system view |
| 7 | `Files` | `ranger` | File browser |
| 8 | `Logs` | `journalctl` | Live system logs |

### Requirements

- Debian, Ubuntu, or Kubuntu with `apt-get`.
- Root access or `sudo` for system packages and locales.
- A graphical environment to launch kitty.
- `systemd` for the logs tab.
- Compatible GPU drivers for `nvtop` data.

The project is compatible with Ubuntu and Kubuntu 24.04 LTS on amd64. Kubuntu uses the same
Ubuntu package base and repositories, and KDE Plasma requires no installer changes. The
`universe` and `multiverse` components must be enabled because several dependencies come
from them. Other recent Debian/Ubuntu releases should work, but are not verified.

On Ubuntu 24.04, where `fastfetch` is not yet part of the official repository, the
installer adds `ppa:zhangsongcui3371/fastfetch`, as recommended by the
[official Fastfetch documentation](https://github.com/fastfetch-cli/fastfetch#installation).

Before changing system packages or locales, the script announces the operation and runs
`sudo -v`. When authentication is needed, `sudo` requests the password directly in the
terminal. Files inside the home directory are managed without `sudo`.

### Distribution compatibility

Checked on **September 1, 2026**. “Tested” means `install-dashbash.sh --check` was run in a
clean official image and every declared APT package was queried. Launching the kitty GUI
cannot be validated inside a container.

| Distribution | Status | Evidence and adjustments |
|---|---|---|
| Ubuntu 24.04 LTS | ✅ Compatible | `fastfetch` requires the PPA recommended by its project, which the installer adds automatically. Enable `universe` and `multiverse`. |
| Kubuntu 24.04 LTS | ✅ Compatible | Uses the Ubuntu Noble base; the installer automatically adds the `fastfetch` PPA. Enable `universe` and `multiverse`. |
| Linux Mint 22.x | 🟡 Base-compatible | Mint 22.x uses Ubuntu Noble. A complete desktop image was not tested. This does not cover LMDE. |
| Ubuntu-based Pop!_OS | 🟡 Base-compatible | Uses APT and Ubuntu repositories; a complete desktop image was not tested. |
| Debian 13 (Trixie) | ✅ Tested | Diagnostics run and every declared APT package is available. |
| Debian 12 (Bookworm) | ⚠️ Adjustment required | `nvtop` requires `contrib`, and `fastfetch` is absent from the official repositories; install it manually. |
| Fedora 42 | ❌ Unsupported | Tested: exits safely because `apt-get` is absent; a DNF backend is required. |
| Arch Linux / Manjaro | ❌ Unsupported | Tested on Arch: exits safely; a pacman/AUR backend is required. |
| openSUSE Leap 15.6 | ❌ Unsupported | Tested: exits safely; a Zypper backend is required. |

On Ubuntu, Kubuntu, Mint, or Pop!_OS, enable missing repository components with:

```bash
sudo add-apt-repository universe
sudo add-apt-repository multiverse
sudo apt update
```

On Debian 12, add `contrib` to the Debian source `Components` in `/etc/apt/sources.list` or
`/etc/apt/sources.list.d/*.sources`, then run:

```bash
sudo apt update
```

Unsupported distributions need more than package-name substitutions: the installer needs
a package-manager backend, package mappings, and dedicated tests.

### Install from the repository

```bash
git clone https://github.com/jerpdev9/dashboardbash.git dashbash-installer
cd dashbash-installer
./install-dashbash.sh
```

### Install with `curl`

The kitty session and launcher are embedded in the installer, so cloning is optional:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash
```

To inspect the script before running it:

```bash
curl --proto '=https' --tlsv1.2 -fsSLo install-dashbash.sh https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh
less install-dashbash.sh
chmod +x install-dashbash.sh
./install-dashbash.sh
```

### Usage modes

The master manager displays an interactive menu when run without arguments:

```bash
./dashbash-manager.sh
```

It also accepts direct commands for automation:

```bash
./dashbash-manager.sh install
./dashbash-manager.sh uninstall
./dashbash-manager.sh update
```

`update` removes managed files and immediately performs a fresh installation. It preserves
dependencies, backups, and any customized `kitty.conf`.

| Command | Result |
|---|---|
| `./install-dashbash.sh` | Installs dependencies, configuration, and launcher |
| `./install-dashbash.sh --check` | Diagnoses without changes; exits with `1` if anything is missing |
| `./install-dashbash.sh --no-config` | Installs dependencies only and skips `~/.config` and `~/bin` |
| `./install-dashbash.sh --help` | Displays help |

### Uninstallation

To remove dashbash-owned files without deleting shared programs:

```bash
./uninstall-dashbash.sh
```

To preview the actions or perform a complete uninstall including dependencies:

```bash
./uninstall-dashbash.sh --dry-run
./uninstall-dashbash.sh --purge-deps
```

`--purge-deps` removes the crates and dashboard-specific APT tools; use it only if you do
not need those tools elsewhere. It preserves shared foundational dependencies such as
`systemd`, `procps`, `iproute2`, locales, certificates, and build toolchains. `.bak.*`
backups and a customized `kitty.conf` are always preserved.

Arguments also work when the script is provided through stdin:

```bash
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash -s -- --check
curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/jerpdev9/dashboardbash/main/install-dashbash.sh | bash -s -- --no-config
```

### What gets installed

APT packages:

`kitty`, `fastfetch`, `btop`, `bmon`, `iproute2`, `procps`, `nvtop`, `gdu`, `ranger`,
`systemd`, `locales`, `fontconfig`, `fonts-jetbrains-mono`, `ca-certificates`, `curl`,
`build-essential`, and `pkg-config`.

Rust crates:

| Crate | Binary | Used by |
|---|---|---|
| `clock-tui` | `tclock` | Home clock |
| `bottom` 0.13.0 | `btm` | Monitor tab; compatible with Rust 1.85 or newer |

The installer ensures `rustup` is available, updates Rust to the latest stable channel, and
makes it the default. This installs or updates both `rustc` and `cargo`. The first download
and crate compilation may take several minutes. The launcher adds `~/.cargo/bin` to its
`PATH` so it can always find `tclock` and `btm`. It also generates `es_CL.UTF-8` for the
clock. `bottom` remains pinned to 0.13.0 as additional protection against incompatible
future changes.

### Managed files

| Destination | Behavior |
|---|---|
| `~/.config/kitty/dashboard.conf` | Updated from the repository or embedded copy |
| `~/bin/dashbash` | Executable kitty launcher |
| `~/.config/kitty/kitty.conf` | Created only when absent; customizations are not overwritten |
| `~/.bashrc` | Adds `~/bin` to `PATH` only when needed |
| `~/.local/state/dashbash/fastfetch-ppa-added` | Records whether the installer added the Fastfetch PPA |

Before replacing a managed file, the installer creates a `.bak.<timestamp>` copy. Running
it again without changes does not create additional backups.

### Run and customize

After opening a new shell:

```bash
dashbash
```

If the command is not in `PATH` yet:

```bash
source ~/.bashrc
command -v dashbash
```

To customize the tabs, edit `config/dashboard.conf` and rerun the installer. When adding a
tool, also add it to `APT_DEPS` or `CARGO_DEPS` in `install-dashbash.sh` so installation
and `--check` stay in sync.

### Tests

The suite uses a temporary `HOME` and mocks APT, dpkg, cargo, sudo, and locales. It does
not install real packages or modify the user's configuration:

```bash
bash tests/run.sh
```

It covers the CLI, diagnostics, extra packages, local and stdin installation,
`--no-config`, idempotency, backups, the launcher, and all eight tabs.

### Project structure

```text
dashbash-installer/
├── dashbash-manager.sh
├── install-dashbash.sh
├── uninstall-dashbash.sh
├── bin/
│   └── dashbash
├── config/
│   └── dashboard.conf
├── tests/
│   ├── run.sh
│   └── support/
│       └── mock-command
└── README.md
```

[Back to language selector](#dashbash)
