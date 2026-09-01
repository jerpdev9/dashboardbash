#!/usr/bin/env bash
# ==============================================================================
#  install-dashbash.sh — Instala todo lo necesario para ejecutar `dashbash`
#
#  `dashbash` lanza Kitty en modo maximizado con la sesión ~/.config/kitty/dashboard.conf,
#  que abre 8 pestañas de monitoreo:
#     Home      → tclock (clock-tui) + fastfetch
#     System    → btop
#     Network   → bmon + watch/ss (iproute2, procps)
#     Hardware  → nvtop
#     Disks     → gdu
#     Monitor   → btm (bottom)
#     Files     → ranger
#     Logs      → journalctl (systemd)
#
#  Compatible con: Ubuntu/Kubuntu 24.04 LTS (noble) / amd64
#  Uso:
#     ./install-dashbash.sh                 # instala dependencias + config + launcher
#     ./install-dashbash.sh --no-config     # solo dependencias, no toca ~/.config ni ~/bin
#     ./install-dashbash.sh --check         # solo diagnostica qué falta, no instala nada
# ==============================================================================

set -Eeuo pipefail

# ──────────────────────────────────────────────────────────────────────────────
#  Presentación
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
    C_OK=$'\033[32m';   C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_INFO=$'\033[36m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_OK=''; C_WARN=''; C_ERR=''; C_INFO=''
fi

log()  { printf '%s==>%s %s\n'  "$C_INFO$C_BOLD" "$C_RESET" "$*"; }
ok()   { printf '%s  ok%s  %s\n' "$C_OK"   "$C_RESET" "$*"; }
warn() { printf '%s  !!%s  %s\n' "$C_WARN" "$C_RESET" "$*" >&2; }
die()  { printf '%s ERROR:%s %s\n' "$C_ERR$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }
step() { printf '\n%s──%s %s %s\n' "$C_BOLD" "$C_RESET" "$C_BOLD$*$C_RESET" "$C_DIM$(printf '─%.0s' $(seq 1 20))$C_RESET"; }

trap 'die "falló la línea $LINENO (comando: ${BASH_COMMAND})"' ERR

# Directorio del propio script: si venimos del repo usamos sus archivos de config;
# con `curl | bash`, BASH_SOURCE no está definido y usamos las copias embebidas.
SCRIPT_DIR=""
if [[ -n ${BASH_SOURCE[0]:-} ]]; then
    SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
fi

# ──────────────────────────────────────────────────────────────────────────────
#  Flags
# ──────────────────────────────────────────────────────────────────────────────
DO_CONFIG=1
CHECK_ONLY=0

show_help() {
    cat <<'HELP_EOF'
install-dashbash.sh — instala el dashboard de monitoreo dashbash

Uso:
  install-dashbash.sh [--check | --no-config | --help]

Opciones:
  --check       Diagnostica qué falta sin instalar ni modificar archivos.
  --no-config   Instala dependencias sin tocar ~/.config ni ~/bin.
  -h, --help    Muestra esta ayuda.
HELP_EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-config) DO_CONFIG=0 ;;
        --check)     CHECK_ONLY=1 ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
    shift
done

# ──────────────────────────────────────────────────────────────────────────────
#  Definición de dependencias
# ──────────────────────────────────────────────────────────────────────────────

# Paquetes APT: <binario>:<paquete>
APT_DEPS=(
    "kitty:kitty"                       # terminal que hospeda el dashboard
    "fastfetch:fastfetch"               # información del sistema (tab Home)
    "btop:btop"                         # monitor de sistema (tab System)
    "bmon:bmon"                         # monitor de ancho de banda (tab Network)
    "ss:iproute2"                       # sockets/puertos (tab Network)
    "watch:procps"                      # refresco periódico de ss (tab Network)
    "nvtop:nvtop"                       # monitor de GPU (tab Hardware)
    "gdu:gdu"                           # uso de disco (tab Disks)
    "ranger:ranger"                     # explorador de archivos (tab Files)
    "journalctl:systemd"                # logs del sistema (tab Logs)
    "locale:locales"                    # necesario para es_CL.UTF-8 del reloj
    "fc-list:fontconfig"                # gestión de fuentes
)

# Paquetes APT extra (sin binario propio que verificar)
APT_EXTRA=(
    fonts-jetbrains-mono                # font_family de kitty.conf
    ca-certificates
    curl
    build-essential                     # toolchain para compilar los crates de Rust
    pkg-config
)

# Crates de Rust: <binario>:<crate>[:<versión fijada>]
CARGO_DEPS=(
    "tclock:clock-tui"                  # reloj TUI del tab Home
    "btm:bottom:0.13.0"                 # compatible con rustc >= 1.85
)

