#
# Copyright (C) 2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

COMMON_PATH := device/rockchip/rk3576-common

# This directory's Android.bp declares a soong_namespace, so anything defined
# beneath it (libshims/) is invisible until the namespace is imported.
PRODUCT_SOONG_NAMESPACES += $(COMMON_PATH)

## Shipping level
# Stock is already Android 14 / SDK 34 with an FCM target-level 8 vendor image,
# so no VNDK back-compat shims are required.
PRODUCT_SHIPPING_API_LEVEL := 34
PRODUCT_ENFORCE_VINTF_MANIFEST := true

## 64/32-bit (ro.zygote=zygote64_32)
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

## Dynamic partitions
# Without this, board_config.mk never derives BOARD_SUPER_PARTITION_PARTITION_LIST
# from BOARD_SUPER_PARTITION_GROUPS, the sub-partitions are not treated as
# logical, and build_image dies with KeyError: 'partition_size'.
PRODUCT_USE_DYNAMIC_PARTITIONS := true

PRODUCT_BUILD_SYSTEM_EXT_IMAGE := true
PRODUCT_BUILD_PRODUCT_IMAGE := true
PRODUCT_BUILD_VENDOR_DLKM_IMAGE := true
PRODUCT_BUILD_ODM_DLKM_IMAGE := true
PRODUCT_BUILD_SYSTEM_DLKM_IMAGE := true

## Screen density
# Stock ships ro.sf.lcd_density=213 for a 1080p TV panel.
PRODUCT_AAPT_CONFIG := xlarge large tvdpi hdpi xhdpi
PRODUCT_AAPT_PREF_CONFIG := tvdpi
PRODUCT_PROPERTY_OVERRIDES += ro.sf.lcd_density=213

##
## NOTE ON PACKAGE SELECTION
##
## Almost the entire vendor partition is taken from the stock ROM via
## proprietary-files.txt (HALs, their .rc files and VINTF fragments included).
## Only add PRODUCT_PACKAGES entries here for things that are NOT extracted,
## otherwise the build fails with duplicate install rules.
##

##
## HAL INTERFACE AND SUPPORT LIBRARIES FOR THE EXTRACTED BLOBS
##
## Every HAL on this device is a stock prebuilt, so nothing in the build
## declares a dependency on the interface libraries they link against and none
## of them get installed. The blobs then die at exec time with e.g.
##
##   CANNOT LINK EXECUTABLE ".../android.hardware.graphics.composer3-service.rockchip":
##       library "android.hardware.graphics.composer3-V2-ndk.so" not found
##
## taking surfaceflinger, keymint, gralloc and the rest of the HALs with them.
##
## These are built rather than extracted on purpose. AIDL interface versions are
## ABI-frozen, so building the exact version a blob was compiled against is
## equivalent to shipping the stock copy -- and for the plain libraries it is
## strictly safer: the build already installs its own libcrypto.so, and pairing
## that with a stock libssl.so from a different BoringSSL drop would be an ABI
## mismatch. Note the versions differ from what the build otherwise installs
## (it brings V5 graphics.common, V2 allocator, V4 bluetooth.audio); both
## versions coexist happily, they are separate files.
##
## To re-derive this list after changing the blob set:
##   readelf -d on every ELF under $(PRODUCT_OUT)/vendor and $(PRODUCT_OUT)/odm,
##   then subtract vendor/odm lib dirs and system/etc/llndk.libraries.txt.

# Graphics: gralloc (vendor.gralloc-v1) and the Rockchip HWC3 (hwcomposer-3)
PRODUCT_PACKAGES += \
    android.hardware.graphics.allocator-V1-ndk.vendor \
    android.hardware.graphics.common-V4-ndk.vendor \
    android.hardware.graphics.composer3-V2-ndk.vendor \
    android.hardware.graphics.composer@2.1-resources.vendor \
    android.hardware.graphics.composer@2.2-resources.vendor \
    android.hardware.graphics.composer@2.4.vendor

# OP-TEE backed security HALs
PRODUCT_PACKAGES += \
    android.hardware.gatekeeper-V1-ndk.vendor \
    android.hardware.security.keymint-V3-ndk.vendor \
    android.hardware.security.rkp-V3-ndk.vendor \
    android.hardware.security.sharedsecret-V1-ndk.vendor \
    android.hardware.weaver-V2-ndk.vendor \
    libgatekeeper.vendor

