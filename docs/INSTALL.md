# Setup guide (fresh install)

For the **HP Envy x360 13-bf0xxx with an i7-1250U** (Alder Lake-U, Iris Xe
0x46AA) and the 2880×1800 Samsung OLED (SDC 4166). Other HP Envy x360 13-bf
models with a different panel, CPU or Wi-Fi card may need changes. Tested on
macOS Tahoe 26.7.1 (25G241).

This assumes you know how to install macOS with OpenCore. If not, read the
[Dortania guide](https://dortania.github.io/OpenCore-Install-Guide/) first.
**Back up your data.** This is experimental graphics support.

This setup was built up on an existing install; a fresh install with this
exact EFI hasn't been tested end to end. The steps below are what that
install needed.

## 1. Fill in your own SMBIOS

The published `config.plist` has empty `SystemSerialNumber`, `MLB`,
`SystemUUID` and `ROM`.

1. Use [GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) to generate a
   **MacBookPro16,2** serial, MLB and UUID.
2. For `ROM`, use your Wi-Fi card's MAC address (6 bytes).
3. Fill them into `PlatformInfo → Generic` with
   [ProperTree](https://github.com/corpnewt/ProperTree).

iCloud services need this step. They won't work with blank or copied values,
and never use someone else's serial.

## 2. Put the EFI on a USB stick

Format a USB stick as **GUID Partition Map** with an **MS-DOS (FAT32)**
partition. Copy this repo's `EFI` folder to the root of that partition.

Boot it with **F9** (boot menu) and test before copying it to the internal
disk's EFI partition. Keep a known-good EFI stick around.

## 3. Install macOS

Install macOS Tahoe as usual from the USB. Graphics won't be accelerated yet,
because WhateverXe needs the graphics package from step 4. If the installer's
screen goes black, try booting it without `-wex-adlp-edp`, then add it back
after step 4.

## 4. Install WhateverXe Graphics 0.3.1

Download **WhateverXe-Graphics 0.3.1** from
[b00t0x/WhateverXe-Graphics releases](https://github.com/b00t0x/WhateverXe-Graphics/releases/tag/v0.3.1)
and install it:

```bash
sudo installer -pkg WhateverXe-Graphics-0.3.1.pkg -target /
```

Reboot. If macOS says "System Extension Blocked", allow it in System Settings →
Privacy & Security, then reboot again.

This setup was tested with 0.3.1. Newer packages update AppleIntelTGLCompat
for upstream's own panel code, and haven't been tested with this branch.

After this you should have Metal acceleration on the OLED at native
2880×1800, shown as **Built-in Display**.

## 5. Retina (HiDPI) scaling

```bash
sudo zsh macOS/display-override/install-display-override.sh
```

Reboot, then choose **1440 × 900** in System Settings → Displays. Avoid
1600 × 1000 and larger: moving content shows corruption there. To switch
from the command line instead, run `swift macOS/display-override/set-1440x900.swift`.
`list-modes.swift` prints every mode.

## 6. Turn off sleep

The firmware can't wake from macOS sleep, so turn sleep off. Closing the lid
then just turns the screen off.

```bash
sudo zsh macOS/sleep/disable-sleep.sh
```

`--undo` restores the defaults.

## 7. Optional: video processing fix

Apple's Tiger Lake VA driver crashes when an app asks it to scale or
colour-convert video (VideoToolbox, Photos analysis, wallpaper). This script
patches 8 bytes of the installed driver so those requests fail cleanly and
macOS converts frames itself. It keeps a backup, and `--revert` restores it.

```bash
sudo zsh macOS/va-vpp-fix/install-va-vpp-fix.sh
```

Reboot afterwards. Limits:

- It only works where macOS accepts an ad-hoc signature. Safari's GPU process
  refuses the patched driver and decodes video in software.
- Reinstalling the graphics package undoes it.

## Boot-args in this EFI

```
-allow3d -disablegfxfirmware -igfxdvmt -wex-adlp-edp keepsyms=1 shda-lang=en alcid=11 -wex-reset-restore -wex-no-multicontext -wex-scanout-coherent -wex-pm
```

`-wex-reset-restore` and `-wex-no-multicontext` are what make GPU hangs
recover instead of freezing the laptop. `-wex-scanout-coherent` keeps HiDPI
modes above 1440×900 clean, and `-wex-pm` is the CPU profile. See
[EFI.md](EFI.md#graphics).

## Checklist

- [ ] Display accelerated at 2880×1800, "Built-in Display", HiDPI at 1440×900
      and 1600×1000 without flicker
- [ ] Brightness slider and F2/F3 keys (down to fully off and back)
- [ ] Lid close turns the screen off and reopening brings it back
- [ ] Wi-Fi, Bluetooth, keyboard, USB ports, battery
- [ ] Touchscreen: tap, scroll and multi-finger gestures
- [ ] Touchpad (untested on the author's laptop: its touchpad hardware is broken)
- [ ] Headphone jack output
- [ ] A GPU hang (for example App Store videos) stutters for a few seconds and recovers

## Troubleshooting

- **Black screen right after the Apple logo:** boot from your known-good stick.
  Check that `-wex-adlp-edp` is in boot-args and that the graphics package is
  installed.
- **Bluetooth off:** keep the two `bluetooth…` NVRAM entries in config.plist
  (see [EFI.md](EFI.md#bluetooth)).
- **CPU shows as "Xeon W":** don't put a `revpatch=` boot-arg in; the NVRAM
  value handles it.
- **Measuring GPU speed:** `swiftc -O tools/gpubench.swift -o gpubench && ./gpubench`.
  On this laptop a healthy GPU does the compute test in about 4–15 ms and the
  4K copy in about 1.8 ms.
