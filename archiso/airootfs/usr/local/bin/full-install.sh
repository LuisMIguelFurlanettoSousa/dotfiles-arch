#!/usr/bin/env bash
set -uo pipefail
# Nota: NÃO usar set -e. O controle de erros é feito manualmente
# para evitar que pipefail + tee matem o script em falsos positivos.

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

echo "=== Instalação iniciada em $(date) ===" > "$LOG_FILE"

# ============================================================
# Cleanup em caso de erro (trap)
# ============================================================

cleanup() {
    umount -R /mnt 2>/dev/null || true
    swapoff -a 2>/dev/null || true
}
trap cleanup EXIT

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
INSTALL_KEYMAP="br-abnt2"
INSTALL_LOCALE="pt_BR.UTF-8"
INSTALL_TIMEZONE="America/Sao_Paulo"

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
            info "Buscando redes Wi-Fi..."
            systemctl start iwd 2>/dev/null || true
            sleep 2

            # Detectar interface wireless
            WIFI_DEV=$(iwctl device list 2>/dev/null | awk '/station/{print $2}' | head -1)
            if [ -z "${WIFI_DEV:-}" ]; then
                WIFI_DEV=$(ip link show 2>/dev/null | grep -oP 'wlan\d+|wlp\S+' | head -1 || true)
            fi
            if [ -z "${WIFI_DEV:-}" ]; then
                error "Nenhuma interface Wi-Fi encontrada. Use cabo ethernet."
            fi
            info "Interface Wi-Fi: $WIFI_DEV"

            iwctl station "$WIFI_DEV" scan 2>/dev/null || true
            sleep 3

            echo ""
            echo -e "${BOLD}Redes Wi-Fi disponíveis:${NC}"
            echo ""

            # Mostrar saída bruta do iwctl (o parsing de SSIDs com espaços é frágil)
            iwctl station "$WIFI_DEV" get-networks 2>/dev/null || true
            echo ""
            read -rp "$(echo -e "${BOLD}Digite o nome exato da rede Wi-Fi:${NC} ")" WIFI_SSID

            if [ -z "${WIFI_SSID:-}" ]; then
                error "Nome da rede não pode ser vazio."
            fi

            # 3 tentativas de senha
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
            error "Instalação cancelada."
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

if lscpu 2>/dev/null | grep -qi "GenuineIntel"; then
    MICROCODE="intel-ucode"
else
    MICROCODE="amd-ucode"
fi
info "Microcode: $MICROCODE"

success "Pré-requisitos validados."

# ============================================================
# 2. Configurar teclado e regionalização
# ============================================================

echo ""
echo -e "${BOLD}Configuração regional padrão:${NC}"
echo -e "  Teclado:  ${BLUE}br-abnt2${NC}"
echo -e "  Idioma:   ${BLUE}pt_BR.UTF-8${NC}"
echo -e "  Timezone: ${BLUE}America/Sao_Paulo${NC}"
echo ""
read -rp "$(echo -e "${BOLD}Manter configuração padrão (pt_BR, teclado ABNT2)? [S/n]:${NC} ")" regional_choice

