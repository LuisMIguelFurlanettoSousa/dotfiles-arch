<h1 align="center">Hyprland Dotfiles</h1>
<p align="center"><strong>Arch Linux + Hyprland configurado em um comando. Clone, instale, reboot.</strong></p>

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

## Quick Start

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
├── install.sh              # Script de instalação automatizada
├── .stowrc                 # Config do stow (target = ~)
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
