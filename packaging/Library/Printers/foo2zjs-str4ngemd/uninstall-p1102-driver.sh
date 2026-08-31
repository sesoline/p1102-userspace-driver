#!/bin/bash
# Uninstaller for the HP LaserJet P1102/P1102w driver installed by the pkg.
# Run as: sudo bash /Library/Printers/foo2zjs-str4ngemd/uninstall-p1102-driver.sh
set -e

echo "Uninstalling HP LaserJet P1102 driver (foo2zjs-str4ngemd)..."

/bin/launchctl unload /Library/LaunchAgents/com.str4ngemd.p1102-fw-uploader.plist >/dev/null 2>&1 || true
rm -f /Library/LaunchAgents/com.str4ngemd.p1102-fw-uploader.plist
rm -rf /Library/Printers/foo2zjs-str4ngemd
rm -f "/Library/Printers/PPDs/Contents/Resources/HP_LaserJet_Professional_P1102_Native.ppd"

/usr/bin/launchctl kickstart -k system/org.cups.cupsd >/dev/null 2>&1 || true

echo "Driver removed."
echo "You can also remove the printer from System Settings > Printers & Scanners if it still appears."
