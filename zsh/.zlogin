# Auto-iniciar Hyprland no login do TTY1
if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
    exec Hyprland
fi
