-- radon host config — monitors + workspace placement. Keybinds live in hyprland.lua.
-- Loaded from hyprland.lua via require("host").

hl.monitor({ output = "DP-5",     mode = "2560x1440@164.96", position = "0x0", scale = "1" })
hl.monitor({ output = "HDMI-A-5", mode = "1920x1080@60",    position = "320x-1080", scale = "1", transform = 2 })

for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-5" })
    hl.workspace_rule({ workspace = tostring(i + 5), monitor = "HDMI-A-5" })
end

hl.on("hyprland.start", function()
    hl.exec_cmd("xrandr --output DP-5 --primary")
    hl.exec_cmd("steam -silent")
end)