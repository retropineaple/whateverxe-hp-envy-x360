#!/bin/zsh
# sudo zsh disable-sleep.sh            turn system sleep off (lid close only turns the screen off)
# sudo zsh disable-sleep.sh --undo     restore the macOS defaults
#
# This laptop enters S3 sleep but never wakes ("Sleep Wake failure in EFI").
# It happens without any graphics drivers too, so it is a firmware limit
# (Modern Standby machine), not WhateverXe.
set -e
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
if [[ "$1" == --undo ]]; then
  pmset -a disablesleep 0 hibernatemode 3 standby 1 powernap 1 proximitywake 1 autopoweroff 1
  echo "Sleep settings restored."; exit 0
fi
pmset -a disablesleep 1 hibernatemode 0 standby 0 powernap 0 proximitywake 0 autopoweroff 0
rm -f /var/vm/sleepimage
pmset -g | grep -E 'SleepDisabled|hibernatemode|standby |powernap|proximitywake'
