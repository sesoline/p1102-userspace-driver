#!/bin/bash
# Build script: creates a universal macOS installer (.pkg) and a .dmg
# for the HP LaserJet P1102/P1102w driver.
#
# Usage:
#   ./packaging/build-pkg.sh [VERSION]     (default version: 1.0.0)
#
# Requirements: Xcode Command Line Tools (clang, swiftc) plus pkgbuild,
# productbuild, hdiutil and git (all standard on macOS). No sudo needed
# to build; the pkg installer itself will ask for the admin password.
set -euo pipefail

VERSION="${1:-1.0.0}"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORK_DIR="$(mktemp -d /tmp/p1102-pkg.XXXXXX)"
PAYLOAD="$WORK_DIR/root"
OUT_DIR="$REPO_DIR/dist"

trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Checking tools..."
for t in clang swiftc pkgbuild productbuild hdiutil git lipo sed; do
    command -v "$t" >/dev/null 2>&1 || { echo "ERROR: missing tool: $t (run: xcode-select --install)"; exit 1; }
done

mkdir -p "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/filter"
mkdir -p "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/bin"
mkdir -p "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/firmware"
mkdir -p "$PAYLOAD/Library/Printers/PPDs/Contents/Resources"
mkdir -p "$PAYLOAD/Library/LaunchAgents"
mkdir -p "$OUT_DIR"

echo "==> Compiling universal rastertozjs (arm64 + x86_64) from OpenPrinting/foo2zjs + patch..."
FOO2ZJS_SRC="$WORK_DIR/foo2zjs"
git clone --depth 1 https://github.com/OpenPrinting/foo2zjs.git "$FOO2ZJS_SRC" >/dev/null 2>&1
(cd "$FOO2ZJS_SRC" && patch -p1 < "$REPO_DIR/foo2zjs_cups.patch" >/dev/null)
clang -O2 -Wall -DcupsFilter -I"$FOO2ZJS_SRC" -lcups -arch arm64 -arch x86_64 \
    "$FOO2ZJS_SRC/foo2zjs.c" "$FOO2ZJS_SRC/jbig.c" "$FOO2ZJS_SRC/jbig_ar.c" \
    -o "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/filter/rastertozjs"

echo "==> Compiling universal firmware uploader (arm64 + x86_64)..."
swiftc -O -target arm64-apple-macosx14.0 "$REPO_DIR/p1102_fw_uploader.swift" -o "$WORK_DIR/up_arm"
swiftc -O -target x86_64-apple-macosx14.0 "$REPO_DIR/p1102_fw_uploader.swift" -o "$WORK_DIR/up_x86"
lipo -create "$WORK_DIR/up_arm" "$WORK_DIR/up_x86" \
    -output "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/bin/p1102_fw_uploader"

echo "==> Copying firmware, PPD, launchd agent and uninstaller..."
cp "$REPO_DIR/firmware/sihpP1102.dl" "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/firmware/"
cp "$REPO_DIR/HP_LaserJet_Professional_P1102.ppd" \
    "$PAYLOAD/Library/Printers/PPDs/Contents/Resources/HP_LaserJet_Professional_P1102_Native.ppd"
cp "$REPO_DIR/packaging/Library/LaunchAgents/com.str4ngemd.p1102-fw-uploader.plist" \
    "$PAYLOAD/Library/LaunchAgents/"
cp "$REPO_DIR/packaging/Library/Printers/foo2zjs-str4ngemd/uninstall-p1102-driver.sh" \
    "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/"

echo "==> Stripping extended attributes (avoid AppleDouble files in payload)..."
xattr -cr "$PAYLOAD" 2>/dev/null || true

chmod 0555 "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/filter/rastertozjs"
chmod 0755 "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/bin/p1102_fw_uploader"
chmod 0755 "$PAYLOAD/Library/Printers/foo2zjs-str4ngemd/uninstall-p1102-driver.sh"

echo "==> Building component package..."
pkgbuild --root "$PAYLOAD" \
    --identifier com.sesoline.p1102-userspace-driver \
    --version "$VERSION" \
    --ownership recommended \
    --scripts "$REPO_DIR/packaging/scripts" \
    "$WORK_DIR/p1102-userspace-driver-$VERSION.pkg"

echo "==> Building product archive..."
sed "s/@VERSION@/$VERSION/g" "$REPO_DIR/packaging/Distribution.xml" > "$WORK_DIR/Distribution.xml"
(cd "$WORK_DIR" && productbuild --distribution Distribution.xml \
    --resources "$REPO_DIR/packaging" \
    --package-path "$WORK_DIR" \
    "p1102-userspace-driver-$VERSION.pkg")

cp "$WORK_DIR/p1102-userspace-driver-$VERSION.pkg" "$OUT_DIR/"

echo "==> Creating disk image..."
mkdir -p "$WORK_DIR/dmg"
cp "$WORK_DIR/p1102-userspace-driver-$VERSION.pkg" "$WORK_DIR/dmg/"
hdiutil create -volname "P1102 Driver $VERSION" \
    -srcfolder "$WORK_DIR/dmg" -ov -format UDZO \
    "$OUT_DIR/p1102-userspace-driver-$VERSION.dmg" >/dev/null

echo ""
echo "Done:"
ls -la "$OUT_DIR/p1102-userspace-driver-$VERSION.pkg" "$OUT_DIR/p1102-userspace-driver-$VERSION.dmg"
echo ""
echo "Note: the package is not code-signed (no Apple Developer ID)."
echo "Downloaded copies may show an 'unidentified developer' warning;"
echo "users can allow it via System Settings > Privacy & Security."
