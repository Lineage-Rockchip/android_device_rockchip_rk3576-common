#!/usr/bin/env python3
#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
"""Flip a dwc3 controller's dr_mode inside a Rockchip resource.img.

The stock H96 Max M9S device tree declares both USB3 controllers host-only:

    usb@23000000 { compatible = "rockchip,rk3576-dwc3"; dr_mode = "host"; ... };
    usb@23400000 { compatible = "rockchip,rk3576-dwc3"; dr_mode = "host"; ... };

so Linux never registers a UDC, /sys/class/udc stays empty, sys.usb.controller
is never set, and recovery cannot bring up adb or fastbootd over USB:

    write /config/usb_gadget/g1/UDC ${sys.usb.controller}
        failed: property 'sys.usb.controller' doesn't exist

This is stock behaviour, not a LineageOS regression -- the stock recovery fails
the same way. Full Android gets away with it because it drives the gadget
through Rockchip's USB gadget HAL instead of init.rc.

U-Boot's own rk3576.dtsi declares dr_mode = "otg" for usb_drd0_dwc3, which is
why fastboot works from the bootloader on the very same port. Only the kernel
device tree disagrees, so "otg" is a safe value here: usb@23000000 already
carries extcon = <&u2phy0> and that phy's otg-port has otg-id / otg-bvalid /
linestate interrupts, i.e. everything role detection needs.

  === Why an in-place byte patch rather than dtc round-trip ===

"host\\0" is five bytes and "otg\\0" is four, so recompiling would change the
property length, shift every following offset in the structure block, and
change the DTB size -- which in turn moves every block offset in resource.img.
Decompiling and recompiling a vendor DTB with dtc can also perturb phandle
ordering and reserved-memory entries.

Instead the value is overwritten as "otg\\0\\0", keeping the declared length at
five. FDT pads property values to four bytes, so the on-disk footprint is
identical and nothing moves. The kernel reads it correctly:
of_property_read_string() only requires strnlen(value, len) < len -- here
strnlen("otg\\0\\0", 5) == 3 -- and usb_get_dr_mode_from_string() then does a
plain strcmp against "otg".

Only the SHA1 that resource.img stores for the entry has to be recomputed;
U-Boot checks it and prints "HASH(ce): OK" when it matches.

Usage:
    patch-dtb-dr-mode.py <in.img> <out.img> [--node usb@23000000] [--mode otg]
    patch-dtb-dr-mode.py --dtb <in.dtb> <out.dtb> [...]
"""

import argparse
import hashlib
import struct
import sys

# resource.img, see u-boot tools/rockchip/resource_tool.c
RSCE_MAGIC = b'RSCE'
ENTR_TAG = b'ENTR'
BLOCK_SIZE = 512
ENTRY_PATH_LEN = 220
ENTRY_HASH_LEN = 32

# Flattened device tree, see scripts/dtc/libfdt/fdt.h
FDT_MAGIC = 0xd00dfeed
FDT_BEGIN_NODE = 1
FDT_END_NODE = 2
FDT_PROP = 3
FDT_NOP = 4
FDT_END = 9


def find_property(dtb, node_name, prop_name):
    """Return (offset, length) of a property's value within the DTB."""
    magic, _, off_struct, off_strings = struct.unpack_from('>IIII', dtb, 0)
    if magic != FDT_MAGIC:
        raise ValueError(f'not a DTB: magic {magic:#x}')

    want = prop_name.encode()
    path = []
    pos = off_struct
    while True:
        token, = struct.unpack_from('>I', dtb, pos)
        pos += 4
        if token == FDT_BEGIN_NODE:
            end = dtb.index(b'\0', pos)
            path.append(dtb[pos:end].decode())
            pos = (end + 4) & ~3
        elif token == FDT_END_NODE:
            path.pop()
            pos = (pos + 3) & ~3
        elif token == FDT_PROP:
            length, nameoff = struct.unpack_from('>II', dtb, pos)
            pos += 8
            name_end = dtb.index(b'\0', off_strings + nameoff)
            name = dtb[off_strings + nameoff:name_end]
            if name == want and path and path[-1] == node_name:
                return pos, length
            pos = (pos + length + 3) & ~3
        elif token == FDT_NOP:
            continue
        elif token == FDT_END:
            raise KeyError(f'{node_name}/{prop_name} not found')
        else:
            raise ValueError(f'bad FDT token {token} at {pos - 4:#x}')