DASH_LOCALE="es_CL.UTF-8"
LOCALE_GEN_FILE="${LOCALE_GEN_FILE:-/etc/locale.gen}"
OS_RELEASE_FILE="${OS_RELEASE_FILE:-/etc/os-release}"
STATE_DIR="$HOME/.local/state/dashbash"

# ──────────────────────────────────────────────────────────────────────────────
#  Utilidades
# ──────────────────────────────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

SUDO=""
setup_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif have sudo; then
        SUDO="sudo"
        log "Se requieren privilegios para instalar paquetes y configurar el locale."
        printf '  sudo solicitará tu contraseña en esta terminal si es necesario.\n'
        sudo -v || die "no se obtuvo autorización de sudo"
    else
        die "se necesita root o sudo para instalar paquetes del sistema"
    fi
}

check_os() {
    [[ -r "$OS_RELEASE_FILE" ]] || die "no se pudo leer $OS_RELEASE_FILE"
    # shellcheck source=/dev/null
    . "$OS_RELEASE_FILE"
    have apt-get || die "este script asume Debian/Ubuntu (apt-get). Detectado: ${PRETTY_NAME:-desconocido}"
    log "Sistema: ${PRETTY_NAME:-$ID $VERSION_ID}"
    case "${ID:-}${ID_LIKE:-}" in
        *debian*|*ubuntu*) : ;;
        *) warn "distro no verificada (${ID:-?}); se continuará usando apt-get" ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
