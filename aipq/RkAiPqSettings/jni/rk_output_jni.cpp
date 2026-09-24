// JNI client for rockchip.hardware.outputmanager@1.0 (hw_output.default.so,
// served by vendor.outputmanager-1-0). The pattern is the one proven on
// stock: frameworks' com_android_server_rkdisplay_RkDisplayModes.cpp calls
// IRkOutputManager::getService() from a system process -- the binderized path
// through hwservicemanager, no passthrough dlopen. Values are the percent
// scales documented in the stock framework shim
// (frameworks/base/.../RkDisplayOutputManager.java): brightness, contrast,
// saturation and hue all [0, 100], contrast/saturation/hue default 50.

#include <jni.h>

#include <android/log.h>
#include <hidl/HidlSupport.h>
#include <log/log.h>

#include <rockchip/hardware/outputmanager/1.0/IRkOutputManager.h>

using rockchip::hardware::outputmanager::V1_0::IRkOutputManager;
using rockchip::hardware::outputmanager::V1_0::Result;

using android::hardware::hidl_vec;

namespace {

android::sp<IRkOutputManager> gService;

bool ensureService() {
    if (gService == nullptr) {
        gService = IRkOutputManager::getService();
        if (gService != nullptr) {
            gService->initial();
        } else {
            ALOGE("rkoutput: failed to get IRkOutputManager/default");
        }
    }
    return gService != nullptr;
}

void saveConfig() {
    if (gService != nullptr) {
        gService->saveConfig();
    }
}

}  // namespace

extern "C" {

JNIEXPORT jboolean JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeIsAvailable(JNIEnv*, jobject) {
    return ensureService();
}

// Returns [brightness, contrast, saturation, hue] or null when unavailable.
JNIEXPORT jintArray JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeGetBcsh(JNIEnv* env, jobject, jint dpy) {
    if (!ensureService()) {
        return nullptr;
    }
    Result status = Result::UNKNOWN;
    std::vector<uint32_t> bcsh;
    auto cb = [&](Result r, const hidl_vec<uint32_t>& values) {
        status = r;
        if (r == Result::OK) {
            bcsh = values;
        }
    };
    gService->getBcsh(static_cast<uint64_t>(dpy), cb);
    if (status != Result::OK || bcsh.size() < 4) {
        ALOGE("rkoutput: getBcsh failed, status=%d size=%zu",
              static_cast<int>(status), bcsh.size());
        return nullptr;
    }
    jint out[4] = {static_cast<jint>(bcsh[0]), static_cast<jint>(bcsh[1]),
                   static_cast<jint>(bcsh[2]), static_cast<jint>(bcsh[3])};
    jintArray result = env->NewIntArray(4);
    if (result != nullptr) {
        env->SetIntArrayRegion(result, 0, 4, out);
    }
    return result;
}

JNIEXPORT void JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeSetBrightness(JNIEnv*, jobject, jint dpy,
                                                                  jint value) {
    if (ensureService()) {
        gService->setBrightness(static_cast<uint64_t>(dpy), static_cast<uint32_t>(value));
        saveConfig();
    }
}

JNIEXPORT void JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeSetContrast(JNIEnv*, jobject, jint dpy,
                                                                jint value) {
    if (ensureService()) {
        gService->setContrast(static_cast<uint64_t>(dpy), static_cast<uint32_t>(value));
        saveConfig();
    }
}

JNIEXPORT void JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeSetSaturation(JNIEnv*, jobject, jint dpy,
                                                                  jint value) {
    if (ensureService()) {
        gService->setSaturation(static_cast<uint64_t>(dpy), static_cast<uint32_t>(value));
        saveConfig();
    }
}

JNIEXPORT void JNICALL
Java_org_lineageos_rk3576_aipq_RkOutputClient_nativeSetHue(JNIEnv*, jobject, jint dpy,
                                                           jint value) {
    if (ensureService()) {
        gService->setHue(static_cast<uint64_t>(dpy), static_cast<uint32_t>(value));
        saveConfig();
    }
}

}  // extern "C"
