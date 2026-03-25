#!/bin/bash
# Preview de wallpaper para o rofi
# Recebe o nome do arquivo e gera preview com chafa (terminal image viewer)

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
FILE="$1"

if [ -f "$WALLPAPER_DIR/$FILE" ]; then
    chafa --size=40x20 --animate=off "$WALLPAPER_DIR/$FILE" 2>/dev/null
elif [ -f "$FILE" ]; then
    chafa --size=40x20 --animate=off "$FILE" 2>/dev/null
fi
