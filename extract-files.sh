#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2025 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"
                shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

# The stock vendor image is Android 14 / SDK 34 with an FCM target-level 8
# manifest, so it links against the same VNDK generation LineageOS 21 builds --
# but Rockchip's RKR SDK snapshot predates a couple of upstream symbol removals.
function blob_fixup() {
    case "${1}" in
        # Rockchip's camera implementations call two libui entry points that
        # Android 14 dropped: the GraphicBufferMapper::lock overload taking
        # outBytesPerPixel/outBytesPerStride, and the single-argument
        # GraphicBufferMapper::unlock. Both are GLOBAL (not weak) undefined
        # symbols, so the camera provider services fail to link outright:
        #
        #   CANNOT LINK EXECUTABLE ".../android.hardware.camera.provider-V1-service":
        #     cannot locate symbol "_ZN7android19GraphicBufferMapper4lockE..."
        #     referenced by "/vendor/lib64/camera.device-internal-impl-rk.so"
        #
        # hardware/lineage/compat's libui_shim defines exactly those two
        # symbols, forwarding to the overloads that survived.
        vendor/lib/camera.device-external-impl-rk.so | \
        vendor/lib64/camera.device-external-impl-rk.so | \
        vendor/lib64/camera.device-internal-impl-rk.so)
            [ "$2" = "" ] && return 0
            grep -q "libui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libui_shim.so" "${2}"
            ;;
        # wpa_supplicant references sk_dup, which BoringSSL renamed to
        # OPENSSL_sk_dup. See libshims/crypto_shim.cpp.
        vendor/bin/hw/wpa_supplicant)
            [ "$2" = "" ] && return 0
            grep -q "libcrypto_shim.so" "${2}" || "${PATCHELF}" --add-needed "libcrypto_shim.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for the common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON:-$VENDOR}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../../${VENDOR_BRAND}/${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for the device
    source "${MY_DIR}/../../${VENDOR_BRAND}/${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../../${VENDOR_BRAND}/${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
