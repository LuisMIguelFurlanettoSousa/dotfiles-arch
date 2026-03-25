#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Dotfiles Hyprland — Instalador Automatizado para Arch Linux
# ============================================================
#
# Modo paranóico: log completo, retry em falhas de rede,
# backup de configs, validação pós-instalação, trap de erros.
#
# Uso: ./install.sh
# Log: ~/dotfiles/install.log
# ============================================================

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$DOTFILES_DIR/install.log"
BACKUP_DIR="$HOME/dotfiles-backup/$(date +%Y-%m-%d_%H-%M-%S)"
START_TIME=$(date +%s)
RETRY_MAX=3
RETRY_DELAY=5

# ============================================================
# Cores e funções de output
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"; }
success() { echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"; }
warn()    { echo -e "${YELLOW}[AVISO]${NC} $1" | tee -a "$LOG_FILE"; }
error()   { echo -e "${RED}[ERRO]${NC} $1" | tee -a "$LOG_FILE"; exit 1; }

# ============================================================
# Trap de erro global — captura linha e comando que falhou
# ============================================================

trap_error() {
    local exit_code=$?
    local line_number=$1
    echo "" | tee -a "$LOG_FILE"
    echo -e "${RED}╔══════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}║  ERRO FATAL — instalação interrompida    ║${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}╚══════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
    echo -e "${RED}Linha:${NC} $line_number" | tee -a "$LOG_FILE"
    echo -e "${RED}Código de saída:${NC} $exit_code" | tee -a "$LOG_FILE"
    echo -e "${RED}Log completo:${NC} $LOG_FILE" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}O script é idempotente. Corrija o problema e rode novamente:${NC}" | tee -a "$LOG_FILE"
    echo -e "  ${BOLD}./install.sh${NC}" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
}

trap 'trap_error ${LINENO}' ERR

# ============================================================
# Iniciar log
# ============================================================

echo "=== Instalação iniciada em $(date) ===" > "$LOG_FILE"
echo "Usuário: $(whoami)" >> "$LOG_FILE"
echo "Hostname: $(hostname)" >> "$LOG_FILE"
echo "Kernel: $(uname -r)" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

info "Log sendo salvo em: $LOG_FILE"

# ============================================================
# Funções auxiliares
# ============================================================

# Retry com backoff para comandos que dependem de rede
retry() {
    local desc="$1"
    shift
    local attempt=1

    while [ $attempt -le $RETRY_MAX ]; do
        info "  $desc (tentativa $attempt/$RETRY_MAX)..."
        if "$@" >> "$LOG_FILE" 2>&1; then
            return 0
        fi

        if [ $attempt -lt $RETRY_MAX ]; then
            warn "  Falhou. Tentando novamente em ${RETRY_DELAY}s..."
            sleep $RETRY_DELAY
        fi
        attempt=$((attempt + 1))
    done

    error "$desc falhou após $RETRY_MAX tentativas. Verifique o log: $LOG_FILE"
}

# Verificar se um pacote está instalado
pkg_installed() {
    pacman -Qi "$1" &>/dev/null
}

# Backup de arquivo/diretório antes de sobrescrever
backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        mkdir -p "$BACKUP_DIR"
        local rel_path="${target#$HOME/}"
        local backup_path="$BACKUP_DIR/$rel_path"
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$target" "$backup_path"
        info "  Backup: $target → $backup_path"
    fi
}

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

