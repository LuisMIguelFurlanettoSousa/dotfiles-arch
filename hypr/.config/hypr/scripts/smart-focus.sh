#!/bin/bash
# Navegação inteligente: se a janela ativa estiver em fullscreen/maximizada,
# troca o foco preservando o modo atual (maximizar ou fullscreen real).

direction="$1"

fullscreen=$(hyprctl activewindow -j | jq -r '.fullscreen')

case "$fullscreen" in
    1)
        # Maximizado (Super+F) — preserva modo ao navegar
        hyprctl --batch "dispatch fullscreen 1; dispatch movefocus $direction; dispatch fullscreen 1"
        ;;
    2|true)
        # Fullscreen real (Super+Shift+F) — preserva modo ao navegar
        hyprctl --batch "dispatch fullscreen 0; dispatch movefocus $direction; dispatch fullscreen 0"
        ;;
    *)
        hyprctl dispatch movefocus "$direction"
        ;;
esac