if [[ "${regional_choice:-}" =~ ^[nN]$ ]]; then
    echo ""
    echo -e "${BOLD}Keymaps comuns:${NC}"
    echo -e "  ${GREEN}[1]${NC} br-abnt2 (Brasil ABNT2)"
    echo -e "  ${GREEN}[2]${NC} us (EUA - Internacional)"
    echo -e "  ${GREEN}[3]${NC} uk (Reino Unido)"
    echo -e "  ${GREEN}[4]${NC} de (Alemanha)"
    echo -e "  ${GREEN}[5]${NC} fr (França)"
    echo -e "  ${GREEN}[6]${NC} Outro (digitar manualmente)"
    echo ""
    read -rp "$(echo -e "${BOLD}Keymap [1-6]:${NC} ")" keymap_choice
    case "${keymap_choice:-1}" in
        1) INSTALL_KEYMAP="br-abnt2" ;;
        2) INSTALL_KEYMAP="us" ;;
        3) INSTALL_KEYMAP="uk" ;;
        4) INSTALL_KEYMAP="de" ;;
        5) INSTALL_KEYMAP="fr" ;;
        6) read -rp "$(echo -e "${BOLD}Digite o keymap:${NC} ")" INSTALL_KEYMAP ;;
        *) INSTALL_KEYMAP="br-abnt2" ;;
    esac

    echo ""
    echo -e "${BOLD}Locales comuns:${NC}"
    echo -e "  ${GREEN}[1]${NC} pt_BR.UTF-8 (Português Brasil)"
    echo -e "  ${GREEN}[2]${NC} en_US.UTF-8 (Inglês EUA)"
    echo -e "  ${GREEN}[3]${NC} en_GB.UTF-8 (Inglês UK)"
    echo -e "  ${GREEN}[4]${NC} es_ES.UTF-8 (Espanhol)"
    echo -e "  ${GREEN}[5]${NC} de_DE.UTF-8 (Alemão)"
    echo -e "  ${GREEN}[6]${NC} Outro (digitar manualmente)"
    echo ""
    read -rp "$(echo -e "${BOLD}Locale [1-6]:${NC} ")" locale_choice
    case "${locale_choice:-1}" in
        1) INSTALL_LOCALE="pt_BR.UTF-8" ;;
        2) INSTALL_LOCALE="en_US.UTF-8" ;;
        3) INSTALL_LOCALE="en_GB.UTF-8" ;;
        4) INSTALL_LOCALE="es_ES.UTF-8" ;;
        5) INSTALL_LOCALE="de_DE.UTF-8" ;;
        6) read -rp "$(echo -e "${BOLD}Digite o locale (ex: fr_FR.UTF-8):${NC} ")" INSTALL_LOCALE ;;
        *) INSTALL_LOCALE="pt_BR.UTF-8" ;;
    esac

    echo ""
    echo -e "${BOLD}Timezones comuns:${NC}"
    echo -e "  ${GREEN}[1]${NC} America/Sao_Paulo"
    echo -e "  ${GREEN}[2]${NC} America/New_York"
    echo -e "  ${GREEN}[3]${NC} America/Chicago"
    echo -e "  ${GREEN}[4]${NC} America/Los_Angeles"
    echo -e "  ${GREEN}[5]${NC} Europe/London"
    echo -e "  ${GREEN}[6]${NC} Europe/Berlin"
    echo -e "  ${GREEN}[7]${NC} Outro (digitar manualmente)"
    echo ""
    read -rp "$(echo -e "${BOLD}Timezone [1-7]:${NC} ")" tz_choice
    case "${tz_choice:-1}" in
        1) INSTALL_TIMEZONE="America/Sao_Paulo" ;;
        2) INSTALL_TIMEZONE="America/New_York" ;;
        3) INSTALL_TIMEZONE="America/Chicago" ;;
        4) INSTALL_TIMEZONE="America/Los_Angeles" ;;
        5) INSTALL_TIMEZONE="Europe/London" ;;
        6) INSTALL_TIMEZONE="Europe/Berlin" ;;
        7) read -rp "$(echo -e "${BOLD}Digite o timezone (ex: Asia/Tokyo):${NC} ")" INSTALL_TIMEZONE ;;
        *) INSTALL_TIMEZONE="America/Sao_Paulo" ;;
    esac
fi

info "Keymap: $INSTALL_KEYMAP | Locale: $INSTALL_LOCALE | Timezone: $INSTALL_TIMEZONE"

loadkeys "$INSTALL_KEYMAP" || warn "Falha ao configurar teclado. Continuando com o padrão."
success "Teclado configurado ($INSTALL_KEYMAP)."

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
    local_size=$(lsblk --nodeps --noheadings -o SIZE "/dev/$local_disk" 2>/dev/null || echo "?")
    local_model=$(lsblk --nodeps --noheadings -o MODEL "/dev/$local_disk" 2>/dev/null || echo "Desconhecido")
    echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_disk — ${BOLD}$local_size${NC} — $local_model"
done

