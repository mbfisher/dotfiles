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
xrdb -merge ~/.Xdefaults
feh --bg-fill ~/wallpaper/cubes.jpg

# Read Xmodmap
#xmodmap ~/.Xmodmap

# Run utilities
nm-applet &
sudo python2 ~/bin/hotkeys.py & 2>&1 > ~/hotkeys.log

# Start dbus
source /etc/X11/xinit/xinitrc.d/30-dbus

eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
export SSH_AUTH_SOCK
export GPG_AGENT_INFO
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID

exec i3
