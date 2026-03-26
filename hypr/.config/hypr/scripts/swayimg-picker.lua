-- Configuração do swayimg para o wallpaper picker
-- Modo limpo: sem texto, sem keybindings

-- Esconder texto informativo (nome do arquivo, resolução, etc.)
swayimg.viewer.set_text("topleft", {})
swayimg.viewer.set_text("topright", {})
swayimg.viewer.set_text("bottomleft", {})
swayimg.viewer.set_text("bottomright", {})

-- Desabilitar keybindings padrão para evitar interação acidental
swayimg.viewer.bind_reset()
