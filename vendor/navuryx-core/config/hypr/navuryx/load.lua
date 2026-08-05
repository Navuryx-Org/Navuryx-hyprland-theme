local M = {}

local failures = {}
local loaded = {}

local function state_path(name)
    local home = os.getenv("HOME")
    if not home then
        return nil
    end
    return home .. "/.config/navuryx/" .. name
end

local function write_state(name, text)
    local path = state_path(name)
    if not path then
        return
    end
    local handle = io.open(path, "w")
    if handle then
        handle:write(text)
        handle:close()
    end
end

function M.record(name, err)
    failures[#failures + 1] = string.format("%s: %s", name, tostring(err))
end

function M.load(name)
    local ok, err = pcall(require, name)
    if ok then
        loaded[#loaded + 1] = name
    else
        M.record(name, err)
    end
    return ok
end

function M.load_optional(name)
    pcall(require, name)
end

function M.failed()
    return #failures > 0
end

function M.report()
    local summary = string.format(
        "loaded=%s\nfailed=%s\n",
        table.concat(loaded, ","),
        tostring(#failures)
    )
    write_state("hyprland-config-status", summary)

    if #failures == 0 then
        write_state("hyprland-config-errors.log", "")
        return
    end

    local message = "Navuryx config errors:\n" .. table.concat(failures, "\n")
    io.stderr:write(message .. "\n")
    write_state("hyprland-config-errors.log", message .. "\n")
    if hl and hl.notify then
        pcall(hl.notify, message, { timeout = 30000 })
    end
end

function M.recover(bin)
    if #failures == 0 then
        return
    end

    local essentials = {
        { "SUPER + Return", bin .. "navuryx-terminal" },
        { "SUPER + T", bin .. "navuryx-terminal" },
        { "SUPER + SPACE", bin .. "navuryx-spotlight" },
        { "SUPER + A", bin .. "navuryx-ai" },
        { "SUPER + comma", bin .. "navuryx-settings" },
        { "SUPER + I", bin .. "navuryx-settings" },
        { "SUPER + N", bin .. "navuryx-control" },
        { "SUPER + TAB", bin .. "navuryx-overview" },
        { "SUPER + W", bin .. "navuryx-wallpaper" },
        { "SUPER + K", bin .. "navuryx-keybinds" },
    }

    for _, entry in ipairs(essentials) do
        pcall(hl.bind, entry[1], hl.dsp.exec_cmd(entry[2]))
    end

    for i = 1, 10 do
        local key = i % 10
        pcall(hl.bind, "SUPER + " .. key, hl.dsp.focus({ workspace = i }))
        pcall(hl.bind, "SUPER + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
        pcall(hl.workspace_rule, { workspace = tostring(i), persistent = true })
    end
end

return M