# Camera (internal and USB/external Rockchip providers)
PRODUCT_PACKAGES += \
    android.hardware.camera.common-V1-ndk.vendor \
    android.hardware.camera.device-V2-ndk.vendor \
    android.hardware.camera.provider-V2-ndk.vendor

# Wi-Fi: the stock Rockchip HAL, wpa_supplicant and hostapd
PRODUCT_PACKAGES += \
    android.hardware.wifi-V1-ndk.vendor \
    android.hardware.wifi.hostapd-V1-ndk.vendor \
    android.hardware.wifi.supplicant-V2-ndk.vendor \
    libssl.vendor

# Remaining Rockchip HAL services
PRODUCT_PACKAGES += \
    android.frameworks.stats-V1-ndk.vendor \
    android.hardware.bluetooth.audio-V3-ndk.vendor \
    android.hardware.health-V2-ndk.vendor \
    android.hardware.light-V2-ndk.vendor \
    android.hardware.media.bufferpool2-V1-ndk.vendor \
    android.hardware.power-V4-ndk.vendor \
    android.hardware.thermal-V1-ndk.vendor \
    android.hardware.usb-V1-ndk.vendor \
    android.hardware.usb.gadget-V1-ndk.vendor

# Legacy HIDL interfaces. Stock ships both the AIDL and the older HIDL HAL for
# camera, bluetooth, audio and tv.input, and the HIDL halves still need their
# interface libraries to load.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth@1.0.vendor \
    android.hardware.bluetooth.audio@2.0.vendor \
    android.hardware.bluetooth.audio@2.1.vendor \
    android.hardware.camera.common@1.0.vendor \
    android.hardware.camera.device@1.0.vendor \
    android.hardware.camera.device@3.2.vendor \
    android.hardware.camera.device@3.3.vendor \
    android.hardware.camera.device@3.4.vendor \
    android.hardware.camera.device@3.5.vendor \
    android.hardware.camera.device@3.6.vendor \
    android.hardware.camera.provider@2.4.vendor \
    android.hardware.keymaster@3.0.vendor \
    android.hardware.keymaster@4.0.vendor \
    android.hardware.tv.input@1.0.vendor \
    android.hidl.allocator@1.0.vendor

# The two legacy camera provider implementations are "proprietary: true", so
# they install straight to /vendor and take no .vendor suffix -- adding one is
# rejected as a non-existent module.
PRODUCT_PACKAGES += \
    android.hardware.camera.provider@2.4-external \
    android.hardware.camera.provider@2.4-legacy

# HDMI-CEC and HDMI connection, which matter on a TV box
PRODUCT_PACKAGES += \
    android.hardware.tv.hdmi.cec-V1-ndk.vendor \
    android.hardware.tv.hdmi.connection-V1-ndk.vendor

## Shims
# Attached to individual blobs by blob_fixup() in extract-files.sh, which
# patchelf --add-needed's them. libui_shim comes from hardware/lineage/compat.
PRODUCT_PACKAGES += \
    libcrypto_shim \
    libui_shim.vendor

# Plain support libraries the blobs link against
PRODUCT_PACKAGES += \
    android.system.keystore2-V1-ndk.vendor \
    libaudioroute.vendor \
    libavservices_minijail.vendor \
    libbinder.vendor \
    libcamera_metadata.vendor \
    libchrome.vendor \
    libexif.vendor \
    libexpat.vendor \
    libnetutils.vendor \
    libnl.vendor \
    libpng.vendor \
    libprocessgroup.vendor \
    libutilscallstack.vendor \
    libwifi-system-iface.vendor \
    libxml2.vendor

## Audio
# The audio HAL itself (android.hardware.audio.service + impl .so) is extracted;
# only the HIDL interface libraries need building.
PRODUCT_PACKAGES += \
    android.hardware.audio@7.1.vendor \
    android.hardware.audio@7.1-util.vendor \
    android.hardware.audio.common@2.0.vendor \
    android.hardware.audio.common@5.0.vendor \
    android.hardware.audio.common@7.0-util.vendor \
    android.hardware.audio.common@7.1-enums.vendor \
    android.hardware.audio.common@7.1-util.vendor \
    android.hardware.audio.common-util.vendor \
    android.hardware.audio.effect@7.0.vendor \
    android.hardware.audio.effect@7.0-util.vendor

