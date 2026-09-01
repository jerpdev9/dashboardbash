#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS=0
FAILED=0

fail() { printf '    %s\n' "$*" >&2; return 1; }
assert_status() {
    [[ $1 -eq $2 ]] || {
        printf '    estado esperado: %s; obtenido: %s\n%s\n' "$2" "$1" "${OUTPUT:-}" >&2
        return 1
    }
}
assert_contains() { [[ $1 == *"$2"* ]] || fail "no se encontró: $2"; }
assert_not_exists() { [[ ! -e $1 ]] || fail "no debía existir: $1"; }
assert_file_contains() { grep -Fq -- "$2" "$1" || fail "$1 no contiene: $2"; }

run_test() {
    local name=$1 fn=$2
    TESTS=$((TESTS + 1))
    set +e
    ( set -Eeuo pipefail; "$fn" )
    local status=$?
    set -e
    if [[ $status -eq 0 ]]; then
        printf '  PASS  %s\n' "$name"
    else
        FAILED=$((FAILED + 1))
        printf '  FAIL  %s\n' "$name"
    fi
}

new_fixture() {
    FIXTURE="$(mktemp -d)"
    trap '/bin/rm -rf -- "$FIXTURE"' EXIT
    export HOME="$FIXTURE/home"
    export MOCK_BIN="$FIXTURE/bin"
    export MOCK_LOG="$FIXTURE/commands.log"
    export MOCK_LOCALE_FILE="$FIXTURE/locale-generated"
    export MOCK_DPKG_FILE="$FIXTURE/dpkg-installed"
    export LOCALE_GEN_FILE="$FIXTURE/locale.gen"
    mkdir -p "$HOME" "$MOCK_BIN"
    : > "$MOCK_LOG"
    : > "$MOCK_DPKG_FILE"
    printf '# es_CL.UTF-8 UTF-8\n' > "$LOCALE_GEN_FILE"

    /bin/cp "$ROOT/tests/support/mock-command" "$MOCK_BIN/mock-command"
    /bin/chmod +x "$MOCK_BIN/mock-command"
    local cmd
    for cmd in apt-get dpkg locale locale-gen sudo cargo; do
        /bin/ln -s mock-command "$MOCK_BIN/$cmd"
    done
    for cmd in bash basename cat chmod cmp cp date dirname env find grep head ln mkdir mktemp mv rm rmdir sed seq tee touch wc; do
        /bin/ln -s "$(command -v "$cmd")" "$MOCK_BIN/$cmd"
    done
    export PATH="$MOCK_BIN"
}

add_dependency_commands() {
    local cmd
    for cmd in kitty cava btop bmon ss watch nvtop gdu ranger journalctl fc-list tclock btm; do
        ln -sf mock-command "$MOCK_BIN/$cmd"
    done
    printf '%s\n' fonts-jetbrains-mono ca-certificates curl build-essential pkg-config > "$MOCK_DPKG_FILE"
}

invoke() {
    set +e
    OUTPUT="$(bash "$ROOT/install-dashbash.sh" "$@" 2>&1)"
    STATUS=$?
    set -e
}

invoke_from_stdin() {
    set +e
    OUTPUT="$(cd "$FIXTURE" && bash -s -- "$@" < "$ROOT/install-dashbash.sh" 2>&1)"
    STATUS=$?
    set -e
}

invoke_uninstall() {
    set +e
    OUTPUT="$(bash "$ROOT/uninstall-dashbash.sh" "$@" 2>&1)"
    STATUS=$?
    set -e
}

invoke_manager() {
    set +e
    OUTPUT="$(bash "$ROOT/dashbash-manager.sh" "$@" 2>&1)"
    STATUS=$?
    set -e
}

test_help() {
    new_fixture
    invoke --help
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'Uso:'
    [[ ! -s $MOCK_LOG ]] || fail 'la ayuda ejecutó comandos externos'
}

test_unknown_option() {
    new_fixture
    invoke --no-existe
    assert_status "$STATUS" 1
    assert_contains "$OUTPUT" 'opción desconocida: --no-existe'
}

