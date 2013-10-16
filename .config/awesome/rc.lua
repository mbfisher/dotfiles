-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Theme handling library
local beautiful = require("beautiful")

dofile(awful.util.getdir("config") .. "/rc.d/init.lua")

-- {{{ Theme
beautiful.init(awful.util.getdir('config') .. "/themes/mbfisher/theme.lua")

-- Maximise wallpaper
if beautiful.wallpaper then
    for s = 1, screen.count() do
        gears.wallpaper.maximized(beautiful.wallpaper, s, true)
    end
end
-- }}}

-- {{{ Variables
-- This is used later as the default terminal and editor to run.
terminal = 'urxvt -e tmux'
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod3"
-- }}}

-- {{{ Layouts
-- Table of layouts to cover with awful.layout.inc, order matters.
local layouts =
{
    awful.layout.suit.floating,
    awful.layout.suit.tile,
    awful.layout.suit.tile.left,
    awful.layout.suit.tile.bottom,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair,
    awful.layout.suit.fair.horizontal,
    awful.layout.suit.spiral,
    awful.layout.suit.spiral.dwindle,
    awful.layout.suit.max,
    awful.layout.suit.max.fullscreen,
    awful.layout.suit.magnifier
}
-- }}}

-- {{{ Resources
resources = {
    'tags.lua',
    'menu.lua',
    'keybindings.lua',
    'rules.lua',
    'signals.lua',
    'wibox.lua'
}
for i = 1, #resources do
    dofile(awful.util.getdir("config") .. "/rc.d/" .. resources[i])
end
-- }}}
