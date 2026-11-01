# Rebuilding WhateverXe.kext from upstream

The `WhateverXe.kext` in this repo's EFI is b00t0x's **WhateverXe 0.6.0**
source plus the 54 patches in [`patches/`](patches), compiled. WhateverXe is a
Lilu plugin built from C++ source, so the changes are source patches rather
than edits to the released binary: start from upstream's 0.6.0 source, apply
the patches, build.

```bash
zsh whateverxe/build-whateverxe.sh ~/whateverxe-build
```

The script:

1. clones [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe) and
   checks out the **0.6.0** release (`7b6b246`)
2. applies `patches/0001…0054` with `git am`
3. fetches the build dependencies pinned by upstream's CI:
   [MacKernelSDK](https://github.com/acidanthera/MacKernelSDK) `05094e5` and
   [Lilu](https://github.com/acidanthera/Lilu) **1.7.2**
4. runs WhateverXe's CPU tests, then the RELEASE build
5. compares the result with the kext in `EFI/OC/Kexts/WhateverXe.kext`

With the same compiler (Apple clang 21.0.0, `clang-2100.1.1.101`, from
Command Line Tools 26.6) the result is **byte-identical** to the EFI's kext,
SHA-256 `197da23bbe5a09731ef9517a0a6f9dabe52ab1f9b0c885a841a064190770288c`.
Two build details are pinned to make that possible:

- Lilu stamps the build date into every plugin (`REL-060-2026-10-31`), so the
  build runs with `SOURCE_DATE_EPOCH` set to 31 Oct 2026.
- The linker's `LC_UUID` depends on the build folder's path, so the script
  writes the original build's UUID (`93BA5765-EE4C-3B00-851A-09E56A97AE7B`)
  into the rebuilt binary. Every other byte is the compiler's own output.

A different compiler version gives a different but equivalent binary.

The same 54 commits are on the
[`adlp-edp` branch of retropineaple/WhateverXe](https://github.com/retropineaple/WhateverXe/tree/adlp-edp),
and [docs/WHATEVERXE-CHANGES.md](../docs/WHATEVERXE-CHANGES.md) explains each
one.

## Other patched files

| File | How it's made |
|---|---|
| `EFI/OC/Kexts/AppleALC.kext` | Stock AppleALC 1.9.8 RELEASE, patched with `tools/patch-applealc-alc245-layout11.py` (byte-identical output) |
| AppleIntelTGLGraphicsVADriver (installed by WhateverXe Graphics) | Optional; patched on the Mac by `macOS/va-vpp-fix/install-va-vpp-fix.sh` |
