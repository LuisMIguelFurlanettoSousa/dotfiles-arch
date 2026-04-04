<h1 align="center">Hyprland Dotfiles</h1>
<p align="center"><strong>Arch Linux + Hyprland do zero. ISO bootável ou instalação em um comando.</strong></p>

<p align="center">
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat&logo=arch-linux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-58E1FF?style=flat&logo=wayland&logoColor=white" alt="Hyprland"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licença-MIT-green" alt="License"></a>
  <a href="https://github.com/LuisMIguelFurlanettoSousa/dotfiles-arch/stargazers"><img src="https://img.shields.io/github/stars/LuisMIguelFurlanettoSousa/dotfiles?style=flat" alt="Stars"></a>
</p>

<p align="center">
  <!-- Substitua por um screenshot real do seu desktop -->
  <img src="https://raw.githubusercontent.com/LuisMIguelFurlanettoSousa/dotfiles/main/.github/preview.png" alt="Preview do desktop Hyprland" width="800">
</p>

---

## Contents

### 🖥️ Desktop Environment

| Config | Descrição |
|--------|-----------|
| [hyprland](hypr/) | Compositor Wayland — keybinds, animações, workspace rules, scroller layout |
| [hypridle](hypr/) | Gerenciamento de idle — dim, lock, backlight, suspend |
| [hyprlock](hypr/) | Tela de bloqueio |
| [wlogout](wlogout/) | Menu de logout/shutdown |
| [waybar](waybar/) | Barra de status customizável |
| [rofi](rofi/) | App launcher e seletor de wallpaper |
| [wofi](wofi/) | App launcher alternativo para Wayland |
| [swaync](swaync/) | Central de notificações |

### 🛠️ Terminal & Shell

| Config | Descrição |
|--------|-----------|
| [ghostty](ghostty/) | Terminal GPU-accelerated |
| [kitty](kitty/) | Terminal GPU-accelerated |
| [alacritty](alacritty/) | Terminal GPU-accelerated |
| [tmux](tmux/) | Multiplexador de terminal com plugins |
| [zsh](zsh/) | Shell com zinit + syntax highlighting + fzf-tab + modo vi |

### 🎨 Aparência

| Config | Descrição |
|--------|-----------|
| [gtk-3.0](gtk-3.0/) | Tema GTK escuro (Materia + Papirus) |
| [wallpapers](wallpapers/) | Wallpaper padrão |
| [picom](picom/) | Compositor para X11 — transparência, blur, sombras |

### 💻 Editores

| Config | Descrição |
|--------|-----------|
| [nvim](nvim/) | Neovim com NvChad |
| [vscode](vscode/) | Settings e keybindings do VS Code |

### 🎵 Mídia

| Config | Descrição |
|--------|-----------|
| [spicetify](spicetify/) | Theming do Spotify |

### 📊 Sistema & Utilitários

| Config | Descrição |
|--------|-----------|
| [git](git/) | Configuração global do Git |
| [custom-scripts](custom-scripts/) | Scripts utilitários personalizados |

---

## Instalação

Duas formas de usar este projeto:

### Opção A: ISO Bootável (recomendado para quem NÃO tem Arch instalado)

Crie uma ISO customizada com Arch Linux + Hyprland pré-configurado. Boota pelo pendrive, testa o Hyprland ao vivo, e instala no disco com um comando.

**Pré-requisitos:** Docker instalado (qualquer distro Linux) ou Arch Linux com `archiso`.

```bash
# 1. Clonar o repositório
git clone https://github.com/LuisMIguelFurlanettoSousa/dotfiles-arch
cd dotfiles

# 2. Buildar a ISO (~10-30 min, baixa ~1.8GB de pacotes)
cd archiso
sudo ./build.sh

# 3. Gravar no pendrive (substitua /dev/sdX pelo seu USB)
# Use 'lsblk' para identificar o dispositivo correto
# A ISO estará em /root/iso-out/ — confira o nome exato com: sudo ls /root/iso-out/
sudo dd bs=4M if=/root/iso-out/archlinux-hyprland-*.iso of=/dev/sdX conv=fsync oflag=direct status=progress

# 4. Bootar pelo pendrive e seguir o menu interativo
```

