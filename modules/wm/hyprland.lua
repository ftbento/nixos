-- Hyprland config (Lua entrypoint, Hyprland >= 0.55).
-- This is the ONLY config; the legacy hyprland.conf is not generated anymore.
-- Per-host additions (monitors, workspaces, host autostart) live in host.lua
-- (see hosts/radon/hyprland-host.lua) and are required at the top.

require("host")

local mainMod = "SUPER"
local terminal = "kitty"
local launcher = "noctalia msg panel-toggle launcher"

hl.env("XCURSOR_SIZE", "24")

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,
        border_size = 2,
        layout   = "scrolling",
    },
    scrolling = {
        column_width = 1.0,
        fullscreen_on_one_column = true,
    },
    decoration = {
        rounding = 10,
        blur = {
            enabled = true,
            size    = 4,
            passes  = 2,
        },
    },
    input = {
        kb_layout   = "us",
        kb_options  = "caps:super",
        sensitivity = -0.25,
        follow_mouse = 0,
    },
    cursor = {
        no_hardware_cursors = true,
    },
})

-- curves
hl.curve("easeOutCubic",   { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.65, 0.05 }, { 0.36, 1 } } })
hl.curve("easeOutQuint",   { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("snappy",         { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })
hl.curve("linear",         { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- animations
hl.animation({ leaf = "global",      enabled = true, speed = 10, bezier = "linear" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "easeOutCubic" })
hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "easeOutQuint", style = "popin 80%" })
hl.animation({ leaf = "windowsIn",   enabled = true, speed = 7,  bezier = "easeOutQuint", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "easeOutQuint", style = "popin 80%" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "easeOutCubic" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layers",      enabled = true, speed = 7,  bezier = "easeOutCubic" })
hl.animation({ leaf = "layersIn",    enabled = true, speed = 7,  bezier = "easeOutCubic", style = "fade" })
hl.animation({ leaf = "layersOut",   enabled = true, speed = 7,  bezier = "easeOutCubic", style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 7, bezier = "easeOutCubic" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 7, bezier = "easeOutCubic" })
hl.animation({ leaf = "zoomFactor",  enabled = true, speed = 7,  bezier = "snappy" })

-- app launcher / control center / settings (Noctalia IPC)
hl.bind("ALT + Tab",           hl.dsp.exec_cmd("noctalia msg window-switcher"))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + D",     hl.dsp.exec_cmd(launcher))
hl.bind(mainMod .. " + S",     hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"))
hl.bind(mainMod .. " + V",     hl.dsp.exec_cmd("noctalia msg panel-toggle clipboard"))
hl.bind(mainMod .. " + comma", hl.dsp.exec_cmd("noctalia msg settings-toggle"))
-- Tap-only control-center toggle: SUPER+SUPER_L fires only on release of a bare
-- SUPER tap (uses the active mod as its own target modmask, per the Hyprland
-- "binding modkeys only" docs). The release flag + arming logic means it does
-- NOT fire after combos like SUPER+D. caps:super is set via kb_options, so the
-- physical CapsLock key emits SUPER_L too and is covered by this same bind.
hl.bind("SUPER + SUPER_L", hl.dsp.exec_cmd("noctalia msg panel-toggle control-center"), { release = true })

-- windows
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + Q",     hl.dsp.window.close())
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd("qylock-lock"))
hl.bind(mainMod .. " + A",     hl.dsp.exec_cmd("pwvucontrol"))

-- screenshots — shared Noctalia policy (save + clipboard) set in
-- profiles/desktop.nix. SUPER+Print runs the capture through the annotation
-- editor (freeze -> edit -> Done applies the same save+clip policy).
hl.bind("Print",               hl.dsp.exec_cmd("noctalia msg screenshot-region"))
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("noctalia msg screenshot-annotate"))

-- scrolling: focus / move / swap / resize
hl.bind(mainMod .. " + h",           hl.dsp.layout("focus l"))
hl.bind(mainMod .. " + l",           hl.dsp.layout("focus r"))
hl.bind(mainMod .. " + k",           hl.dsp.layout("focus u"))
hl.bind(mainMod .. " + j",           hl.dsp.layout("focus d"))
-- Super+scroll flips between columns; the wheel direction is inverted
-- relative to the stock binds so scrolling follows the column order.
hl.bind(mainMod .. " + mouse_down",  hl.dsp.layout("move -col"))
hl.bind(mainMod .. " + mouse_up",    hl.dsp.layout("move +col"))
-- Super+Shift+scroll switches workspaces (no numeric workspace binds)
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + SHIFT + h",   hl.dsp.layout("swapcol l"))
hl.bind(mainMod .. " + SHIFT + l",   hl.dsp.layout("swapcol r"))
hl.bind(mainMod .. " + SHIFT + k",   hl.dsp.layout("expel"))
hl.bind(mainMod .. " + SHIFT + j",   hl.dsp.layout("consume"))
hl.bind(mainMod .. " + CTRL + h",    hl.dsp.layout("colresize -conf"))
hl.bind(mainMod .. " + CTRL + l",    hl.dsp.layout("colresize +conf"))
hl.bind(mainMod .. " + CTRL + k",    hl.dsp.layout("colresize -0.05"))
hl.bind(mainMod .. " + CTRL + j",    hl.dsp.layout("colresize +0.05"))

-- mouse
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- layer rules (Noctalia blur) — the bar is deliberately excluded: it is
-- transparent (background_opacity = 0), so compositor blur behind it would
-- smear whatever is underneath.
--
-- The launcher/control-center/etc. ("panel" family) are excluded too: those
-- surfaces are almost fully transparent (only their cards are painted), so
-- compositor blur shows blurred wallpaper right behind the search/result text
-- and makes it blend into the background. Keep blur only where the surface
-- actually covers its own backdrop: notifications, OSD, window switcher.
hl.layer_rule({
    name  = "noctalia-blur",
    match = { namespace = "^noctalia-(notification|osd|window-switcher)$" },
    blur  = true,
})

-- window rules (Noctalia settings window)
hl.window_rule({
    name  = "noctalia-settings",
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size  = { 1080, 920 },
})

-- autostart (desktop-wide)
hl.on("hyprland.start", function()
    hl.exec_cmd("noctalia")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
end)