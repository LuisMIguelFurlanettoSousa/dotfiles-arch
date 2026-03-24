# Correções para Release Público — Archiso Hyprland

**Data:** 2026-03-24
**Status:** Aprovado
**Branch:** `feat/archiso-hyprland`

## Alterações

### 1. Fix wlogout no install.sh
Mover `wlogout` de `PACMAN_PKGS` para `AUR_PKGS`. É AUR, não oficial.

### 2. Keymap/Locale/Timezone configurável
No `full-install.sh`, perguntar antes de hardcodar:
- Padrão: pt_BR.UTF-8, br-abnt2, America/Sao_Paulo
- Pergunta: "Manter configuração padrão (pt_BR, teclado ABNT2)? [S/n]"
- Se "n": perguntar timezone, locale e keymap
- Também perguntar keymap no boot do live (passo 2)

### 3. README para público geral
Reescrever README.md com instruções de build, gravação no USB e instalação.

## Arquivos

| Arquivo | Ação |
|---------|------|
| `install.sh` | Mover wlogout de PACMAN_PKGS para AUR_PKGS |
| `archiso/airootfs/usr/local/bin/full-install.sh` | Locale/keymap/timezone configurável |
| `README.md` | Reescrever para público geral |
