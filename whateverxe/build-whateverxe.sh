#!/bin/zsh
# zsh whateverxe/build-whateverxe.sh [work-folder]
#
# Rebuilds this repo's WhateverXe.kext from b00t0x's original source:
#   1. clones b00t0x/WhateverXe and checks out the 0.6.0 release
#   2. applies the 54 patches in whateverxe/patches (the adlp-edp branch)
#   3. fetches the same pinned build dependencies upstream's CI uses
#   4. runs the CPU tests and the RELEASE build
#   5. compares the result with the kext in EFI/OC/Kexts
#
# Needs macOS with the Xcode Command Line Tools, git and python3.
# Byte-identical output needs the same compiler (Apple clang 21.0.0,
# clang-2100.1.1.101, from Command Line Tools 26.6). Lilu stamps the build
# date into every plugin, so it is pinned to the original build's date.
set -e
here=${0:A:h}
repo=${here:h}
work=${1:-$PWD/whateverxe-build}
expected=197da23bbe5a09731ef9517a0a6f9dabe52ab1f9b0c885a841a064190770288c

[[ -e $work ]] && { echo "$work already exists; pass another folder"; exit 1; }
git clone -q https://github.com/b00t0x/WhateverXe $work
cd $work
git checkout -q 7b6b246dd425ff4847ba31dd66c89740e9c712c0   # tag 0.6.0
git -c user.name=build -c user.email=build@localhost am -q $here/patches/*.patch

git clone -q https://github.com/acidanthera/MacKernelSDK MacKernelSDK
git -C MacKernelSDK checkout -q 05094e5e88cec7caedbfb35e8449ed0db94bf95b
git clone -q --depth 1 -b 1.7.2 https://github.com/acidanthera/Lilu build/dependencies/Lilu
mkdir -p Lilu.kext/Contents/Resources
ln -s $work/build/dependencies/Lilu/Lilu/Headers Lilu.kext/Contents/Resources/Headers
ln -s $work/build/dependencies/Lilu/Lilu/Library Lilu.kext/Contents/Resources/Library

python3 tools/test.py
# __DATE__ = Oct 31 2026, as in the original build
SOURCE_DATE_EPOCH=1793448000 python3 tools/build.py --release

built=$work/build/WhateverXe.kext
# The linker's LC_UUID depends on the build folder's path, so it never
# matches across machines. Stamp the original build's UUID; every other byte
# is the compiler's own output.
python3 - $built/Contents/MacOS/WhateverXe <<'P'
import struct, sys, uuid
path = sys.argv[1]
d = bytearray(open(path, 'rb').read())
off = 32
for _ in range(struct.unpack_from('<I', d, 16)[0]):
    cmd, size = struct.unpack_from('<II', d, off)
    if cmd == 0x1B:
        d[off + 8:off + 24] = uuid.UUID('93BA5765-EE4C-3B00-851A-09E56A97AE7B').bytes
        break
    off += size
else:
    sys.exit('no LC_UUID')
open(path, 'wb').write(d)
P
sum=$(shasum -a 256 $built/Contents/MacOS/WhateverXe | cut -d' ' -f1)
echo
echo "Built: $built"
echo "SHA-256: $sum"
if [[ $sum == $expected ]]; then
  echo "Identical to the WhateverXe.kext in this repo's EFI."
else
  echo "Differs from the EFI's kext ($expected)."
  echo "That's expected with a different compiler version; the source is the same."
fi
