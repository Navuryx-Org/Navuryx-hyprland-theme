hl.window_rule({ name = "float-dialogs", match = { title = "^(Open File|Save File|Picture-in-Picture)$" }, float = true, center = true })
hl.window_rule({ name = "float-tools", match = { class = "^(pavucontrol|blueman-manager|nm-connection-editor)$" }, float = true, center = true, size = "900 600" })
hl.window_rule({ name = "float-ai", match = { class = "^(navuryx-ai)$" }, float = true, center = true, size = "1000 700" })
hl.window_rule({ name = "float-power", match = { class = "^(wlogout)$" }, float = true, fullscreen = true })
hl.window_rule({ name = "pip", match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true, size = "480 270", move = "100%-500 100%-300" })
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({
    name = "xwayland-fix",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})
