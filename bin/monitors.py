#!/usr/bin/env python

import configparser
import subprocess

config = configparser.ConfigParser()
config.read('.monitors.ini')

for monitor in config.sections():
    print(monitor)
    args = []
    for flag, value in config.items(monitor):
        args.extend(('--'+flag, value))

    print(args)
    subprocess.call(['xrandr', '--output', monitor] + args)