test_check_reports_missing_without_writes() {
    new_fixture
    invoke --check
    [[ $STATUS -ne 0 ]] || fail '--check debe fallar cuando hay elementos pendientes'
    assert_contains "$OUTPUT" 'Faltan '
    assert_contains "$OUTPUT" 'falta (kitty)'
    assert_not_exists "$HOME/.config"
    assert_not_exists "$HOME/bin"
    ! grep -Eq 'apt-get|locale-gen|cargo install' "$MOCK_LOG" || fail '--check intentó instalar'
}

test_check_succeeds_when_complete() {
    new_fixture
    add_dependency_commands
    touch "$MOCK_LOCALE_FILE"
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    : > "$HOME/.config/kitty/dashboard.conf"
    : > "$HOME/bin/dashbash"
    invoke --check
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'Todo listo.'
}

test_full_install_from_empty_fixture() {
    new_fixture
    invoke
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'Todo instalado.'
    cmp -s "$ROOT/config/dashboard.conf" "$HOME/.config/kitty/dashboard.conf"
    cmp -s "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    [[ -x $HOME/bin/dashbash ]] || fail 'el launcher no es ejecutable'
    assert_file_contains "$HOME/.config/kitty/kitty.conf" 'font_family JetBrains Mono'
    assert_file_contains "$HOME/.bashrc" 'export PATH="$HOME/bin:$PATH"'
    assert_file_contains "$MOCK_LOG" 'apt-get update -qq'
    assert_file_contains "$MOCK_LOG" 'cargo install --locked clock-tui'
    assert_file_contains "$MOCK_LOG" 'cargo install --locked bottom'
    [[ -e $MOCK_LOCALE_FILE ]] || fail 'no se generó el locale'
}

test_standalone_install_from_stdin() {
    new_fixture
    invoke_from_stdin
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'Todo instalado.'
    cmp -s "$ROOT/config/dashboard.conf" "$HOME/.config/kitty/dashboard.conf"
    cmp -s "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    [[ -x $HOME/bin/dashbash ]] || fail 'el launcher embebido no es ejecutable'
}

test_stdin_forwards_check_argument() {
    new_fixture
    invoke_from_stdin --check
    assert_status "$STATUS" 1
    assert_contains "$OUTPUT" 'Faltan '
    assert_not_exists "$HOME/.config"
    assert_not_exists "$HOME/bin"
}

test_no_config_leaves_home_untouched() {
    new_fixture
    invoke --no-config
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" '--no-config: no se tocaron'
    assert_not_exists "$HOME/.config"
    assert_not_exists "$HOME/bin"
}

test_check_reports_missing_extra_packages() {
    new_fixture
    add_dependency_commands
    : > "$MOCK_DPKG_FILE"
    touch "$MOCK_LOCALE_FILE"
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    : > "$HOME/.config/kitty/dashboard.conf"
    : > "$HOME/bin/dashbash"
    invoke --check
    assert_status "$STATUS" 1
    assert_contains "$OUTPUT" 'fonts-jetbrains-mono'
    assert_contains "$OUTPUT" 'falta (apt)'
}

test_reinstall_is_idempotent_and_preserves_kitty_conf() {
    new_fixture
    invoke
    assert_status "$STATUS" 0
    printf 'custom-setting yes\n' > "$HOME/.config/kitty/kitty.conf"
    : > "$MOCK_LOG"
    invoke
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'dashboard.conf ya está al día'
    assert_contains "$OUTPUT" '~/bin/dashbash ya está al día'
    assert_file_contains "$HOME/.config/kitty/kitty.conf" 'custom-setting yes'
    ! find "$HOME" -name '*.bak.*' -print -quit | grep -q . || fail 'la reinstalación idéntica creó respaldos'
}

