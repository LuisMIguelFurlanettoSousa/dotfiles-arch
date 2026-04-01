#!/bin/bash
# Reabre a última janela fechada, lendo da pilha de histórico.

HISTORY_FILE="/tmp/hypr-closed-windows"

if [[ ! -f "$HISTORY_FILE" ]] || [[ ! -s "$HISTORY_FILE" ]]; then
    notify-send "Hyprland" "Nenhuma janela fechada para reabrir" -t 2000
    exit 0
fi

# Lê a última classe registrada
class=$(tail -n 1 "$HISTORY_FILE")

# Remove a última linha da pilha
sed -i '$ d' "$HISTORY_FILE"

# Reabre o aplicativo pela classe
hyprctl dispatch exec "$class"
