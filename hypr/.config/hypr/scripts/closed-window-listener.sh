#!/bin/bash
# Listener que monitora janelas fechadas via socket IPC do Hyprland
# e salva o executável da janela em uma pilha para reabertura posterior.
# Usa Python para conectar ao socket Unix (sem dependência de socat/nc).
#
# Lógica: openwindow → captura address, busca PID via hyprctl, resolve
# o executável real via /proc/PID/exe. closewindow → salva o executável.

HISTORY_FILE="/tmp/hypr-closed-windows"
SOCKET_PATH="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Mata instâncias anteriores para evitar duplicatas competindo pelo socket
pkill -f "closed-window-listener" --older 1 2>/dev/null

# Limpa histórico anterior ao iniciar
> "$HISTORY_FILE"

exec python3 -u - "$SOCKET_PATH" "$HISTORY_FILE" << 'PYEOF'
import socket, json, subprocess, os, sys

SOCKET_PATH = sys.argv[1]
HISTORY_FILE = sys.argv[2]

sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
sock.connect(SOCKET_PATH)

# Mapa de janelas: address → executável
windows = {}

def get_exe_from_pid(pid):
    """Resolve o executável real a partir do PID via /proc."""
    try:
        return os.readlink(f'/proc/{pid}/exe')
    except OSError:
        return ''

def load_clients():
    """Carrega janelas já abertas e seus executáveis."""
    try:
        result = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True)
        for client in json.loads(result.stdout):
            addr = str(client['address']).replace('0x', '')
            pid = client.get('pid', 0)
            exe = get_exe_from_pid(pid)
            if exe:
                windows[addr] = exe
    except Exception:
        pass

def resolve_new_window(addr):
    """Busca o executável de uma janela recém-aberta via hyprctl clients."""
    try:
        result = subprocess.run(['hyprctl', 'clients', '-j'], capture_output=True, text=True)
        for client in json.loads(result.stdout):
            client_addr = str(client['address']).replace('0x', '')
            if client_addr == addr:
                return get_exe_from_pid(client.get('pid', 0))
    except Exception:
        pass
    return ''

load_clients()

buf = b''
while True:
    data = sock.recv(4096)
    if not data:
        break
    buf += data
    while b'\n' in buf:
        line, buf = buf.split(b'\n', 1)
        line = line.decode('utf-8', errors='replace').strip()

        if line.startswith('openwindow>>'):
            addr = line[len('openwindow>>'):].split(',', 1)[0]
            exe = resolve_new_window(addr)
            if exe:
                windows[addr] = exe

        elif line.startswith('closewindow>>'):
            addr = line[len('closewindow>>'):]
            exe = windows.pop(addr, '')
            if exe:
                with open(HISTORY_FILE, 'a') as f:
                    f.write(exe + '\n')
                with open(HISTORY_FILE, 'r') as f:
                    lines = f.readlines()
                if len(lines) > 20:
                    with open(HISTORY_FILE, 'w') as f:
                        f.writelines(lines[-20:])
PYEOF
