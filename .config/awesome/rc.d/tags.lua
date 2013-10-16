local awful = require("awful")
awful.rules = require("awful.rules")
local tyrannical = require("tyrannical")

-- {{{ Tags
--[[ Define a tag table which hold all screen tags.
tags = {
    awful.tag({'web', 'skype'}, 1, awful.layout.suit.floating),
    awful.tag({'term'}, 2, awful.layout.suit.tile)
}
--]]
-- }}}

tyrannical.tags = {
    {
        name        = "term",                 -- Call the tag "Term"
        init        = true,                   -- Load the tag on startup
        exclusive   = true,                   -- Refuse any other type of clients (by classes)
        screen      = screen.count() > 1 and 2 or 1,                  -- Create this tag on screen 1 and screen 2
        layout      = awful.layout.suit.tile, -- Use the tile layout
        class       = { --Accept the following classes, refuse everything else (because of "exclusive=true")
            "xterm" , "urxvt" , "aterm","URxvt","XTerm","konsole","terminator","gnome-terminal"
        }
    },
    {
        name = "web",
        exclusive = true,
        screen = 1,
        force_screen  = 1,
        layout = awful.layout.suit.floating,
        class = {"Google-chrome", "Chromium"}
    },
    {
        name = "skype",
        exclusive = true,
        screen = 1,
        layout = awful.layout.suit.floating,
        class = {"skype"}
    }
}
