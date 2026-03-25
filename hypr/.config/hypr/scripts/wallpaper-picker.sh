#!/bin/bash
# ============================================================
# Seletor de Wallpaper — Rofi + swww (inspirado no binnewbs)
# ============================================================
# Uso: Super + W (configurado no keybinds.conf)
# Wallpapers devem estar em ~/Pictures/wallpapers/walls/
# ============================================================

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"

# Verificar se o diretório existe
if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Diretório $WALLPAPER_DIR não encontrado." -u critical
    exit 1
fi

cd "$WALLPAPER_DIR" || exit 1

# Handle nomes com espaços
IFS=$'\n'

# Listar wallpapers com preview de ícone no Rofi (ordenados por mais recente)
SELECTED_WALL=$(for a in $(ls -t *.jpg *.png *.jpeg *.webp 2>/dev/null); do
    echo -en "$a\0icon\x1f$WALLPAPER_DIR/$a\n"
done | rofi -dmenu -p "" -theme-str 'window {width: 600px;} listview {lines: 8;}')

# Se o usuário cancelou, sair
[ -z "$SELECTED_WALL" ] && exit 0

SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

# Verificar se o arquivo existe
if [ ! -f "$SELECTED_PATH" ]; then
    notify-send "Wallpaper Picker" "Arquivo não encontrado: $SELECTED_PATH" -u critical
    exit 1
fi

# Aplicar wallpaper com transição
swww img "$SELECTED_PATH" --transition-type grow --transition-fps 60 --transition-duration 2

# Criar symlink para referência (usado pelo Rofi como preview)
mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

notify-send "Wallpaper" "Aplicado: $SELECTED_WALL" -t 3000
