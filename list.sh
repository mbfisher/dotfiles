#!/bin/bash
gfind src -maxdepth 1 -printf "%f\n" | grep -vp '^src$' 
