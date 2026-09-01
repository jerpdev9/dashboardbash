#!/usr/bin/env bash
# Punto de entrada para instalar, desinstalar o actualizar dashbash.

set -Eeuo pipefail

die() { printf ' ERROR: %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
INSTALLER="$SCRIPT_DIR/install-dashbash.sh"
UNINSTALLER="$SCRIPT_DIR/uninstall-dashbash.sh"

show_help() {
    cat <<'HELP_EOF'
dashbash-manager.sh — administrador de dashbash

Uso:
  ./dashbash-manager.sh
  ./dashbash-manager.sh install [--check | --no-config]
  ./dashbash-manager.sh uninstall [--purge-deps | --dry-run]
  ./dashbash-manager.sh update
  ./dashbash-manager.sh help

Comandos:
  install      Ejecuta el instalador. Admite sus opciones habituales.
  uninstall    Ejecuta el desinstalador. Conserva dependencias por defecto.
  update       Desinstala los archivos administrados y vuelve a instalarlos.
  help         Muestra esta ayuda.

Sin argumentos se muestra un menú interactivo.
HELP_EOF
}

require_script() {
    local path="$1"
    [[ -f "$path" ]] || die "no se encontró $path; ejecuta el administrador desde el repositorio completo"
}

install_dashbash() {
    require_script "$INSTALLER"
    bash "$INSTALLER" "$@"
}

uninstall_dashbash() {
    require_script "$UNINSTALLER"
    bash "$UNINSTALLER" "$@"
}

update_dashbash() {
    [[ $# -eq 0 ]] || die "update no admite opciones"
    require_script "$INSTALLER"
    require_script "$UNINSTALLER"
    printf '==> Actualizando dashbash: limpieza de archivos administrados\n'
    bash "$UNINSTALLER"
    printf '\n==> Reinstalando la versión actual de dashbash\n'
    bash "$INSTALLER"
    printf '\n✔ dashbash actualizado correctamente.\n'
}

interactive_menu() {
    [[ -t 0 ]] || die "sin terminal interactiva; usa install, uninstall, update o help"
    printf '%s\n' \
        'dashbash — administrador maestro' \
        '' \
        '  1) Instalar' \
        '  2) Desinstalar' \
        '  3) Actualizar (desinstalar y volver a instalar)' \
        '  4) Salir' \
        ''
    read -r -p 'Selecciona una opción [1-4]: ' choice
    case "$choice" in
        1) install_dashbash ;;
        2) uninstall_dashbash ;;
        3) update_dashbash ;;
        4) printf 'Operación cancelada.\n' ;;
        *) die "opción inválida: ${choice:-vacía}" ;;
    esac
}

main() {
    if [[ $# -eq 0 ]]; then
        interactive_menu
        return
    fi

    local command="$1"
    shift
    case "$command" in
        install|instalar)       install_dashbash "$@" ;;
        uninstall|desinstalar) uninstall_dashbash "$@" ;;
        update|actualizar)      update_dashbash "$@" ;;
        help|-h|--help)         show_help ;;
        *) die "comando desconocido: $command (usa --help)" ;;
    esac
}

main "$@"
