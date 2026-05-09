# Tuning de sistema — Arch Linux

Configurações de performance aplicadas em `/etc/` (fora do escopo do Stow).
Esses arquivos **não são symlinks vivos** — são copiados via `install-system.sh`.

## O que é aplicado

| # | Config | Arquivo | Efeito |
|---|--------|---------|--------|
| 1 | CPU governor `performance` permanente | `etc/default/cpupower` | CPU sempre responsiva, inclusive na bateria. Custa autonomia. |
| 2 | `systemd-oomd` ativo | (só `systemctl enable`) | Mata processo problemático antes do swap thrashing travar a máquina inteira. |
| 3 | `vm.swappiness=10` + `vm.vfs_cache_pressure=50` | `etc/sysctl.d/99-perf.conf` | Kernel evita paginar pra swap em desktops com bastante RAM e mantém metadata de filesystem em cache. |
| 4 | ZRAM (zstd, metade da RAM) | `etc/systemd/zram-generator.conf` | Swap comprimido em RAM (PRIO 100), antes do swapfile em disco (PRIO -1). |

## Como aplicar

```bash
sudo bash ~/dotfiles/system/install-system.sh
```

O `install.sh` master também invoca esse script automaticamente na seção 13.5.

### Opções

- `--no-start` — habilita serviços sem iniciar agora (usado durante chroot do archiso).

## Como reverter

```bash
# 1. CPU governor
sudo systemctl disable --now cpupower.service
sudo pacman -Rns cpupower

# 2. systemd-oomd
sudo systemctl disable --now systemd-oomd.service

# 3. sysctl
sudo rm /etc/sysctl.d/99-perf.conf
sudo sysctl --system

# 4. ZRAM
sudo systemctl stop dev-zram0.swap
sudo pacman -Rns zram-generator
sudo rm /etc/systemd/zram-generator.conf
```

## Por que cada decisão

### Por que `performance` permanente em vez de `auto-cpufreq`

`auto-cpufreq` alterna `powersave`/`performance` baseado em AC/bateria + carga. É o
padrão "inteligente". Optei pelo modo fixo porque o `intel_pstate` em `powersave`
demora dezenas a centenas de ms pra acordar quando há carga súbita — sensação de
"travada" quando se abre IDE/Chrome/etc. Custo aceito: ~15-25% menos autonomia.

### Por que `swappiness=10` e não `0` ou `1`

Valor `0` desativa swap exceto em emergência crítica — pode causar OOM kill em vez de
paginar páginas frias. `10` mantém swap como rede de segurança ativa, mas o kernel
prefere reclamar page cache antes. Para desktop com 16+ GiB de RAM, é o sweet spot.

### Por que ZRAM com `zstd`, não `lz4`

`lz4` é mais rápido na compressão; `zstd` comprime ~30% melhor com CPU
moderno fazendo a descompressão em microssegundos. Para zram (que troca tempo
de CPU por economia de RAM), zstd ganha.

### Por que zram = metade da RAM

Default razoável recomendado pela documentação do `zram-generator`. Em CPUs
modernos com compressão zstd ~3:1, isso significa potencialmente 1.5x mais
"memória virtual" antes de tocar no SSD. Ir além tem retorno decrescente.
