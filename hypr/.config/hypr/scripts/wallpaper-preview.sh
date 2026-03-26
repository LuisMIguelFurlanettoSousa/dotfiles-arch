#!/bin/bash
# Atualiza o preview do imv quando a seleção muda no Rofi
# Usa imv-msg IPC para trocar a imagem sem reiniciar o processo

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
FILE="$1"

[ -z "$FILE" ] && exit 0

FULL_PATH="$WALLPAPER_DIR/$FILE"

[ ! -f "$FULL_PATH" ] && exit 1

# Lê o PID do imv salvo pelo wallpaper-picker
IMV_PID_FILE="/tmp/wallpaper-picker-imv-pid"
[ ! -f "$IMV_PID_FILE" ] && exit 1
IMV_PID=$(cat "$IMV_PID_FILE")

# Troca a imagem via IPC (sem reiniciar o processo)
imv-msg "$IMV_PID" close all
imv-msg "$IMV_PID" open "$FULL_PATH"

# Garante que o imv fique acima do Rofi
hyprctl dispatch alterzorder top,class:imv 2>/dev/null
