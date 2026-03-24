# Auto-executar o menu-live no login do root (apenas no tty1)
if [ "$(tty)" = "/dev/tty1" ]; then
    chmod +x /usr/local/bin/menu-live /usr/local/bin/instalar-sistema /usr/local/bin/full-install.sh 2>/dev/null
    /usr/local/bin/menu-live
fi
