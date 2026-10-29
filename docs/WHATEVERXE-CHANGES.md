# Changes to WhateverXe

The `WhateverXe.kext` in this EFI is built from the `adlp-edp` branch of
[retropineaple/WhateverXe](https://github.com/retropineaple/WhateverXe/tree/adlp-edp),
a fork of [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe). The branch
starts from the upstream **0.6.0** release and adds 47 commits. To see them all:

```bash
git log --reverse 0.6.0..adlp-edp
git diff 0.6.0 adlp-edp
```

Everything new is off unless its boot-arg is set, so upstream behaviour is
unchanged on other machines:

| Boot-arg | What it enables |
|---|---|
| `-wex-adlp-edp` | Internal eDP panel mode (sections 1–8) |
| `-wex-reset-restore` | GPU hang recovery fixes (section 10) |
| `-wex-no-multicontext` | Compute on the render engine instead of Apple's second ring (section 10) |
| `-wex-reset-trace` | Recovery trace only (diagnostics) |
| `-wex-adlp-readout`, `-wex-adlp-readout-noaux` | Firmware state readout (diagnostics) |
| `-wex-noppguard` | Turns off the inactive VA user patch (section 9) |

The code says "ADL-P" because Intel and Linux use that name for the silicon
family that covers both Alder Lake-P and Alder Lake-U (the i7-1250U is
Alder Lake-U).

Upstream 0.6.1 later added its own experimental internal-display support for
this family, but it doesn't cover this panel: it supports only PWM backlights
(this OLED is dimmed over AUX) and has no eDP 1.4 link-rate-table handling.

## Why the panel didn't work

Upstream 0.6.0 drives external HDMI/DP on these chips, but not the internal
eDP panel. On this laptop the firmware lights the OLED from **Combo PHY A** as
a DisplayPort sink: 4 lanes at 2.7 Gbps, chosen through the eDP 1.4
`LINK_RATE_SET` table. The panel only takes its brightness over the DP AUX
channel. The branch drives the panel as a fixed DP output on Combo A and
fixes each point where Apple's Tiger Lake driver then broke.

## 1. Driving the panel as a fixed DP output on Combo A

- **Experimental ADL-P internal panel as fixed Combo A DP (`-wex-adlp-edp`).**
  The new opt-in mode.
  - VBT parsing keeps the first child per DDI, as Linux does, and prefers DDI A as the panel.
  - Combo A is admitted as a fixed DP port, and the donor's panel record is rewritten to a fixed Combo DP record.
  - The shared link-training adapter is installed for Combo-only DP.
  - `TRANS_CLK_SEL` and the lease checks are fixed for Combo DDIs.
  - The boot handoff checks the whole firmware framebuffer, not just a 1080p-sized prefix.
- **Admit the Combo A route without LFP panel facts.** This laptop's VBT
  picks its panel by PnP ID (`panel_type 0xFF`), so it has no panel timing
  table. The DP route doesn't program panel power sequencing, so it only
  needs the internal DP child on Combo A with AUX A. The laptop's VBT is
  included as a test fixture.
- **Adopt the Combo DP boot path before the first port probe.** Takeover of
  the firmware-lit link runs before ports are classified. The unprobed state
  is accepted for that step only.

## 2. Keeping the panel and display engine powered

- **Keep the panel powered.** The donor driver's panel-power (`PP_CONTROL`)
  writes that would cut panel power are refused.
- **Block DC3CO/DC5/DC6.** No display firmware (DMC) is loaded, so display
  power-saving states would power-gate the display engine and its AUX channel
  once the boot pipe goes idle.

## 3. Making macOS see a display

- **Keep the framebuffer connected through `connectionProbe`.** Apple's
  built-in-panel "clamshell" policy cleared the connected flag while the link
  was still running, so WindowServer saw no display.
- **Ignore AGDC framebuffer-online requests.** A graphics policy (AGDC)
  request took the only display offline, because the donor driver sees no
  built-in panel.
- **Report the panel as built-in** (`kIOConnectionBuiltIn`). This gives
  "Built-in Display", HiDPI and the laptop display behaviour.

## 4. Modes and timings

- **Resolve the adopted boot mode to the matching EDID mode**, and **report
  the native EDID mode before CoreDisplay installs timings.** The boot mode
  could never be described, so CoreDisplay kept the panel offline.
- **Describe the native panel mode before CoreDisplay installs timings.**
  `validateDisplayMode` couldn't describe any mode yet, so the GPU's display
  pipe couldn't attach to the framebuffer.
- **Never program an uninitialized timing.** When a link check failed, the
  donor programmed leftover stack memory as a timing (striped picture), then
  panicked dividing by zero.

## 5. Link rate (eDP 1.4)

- **Report the running link rate in `LINK_BW_SET`.** The OLED reports 0x01
  there (it uses `LINK_RATE_SET`), and Apple's policy rejected every mode.
- **Select the link rate through `LINK_RATE_SET` and train 4 × HBR.**
  `LINK_BW_SET` writes are translated to `LINK_BW_SET=0` plus the panel's
  rate-table index, as Linux does for eDP 1.4 panels. `MAX_LINK_RATE` is
  capped at HBR so training repeats the firmware's working setup.
- **Cap the extended DPCD link rate too** (DPCD 0x2201, which the donor reads).

## 6. Vertical blank and watermarks

- **Replay a VBL enable dropped during the modeset.** The lost vertical-blank
  interrupt made every later frame flip fail.
- **Use Y-tiled watermarks for the primary plane.** The linear watermark
  computed during the switch from the firmware framebuffer underran at 2880
  pixels wide.
- **Plan cursor watermarks for the pending cursor size** on HiDPI changes.
- **Accept downscaled source widths and heights above `htotal`/`vtotal`**,
  and **use the pipe's base pixel clock for line time under downscaling.**
  These are needed for scaled HiDPI modes. Looks-like 1600×1000 and larger
  still show motion corruption; 1440×900 is clean.

## 7. Framebuffer memory

- **An empty aperture before scanout allocation is "not ready", not a memory
  fault.** Otherwise the fault state stuck for good.
- **Validate the page-rounded range for unaligned sizes.** 2880×1800×4 bytes
  isn't page-aligned.

## 8. Brightness

- **Brightness over VESA DPCD AUX** (registers 0x722/0x723), answering
  macOS's `bklt` attribute.
- **Scale to `PWMGEN_BIT_COUNT`.** This OLED is 11-bit; a full 16-bit value
  blacked it out.
- **Backlight profile for this panel mode**, keyed by the PNLF `_UID`, so
  the brightness slider and keys work.
- **Brightness 0 = DPCD level 0.** Turning off the backlight-enable bit
  (0x720) instead left the panel dark for good, so that approach was
  reverted.

## 9. Video post-processing attempts

The Tiger Lake VA driver (from the WhateverXe-Graphics package) only builds
the COMPOSITE renderer on this GPU, and every scaling/colour-conversion
request then dereferences the missing VEBOX renderer.

- **Stop advertising `IOGVAScaler`**, then **revert it.** It wasn't the switch
  AppleGVA uses, so the net change is none.
- **Refuse the VA driver's post-processing context (Lilu user patch).**
  Correct in an in-process test, but **inactive in practice**: Lilu reads the
  file at early boot, before `/Library` is mounted, so the patch never applies.
  `-wex-noppguard` turns it off. The working approach is the optional on-disk
  patch in [`macOS/va-vpp-fix`](../macOS/va-vpp-fix).

## 10. GPU hang recovery

Before these changes, any GPU hang froze the laptop. Upstream already
replaces Apple's channel restart with a single-pass reset and resume on
Tahoe. On this GPU that reset leaves the hardware unusable. Each fix below
came from tracing the recovery on the laptop.

- **Trace the donor's GPU hang recovery (`-wex-reset-trace`).** Records each
  recovery step (channel restart, engine reset, scheduler reset and resume,
  command-streamer reset) with the render engine's registers. Hooks only
  donor functions that no other WhateverXe route owns.
- **Restore the render engine registers before replay (`-wex-reset-restore`).**
  The hung work's ring resets the render `GDRST` domain, but its restore list
  only names its own registers. So the render engine's mode (execlists),
  status page and workaround registers were cleared and never restored, and
  every replay hung again. Just before a render-domain reset, the render
  domain is woken and those registers are saved from a healthy engine. After
  the reset, with the donor's forcewake still held, they're written back
  before work is replayed.
- **Run compute on the render engine (`-wex-no-multicontext`).** Clears
  `EnableMultiContext` in the donor's settings before start, so its second
  (multi-context compute) ring isn't used. Work on that ring deadlocked:
  render work waited on a semaphore it never signalled, and its recovery
  could never resubmit.
- **Also restore the user-mode whitelist** (`FORCE_TO_NONPRIV0..11`),
  `RC_PWRCTX_MAX` and `EMR`. Without the whitelist the donor's Metal and VA
  drivers lose their register writes.
- **Record the hang report registers before and after recovery**, plus GT
  frequency, RC6 and wider register ranges, published as `WEXGPUResetDump`
  (diagnostics).
- **Complete stamps lost in the reset.** Work dropped by the reset never
  finishes, so IOAccel's progress check signalled a restart for it every few
  seconds and skipped it for lack of a channel, stalling the GPU work loop
  each time. Two seconds after a recovery, stamp slots still behind their
  last issued value, and unchanged since the recovery, are completed.
- **Restore the cache-control tables.** The reset also cleared the L3 cache
  control table (0xB020..). Without it the GPU ran 20–40× slower after a
  recovery. The global MOCS (0x4000..) and L3 tables are saved with the other
  registers, and entries that changed are rewritten.

## 11. Diagnostics (no effect on normal use)

- `-wex-adlp-readout` also records the firmware's eDP state:
  - registers: transcoder, PPS, backlight, PSR, PLL and Combo PHY A
  - the VBT
  - the panel's DPCD

  `-wex-adlp-readout-noaux` skips the DPCD reads.
- An ordered trace of display bring-up (connection changes, probes, EDID,
  training, AUX failures), a rolling recent-events ring for sleep/wake, and
  steady-state scaler/DBUF/underrun samples. `tools/decode_panel_trace.py`
  decodes them.
- The firmware DSDT/SSDTs are published as `WEXACPI-*` registry properties
  in panel mode. That's how this repo's ACPI patches were checked.

## Building

To rebuild the exact kext in this repo's EFI from b00t0x's 0.6.0 source, see
[whateverxe/README.md](../whateverxe/README.md):

```bash
zsh whateverxe/build-whateverxe.sh ~/whateverxe-build
```

Or build the branch directly:

```bash
git clone -b adlp-edp https://github.com/retropineaple/WhateverXe
cd WhateverXe
# Put MacKernelSDK/ (05094e5) and Lilu.kext/ (Lilu 1.7.2 headers) in the repo root
python3 tools/build.py --release
python3 tools/test.py
```

The kext is built to `build/WhateverXe.kext`. AppleIntelTGLCompat is
unchanged, so use the one from WhateverXe-Graphics 0.3.1.
