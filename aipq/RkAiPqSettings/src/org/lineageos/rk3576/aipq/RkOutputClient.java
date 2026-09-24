package org.lineageos.rk3576.aipq;

/**
 * Thin Java wrapper over the outputmanager HIDL JNI client. Ranges and
 * defaults follow the stock framework shim: all four controls are percent
 * [0, 100]; contrast, saturation and hue default to 50.
 *
 * All methods must be called from a binder/background thread: getService()
 * blocks on first use.
 */
final class RkOutputClient {
    static {
        System.loadLibrary("rkoutputmgr_jni");
    }

    private RkOutputClient() {}

    /** MAIN_DISPLAY in the stock shim. */
    static final int DISPLAY_MAIN = 0;

    /** Fallback when the HAL answers nothing: contrast/sat/hue defaults. */
    static final int[] DEFAULT_BCSH = {50, 50, 50, 50};

    static native boolean nativeIsAvailable();

    /** [brightness, contrast, saturation, hue], or null if unavailable. */
    static native int[] nativeGetBcsh(int dpy);

    static native void nativeSetBrightness(int dpy, int value);
    static native void nativeSetContrast(int dpy, int value);
    static native void nativeSetSaturation(int dpy, int value);
    static native void nativeSetHue(int dpy, int value);
}
