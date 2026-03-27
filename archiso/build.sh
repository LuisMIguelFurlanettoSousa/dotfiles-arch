#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build da ISO customizada — Arch Linux + Hyprland
# ============================================================
# Uso: sudo ./build.sh
# Saída: ~/iso-out/archlinux-hyprland-YYYY.MM.DD-x86_64.iso
#
# Funciona em:
#   - Arch Linux (usa archiso direto)
#   - Ubuntu/Debian/Fedora/qualquer distro (usa Docker)
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[BUILD]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# ============================================================
# Gravar ISO no pendrive
# ============================================================

gravar_pendrive() {
    local iso_file="$1"

    echo ""
    info "Dispositivos de bloco disponíveis:"
    echo ""
    lsblk -d -o NAME,SIZE,MODEL,TRAN | grep -E "usb|NAME" || true
    echo ""

    # Listar apenas dispositivos USB removíveis
    local usb_devices
    usb_devices=$(lsblk -d -n -o NAME,TRAN | awk '$2 == "usb" {print "/dev/"$1}')

    if [ -z "$usb_devices" ]; then
        warn "Nenhum dispositivo USB encontrado."
        echo -e "${YELLOW}Para gravar manualmente:${NC}"
        echo -e "  sudo dd bs=4M if=$iso_file of=/dev/sdX conv=fsync oflag=direct status=progress"
        return 1
    fi

    echo -e "${BOLD}Dispositivos USB detectados:${NC}"
    local i=1
    local devices=()
    while IFS= read -r dev; do
        local size model
        size=$(lsblk -d -n -o SIZE "$dev" 2>/dev/null)
        model=$(lsblk -d -n -o MODEL "$dev" 2>/dev/null)
        echo -e "  ${BOLD}$i)${NC} $dev — $size $model"
        devices+=("$dev")
        ((i++))
    done <<< "$usb_devices"

    echo ""
    read -rp "Escolha o dispositivo (número): " escolha

    if ! [[ "$escolha" =~ ^[0-9]+$ ]] || [ "$escolha" -lt 1 ] || [ "$escolha" -gt "${#devices[@]}" ]; then
        error "Opção inválida."
    fi

    local device="${devices[$((escolha-1))]}"
    local dev_size dev_model
    dev_size=$(lsblk -d -n -o SIZE "$device" 2>/dev/null)
    dev_model=$(lsblk -d -n -o MODEL "$device" 2>/dev/null)

    echo ""
    echo -e "${RED}${BOLD}ATENÇÃO: TODOS OS DADOS EM ${device} (${dev_size} ${dev_model}) SERÃO APAGADOS!${NC}"
    read -rp "Confirmar gravação? (digite SIM em maiúsculo): " confirmacao

    if [ "$confirmacao" != "SIM" ]; then
        warn "Gravação cancelada."
        return 1
    fi

    # Desmontar partições do dispositivo
    info "Desmontando partições de ${device}..."
    umount "${device}"* 2>/dev/null || true

    info "Gravando ISO no pendrive ${device}..."
    dd bs=4M if="$iso_file" of="$device" conv=fsync oflag=direct status=progress

    sync

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Pendrive gravado com sucesso!                ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Dispositivo: ${BLUE}${device}${NC}"
    echo -e "  ISO:         ${BLUE}${iso_file}${NC}"
    echo ""
}

# ============================================================
# Detectar ambiente e decidir: nativo (Arch) ou Docker
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Execute como root: sudo ./build.sh"
fi

# ============================================================
# Menu: escolher saída (ISO ou Pendrive)
# ============================================================

echo ""
echo -e "${BOLD}O que deseja fazer?${NC}"
echo ""
echo -e "  ${BOLD}1)${NC} Gerar apenas a ISO"
echo -e "  ${BOLD}2)${NC} Gerar a ISO e gravar no pendrive"
echo ""
read -rp "Escolha uma opção [1/2] (padrão: 1): " BUILD_MODE

