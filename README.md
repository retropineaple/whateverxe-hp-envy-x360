# WhateverXe on the HP Envy x360 13 (i7-1250U, Alder Lake-U)

macOS Tahoe on the **HP Envy x360 13-bf0059TU** with Metal acceleration on the
**internal 2880×1800 OLED**, using a modified
[WhateverXe](https://github.com/b00t0x/WhateverXe) that drives the internal
eDP panel and recovers from GPU hangs on this chip, plus a touchscreen driver
written for it.

> [!WARNING]
> **This is a work in progress.** It's experimental, and there may be
> problems that haven't been discovered yet, beyond the known issues below.
> Back up your data and keep a working boot option before trying it.

> [!NOTE]
> **AI was used in this project.** The debugging, the WhateverXe patches, the
> scripts and these docs were developed with the help of Claude, an AI
> assistant, and tested on the author's own laptop.

- **[Setup guide](docs/INSTALL.md)**: from a fresh macOS install to this setup
- **[Problems fixed and still open](docs/FIXES.md)**: every issue, its cause and its fix
- **[WhateverXe changes](docs/WHATEVERXE-CHANGES.md)**: every change to the kext, explained
- **[EFI contents](docs/EFI.md)**: every kext, SSDT, patch and setting, explained
- **[Rebuild the kext yourself](whateverxe/README.md)**: upstream 0.6.0 source + the patches in `whateverxe/patches` give a byte-identical `WhateverXe.kext`
- **[Touchscreen driver](ithc/README.md)**: source and build script for `ITHC.kext`
- WhateverXe source: [retropineaple/WhateverXe, branch `adlp-edp`](https://github.com/retropineaple/WhateverXe/tree/adlp-edp)

## Specs

| | |
|---|---|
| Laptop | HP Envy x360 13-bf0059TU |
| CPU | Intel Core i7-1250U (12th gen Alder Lake-U, 2P + 8E) |
| iGPU | Intel Iris Xe, device ID 0x46AA |
| Display | 13.3" Samsung OLED 2880×1800 (SDC 4166), eDP 1.4, AUX brightness |
| Wi-Fi / Bluetooth | Intel AX211 CNVi |
| Audio | Realtek ALC245, plus Cirrus Logic CS35L41 speaker amplifiers |
| macOS | Tahoe 26.7.1 (25G241) |
| OpenCore | 1.0.8 |
| SMBIOS | MacBookPro16,2 |

## What works

- **Metal acceleration** on the internal OLED at native 2880×1800 @ 60 Hz,
  shown as **Built-in Display** with HiDPI (1440×900, and 1600×1000 and the
  other scaled modes without flicker)
- **Touchscreen**: taps, scrolling, multi-finger gestures (ITHC.kext with
  VoodooI2CHID)
- **CPU performance**: full P-core turbo (4.15 GHz on one thread) and deep core
  idle states with the XE-PM profile (`-wex-pm`)
- **GPU hang recovery**: a GPU hang causes a few-second stutter, then the
  laptop carries on at full speed (it used to freeze the whole machine)
- **Hardware video decode** (H.264/HEVC) through VideoToolbox
- **Brightness**: slider and F2/F3 keys, down to fully off and back
- **Lid**: closing turns the panel off, opening brings it back (with sleep disabled)
- **Wi-Fi** (AirportItlwm), **Bluetooth** (Intel): headphone audio and the
  headset mic (except for Siri)
- **Headphone jack** output (ALC245 layout 11, DSP removed)
- **Keyboard** (VoodooPS2), **battery**, **USB**
- **CPU name** shows correctly (RestrictEvents)
- **iCloud services** work, once you've generated your own SMBIOS (serial,
  MLB, UUID and ROM). The published config has these blank. See
  [step 1 of the setup guide](docs/INSTALL.md#1-fill-in-your-own-smbios).

## What doesn't work / known issues

- **Video playback sometimes hangs the GPU** (seen with the App Store's
  autoplaying videos): the hang recovers, but each one causes a stutter of a
  few seconds. The video driver's GPU program that hangs isn't fixed yet.
  Turning off App Store autoplay avoids it.
- **Sleep**: the laptop enters sleep but never wakes ("Sleep Wake failure in
  EFI"), even without graphics drivers. It's a firmware limit; sleep is turned
  off instead.
- **Speakers**: the CS35L41 smart amplifiers have no macOS driver.
- **Siri can't hear you**, over either a Bluetooth headset or the headphone
  jack. Bluetooth audio and its mic otherwise work (voice memos record fine).
- **Camera**: it's an IPU6 MIPI camera, which has no macOS driver, so it
  can't work.
- **Touchscreen scrolling** shares macOS's "Natural scrolling" setting with the
  mouse. A tool such as LinearMouse can set them separately.
- **Touchpad**: untested. This laptop's touchpad is broken in hardware (it
  doesn't work in Windows or Ubuntu either). VoodooI2C is included for it.
- **Battery life and heat**: better with `-wex-pm` (about 4–6.5 W at idle), but
  still worse than Ubuntu (2–3 W). The rest needs the display's power-saving
  firmware and states (DMC, DC5/DC6, PSR), which aren't done yet.
- **Occasional animation stutter**: macOS on Intel doesn't tell P-cores from
  E-cores, so UI work sometimes lands on a slower E-core.
- **Safari video** decodes in software: Safari refuses the patched VA driver,
  and the unpatched one crashes on video processing.
- **AirDrop / Continuity**: not possible with the Intel AX211.
- **Apple TV app / FairPlay video**: not supported by WhateverXe.

Details, causes and what was tried are in [docs/FIXES.md](docs/FIXES.md).

## Credits

- [b00t0x](https://github.com/b00t0x) for WhateverXe and WhateverXe Graphics.
  None of this exists without it.
- [acidanthera](https://github.com/acidanthera): OpenCore, Lilu, VirtualSMC,
  AppleALC, BrightnessKeys, RestrictEvents, NVMeFix
- [OpenIntelWireless](https://github.com/OpenIntelWireless): AirportItlwm,
  IntelBluetoothFirmware
- [laobamac](https://github.com/laobamac/SimpleHDA) for SimpleHDA
- VoodooI2C, VoodooPS2, USBToolBox, CpuTopologyRebuild and HoRNDIS authors
- [quo/ithc-linux](https://github.com/quo/ithc-linux): the Linux THC driver
  that ITHC.kext is ported from
- [JulioNectar](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe):
  the XE-PM CPU profile (`-wex-pm`) is his code from the NootedGreen fork,
  shared with the Hackintosh community
- The [Linux i915 driver](https://github.com/torvalds/linux/tree/v6.12/drivers/gpu/drm/i915),
  used as the reference for this GPU's behaviour
- Claude (AI) helped with the debugging, patches, scripts and docs.

## Licenses

Each kext in `EFI/OC/Kexts` keeps its own license. WhateverXe is BSD-3-Clause
(see the fork). ITHC.kext is BSD-2-Clause, as allowed by ithc-linux's
"GPL-2.0 OR BSD-2-Clause" license (see [ithc/LICENSE](ithc/LICENSE)). The scripts and docs in this repo are provided as-is.
Apple's graphics drivers aren't included: get them from the WhateverXe
Graphics release.