# Verificar conexão — se não tiver, oferecer Wi-Fi
if ! curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
    warn "Sem conexão com a internet."
    echo ""
    echo -e "${BOLD}Como deseja conectar?${NC}"
    echo -e "  ${GREEN}[1]${NC} Wi-Fi"
    echo -e "  ${BLUE}[2]${NC} Já estou com cabo ethernet (tentar novamente)"
    echo -e "  ${YELLOW}[3]${NC} Cancelar"
    echo ""
    read -rp "$(echo -e "${BOLD}Opção [1-3]:${NC} ")" net_choice

    case "${net_choice:-3}" in
        1)
            info "Buscando redes Wi-Fi..."
            # Usar nmcli (NetworkManager) se disponível, senão iwctl
            if command -v nmcli &>/dev/null && nmcli -t -f RUNNING general 2>/dev/null | grep -q running; then
                # Escanear e listar redes via NetworkManager
                nmcli device wifi rescan 2>/dev/null || true
                sleep 3
                echo ""
                echo -e "${BOLD}Redes Wi-Fi disponíveis:${NC}"
                echo ""
                nmcli device wifi list 2>/dev/null
                echo ""
                read -rp "$(echo -e "${BOLD}Digite o nome exato da rede Wi-Fi:${NC} ")" WIFI_SSID

                WIFI_CONECTADO=false
                for tentativa in 1 2 3; do
                    echo ""
                    read -rsp "$(echo -e "${BOLD}Senha do Wi-Fi ($WIFI_SSID) [tentativa $tentativa/3]:${NC} ")" WIFI_PASS
                    echo ""
                    info "Conectando a '$WIFI_SSID'..."
                    nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASS" 2>/dev/null || true
                    sleep 5
                    if curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
                        success "Conectado ao Wi-Fi '$WIFI_SSID'."
                        WIFI_CONECTADO=true
                        break
                    else
                        warn "Falha ao conectar. Verifique a senha e tente novamente."
                    fi
                done
                if [ "$WIFI_CONECTADO" = false ]; then
                    error "Falha ao conectar ao Wi-Fi após 3 tentativas."
                fi
            elif command -v iwctl &>/dev/null; then
                # Fallback: usar iwctl
                systemctl start iwd 2>/dev/null || true
                sleep 2
                WIFI_DEV=$(iwctl device list 2>/dev/null | awk '/station/{print $2}' | head -1)
                if [ -z "${WIFI_DEV:-}" ]; then
                    WIFI_DEV=$(ip link show 2>/dev/null | grep -oP 'wlan\d+|wlp\S+' | head -1 || true)
                fi
                if [ -z "${WIFI_DEV:-}" ]; then
                    error "Nenhuma interface Wi-Fi encontrada. Use cabo ethernet."
                fi
                iwctl station "$WIFI_DEV" scan 2>/dev/null || true
                sleep 3
                echo ""
                echo -e "${BOLD}Redes Wi-Fi disponíveis:${NC}"
                iwctl station "$WIFI_DEV" get-networks 2>/dev/null || true
                echo ""
                read -rp "$(echo -e "${BOLD}Digite o nome exato da rede Wi-Fi:${NC} ")" WIFI_SSID

                WIFI_CONECTADO=false
                for tentativa in 1 2 3; do
                    echo ""
                    read -rsp "$(echo -e "${BOLD}Senha do Wi-Fi ($WIFI_SSID) [tentativa $tentativa/3]:${NC} ")" WIFI_PASS
                    echo ""
                    info "Conectando a '$WIFI_SSID'..."
                    iwctl --passphrase "$WIFI_PASS" station "$WIFI_DEV" connect "$WIFI_SSID" 2>/dev/null || true
                    sleep 5
                    if curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
                        success "Conectado ao Wi-Fi '$WIFI_SSID'."
                        WIFI_CONECTADO=true
                        break
                    else
                        warn "Falha ao conectar. Verifique a senha e tente novamente."
                    fi
                done
                if [ "$WIFI_CONECTADO" = false ]; then
                    error "Falha ao conectar ao Wi-Fi após 3 tentativas."
                fi
            else
                error "Nenhum gerenciador de rede encontrado (nmcli/iwctl). Conecte-se manualmente."
            fi
            ;;
        2)
            info "Tentando novamente..."
            sleep 3
            if ! curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
                error "Ainda sem internet. Verifique o cabo ethernet."
            fi
            success "Conectado via ethernet."
            ;;
        *)
            error "Instalação cancelada."
            ;;
    esac
fi

# Verificar se sudo está configurado e manter cache ativo
if ! sudo -v 2>/dev/null; then
    error "sudo não está configurado para este usuário."
fi

# Manter sudo ativo durante toda a execução (renova a cada 50s em background)
while true; do sudo -n true; sleep 50; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
# Garantir que o processo de keepalive morre quando o script terminar
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

success "Pré-requisitos validados."

# ============================================================
# 2. Inicializar keyring e atualizar sistema
# ============================================================

# Detectar se está rodando dentro de um chroot (ex: via full-install.sh)
IN_CHROOT=false
if [ "$(stat -c %d:%i /)" != "$(stat -c %d:%i /proc/1/root/.)" ] 2>/dev/null; then
    IN_CHROOT=true
    info "Detectado ambiente chroot."
fi

if [ "$IN_CHROOT" = false ]; then
    info "Inicializando keyring do pacman..."
    sudo pacman-key --init >> "$LOG_FILE" 2>&1
    sudo pacman-key --populate archlinux >> "$LOG_FILE" 2>&1
    success "Keyring inicializado."

    info "Atualizando sistema..."
    retry "Atualização do sistema (pacman -Syu)" sudo pacman -Syu --noconfirm
    success "Sistema atualizado."
