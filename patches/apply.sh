#!/usr/bin/env bash
#
# Apply TWRP source fixes required to build this device tree with the
# twrp-10.0-deprecated manifest (TWRP 10.0 / TeamWin android-10.0 recovery).
#
# Run from the root of the synced TWRP source tree:
#   bash device/Lenovo/TB8505F/patches/apply.sh
#
set -e

PATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_ROOT="$(cd "$PATCH_DIR/../../../.." && pwd)"
cd "$SRC_ROOT"

apply_patch() {
    local patch_file="$1"
    echo "==> Applying $(basename "$patch_file")"
    if git apply --check "$patch_file" 2>/dev/null; then
        git apply "$patch_file"
    else
        # fall back to GNU patch with fuzz for robustness
        patch -p1 --fuzz=3 --forward < "$patch_file"
    fi
}

apply_patch "$PATCH_DIR/0001-vold_decrypt-guard-service-functions.patch"
apply_patch "$PATCH_DIR/0002-vold_decrypt-loginfo.patch"
apply_patch "$PATCH_DIR/0003-vold_decrypt-include-paths.patch"
apply_patch "$PATCH_DIR/0004-vold_decrypt-vdc_pie-disable.patch"
apply_patch "$PATCH_DIR/0005-initrc-import-crypto.patch"
apply_patch "$PATCH_DIR/0006-prebuilt-vdc_pie-sbin.patch"
apply_patch "$PATCH_DIR/0007-vold_decrypt-vdc_pie-sbin.patch"
apply_patch "$PATCH_DIR/0008-vold_decrypt-rc.patch"
apply_patch "$PATCH_DIR/0009-vold_decrypt-hwservicemanager-ready.patch"
apply_patch "$PATCH_DIR/0011-partitionmanager-direct-vold.patch"
apply_patch "$PATCH_DIR/0012-twrp-reboot-meta-restore.patch"
apply_patch "$PATCH_DIR/0013-refuse-auto-scripts.patch"
apply_patch "$PATCH_DIR/0014-refuse-scripts-persist.patch"
apply_patch "$PATCH_DIR/0015-vold-decrypt-keep-system-mounted.patch"

# Replace the prebuilt vdc_pie with the transact-code-fixed binary.
# TWRP's vdc_pie (Pie IVold) calls cryptfs checkpw with transact code 27,
# but Android 10 vold moved fdeCheckPassword to code 29 (mountAppFuse is now
# 27). The unpatched vdc_pie therefore hits mountAppFuse and returns -1 with
# zero vold logs. This copy overwrites the TWRP prebuilt with the patched
# one (movz w1, #27 -> #29).
echo "==> Installing transact-code-fixed vdc_pie (code 29) prebuilt"
VOLD_PIE_DST="bootable/recovery/prebuilt/vdc_pie-arm64"
if [ -f "$VOLD_PIE_DST" ]; then
    cp -f "$PATCH_DIR/vdc_pie-arm64" "$VOLD_PIE_DST"
    chmod 755 "$VOLD_PIE_DST"
    echo "    replaced $VOLD_PIE_DST"
else
    echo "WARNING: $VOLD_PIE_DST not found, patched vdc_pie NOT installed!" >&2
fi

# ziparchive + android-base headers (needed by twrpApex.hpp / twcommon.h,
# which are pulled in via partitions.hpp by several modules).
echo "==> Copying ziparchive and android-base headers into system/core/include"
if [ ! -d system/core/libziparchive/include/ziparchive ]; then
    echo "ERROR: system/core/libziparchive/include/ziparchive not found" >&2
    exit 1
fi
if [ ! -d system/core/base/include/android-base ]; then
    echo "ERROR: system/core/base/include/android-base not found" >&2
    exit 1
fi
mkdir -p system/core/include/ziparchive system/core/include/android-base
cp -f system/core/libziparchive/include/ziparchive/*.h system/core/include/ziparchive/
cp -f system/core/base/include/android-base/*.h system/core/include/android-base/

echo "All patches applied successfully."
