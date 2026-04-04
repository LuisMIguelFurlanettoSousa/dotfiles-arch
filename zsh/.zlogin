# Auto-iniciar Hyprland no login do TTY1
# Desativado — SDDM agora gerencia o login gráfico
# Para restaurar: descomente as 3 linhas abaixo e desabilite o SDDM (sudo systemctl disable sddm)
# if [ "$(tty)" = "/dev/tty1" ] && [ -z "$WAYLAND_DISPLAY" ]; then
#     exec Hyprland
# fi
