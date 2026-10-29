# Problems fixed and still open

Every problem met while bringing up this laptop, what caused it and how it was
fixed. Code changes are in the `adlp-edp` branch of the WhateverXe fork, and
each is explained in [WHATEVERXE-CHANGES.md](WHATEVERXE-CHANGES.md).

## Fixed

### Display and graphics

| Problem | Cause | Fix |
|---|---|---|
| Internal OLED not driven, so no acceleration | WhateverXe 0.6.0 doesn't drive Alder Lake-P/U internal eDP panels | New `-wex-adlp-edp` mode: drive the panel as a fixed DisplayPort output on Combo PHY A |
| Black screen or no mode after the switch from firmware | Mode reporting, timing and eDP 1.4 link-rate handling didn't fit this panel | Report the native EDID mode early; train through `LINK_RATE_SET`; guard uninitialized timings |
| Frame flips failing, picture stuck | A vertical-blank enable was dropped during the modeset | Replay it once the display path exists |
| Underruns and corruption at 2880 px | Linear watermarks used for a Y-tiled plane; unaligned framebuffer size | Y-tiled watermarks; page-rounded framebuffer range |
| Panel shown as an external display | Connection type not reported as built-in | Report `kIOConnectionBuiltIn` |
| Text too small, no Retina modes | No display override for this panel | `macOS/display-override` (1440×900 HiDPI) |
| Brightness slider greyed out | This OLED is dimmed over the DP AUX channel, which nothing handled | Brightness over VESA DPCD AUX, `AAPL,backlight-control`, SSDT-PNLF and a backlight profile |
| Screen black right after boot | Brightness sent as a 16-bit value; this panel is 11-bit | Scale to the panel's `PWMGEN_BIT_COUNT` |
| Brightness 0 left the panel dark for good | Clearing the backlight-enable bit; this panel never comes back from that | Use DPCD brightness level 0 instead |
| F2/F3 keys did nothing | HP's firmware notifies `GFX0.DD1F`; BrightnessKeys listens on `DD02` | OpenCore ACPI patch DD1F → DD02 |

### GPU hangs

| Problem | Cause | Fix |
|---|---|---|
| A GPU hang froze the whole laptop (also the "screen never wakes after idle" case) | The engine reset wipes the render engine's settings, execlist mode included, and Apple's restore didn't put them back | `-wex-reset-restore`: save the render engine's registers before the reset and write them back afterwards |
| Second hang right after the first never recovered | Apple's second "multi-context" compute ring left work waiting on a semaphore that never fired | `-wex-no-multicontext`: run compute on the render engine, as Linux does on this GPU |
| GPU drivers couldn't program their registers after a reset | The reset also cleared the user-mode register whitelist | Whitelist added to the restore |
| Stutter every 5 seconds after a recovery | Work lost in the reset never finished, so macOS's GPU watchdog kept flagging it | Two seconds after recovery, mark lost work finished |
| GPU 20–40× slower after a recovery | The reset cleared the L3 cache-control table | Cache-control tables added to the restore |

### Audio, Bluetooth and system

| Problem | Cause | Fix |
|---|---|---|
| No audio at all | Tahoe removed AppleHDA | SimpleHDA + AppleALC (`alcid=11`) |
| AppleALC didn't attach | Its controller table lacks this laptop's 0x51CC | `device-id` spoofed to 0x51C8 (same family) |
| Audio device names in Chinese | SimpleHDA default language | `shda-lang=en` |
| Kernel panic whenever something recorded | Layout 11's mic noise-reduction DSP crashed in `EupDSP::ConfigParamInt` | AppleALC patched to remove the DSP chains (`tools/patch-applealc-alc245-layout11.py`) |
| Safari YouTube wouldn't play | No audio output device existed | Fixed by having the headphone output |
| Bluetooth off | The standard Intel Bluetooth NVRAM entries were missing | `bluetoothExternalDongleFailed` and `bluetoothInternalControllerInfo` in NVRAM |
| Kernel panic at boot | The `-ibtcompatbeta` boot-arg | Removed |
| CPU shown as "Xeon W" | The `revpatch` boot-arg overrode the NVRAM value | RestrictEvents NVRAM `revpatch=sbvmm,cpuname` and `revcpuname`, no boot-arg |
| Video processing crashed apps | Apple's Tiger Lake VA driver has no VEBOX renderer on this GPU | Optional on-disk VA patch (`macOS/va-vpp-fix`), with limits |
| Sleep never woke | Firmware limit (Modern Standby machine) | Workaround: sleep disabled, lid close turns the screen off |

## Still open

| Problem | What's known |
|---|---|
| Video sometimes hangs the GPU (App Store autoplay videos) | The video driver's GPU program (`MEDIA_OBJECT`) never finishes. Recovery now handles it, at the cost of a ~3 s stutter per hang |
| Idle black screen | Caused by a GPU hang during Photos analysis; the recovery fixes should cover it, but it hasn't been re-tested after an hour idle |
| Sleep | Firmware limit, see above |
| Speakers | CS35L41 amplifiers have no macOS driver |
| Siri can't hear you | Bluetooth voice packets are discarded as malformed for Siri; the jack mic records but Siri gets nothing usable |
| Camera, touchscreen | Not working yet, not investigated |
| Touchpad | Untested: the author's touchpad is broken in hardware |
| Battery drain and heat | Not investigated |
| Safari video in software | Safari's GPU process refuses the ad-hoc signed VA driver |
| HiDPI above 1440×900 | Motion corruption at 1600×1000 and up |
| AirDrop / Continuity | Not possible with the Intel AX211 |
| Apple TV app / FairPlay | Not supported by WhateverXe |
| Turning off the multi-context compute ring | Fixes the deadlock; long-term side effects not fully known |
