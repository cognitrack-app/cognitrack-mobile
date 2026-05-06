package com.cognitrack.cognitrack_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.AppOpsManager
import android.os.Process

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
            if (mode == AppOpsManager.MODE_ALLOWED) {
                ForegroundService.start(context)
            }
        }
    }
}
