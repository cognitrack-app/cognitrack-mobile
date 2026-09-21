package com.cognitrack.cognitrack_mobile

/**
 * Shared launcher and system packages to exclude from usage stats tracking.
 *
 * Pressing Home fires MOVE_TO_FOREGROUND for the active launcher, which would
 * count as a context switch to 'tools' and inflate switch counts on every device.
 * This set covers all major OEMs and is shared between UsageStatsPlugin and
 * ForegroundService to ensure consistent filtering.
 */
object ExcludedPackages {
    const val LAUNCHER_PACKAGES = setOf(
        "com.android.launcher",              // AOSP generic
        "com.android.launcher3",             // AOSP Launcher3
        "com.google.android.apps.nexuslauncher", // Pixel 6+
        "com.sec.android.app.launcher",      // Samsung One UI
        "com.samsung.android.app.spage",     // Samsung Bixby Home
        "com.miui.home",                     // Xiaomi MIUI
        "com.oneplus.launcher",              // OnePlus OxygenOS
        "com.oppo.launcher",                 // Oppo ColorOS
        "net.one.punch.launcher",            // Realme
        "com.huawei.android.launcher",       // Huawei EMUI
        "com.hihonor.android.launcher",      // Honor
        "com.asus.launcher",                 // ASUS ZenUI
        "com.lge.launcher3",                 // LG UX
    )

    /** Returns true if [pkg] is a launcher or CogniTrack itself. */
    fun isExcluded(pkg: String, ownPackageName: String): Boolean {
        return pkg in LAUNCHER_PACKAGES || pkg == ownPackageName
    }
}