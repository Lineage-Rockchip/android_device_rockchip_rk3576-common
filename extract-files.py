#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: 2025 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)

from extract_utils.fixups_lib import (
    lib_fixups as lib_fixups_default,
    lib_fixups_user_type,
)

from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

# libshims/ is behind a soong_namespace, so the generated vendor blueprint has
# to import it.
namespace_imports = [
    'device/rockchip/rk3576-common',
]

GRAPHICS_COMMON_V4 = 'android.hardware.graphics.common-V4-ndk.so'
GRAPHICS_COMMON_CURRENT = 'android.hardware.graphics.common-V7-ndk.so'

blob_fixups: blob_fixups_user_type = {
    # Rockchip's camera impls call two libui entry points Android 14 dropped:
    # the GraphicBufferMapper::lock overload taking outBytesPerPixel/
    # outBytesPerStride, and the single-argument unlock. compat's libui_shim
    # forwards both to the overloads that survived.
    (
        'vendor/lib/camera.device-external-impl-rk.so',
        'vendor/lib64/camera.device-external-impl-rk.so',
        'vendor/lib64/camera.device-internal-impl-rk.so',
    ): blob_fixup()
        .add_needed('libui_shim.so')
        .replace_needed(GRAPHICS_COMMON_V4, GRAPHICS_COMMON_CURRENT),
    # graphics.common is at V7 tree-side, and Soong rejects two versions of one
    # aidl_interface in a single dependency graph. The interface is types-only
    # and AIDL is ABI-compatible upwards.
    (
        'vendor/bin/hw/android.hardware.graphics.allocator-V1-service',
        'vendor/lib/egl/libGLES_mali.so',
        'vendor/lib64/egl/libGLES_mali.so',
        'vendor/lib/hw/android.hardware.graphics.allocator-V1-arm.so',
        'vendor/lib64/hw/android.hardware.graphics.allocator-V1-arm.so',
        'vendor/lib/hw/android.hardware.graphics.allocator-V1-bifrost.so',
        'vendor/lib64/hw/android.hardware.graphics.allocator-V1-bifrost.so',
        'vendor/lib/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so',
        'vendor/lib64/hw/android.hardware.graphics.mapper@4.0-impl-bifrost.so',
    ): blob_fixup()
        .replace_needed(GRAPHICS_COMMON_V4, GRAPHICS_COMMON_CURRENT),
    # Same problem for IAllocator: stock mixes V1 and V2 clients. Bumping a
    # client is safe; the V1 *service* is deliberately left alone, because
    # relinking a server would have it advertise methods it does not implement.
    (
        'vendor/lib/hw/camera.rk30board.so',
        'vendor/lib64/hw/camera.rk30board.so',
    ): blob_fixup()
        .replace_needed(
            'android.hardware.graphics.allocator-V1-ndk.so',
            'android.hardware.graphics.allocator-V2-ndk.so',
        ),
    # wpa_supplicant references sk_dup (renamed OPENSSL_sk_dup; see
    # libshims/crypto_shim.cpp) and CBS_init (now OPENSSL_INLINE, so no longer
    # exported; compat's libcrypto_shim is exactly that function). Deliberately
    # not libcrypto-v33: there is no libssl-v33, and wpa_supplicant links libssl
    # too, which would leave one BoringSSL linked against another.
    'vendor/bin/hw/wpa_supplicant': blob_fixup()
        .add_needed('libcrypto_shim_rk.so')
        .add_needed('libcrypto_shim.so'),
    # Arm ships this as vulkan.mali.so and Rockchip renamed the file without
    # touching the ELF, which check_elf_file rejects.
    (
        'vendor/lib/hw/vulkan.rk3576.so',
        'vendor/lib64/hw/vulkan.rk3576.so',
    ): blob_fixup()
        .fix_soname(),
    # cppbor::Item gained two virtual methods since Android 14, so the Android
    # 14 library is extracted rather than built (BRINGUP-NOTES.md section 7.7).
    # It cannot keep its own name, hence the rename in gen-proprietary-files.py
    # and these NEEDED rewrites to match.
    (
        'vendor/bin/hw/android.hardware.security.keymint-service.optee',
        'vendor/lib64/libRkcppcose_rkp.so',
        'vendor/lib64/libRkkeymaster_portable.so',
        'vendor/lib64/libRkkeymint.so',
        'vendor/lib64/libRkpuresoftkeymasterdevice.so',
        'vendor/lib64/libRksoftkeymasterdevice.so',
    ): blob_fixup()
        .replace_needed(
            'libcppbor_external.so',
            'libcppbor_external_rk.so',
        ),
    # The whole KeyMint process onto the Android 13 VNDK snapshot in
    # hardware/lineage/compat. This list is the *whole* process, deliberately:
    # half-migrating would put two BoringSSLs in one address space.
    (
        'vendor/bin/hw/android.hardware.security.keymint-service.optee',
        'vendor/lib64/libRkTeeKeymaster.so',
        'vendor/lib64/libRkcppcose_rkp.so',
        'vendor/lib64/libRkkeymaster4.so',
        'vendor/lib64/libRkkeymaster_portable.so',
        'vendor/lib64/libRkkeymint.so',
        'vendor/lib64/libRkpuresoftkeymasterdevice.so',
        'vendor/lib64/libRksoftkeymasterdevice.so',
        'vendor/lib64/libcppbor_external_rk.so',
    ): blob_fixup()
        .replace_needed('libcrypto.so', 'libcrypto-v33.so'),
    # Same process, same reasoning, for libbase.
    (
        'vendor/bin/hw/android.hardware.security.keymint-service.optee',
        'vendor/lib64/libRkkeymaster4.so',
        'vendor/lib64/libRkkeymint.so',
        'vendor/lib64/libRkpuresoftkeymasterdevice.so',
        'vendor/lib64/libRksoftkeymasterdevice.so',
        'vendor/lib64/lib_Rk_keymaster_keymint_utils.so',
        'vendor/lib64/libcppbor_external_rk.so',
    ): blob_fixup()
        .replace_needed('libbase.so', 'libbase-v33.so'),
    # sizeof(tinyxml2::XMLDocument) went 776 -> 880 between 9.0.0 and 11.0.0.
    # Each of these blobs declares one as a *local*, so it reserves the Android
    # 14 size and the current library constructs 104 bytes past the end of it,
    # into the caller's frame. That is what crash-loops the composer, lights and
    # camera services. BRINGUP-NOTES.md section 7.12.
    #
    # hwcomposer.rk30board.so deliberately has no libui-v34 fixup: it had one on
    # the vtable theory and it changed nothing (test131/133 vs test128/130).
    (
        'vendor/bin/hw/android.hardware.camera.provider-V1-external-service-rk',
        'vendor/bin/hw/android.hardware.lights-service.rockchip',
        'vendor/lib/android.hardware.camera.provider-V1-external-impl-rk.so',
        'vendor/lib/camera.device-external-impl-rk.so',
        'vendor/lib/hw/hwcomposer.rk30board.so',
        'vendor/lib64/android.hardware.camera.provider-V1-external-impl-rk.so',
        'vendor/lib64/camera.device-external-impl-rk.so',
        'vendor/lib64/camera.device-internal-impl-rk.so',
        'vendor/lib64/hw/hwcomposer.rk30board.so',
    ): blob_fixup()
        .replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so'),
    # The same shape one layer up: ComposerResources embeds
    # ComposerHandleImporter by value, which lost 16 bytes since Android 14, and
    # the blob instantiates it itself through an inline create(). compat's
    # composer_utils is that Android 14 source under a -v34 name.
    # BRINGUP-NOTES.md section 7.13.
    'vendor/bin/hw/android.hardware.graphics.composer3-service.rockchip': blob_fixup()
        .replace_needed(
            'android.hardware.graphics.composer@2.1-resources.so',
            'android.hardware.graphics.composer@2.1-resources-v34.so',
        ),
}  # fmt: skip

# Libraries extracted under -rockchip module names (MODULE_SUFFIX_BASENAMES in
# gen-proprietary-files.py). A module rename does not rewrite the DT_NEEDED
# entries that name the library, so map them here too.
suffixed_libs = (
    'libwifi-hal-aic',
    'libwifi-hal-bcm',
    'libwifi-hal-bes',
    'libwifi-hal-rtk',
    'libwifi-hal-skw',
)


def lib_fixup_rockchip(lib: str, partition: str, *args, **kwargs):
    return f'{lib}-rockchip' if partition in ('odm', 'vendor') else lib


lib_fixups: lib_fixups_user_type = {
    **lib_fixups_default,
    suffixed_libs: lib_fixup_rockchip,
}

module = ExtractUtilsModule(
    'rk3576-common',
    'rockchip',
    blob_fixups=blob_fixups,
    lib_fixups=lib_fixups,
    namespace_imports=namespace_imports,
)

if __name__ == '__main__':
    utils = ExtractUtils.device(module)
    utils.run()
