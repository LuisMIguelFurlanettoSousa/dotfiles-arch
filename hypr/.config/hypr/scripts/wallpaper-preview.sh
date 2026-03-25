#!/bin/bash
# Atualiza o preview do swayimg quando a seleção muda no Rofi
# Recebe o nome do wallpaper selecionado e envia SIGUSR1 ao swayimg

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
PREVIEW_LINK="/tmp/wallpaper-picker-preview"
FILE="$1"

[ -z "$FILE" ] && exit 0

FULL_PATH="$WALLPAPER_DIR/$FILE"

[ ! -f "$FULL_PATH" ] && exit 1

# Atualiza o symlink temporário para o wallpaper selecionado
ln -sf "$FULL_PATH" "$PREVIEW_LINK"

# Envia SIGUSR1 ao swayimg para recarregar a imagem
pkill -USR1 -f "swayimg.*swayimg-picker"
