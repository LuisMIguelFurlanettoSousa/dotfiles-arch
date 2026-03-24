<h1 align="center">Hyprland Dotfiles</h1>
<p align="center"><strong>Arch Linux + Hyprland do zero. ISO bootável ou instalação em um comando.</strong></p>

<p align="center">
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Arch_Linux-1793D1?style=flat&logo=arch-linux&logoColor=white" alt="Arch Linux"></a>
  <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-58E1FF?style=flat&logo=wayland&logoColor=white" alt="Hyprland"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/licença-MIT-green" alt="License"></a>
  <a href="https://github.com/LuisMIguelFurlanettoSousa/dotfiles/stargazers"><img src="https://img.shields.io/github/stars/LuisMIguelFurlanettoSousa/dotfiles?style=flat" alt="Stars"></a>
</p>

<p align="center">
  <!-- Substitua por um screenshot real do seu desktop -->
  <img src="https://raw.githubusercontent.com/LuisMIguelFurlanettoSousa/dotfiles/main/.github/preview.png" alt="Preview do desktop Hyprland" width="800">
</p>

---

## Instalação

Duas formas de usar este projeto:

### Opção A: ISO Bootável (recomendado para quem NÃO tem Arch instalado)

Crie uma ISO customizada com Arch Linux + Hyprland pré-configurado. Boota pelo pendrive, testa o Hyprland ao vivo, e instala no disco com um comando.

**Pré-requisitos:** Docker instalado (qualquer distro Linux) ou Arch Linux com `archiso`.

```bash
# 1. Clonar o repositório
git clone https://github.com/LuisMIguelFurlanettoSousa/dotfiles
cd dotfiles

# 2. Buildar a ISO (~10-30 min, baixa ~1.8GB de pacotes)
cd archiso
sudo ./build.sh

# 3. Gravar no pendrive (substitua /dev/sdX pelo seu USB)
# Use 'lsblk' para identificar o dispositivo correto
sudo dd bs=4M if=/root/iso-out/archlinux-hyprland-*.iso of=/dev/sdX conv=fsync oflag=direct status=progress

# 4. Bootar pelo pendrive e seguir o menu interativo
```

> **Importante:** O comando `dd` apaga tudo no pendrive. Certifique-se de selecionar o dispositivo correto.

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
sudo pacman -S git
git clone https://github.com/LuisMIguelFurlanettoSousa/dotfiles
cd dotfiles
./install.sh
sudo reboot
```

> **Pré-requisitos:** Arch Linux com `base`, `linux`, `linux-firmware`, usuário com `sudo` e internet.

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

## Stack

| Componente | Programa | Descrição |
|---|---|---|
| Window Manager | [Hyprland](https://hyprland.org) | Compositor Wayland com animações e tiling |
| Barra | [Waybar](https://github.com/Alexays/Waybar) | Barra de status customizável |
| Terminal | [Ghostty](https://ghostty.org) | Terminal GPU-accelerated |
| Launcher | [Wofi](https://hg.sr.ht/~scoopta/wofi) | Application launcher para Wayland |
| File Manager | [Nemo](https://github.com/linuxmint/nemo) | Gerenciador de arquivos GTK |
| Lock Screen | [Hyprlock](https://github.com/hyprwm/hyprlock) | Tela de bloqueio para Hyprland |
| Logout | [Wlogout](https://github.com/ArtsyMacaw/wlogout) | Menu de logout/shutdown |
| Wallpaper | [swww](https://github.com/LGFae/swww) | Daemon de wallpaper com transições |
| Shell | [Zsh](https://www.zsh.org) + zinit | Shell com plugins e prompt customizado |
| Editor | [Neovim](https://neovim.io) (NvChad) + [VS Code](https://code.visualstudio.com) | Editores de código |
| Night Mode | [Hyprsunset](https://github.com/hyprwm/hyprsunset) | Filtro de luz azul |
| Cursor | [Bibata](https://github.com/ful1e5/Bibata_Cursor) | Tema de cursor moderno |
| GTK Theme | [Materia](https://github.com/nana-4/materia-theme) + [Papirus](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme) | Tema escuro com ícones |

## Atalhos

| Atalho | Ação |
|---|---|
| `SUPER + Enter` | Terminal |
| `SUPER + Space` | Launcher (Wofi) |
| `SUPER + E` | Gerenciador de arquivos |
| `SUPER + C` ou `Q` | Fechar janela |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Floating |
| `SUPER + S` | Screenshot (monitor ativo) |
| `SUPER + SHIFT + S` | Screenshot (área selecionada) |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + Q` | Menu de logout |
| `SUPER + 1-0` | Trocar workspace |
| `SUPER + SHIFT + 1-0` | Mover janela para workspace |
| `SUPER + H/J/K/L` | Navegar janelas (vim-style) |
| `SUPER + SHIFT + CTRL + B` | Toggle modo compacto (sem gaps/bordas) |

## O que o install.sh faz

```
./install.sh
  ├── Valida pré-requisitos (Arch Linux, internet, usuário não-root)
  ├── Atualiza o sistema (pacman -Syu)
  ├── Instala yay (AUR helper)
  ├── Detecta GPU e instala drivers
  │     ├── NVIDIA → nvidia-dkms + variáveis de ambiente
  │     ├── AMD → mesa + vulkan-radeon
  │     └── Intel → mesa + vulkan-intel
  ├── Instala ~40 pacotes (pacman + yay)
  ├── Remove configs conflitantes
  ├── Aplica configs via stow (symlinks)
  ├── Configura Zsh como shell padrão
  ├── Cria diretórios necessários
  ├── Copia wallpaper padrão
  ├── Habilita serviços (NetworkManager, Bluetooth, PipeWire)
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
├── hypr/                   # Hyprland, Hyprlock, scripts
├── waybar/                 # Barra de status + scripts
├── wofi/                   # Launcher config + estilo
├── wlogout/                # Menu de logout + ícones
├── ghostty/                # Config do terminal
├── zsh/                    # .zshrc com zinit e prompt custom
├── nvim/                   # Neovim com NvChad
├── vscode/                 # Settings e keybindings
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
