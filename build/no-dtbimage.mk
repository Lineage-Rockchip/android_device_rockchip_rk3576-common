#
# Copyright (C) 2026 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#
# Deliberately empty. This is BOARD_CUSTOM_DTBIMG_MK, and its only job is to
# take vendor/lineage/build/tasks/kernel.mk down the branch where it does *not*
# define dtb.img itself:
#
#   ifneq ($(BOARD_CUSTOM_DTBIMG_MK),)
#   include $(BOARD_CUSTOM_DTBIMG_MK)
#   else
#     <kernel.mk's own dtb.img rule>
#   endif
#
# dtb.img is defined in build/tasks/dtbimage.mk instead. That rule cannot simply
# be added on top: BUILD_BROKEN_DUP_RULES is false here, so a second recipe for
# the same target is a hard error rather than an override.
#
# kernel.mk's own rule is not merely redundant. It runs a *second* kernel config
# and full dtbs build in its own DTB_OBJ out dir, and then collects from
# $(DTB_OUT)/arch/$(KERNEL_ARCH)/boot/dts/$(dir $(TARGET_DTB_LIST_WILDCARD)) --
# a path that already contains arch/.../boot/dts/, so nothing ever matched and
# dtb.img came out zero bytes ("DTB image must not be empty" from mkbootimg).
# The replacement just copies the dtb the real kernel build already produced.
