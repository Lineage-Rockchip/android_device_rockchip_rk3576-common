#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

COMMON_PATH := device/rockchip/rk3576-common

# Prebuilt kernel artifacts pulled out of the stock boot.img
KERNEL_PATH := kernel/rockchip/rk3576

## Platform
TARGET_BOARD_PLATFORM := rk3576
TARGET_BOARD_PLATFORM_GPU := mali-g52

## Architecture
# RK3576: 4x Cortex-A72 + 4x Cortex-A53
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := cortex-a53
TARGET_CPU_VARIANT_RUNTIME := cortex-a72

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := cortex-a53
# Stock reports dalvik.vm.isa.arm.variant=cortex-a53 / ro.bionic.2nd_cpu_variant
# =cortex-a53, i.e. the 32-bit runtime targets the little cluster.
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53

TARGET_SUPPORTS_64_BIT_APPS := true

## Bootloader
# The Rockchip loader (MiniLoaderAll.bin + uboot.img) is never rebuilt here.
TARGET_NO_BOOTLOADER := false
TARGET_BOOTLOADER_BOARD_NAME := rk30board

## Kernel
# Stock BSP kernel 6.1.75 (non-GKI) is used as-is; nothing is built from source.
TARGET_NO_KERNEL := false
TARGET_NO_KERNEL_OVERRIDE := true
TARGET_KERNEL_VERSION := 6.1

PRODUCT_COPY_FILES += \
    $(KERNEL_PATH)/Image:kernel

BOARD_KERNEL_IMAGE_NAME := Image

# Matches the stock boot.img header exactly (header v2, 2048 byte pages).
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x10000000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_KERNEL_SECOND_OFFSET := 0x00f00000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
BOARD_DTB_OFFSET := 0x01f00000

BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --second_offset $(BOARD_KERNEL_SECOND_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)

# Rockchip's U-Boot verifies the SHA1 in the boot image header before booting
# (CONFIG_ANDROID_BOOT_IMAGE_HASH). LineageOS' local "--dt" patch to
# system/tools/mkbootimg folds four extra zero bytes into that digest even when
# --dt is unused, so the stock bootloader rejects the image with
# "Failed to load android image". This wrapper rewrites the ID field with the
# upstream digest. It applies to boot.img and recovery.img alike.
BOARD_CUSTOM_MKBOOTIMG := $(COMMON_PATH)/tools/mkbootimg-rk

# androidboot.selinux=permissive matches stock. U-Boot additionally appends
# androidboot.storagemedia, androidboot.mode, androidboot.serialno and earlycon
# at runtime, so they are deliberately not listed here.
BOARD_KERNEL_CMDLINE := console=ttyFIQ0
BOARD_KERNEL_CMDLINE += firmware_class.path=/vendor/etc/firmware
BOARD_KERNEL_CMDLINE += init=/init
BOARD_KERNEL_CMDLINE += rootwait ro
BOARD_KERNEL_CMDLINE += loop.max_part=7
BOARD_KERNEL_CMDLINE += printk.devkmsg=on
BOARD_KERNEL_CMDLINE += kvm-arm.mode=none
BOARD_KERNEL_CMDLINE += androidboot.console=ttyFIQ0
BOARD_KERNEL_CMDLINE += androidboot.wificountrycode=CN
BOARD_KERNEL_CMDLINE += androidboot.hardware=rk30board
BOARD_KERNEL_CMDLINE += androidboot.boot_devices=2a2d0000.ufs,2a330000.mmc
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive

## DTB / DTBO
# The device tree is appended to boot.img rather than shipped in a vendor_boot.
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(KERNEL_PATH)/dtb

# Stock dtbo.img holds a single empty overlay; kept only so the dtbo partition
# is populated with something the bootloader accepts.
BOARD_PREBUILT_DTBOIMAGE := $(KERNEL_PATH)/dtbo.img

## Rockchip resource.img
# Rockchip stores resource.img (RSCE: logo/battery bitmaps + rk-kernel.dtb) in
# the boot image "second" area. TARGET_BOOTLOADER_IS_2ND makes the build pass
# it to mkbootimg via --second; AndroidBoard.mk provides the copy rule.
TARGET_BOOTLOADER_IS_2ND := true
TARGET_PREBUILT_RESOURCE_IMAGE := $(KERNEL_PATH)/resource.img

