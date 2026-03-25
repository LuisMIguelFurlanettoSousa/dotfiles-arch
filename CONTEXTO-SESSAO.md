# Contexto da Sessão — Arch Linux + Hyprland ISO Customizada

**Data:** 2026-03-23 a 2026-03-25
**Branch:** `feat/archiso-hyprland`
**Objetivo:** Criar ISO bootável do Arch Linux com Hyprland pré-configurado + instalador automatizado

---

## O que foi feito

### 1. ISO Customizada com Archiso
- Criada ISO bootável baseada no Arch Linux 2026.02.01 (kernel 6.18.7)
- Build funciona via Docker (qualquer distro) ou nativamente no Arch
- Comando: `cd archiso && sudo ./build.sh`
- ISO gerada em `/root/iso-out/`

### 2. Menu Live no Boot
- Auto-login como root no TTY1
- Menu interativo com 3 opções: Hyprland test drive, Instalar, Shell
- Hyprland no live roda como usuário temporário `live` (não pode rodar como root)
- Terminal do live é `foot` (ghostty é AUR, indisponível no live)

### 3. Instalador Completo (full-install.sh)
- Conexão Wi-Fi interativa com listagem de redes e 3 tentativas de senha
- Particionamento: automático (disco inteiro) ou manual (cfdisk)
- Proteção de EFI compartilhada (pergunta antes de formatar, preserva Windows)
- Limpeza de arquivos Linux antigos na EFI (evita conflito intel-ucode.img)
- Detecção automática de UEFI vs BIOS
- Detecção automática de CPU (intel-ucode vs amd-ucode)
- GRUB com `--removable` (funciona mesmo sem acesso à NVRAM no chroot)
- os-prober habilitado para detectar Windows/outros SOs
- Locale/keymap/timezone configuráveis com padrão pt_BR (aceita maiúsculo/minúsculo)
- Confirmação "SIM" case-insensitive
- NOPASSWD temporário para install.sh rodar no chroot
- ntfs-3g incluído no pacstrap (necessário para os-prober detectar Windows)
- pciutils incluído no pacstrap (necessário para lspci detectar GPU)
- Espera pacman-init.service antes do pacstrap
- Sincroniza relógio NTP antes do pacstrap
- /etc/hosts configurado automaticamente

### 4. install.sh (pós-instalação)
- Wi-Fi interativo com listagem de redes (nmcli ou iwctl)
- Sudo pede senha uma vez e mantém cache ativo (keepalive em background)
- Detecção de chroot: pula keyring/pacman-syu quando dentro do arch-chroot
- systemctl enable sem --now quando em chroot (--now falha sem systemd PID 1)
- wlogout movido de PACMAN_PKGS para AUR_PKGS (é AUR, não oficial)
- rofi adicionado aos pacotes (para wallpaper picker)

### 5. Seletor de Wallpaper
- Script: `hypr/.config/hypr/scripts/wallpaper-picker.sh`
- Atalho: `SUPER + W`
- Usa Rofi com preview de ícones
- Aplica wallpaper via swww com transição animada
- Wallpapers ficam em `~/Pictures/wallpapers/walls/`

### 6. Auto-start do Hyprland
- Arquivo: `zsh/.zlogin` (não .zprofile — .zlogin executa depois do .zshrc)
- Inicia Hyprland automaticamente no login do TTY1
- Não inicia em terminais dentro do Hyprland (verifica tty e WAYLAND_DISPLAY)

### 7. Aparência
- Ghostty: opacidade 0.75 (blur do Hyprland aparece atrás do terminal)
- Ghostty: fonte 14 (era 18, muito grande)
- Monitor: escala 1 (era auto, causava zoom)

---

## Problemas Conhecidos / Pendências

### Corrigidos
- EFI cleanup não funcionava (if ls com pipefail) → rm -f incondicional
- set -e + tee + pipefail causava falsos triggers → removido set -e
- Senhas com ":" quebravam chpasswd → usa printf
- grub-install não registrava entrada EFI no chroot → --removable adicionado
- nvidia-dkms falhava no build Docker → removido da ISO, install.sh instala no sistema final
- ISO antiga sendo gravada no pendrive → nome mudava com a data, dd usava nome hardcoded
- pacstrap falhava silenciosamente → saída visível na tela com tee

