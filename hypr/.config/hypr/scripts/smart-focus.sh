#!/bin/bash
# Navegação inteligente: se a janela ativa estiver em fullscreen,
# sai do fullscreen, troca o foco e volta pro fullscreen.

direction="$1"

fullscreen=$(hyprctl activewindow -j | jq -r '.fullscreen')

if [ "$fullscreen" = "true" ] || [ "$fullscreen" = "1" ] || [ "$fullscreen" = "2" ]; then
    hyprctl dispatch fullscreen 0
    hyprctl dispatch movefocus "$direction"
    hyprctl dispatch fullscreen 0
else
    hyprctl dispatch movefocus "$direction"
fi
