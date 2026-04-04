#!/bin/bash
# Seletor de Tema de Lockscreen — Rofi + Quickshell

THEMES_DIR="$HOME/dotfiles/qylock/themes"
ASSETS_DIR="$HOME/dotfiles/qylock/Assets"
LOCK_SH="$HOME/.local/share/quickshell-lockscreen/lock.sh"
CACHE_DIR="$HOME/.cache/qylock-thumbs"

mkdir -p "$CACHE_DIR"

# Mapeamento de nome de tema → GIF de preview
declare -A PREVIEW_MAP=(
    [cyberpunk]="cyberpunk.gif"
    [enfield]="enfield.gif"
    [Genshin]="genshin.gif"
    [minecraft]=""
    [nier-automata]="nier_automata.gif"
    [ninja_gaiden]="ninja_gaiden.gif"
    [paper]="paper.gif"
    [pixel-coffee]="pixel_coffee.gif"
    [pixel-dusk-city]="pixel_dusk_city.gif"
    [pixel-emerald]="pixel_emerald.gif"
    [pixel-hollowknight]="pixel_hollowknight.gif"
    [pixel-munchax]="pixel_munchax.gif"
    [pixel-night-city]="pixel_night_city.gif"
    [pixel-rainyroom]="pixel_rainyroom.gif"
    [pixel-skyscrapers]="pixel_skyscrapers.gif"
    [porsche]="porsche.gif"
    [star-rail]="star_rail.gif"
    [sword]="sword.gif"
    [terraria]="terraria.gif"
    [tui]="tui.gif"
    [windows_7]="win7.gif"
    [wuwa]="wuwa.gif"
)

# Gerar thumbnails PNG dos GIFs para o Rofi (GIF não funciona como ícone)
generate_thumb() {
    local theme="$1"
    local gif="${PREVIEW_MAP[$theme]}"
    local thumb="$CACHE_DIR/$theme.png"

    # Se já existe o thumbnail, retorna
    [ -f "$thumb" ] && echo "$thumb" && return

    if [ -n "$gif" ] && [ -f "$ASSETS_DIR/$gif" ]; then
        # Extrai primeiro frame do GIF
        ffmpeg -loglevel quiet -y -i "$ASSETS_DIR/$gif" -vframes 1 -update 1 "$thumb" 2>/dev/null
        [ -f "$thumb" ] && echo "$thumb" && return
    fi

    # Fallback: buscar imagem estática no tema
    local bg
    bg=$(find "$THEMES_DIR/$theme" -maxdepth 1 \( -name "background.png" -o -name "bg.png" -o -name "bg.jpg" \) ! -name "pfp.png" ! -name "logo.png" | head -1)
    if [ -n "$bg" ]; then
        echo "$bg"
        return
    fi

    # Fallback: extrair frame do vídeo
    local video
    video=$(find "$THEMES_DIR/$theme" -maxdepth 1 -name "*.mp4" | head -1)
    if [ -n "$video" ]; then
        ffmpeg -loglevel quiet -y -ss 2 -i "$video" -vframes 1 -update 1 "$thumb" 2>/dev/null
        [ -f "$thumb" ] && echo "$thumb" && return
    fi

    echo ""
}

# Obter tema atual
CURRENT_THEME=$(grep 'QS_THEME=.*:-' "$LOCK_SH" 2>/dev/null | sed 's/.*:-\(.*\)}.*/\1/')

# Listar temas (excluir cozytile e tui que são containers de variantes)
ROFI_INPUT=""
for theme_dir in "$THEMES_DIR"/*/; do
    theme=$(basename "$theme_dir")

    # Pular containers — listar variantes individualmente
    if [ "$theme" = "cozytile" ]; then
        for variant_dir in "$theme_dir"*/; do
            [ ! -d "$variant_dir" ] && continue
            variant=$(basename "$variant_dir")
            bg=$(find "$variant_dir" -maxdepth 1 \( -name "*.png" -o -name "*.jpg" \) ! -name "pfp.png" | head -1)
            label="cozytile/$variant"
            [ "$label" = "$CURRENT_THEME" ] && label="$label  (atual)"
            ROFI_INPUT+="${label}\0icon\x1f${bg:-}\n"
        done
        continue
    fi

    if [ "$theme" = "tui" ]; then
        for variant_dir in "$theme_dir"*/; do
            [ ! -d "$variant_dir" ] && continue
            variant=$(basename "$variant_dir")
            [ "$variant" = "tui-fonts" ] && continue
            label="tui/$variant"
            [ "$label" = "$CURRENT_THEME" ] && label="$label  (atual)"
            ROFI_INPUT+="${label}\0icon\x1f$ASSETS_DIR/tui.gif\n"
        done
        continue
    fi

    thumb=$(generate_thumb "$theme")
    label="$theme"
    [ "$theme" = "$CURRENT_THEME" ] && label="$label  (atual)"
    ROFI_INPUT+="${label}\0icon\x1f${thumb:-}\n"
done

# Mostrar seletor
SELECTED=$(echo -en "$ROFI_INPUT" | rofi -dmenu -p "" \
    -theme ~/.config/rofi/lockscreen-picker.rasi)

[ -z "$SELECTED" ] && exit 0

# Remover sufixo " (atual)" se existir
SELECTED=$(echo "$SELECTED" | sed 's/  (atual)$//')

# Atualizar lock.sh com o tema selecionado
sed -i "s|export QS_THEME=\"\${1:-.*}\"|export QS_THEME=\"\${1:-$SELECTED}\"|" "$LOCK_SH"

notify-send "Lockscreen" "Tema alterado para: $SELECTED" -t 3000

# Perguntar se quer testar agora
TEST=$(echo -e "Sim\nNão" | rofi -dmenu -p "Testar agora?" \
    -theme ~/.config/rofi/lockscreen-picker.rasi \
    -lines 2)

[ "$TEST" = "Sim" ] && exec "$LOCK_SH" "$SELECTED"
