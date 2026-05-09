#!/bin/bash
# ============================================================
# Tuning de sistema — Arch Linux
# ============================================================
# Aplica otimizações de performance:
#   1. CPU governor: performance (permanente, mesmo na bateria)
#   2. systemd-oomd:  proteção contra travamento por falta de RAM
#   3. sysctl: swappiness=10, vfs_cache_pressure=50
#   4. ZRAM: swap comprimido em RAM (zstd, metade da RAM)
#
# Idempotente: pode rodar várias vezes sem efeito colateral.
# Standalone: também pode ser invocado pelo install.sh master.
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Modo --no-start: aplica configs e habilita serviços (enable),
# mas NÃO inicia agora (--now). Útil em chroot durante archiso.
NO_START=false
if [[ "${1:-}" == "--no-start" ]]; then
    NO_START=true
fi

# Cores e helpers (compatível com install.sh master)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# Sem privilégio de root, aborta cedo
if [[ $EUID -ne 0 ]]; then
    if ! sudo -v; then
        error "Este script precisa de sudo. Aborte e rode com privilégio."
    fi
fi

# ============================================================
# 1. Instalar pacotes necessários
# ============================================================
info "Instalando pacotes (cpupower, zram-generator)..."
sudo pacman -S --needed --noconfirm cpupower zram-generator >/dev/null
success "Pacotes presentes."

# ============================================================
# 2. Copiar arquivos de config para /etc
# ============================================================
info "Aplicando arquivos de configuração em /etc..."

# Faz backup do arquivo destino se ele existir e for diferente do nosso
copy_if_different() {
    local src="$1"
    local dst="$2"
    sudo install -d "$(dirname "$dst")"
    if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
        return 0  # já idêntico
    fi
    if [[ -f "$dst" ]]; then
        sudo cp -a "$dst" "${dst}.bak.$(date +%Y%m%d-%H%M%S)"
    fi
    sudo install -m 644 "$src" "$dst"
}

copy_if_different "$SCRIPT_DIR/etc/default/cpupower"             /etc/default/cpupower
copy_if_different "$SCRIPT_DIR/etc/sysctl.d/99-perf.conf"        /etc/sysctl.d/99-perf.conf
copy_if_different "$SCRIPT_DIR/etc/systemd/zram-generator.conf"  /etc/systemd/zram-generator.conf
success "Arquivos de configuração aplicados."

# ============================================================
# 3. Recarregar sysctl (efeito imediato sem reboot)
# ============================================================
info "Recarregando parâmetros sysctl..."
sudo sysctl --system >/dev/null
success "sysctl recarregado (swappiness=$(cat /proc/sys/vm/swappiness))."

# ============================================================
# 4. Habilitar / iniciar serviços
# ============================================================
if $NO_START; then
    SYSTEMCTL_FLAG="enable"
    info "Modo --no-start: habilitando serviços sem iniciar agora."
else
    SYSTEMCTL_FLAG="enable --now"
    info "Habilitando e iniciando serviços..."
fi

for svc in cpupower.service systemd-oomd.service; do
    if sudo systemctl $SYSTEMCTL_FLAG "$svc" 2>/dev/null; then
        success "  $svc"
    else
        warn "  Falha ao processar $svc"
    fi
done

# ZRAM: o zram-generator cria a unit `dev-zram0.swap` dinamicamente.
# Em modo --no-start, basta o reboot pra subir.
sudo systemctl daemon-reload
if ! $NO_START; then
    if sudo systemctl start dev-zram0.swap 2>/dev/null; then
        success "  ZRAM ativo (dev-zram0.swap)"
    else
        warn "  Falha ao iniciar ZRAM (verá no próximo boot)"
    fi
fi

# ============================================================
# 5. Resumo
# ============================================================
echo ""
info "Resumo final:"
echo "  • CPU governor : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
echo "  • swappiness   : $(cat /proc/sys/vm/swappiness)"
echo "  • systemd-oomd : $(systemctl is-active systemd-oomd 2>/dev/null || echo inactive)"
if command -v zramctl &>/dev/null; then
    zram_line=$(zramctl --noheadings 2>/dev/null | head -1)
    echo "  • ZRAM         : ${zram_line:-(inativo, sobe no próximo boot)}"
fi
success "Tuning de sistema aplicado."
