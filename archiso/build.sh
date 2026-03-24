#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Build da ISO customizada — Arch Linux + Hyprland
# ============================================================
# Uso: sudo ./build.sh
# Saída: ~/iso-out/archlinux-hyprland-YYYY.MM.DD-x86_64.iso
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
WORK_DIR="/tmp/archiso-work"
OUT_DIR="$HOME/iso-out"
PROFILE_DIR="/tmp/archiso-profile"

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
# 1. Verificar pré-requisitos
# ============================================================

if [ "$EUID" -ne 0 ]; then
    error "Execute como root: sudo ./build.sh"
fi

if ! pacman -Qi archiso &>/dev/null; then
    error "archiso não está instalado. Instale com: sudo pacman -S archiso"
fi

# ============================================================
# 2. Limpar builds anteriores
# ============================================================

info "Limpando builds anteriores..."
rm -rf "$WORK_DIR" "$PROFILE_DIR"
mkdir -p "$OUT_DIR"

# ============================================================
# 3. Copiar perfil releng
# ============================================================

info "Copiando perfil releng..."
cp -r /usr/share/archiso/configs/releng/ "$PROFILE_DIR"
success "Perfil releng copiado."

# ============================================================
# 4. Habilitar multilib no pacman.conf do build
# ============================================================

info "Habilitando multilib..."
sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' "$PROFILE_DIR/pacman.conf"
success "Multilib habilitado."

# ============================================================
# 5. Adicionar pacotes extras
# ============================================================

info "Adicionando pacotes extras..."
cat "$SCRIPT_DIR/packages.x86_64" >> "$PROFILE_DIR/packages.x86_64"

# Remover duplicatas mantendo a ordem
awk '!seen[$0]++ || /^#/ || /^$/' "$PROFILE_DIR/packages.x86_64" > "$PROFILE_DIR/packages.x86_64.tmp"
mv "$PROFILE_DIR/packages.x86_64.tmp" "$PROFILE_DIR/packages.x86_64"

success "Pacotes extras adicionados."

# ============================================================
# 6. Copiar airootfs customizado
# ============================================================

info "Copiando configurações customizadas..."
cp -r "$SCRIPT_DIR/airootfs/"* "$PROFILE_DIR/airootfs/" 2>/dev/null || true

# Copiar dotfiles para /etc/skel
info "Copiando dotfiles para /etc/skel..."
SKEL_DIR="$PROFILE_DIR/airootfs/etc/skel"
mkdir -p "$SKEL_DIR/.config"

# Copiar módulos stow (sem a estrutura stow)
for module in hypr waybar wofi wlogout nvim; do
    if [ -d "$REPO_DIR/$module/.config/$module" ]; then
        cp -r "$REPO_DIR/$module/.config/$module" "$SKEL_DIR/.config/"
        success "  $module copiado para skel."
    fi
done

# GTK
if [ -d "$REPO_DIR/gtk-3.0/.config/gtk-3.0" ]; then
    cp -r "$REPO_DIR/gtk-3.0/.config/gtk-3.0" "$SKEL_DIR/.config/"
    success "  gtk-3.0 copiado para skel."
fi

# Ghostty config (mesmo sem o binário no live, prepara para pós-instalação)
if [ -d "$REPO_DIR/ghostty/.config/ghostty" ]; then
    cp -r "$REPO_DIR/ghostty/.config/ghostty" "$SKEL_DIR/.config/"
    success "  ghostty (config) copiado para skel."
fi

# ZSH
if [ -f "$REPO_DIR/zsh/.zshrc" ]; then
    cp "$REPO_DIR/zsh/.zshrc" "$SKEL_DIR/.zshrc"
    success "  .zshrc copiado para skel."
fi

# Wallpapers
if [ -f "$REPO_DIR/wallpapers/default.jpg" ]; then
    mkdir -p "$SKEL_DIR/Pictures/wallpapers/walls"
    cp "$REPO_DIR/wallpapers/default.jpg" "$SKEL_DIR/Pictures/wallpapers/walls/"
    success "  Wallpaper copiado para skel."
