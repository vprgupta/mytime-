package com.example.mytime

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class AppProtectionDeviceAdminReceiver : DeviceAdminReceiver() {
    
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Toast.makeText(context, "App protection enabled", Toast.LENGTH_SHORT).show()
    }
    
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Toast.makeText(context, "App protection disabled", Toast.LENGTH_SHORT).show()
    }
    
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        val commitmentManager = CommitmentModeManager(context)
        if (commitmentManager.isCommitmentActive()) {
            return "⚠️ COMMITMENT ACTIVE ⚠️\n\nYou cannot disable this while a commitment is active. Your device may lock or restart if you proceed."
        }
        return "Disabling app protection will allow bypassing app blocking. Continue?"
    }
}