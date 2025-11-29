package com.example.mytime

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.PowerManager
import android.os.UserManager
import android.provider.Settings
import android.text.TextUtils
import android.util.Log
import androidx.core.app.NotificationManagerCompat
import java.util.*

class AdvancedBypassDetection(private val context: Context) {
    private val tag = "AdvancedBypassDetection"
    private var lastSystemTime = System.currentTimeMillis()
    private var isMonitoring = false
    private var monitoringThread: Thread? = null
    private var lastAccessibilityCheck = 0L
    private var accessibilityAlertShown = false
    
    private val timeChangeReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED -> {
                    handleTimeManipulation()
                }
            }
        }
    }

    fun startMonitoring() {
        if (isMonitoring) return
        isMonitoring = true
        
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_TIME_CHANGED)
            addAction(Intent.ACTION_TIMEZONE_CHANGED)
        }
        context.registerReceiver(timeChangeReceiver, filter)
        
        // Start periodic checks
        startPeriodicChecks()
        Log.d(tag, "Advanced bypass detection started")
    }

    fun stopMonitoring() {
        if (!isMonitoring) return
        isMonitoring = false
        
        try {
            context.unregisterReceiver(timeChangeReceiver)
        } catch (e: Exception) {
            Log.e(tag, "Error unregistering receiver", e)
        }
        
        // Properly stop monitoring thread
        monitoringThread?.interrupt()
        monitoringThread = null
        
        Log.d(tag, "Advanced bypass detection stopped")
    }

    private fun startPeriodicChecks() {
        monitoringThread = Thread {
            var cycleCount = 0
            while (isMonitoring) {
                try {
                    // Accessibility monitoring disabled - using smart interception
                    
                    // Less critical checks every 3rd cycle
                    if (cycleCount % 3 == 0) {
                        if (MonitoringConfig.ENABLE_TIME_MONITORING) {
                            checkTimeManipulation()
                        }
                        if (MonitoringConfig.ENABLE_BATTERY_MONITORING) {
                            checkBatteryOptimization()
                        }
                    }
                    
                    // Least critical checks every 6th cycle
                    if (cycleCount % 6 == 0) {
                        if (MonitoringConfig.ENABLE_NOTIFICATION_MONITORING) {
                            checkNotificationPermissions()
                        }
                        if (MonitoringConfig.ENABLE_USER_SWITCH_MONITORING) {
                            checkUserAccountSwitching()
                        }
                    }
                    
                    cycleCount++
                    Thread.sleep(MonitoringConfig.CRITICAL_CHECK_INTERVAL)
                } catch (e: Exception) {
                    Log.e(tag, "Error in periodic checks", e)
                    Thread.sleep(MonitoringConfig.ERROR_RETRY_DELAY)
                }
            }
        }
        monitoringThread?.start()
    }

    // 7. Time Manipulation Detection
    private fun checkTimeManipulation() {
        val currentTime = System.currentTimeMillis()
        val timeDiff = Math.abs(currentTime - lastSystemTime)
        
        // Detect unrealistic time jumps (more than 1 minute in 5 seconds)
        if (timeDiff > 60000 && lastSystemTime != 0L) {
            Log.w(tag, "Time manipulation detected: ${timeDiff}ms jump")
            handleTimeManipulation()
        }
        lastSystemTime = currentTime
    }

    private fun handleTimeManipulation() {
        Log.w(tag, "Time manipulation attempt detected")
        // Log the manipulation but don't open MyTask app
        val currentTime = System.currentTimeMillis()
        val timeDiff = Math.abs(currentTime - lastSystemTime)
        Log.w(tag, "Time jump detected: ${timeDiff}ms")
    }

    // 8. Battery Optimization Detection
    private fun checkBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val packageName = context.packageName
            
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                Log.w(tag, "Battery optimization not disabled for app")
                handleBatteryOptimization()
            }
        }
    }

    private fun handleBatteryOptimization() {
        Log.w(tag, "Battery optimization detected - requesting exemption")
        // Don't immediately bring to front - just request exemption
        requestBatteryOptimizationExemption()
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                context.startActivity(intent)
            } catch (e: Exception) {
                Log.e(tag, "Error requesting battery optimization exemption", e)
            }
        }
    }

    // 9. Notification Permission Monitoring
    private fun checkNotificationPermissions() {
        val notificationManager = NotificationManagerCompat.from(context)
        if (!notificationManager.areNotificationsEnabled()) {
            Log.w(tag, "Notifications disabled for app")
            handleNotificationBlock()
        }
    }

    private fun handleNotificationBlock() {
        Log.w(tag, "Notifications disabled - using alternative alerts")
        // Don't bring to front immediately - just log and use alternatives
        showSystemAlert()
    }

    private fun showSystemAlert() {
        // Log the alert but don't open MyTask app
        Log.w(tag, "System alert: Notification permissions required")
    }

    // 10. User Account Switching Detection
    private fun checkUserAccountSwitching() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
            val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager
            
            // Check if we're in guest mode or secondary user
            if (isGuestMode() || isSecondaryUser()) {
                Log.w(tag, "User account switching detected")
                handleUserSwitch()
            }
        }
    }

    private fun isGuestMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            val userManager = context.getSystemService(Context.USER_SERVICE) as UserManager
            userManager.isUserUnlocked && userManager.isSystemUser.not()
        } else {
            false
        }
    }

    private fun isSecondaryUser(): Boolean {
        return false // Simplified for compatibility
    }

    private fun handleUserSwitch() {
        Log.w(tag, "User account switching detected")
        // Only bring to front for actual bypass attempts
        enforceSystemWideProtection()
    }

    private fun enforceSystemWideProtection() {
        // Try to maintain protection across user accounts
        try {
            val devicePolicyManager = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            // Additional device admin enforcement
        } catch (e: Exception) {
            Log.e(tag, "Error enforcing system-wide protection", e)
        }
    }

    // 16. CRITICAL: Accessibility Service Monitoring - DISABLED (using smart interception instead)
    private fun checkAccessibilityService() {
        // Smart interception handles this now - no periodic checking needed
        return
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val accessibilityEnabled = try {
            Settings.Secure.getInt(context.contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED)
        } catch (e: Exception) {
            0
        }

        if (accessibilityEnabled == 1) {
            val settingValue = Settings.Secure.getString(
                context.contentResolver,
                Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            
            if (!settingValue.isNullOrEmpty()) {
                val splitter = TextUtils.SimpleStringSplitter(':')
                splitter.setString(settingValue)
                
                while (splitter.hasNext()) {
                    val accessibilityService = splitter.next()
                    if (accessibilityService.equals(
                        "${context.packageName}/com.example.mytask.AppBlockingAccessibilityService",
                        ignoreCase = true
                    )) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private fun handleAccessibilityServiceDisabled() {
        val currentTime = System.currentTimeMillis()
        
        // Only act if blocking is active and cooldown has passed
        if (!AppBlockingAccessibilityService.isBlockingActive) {
            return
        }
        
        // Prevent spam alerts - use configured cooldown
        if (currentTime - lastAccessibilityCheck < MonitoringConfig.ACCESSIBILITY_ALERT_COOLDOWN && accessibilityAlertShown) {
            return
        }
        
        Log.e(tag, "ACCESSIBILITY SERVICE DISABLED DURING ACTIVE BLOCKING!")
        
        // Show alert only if not shown recently
        if (!accessibilityAlertShown || currentTime - lastAccessibilityCheck > MonitoringConfig.ACCESSIBILITY_ALERT_COOLDOWN) {
            bringAppToFrontWithAccessibilityAlert()
            showAccessibilityServiceAlert()
            accessibilityAlertShown = true
            lastAccessibilityCheck = currentTime
        }
    }

    private fun bringAppToFrontWithAccessibilityAlert() {
        // Log the accessibility alert but don't open MyTask app
        Log.e(tag, "CRITICAL: Accessibility service must be enabled for app blocking to work!")
    }

    private fun showAccessibilityServiceAlert() {
        // This would show a persistent notification about accessibility service being disabled
        // Implementation depends on your notification service
        Log.w(tag, "Showing persistent accessibility service alert")
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(tag, "Error opening accessibility settings", e)
            // Fallback: open general settings
            try {
                val fallbackIntent = Intent(Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                context.startActivity(fallbackIntent)
            } catch (fallbackE: Exception) {
                Log.e(tag, "Error opening settings as fallback", fallbackE)
            }
        }
    }

    // Additional Security Measures
    fun checkRootAccess(): Boolean {
        return try {
            val process = Runtime.getRuntime().exec("su")
            process.destroy()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun checkEmulator(): Boolean {
        return (Build.FINGERPRINT.startsWith("generic") ||
                Build.FINGERPRINT.startsWith("unknown") ||
                Build.MODEL.contains("google_sdk") ||
                Build.MODEL.contains("Emulator") ||
                Build.MODEL.contains("Android SDK built for x86") ||
                Build.MANUFACTURER.contains("Genymotion") ||
                Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic"))
    }

    fun checkDebugging(): Boolean {
        return (context.applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0
    }

    fun checkHookFrameworks(): Boolean {
        return try {
            Class.forName("de.robv.android.xposed.XposedHelpers") != null ||
                   Class.forName("com.saurik.substrate.MS") != null
        } catch (e: ClassNotFoundException) {
            false
        }
    }

    private fun bringAppToFront() {
        // Log the event but don't open MyTask app
        Log.w(tag, "Bypass attempt detected - logging only")
    }

    // Comprehensive security check
    fun performSecurityCheck(): SecurityCheckResult {
        return SecurityCheckResult(
            isRooted = checkRootAccess(),
            isEmulator = checkEmulator(),
            isDebugging = checkDebugging(),
            hasHookFrameworks = checkHookFrameworks(),
            hasBatteryOptimization = !isBatteryOptimizationDisabled(),
            hasNotificationPermission = areNotificationsEnabled(),
            isGuestMode = isGuestMode(),
            isSecondaryUser = isSecondaryUser(),
            hasAccessibilityService = isAccessibilityServiceEnabled() // CRITICAL CHECK
        )
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true
        }
    }

    private fun areNotificationsEnabled(): Boolean {
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }
}

data class SecurityCheckResult(
    val isRooted: Boolean,
    val isEmulator: Boolean,
    val isDebugging: Boolean,
    val hasHookFrameworks: Boolean,
    val hasBatteryOptimization: Boolean,
    val hasNotificationPermission: Boolean,
    val isGuestMode: Boolean,
    val isSecondaryUser: Boolean,
    val hasAccessibilityService: Boolean // CRITICAL: Accessibility service status
) {
    val isSecure: Boolean
        get() = !isRooted && !isEmulator && !isDebugging && 
                !hasHookFrameworks && !hasBatteryOptimization && 
                hasNotificationPermission && !isGuestMode && !isSecondaryUser &&
                hasAccessibilityService // CRITICAL: Must have accessibility service
}