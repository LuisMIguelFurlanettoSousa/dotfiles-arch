#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Full Install — Instalação base do Arch Linux
# ============================================================
# Chamado pelo instalar-sistema. Faz particionamento, pacstrap,
# chroot, GRUB e depois roda o install.sh dos dotfiles.
#
# Log: /tmp/full-install.log
# ============================================================

LOG_FILE="/tmp/full-install.log"

# ============================================================
# Cores
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
# Trap de erro
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
    echo -e "${RED}Log:${NC} $LOG_FILE" | tee -a "$LOG_FILE"

    # Tentar desmontar caso tenha falhado no meio
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
}

trap 'trap_error ${LINENO}' ERR

echo "=== Instalação iniciada em $(date) ===" > "$LOG_FILE"

# ============================================================
# Variáveis globais (preenchidas durante a execução)
# ============================================================

BOOT_MODE=""
TARGET_DISK=""
PART_EFI=""
PART_SWAP=""
PART_ROOT=""
INSTALL_USER=""
INSTALL_HOSTNAME=""
MICROCODE=""

# ============================================================
# 1. Validar pré-requisitos
# ============================================================

info "Validando pré-requisitos..."

if [ ! -d /run/archiso ]; then
    error "Este script deve ser executado a partir da ISO live do Arch Linux."
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

    case "$net_choice" in
        1)
            # Listar redes Wi-Fi disponíveis
            info "Buscando redes Wi-Fi..."

            # Garantir que o iwd está rodando
            systemctl start iwd 2>/dev/null || true
            sleep 2

            # Detectar interface wireless
            WIFI_DEV=$(iwctl device list 2>/dev/null | awk '/station/{print $2}' | head -1)
            if [ -z "$WIFI_DEV" ]; then
                # Fallback: pegar qualquer interface wlan
                WIFI_DEV=$(ip link show | grep -oP 'wlan\d+|wlp\S+' | head -1)
            fi

            if [ -z "$WIFI_DEV" ]; then
                error "Nenhuma interface Wi-Fi encontrada. Use cabo ethernet."
            fi

            info "Interface Wi-Fi: $WIFI_DEV"

            # Escanear redes
            iwctl station "$WIFI_DEV" scan 2>/dev/null
            sleep 3

            # Listar redes disponíveis
            echo ""
            echo -e "${BOLD}Redes Wi-Fi disponíveis:${NC}"
            echo ""
            mapfile -t NETWORKS < <(iwctl station "$WIFI_DEV" get-networks 2>/dev/null | grep -E '^\s+' | awk '{$1=$1};1' | grep -v '^-' | grep -v 'Network name' | grep -v '^\s*$' | sed 's/\x1b\[[0-9;]*m//g' | awk '{print $1}')

            if [ ${#NETWORKS[@]} -eq 0 ]; then
                # Fallback: mostrar saída bruta do iwctl
                echo -e "${YELLOW}Não foi possível listar automaticamente. Mostrando saída bruta:${NC}"
                iwctl station "$WIFI_DEV" get-networks 2>/dev/null
                echo ""
                read -rp "$(echo -e "${BOLD}Digite o nome da rede Wi-Fi:${NC} ")" WIFI_SSID
            else
                for i in "${!NETWORKS[@]}"; do
                    echo -e "  ${GREEN}[$((i+1))]${NC} ${NETWORKS[$i]}"
                done
                echo ""
                read -rp "$(echo -e "${BOLD}Selecione a rede [1-${#NETWORKS[@]}]:${NC} ")" wifi_choice

                if [[ "$wifi_choice" =~ ^[0-9]+$ ]] && [ "$wifi_choice" -ge 1 ] && [ "$wifi_choice" -le ${#NETWORKS[@]} ]; then
                    WIFI_SSID="${NETWORKS[$((wifi_choice-1))]}"
                else
                    read -rp "$(echo -e "${BOLD}Opção inválida. Digite o nome da rede manualmente:${NC} ")" WIFI_SSID
                fi
            fi

            # Pedir senha com 3 tentativas
            WIFI_TENTATIVAS=3
            WIFI_CONECTADO=false

            for tentativa in $(seq 1 $WIFI_TENTATIVAS); do
                echo ""
                read -rsp "$(echo -e "${BOLD}Senha do Wi-Fi ($WIFI_SSID) [tentativa $tentativa/$WIFI_TENTATIVAS]:${NC} ")" WIFI_PASS
                echo ""

                info "Conectando a '$WIFI_SSID'..."
                iwctl --passphrase "$WIFI_PASS" station "$WIFI_DEV" connect "$WIFI_SSID" 2>/dev/null

                sleep 5

                if curl -sf --max-time 10 "https://archlinux.org" > /dev/null 2>&1; then
                    success "Conectado ao Wi-Fi '$WIFI_SSID'."
                    WIFI_CONECTADO=true
                    break
                else
                    if [ "$tentativa" -lt "$WIFI_TENTATIVAS" ]; then
                        warn "Falha ao conectar. Verifique a senha e tente novamente."
                    fi
                fi
            done

            if [ "$WIFI_CONECTADO" = false ]; then
                error "Falha ao conectar ao Wi-Fi após $WIFI_TENTATIVAS tentativas."
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
        3)
            error "Instalação cancelada. Sem internet não é possível instalar."
            ;;
        *)
            error "Opção inválida."
            ;;
    esac
fi

if [ -d /sys/firmware/efi/efivars ]; then
    BOOT_MODE="uefi"
    info "Modo de boot: UEFI"
else
    BOOT_MODE="bios"
    info "Modo de boot: BIOS/Legacy"
fi

if lscpu | grep -qi "GenuineIntel"; then
    MICROCODE="intel-ucode"
else
    MICROCODE="amd-ucode"
fi
info "Microcode: $MICROCODE"

success "Pré-requisitos validados."

# ============================================================
# 2. Configurar teclado
# ============================================================

loadkeys br-abnt2
success "Teclado configurado (br-abnt2)."

# ============================================================
# 3. Selecionar disco
# ============================================================

info "Discos disponíveis:"
echo ""

mapfile -t DISKS < <(lsblk --nodeps --noheadings -o NAME,SIZE,TYPE | awk '$3=="disk" {print $1}')

if [ ${#DISKS[@]} -eq 0 ]; then
    error "Nenhum disco encontrado."
fi

for i in "${!DISKS[@]}"; do
    local_disk="${DISKS[$i]}"
    local_size=$(lsblk --nodeps --noheadings -o SIZE "/dev/$local_disk")
    local_model=$(lsblk --nodeps --noheadings -o MODEL "/dev/$local_disk" 2>/dev/null || echo "Desconhecido")
    echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_disk — ${BOLD}$local_size${NC} — $local_model"
done

echo ""
read -rp "$(echo -e "${BOLD}Selecione o disco [1-${#DISKS[@]}]:${NC} ")" disk_choice

if ! [[ "$disk_choice" =~ ^[0-9]+$ ]] || [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -gt ${#DISKS[@]} ]; then
    error "Opção inválida."
fi

TARGET_DISK="/dev/${DISKS[$((disk_choice-1))]}"
info "Disco selecionado: $TARGET_DISK"

# ============================================================
# 4. Menu de particionamento
# ============================================================

echo ""
echo -e "${BOLD}Como deseja particionar?${NC}"
echo -e "  ${GREEN}[1]${NC} Usar disco inteiro (automático)"
echo -e "  ${BLUE}[2]${NC} Particionar manualmente (abre cfdisk)"
echo ""
read -rp "$(echo -e "${BOLD}Opção [1-2]:${NC} ")" part_choice

case "$part_choice" in
    1)
        echo ""
        echo -e "${RED}${BOLD}ATENÇÃO: TODOS os dados de $TARGET_DISK serão APAGADOS!${NC}"
        read -rp "$(echo -e "${BOLD}Tem certeza? Digite 'SIM' para confirmar:${NC} ")" confirm
        if [ "$confirm" != "SIM" ]; then
            error "Particionamento cancelado pelo usuário."
        fi

        RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
        if [ "$RAM_GB" -le 8 ]; then
            SWAP_SIZE="${RAM_GB}G"
        else
            SWAP_SIZE="8G"
        fi
        info "Swap calculado: ${SWAP_SIZE} (RAM: ${RAM_GB}G)"

        sgdisk --zap-all "$TARGET_DISK" >> "$LOG_FILE" 2>&1

        if [ "$BOOT_MODE" = "uefi" ]; then
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
        else
            sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1
        fi

        if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
            PART_SUFFIX="p"
        else
            PART_SUFFIX=""
        fi

        if [ "$BOOT_MODE" = "uefi" ]; then
            PART_EFI="${TARGET_DISK}${PART_SUFFIX}1"
            PART_SWAP="${TARGET_DISK}${PART_SUFFIX}2"
            PART_ROOT="${TARGET_DISK}${PART_SUFFIX}3"
        else
            PART_EFI=""
            PART_SWAP="${TARGET_DISK}${PART_SUFFIX}2"
            PART_ROOT="${TARGET_DISK}${PART_SUFFIX}3"
        fi

        success "Particionamento automático concluído."
        ;;

    2)
        info "Abrindo cfdisk para $TARGET_DISK..."
        cfdisk "$TARGET_DISK"

        echo ""
        info "Partições detectadas:"
        echo ""
        mapfile -t PARTS < <(lsblk -ln -o NAME,SIZE,FSTYPE "$TARGET_DISK" | tail -n +2 | awk '{print $1}')

        if [ ${#PARTS[@]} -eq 0 ]; then
            error "Nenhuma partição encontrada em $TARGET_DISK. Rode novamente e crie as partições no cfdisk."
        fi

        for i in "${!PARTS[@]}"; do
            local_part="${PARTS[$i]}"
            local_info=$(lsblk -ln -o NAME,SIZE,FSTYPE "/dev/$local_part" | head -1)
            echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_part — $local_info"
        done

        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para ROOT? [1-${#PARTS[@]}]:${NC} ")" root_choice
        PART_ROOT="/dev/${PARTS[$((root_choice-1))]}"

        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para SWAP? [1-${#PARTS[@]}, ou 0 para nenhuma]:${NC} ")" swap_choice
        if [ "$swap_choice" != "0" ]; then
            PART_SWAP="/dev/${PARTS[$((swap_choice-1))]}"
        else
            PART_SWAP=""
        fi

        if [ "$BOOT_MODE" = "uefi" ]; then
            echo ""
            read -rp "$(echo -e "${BOLD}Qual partição para EFI? [1-${#PARTS[@]}]:${NC} ")" efi_choice
            PART_EFI="/dev/${PARTS[$((efi_choice-1))]}"
        fi

        success "Partições selecionadas."
        ;;

    *)
        error "Opção inválida."
        ;;
esac

info "Root: $PART_ROOT"
[ -n "$PART_SWAP" ] && info "Swap: $PART_SWAP"
[ -n "$PART_EFI" ] && info "EFI:  $PART_EFI"

# ============================================================
# 5. Formatar partições
# ============================================================

echo ""
echo -e "${YELLOW}As seguintes partições serão formatadas:${NC}"
echo -e "  Root: ${BOLD}$PART_ROOT${NC} → ext4"
[ -n "$PART_SWAP" ] && echo -e "  Swap: ${BOLD}$PART_SWAP${NC} → swap"

FORMAT_EFI="n"
if [ -n "$PART_EFI" ]; then
    echo ""
    echo -e "${YELLOW}A partição EFI (${PART_EFI}) já pode conter bootloaders de outros sistemas.${NC}"
    echo -e "${YELLOW}Se você tem Windows ou outro SO, ${RED}${BOLD}NÃO formate${NC}${YELLOW} a EFI.${NC}"
    read -rp "$(echo -e "${BOLD}Formatar a partição EFI? [s/N]:${NC} ")" FORMAT_EFI
    if [[ "$FORMAT_EFI" =~ ^[sS]$ ]]; then
        echo -e "  EFI:  ${BOLD}$PART_EFI${NC} → FAT32 (será formatada)"
    else
        echo -e "  EFI:  ${BOLD}$PART_EFI${NC} → manter existente (não formatar)"
    fi
fi

echo ""
read -rp "$(echo -e "${BOLD}Confirmar formatação? [s/N]:${NC} ")" fmt_confirm
if [[ ! "$fmt_confirm" =~ ^[sS]$ ]]; then
    error "Formatação cancelada pelo usuário."
fi

info "Formatando partições..."

mkfs.ext4 -F "$PART_ROOT" >> "$LOG_FILE" 2>&1
success "Root formatado (ext4)."

if [ -n "$PART_SWAP" ]; then
    mkswap "$PART_SWAP" >> "$LOG_FILE" 2>&1
    swapon "$PART_SWAP" >> "$LOG_FILE" 2>&1
    success "Swap ativado."
fi

if [ -n "$PART_EFI" ]; then
    if [[ "$FORMAT_EFI" =~ ^[sS]$ ]]; then
        mkfs.fat -F 32 "$PART_EFI" >> "$LOG_FILE" 2>&1
        success "EFI formatado (FAT32)."
    else
        success "EFI mantida sem formatar."
    fi
fi

# ============================================================
# 6. Montar partições
# ============================================================

info "Montando partições..."

mount "$PART_ROOT" /mnt
success "Root montado em /mnt."

if [ -n "$PART_EFI" ]; then
    mount --mkdir "$PART_EFI" /mnt/boot
    success "EFI montado em /mnt/boot."
fi

# ============================================================
# 7. Configurar mirrors
# ============================================================

info "Configurando mirrors (Brasil)..."
reflector --country Brazil --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist >> "$LOG_FILE" 2>&1
success "Mirrors configurados."

# ============================================================
# 8. Instalar sistema base
# ============================================================

# zsh incluído no pacstrap porque useradd usa -s /bin/zsh
info "Instalando sistema base (pacstrap)..."
pacstrap -K /mnt base linux linux-firmware linux-headers \
    "$MICROCODE" networkmanager grub efibootmgr os-prober \
    git base-devel sudo zsh >> "$LOG_FILE" 2>&1
success "Sistema base instalado."

# ============================================================
# 9. Gerar fstab
# ============================================================

info "Gerando fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

if [ ! -s /mnt/etc/fstab ]; then
    error "fstab está vazio. Algo deu errado na montagem."
fi

success "fstab gerado."

# ============================================================
# 10. Perguntar dados do usuário
# ============================================================

echo ""
echo -e "${BOLD}Configuração do sistema:${NC}"
echo ""

read -rp "$(echo -e "${BOLD}Hostname${NC} [archlinux]: ")" INSTALL_HOSTNAME
INSTALL_HOSTNAME="${INSTALL_HOSTNAME:-archlinux}"

read -rp "$(echo -e "${BOLD}Nome do usuário:${NC} ")" INSTALL_USER
while [ -z "$INSTALL_USER" ]; do
    echo -e "${RED}O nome do usuário não pode ser vazio.${NC}"
    read -rp "$(echo -e "${BOLD}Nome do usuário:${NC} ")" INSTALL_USER
done

echo -e "${BOLD}Senha do usuário ($INSTALL_USER):${NC}"
while true; do
    read -rsp "  Senha: " USER_PASS
    echo ""
    read -rsp "  Confirmar: " USER_PASS_CONFIRM
    echo ""
    if [ "$USER_PASS" = "$USER_PASS_CONFIRM" ] && [ -n "$USER_PASS" ]; then
        break
    fi
    echo -e "${RED}Senhas não conferem ou vazias. Tente novamente.${NC}"
done

echo -e "${BOLD}Senha do root:${NC}"
while true; do
    read -rsp "  Senha: " ROOT_PASS
    echo ""
    read -rsp "  Confirmar: " ROOT_PASS_CONFIRM
    echo ""
    if [ "$ROOT_PASS" = "$ROOT_PASS_CONFIRM" ] && [ -n "$ROOT_PASS" ]; then
        break
    fi
    echo -e "${RED}Senhas não conferem ou vazias. Tente novamente.${NC}"
done

# ============================================================
# 11. Configurar via arch-chroot
# ============================================================

info "Configurando o sistema via chroot..."

# Timezone
arch-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
arch-chroot /mnt hwclock --systohc

# Locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
sed -i 's/^#pt_BR.UTF-8/pt_BR.UTF-8/' /mnt/etc/locale.gen
arch-chroot /mnt locale-gen >> "$LOG_FILE" 2>&1
echo "LANG=pt_BR.UTF-8" > /mnt/etc/locale.conf
echo "KEYMAP=br-abnt2" > /mnt/etc/vconsole.conf

# Hostname
echo "$INSTALL_HOSTNAME" > /mnt/etc/hostname

# Senha do root
echo "root:${ROOT_PASS}" | arch-chroot /mnt chpasswd

# Criar usuário
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$INSTALL_USER"
echo "${INSTALL_USER}:${USER_PASS}" | arch-chroot /mnt chpasswd

# Configurar sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

# Habilitar serviços
arch-chroot /mnt systemctl enable NetworkManager >> "$LOG_FILE" 2>&1
arch-chroot /mnt systemctl enable bluetooth >> "$LOG_FILE" 2>&1

success "Sistema configurado."

# ── GRUB ──

info "Instalando GRUB..."

if [ "$BOOT_MODE" = "uefi" ]; then
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> "$LOG_FILE" 2>&1
else
    arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK" >> "$LOG_FILE" 2>&1
fi

# Habilitar os-prober
sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> "$LOG_FILE" 2>&1
success "GRUB instalado e configurado."

# ── Dotfiles + install.sh ──

info "Copiando dotfiles e executando install.sh..."

if [ -d /opt/dotfiles ]; then
    cp -r /opt/dotfiles "/mnt/home/${INSTALL_USER}/dotfiles"
    arch-chroot /mnt chown -R "${INSTALL_USER}:${INSTALL_USER}" "/home/${INSTALL_USER}/dotfiles"
    success "Dotfiles copiados para /home/${INSTALL_USER}/dotfiles."

    # Executar install.sh como o usuário (não como root)
    info "Executando install.sh (pós-instalação)..."
    arch-chroot /mnt runuser -u "$INSTALL_USER" -- /home/"$INSTALL_USER"/dotfiles/install.sh >> "$LOG_FILE" 2>&1 || {
        warn "install.sh retornou erro. Verifique o log: $LOG_FILE"
        warn "Você pode rodar manualmente após o reboot: cd ~/dotfiles && ./install.sh"
    }
else
    warn "/opt/dotfiles não encontrado. Pule a pós-instalação."
    warn "Após o reboot, clone os dotfiles e rode ./install.sh manualmente."
fi

# ============================================================
# 12. Finalizar
# ============================================================

info "Finalizando..."

umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "" | tee -a "$LOG_FILE"
echo -e "${GREEN}╔══════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                              ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║  Instalação concluída com sucesso!            ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                              ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}╚══════════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "  Hostname:  ${BLUE}$INSTALL_HOSTNAME${NC}" | tee -a "$LOG_FILE"
echo -e "  Usuário:   ${BLUE}$INSTALL_USER${NC}" | tee -a "$LOG_FILE"
echo -e "  Boot:      ${BLUE}$BOOT_MODE${NC}" | tee -a "$LOG_FILE"
echo -e "  Microcode: ${BLUE}$MICROCODE${NC}" | tee -a "$LOG_FILE"
echo -e "  Log:       ${BLUE}$LOG_FILE${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo -e "${YELLOW}Remova o pendrive e reinicie:${NC}" | tee -a "$LOG_FILE"
echo -e "  ${BOLD}reboot${NC}" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