> **Importante:** O comando `dd` apaga tudo no pendrive. Certifique-se de selecionar o dispositivo correto.

<details>
<summary><strong>Como dar boot pelo pendrive</strong></summary>

1. Desligue o computador e insira o pendrive
2. Ligue o computador e entre no menu de boot:
   - **Acer/ASUS/Samsung:** pressione `F2` ou `DEL` repetidamente ao ligar
   - **Dell:** pressione `F12`
   - **HP:** pressione `F9` ou `ESC`
   - **Lenovo:** pressione `F12` ou `Fn + F12`
   - **MSI:** pressione `DEL`
   - Se nenhuma funcionar, procure "boot menu key + modelo do seu PC" no Google
3. No menu de boot, selecione o pendrive USB (pode aparecer como "USB", "UEFI: nome-do-pendrive" ou o nome do fabricante do pendrive)
4. Se o PC não reconhecer o pendrive, entre na BIOS/UEFI e **desabilite Secure Boot**

> **Dica:** Em notebooks com Windows, pode ser necessário desabilitar "Fast Startup" nas configurações de energia do Windows antes de reiniciar.

</details>

<details>
<summary><strong>O que acontece ao bootar o pendrive</strong></summary>

```
╔══════════════════════════════════════════════╗
║     Arch Linux + Hyprland — Live USB         ║
║                                              ║
║  [1] Iniciar Hyprland (test drive)           ║
║  [2] Instalar no disco                       ║
║  [3] Shell                                   ║
╚══════════════════════════════════════════════╝
```

- **Opção 1** — Testa o Hyprland ao vivo sem instalar nada. Ideal para ver se tudo funciona no seu hardware.
- **Opção 2** — Instalação guiada: particiona o disco (automático ou manual), instala o Arch + Hyprland + dotfiles. Suporta dual-boot com Windows.
- **Opção 3** — Shell para uso manual.

**Wi-Fi:** Se não tiver cabo ethernet, o instalador lista as redes Wi-Fi disponíveis e pede a senha.

**Dual-boot:** O GRUB com `os-prober` detecta Windows automaticamente. Na partição EFI, o instalador pergunta se quer formatar ou manter (preservando o boot do Windows).

</details>

<details>
<summary><strong>Layout de partições recomendado para dual-boot</strong></summary>

Se você tem Windows e quer instalar o Arch ao lado:

| Partição | Uso | Formatar? |
|----------|-----|-----------|
| EFI existente (ex: 260M) | Compartilhada com Windows | **NÃO** |
| Partição livre (ex: 40G+) | Root do Arch (/) | Sim (ext4) |
| Partição livre (ex: 4G+) | Swap | Sim |

Na opção 2 do instalador, escolha "Particionar manualmente" e selecione as partições corretas.

</details>

### Opção B: Apenas dotfiles (para quem JÁ tem Arch instalado)

```bash
# 1. Instalar git (se não tiver)
sudo pacman -S git

# 2. Clonar e rodar (NÃO use sudo no install.sh)
git clone https://github.com/LuisMIguelFurlanettoSousa/dotfiles-arch
cd dotfiles
chmod +x install.sh
./install.sh

# 3. Reiniciar
sudo reboot
```

> **Pré-requisitos:** Arch Linux com `base`, `linux`, `linux-firmware`, usuário com `sudo` e internet (Wi-Fi ou cabo).
> O script pede a senha sudo uma vez e conecta ao Wi-Fi se necessário.

## Requisitos mínimos

| Requisito | Mínimo |
|---|---|
| CPU | x86_64 (qualquer processador 64-bit) |
| RAM | 2 GB (recomendado 4 GB+) |
| Disco | 20 GB livres (recomendado 40 GB+) |
| GPU | NVIDIA, AMD ou Intel (drivers instalados automaticamente) |
| Pendrive | 4 GB+ (para a ISO bootável) |
| Internet | Necessária para instalação (Wi-Fi ou cabo ethernet) |