#  Diagnóstico
# ──────────────────────────────────────────────────────────────────────────────
report() {
    step "Estado de dependencias"
    local include_config="${1:-1}"
    local bin pkg path missing=0
    for entry in "${APT_DEPS[@]}" "${CARGO_DEPS[@]}"; do
        bin="${entry%%:*}"; pkg="${entry#*:}"
        pkg="${pkg%%:*}"
        if path="$(command -v "$bin" 2>/dev/null)"; then
            printf '  %s✔%s %-12s %s%s%s\n' "$C_OK" "$C_RESET" "$bin" "$C_DIM" "$path" "$C_RESET"
        else
            printf '  %s✘%s %-12s %sfalta (%s)%s\n' "$C_ERR" "$C_RESET" "$bin" "$C_WARN" "$pkg" "$C_RESET"
            missing=$((missing + 1))
        fi
    done

    for pkg in "${APT_EXTRA[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            printf '  %s✔%s %-12s %s%s%s\n' "$C_OK" "$C_RESET" "$pkg" "$C_DIM" "paquete instalado" "$C_RESET"
        else
            printf '  %s✘%s %-12s %sfalta (apt)%s\n' "$C_ERR" "$C_RESET" "$pkg" "$C_WARN" "$C_RESET"
            missing=$((missing + 1))
        fi
    done

    if locale -a 2>/dev/null | grep -qiE "^${DASH_LOCALE//./\\.}$|^es_CL\.utf8$"; then
        printf '  %s✔%s %-12s %s%s%s\n' "$C_OK" "$C_RESET" "locale" "$C_DIM" "$DASH_LOCALE generado" "$C_RESET"
    else
        printf '  %s✘%s %-12s %sfalta %s%s\n' "$C_ERR" "$C_RESET" "locale" "$C_WARN" "$DASH_LOCALE" "$C_RESET"
        missing=$((missing + 1))
    fi

    if [[ $include_config -eq 1 ]]; then
        for f in "$HOME/.config/kitty/dashboard.conf" "$HOME/bin/dashbash"; do
            if [[ -e "$f" ]]; then
                printf '  %s✔%s %-12s %s%s%s\n' "$C_OK" "$C_RESET" "$(basename "$f")" "$C_DIM" "$f" "$C_RESET"
            else
                printf '  %s✘%s %-12s %sfalta %s%s\n' "$C_ERR" "$C_RESET" "$(basename "$f")" "$C_WARN" "$f" "$C_RESET"
                missing=$((missing + 1))
            fi
        done
    fi

    return "$missing"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Instalación: paquetes APT
# ──────────────────────────────────────────────────────────────────────────────
install_apt() {
    step "Paquetes del sistema (apt)"
    local bin pkg pending=()

    for entry in "${APT_DEPS[@]}"; do
        bin="${entry%%:*}"; pkg="${entry#*:}"
        if have "$bin"; then
            ok "$bin ya presente"
        else
            pending+=("$pkg")
        fi
    done

    for pkg in "${APT_EXTRA[@]}"; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            ok "$pkg ya instalado"
        else
            pending+=("$pkg")
        fi
    done

    if [[ ${#pending[@]} -eq 0 ]]; then
        ok "nada que instalar desde apt"
        return 0
    fi

    log "Instalando: ${pending[*]}"
    $SUDO apt-get update -qq
    DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends "${pending[@]}"
    ok "paquetes apt instalados"
}

ensure_fastfetch_repository() {
    have fastfetch && return 0
    if have apt-cache && apt-cache show fastfetch >/dev/null 2>&1; then
        return 0
    fi

    case "${ID:-}${ID_LIKE:-}" in
        *ubuntu*)
            step "Repositorio de Fastfetch"
            if ! have add-apt-repository; then
                log "Instalando software-properties-common para administrar el PPA"
                $SUDO apt-get update -qq
                DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y --no-install-recommends software-properties-common
            fi
            log "Añadiendo ppa:zhangsongcui3371/fastfetch"
            $SUDO add-apt-repository -y ppa:zhangsongcui3371/fastfetch
            mkdir -p "$STATE_DIR"
            : > "$STATE_DIR/fastfetch-ppa-added"
            ;;
        *)
            die "fastfetch no está disponible en los repositorios APT configurados; instálalo manualmente y vuelve a ejecutar el script"
            ;;
    esac
}

# ──────────────────────────────────────────────────────────────────────────────
#  Instalación: locale es_CL.UTF-8 (lo usa el reloj del tab Home)
# ──────────────────────────────────────────────────────────────────────────────
install_locale() {
    step "Locale $DASH_LOCALE"
    if locale -a 2>/dev/null | grep -qi '^es_CL\.utf8$'; then
        ok "$DASH_LOCALE ya está generado"
        return 0
    fi

    if [[ -f "$LOCALE_GEN_FILE" ]]; then
        $SUDO sed -i "s/^# *\(${DASH_LOCALE} UTF-8\)/\1/" "$LOCALE_GEN_FILE"
        grep -q "^${DASH_LOCALE} UTF-8" "$LOCALE_GEN_FILE" \
            || echo "${DASH_LOCALE} UTF-8" | $SUDO tee -a "$LOCALE_GEN_FILE" >/dev/null
    fi
    $SUDO locale-gen "$DASH_LOCALE"
    ok "$DASH_LOCALE generado"
}

# ──────────────────────────────────────────────────────────────────────────────
#  Instalación: toolchain de Rust + crates (tclock, btm)
# ──────────────────────────────────────────────────────────────────────────────
install_rust() {
    step "Toolchain de Rust"
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! have rustup; then
        log "Instalando rustup (no interactivo)…"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --profile minimal
        # shellcheck source=/dev/null
        [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
        have rustup || die "rustup no quedó disponible después de instalarlo"
    else
        ok "rustup ya está instalado"
    fi

    log "Actualizando Rust al canal estable más reciente…"
    rustup set profile minimal
    rustup update stable
    rustup default stable
    have rustc || die "rustc no quedó disponible después de actualizar Rust"
    have cargo || die "cargo no quedó disponible después de actualizar Rust"
    ok "$(rustc --version 2>/dev/null | head -1)"
    ok "$(cargo --version 2>/dev/null | head -1)"
}

install_crates() {
    step "Crates de Rust"
    local bin crate rest version
    for entry in "${CARGO_DEPS[@]}"; do
        bin="${entry%%:*}"
        rest="${entry#*:}"
        crate="${rest%%:*}"
        version=""
        [[ "$rest" == *:* ]] && version="${rest#*:}"
        if have "$bin"; then
            ok "$bin ya presente ($crate${version:+ $version})"
            continue
        fi
        log "cargo install $crate${version:+ $version}  → provee '$bin' (compila, puede tardar varios minutos)"
        if [[ -n "$version" ]]; then
            cargo install --locked "$crate" --version "$version"
        else
            cargo install --locked "$crate"
        fi
        ok "$bin instalado"
    done
}

# ──────────────────────────────────────────────────────────────────────────────
#  Configuración: sesión de kitty + launcher `dashbash`
# ──────────────────────────────────────────────────────────────────────────────
backup_if_exists() {
    local f="$1"
    if [[ -e "$f" ]]; then
        local bak="${f}.bak.$(date +%Y%m%d%H%M%S)"
        cp -a "$f" "$bak"
        warn "respaldo: $bak"
    fi
}

install_kitty_session() {
    step "Sesión de kitty (dashboard.conf)"
    local dir="$HOME/.config/kitty"
    local session="$dir/dashboard.conf"
    mkdir -p "$dir"

    local tmp; tmp="$(mktemp)"
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/config/dashboard.conf" ]]; then
        cp "$SCRIPT_DIR/config/dashboard.conf" "$tmp"
    else
    cat > "$tmp" <<'SESSION_EOF'
# TAB 1 — Home (hora · información del sistema)
new_tab Home
layout tall
launch sh -lc 'LC_TIME=es_CL.UTF-8 tclock -c "#E6B35A"'
launch fastfetch

# TAB 2 — System
new_tab System
launch btop

# TAB 3 — Network
new_tab Network
layout tall
launch bmon
launch sh -lc 'watch -n 2 "ss -tulpn"'

# TAB 4 — Hardware (GPU)
new_tab Hardware
launch nvtop

# TAB 5 — Disks
new_tab Disks
launch gdu -d

# TAB 6 — Monitor
new_tab Monitor
launch btm

# TAB 7 — Files
new_tab Files
launch ranger

# TAB 8 — Logs
new_tab Logs
layout tall
launch journalctl -f
SESSION_EOF
    fi

    if [[ -f "$session" ]] && cmp -s "$tmp" "$session"; then
        ok "dashboard.conf ya está al día"
        rm -f "$tmp"
    else
        backup_if_exists "$session"
        mv "$tmp" "$session"
        chmod 644 "$session"
        ok "escrito $session"
    fi

    # kitty.conf mínimo solo si no existe (no pisamos personalizaciones)
    local kconf="$dir/kitty.conf"
    if [[ ! -f "$kconf" ]]; then
        cat > "$kconf" <<'KITTY_EOF'
font_family JetBrains Mono
font_size 14.0
KITTY_EOF
        ok "creado $kconf (font JetBrains Mono 14)"
    else
        ok "kitty.conf existente respetado"
    fi
}

install_launcher() {
    step "Launcher 'dashbash'"
    local bindir="$HOME/bin"
    local launcher="$bindir/dashbash"
    mkdir -p "$bindir"

    local tmp; tmp="$(mktemp)"
    if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/bin/dashbash" ]]; then
        cp "$SCRIPT_DIR/bin/dashbash" "$tmp"
    else
cat > "$tmp" <<'DASH_EOF'
#!/usr/bin/env bash
export PATH="$HOME/.cargo/bin:$PATH"
exec kitty --start-as=maximized --session "$HOME/.config/kitty/dashboard.conf"
DASH_EOF
    fi

    if [[ -f "$launcher" ]] && cmp -s "$tmp" "$launcher"; then
        ok "~/bin/dashbash ya está al día"
        rm -f "$tmp"
    else
        backup_if_exists "$launcher"
        mv "$tmp" "$launcher"
        ok "escrito $launcher"
    fi
    chmod 755 "$launcher"

    case ":$PATH:" in
        *":$bindir:"*) ok "$bindir ya está en el PATH" ;;
        *)
            local rc="$HOME/.bashrc"
            if ! grep -qs 'HOME/bin' "$rc"; then
                printf '\n# añadido por install-dashbash.sh\nexport PATH="$HOME/bin:$PATH"\n' >> "$rc"
                warn "se añadió \$HOME/bin al PATH en $rc — abre una shell nueva o ejecuta: source $rc"
            else
                warn "$rc ya menciona \$HOME/bin, pero no está en el PATH actual: abre una shell nueva"
            fi
            ;;
    esac

}

# ──────────────────────────────────────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────────────────────────────────────
main() {
    printf '%s\n' "${C_BOLD}install-dashbash.sh — dependencias del dashboard 'dashbash'${C_RESET}"

    check_os

    if [[ $CHECK_ONLY -eq 1 ]]; then
        if report; then
            printf '\n%sTodo listo.%s Ejecuta: %sdashbash%s\n' "$C_OK$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
        else
            missing=$?
            printf '\n%sFaltan %s elementos.%s Ejecuta este script sin --check para instalarlos.\n' \
                "$C_WARN$C_BOLD" "$missing" "$C_RESET"
            exit 1
        fi
        exit 0
    fi

    setup_sudo
    ensure_fastfetch_repository
    install_apt
    install_locale
    install_rust
    install_crates

    if [[ $DO_CONFIG -eq 1 ]]; then
        install_kitty_session
        install_launcher
    else
        warn "--no-config: no se tocaron ~/.config/kitty ni ~/bin"
    fi

    step "Verificación final"
    if report "$DO_CONFIG"; then
        printf '\n%s✔ Todo instalado.%s Lanza el dashboard con: %sdashbash%s\n' \
            "$C_OK$C_BOLD" "$C_RESET" "$C_BOLD" "$C_RESET"
    else
        printf '\n%s! Quedan elementos pendientes%s (ver arriba).\n' "$C_WARN$C_BOLD" "$C_RESET"
        printf '  Notas: nvtop necesita drivers de GPU cargados para mostrar datos;\n'
        printf '         journalctl requiere systemd (no disponible en WSL1/contenedores).\n'
        exit 1
    fi
}

main "$@"