def patch_dtb(dtb, node_name, mode):
    """Rewrite node_name's dr_mode, keeping the property length unchanged."""
    offset, length = find_property(dtb, node_name, 'dr_mode')
    old = bytes(dtb[offset:offset + length])
    new = mode.encode() + b'\0'
    if len(new) > length:
        raise ValueError(
            f'"{mode}" needs {len(new)} bytes but dr_mode holds only {length}; '
            'an in-place patch cannot grow the property')
    new = new.ljust(length, b'\0')
    if old == new:
        return False
    print(f'  {node_name}: dr_mode {old!r} -> {new!r}')
    dtb[offset:offset + length] = new
    return True


def patch_resource(data, node_name, mode):
    """Patch rk-kernel.dtb inside a resource.img and refresh its hash."""
    if data[:4] != RSCE_MAGIC:
        raise ValueError('not a resource.img (no RSCE magic)')
    tbl_offset, entry_blocks = data[9], data[10]
    entry_count, = struct.unpack_from('<I', data, 12)

    for i in range(entry_count):
        base = (tbl_offset + i * entry_blocks) * BLOCK_SIZE
        if data[base:base + 4] != ENTR_TAG:
            raise ValueError(f'entry {i} is not tagged ENTR')
        path = data[base + 4:base + 4 + ENTRY_PATH_LEN].split(b'\0')[0]
        if not path.endswith(b'.dtb'):
            continue

        hash_base = base + 4 + ENTRY_PATH_LEN
        hash_size, = struct.unpack_from('<I', data, hash_base + ENTRY_HASH_LEN)
        content_blk, = struct.unpack_from('<I', data, hash_base + ENTRY_HASH_LEN + 4)
        content_size, = struct.unpack_from('<I', data, hash_base + ENTRY_HASH_LEN + 8)
        start = content_blk * BLOCK_SIZE
        dtb = bytearray(data[start:start + content_size])

        stored = bytes(data[hash_base:hash_base + hash_size])
        digest = {20: hashlib.sha1, 32: hashlib.sha256}.get(hash_size)
        if digest is None:
            raise ValueError(f'unexpected hash size {hash_size}')
        if digest(dtb).digest() != stored:
            raise ValueError(f'{path.decode()}: stored hash does not match '
                             'its content; refusing to touch it')

        print(f'{path.decode()} ({content_size} bytes at block {content_blk})')
        if not patch_dtb(dtb, node_name, mode):
            print('  already set, nothing to do')
            return False

        data[start:start + content_size] = dtb
        new_hash = digest(dtb).digest()
        data[hash_base:hash_base + hash_size] = new_hash
        print(f'  hash {stored.hex()} -> {new_hash.hex()}')
        return True

    raise KeyError('no .dtb entry in resource.img')


def main():
    parser = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    parser.add_argument('source')
    parser.add_argument('output')
    parser.add_argument('--node', default='usb@23000000',
                        help='device tree node to patch (default: the OTG-capable '
                             'controller, usb@23000000)')
    parser.add_argument('--mode', default='otg', choices=['otg', 'peripheral', 'host'])
    parser.add_argument('--dtb', action='store_true',
                        help='source is a bare .dtb rather than a resource.img')
    args = parser.parse_args()

    with open(args.source, 'rb') as f:
        data = bytearray(f.read())

    if args.dtb:
        changed = patch_dtb(data, args.node, args.mode)
    else:
        changed = patch_resource(data, args.node, args.mode)

    if not changed:
        return 1

    with open(args.output, 'wb') as f:
        f.write(data)
    print(f'wrote {args.output} ({len(data)} bytes)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