case "${BUILD_MODE:-1}" in
    1|"") BUILD_MODE="iso" ;;
    2) BUILD_MODE="usb" ;;
    *) error "Opção inválida. Use 1 ou 2." ;;
esac

# ============================================================
# Verificar se já existe uma ISO recente (menos de 30 minutos)
# ============================================================

DEST_DIR="$REPO_DIR/iso-out"
EXISTING_ISO=$(ls -t "$DEST_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)

if [ -n "$EXISTING_ISO" ]; then
    ISO_AGE_MIN=$(( ($(date +%s) - $(stat -c %Y "$EXISTING_ISO")) / 60 ))

    if [ "$ISO_AGE_MIN" -lt 30 ]; then
        ISO_SIZE=$(du -h "$EXISTING_ISO" | cut -f1)
        echo ""
        warn "ISO encontrada com ${ISO_AGE_MIN} minuto(s) de idade:"
        echo -e "  ${BLUE}$EXISTING_ISO${NC} (${ISO_SIZE})"
        echo ""
        read -rp "Deseja usar essa ISO existente? [S/n] (padrão: S): " USAR_EXISTENTE

        if [[ "${USAR_EXISTENTE:-S}" =~ ^[Ss]$ ]]; then
            success "Usando ISO existente."

            if [ "$BUILD_MODE" = "usb" ]; then
                gravar_pendrive "$EXISTING_ISO"
            else
                echo ""
                info "A ISO está em: ${BOLD}$EXISTING_ISO${NC}"
                echo ""
                echo -e "${YELLOW}Para gravar no USB:${NC}"
                echo -e "  sudo dd bs=4M if=$EXISTING_ISO of=/dev/sdX conv=fsync oflag=direct status=progress"
                echo ""
            fi

            exit 0
        fi

        info "Gerando nova ISO..."
    fi
fi

# Se NÃO estiver no Arch Linux, usar Docker
if [ ! -f /etc/arch-release ]; then
    info "Sistema detectado: $(. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME" || echo "não-Arch")"
    info "Archiso requer Arch Linux. Usando Docker para buildar..."

    # Verificar se Docker está instalado
    if ! command -v docker &>/dev/null; then
        echo ""
        echo -e "${YELLOW}Docker não encontrado. Instale com:${NC}"
        echo -e "  ${BOLD}Ubuntu/Debian:${NC} sudo apt install docker.io"
        echo -e "  ${BOLD}Fedora:${NC}        sudo dnf install docker"
        echo ""
        error "Docker é necessário para buildar fora do Arch Linux."
    fi

    # Verificar se o daemon Docker está rodando
    if ! docker info &>/dev/null; then
        info "Iniciando Docker..."
        systemctl start docker 2>/dev/null || service docker start 2>/dev/null || {
            error "Não foi possível iniciar o Docker. Rode: sudo systemctl start docker"
        }
    fi

    # Criar diretório de saída
    OUT_DIR="${SUDO_HOME:-$HOME}/iso-out"
    mkdir -p "$OUT_DIR"

    # Verificar se a imagem do Arch Linux já foi baixada recentemente (menos de 24h)
    PULL_IMAGE=true
    if docker image inspect archlinux:latest &>/dev/null; then
        IMAGE_CREATED=$(docker image inspect --format '{{.Created}}' archlinux:latest)
        IMAGE_EPOCH=$(date -d "$IMAGE_CREATED" +%s 2>/dev/null || echo 0)
        IMAGE_AGE_HOURS=$(( ($(date +%s) - IMAGE_EPOCH) / 3600 ))

        if [ "$IMAGE_AGE_HOURS" -lt 24 ]; then
            success "Imagem archlinux:latest encontrada (${IMAGE_AGE_HOURS}h atrás). Pulando download."
            PULL_IMAGE=false
        else
            info "Imagem archlinux:latest com ${IMAGE_AGE_HOURS}h. Atualizando..."
        fi
    fi

    if [ "$PULL_IMAGE" = true ]; then
        info "Baixando imagem do Arch Linux..."
        docker pull archlinux:latest
    fi

    info "Iniciando build dentro do container Docker..."
    echo ""

    docker run --rm --privileged \
        -v "$REPO_DIR":/dotfiles:ro \
        -v "$OUT_DIR":/iso-out \
        archlinux:latest \
        /bin/bash -c '
            set -euo pipefail
            echo "=== Container Arch Linux iniciado ==="

            # Instalar dependências
            pacman -Sy --noconfirm archiso rsync &>/dev/null
            echo "[OK] archiso instalado no container."

            # Rodar o build internamente
            # (re-executar este script dentro do Arch, agora com archiso disponível)
            cp -r /dotfiles /tmp/dotfiles-build
            cd /tmp/dotfiles-build/archiso
            export HOME=/root
            mkdir -p /iso-out

            # Executar a parte nativa do build
            bash ./build-native.sh
        '

    # Ajustar permissões da ISO (Docker roda como root)
    REAL_USER="${SUDO_USER:-$(whoami)}"
    chown -R "$REAL_USER:$REAL_USER" "$OUT_DIR" 2>/dev/null || true

    ISO_FILE=$(ls -t "$OUT_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)
    if [ -z "$ISO_FILE" ]; then
        error "ISO não foi gerada. Verifique os erros acima."
    fi

    ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

    # Copiar ISO para a raiz do repositório
    DEST_DIR="$REPO_DIR/iso-out"
    mkdir -p "$DEST_DIR"
    cp "$ISO_FILE" "${ISO_FILE}.sha256" "$DEST_DIR/" 2>/dev/null || true
    chown -R "$REAL_USER:$REAL_USER" "$DEST_DIR" 2>/dev/null || true

    DEST_ISO="$DEST_DIR/$(basename "$ISO_FILE")"

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  ISO gerada com sucesso (via Docker)!        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ISO:      ${BLUE}$DEST_ISO${NC}"
    echo -e "  Tamanho:  ${BLUE}$ISO_SIZE${NC}"
    echo ""
    info "A ISO foi salva em: ${BOLD}$DEST_DIR/${NC}"
    echo ""

    if [ "$BUILD_MODE" = "usb" ]; then
        gravar_pendrive "$DEST_ISO"
    else
        echo -e "${YELLOW}Para gravar no USB:${NC}"
        echo -e "  sudo dd bs=4M if=$DEST_ISO of=/dev/sdX conv=fsync oflag=direct status=progress"
        echo ""
    fi

    exit 0
fi

# ============================================================
# Modo nativo (Arch Linux) — verificar archiso
# ============================================================

if ! pacman -Qi archiso &>/dev/null; then
    info "archiso não encontrado. Instalando..."
    pacman -S --needed --noconfirm archiso || error "Falha ao instalar archiso."
    success "archiso instalado."
fi

info "Sistema detectado: Arch Linux (modo nativo)"

# Modo nativo — chamar build-native.sh diretamente
"$SCRIPT_DIR/build-native.sh"

# Copiar ISO para a raiz do repositório
SRC_DIR="${HOME}/iso-out"
DEST_DIR="$REPO_DIR/iso-out"
mkdir -p "$DEST_DIR"

ISO_FILE=$(ls -t "$SRC_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)
if [ -n "$ISO_FILE" ]; then
    cp "$ISO_FILE" "${ISO_FILE}.sha256" "$DEST_DIR/" 2>/dev/null || true
    DEST_ISO="$DEST_DIR/$(basename "$ISO_FILE")"
    echo ""
    info "A ISO foi copiada para: ${BOLD}$DEST_ISO${NC}"
    echo ""

    if [ "$BUILD_MODE" = "usb" ]; then
        gravar_pendrive "$DEST_ISO"
    fi
fi
