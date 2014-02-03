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
if [ -d /usr/share/fonts/local ] ; then
    xset +fp /usr/share/fonts/local
    xset fp rehash
fi

# Read Xresources config
xrdb -merge ~/.Xresources

# Read Xmodmap
xmodmap ~/.Xmodmap

# Dim screen
xbacklight -set 50
[ -e ~/.monitors.ini ] && ~/bin/monitors.py

# Run utilities
parcellite &
udiskie >> ~/log/udiskie.log 2>&1 &


exec i3
#exec awesome > ~/.awesome.log 2>&1
