#!/usr/bin/env bash
# Desinstala dashbash de forma segura. Las dependencias solo se retiran bajo petición.

set -Eeuo pipefail

PURGE_DEPS=0
DRY_RUN=0
SUDO=""

log()  { printf '==> %s\n' "$*"; }
ok()   { printf '  ok  %s\n' "$*"; }
warn() { printf '  !!  %s\n' "$*" >&2; }
die()  { printf ' ERROR: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

show_help() {
    cat <<'HELP_EOF'
uninstall-dashbash.sh — desinstala el dashboard dashbash

Uso:
  uninstall-dashbash.sh [--purge-deps] [--dry-run] [--help]

Opciones:
  --purge-deps  También desinstala crates y herramientas APT específicas de dashbash.
                Atención: puede quitar programas que ya usabas antes de dashbash.
  --dry-run     Muestra las acciones sin modificar el sistema.
  -h, --help    Muestra esta ayuda.

Sin --purge-deps se eliminan únicamente el launcher, la sesión de kitty, el
kitty.conf generado sin modificar y el bloque PATH añadido por el instalador.
Los archivos .bak.* y cualquier kitty.conf personalizado se conservan.
HELP_EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --purge-deps) PURGE_DEPS=1 ;;
        --dry-run)    DRY_RUN=1 ;;
        -h|--help)    show_help; exit 0 ;;
        *) die "opción desconocida: $1 (usa --help)" ;;
    esac
    shift
done

run() {
    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  →'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

remove_file() {
    local path="$1"
    if [[ -e "$path" || -L "$path" ]]; then
        run rm -f -- "$path"
        ok "eliminado $path"
    else
        ok "$path ya no existe"
    fi
}

remove_generated_kitty_conf() {
    local path="$HOME/.config/kitty/kitty.conf"
    [[ -f "$path" ]] || { ok "$path ya no existe"; return; }

    local expected
    expected=$'font_family JetBrains Mono\nfont_size 14.0'
    if [[ $(<"$path") == "$expected" ]]; then
        remove_file "$path"
    else
        warn "se conserva $path porque contiene personalizaciones"
    fi
}

remove_bashrc_block() {
    local rc="$HOME/.bashrc"
    [[ -f "$rc" ]] || { ok "$rc ya no existe"; return; }
    if ! grep -Fq '# añadido por install-dashbash.sh' "$rc"; then
        ok "el bloque PATH de dashbash ya no está en $rc"
        return
    fi

    if [[ $DRY_RUN -eq 1 ]]; then
        printf '  → eliminar bloque PATH de %q\n' "$rc"
    else
        local tmp
        tmp="$(mktemp)"
        sed '/^# añadido por install-dashbash\.sh$/ { N; /^# añadido por install-dashbash\.sh\nexport PATH="\$HOME\/bin:\$PATH"$/d; }' "$rc" > "$tmp"
        mv "$tmp" "$rc"
    fi
    ok "eliminado el bloque PATH añadido por dashbash"
}

remove_empty_dirs() {
    local dir
    for dir in "$HOME/.config/kitty" "$HOME/.config" "$HOME/bin"; do
        [[ -d "$dir" ]] || continue
        if [[ $DRY_RUN -eq 1 ]]; then
            printf '  → rmdir (si está vacío) %q\n' "$dir"
        else
            rmdir -- "$dir" 2>/dev/null || true
        fi
    done
}

setup_sudo() {
    if [[ $EUID -eq 0 ]]; then
        SUDO=""
    elif have sudo; then
        SUDO="sudo"
        log "Se requieren privilegios para retirar las herramientas APT."
        printf '  sudo solicitará tu contraseña en esta terminal si es necesario.\n'
        sudo -v || die "no se obtuvo autorización de sudo"
    else
        die "se necesita root o sudo para retirar paquetes APT"
    fi
}

purge_dependencies() {
    log "Crates de Rust"
    if have cargo; then
        run cargo uninstall clock-tui bottom
        ok "solicitada la desinstalación de clock-tui y bottom"
    else
        warn "cargo no está disponible; no se retiraron los crates"
    fi

    have apt-get || die "--purge-deps requiere apt-get (Debian/Ubuntu)"
    setup_sudo
    # No se purgan dependencias fundamentales compartidas (systemd, procps,
    # iproute2, locales, curl, certificados ni toolchains de compilación).
    local packages=(kitty cava btop bmon nvtop gdu ranger fonts-jetbrains-mono)
    log "Paquetes del sistema"
    run ${SUDO:+$SUDO} apt-get purge -y "${packages[@]}"
    ok "herramientas APT específicas de dashbash retiradas"
}

main() {
    printf 'uninstall-dashbash.sh — desinstalación de dashbash\n'
    [[ $DRY_RUN -eq 0 ]] || warn "modo simulación: no se modificará nada"

    log "Archivos de dashbash"
    remove_file "$HOME/bin/dashbash"
    remove_file "$HOME/.config/kitty/dashboard.conf"
    remove_generated_kitty_conf
    remove_bashrc_block
    remove_empty_dirs

    if [[ $PURGE_DEPS -eq 1 ]]; then
        purge_dependencies
    else
        warn "se conservaron las dependencias; usa --purge-deps para retirarlas"
    fi

    printf '\n✔ dashbash desinstalado%s.\n' "$([[ $DRY_RUN -eq 1 ]] && printf ' (simulación)' || true)"
}

main
