#!/bin/bash
which gfind >/dev/null || brew install findutils
gfind src -maxdepth 1 -printf "%f\n" | grep -vp '^src$' 
