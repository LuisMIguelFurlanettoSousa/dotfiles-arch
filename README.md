# dotfiles — Hyprland para Arch Linux

Fork do [maxhu08/dotfiles](https://github.com/maxhu08/dotfiles) com instalação automatizada.

## Screenshot

<!-- TODO: adicionar screenshot -->

## Instalação

Em um Arch Linux com `base`, `linux`, `linux-firmware`, usuário com `sudo` e internet:

```bash
sudo pacman -S git
git clone https://github.com/LuisMIguelFurlanettoSousa/dotfiles
cd dotfiles
./install.sh
sudo reboot
```

Pronto. O script:

- Detecta sua GPU (NVIDIA / AMD / Intel) e instala os drivers
- Instala todos os pacotes necessários (pacman + yay)
- Aplica todas as configurações via stow
- Configura Zsh como shell padrão
- Habilita NetworkManager e Bluetooth

## O que está incluído

| Componente | Programa |
|---|---|
| Window Manager | Hyprland |
| Barra | Waybar |
| Terminal | Ghostty |
| Launcher | Wofi |
| File Manager | Nemo |
| Lock Screen | Hyprlock |
| Logout | Wlogout |
| Wallpaper | swww |
| Shell | Zsh (com zinit) |
| Editor | Neovim (NvChad) + VS Code |
| Night Mode | Hyprsunset |

## Atalhos principais

| Atalho | Ação |
|---|---|
| `SUPER + Enter` | Terminal |
| `SUPER + Space` | Menu (Wofi) |
| `SUPER + E` | Gerenciador de arquivos |
| `SUPER + C` ou `Q` | Fechar janela |
| `SUPER + F` | Fullscreen |
| `SUPER + V` | Floating |
| `SUPER + S` | Screenshot (monitor) |
| `SUPER + SHIFT + S` | Screenshot (área) |
| `SUPER + SHIFT + L` | Lock screen |
| `SUPER + SHIFT + Q` | Menu de logout |
| `SUPER + 1-0` | Trocar workspace |
| `SUPER + SHIFT + 1-0` | Mover janela para workspace |
| `SUPER + H/J/K/L` | Navegar janelas (vim-style) |

## Créditos

Baseado no [maxhu08/dotfiles](https://github.com/maxhu08/dotfiles).
