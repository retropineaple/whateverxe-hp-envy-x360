# What's in the EFI and why

Every kext, SSDT, patch and setting in this EFI, and why it's there.

OpenCore 1.0.8, SMBIOS MacBookPro16,2, macOS Tahoe 26.7.1.

## Graphics

| Setting | Value | Why |
|---|---|---|
| `Kexts/WhateverXe.kext` | built from the `adlp-edp` branch | Runs Apple's Tiger Lake drivers on this GPU, drives the internal OLED and recovers from GPU hangs. See [WHATEVERXE-CHANGES.md](WHATEVERXE-CHANGES.md). |
| `Kexts/AMFIPass.kext` | 1.4.1 Mod (from WhateverXe-Graphics) | Lets the re-signed Tiger Lake GPU bundles in `/Library/GPUBundles` load. |
| boot-arg `-wex-adlp-edp` | | Internal-panel mode. Without it the OLED gets no driver. |
| boot-arg `-wex-reset-restore` | | GPU hang recovery for this chip: restores the render engine's settings, whitelist and cache tables after a reset, and finishes lost work. |
| boot-arg `-wex-no-multicontext` | | Turns off Apple's second compute ring, which deadlocked during recovery; compute runs on the render engine. |
| boot-args `-allow3d -disablegfxfirmware` | | Required by WhateverXe (see its README). |
| boot-arg `-igfxdvmt` | | DVMT (stolen memory) handling for the iGPU. |
| boot-args `keepsyms=1 msgbuf=4194304` | | Readable panic logs and a larger kernel log buffer. |
| `csr-active-config` | `03080000` (0x803) | SIP relaxed for the GPU bundles and AMFIPass. |
| IGPU `AAPL,backlight-control` | `01000000` | Makes macOS show the brightness slider. |
| IGPU `built-in`, `AAPL,slot-name`, `model`, `hda-gfx` | | Device naming and HDMI-audio hints for macOS. |
| IGPU `framebuffer-patch-enable`, `framebuffer-stolenmem` | `01000000`, `0000c003` | Framebuffer stolen-memory size. |
| `ACPI/SSDT-PNLF.aml` + "PNLF to XNLF" rename | | Backlight device for macOS. The HP DSDT has its own PNLF, which the rename moves aside. |

## Brightness keys

HP's firmware sends the F2/F3 brightness events to `GFX0.DD1F`, but
BrightnessKeys listens on `DD02`. One ACPI patch redirects them:

| Field | Value |
|---|---|
| Comment | Brightness keys: Notify GFX0.DD1F -> DD02 |
| Table | DSDT, count 2 |
| Find | `865E5E5E2E4746583044443146` |
| Replace | `865E5E5E2E4746583044443032` |

`BrightnessKeys.kext` does the rest.

## Audio (headphone jack and mic)

Tahoe removed AppleHDA, so AppleALC alone does nothing.

| Setting | Value | Why |
|---|---|---|
| `Kexts/SimpleHDA.kext` | 1.0.0 (`MinKernel` 25) | Brings back an AppleHDA for Tahoe. |
| boot-arg `shda-lang=en` | | Device names in English instead of Chinese. |
| `Kexts/AppleALC.kext` | 1.9.8, **patched** | See below. |
| boot-arg `alcid=11` | | ALC245 layout 11 gave the best headphone quality of 11, 12 and 13. |
| `PciRoot(0x0)/Pci(0x1F,0x3)` `device-id` | `C8510000` (0x51C8) | AppleALC's controller table lacks this laptop's 0x51CC; 0x51C8 is the same controller family. |

**The AppleALC patch.** Layout 11 sends the mic through Apple's
noise-reduction DSP. On this laptop that crashes the kernel (in
`EupDSP::ConfigParamInt`) the moment anything records. The patched kext has
every `SignalProcessing` block removed from layout 11. The headphone output is
unchanged, and recording no longer panics. To make the same change to a stock
AppleALC 1.9.8 RELEASE:

```bash
python3 tools/patch-applealc-alc245-layout11.py \
  AppleALC.kext/Contents/MacOS/AppleALC AppleALC.patched
```

Then replace `Contents/MacOS/AppleALC` with the output. The script's result is
byte-identical to the kext in this EFI.

The speakers can't work: they sit behind Cirrus Logic CS35L41 smart
amplifiers that macOS has no driver for.

## Bluetooth

| Setting | Why |
|---|---|
| IntelBluetoothFirmware, IntelBTPatcher 2.5.1, BlueToolFixup 2.7.3 | Intel AX211 Bluetooth. |
| NVRAM `bluetoothExternalDongleFailed` = `00`, `bluetoothInternalControllerInfo` = 14 zero bytes (also in NVRAM → Delete) | The standard Intel Bluetooth fix on recent macOS. Without them Bluetooth stays off. |

## CPU name

RestrictEvents with NVRAM `revpatch` = `sbvmm,cpuname` and `revcpuname` =
`12th Gen Intel(R) Core(TM) i7-1250U`. Don't add a `revpatch=` boot-arg: it
overrides the NVRAM value and the CPU shows as "Xeon W" again.

## USB

`UTBMap.kext` (USBToolBox) maps this HP's ports: two USB-A ports with USB 3,
two Type-C ports and the internal Bluetooth port. `XHCI-unsupported.kext`
attaches Apple's USB driver to this controller (0x51ED).

## Other SSDTs and kexts

Standard OpenCore SSDTs, each pointing at devices in the HP's ACPI tables:

- SSDT-ALS0, SSDT-SBUS, SSDT-EC, SSDT-GPI0 (+ "GPI0 _STA to XSTA")
- SSDT-MCHC, SSDT-PLUG-ALT-12, SSDT-RTCAWAC
- SSDT-USB-Reset, SSDT-USBW, SSDT-USBX
- SSDT-XOSI (+ "_OSI to XOSI")

Other kexts:

- Lilu
- VirtualSMC (+ SMCBatteryManager, SMCProcessor)
- CpuTopologyRebuild (hybrid P/E-core topology)
- NVMeFix
- VoodooI2C/VoodooI2CHID (I2C touchpad; untested, see the README)
- VoodooPS2Controller (keyboard)
- AirportItlwm (Wi-Fi)
- HoRNDIS (Android USB tethering)

## Booter

`DevirtualiseMmio` is on, with the PCIe ECAM window (0xC0000000) and four
firmware MMIO ranges whitelisted so they stay mapped.

## Blanked for publishing

`PlatformInfo → Generic`: `SystemSerialNumber`, `MLB`, `SystemUUID` and `ROM`
are empty. Generate your own (see [INSTALL.md](INSTALL.md)). Never reuse
someone else's.