fi

# Fix terminal do live: substituir ghostty por foot no skel
# O programs.conf original usa $terminal = ghostty (AUR, não disponível no live).
if [ -f "$SKEL_DIR/.config/hypr/conf/programs.conf" ]; then
    sed -i 's/\$terminal = ghostty/$terminal = foot/' "$SKEL_DIR/.config/hypr/conf/programs.conf"
    success "  Terminal do live substituído: ghostty → foot no programs.conf do skel."
fi

# ============================================================
# 7. Copiar repo completo para /opt/dotfiles
# ============================================================

info "Copiando repositório para /opt/dotfiles..."
OPT_DIR="$PROFILE_DIR/airootfs/opt/dotfiles"
mkdir -p "$OPT_DIR"

# Copiar tudo exceto .git, diretórios de build e ISOs
rsync -a --exclude='.git' --exclude='docs/superpowers' --exclude='iso-out' --exclude='*.iso' "$REPO_DIR/" "$OPT_DIR/"
success "Repositório copiado para /opt/dotfiles."

# ============================================================
# 8. Atualizar profiledef.sh
# ============================================================

info "Atualizando profiledef.sh..."

sed -i "s|^iso_name=.*|iso_name=\"archlinux-hyprland\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_label=.*|iso_label=\"ARCH_HYPR_\$(date --date=\"@\${SOURCE_DATE_EPOCH:-\$(date +%s)}\" +%Y%m)\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_publisher=.*|iso_publisher=\"Luis Miguel <https://github.com/LuisMIguelFurlanettoSousa>\"|" "$PROFILE_DIR/profiledef.sh"
sed -i "s|^iso_application=.*|iso_application=\"Arch Linux + Hyprland — Live/Install\"|" "$PROFILE_DIR/profiledef.sh"

# Adicionar permissões customizadas ao file_permissions
sed -i '/^\s*\[\"\/etc\/gshadow\"\]/a\  ["/root/.zlogin"]="0:0:755"\n  ["/usr/local/bin/menu-live"]="0:0:755"\n  ["/usr/local/bin/instalar-sistema"]="0:0:755"\n  ["/usr/local/bin/full-install.sh"]="0:0:755"\n  ["/opt/dotfiles/install.sh"]="0:0:755"' "$PROFILE_DIR/profiledef.sh"

success "profiledef.sh atualizado."

# ============================================================
# 9. Build da ISO
# ============================================================

info "Iniciando build da ISO (isso pode levar 10-30 minutos)..."
echo ""

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"

# ============================================================
# 10. Gerar checksum
# ============================================================

ISO_FILE=$(ls -t "$OUT_DIR"/archlinux-hyprland-*.iso 2>/dev/null | head -1)

if [ -z "$ISO_FILE" ]; then
    error "ISO não foi gerada. Verifique os erros acima."
fi

info "Gerando checksum SHA256..."
sha256sum "$ISO_FILE" > "${ISO_FILE}.sha256"

# ============================================================
# 11. Limpar
# ============================================================

info "Limpando arquivos temporários..."
rm -rf "$WORK_DIR" "$PROFILE_DIR"

# ============================================================
# Resumo
# ============================================================

ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ISO gerada com sucesso!                     ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ISO:      ${BLUE}$ISO_FILE${NC}"
echo -e "  Tamanho:  ${BLUE}$ISO_SIZE${NC}"
echo -e "  SHA256:   ${BLUE}${ISO_FILE}.sha256${NC}"
echo ""
echo -e "${YELLOW}Para testar com QEMU:${NC}"
echo -e "  run_archiso -u -i $ISO_FILE"
echo ""
echo -e "${YELLOW}Para gravar no USB:${NC}"
echo -e "  sudo dd bs=4M if=$ISO_FILE of=/dev/sdX conv=fsync oflag=direct status=progress"
echo ""
