#!/bin/bash
printf -v now '%(%s)T' -1
if (( now % 2 == 0 )); then echo "|"; else echo " "; fi
