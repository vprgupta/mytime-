package com.example.mytime

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.provider.Settings
import android.app.admin.DevicePolicyManager
import android.content.ComponentName

class CommitmentBootReceiver : BroadcastReceiver() {
    
    private val TAG = "CommitmentBootReceiver"
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            
            Log.d(TAG, "📱 Boot/Package replaced detected, checking commitment status")
            
            val commitmentManager = CommitmentModeManager(context)
            
            // Check if commitment mode is active
            if (commitmentManager.isCommitmentActive()) {
                val remainingMs = commitmentManager.getRemainingTime()
                val remainingHours = remainingMs / (1000 * 60 * 60)
                val remainingMins = (remainingMs % (1000 * 60 * 60)) / (1000 * 60)
                
                Log.d(TAG, "✅ Commitment is ACTIVE! Remaining: ${remainingHours}h ${remainingMins}m")
                
                // CRITICAL: Immediately re-enable Device Admin uninstall blocking
                // This MUST happen BEFORE accessibility service starts to prevent
                // uninstallation during the boot window
                immediatelyBlockUninstall(context)
                
                // STEP 1: Verify accessibility service is enabled
                if (!isAccessibilityServiceEnabled(context)) {
                    Log.w(TAG, "⚠️ Accessibility service NOT enabled - user must re-enable")
                } else {
                    Log.d(TAG, "✅ Accessibility service is enabled")
                }
                
                // STEP 2: Verify device admin is active
                if (!isDeviceAdminActive(context)) {
                    Log.w(TAG, "⚠️ Device Admin NOT active - attempting to restore")
                    // Cannot auto-enable, but log for user notification
                } else {
                    Log.d(TAG, "✅ Device Admin is active")
                }
                
                // STEP 3: Restore blocked apps to AccessibilityService
                restoreBlockedApps(context)
                
                // STEP 4: Restore scheduled apps
                restoreScheduledApps(context)
                
                // STEP 5: Start monitoring service
                val serviceIntent = Intent(context, CommitmentMonitoringService::class.java)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(serviceIntent)
                    } else {
                        context.startService(serviceIntent)
                    }
                    Log.d(TAG, "✅ Started CommitmentMonitoringService")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start CommitmentMonitoringService", e)
                }
                
                // STEP 6: Restart other protection services
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(Intent(context, UninstallProtectionService::class.java))
                        context.startForegroundService(Intent(context, BypassDetectionService::class.java))
                    } else {
                        context.startService(Intent(context, UninstallProtectionService::class.java))
                        context.startService(Intent(context, BypassDetectionService::class.java))
                    }
                    Log.d(TAG, "✅ Started protection services")
                } catch (e: Exception) {
                    Log.e(TAG, "❌ Failed to start protection services", e)
                }
                
                Log.d(TAG, "🎯 Commitment mode FULLY RESTORED after boot")
            } else {
                // Clear expired commitment
                commitmentManager.clearIfExpired()
                Log.d(TAG, "ℹ️ No active commitment or commitment expired")
            }
        }
    }
    
    /**
     * CRITICAL: Immediately block uninstallation using Device Admin
     * This runs synchronously on boot to prevent uninstallation during
     * the window before accessibility service starts
     */
    private fun immediatelyBlockUninstall(context: Context) {
        try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val adminComponent = ComponentName(context, AppProtectionDeviceAdminReceiver::class.java)
            
            if (devicePolicyManager != null && devicePolicyManager.isAdminActive(adminComponent)) {
                // Block uninstallation IMMEDIATELY
                devicePolicyManager.setUninstallBlocked(adminComponent, context.packageName, true)
                Log.d(TAG, "🔒 IMMEDIATE uninstall block applied on boot")
            } else {
                Log.e(TAG, "❌ Device Admin NOT active - cannot block uninstall!")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to immediately block uninstall", e)
        }
    }
    
    private fun isAccessibilityServiceEnabled(context: Context): Boolean {
        return try {
            val enabledServices = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            enabledServices?.contains(context.packageName) == true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check accessibility service", e)
            false
        }
    }
    
    private fun isDeviceAdminActive(context: Context): Boolean {
        return try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
            val adminComponent = ComponentName(context, AppProtectionDeviceAdminReceiver::class.java)
            devicePolicyManager?.isAdminActive(adminComponent) == true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check device admin", e)
            false
        }
    }
    
    private fun showAccessibilityWarning(context: Context) {
        // Log warning - user will see when they open the app
        Log.w(TAG, "⚠️ ACCESSIBILITY SERVICE DISABLED - User must re-enable manually")
        // TODO: Show notification when NotificationHelper is implemented
    }
    
    private fun showDeviceAdminWarning(context: Context) {
        // Log warning - user will see when they open the app
        Log.w(TAG, "⚠️ DEVICE ADMIN DISABLED - User must re-enable manually")
        // TODO: Show notification when NotificationHelper is implemented
    }
    
    private fun restoreBlockedApps(context: Context) {
        try {
            // Read blocked apps from persistent storage
            val prefs = context.getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            var restoredCount = 0
            
            prefs.all.forEach { (packageName, endTime) ->
                if (endTime is Long && endTime > now) {
                    // Re-add to blocked list
                    MainActivity.blockedPackages.add(packageName)
                    
                    val appName = getAppName(context, packageName)
                    MainActivity.blockedAppNames.add(appName.lowercase())
                    
                    AppBlockingAccessibilityService.addBlockedApp(packageName)
                    
                    restoredCount++
                    Log.d(TAG, "✅ Restored block for $packageName")
                }
            }
            
            Log.d(TAG, "📦 Restored $restoredCount blocked apps")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restore blocked apps", e)
        }
    }
    
    private fun restoreScheduledApps(context: Context) {
        try {
            val prefs = context.getSharedPreferences("ScheduledBlocks", Context.MODE_PRIVATE)
            var restoredCount = 0
            
            prefs.all.forEach { (packageName, scheduleJson) ->
                if (scheduleJson is String) {
                    // Scheduled apps are automatically restored from SharedPreferences
                    // The AccessibilityService reads from SharedPreferences directly
                    restoredCount++
                    Log.d(TAG, "✅ Restored schedule for $packageName")
                }
            }
            
            Log.d(TAG, "📅 Restored $restoredCount scheduled apps")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to restore scheduled apps", e)
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
