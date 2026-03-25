#!/bin/bash
# Seletor de Wallpaper — Rofi + awww + preview dinâmico

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
PREVIEW_SCRIPT="$HOME/.config/hypr/scripts/wallpaper-preview.sh"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Diretório $WALLPAPER_DIR não encontrado." -u critical
    exit 1
fi

cd "$WALLPAPER_DIR" || exit 1

IFS=$'\n'

SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.jpeg *.webp *.gif 2>/dev/null); do
    echo -en "$a\0icon\x1f$WALLPAPER_DIR/$a\n"
done | rofi -dmenu -p "" \
    -theme ~/.config/rofi/wallpaper-picker.rasi \
    -preview-cmd "$PREVIEW_SCRIPT {}")

[ -z "$SELECTED_WALL" ] && exit 0

SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

if [ ! -f "$SELECTED_PATH" ]; then
    notify-send "Wallpaper Picker" "Arquivo não encontrado: $SELECTED_PATH" -u critical
    exit 1
fi

awww img "$SELECTED_PATH" --transition-type grow --transition-fps 60 --transition-duration 2

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

notify-send "Wallpaper" "Aplicado: $SELECTED_WALL" -t 3000