echo ""
read -rp "$(echo -e "${BOLD}Selecione o disco [1-${#DISKS[@]}]:${NC} ")" disk_choice

if ! [[ "${disk_choice:-}" =~ ^[0-9]+$ ]] || [ "$disk_choice" -lt 1 ] || [ "$disk_choice" -gt ${#DISKS[@]} ]; then
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

case "${part_choice:-}" in
    1)
        echo ""
        echo -e "${RED}${BOLD}ATENÇÃO: TODOS os dados de $TARGET_DISK serão APAGADOS!${NC}"
        read -rp "$(echo -e "${BOLD}Tem certeza? Digite 'SIM' para confirmar:${NC} ")" confirm
        # Case-insensitive: aceita SIM, sim, Sim, etc.
        if [[ ! "${confirm:-}" =~ ^[sS][iI][mM]$ ]]; then
            error "Particionamento cancelado pelo usuário."
        fi

        RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
        if [ "${RAM_GB:-0}" -le 0 ]; then
            SWAP_SIZE="1G"
        elif [ "$RAM_GB" -le 8 ]; then
            SWAP_SIZE="${RAM_GB}G"
        else
            SWAP_SIZE="8G"
        fi
        info "Swap calculado: ${SWAP_SIZE} (RAM: ${RAM_GB}G)"

        sgdisk --zap-all "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao limpar tabela de partições."

        if [ "$BOOT_MODE" = "uefi" ]; then
            sgdisk -n 1:0:+1G -t 1:ef00 -c 1:"EFI" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar partição EFI."
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar partição swap."
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar partição root."
        else
            sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS boot" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar BIOS boot."
            sgdisk -n 2:0:+${SWAP_SIZE} -t 2:8200 -c 2:"Swap" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar partição swap."
            sgdisk -n 3:0:0 -t 3:8300 -c 3:"Root" "$TARGET_DISK" >> "$LOG_FILE" 2>&1 || error "Falha ao criar partição root."
        fi

        # Forçar kernel a reler tabela de partições e esperar
        partprobe "$TARGET_DISK" 2>/dev/null || true
        info "Aguardando partições aparecerem..."
        for _wait in $(seq 1 10); do
            if [[ "$TARGET_DISK" == *"nvme"* ]] || [[ "$TARGET_DISK" == *"mmcblk"* ]]; then
                [ -b "${TARGET_DISK}p3" ] && break
            else
                [ -b "${TARGET_DISK}3" ] && break
            fi
            sleep 1
        done

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
            local_info=$(lsblk -ln -o NAME,SIZE,FSTYPE "/dev/$local_part" 2>/dev/null | head -1)
            echo -e "  ${GREEN}[$((i+1))]${NC} /dev/$local_part — $local_info"
        done

        # ROOT
        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para ROOT? [1-${#PARTS[@]}]:${NC} ")" root_choice
        if ! [[ "${root_choice:-}" =~ ^[0-9]+$ ]] || [ "$root_choice" -lt 1 ] || [ "$root_choice" -gt ${#PARTS[@]} ]; then
            error "Opção inválida para ROOT."
        fi
        PART_ROOT="/dev/${PARTS[$((root_choice-1))]}"

        # SWAP
        echo ""
        read -rp "$(echo -e "${BOLD}Qual partição para SWAP? [1-${#PARTS[@]}, ou 0 para nenhuma]:${NC} ")" swap_choice
        if [ "${swap_choice:-0}" != "0" ]; then
            if ! [[ "$swap_choice" =~ ^[0-9]+$ ]] || [ "$swap_choice" -lt 1 ] || [ "$swap_choice" -gt ${#PARTS[@]} ]; then
                error "Opção inválida para SWAP."
            fi
            PART_SWAP="/dev/${PARTS[$((swap_choice-1))]}"
        else
            PART_SWAP=""
        fi

        # EFI
        if [ "$BOOT_MODE" = "uefi" ]; then
            echo ""
            read -rp "$(echo -e "${BOLD}Qual partição para EFI? [1-${#PARTS[@]}]:${NC} ")" efi_choice
            if ! [[ "${efi_choice:-}" =~ ^[0-9]+$ ]] || [ "$efi_choice" -lt 1 ] || [ "$efi_choice" -gt ${#PARTS[@]} ]; then
                error "Opção inválida para EFI."
            fi
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
    if [[ "${FORMAT_EFI:-n}" =~ ^[sS]$ ]]; then
        echo -e "  EFI:  ${BOLD}$PART_EFI${NC} → FAT32 (será formatada)"
    else
        echo -e "  EFI:  ${BOLD}$PART_EFI${NC} → manter existente (não formatar)"
    fi
fi

echo ""
read -rp "$(echo -e "${BOLD}Confirmar formatação? [s/N]:${NC} ")" fmt_confirm
if [[ ! "${fmt_confirm:-n}" =~ ^[sS]$ ]]; then
    error "Formatação cancelada pelo usuário."
fi

info "Formatando partições..."

mkfs.ext4 -F "$PART_ROOT" 2>&1 | tee -a "$LOG_FILE" || error "Falha ao formatar root."
success "Root formatado (ext4)."

if [ -n "$PART_SWAP" ]; then
    mkswap "$PART_SWAP" >> "$LOG_FILE" 2>&1 || error "Falha ao criar swap."
    swapon "$PART_SWAP" >> "$LOG_FILE" 2>&1 || error "Falha ao ativar swap."
    success "Swap ativado."
fi

if [ -n "$PART_EFI" ]; then
    if [[ "${FORMAT_EFI:-n}" =~ ^[sS]$ ]]; then
        mkfs.fat -F 32 "$PART_EFI" >> "$LOG_FILE" 2>&1 || error "Falha ao formatar EFI."
        success "EFI formatado (FAT32)."
    else
        success "EFI mantida sem formatar."
    fi
fi

# ============================================================
# 6. Montar partições
# ============================================================

info "Montando partições..."

mount "$PART_ROOT" /mnt || error "Falha ao montar root em /mnt."
success "Root montado em /mnt."

if [ -n "$PART_EFI" ]; then
    mount --mkdir "$PART_EFI" /mnt/boot || error "Falha ao montar EFI em /mnt/boot."
    success "EFI montado em /mnt/boot."

    # SEMPRE limpar arquivos Linux antigos da EFI antes do pacstrap
    # (evita "conflicting files" com intel-ucode.img, vmlinuz-*, etc.)
    # Preserva /mnt/boot/EFI/ onde ficam os bootloaders do Windows e outros SOs
    info "Limpando arquivos Linux antigos da partição EFI (se houver)..."
    rm -f /mnt/boot/vmlinuz-* 2>/dev/null || true
    rm -f /mnt/boot/initramfs-* 2>/dev/null || true
    rm -f /mnt/boot/intel-ucode.img 2>/dev/null || true
    rm -f /mnt/boot/amd-ucode.img 2>/dev/null || true
    rm -rf /mnt/boot/grub 2>/dev/null || true
    success "EFI limpa (bootloader Windows preservado)."
fi

# ============================================================
# 7. Configurar mirrors
# ============================================================

info "Configurando mirrors (Brasil)..."
if ! reflector --country Brazil --age 24 --protocol https --sort rate --save /etc/pacman.d/mirrorlist >> "$LOG_FILE" 2>&1; then
    warn "Reflector falhou para Brasil. Usando mirrors globais..."
    if ! reflector --age 24 --protocol https --sort rate --number 10 --save /etc/pacman.d/mirrorlist >> "$LOG_FILE" 2>&1; then
        warn "Reflector falhou completamente. Usando mirrorlist padrão da ISO."
    fi
fi
if [ ! -s /etc/pacman.d/mirrorlist ]; then
    error "mirrorlist está vazio. Verifique sua conexão com a internet."
fi
success "Mirrors configurados."

# ============================================================
# 8. Instalar sistema base
# ============================================================

# Esperar pacman-init.service terminar (evita erros de keyring/PGP)
info "Aguardando inicialização do keyring..."
systemctl is-active --wait pacman-init.service 2>/dev/null || true

# Sincronizar relógio (assinaturas PGP dependem de hora correta)
timedatectl set-ntp true 2>/dev/null || true
sleep 2

info "Instalando sistema base (pacstrap)... Isso pode levar alguns minutos."
if ! pacstrap -K /mnt base linux linux-firmware linux-headers \
    "$MICROCODE" networkmanager grub efibootmgr os-prober \
    git base-devel sudo zsh pciutils ntfs-3g 2>&1 | tee -a "$LOG_FILE"; then
    error "pacstrap falhou. Verifique o log acima."
fi
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
while [ -z "${INSTALL_USER:-}" ]; do
    echo -e "${RED}O nome do usuário não pode ser vazio.${NC}"
    read -rp "$(echo -e "${BOLD}Nome do usuário:${NC} ")" INSTALL_USER
done

echo -e "${BOLD}Senha do usuário ($INSTALL_USER):${NC}"
while true; do
    read -rsp "  Senha: " USER_PASS
    echo ""
    read -rsp "  Confirmar: " USER_PASS_CONFIRM
    echo ""
    if [ "${USER_PASS:-}" = "${USER_PASS_CONFIRM:-}" ] && [ -n "${USER_PASS:-}" ]; then
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
    if [ "${ROOT_PASS:-}" = "${ROOT_PASS_CONFIRM:-}" ] && [ -n "${ROOT_PASS:-}" ]; then
        break
    fi
    echo -e "${RED}Senhas não conferem ou vazias. Tente novamente.${NC}"
done

# ============================================================
# 11. Configurar via arch-chroot
# ============================================================

info "Configurando o sistema via chroot..."

# Timezone
arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$INSTALL_TIMEZONE" /etc/localtime || warn "Falha ao configurar timezone."
arch-chroot /mnt hwclock --systohc || warn "Falha ao configurar relógio."

# Locale
LOCALE_PREFIX="${INSTALL_LOCALE%%.*}"
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /mnt/etc/locale.gen
sed -i "s/^#${LOCALE_PREFIX}/${LOCALE_PREFIX}/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen 2>&1 | tee -a "$LOG_FILE" || warn "Falha no locale-gen."
echo "LANG=$INSTALL_LOCALE" > /mnt/etc/locale.conf
echo "KEYMAP=$INSTALL_KEYMAP" > /mnt/etc/vconsole.conf

# Hostname
echo "$INSTALL_HOSTNAME" > /mnt/etc/hostname

# Hosts
cat > /mnt/etc/hosts << HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${INSTALL_HOSTNAME}.localdomain ${INSTALL_HOSTNAME}
HOSTS

# Senha do root (printf evita problemas com caracteres especiais no echo)
printf '%s:%s\n' "root" "$ROOT_PASS" | arch-chroot /mnt chpasswd || warn "Falha ao definir senha do root."

# Criar usuário
arch-chroot /mnt useradd -m -G wheel -s /bin/zsh "$INSTALL_USER" || warn "Falha ao criar usuário."
printf '%s:%s\n' "$INSTALL_USER" "$USER_PASS" | arch-chroot /mnt chpasswd || warn "Falha ao definir senha do usuário."

# Configurar sudo (tenta dois padrões possíveis)
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers

# Habilitar serviços (sem --now, que falha no chroot)
arch-chroot /mnt systemctl enable NetworkManager 2>&1 | tee -a "$LOG_FILE" || warn "Falha ao habilitar NetworkManager."

success "Sistema configurado."

# ── GRUB ──

info "Instalando GRUB..."

if [ "$BOOT_MODE" = "uefi" ]; then
    # --removable instala em /EFI/BOOT/BOOTx64.EFI (fallback UEFI universal)
    # Necessário porque dentro do chroot o efivarfs pode não ser gravável,
    # impedindo o grub-install de criar entrada na NVRAM da UEFI
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable 2>&1 | tee -a "$LOG_FILE" || error "Falha ao instalar GRUB."
else
    arch-chroot /mnt grub-install --target=i386-pc "$TARGET_DISK" 2>&1 | tee -a "$LOG_FILE" || error "Falha ao instalar GRUB."
fi

# Habilitar os-prober (descomentar se existir, adicionar se não existir)
if grep -q "GRUB_DISABLE_OS_PROBER" /mnt/etc/default/grub 2>/dev/null; then
    sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' /mnt/etc/default/grub
else
    echo "GRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub
fi

arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 2>&1 | tee -a "$LOG_FILE" || warn "Falha no grub-mkconfig."
success "GRUB instalado e configurado."

info "Após o reboot, rode 'sudo grub-mkconfig -o /boot/grub/grub.cfg' para detectar Windows/outros SOs."

# ── Dotfiles + install.sh ──

info "Copiando dotfiles e executando install.sh..."

if [ -d /opt/dotfiles ]; then
    cp -r /opt/dotfiles "/mnt/home/${INSTALL_USER}/dotfiles"
    arch-chroot /mnt chown -R "${INSTALL_USER}:${INSTALL_USER}" "/home/${INSTALL_USER}/dotfiles"
    success "Dotfiles copiados para /home/${INSTALL_USER}/dotfiles."

    # NOPASSWD temporário para o install.sh poder usar sudo no chroot
    echo "${INSTALL_USER} ALL=(ALL:ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/99-install-nopasswd
    chmod 440 /mnt/etc/sudoers.d/99-install-nopasswd

    info "Executando install.sh (pós-instalação)..."
    arch-chroot /mnt runuser -u "$INSTALL_USER" -- /home/"$INSTALL_USER"/dotfiles/install.sh 2>&1 | tee -a "$LOG_FILE" || {
        warn "install.sh retornou erro. Verifique o log: $LOG_FILE"
        warn "Você pode rodar manualmente após o reboot: cd ~/dotfiles && ./install.sh"
    }

    # Remover NOPASSWD temporário (segurança)
    rm -f /mnt/etc/sudoers.d/99-install-nopasswd
else
    warn "/opt/dotfiles não encontrado na ISO."
    warn "Após o reboot, clone os dotfiles e rode ./install.sh manualmente."
fi

# Limpar variáveis de senha da memória
unset USER_PASS USER_PASS_CONFIRM ROOT_PASS ROOT_PASS_CONFIRM

# ============================================================
# 12. Finalizar
# ============================================================

# Desabilitar o cleanup automático (sucesso, não precisa desmontar no trap)
trap - EXIT

info "Finalizando..."

umount -R /mnt 2>/dev/null || true
swapoff -a 2>/dev/null || true

echo "" | tee -a "$LOG_FILE"
echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                                  ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║    Instalação concluída com sucesso!              ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}║                                                  ║${NC}" | tee -a "$LOG_FILE"
echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}" | tee -a "$LOG_FILE"
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
