#!/bin/bash
# Lock screen Caps Lock indicator: prints its arguments while any keyboard has the Caps Lock LED on.
for led in /sys/class/leds/*::capslock/brightness; do
    [[ -r $led ]] || continue
    read -r on <"$led"
    if (( on > 0 )); then echo "$*"; exit 0; fi
done
echo ""
