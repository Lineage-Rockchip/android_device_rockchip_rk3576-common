#!/bin/bash
#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Rebuild kernel/rockchip/rk3576/resource.img around a freshly built device tree.
#
# Rockchip's resource.img is an "RSCE" container that rides in the boot image
# "second" area (BoardConfigCommon.mk sets TARGET_BOOTLOADER_IS_2ND). It holds
# the boot logo, the battery bitmaps and -- the part that matters here -- a copy
# of the device tree named rk-kernel.dtb, which U-Boot reads.
#
# That copy is live: it is not merely decorative, which is why the old
# patch-dtb-dr-mode.py had to patch resource.img and not just the appended dtb.
# So whenever the kernel device tree changes, this image has to be repacked or
# the board boots a new kernel against an old device tree.
#
# The packer is Rockchip's own scripts/resource_tool, built as a host tool by
# any kernel build, so point KERNEL_OUT at one.
#
# Usage:
#   tools/pack-resource-img.sh <new-rk-kernel.dtb> [kernel-out-dir]
#
# Entry order is preserved exactly as stock shipped it. U-Boot looks entries up
# by name so order should not matter, but there is no reason to find out.

set -euo pipefail

DTB=${1:?usage: $0 <new-rk-kernel.dtb> [kernel-out-dir]}
KERNEL_OUT=${2:-/home/tomin/devel/rk3576-kbuild}

TOOL=$KERNEL_OUT/scripts/resource_tool
IMG=$(cd "$(dirname "$0")/../../../../kernel/rockchip/rk3576" && pwd)/resource.img

[ -x "$TOOL" ] || { echo "no resource_tool at $TOOL -- build the kernel first"; exit 1; }
[ -f "$DTB" ]  || { echo "no dtb at $DTB"; exit 1; }
[ -f "$IMG" ]  || { echo "no resource.img at $IMG"; exit 1; }

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Unpack the current image so the logo and battery bitmaps come along unchanged.
( cd "$WORK" && "$TOOL" --unpack --image="$IMG" >/dev/null )
cp "$DTB" "$WORK/out/rk-kernel.dtb"

( cd "$WORK/out" && "$TOOL" --pack --root=. --image="$WORK/new.img" \
    rk-kernel.dtb \
    battery_1.bmp battery_2.bmp battery_3.bmp battery_4.bmp battery_5.bmp \
    battery_fail.bmp logo.bmp logo_kernel.bmp battery_0.bmp >/dev/null )

# Round-trip the result before letting it near the tree.
( cd "$WORK" && mkdir -p check && cd check && "$TOOL" --unpack --image="$WORK/new.img" >/dev/null )
cmp "$WORK/check/out/rk-kernel.dtb" "$DTB"
for f in battery_0 battery_1 battery_2 battery_3 battery_4 battery_5 battery_fail logo logo_kernel; do
    cmp "$WORK/check/out/$f.bmp" "$WORK/out/$f.bmp"
done

cp "$WORK/new.img" "$IMG"
echo "resource.img rebuilt: $(stat -c%s "$IMG") bytes, rk-kernel.dtb = $(stat -c%s "$DTB") bytes"
