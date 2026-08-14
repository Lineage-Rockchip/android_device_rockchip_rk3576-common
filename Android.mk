#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

ifeq ($(TARGET_BOARD_PLATFORM),rk3576)

LOCAL_PATH := $(call my-dir)

# Rockchip keeps resource.img (RSCE container holding the boot logo, battery
# bitmaps and rk-kernel.dtb) in the boot image "second" area. The build system
# only knows how to pass $(PRODUCT_OUT)/2ndbootloader to mkbootimg --second,
# so stage the prebuilt resource image there.
ifeq ($(TARGET_BOOTLOADER_IS_2ND),true)
$(eval $(call copy-one-file,$(TARGET_PREBUILT_RESOURCE_IMAGE),$(PRODUCT_OUT)/2ndbootloader))
endif

include $(call all-makefiles-under,$(LOCAL_PATH))

endif
