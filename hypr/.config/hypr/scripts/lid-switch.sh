#!/usr/bin/env bash
# Gerencia o monitor interno (eDP-1) em função da tampa e dos monitores externos.
#   close           → tampa fechou; persiste estado; desliga eDP-1 se houver externo
#   open            → tampa abriu; persiste estado; religa eDP-1 no modo nativo
#   monitor-added   → monitor foi plugado; se a flag indicar tampa fechada, desliga eDP-1
#   monitor-removed → monitor foi removido; religa eDP-1 como fallback se nada restar
#
# Fonte da verdade do estado da tampa: flag em $LID_STATE_FILE, atualizada pelos
# bindl do Hyprland (libinput). Evita a inconfiabilidade do /proc/acpi/button/lid/*/state.

set -euo pipefail

action="${1:-}"
internal="eDP-1"
internal_mode="1920x1080@144,0x0,1"
LID_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-lid-state"

set_lid_state() { printf '%s\n' "$1" > "$LID_STATE_FILE"; }
lid_closed()    { [[ -f "$LID_STATE_FILE" ]] && grep -qw "closed" "$LID_STATE_FILE"; }

external_connected() {
    # Conta monitores ativos diferentes do interno
    hyprctl -j monitors | jq -e --arg i "$internal" \
        'map(select(.name != $i)) | length > 0' >/dev/null
}

disable_internal() { hyprctl keyword monitor "$internal,disable"; }
enable_internal()  { hyprctl keyword monitor "$internal,$internal_mode"; }

case "$action" in
    close)
        set_lid_state closed
        if external_connected; then
            disable_internal
        fi
        ;;
    open)
        set_lid_state open
        enable_internal
        ;;
    monitor-added)
        # Plugar monitor com a tampa fechada → migra tudo para o externo
        if lid_closed && external_connected; then
            disable_internal
        fi
        ;;
    monitor-removed)
        # Desconectou o externo → se não sobrou nenhum externo, religa o interno
        # para evitar ficar sem tela quando a tampa voltar a abrir
        if ! external_connected; then
            enable_internal
        fi
        ;;
    *)
        echo "uso: $0 {close|open|monitor-added|monitor-removed}" >&2
        exit 1
        ;;
esac