else
    info "Chroot detectado: pulando keyring e atualização (já feito pelo pacstrap)."
fi

# ============================================================
# 3. Habilitar multilib (necessário para pacotes lib32-*)
# ============================================================

if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    info "Habilitando repositório multilib..."
    # Descomentar [multilib] e a linha Include logo abaixo
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    retry "Sincronizar repositórios" sudo pacman -Sy --noconfirm
    success "Multilib habilitado."
else
    success "Multilib já está habilitado."
fi

# ============================================================
# 4. Instalar yay (AUR helper)
# ============================================================

if command -v yay &>/dev/null; then
    success "yay já está instalado."
else
    info "Instalando yay..."
    sudo pacman -S --needed --noconfirm git base-devel >> "$LOG_FILE" 2>&1

    # Verificar dependências críticas do makepkg
    for dep in fakeroot strip make gcc; do
        if ! command -v "$dep" &>/dev/null; then
            error "Dependência '$dep' não encontrada após instalar base-devel. Verifique o pacman."
        fi
    done

    TEMP_DIR=$(mktemp -d)
    git clone https://aur.archlinux.org/yay.git "$TEMP_DIR/yay" >> "$LOG_FILE" 2>&1
    cd "$TEMP_DIR/yay"
    makepkg -si --noconfirm >> "$LOG_FILE" 2>&1
    cd "$DOTFILES_DIR"
    rm -rf "$TEMP_DIR"

    if ! command -v yay &>/dev/null; then
        error "yay não foi encontrado após instalação. Verifique o log."
    fi

    success "yay instalado."
fi

# ============================================================
# 5. Detectar GPU e instalar drivers
# ============================================================

info "Detectando GPU..."
GPU_INFO=$(lspci -nn | grep -E '\[03[0-9]{2}\]' || true)
GPU_TYPE="intel" # padrão

echo "GPU detectada (lspci): $GPU_INFO" >> "$LOG_FILE"

if echo "$GPU_INFO" | grep -qi nvidia; then
    GPU_TYPE="nvidia"
    info "GPU NVIDIA detectada."
    retry "Instalar drivers NVIDIA" sudo pacman -S --needed --noconfirm \
        nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
elif echo "$GPU_INFO" | grep -qi 'amd\|radeon'; then
    GPU_TYPE="amd"
    info "GPU AMD detectada."
    retry "Instalar drivers AMD" sudo pacman -S --needed --noconfirm \
        mesa vulkan-radeon lib32-mesa lib32-vulkan-radeon
else
    info "GPU Intel detectada (ou não identificada)."
    retry "Instalar drivers Intel" sudo pacman -S --needed --noconfirm \
        mesa vulkan-intel lib32-mesa lib32-vulkan-intel
fi

success "Drivers de GPU instalados ($GPU_TYPE)."

# ============================================================
# 6. Instalar pacotes
# ============================================================

info "Instalando pacotes via pacman..."

PACMAN_PKGS=(
    # Hyprland core
    hyprland
    hyprlock
    xdg-desktop-portal-hyprland
    # Barra, menu e seletor
    waybar
    wofi
    rofi
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

retry "Instalar pacotes pacman" sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}"
success "Pacotes pacman instalados."

info "Instalando pacotes via yay (AUR)..."

AUR_PKGS=(
    ghostty
    visual-studio-code-bin
    bibata-cursor-theme
    ttf-jetbrains-mono-nerd
    wlogout
)

# AUR: instalar um por um com fallback (se um falhar, os outros continuam)
AUR_FAILED=()
for pkg in "${AUR_PKGS[@]}"; do
    if pkg_installed "$pkg"; then
        success "  $pkg já está instalado."
        continue
    fi

    info "  Instalando $pkg..."
    if yay -S --needed --noconfirm "$pkg" >> "$LOG_FILE" 2>&1; then
        success "  $pkg instalado."
    else
        warn "  $pkg falhou. Continuando com os demais..."
        AUR_FAILED+=("$pkg")
    fi
done

