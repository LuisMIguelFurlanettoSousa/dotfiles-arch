# Preview Dinâmico no Seletor de Wallpaper

## Problema

O seletor de wallpaper (Super+W) exibe no painel esquerdo do Rofi um preview estático do wallpaper **atual** via `background-image` no tema `.rasi`. O usuário quer ver o preview do wallpaper que está **selecionando/navegando**, não o atual.

O Rofi não suporta atualização dinâmica de `background-image` no tema — a imagem é carregada uma vez ao abrir.

## Solução

Usar o `swayimg` (visualizador Wayland-nativo) como janela flutuante de preview ao lado do Rofi, atualizada em tempo real via `-on-selection-changed` do Rofi 2.0.

## Arquitetura

```
Super+W
  |
  v
wallpaper-picker.sh
  |- 1. Inicia swayimg (janela flutuante, posição esquerda)
  |- 2. Abre Rofi com -on-selection-changed
  |     | (a cada mudança de seleção)
  |     v
  |     update-wallpaper-preview.sh <nome>
  |       -> swayimgctl open <caminho da imagem>
  |- 3. Usuário confirma -> aplica wallpaper via swww
  '- 4. Fecha swayimg ao sair do Rofi
```

## Arquivos Modificados

### 1. `wallpaper-picker.sh` (reescrito)

- Abre `swayimg` em background mostrando o primeiro wallpaper da lista
- Passa `-on-selection-changed` ao Rofi apontando para o script de update
- Fecha `swayimg` quando o Rofi fechar (seleção ou ESC)

### 2. `wallpaper-preview.sh` (reescrito)

- Recebe o nome do wallpaper selecionado
- Envia ao `swayimg` o comando para trocar a imagem via IPC (`swayimgctl`)

### 3. `wallpaper-picker.rasi` (simplificado)

- Remove o `imagebox` (preview estático via `background-image`)
- Layout passa a ser só a `listbox` (busca + lista de wallpapers)
- Janela redimensionada para compensar a remoção do painel esquerdo

### 4. `windowrules.conf` (adição)

- Regra para `swayimg`: flutuante, tamanho fixo, posição à esquerda do Rofi, sem foco

## Dependências

- **swayimg** — pacote `extra/swayimg` (497 KiB download, ~1 MiB instalado)
- Já disponível no repositório `extra` do Arch Linux

## Fluxo do Usuário

1. Pressiona `Super+W`
2. Abre Rofi à direita + janela `swayimg` à esquerda mostrando o primeiro wallpaper
3. Ao navegar na lista (setas/teclado), o preview atualiza em tempo real
4. Confirma → aplica o wallpaper; ou ESC → cancela
5. Ambos os casos fecham o `swayimg`