test_changed_files_are_backed_up() {
    new_fixture
    add_dependency_commands
    touch "$MOCK_LOCALE_FILE"
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    printf 'old dashboard\n' > "$HOME/.config/kitty/dashboard.conf"
    printf 'old launcher\n' > "$HOME/bin/dashbash"
    invoke
    assert_status "$STATUS" 0
    [[ $(find "$HOME/.config/kitty" -name 'dashboard.conf.bak.*' | wc -l) -eq 1 ]]
    [[ $(find "$HOME/bin" -name 'dashbash.bak.*' | wc -l) -eq 1 ]]
    grep -Rq 'old dashboard' "$HOME/.config/kitty"/dashboard.conf.bak.*
    grep -Rq 'old launcher' "$HOME/bin"/dashbash.bak.*
}

test_launcher_forwards_expected_kitty_arguments() {
    new_fixture
    ln -sf mock-command "$MOCK_BIN/kitty"
    bash "$ROOT/bin/dashbash"
    assert_file_contains "$MOCK_LOG" "kitty --start-as=maximized --session $HOME/.config/kitty/dashboard.conf"
}

test_dashboard_declares_all_tabs_and_tools() {
    local config="$ROOT/config/dashboard.conf"
    [[ $(grep -c '^new_tab ' "$config") -eq 8 ]] || fail 'se esperaban 8 pestañas'
    local item
    for item in Home System Network Hardware Disks Monitor Files Logs tclock cava btop bmon ss nvtop gdu btm ranger journalctl; do
        grep -Fq "$item" "$config" || fail "falta $item en dashboard.conf"
    done
}

test_uninstall_removes_only_managed_files() {
    new_fixture
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    cp "$ROOT/config/dashboard.conf" "$HOME/.config/kitty/dashboard.conf"
    cp "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    printf 'font_family JetBrains Mono\nfont_size 14.0\n' > "$HOME/.config/kitty/kitty.conf"
    printf 'keep me\n' > "$HOME/.config/kitty/custom.conf"
    printf 'before\n\n# añadido por install-dashbash.sh\nexport PATH="$HOME/bin:$PATH"\nafter\n' > "$HOME/.bashrc"
    printf 'backup\n' > "$HOME/bin/dashbash.bak.20260901"

    invoke_uninstall
    assert_status "$STATUS" 0
    assert_not_exists "$HOME/bin/dashbash"
    assert_not_exists "$HOME/.config/kitty/dashboard.conf"
    assert_not_exists "$HOME/.config/kitty/kitty.conf"
    assert_file_contains "$HOME/.config/kitty/custom.conf" 'keep me'
    assert_file_contains "$HOME/bin/dashbash.bak.20260901" 'backup'
    ! grep -Fq 'añadido por install-dashbash.sh' "$HOME/.bashrc"
    assert_file_contains "$HOME/.bashrc" 'after'
    ! grep -Fq 'apt-get purge' "$MOCK_LOG" || fail 'desinstaló paquetes sin --purge-deps'
}

test_uninstall_preserves_custom_kitty_conf() {
    new_fixture
    mkdir -p "$HOME/.config/kitty"
    printf 'font_size 22\n' > "$HOME/.config/kitty/kitty.conf"
    invoke_uninstall
    assert_status "$STATUS" 0
    assert_file_contains "$HOME/.config/kitty/kitty.conf" 'font_size 22'
    assert_contains "$OUTPUT" 'contiene personalizaciones'
}

test_uninstall_dry_run_changes_nothing() {
    new_fixture
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    cp "$ROOT/config/dashboard.conf" "$HOME/.config/kitty/dashboard.conf"
    cp "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    invoke_uninstall --dry-run
    assert_status "$STATUS" 0
    [[ -f $HOME/bin/dashbash ]]
    [[ -f $HOME/.config/kitty/dashboard.conf ]]
    assert_contains "$OUTPUT" 'modo simulación'
}

test_uninstall_purges_dependencies_on_request() {
    new_fixture
    add_dependency_commands
    invoke_uninstall --purge-deps
    assert_status "$STATUS" 0
    assert_file_contains "$MOCK_LOG" 'cargo uninstall clock-tui bottom'
    assert_file_contains "$MOCK_LOG" 'apt-get purge -y kitty cava btop'
    ! grep -Fq 'systemd' "$MOCK_LOG" || fail 'intentó retirar una dependencia fundamental'
    ! grep -Fq 'apt-get autoremove' "$MOCK_LOG" || fail 'ejecutó autoremove'
}

