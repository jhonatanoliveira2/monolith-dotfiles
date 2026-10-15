#!/bin/bash

DIR="$HOME/.config/fastfetch"

find "$DIR/ascii" "$DIR/pngs" -type f | shuf -n 1
