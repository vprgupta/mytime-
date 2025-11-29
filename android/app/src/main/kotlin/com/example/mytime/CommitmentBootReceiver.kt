package com.example.mytime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class CommitmentBootReceiver : BroadcastReceiver() {
    
    private val TAG = "CommitmentBootReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            
            Log.d(TAG, "Boot/Package replaced detected, checking commitment status")
            
            val commitmentManager = CommitmentModeManager(context)
            
            // Check if commitment mode is active
            if (commitmentManager.isCommitmentActive()) {
                val remainingHours = commitmentManager.getRemainingTime() / (1000 * 60 * 60)
                Log.d(TAG, "Commitment is active! Remaining: ${remainingHours}h")
                
                // Restore blocked apps to AccessibilityService
                restoreBlockedApps(context)
                
                // Start monitoring service
                val serviceIntent = Intent(context, CommitmentMonitoringService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                // Restart other protection services
                try {
                    context.startService(Intent(context, UninstallProtectionService::class.java))
                    context.startService(Intent(context, BypassDetectionService::class.java))
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start protection services", e)
                }
                
                Log.d(TAG, "Commitment mode restored after boot")
            } else {
                // Clear expired commitment
                commitmentManager.clearIfExpired()
                Log.d(TAG, "No active commitment or commitment expired")
            }
        }
    }
    
    private fun restoreBlockedApps(context: Context) {
        try {
            // Read blocked apps from persistent storage
            val prefs = context.getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            
            prefs.all.forEach { (packageName, endTime) ->
                if (endTime is Long && endTime > now) {
                    // Re-add to blocked list
                    MainActivity.blockedPackages.add(packageName)
                    
                    val appName = getAppName(context, packageName)
                    MainActivity.blockedAppNames.add(appName.lowercase())
                    
                    AppBlockingAccessibilityService.addBlockedApp(packageName)
                    
                    Log.d(TAG, "Restored block for $packageName")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore blocked apps", e)
        }
    }
    
    private fun getAppName(context: Context, packageName: String): String {
        return try {
            val packageManager = context.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
}