### Pendências (baixo risco)
- Cursor Bibata: pode dar erro no startup se bibata-cursor-theme não instalou (é AUR)
- Config do foot: terminal do live abre com tema padrão (sem customização)
- wlogout keybind (SUPER+SHIFT+Q): falha no live porque wlogout é AUR
- Validação de hostname/username: aceita caracteres inválidos (não causa crash)

---

## Estrutura dos Arquivos Principais

```
dotfiles/
├── install.sh                              # Pós-instalação (dotfiles + pacotes)
├── archiso/
│   ├── build.sh                            # Build ISO (Docker ou Arch nativo)
│   ├── build-native.sh                     # Lógica de build (chamado pelo build.sh)
│   ├── packages.x86_64                     # Pacotes extras da ISO
│   └── airootfs/
│       ├── etc/
│       │   ├── hostname                    # "archlive"
│       │   ├── locale.conf                 # pt_BR.UTF-8
│       │   ├── vconsole.conf               # br-abnt2
│       │   ├── locale.gen                  # pt_BR + en_US
│       │   └── systemd/system/getty@tty1.service.d/
│       │       └── autologin.conf          # Auto-login root no TTY1
│       ├── root/
│       │   └── .zlogin                     # Executa menu-live no login
│       └── usr/local/bin/
│           ├── menu-live                   # Menu interativo (3 opções)
│           ├── instalar-sistema            # Wrapper com aviso e confirmação
│           └── full-install.sh             # Instalação base completa
├── hypr/.config/hypr/
│   ├── hyprland.conf                       # Config principal (sources)
│   ├── conf/
│   │   ├── appearance.conf                 # Blur, gaps, bordas, animações
│   │   ├── keybinds.conf                   # Atalhos (inclui SUPER+W wallpaper)
│   │   ├── monitors.conf                   # Escala 1, resolução auto
│   │   ├── programs.conf                   # $terminal = ghostty
│   │   ├── startup.conf                    # swww, waybar, polkit, cursor
│   │   └── windowrules.conf                # Regras de janela
│   └── scripts/
│       ├── wallpaper-picker.sh             # Seletor de wallpaper (Rofi + swww)
│       └── toggle-compact.sh               # Toggle modo compacto
├── ghostty/.config/ghostty/config          # Opacidade 0.75, fonte 14
├── zsh/
│   ├── .zshrc                              # Zinit + plugins
│   └── .zlogin                             # Auto-start Hyprland no TTY1
├── waybar/.config/waybar/                  # Barra de status
├── wofi/.config/wofi/                      # Launcher
├── wlogout/.config/wlogout/                # Menu logout
└── wallpapers/default.jpg                  # Wallpaper padrão
```

---

## Comandos Úteis no Arch

```bash
# Atualizar dotfiles
cd ~/dotfiles && git pull && stow --restow zsh hypr ghostty waybar wofi wlogout gtk-3.0

# Reiniciar Hyprland sem reboot
SUPER + M  (ou: hyprctl dispatch exit)

# Trocar wallpaper
SUPER + W

# Instalar pacotes que faltaram
./install.sh

# Regenerar GRUB (detectar Windows/Ubuntu)
sudo grub-mkconfig -o /boot/grub/grub.cfg
```

---

## Configuração do GRUB no Ubuntu

Para o Arch aparecer no GRUB do Ubuntu, foi adicionada uma entrada manual em `/etc/grub.d/40_custom`:

```
menuentry 'Arch Linux + Hyprland' --class arch --class gnu-linux --class os {
    insmod part_gpt
    insmod fat
    search --no-floppy --fs-uuid --set=root 10E3-DCCF
    linux /vmlinuz-linux root=UUID=d58efa18-0eb8-432d-8f99-b596b67a6209 rw loglevel=3 quiet
    initrd /intel-ucode.img /initramfs-linux.img
}
```

Nota: o os-prober do Ubuntu gerava o caminho do initrd errado (`/boot/initramfs-linux.img` em vez de `/initramfs-linux.img`), causando kernel panic. A entrada manual corrige isso.

---

## Discos do Computador

```
nvme0n1 (476.9G Micron)  → Ubuntu
nvme1n1 (931.5G Kingston) → Windows (p8: 454.6G) + Arch (p3: 417.1G)
  p1: 260M EFI (compartilhada Windows/Arch)
  p3: 417.1G → Arch Linux (root)
  p5: 3.7G → Swap
  p8: 454.6G → Windows ativo
```