# Bluetooth audio: audiohalservice dlopens android.hardware.bluetooth.audio-impl.so
# and createIBluetoothAudioProviderFactory() from it. The stock blob is excluded by
# gen-proprietary-files.py's AOSP-prefix rule, so build AOSP's module -- it carries
# its own bluetooth_audio.xml VINTF fragment and pulls in
# libbluetooth_audio_session_aidl, both of which replace the stock copies.
#
# Note this tree's latest bluetooth.audio AIDL is V4 while the stock blobs were
# built against V3, so android.hardware.bluetooth.audio-V3-ndk.vendor stays in the
# list above: vendor/lib{,64}/hw/audio.bluetooth.default.so still links it.
PRODUCT_PACKAGES += \
    android.hardware.bluetooth.audio-impl

PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/configs/audio/a2dp_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/a2dp_audio_policy_configuration_7_0.xml \
    $(COMMON_PATH)/configs/audio/audio_effects.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_effects.xml \
    $(COMMON_PATH)/configs/audio/audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration.xml \
    $(COMMON_PATH)/configs/audio/audio_policy_configuration_singlehal.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_configuration_singlehal.xml \
    $(COMMON_PATH)/configs/audio/audio_policy_volumes_drc.xml:$(TARGET_COPY_OUT_VENDOR)/etc/audio_policy_volumes_drc.xml \
    $(COMMON_PATH)/configs/audio/bluetooth_audio_policy_configuration_7_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/bluetooth_audio_policy_configuration_7_0.xml \
    $(COMMON_PATH)/configs/audio/default_volume_tables.xml:$(TARGET_COPY_OUT_VENDOR)/etc/default_volume_tables.xml \
    $(COMMON_PATH)/configs/audio/r_submix_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/r_submix_audio_policy_configuration.xml \
    $(COMMON_PATH)/configs/audio/usb_audio_policy_configuration.xml:$(TARGET_COPY_OUT_VENDOR)/etc/usb_audio_policy_configuration.xml

## Codec 2
# libcodec2_rk_{store,component}.so and libcodec2_hidl_plugin.so are extracted;
# the AOSP framework halves they link against are built here.
PRODUCT_PACKAGES += \
    libcodec2_hidl@1.2.vendor \
    libcodec2_vndk.vendor \
    libcodec2_soft_common.vendor \
    libsfplugin_ccodec_utils.vendor \
    libstagefright_bufferpool@2.0.vendor

PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/configs/media/media_codecs.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs.xml \
    $(COMMON_PATH)/configs/media/media_codecs_c2_base.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_c2_base.xml \
    $(COMMON_PATH)/configs/media/media_codecs_google_c2.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_google_c2.xml \
    $(COMMON_PATH)/configs/media/media_codecs_performance.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_codecs_performance.xml \
    $(COMMON_PATH)/configs/media/media_profiles_V1_0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/media_profiles_V1_0.xml

## Camera
PRODUCT_PACKAGES += \
    libyuv.vendor

## DRM
# ClearKey is built from AOSP source rather than extracted. CAS is dropped
# entirely: stock only shipped AOSP's cas-service.example, which in Android 14
# lives inside the com.android.hardware.cas APEX.
PRODUCT_PACKAGES += \
    android.hardware.drm-service.clearkey

## Display
PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/configs/display/HwComposerEnv.xml:$(TARGET_COPY_OUT_VENDOR)/etc/HwComposerEnv.xml \
    $(COMMON_PATH)/configs/display/display_settings.xml:$(TARGET_COPY_OUT_VENDOR)/etc/display_settings.xml \
    $(COMMON_PATH)/configs/display/package_uimode_config.xml:$(TARGET_COPY_OUT_VENDOR)/etc/package_uimode_config.xml

## Cgroups
PRODUCT_COPY_FILES += \
    system/core/libprocessgroup/profiles/cgroups_28.json:$(TARGET_COPY_OUT_VENDOR)/etc/cgroups.json \
    system/core/libprocessgroup/profiles/task_profiles_28.json:$(TARGET_COPY_OUT_VENDOR)/etc/task_profiles.json

## fstab
# androidboot.hardware=rk30board, so the fstab keeps that suffix. It is needed
# in the first-stage ramdisk and on /vendor for second stage.
PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/init-files/fstab.rk30board:$(TARGET_COPY_OUT_RAMDISK)/fstab.rk30board \
    $(COMMON_PATH)/init-files/fstab.rk30board:$(TARGET_COPY_OUT_VENDOR)/etc/fstab.rk30board