## Features

- **Instalação automatizada** — um script faz tudo, sem perguntas
- **Detecção automática de GPU** — NVIDIA, AMD ou Intel, com drivers corretos
- **Monitores plug-and-play** — qualquer monitor funciona sem configuração manual
- **Gerenciamento via stow** — configs versionadas com symlinks, fácil de manter
- **Zsh turbinado** — zinit + syntax highlighting + autosuggestions + fzf-tab + modo vi
- **Waybar customizado** — CPU, RAM, áudio, bluetooth, rede, night mode, updates
- **Screenshots inteligentes** — fullscreen ou área, com cópia automática para clipboard
- **Lock screen elegante** — Hyprlock com blur e relógio
- **Night mode integrado** — Hyprsunset toggle via Waybar
- **Idempotente** — rode `./install.sh` quantas vezes quiser sem quebrar nada

## Atalhos

### Geral

| Atalho | Ação |
|--------|------|
| `SUPER + Enter` | Terminal |
| `SUPER + Space` | Launcher (menu) |
| `SUPER + R` | Launcher (alias) |
| `SUPER + E` | Gerenciador de arquivos |
| `SUPER + W` | Seletor de wallpaper |
| `SUPER + SHIFT + W` | Seletor de tema do lockscreen |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + Q` | Menu de logout (wlogout) |
| `SUPER + SHIFT + B` | Recarregar Waybar |
| `SUPER + SHIFT + CTRL + B` | Toggle modo compacto (sem gaps/bordas) |

### Janelas

| Atalho | Ação |
|--------|------|
| `SUPER + C` | Fechar janela |
| `SUPER + Q` | Fechar janela |
| `SUPER + V` | Toggle floating |
| `SUPER + F` | Maximizar (mantém waybar e gaps) |
| `SUPER + SHIFT + F` | Fullscreen real |
| `SUPER + P` | Pseudo (dwindle) |
| `SUPER + T` | Toggle split (dwindle) |
| `SUPER + SHIFT + T` | Reabrir última janela fechada |
| `SUPER + H/J/K/L` | Navegar janelas (vim-style) |
| `SUPER + Setas` | Navegar janelas (fullscreen → troca workspace) |
| `SUPER + SHIFT + Setas` | Trocar janela de posição |
| `SUPER + CTRL + Setas` | Redimensionar janela |
| `SUPER + LMB` | Mover janela com mouse |
| `SUPER + RMB` | Redimensionar janela com mouse |

### Workspaces

| Atalho | Ação |
|--------|------|
| `SUPER + 1-0` | Trocar workspace |
| `SUPER + SHIFT + 1-0` | Mover janela para workspace |
| `SUPER + Scroll` | Navegar workspaces com scroll |

### Screenshots

| Atalho | Ação |
|--------|------|
| `SUPER + S` | Screenshot do monitor ativo (copia para clipboard) |
| `SUPER + SHIFT + S` | Screenshot de área selecionada (copia para clipboard) |

### Mídia

| Atalho | Ação |
|--------|------|
| `XF86AudioRaiseVolume` | Volume + |
| `XF86AudioLowerVolume` | Volume − |
| `XF86AudioMute` | Toggle mute |

## O que o install.sh faz

```
./install.sh
  ├── Valida pré-requisitos (Arch Linux, internet, usuário não-root)
  ├── Conecta ao Wi-Fi (se necessário)
  ├── Atualiza o sistema (pacman -Syu)
  ├── Habilita repositório multilib
  ├── Instala yay (AUR helper)
  ├── Detecta GPU e instala drivers
  │     ├── NVIDIA → nvidia-open-dkms + variáveis de ambiente
  │     ├── AMD → mesa + vulkan-radeon
  │     └── Intel → mesa + vulkan-intel
  ├── Instala ~50 pacotes (pacman + yay)
  ├── Faz backup das configs existentes
  ├── Aplica configs via stow (symlinks)
  ├── Configura Zsh como shell padrão
  ├── Instala Tmux Plugin Manager (TPM)
  ├── Cria diretórios necessários
  ├── Copia wallpaper padrão
  ├── Habilita serviços (NetworkManager, Bluetooth, PipeWire)
  ├── Valida instalação (pacotes críticos + symlinks)
  └── Pronto! Só dar reboot.
