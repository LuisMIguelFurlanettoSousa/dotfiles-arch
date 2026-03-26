#!/bin/bash
# Seletor de Wallpaper — Rofi + swayimg (preview dinâmico) + swww

WALLPAPER_DIR="$HOME/Pictures/wallpapers/walls"
SYMLINK_PATH="$HOME/.config/hypr/current_wallpaper"
PREVIEW_LINK="/tmp/wallpaper-picker-preview"
PREVIEW_SCRIPT="$HOME/.config/hypr/scripts/wallpaper-preview.sh"
SWAYIMG_CONFIG="$HOME/.config/hypr/scripts/swayimg-picker.lua"

if [ ! -d "$WALLPAPER_DIR" ]; then
    notify-send "Wallpaper Picker" "Diretório $WALLPAPER_DIR não encontrado." -u critical
    exit 1
fi

cd "$WALLPAPER_DIR" || exit 1

# Lista wallpapers ordenados por data de modificação
WALLPAPERS=($(ls -t *.jpg *.png *.jpeg *.webp *.gif 2>/dev/null))

if [ ${#WALLPAPERS[@]} -eq 0 ]; then
    notify-send "Wallpaper Picker" "Nenhum wallpaper encontrado." -u critical
    exit 1
fi

# Cria symlink inicial apontando para o primeiro wallpaper da lista
FIRST_WALL="$WALLPAPER_DIR/${WALLPAPERS[0]}"
ln -sf "$FIRST_WALL" "$PREVIEW_LINK"

# Inicia swayimg em background com classe customizada para window rule
swayimg --class swayimg-picker -c "$SWAYIMG_CONFIG" "$PREVIEW_LINK" &
SWAYIMG_PID=$!

# Garante que o swayimg será fechado ao sair (seleção ou ESC)
cleanup() {
    kill "$SWAYIMG_PID" 2>/dev/null
    rm -f "$PREVIEW_LINK"
}
trap cleanup EXIT

# Aguarda o swayimg abrir antes do Rofi
for _ in $(seq 1 20); do
    pgrep -f "swayimg.*swayimg-picker" > /dev/null && break
    sleep 0.05
done

IFS=$'\n'

# Abre Rofi com on-selection-changed para atualizar o preview
SELECTED_WALL=$(for a in "${WALLPAPERS[@]}"; do
    echo -en "$a\0icon\x1f$WALLPAPER_DIR/$a\n"
done | rofi -dmenu -p "" \
    -theme ~/.config/rofi/wallpaper-picker.rasi \
    -on-selection-changed "$PREVIEW_SCRIPT {entry}")

[ -z "$SELECTED_WALL" ] && exit 0

SELECTED_PATH="$WALLPAPER_DIR/$SELECTED_WALL"

if [ ! -f "$SELECTED_PATH" ]; then
    notify-send "Wallpaper Picker" "Arquivo não encontrado: $SELECTED_PATH" -u critical
    exit 1
fi

swww img "$SELECTED_PATH" --transition-type grow --transition-fps 60 --transition-duration 2

mkdir -p "$(dirname "$SYMLINK_PATH")"
ln -sf "$SELECTED_PATH" "$SYMLINK_PATH"

notify-send "Wallpaper" "Aplicado: $SELECTED_WALL" -t 3000
