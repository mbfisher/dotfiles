#!/bin/sh
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here)

if [ -d /etc/X11/xinit/xinitrc.d ]; then
  for f in /etc/X11/xinit/xinitrc.d/*; do
    [ -x "$f" ] && . "$f"
  done
  unset f
fi

# Load extra fonts
xset +fp /usr/share/fonts/local
xset fp rehash

# Read Xresources config
xrdb -merge ~/.Xresources

# Read Xmodmap
xmodmap ~/.Xmodmap

# Dim screen
xbacklight -set 50

# Set up dual screen
xrandr --output LVDS1 --mode 1366x768
if xrandr | grep "HDMI1 connected" ; then
  xrandr --output HDMI1 --mode 1920x1080
  xrandr --output HDMI1 --left-of LVDS1
fi

# Run utilities
parcellite &

exec awesome
