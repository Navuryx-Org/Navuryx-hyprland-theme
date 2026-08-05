local sections = {
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(3558D4ff)", "rgba(7A24C9ff)" }, angle = 45 },
            inactive_border = "rgba(12122aaa)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
        snap = {
            enabled = true,
            window_gap = 4,
            monitor_gap = 5,
            respect_gaps = true,
        },
    },
    decoration = {
        rounding = 14,
        rounding_power = 2.5,
        active_opacity = 0.985,
        inactive_opacity = 0.93,
        shadow = {
            enabled = true,
            range = 20,
            offset = { 0, 2 },
            render_power = 3,
            color = 0xcc010106,
        },
        blur = {
            enabled = true,
            size = 8,
            passes = 3,
            vibrancy = 0.18,
            new_optimizations = true,
            xray = true,
            noise = 0.04,
            contrast = 0.9,
            brightness = 0.92,
        },
    },
    dwindle = { preserve_split = true, smart_split = true },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        focus_on_activate = true,
    },
}

local minimal = {
    general = {
        gaps_in = 6,
        gaps_out = 14,
        border_size = 2,
        layout = "dwindle",
    },
    decoration = {
        rounding = 14,
        active_opacity = 0.985,
        inactive_opacity = 0.93,
    },
    dwindle = { preserve_split = true },
    misc = { disable_hyprland_logo = true },
}

for name, values in pairs(sections) do
    if not pcall(hl.config, { [name] = values }) then
        pcall(hl.config, { [name] = minimal[name] })
    end
end

pcall(hl.monitor, { output = "", mode = "preferred", position = "auto", scale = "auto" })

local environment = {
    { "XCURSOR_SIZE", "24" },
    { "HYPRCURSOR_SIZE", "24" },
    { "QT_QPA_PLATFORM", "wayland;xcb" },
    { "QT_WAYLAND_DISABLE_WINDOWDECORATION", "1" },
    { "GDK_BACKEND", "wayland,x11,*" },
    { "XDG_CURRENT_DESKTOP", "Hyprland" },
    { "XDG_SESSION_TYPE", "wayland" },
    { "XDG_SESSION_DESKTOP", "Hyprland" },
    { "QT_QPA_PLATFORMTHEME", "qt6ct" },
    { "GTK_THEME", "Adwaita-dark" },
}

for _, entry in ipairs(environment) do
    pcall(hl.env, entry[1], entry[2])
end

for i = 1, 10 do
    local rule = { workspace = tostring(i), persistent = true }
    if i == 1 then
        rule.default = true
    end
    if not pcall(hl.workspace_rule, rule) then
        pcall(hl.workspace_rule, { workspace = tostring(i), persistent = true })
    end
end