if [ ${#AUR_FAILED[@]} -gt 0 ]; then
    warn "Pacotes AUR que falharam: ${AUR_FAILED[*]}"
    warn "Instale manualmente após a conclusão: yay -S ${AUR_FAILED[*]}"
else
    success "Todos os pacotes AUR instalados."
fi

# ============================================================
# 7. Aplicar env.conf conforme GPU
# ============================================================

info "Configurando env.conf para GPU $GPU_TYPE..."

if [ "$GPU_TYPE" = "nvidia" ]; then
    if [ -f "$DOTFILES_DIR/hypr/.config/hypr/conf/env.conf.nvidia" ]; then
        cp "$DOTFILES_DIR/hypr/.config/hypr/conf/env.conf.nvidia" \
           "$DOTFILES_DIR/hypr/.config/hypr/conf/env.conf"
    else
        warn "Template env.conf.nvidia não encontrado. Mantendo env.conf padrão."
    fi
fi

success "env.conf configurado."

# ============================================================
# 8. Backup e aplicar configs via stow
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

# Backup e remoção de configs conflitantes
for pkg in "${STOW_PACKAGES[@]}"; do
    if [ -d "$pkg/.config" ]; then
        find "$pkg/.config" -mindepth 1 -maxdepth 1 | while read -r item; do
            target="$HOME/.config/$(basename "$item")"
            if [ -e "$target" ] && [ ! -L "$target" ]; then
                backup_if_exists "$target"
                rm -rf "$target"
            fi
        done
    fi
done

# Backup e remover .zshrc existente
if [ -f "$HOME/.zshrc" ] && [ ! -L "$HOME/.zshrc" ]; then
    backup_if_exists "$HOME/.zshrc"
    rm -f "$HOME/.zshrc"
fi

# Backup e remover .tmux.conf existente
if [ -f "$HOME/.tmux.conf" ] && [ ! -L "$HOME/.tmux.conf" ]; then
    backup_if_exists "$HOME/.tmux.conf"
    rm -f "$HOME/.tmux.conf"
fi

# Aplicar stow com tratamento de erro por pacote
STOW_FAILED=()
for pkg in "${STOW_PACKAGES[@]}"; do
    if [ ! -d "$DOTFILES_DIR/$pkg" ]; then
        warn "  Pacote stow '$pkg' não encontrado no repo. Pulando..."
        continue
    fi

    info "  stow $pkg..."
    if stow --restow "$pkg" >> "$LOG_FILE" 2>&1; then
        success "  $pkg aplicado."
    else
        warn "  stow $pkg falhou. Tentando com --adopt..."
        if stow --adopt "$pkg" >> "$LOG_FILE" 2>&1; then
            # --adopt traz os arquivos conflitantes para o repo
            # Restaurar os arquivos originais do repo
            git checkout -- "$pkg/" >> "$LOG_FILE" 2>&1 || true
            stow --restow "$pkg" >> "$LOG_FILE" 2>&1 || true
            success "  $pkg aplicado (via adopt + restore)."
        else
            STOW_FAILED+=("$pkg")
            warn "  stow $pkg falhou definitivamente. Verifique o log."
        fi
    fi
done

if [ ${#STOW_FAILED[@]} -gt 0 ]; then
    warn "Pacotes stow que falharam: ${STOW_FAILED[*]}"
fi

if [ -d "$BACKUP_DIR" ]; then
    info "Configs anteriores salvas em: $BACKUP_DIR"
fi

success "Configurações aplicadas."

# ============================================================
# 9. Configurar Zsh como shell padrão
# ============================================================

ZSH_PATH="$(command -v zsh)"

if [ "$SHELL" != "$ZSH_PATH" ]; then
    info "Configurando Zsh como shell padrão..."
    # Usar sudo usermod em vez de chsh (não pede senha interativamente)
    if sudo usermod -s "$ZSH_PATH" "$(whoami)" >> "$LOG_FILE" 2>&1; then
        success "Zsh configurado como shell padrão."
    else
        warn "Falha ao configurar Zsh. Execute manualmente: chsh -s $ZSH_PATH"
    fi
else
    success "Zsh já é o shell padrão."
fi

# ============================================================
# 10. Criar diretórios necessários
# ============================================================

info "Criando diretórios..."
mkdir -p ~/Pictures/screenshots
mkdir -p ~/Pictures/wallpapers/walls
success "Diretórios criados."

# ============================================================
# 11. Copiar wallpaper padrão
# ============================================================

if [ -f "$DOTFILES_DIR/wallpapers/default.jpg" ]; then
    cp "$DOTFILES_DIR/wallpapers/default.jpg" ~/Pictures/wallpapers/walls/default.jpg
    success "Wallpaper padrão copiado."
else
    warn "Wallpaper padrão não encontrado em wallpapers/default.jpg"
fi

# ============================================================
# 12. Habilitar serviços
# ============================================================

info "Habilitando serviços..."

# Serviços do sistema (com sudo)
# No chroot, --now não funciona (systemd não é PID 1), usar só enable
if [ "$IN_CHROOT" = true ]; then
    SYSTEMCTL_FLAG="enable"
else
    SYSTEMCTL_FLAG="enable --now"
fi

for svc in NetworkManager bluetooth; do
    if sudo systemctl $SYSTEMCTL_FLAG "$svc" >> "$LOG_FILE" 2>&1; then
        success "  $svc habilitado."
    else
        warn "  Falha ao habilitar $svc."
    fi
done

# Serviços do usuário (sem sudo, pode falhar em TTY puro)
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    for svc in pipewire wireplumber; do
        if systemctl --user enable "$svc" >> "$LOG_FILE" 2>&1; then
            success "  $svc (user) habilitado."
        else
            warn "  Falha ao habilitar $svc (user). Será ativado automaticamente no login."
        fi
    done
else
    warn "Sessão D-Bus não detectada (TTY puro). PipeWire será habilitado automaticamente no primeiro login gráfico."
fi

# ============================================================
# 13. Validação pós-instalação
# ============================================================

info "Validando instalação..."

CRITICAL_PKGS=(hyprland waybar wofi ghostty zsh stow)
VALIDATION_FAILED=()

for pkg in "${CRITICAL_PKGS[@]}"; do
    if command -v "$pkg" &>/dev/null || pkg_installed "$pkg"; then
        success "  $pkg ✓"
    else
        VALIDATION_FAILED+=("$pkg")
        warn "  $pkg ✗ — NÃO encontrado!"
    fi
done

# Validar que os symlinks do stow existem
CRITICAL_CONFIGS=(
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/waybar/config.jsonc"
    "$HOME/.config/wofi/config"
    "$HOME/.zshrc"
)

for cfg in "${CRITICAL_CONFIGS[@]}"; do
    if [ -L "$cfg" ] || [ -f "$cfg" ]; then
        success "  $(basename "$cfg") ✓"
    else
        VALIDATION_FAILED+=("$cfg")
        warn "  $cfg ✗ — NÃO encontrado!"
    fi
done

if [ ${#VALIDATION_FAILED[@]} -gt 0 ]; then
    warn "Validação encontrou ${#VALIDATION_FAILED[@]} problema(s). Verifique o log."
else
    success "Todos os componentes críticos validados."
fi

# ============================================================
# Resumo final
# ============================================================

END_TIME=$(date +%s)
ELAPSED=$(( END_TIME - START_TIME ))
MINUTES=$(( ELAPSED / 60 ))
SECONDS_REMAINING=$(( ELAPSED % 60 ))

# Contar pacotes instalados
TOTAL_PACMAN=$(pacman -Qq 2>/dev/null | wc -l)

echo "" | tee -a "$LOG_FILE"
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║  Instalação concluída com sucesso!        ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "  GPU detectada:    ${BLUE}$GPU_TYPE${NC}" | tee -a "$LOG_FILE"
echo -e "  Shell:            ${BLUE}zsh${NC}" | tee -a "$LOG_FILE"
echo -e "  Pacotes totais:   ${BLUE}$TOTAL_PACMAN${NC}" | tee -a "$LOG_FILE"
echo -e "  Tempo:            ${BLUE}${MINUTES}min ${SECONDS_REMAINING}s${NC}" | tee -a "$LOG_FILE"
echo -e "  Log:              ${BLUE}$LOG_FILE${NC}" | tee -a "$LOG_FILE"

if [ -d "$BACKUP_DIR" ]; then
    echo -e "  Backup:           ${BLUE}$BACKUP_DIR${NC}" | tee -a "$LOG_FILE"
fi

if [ ${#AUR_FAILED[@]} -gt 0 ]; then
    echo "" | tee -a "$LOG_FILE"
    echo -e "  ${YELLOW}Pacotes AUR pendentes: ${AUR_FAILED[*]}${NC}" | tee -a "$LOG_FILE"
    echo -e "  ${YELLOW}Instale com: yay -S ${AUR_FAILED[*]}${NC}" | tee -a "$LOG_FILE"
fi

if [ ${#STOW_FAILED[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}Stow pendentes: ${STOW_FAILED[*]}${NC}" | tee -a "$LOG_FILE"
fi

if [ ${#VALIDATION_FAILED[@]} -gt 0 ]; then
    echo -e "  ${YELLOW}Validação pendente: ${VALIDATION_FAILED[*]}${NC}" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Reinicie o computador para aplicar todas as mudanças:${NC}" | tee -a "$LOG_FILE"
echo -e "  ${BOLD}sudo reboot${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "Após o reboot, selecione ${BLUE}Hyprland${NC} no seu display manager" | tee -a "$LOG_FILE"
echo -e "ou inicie manualmente com: ${BLUE}Hyprland${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

echo "=== Instalação finalizada em $(date) ===" >> "$LOG_FILE"
