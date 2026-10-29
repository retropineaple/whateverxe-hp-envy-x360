#!/bin/zsh
# sudo zsh install-va-vpp-fix.sh            install the fix
# sudo zsh install-va-vpp-fix.sh --revert   put the original driver back
#
# Fixes the GPU hang/crash when apps (Safari/WebKit, VideoToolbox, wallpaper,
# Photos analysis) ask the TGL VA donor driver for video post-processing
# (scaling / colour conversion). The donor only builds the COMPOSITE renderer,
# then dereferences the missing VEBOX one. The 8-byte patch at file offset
# 0x14906 makes that post-processing context creation fail cleanly, so
# VideoToolbox falls back to its own (correct) conversion. Decode stays on the GPU.
#
# Limits: the patched file is re-signed ad hoc. AMFIPass accepts that in
# VTDecoderXPCService and in ordinary apps, but Apple platform processes such as
# Safari's com.apple.WebKit.GPU refuse it and decode video in software instead.
# Reinstalling the WhateverXe-Graphics package undoes the fix.
set -e
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }
drv=/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.bundle/Contents/MacOS/AppleIntelTGLGraphicsVADriver
bak=/Library/GPUBundles/AppleIntelTGLGraphicsVADriver.original
orig_sha=b41dfb6f3efeb4279d8b29f66cc5dec240942f10397cd2d06c51f34a37ee48a3
off=$((0x14906))
old=39c20f8760060000
new=e9630600000f1f00

swap_in() { # atomic replace, so running processes keep their mapped copy
  local tmp=$drv.new.$$
  cp -p "$1" $tmp && chown root:wheel $tmp && chmod 755 $tmp && mv -f $tmp $drv
  killall VTDecoderXPCService 2>/dev/null || true
}

if [[ "$1" == --revert ]]; then
  [[ -f $bak ]] || { echo "no backup at $bak"; exit 1; }
  [[ $(shasum -a 256 $bak | cut -d' ' -f1) == $orig_sha ]] || { echo "backup checksum mismatch, not touching anything"; exit 1; }
  swap_in $bak
  echo "Original driver restored. Reboot (or quit Safari) to reload it everywhere."
  exit 0
fi

cur=$(xxd -s $off -l 8 -p $drv)
if [[ $cur == $new ]]; then echo "Already installed."; exit 0; fi
[[ $cur == $old && $(shasum -a 256 $drv | cut -d' ' -f1) == $orig_sha ]] || {
  echo "Driver is not the expected 0.3.1 donor build, not patching."; exit 1; }
[[ -f $bak ]] || cp -p $drv $bak
work=$(mktemp -d)
cp $drv $work/va
printf "$(echo $new | sed 's/../\\x&/g')" | dd of=$work/va bs=1 seek=$off conv=notrunc status=none
[[ $(xxd -s $off -l 8 -p $work/va) == $new ]] || { echo "patch write failed"; exit 1; }
codesign -f -s - $work/va
swap_in $work/va
rm -rf $work
echo "Installed. Backup of the original: $bak"
echo "Reboot so every process loads the fixed driver."
