#!/usr/bin/env bash
set -e

# ============================================================
# Dotfiles Hyprland — Instalador Automatizado para Arch Linux
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# ============================================================
# 1. Validar pré-requisitos
# ============================================================

info "Validando pré-requisitos..."

# Não pode rodar como root
if [ "$EUID" -eq 0 ]; then
    error "Não execute como root. Use um usuário normal com sudo."
fi

# Verificar se é Arch Linux
if [ ! -f /etc/arch-release ]; then
    error "Este script é exclusivo para Arch Linux."
fi

# Verificar conexão com internet
if ! ping -c 1 archlinux.org &>/dev/null; then
    error "Sem conexão com a internet."
fi

success "Pré-requisitos validados."

# ============================================================
# 2. Atualizar sistema
# ============================================================

info "Atualizando sistema..."
sudo pacman -Syu --noconfirm
success "Sistema atualizado."

# ============================================================
# 3. Instalar yay (AUR helper)
# ============================================================

if command -v yay &>/dev/null; then
    success "yay já está instalado."
else
    info "Instalando yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay"
    cd "$TEMP_DIR/yay"
    makepkg -si --noconfirm
    cd "$DOTFILES_DIR"
    rm -rf "$TEMP_DIR"
    success "yay instalado."
fi

# ============================================================
# 4. Detectar GPU e instalar drivers
# ============================================================

info "Detectando GPU..."
GPU_INFO=$(lspci -nn | grep -E '\[03[0-9]{2}\]' || true)
GPU_TYPE="intel" # padrão

if echo "$GPU_INFO" | grep -qi nvidia; then
    GPU_TYPE="nvidia"
    info "GPU NVIDIA detectada."
    sudo pacman -S --needed --noconfirm nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi 'amd\|radeon'; then
    GPU_TYPE="amd"
    info "GPU AMD detectada."
    sudo pacman -S --needed --noconfirm mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon
else
    info "GPU Intel detectada (ou não identificada)."
    sudo pacman -S --needed --noconfirm mesa vulkan-intel lib32-mesa lib32-vulkan-intel
fi

success "Drivers de GPU instalados ($GPU_TYPE)."

# ============================================================
# 5. Instalar pacotes
# ============================================================

info "Instalando pacotes via pacman..."

PACMAN_PKGS=(
    # Hyprland core
    hyprland
    hyprlock
    xdg-desktop-portal-hyprland
    # Barra, menu, logout
    waybar
    wofi
    wlogout
    # Utilitários Wayland
    grim
    slurp
    wl-clipboard
    swww
    # Aparência
    qt6ct
    noto-fonts-emoji
    # Áudio
    pipewire
    wireplumber
    pipewire-pulse
    pavucontrol
    # Bluetooth
    bluez
    bluez-utils
    blueman
    # Rede
    networkmanager
    nm-connection-editor
    # Gerenciador de arquivos
    nemo
    # Shell e ferramentas
    zsh
    eza
    fzf
    zoxide
    tree
    jq
    # Sistema
    stow
    git
    base-devel
    polkit-gnome
    # Editor
    neovim
    # Night mode
    hyprsunset
    # GTK theme e ícones
    materia-gtk-theme
    papirus-icon-theme
    # Waybar dependência (checkupdates)
    pacman-contrib
)

sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
success "Pacotes pacman instalados."

info "Instalando pacotes via yay (AUR)..."

AUR_PKGS=(
    ghostty
    visual-studio-code-bin
    bibata-cursor-theme
    ttf-jetbrains-mono-nerd
)

yay -S --needed --noconfirm "${AUR_PKGS[@]}"
success "Pacotes AUR instalados."

# ============================================================
# 6. Aplicar env.conf conforme GPU
# ============================================================

info "Configurando env.conf para GPU $GPU_TYPE..."

if [ "$GPU_TYPE" = "nvidia" ]; then
    cp "$DOTFILES_DIR/hypr/.config/hypr/conf/env.conf.nvidia" \
       "$DOTFILES_DIR/hypr/.config/hypr/conf/env.conf"
fi
# Para AMD/Intel, o env.conf padrão (sem variáveis NVIDIA) já está correto.

success "env.conf configurado."

# ============================================================
# 7. Remover configs conflitantes e aplicar via stow
# ============================================================

info "Aplicando configurações via stow..."

cd "$DOTFILES_DIR"

STOW_PACKAGES=(
    hypr
    waybar
    wofi
    wlogout
    ghostty
    zsh
    gtk-3.0
    nvim
    vscode
)

# Remover configs existentes que conflitariam com o stow
for pkg in "${STOW_PACKAGES[@]}"; do
    if [ -d "$pkg/.config" ]; then
        # Para cada diretório dentro do pacote stow, remover o equivalente em ~/
        find "$pkg/.config" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
            target_dir="$HOME/.config/$(basename "$dir")"
            if [ -d "$target_dir" ] && [ ! -L "$target_dir" ]; then
                info "  Removendo config existente: $target_dir"
                rm -rf "$target_dir"
            fi
        done
    fi
done

# Remover .zshrc existente se não for symlink (conflita com stow)
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    info "  Removendo .zshrc existente..."
    rm -f "$HOME/.zshrc"
fi

for pkg in "${STOW_PACKAGES[@]}"; do
    info "  stow $pkg..."
    stow --restow "$pkg"
done

success "Configurações aplicadas."

# ============================================================
# 8. Configurar Zsh como shell padrão
# ============================================================

if [ "$SHELL" != "$(command -v zsh)" ]; then
    info "Configurando Zsh como shell padrão..."
    chsh -s "$(command -v zsh)"
    success "Zsh configurado como shell padrão."
else
    success "Zsh já é o shell padrão."
fi

# ============================================================
# 9. Criar diretórios necessários
# ============================================================

info "Criando diretórios..."
mkdir -p ~/Pictures/screenshots
mkdir -p ~/Pictures/wallpapers/walls
success "Diretórios criados."

# ============================================================
# 10. Copiar wallpaper padrão
# ============================================================

if [ -f "$DOTFILES_DIR/wallpapers/default.jpg" ]; then
    cp "$DOTFILES_DIR/wallpapers/default.jpg" ~/Pictures/wallpapers/walls/default.jpg
    success "Wallpaper padrão copiado."
else
    warn "Wallpaper padrão não encontrado em wallpapers/default.jpg"
fi

# ============================================================
# 11. Habilitar serviços
# ============================================================

info "Habilitando serviços..."
sudo systemctl enable --now NetworkManager 2>/dev/null || true
sudo systemctl enable --now bluetooth 2>/dev/null || true
systemctl --user enable pipewire wireplumber 2>/dev/null || true
success "Serviços habilitados."

# ============================================================
# Concluído!
# ============================================================

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Instalação concluída com sucesso!${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "GPU detectada: ${BLUE}$GPU_TYPE${NC}"
echo -e "Shell: ${BLUE}zsh${NC}"
echo ""
echo -e "${YELLOW}Reinicie o computador para aplicar todas as mudanças:${NC}"
echo -e "  sudo reboot"
echo ""
echo -e "Após o reboot, selecione ${BLUE}Hyprland${NC} no seu display manager"
echo -e "ou inicie manualmente com: ${BLUE}Hyprland${NC}"
echo ""