test_manager_help() {
    new_fixture
    invoke_manager --help
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'install'
    assert_contains "$OUTPUT" 'uninstall'
    assert_contains "$OUTPUT" 'update'
    [[ ! -s $MOCK_LOG ]] || fail 'la ayuda del administrador ejecutó comandos externos'
}

test_manager_forwards_install_options() {
    new_fixture
    invoke_manager install --check
    assert_status "$STATUS" 1
    assert_contains "$OUTPUT" 'Faltan '
    assert_not_exists "$HOME/.config"
}

test_manager_forwards_uninstall_options() {
    new_fixture
    mkdir -p "$HOME/bin"
    cp "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    invoke_manager uninstall --dry-run
    assert_status "$STATUS" 0
    [[ -f $HOME/bin/dashbash ]] || fail 'el administrador no respetó --dry-run'
    assert_contains "$OUTPUT" 'modo simulación'
}

test_manager_update_uninstalls_then_installs() {
    new_fixture
    mkdir -p "$HOME/.config/kitty" "$HOME/bin"
    printf 'versión anterior\n' > "$HOME/.config/kitty/dashboard.conf"
    printf 'launcher anterior\n' > "$HOME/bin/dashbash"
    invoke_manager update
    assert_status "$STATUS" 0
    assert_contains "$OUTPUT" 'Actualizando dashbash'
    assert_contains "$OUTPUT" 'Reinstalando la versión actual'
    assert_contains "$OUTPUT" 'actualizado correctamente'
    cmp -s "$ROOT/config/dashboard.conf" "$HOME/.config/kitty/dashboard.conf"
    cmp -s "$ROOT/bin/dashbash" "$HOME/bin/dashbash"
    ! grep -Fq 'apt-get purge' "$MOCK_LOG" || fail 'update intentó purgar dependencias'
}

run_test 'muestra ayuda sin efectos laterales' test_help
run_test 'rechaza opciones desconocidas' test_unknown_option
run_test 'check detecta faltantes y no modifica' test_check_reports_missing_without_writes
run_test 'check confirma una instalación completa' test_check_succeeds_when_complete
run_test 'instala desde un entorno vacío simulado' test_full_install_from_empty_fixture
run_test 'se instala como script independiente vía stdin' test_standalone_install_from_stdin
run_test 'curl-style reenvía argumentos al instalador' test_stdin_forwards_check_argument
run_test 'check detecta paquetes apt extra faltantes' test_check_reports_missing_extra_packages
run_test 'no-config no escribe configuración' test_no_config_leaves_home_untouched
run_test 'reinstalación idéntica es idempotente' test_reinstall_is_idempotent_and_preserves_kitty_conf
run_test 'respalda archivos modificados' test_changed_files_are_backed_up
run_test 'launcher invoca kitty correctamente' test_launcher_forwards_expected_kitty_arguments
run_test 'dashboard conserva sus 8 pestañas' test_dashboard_declares_all_tabs_and_tools
run_test 'desinstalador elimina solo archivos administrados' test_uninstall_removes_only_managed_files
run_test 'desinstalador conserva kitty.conf personalizado' test_uninstall_preserves_custom_kitty_conf
run_test 'desinstalador permite simular sin cambios' test_uninstall_dry_run_changes_nothing
run_test 'desinstalador retira dependencias bajo petición' test_uninstall_purges_dependencies_on_request
run_test 'administrador maestro muestra ayuda' test_manager_help
run_test 'administrador reenvía opciones de instalación' test_manager_forwards_install_options
run_test 'administrador reenvía opciones de desinstalación' test_manager_forwards_uninstall_options
run_test 'administrador actualiza mediante desinstalación e instalación' test_manager_update_uninstalls_then_installs

printf '\n%d pruebas; %d fallos\n' "$TESTS" "$FAILED"
[[ $FAILED -eq 0 ]]
