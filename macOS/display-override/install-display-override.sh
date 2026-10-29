#!/bin/zsh
# Installs a HiDPI (Retina) display override for the Samsung SDC 4166 OLED.
# Undo: sudo zsh install-display-override.sh --uninstall
set -e
dir=/Library/Displays/Contents/Resources/Overrides/DisplayVendorID-4c83
if [[ "$1" == --uninstall ]]; then rm -f $dir/DisplayProductID-4166; echo "removed; reboot"; exit 0; fi
mkdir -p $dir
cp "${0:A:h}/DisplayProductID-4166" $dir/
chown root:wheel $dir/DisplayProductID-4166; chmod 644 $dir/DisplayProductID-4166
echo "installed $dir/DisplayProductID-4166; reboot"