## Kernel modules
# All stock modules live in vendor_dlkm; odm_dlkm and system_dlkm ship empty.
BOARD_VENDOR_KERNEL_MODULES := $(wildcard $(KERNEL_PATH)/lib/modules/*.ko)
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(KERNEL_PATH)/vendor_dlkm.modules.load 2>/dev/null))

## Verified Boot
# Stock ships a completely unsigned vbmeta (AVB0 header, algorithm 0, no
# descriptors), so the bootloader does not verify anything. Keep it that way.
BOARD_AVB_ENABLE := false

## Partitions
# Non-A/B device with a dedicated recovery partition.
AB_OTA_UPDATER := false

BOARD_USES_METADATA_PARTITION := true

TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
TARGET_USES_MKE2FS := true

BOARD_FLASH_BLOCK_SIZE := 131072

# Super size from the stock dump (level2/config/super_size.txt). Group name and
# the "super size minus 4 MiB of metadata" rule match Rockchip's own BSP
# (device/rockchip/common/build/rockchip/DynamicPartitions.mk).
BOARD_SUPER_PARTITION_SIZE := 4294967296

SSI_PARTITIONS := product system system_dlkm system_ext
TREBLE_PARTITIONS := odm odm_dlkm vendor vendor_dlkm
ALL_PARTITIONS := $(SSI_PARTITIONS) $(TREBLE_PARTITIONS)

BOARD_SUPER_PARTITION_GROUPS := rockchip_dynamic_partitions
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_PARTITION_LIST := $(ALL_PARTITIONS)
# BOARD_SUPER_PARTITION_SIZE - "reasonable overhead of 4 MiB" 4194304
BOARD_ROCKCHIP_DYNAMIC_PARTITIONS_SIZE := $(shell echo $$(($(BOARD_SUPER_PARTITION_SIZE) - 4194304)))

BOARD_BUILD_SUPER_IMAGE_BY_DEFAULT := true
# BUILDING_SUPER_EMPTY_IMAGE is computed by board_config.mk and is KATI_READONLY;
# it follows from PRODUCT_USE_DYNAMIC_PARTITIONS + BOARD_SUPER_PARTITION_SIZE.

BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 4194304

# This is a non-A/B device with a real 384 MiB cache partition (mmcblk2p10),
# which recovery mounts and the block-based OTA uses to stash blocks. The
# generator reads the size from META/misc_info.txt as cache_size; without it
# "make bacon" dies in blockimgdiff.py FindTransfers() on
# "assert cache_size is not None".
# Both variables are required: PROP_DICTIONARY_IMAGES only includes "cache" --
# and therefore only emits cache_size -- when BUILDING_CACHE_IMAGE is set, and
# that is driven by BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE. The resulting empty
# cache.img is a by-product; stock already formatted the partition, so there is
# no need to flash it.
BOARD_CACHEIMAGE_PARTITION_SIZE := 402653184
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := ext4

BOARD_USES_VENDORIMAGE := true
TARGET_COPY_OUT_VENDOR := vendor

BOARD_USES_ODMIMAGE := true
TARGET_COPY_OUT_ODM := odm

BOARD_USES_PRODUCTIMAGE := true
TARGET_COPY_OUT_PRODUCT := product

BOARD_USES_SYSTEM_EXTIMAGE := true
TARGET_COPY_OUT_SYSTEM_EXT := system_ext

BOARD_USES_VENDOR_DLKMIMAGE := true
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm

BOARD_USES_ODM_DLKMIMAGE := true
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm

# Stock ships an (empty) system_dlkm and the fstab mounts it, so it has to be
# built and be part of super.
BOARD_USES_SYSTEM_DLKMIMAGE := true
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := ext4
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm

TARGET_USERIMAGES_SPARSE_EXT_DISABLED := false

## Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init-files/fstab.rk30board
BOARD_USES_RECOVERY_AS_BOOT := false
TARGET_NO_RECOVERY := false
BOARD_INCLUDE_RECOVERY_DTBO := true

## Treble
# Stock vendor is already an Android 14 / FCM target-level 8 image.
PRODUCT_FULL_TREBLE_OVERRIDE := true
# BOARD_VNDK_VERSION is deliberately unset: the VNDK snapshot was removed in
# Android 14 and no LineageOS 21 device tree sets it.
DEVICE_MANIFEST_FILE += $(COMMON_PATH)/manifest.xml
DEVICE_MATRIX_FILE += $(COMMON_PATH)/compatibility_matrix.xml
# Declares the Rockchip-only HIDL HALs (outputmanager, rockit) that appear in no
# AOSP framework compatibility matrix.
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE += \
    $(COMMON_PATH)/vendor_framework_compatibility_matrix.xml

## SELinux
# Stock boots permissive. Kept for bring-up; tighten once the device boots.
BOARD_SEPOLICY_DIRS += $(COMMON_PATH)/sepolicy/vendor
SELINUX_IGNORE_NEVERALLOWS := true

## Properties
TARGET_SYSTEM_PROP += $(COMMON_PATH)/system.prop
TARGET_VENDOR_PROP += $(COMMON_PATH)/vendor.prop
TARGET_PRODUCT_PROP += $(COMMON_PATH)/product.prop

## Graphics
TARGET_USES_HWC2 := true
BOARD_USES_DRM_HWCOMPOSER := true
TARGET_USES_GRALLOC4 := true
# Emits ro.hwui.use_vulkan; must be set here rather than in vendor.prop, or the
# build generates a second, empty assignment and post_process_props rejects it.
TARGET_USES_VULKAN := true

## Media
TARGET_USES_C2_COMPONENT := true

## Wi-Fi (AIC8800D80 over SDIO on mmc0)
# The entire Wi-Fi stack is reused from the stock vendor image: Rockchip's
# libwifi-hal.so multiplexes AIC8800 / Broadcom / Realtek / SeasonChip through
# librkwifi-ctrl.so, and wpa_supplicant + hostapd are extracted too.
#
# BOARD_WLAN_DEVICE is deliberately left unset. Soong only accepts a fixed set
# of values for it (bcmdhd, synadhd, qcwcn, mrvl, nxp, MediaTek, realtek,
# emulator, rtl, slsi, wlan0) and "aic8800" is not among them; setting any of
# them would additionally build AOSP's libwifi-hal, which is proprietary: true
# and would collide with the extracted /vendor/lib64/libwifi-hal.so.
WIFI_DRIVER_SOCKET_IFACE := wlan0

## Bluetooth
BOARD_HAVE_BLUETOOTH := true
BOARD_HAVE_BLUETOOTH_ROCKCHIP := true

## BUILD_BROKEN_*
BUILD_BROKEN_DUP_RULES := true
BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES := true

## Include the common proprietary BoardConfig makefile
-include vendor/rockchip/rk3576-common/BoardConfigVendor.mk
