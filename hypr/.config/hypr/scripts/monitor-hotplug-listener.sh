#!/bin/bash
# Listener que reage ao hotplug de monitores via socket IPC do Hyprland.
# Ao detectar um monitor adicionado, delega ao lid-switch.sh, que decide
# se deve desligar o eDP-1 (baseado no estado atual da tampa).
# Usa Python embarcado para conectar ao socket Unix, sem dependência de socat/nc.

SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"
LID_SWITCH_SCRIPT="$HOME/.config/hypr/scripts/lid-switch.sh"

# Mata instâncias anteriores para evitar duplicatas competindo pelo socket
pkill -f "monitor-hotplug-listener" --older 1 2>/dev/null

exec python3 -u - "$SOCKET_PATH" "$LID_SWITCH_SCRIPT" << 'PYEOF'
import socket, subprocess, sys

SOCKET_PATH = sys.argv[1]
LID_SCRIPT  = sys.argv[2]

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(SOCKET_PATH)

buf = b''
while True:
    data = sock.recv(4096)
    if not data:
        break
    buf += data
    while b'\n' in buf:
        line, buf = buf.split(b'\n', 1)
        line = line.decode('utf-8', errors='replace').strip()
        # Aceita tanto "monitoradded>>" quanto "monitoraddedv2>>" (ambos são emitidos)
        if line.startswith('monitoradded>>'):
            subprocess.run([LID_SCRIPT, 'monitor-added'])
        elif line.startswith('monitorremoved>>'):
            subprocess.run([LID_SCRIPT, 'monitor-removed'])
PYEOF
