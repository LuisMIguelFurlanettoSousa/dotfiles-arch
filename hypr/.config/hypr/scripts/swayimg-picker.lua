-- Configuração do swayimg para o wallpaper picker
-- Recarrega a imagem ao receber SIGUSR1 (quando a seleção muda no Rofi)

-- Esconder texto informativo (nome do arquivo, resolução, etc.)
swayimg.viewer.set_text("")

-- Desabilitar keybindings padrão para evitar interação acidental
swayimg.viewer.bind_reset()

-- Bind: ao receber SIGUSR1, recarregar a imagem do disco
swayimg.viewer.on_signal("USR1", function()
    swayimg.viewer.reload()
    swayimg.viewer.reset()
end)