## Recovery init
# Switches recovery's USB gadget to configfs, without which the functionfs
# mounts fail and neither adb nor fastbootd work over USB. See the file itself.
PRODUCT_COPY_FILES += \
    $(COMMON_PATH)/init-files/init.recovery.rk30board.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.rk30board.rc

## fastbootd
# init.rc declares "service fastbootd /system/bin/fastbootd" unconditionally,
# but the binary is only installed when the product asks for it. Without these,
# picking "Enter fastboot" in recovery tears the adb gadget down and then
# nothing replaces it: no adb, no fastboot, and a device that looks hung.
#
# fastbootd also needs IFastboot. Stock shipped Rockchip's own
# android.hardware.fastboot-service.rockchip_recovery in the recovery ramdisk;
# this is the AOSP equivalent, which is enough to flash logical partitions.
# Both modules are "recovery: true", so PRODUCT_PACKAGES puts them in the
# recovery ramdisk rather than on /system.
#
# Deliberately NO android.hardware.boot-service.default_recovery. It is backed
# by libboot_control, which needs A/B slots, and this device is not A/B:
#
#   android.hardware.boot-service.default_recovery: Slot suffix property is not set
#   android.hardware.boot-service.default_recovery: Check failed: impl_.Init()
#
# The HAL aborts, init respawns it once a second forever, and fastbootd never
# finishes starting -- BootControlClient::WaitForService() blocks in
# AServiceManager_waitForService() precisely because installing the HAL is what
# declares the interface in the recovery VINTF manifest. Leave it out and the
# preceding AServiceManager_isDeclared() check fails, boot_control_hal_ stays
# null, and fastbootd carries on; fastboot_device.cpp spells this out at the
# null check: "Non-A/B devices must not have boot control HALs."
#
# The stock recovery shipped it anyway (its manifest has
# android.hardware.boot-service.default.xml), which is presumably why fastbootd
# never worked on the stock ROM either.
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot-service.example_recovery

## Memory allocators used by the Rockchip media/graphics blobs
PRODUCT_PACKAGES += \
    libion \
    libdmabufheap

## Wi-Fi
# The Wi-Fi HAL, wpa_supplicant and hostapd all come from the stock vendor
# image (Rockchip multiplexes AIC8800 / Broadcom / Realtek / SeasonChip via
# libwifi-hal.so + librkwifi-ctrl.so). Only the system-side daemon is built.
PRODUCT_PACKAGES += \
    wificond

## Permissions
# Hardware feature declarations, copied from AOSP rather than extracted.
PRODUCT_COPY_FILES += \
    frameworks/native/data/etc/android.hardware.bluetooth.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth.xml \
    frameworks/native/data/etc/android.hardware.bluetooth_le.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.bluetooth_le.xml \
    frameworks/native/data/etc/android.hardware.camera.external.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.camera.external.xml \
    frameworks/native/data/etc/android.hardware.ethernet.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.ethernet.xml \
    frameworks/native/data/etc/android.hardware.faketouch.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.faketouch.xml \
    frameworks/native/data/etc/android.hardware.hdmi.cec.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.hdmi.cec.xml \
    frameworks/native/data/etc/android.hardware.opengles.aep.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.opengles.aep.xml \
    frameworks/native/data/etc/android.hardware.usb.accessory.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.accessory.xml \
    frameworks/native/data/etc/android.hardware.usb.host.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.usb.host.xml \
    frameworks/native/data/etc/android.hardware.vulkan.compute-0.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.compute-0.xml \
    frameworks/native/data/etc/android.hardware.vulkan.level-1.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.level-1.xml \
    frameworks/native/data/etc/android.hardware.vulkan.version-1_3.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.vulkan.version-1_3.xml \
    frameworks/native/data/etc/android.hardware.wifi.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.xml \
    frameworks/native/data/etc/android.hardware.wifi.direct.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.direct.xml \
    frameworks/native/data/etc/android.hardware.wifi.passpoint.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.hardware.wifi.passpoint.xml \
    frameworks/native/data/etc/android.software.ipsec_tunnels.xml:$(TARGET_COPY_OUT_VENDOR)/etc/permissions/android.software.ipsec_tunnels.xml

## Overlays
DEVICE_PACKAGE_OVERLAYS += $(COMMON_PATH)/overlay

## Inherit from the common proprietary files makefile
$(call inherit-product-if-exists, vendor/rockchip/rk3576-common/rk3576-common-vendor.mk)
