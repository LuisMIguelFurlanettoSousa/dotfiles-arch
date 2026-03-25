#!/bin/bash
# Script de controle de volume

case "$1" in
    --inc)
        wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+
        ;;
    --dec)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        ;;
    --toggle)
        wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
        ;;
    --toggle-mic)
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        ;;
    --mic-inc)
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%+
        ;;
    --mic-dec)
        wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-
        ;;
esac