```

## Estrutura

```
dotfiles/
├── install.sh              # Script de pós-instalação (dotfiles + pacotes)
├── .stowrc                 # Config do stow (target = ~)
├── archiso/                # ISO bootável customizada
│   ├── build.sh            # Buildar ISO (Docker ou Arch nativo)
│   ├── build-native.sh     # Build interno (chamado pelo build.sh)
│   ├── packages.x86_64     # Pacotes extras da ISO
│   └── airootfs/           # Sistema de arquivos da ISO live
│       └── usr/local/bin/
│           ├── menu-live          # Menu interativo no boot
│           ├── instalar-sistema   # Wrapper do instalador
│           └── full-install.sh    # Instalação completa do Arch
├── hypr/                   # Hyprland, Hyprlock, Hypridle, scripts
├── waybar/                 # Barra de status + scripts
├── wofi/                   # Launcher config + estilo
├── rofi/                   # Launcher alternativo + wallpaper picker
├── wlogout/                # Menu de logout + ícones
├── ghostty/                # Config do terminal Ghostty
├── kitty/                  # Config do terminal Kitty
├── swaync/                 # Central de notificações
├── zsh/                    # .zshrc com zinit e prompt custom
├── tmux/                   # Multiplexador de terminal + plugins
├── git/                    # Configuração global do Git
├── nvim/                   # Neovim com NvChad
├── vscode/                 # Settings e keybindings do VS Code
├── gtk-3.0/                # Tema GTK escuro
└── wallpapers/             # Wallpaper padrão
```

## Personalização

As configs são gerenciadas com [GNU Stow](https://www.gnu.org/software/stow/). Cada pasta na raiz replica a estrutura de `$HOME`:

```bash
# Reaplicar configs após editar
cd ~/dotfiles
stow --restow hypr waybar

# Adicionar nova config
mkdir -p nova-app/.config/nova-app
# edite os arquivos...
stow nova-app
```

## FAQ

<details>
<summary><strong>Preciso estar no Arch Linux para buildar a ISO?</strong></summary>

Não. O `build.sh` detecta o sistema automaticamente. No Ubuntu, Fedora ou qualquer outra distro, ele usa Docker para buildar. Só precisa ter Docker instalado (`sudo apt install docker.io` no Ubuntu).
</details>

<details>
<summary><strong>Posso fazer dual-boot com Windows?</strong></summary>

Sim. Na instalação, escolha "Particionar manualmente" e selecione uma partição livre para o Arch. Quando perguntado sobre a EFI, responda "N" para não formatar (preserva o boot do Windows). O GRUB detecta o Windows automaticamente.
</details>

<details>
<summary><strong>E se eu tiver NVIDIA?</strong></summary>

O `install.sh` detecta a GPU automaticamente e instala os drivers corretos (`nvidia-dkms`). A ISO live inclui drivers NVIDIA, AMD e Intel para funcionar em qualquer hardware.
</details>

<details>
<summary><strong>Funciona sem internet?</strong></summary>

A ISO boota sem internet (opção 1 — test drive funciona offline). Mas a instalação no disco (opção 2) precisa de internet para baixar pacotes. O instalador oferece conexão Wi-Fi com listagem de redes se não tiver cabo ethernet.
</details>

<details>
<summary><strong>Posso rodar o install.sh sem a ISO?</strong></summary>

Sim. Se você já tem Arch Linux instalado, clone o repo e rode `./install.sh` direto. A ISO é apenas para quem quer instalar o Arch do zero.
</details>

## Contributing

Contribuições são bem-vindas! Veja [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes.

## Licença

Este projeto está sob a licença [MIT](LICENSE).

## Créditos

Baseado no [maxhu08/dotfiles](https://github.com/maxhu08/dotfiles).

---

<p align="center">
  Achou útil? Deixe uma ⭐ para apoiar o projeto!
</p>
