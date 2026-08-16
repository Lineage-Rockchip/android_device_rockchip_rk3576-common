/*
 * Copyright (C) 2026 The LineageOS Project
 *
 * SPDX-License-Identifier: Apache-2.0
 */

/*
 * GraphicBufferMapper::unlockAsync(buffer_handle_t, int*) was an out-of-line
 * method through Android 14. In Android 16 it is defined inline in
 * ui/GraphicBufferMapper.h, so libui.so no longer exports it:
 *
 *     camera.device-internal-impl-rk.so: error: Unresolved symbol:
 *         _ZN7android19GraphicBufferMapper11unlockAsyncEPK13native_handlePi
 *
 * Same shape as CBS_init in crypto_shim.cpp -- a name-only loss, with the
 * implementation still present one call down. This is the RKR8 camera blobs'
 * only unresolved symbol; the two entry points that were genuinely removed
 * (the lock overload with outBytesPerPixel/outBytesPerStride, and the
 * one-argument unlock) are covered by hardware/lineage/compat's libui_shim,
 * which the same blobs already carry.
 *
 * The body is the current inline verbatim, so the fence handoff is unchanged:
 * unlock() hands back an owning fd and the caller takes ownership of the int.
 */

#include <android-base/unique_fd.h>
#include <ui/GraphicBufferMapper.h>
#include <utils/Errors.h>

using android::status_t;

extern "C" {
status_t _ZN7android19GraphicBufferMapper11unlockAsyncEPK13native_handlePi(
        void* thisptr, buffer_handle_t handle, int* fenceFd) {
    auto* gbm = static_cast<android::GraphicBufferMapper*>(thisptr);
    android::base::unique_fd temp;
    status_t result = gbm->unlock(handle, fenceFd ? &temp : nullptr);
    if (fenceFd) {
        *fenceFd = temp.release();
    }
    return result;
}
}
