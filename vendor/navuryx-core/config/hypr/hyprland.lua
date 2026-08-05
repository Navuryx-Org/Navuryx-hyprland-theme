local home = os.getenv("HOME") or ""
local bin = home .. "/.config/navuryx/bin/"

local function run(cmd)
    local ok, err = pcall(hl.exec_cmd, cmd)
    if not ok then
        io.stderr:write("navuryx exec failed: " .. tostring(err) .. "\n")
    end
end

local function bind_exec(keys, cmd, opts)
    local ok, err = pcall(function()
        if opts then
            hl.bind(keys, hl.dsp.exec_cmd(cmd), opts)
        else
            hl.bind(keys, hl.dsp.exec_cmd(cmd))
        end
    end)
    if not ok then
        io.stderr:write("navuryx bind failed (" .. keys .. "): " .. tostring(err) .. "\n")
    end
end

hl.on("hyprland.start", function()
    run("bash -lc 'if [ -x \"$HOME/.config/waybar/launch.sh\" ]; then \"$HOME/.config/waybar/launch.sh\"; elif command -v waybar >/dev/null; then waybar; fi'")
    run(bin .. "navuryx-wallpaper --restore")
    run("dbus-update-activation-environment --systemd --all")
    run(bin .. "navuryx-appearance --apply")
    run(bin .. "navuryx-shell-config ensure-workspaces")
    run(bin .. "navuryx-autostart-helpers")
    run(bin .. "navuryx-clipboard-watch")
    run(bin .. "navuryx-polkit")
    run("bash -lc 'command -v qs >/dev/null && qs -c navuryx || command -v quickshell >/dev/null && quickshell -c navuryx || true'")
    run(bin .. "navuryx-welcome")
end)

bind_exec("SUPER + Return", bin .. "navuryx-terminal")
bind_exec("SUPER + T", bin .. "navuryx-terminal")
bind_exec("CTRL + ALT + T", bin .. "navuryx-terminal")
bind_exec("SUPER + SPACE", bin .. "navuryx-spotlight")
bind_exec("SUPER + CTRL + Return", bin .. "navuryx-spotlight")
bind_exec("SUPER + SHIFT + SPACE", bin .. "navuryx-command")
bind_exec("SUPER + A", bin .. "navuryx-ai")
bind_exec("SUPER + ALT + A", bin .. "navuryx-ask-screen")
bind_exec("SUPER + comma", bin .. "navuryx-settings")
bind_exec("SUPER + I", bin .. "navuryx-settings")
bind_exec("SUPER + N", bin .. "navuryx-control")
bind_exec("SUPER + TAB", bin .. "navuryx-overview")
bind_exec("SUPER + W", bin .. "navuryx-wallpaper")
bind_exec("SUPER + K", bin .. "navuryx-keybinds")
bind_exec("SUPER + SHIFT + V", bin .. "navuryx-vpn")
bind_exec("SUPER + SHIFT + G", bin .. "navuryx-gaming")
bind_exec("SUPER + SHIFT + E", bin .. "navuryx-power")
bind_exec("SUPER + SHIFT + S", bin .. "navuryx-screenshot")
bind_exec("SUPER + V", bin .. "navuryx-clipboard")
bind_exec("SUPER + SHIFT + M", bin .. "navuryx-spotify")
bind_exec("CTRL + SUPER + SHIFT + D", bin .. "navuryx-appearance --toggle")

for i = 1, 10 do
    local key = i % 10
    pcall(function()
        hl.bind("SUPER + " .. key, hl.dsp.focus({ workspace = i }))
        hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
    end)
    local rule = { workspace = tostring(i), persistent = true }
    if i == 1 then
        rule.default = true
    end
    if not pcall(hl.workspace_rule, rule) then
        pcall(hl.workspace_rule, { workspace = tostring(i), persistent = true })
    end
end

pcall(function()
    hl.bind("SUPER + Q", hl.dsp.window.close())
    hl.bind("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    hl.bind("SUPER + ALT + SPACE", hl.dsp.window.float({ action = "toggle" }))
end)

local ok_loader, loader = pcall(require, "navuryx.load")
if ok_loader and loader then
    loader.load("navuryx.theme")
    loader.load("navuryx.animations")
    loader.load("navuryx.input")
    loader.load("navuryx.binds")
    loader.load("navuryx.rules")
    loader.load_optional("navuryx.user")
    loader.report()
else
    local path = home .. "/.config/navuryx/hyprland-config-errors.log"
    local handle = io.open(path, "w")
    if handle then
        handle:write("navuryx.load failed: " .. tostring(loader) .. "\n")
        handle:write("Essential binds and Waybar startup are still active from hyprland.lua.\n")
        handle:close()
    end
end
