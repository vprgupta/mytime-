package com.example.mytime

import android.app.ActivityManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_blocking"
    private var isMonitoring = false
    private val handler = Handler(Looper.getMainLooper())
    private var monitoringRunnable: Runnable? = null
    private val blockedApps = mutableSetOf<String>()
    private var devicePolicyManager: DevicePolicyManager? = null
    private var adminComponent: ComponentName? = null
    private val lastBlockTime = mutableMapOf<String, Long>()
    
    // Commitment Mode Manager
    private lateinit var commitmentManager: CommitmentModeManager
    
    // Usage Limiter tracking
    private val limitedApps = mutableSetOf<String>()
    private var previousForegroundApp: String? = null
    
    companion object {
        var instance: MainActivity? = null
        var blockedPackages = mutableSetOf<String>()
        var blockedAppNames = mutableSetOf<String>()
        var limitedPackages = mutableSetOf<String>()  // Apps with usage limits
        var isCommitmentActive = false
        
        // Usage Tracking State (Shared)
        var usageLimits = mutableMapOf<String, Int>()
        var usageToday = mutableMapOf<String, Int>()
        var accumulatedUsage = mutableMapOf<String, Long>() // For tracking partial minutes
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize commitment mode manager
        commitmentManager = CommitmentModeManager(this)
        
        // Initialize device admin
        initializeDeviceAdmin()
        
        // Restore active blocking sessions first
        restoreActiveSessions()
        
        // Cleanup expired blocking sessions
        cleanupExpiredSessions()
       
        // Handle blocked app intent
        handleBlockedAppIntent()

                // Start commitment monitoring and protection ONLY if commitment is active
        if (commitmentManager.isCommitmentActive()) {
            isCommitmentActive = true
            startUninstallProtection()  // Only start when commitment is active!
            startCommitmentMonitoring()
            android.util.Log.d("MainActivity", "🔒 Commitment mode is ACTIVE - Starting protection services")
        } else {
            isCommitmentActive = false
            // Ensure protection services are stopped if commitment is not active
            stopProtectionServices()
            android.util.Log.d("MainActivity", "✅ No active commitment - Protection services stopped")
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startMonitoring" -> {
                    if (PermissionHelper.isAccessibilityServiceEnabled(this) && PermissionHelper.hasUsageStatsPermission(this)) {
                        startMonitoring()
                        result.success(true)
                    } else {
                        // Don't auto-request permissions on startup, let the UI handle it
                        result.success(false)
                    }
                }
                "requestPermissions" -> {
                    requestPermissions()
                    result.success(null)
                }
                "checkPermissions" -> {
                    val hasUsageStats = PermissionHelper.hasUsageStatsPermission(this)
                    val hasAccessibility = PermissionHelper.isAccessibilityServiceEnabled(this)
                    val hasOverlay = PermissionHelper.hasOverlayPermission(this)
                    val hasDeviceAdmin = isDeviceAdminEnabled()
                    result.success(mapOf(
                        "usageStats" to hasUsageStats,
                        "accessibility" to hasAccessibility,
                        "overlay" to hasOverlay,
                        "deviceAdmin" to hasDeviceAdmin
                    ))
                }
                "stopMonitoring" -> {
                    stopMonitoring()
                    AppBlockingAccessibilityService.isBlockingActive = false
                    result.success(null)
                }
                "addBlockedApp" -> {
                    val packageName = call.argument<String>("packageName")
                    val endTime = call.argument<Long>("endTime") ?: 0L
                    
                    if (packageName != null) {
                        blockedApps.add(packageName)
                        blockedPackages.add(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.add(appName.lowercase())
                        AppBlockingAccessibilityService.addBlockedApp(packageName)
                        
                        // Persist blocking session (survives reinstall)
                        if (endTime > 0L) {
                            saveBlockingSession(packageName, endTime)
                        }
                        
                        // Device Admin: Block uninstallation at system level
                        // Always try to block (will check internally if admin enabled)
                        setUninstallBlocked(packageName, true)
                        
                        startRealTimeMonitoring()
                        
                        // IMMEDIATE BLOCK CHECK: Check if this app is currently in foreground
                        val currentApp = getCurrentForegroundApp()
                        if (currentApp == packageName) {
                            blockAppImmediately(packageName)
                            android.util.Log.d("MainActivity", "🚫 Immediate kick-out (UsageStats) for $packageName")
                        }
                        
                        android.util.Log.d("MainActivity", "Added $packageName ($appName) to blocked list, ends at $endTime")
                    }
                    result.success(null)
                }
                "removeBlockedApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        blockedApps.remove(packageName)
                        blockedPackages.remove(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.remove(appName.lowercase())
                        AppBlockingAccessibilityService.removeBlockedApp(packageName)
                        
                        // Remove from persistent storage
                        removeBlockingSession(packageName)
                        
                        // Device Admin: Remove uninstall blocking
                        setUninstallBlocked(packageName, false)
                        
                        lastBlockTime.remove(packageName)
                        if (blockedApps.isEmpty()) {
                            stopMonitoring()
                        }
                        android.util.Log.d("MainActivity", "Removed $packageName from blocked list")
                    }
                    result.success(null)
                }
                "blockApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        blockedApps.add(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.add(appName.lowercase())
                        AppBlockingAccessibilityService.addBlockedApp(packageName)
                        
                        // Device Admin: Block uninstallation at system level
                        setUninstallBlocked(packageName, true)
                        
                        startRealTimeMonitoring()
                    }
                    result.success(null)
                }
                "unblockApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        blockedApps.remove(packageName)
                        blockedPackages.remove(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.remove(appName.lowercase())
                        
                        // Device Admin: Remove uninstall blocking
                        setUninstallBlocked(packageName, false)
                        
                        if (blockedApps.isEmpty()) {
                            AppBlockingAccessibilityService.isBlockingActive = false
                        }
                        android.util.Log.d("MainActivity", "✅ Unblocked app: $packageName")
                    }
                    result.success(null)
                }
                "clearBlockedApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        // Force remove from all blocking lists
                        blockedApps.remove(packageName)
                        blockedPackages.remove(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.remove(appName.lowercase())
                        
                        // Device Admin: Remove uninstall blocking
                        setUninstallBlocked(packageName, false)
                        
                        lastBlockTime.remove(packageName)
                        if (blockedApps.isEmpty()) {
                            AppBlockingAccessibilityService.isBlockingActive = false
                        }
                        android.util.Log.d("MainActivity", "🧹 Force cleared blocked app: $packageName")
                    }
                    result.success(null)
                }
                "addLimitedApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        limitedPackages.add(packageName)
                        android.util.Log.d("MainActivity", "⏱️ Added limited app: $packageName")
                    }
                    result.success(null)
                }
                "removeLimitedApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        limitedPackages.remove(packageName)
                        android.util.Log.d("MainActivity", "⏱️ Removed limited app: $packageName")
                    }
                    result.success(null)
                }

                "setAppLimit" -> {
                    val packageName = call.argument<String>("packageName")
                    val limit = call.argument<Int>("limitMinutes")
                    val used = call.argument<Int>("usedMinutes")
                    
                    if (packageName != null && limit != null && used != null) {
                        limitedPackages.add(packageName)
                        AppBlockingAccessibilityService.updateAppLimit(packageName, limit, used)
                        android.util.Log.d("MainActivity", "📥 setAppLimit: $packageName, Limit: $limit, Used: $used")
                        android.util.Log.d("MainActivity", "📋 Current limitedPackages: $limitedPackages")
                        result.success(true)
                    } else {
                        android.util.Log.e("MainActivity", "⚠️ setAppLimit failed: Missing args (pkg=$packageName, limit=$limit, used=$used)")
                        result.success(false)
                    }
                }
                "getAppName" -> {
                    val packageName = call.argument<String>("packageName")
                    val appName = getAppName(packageName ?: "")
                    result.success(appName)
                }
                "isAppBlocked" -> {
                    val packageName = call.argument<String>("packageName")
                    result.success(blockedApps.contains(packageName))
                }
                "getBlockedApps" -> {
                    result.success(blockedApps.toList())
                }
                "enableDeviceAdmin" -> {
                    enableDeviceAdmin()
                    result.success(null)
                }
                "isDeviceAdminEnabled" -> {
                    val isEnabled = isDeviceAdminEnabled()
                    // If just enabled, apply uninstall block to all currently blocked apps
                    if (isEnabled) {
                        applyUninstallBlockToAllBlockedApps()
                    }
                    result.success(isEnabled)
                }
                "preventUninstall" -> {
                    val prevent = call.argument<Boolean>("prevent") ?: false
                    setUninstallPrevention(prevent)
                    result.success(null)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(null)
                }
                "requestUsageStats" -> {
                    PermissionHelper.requestUsageStatsPermission(this)
                    result.success(null)
                }
                "requestOverlay" -> {
                    PermissionHelper.requestOverlayPermission(this)
                    result.success(null)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "setUninstallLock" -> {
                    val timestamp = call.argument<Long>("timestamp") ?: 0L
                    val prefs = getSharedPreferences("MyTaskPrefs", Context.MODE_PRIVATE)
                    prefs.edit().putLong("uninstall_lock_end_time", timestamp).apply()
                    result.success(null)
                }
                "getUninstallLock" -> {
                    // Check and clear if expired before returning status
                    commitmentManager.clearIfExpired()
                    val timestamp = commitmentManager.getCommitmentEndTime()
                    result.success(timestamp)
                }
                "startCommitmentMode" -> {
                    val hours = call.argument<Int>("hours") ?: 1
                    val success = commitmentManager.startCommitment(hours)
                    if (success) {
                        isCommitmentActive = true
                        startCommitmentMonitoring()
                        // Enforce uninstall protection via Device Admin
                        setUninstallBlocked(packageName, true)
                    }
                    result.success(success)
                }
                "getCommitmentStatus" -> {
                    val status = mapOf(
                        "isActive" to commitmentManager.isCommitmentActive(),
                        "endTime" to commitmentManager.getCommitmentEndTime(),
                        "remainingTime" to commitmentManager.getRemainingTime()
                    )
                    result.success(status)
                }
                "requestBatteryOptimization" -> {
                    requestBatteryOptimizationExemption()
                    result.success(null)
                }
                "getBatteryOptimizationStatus" -> {
                    val isIgnoring = isBatteryOptimizationIgnored()
                    result.success(isIgnoring)
                }
                "getManufacturerInfo" -> {
                    val info = ManufacturerDetector.detect()
                    result.success(mapOf(
                        "manufacturer" to info.manufacturer,
                        "model" to info.model,
                        "androidVersion" to info.androidVersion,
                        "instructions" to info.batteryOptimizationInstructions
                    ))
                }
                "openManufacturerBatterySettings" -> {
                    openBatteryOptimizationSettings()
                    result.success(null)
                }
                "checkIsLimited" -> {
                    val packageName = call.argument<String>("packageName")
                    val isLimited = packageName?.let { isAppLimited(it) } ?: false
                    result.success(isLimited)
                }
                "setAppSchedule" -> {
                    val packageName = call.argument<String>("packageName")
                    val startHour = call.argument<Int>("startHour") ?: 0
                    val startMinute = call.argument<Int>("startMinute") ?: 0
                    val endHour = call.argument<Int>("endHour") ?: 0
                    val endMinute = call.argument<Int>("endMinute") ?: 0
                    val isEnabled = call.argument<Boolean>("isEnabled") ?: true
                    
                    if (packageName != null) {
                        AppBlockingAccessibilityService.setAppSchedule(
                            packageName, startHour, startMinute, endHour, endMinute, isEnabled
                        )
                        // Also persist locally in prefs to survive reboot (simple version)
                        // For now, we rely on Flutter re-syncing on startup, which it does.
                        android.util.Log.d("MainActivity", "📅 Set schedule for $packageName: $startHour:$startMinute - $endHour:$endMinute")
                    }
                    result.success(null)
                }
                "removeAppSchedule" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        AppBlockingAccessibilityService.removeAppSchedule(packageName)
                        android.util.Log.d("MainActivity", "🗑️ Removed schedule for $packageName")
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startMonitoring() {
        if (isMonitoring) return
        isMonitoring = true
        startRealTimeMonitoring()
    }
    
    private fun startRealTimeMonitoring() {
        monitoringRunnable = object : Runnable {
            override fun run() {
                // OPTIMIZATION: Adaptive Polling
                // If no apps are blocked, stop the monitoring loop to save battery
                if (blockedApps.isEmpty()) {
                    isMonitoring = false
                    android.util.Log.d("MainActivity", "🛑 No blocked apps, stopping monitoring loop")
                    return
                }

                // OPTIMIZATION: Background Execution
                // Move usage stats query to background thread to prevent main thread jank
                Thread {
                    try {
                        checkAndBlockApps()
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "Error in monitoring: ${e.message}")
                    }
                }.start()
                
                if (isMonitoring) {
                    // OPTIMIZATION: Increased polling interval to 10 seconds to reduce CPU usage and heating
                    handler.postDelayed(this, 10000) 
                }
            }
        }
        handler.post(monitoringRunnable!!)
    }
    
    private fun checkAndBlockApps() {
        try {
            val currentApp = getCurrentForegroundApp()
            if (currentApp != null && blockedApps.contains(currentApp) && currentApp != packageName) {
                blockAppImmediately(currentApp)
            }
        } catch (e: Exception) {
            // Continue monitoring
        }
    }
    
    private fun getCurrentForegroundApp(): String? {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val time = System.currentTimeMillis()
        
        val usageStats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            time - 1000 * 10, // Last 10 seconds
            time
        )
        
        return usageStats.maxByOrNull { it.lastTimeUsed }?.packageName
    }
    
    private fun blockAppImmediately(packageName: String) {
        try {
            val currentTime = System.currentTimeMillis()
            val lastTime = lastBlockTime[packageName] ?: 0
            
            // Reduced rate limit: only block once per 0.5 seconds per app (safer but responsive)
            if (currentTime - lastTime < 500) {
                return
            }
            lastBlockTime[packageName] = currentTime
            
            // Safety check: don't block system apps
            if (packageName.startsWith("com.android.") || 
                packageName.startsWith("android.") ||
                packageName == "com.android.systemui") {
                return
            }
            
            // Context validation: ensure app is still blocked
            if (!blockedApps.contains(packageName)) {
                android.util.Log.d("MainActivity", "App $packageName no longer blocked, skipping")
                return
            }
            
            // Multi-layer blocking approach
            // 1. Kill the app process
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.killBackgroundProcesses(packageName)
            
            // 2. Force finish any activities
            try {
                val runningTasks = activityManager.getRunningTasks(10)
                for (task in runningTasks) {
                    if (task.topActivity?.packageName == packageName) {
                        activityManager.moveTaskToFront(task.id, 0)
                        break
                    }
                }
            } catch (e: Exception) {
                // Continue with other blocking methods
            }
            
            // 3. Navigate to home screen immediately
            val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            }
            startActivity(homeIntent)
            
            AppBlockingAccessibilityService.addBlockedApp(packageName)
            android.util.Log.d("MainActivity", "Successfully blocked app: $packageName")
            
            // Notify Flutter about the blocked app (for logging purposes only)
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                val channel = MethodChannel(messenger, CHANNEL)
                handler.post {
                    channel.invokeMethod("onAppLaunched", mapOf(
                        "packageName" to packageName,
                        "appName" to getAppName(packageName),
                        "timestamp" to System.currentTimeMillis(),
                        "blocked" to true
                    ))
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error in blockAppImmediately: ${e.message}")
        }
    }

    private fun stopMonitoring() {
        isMonitoring = false
        monitoringRunnable?.let { handler.removeCallbacks(it) }
    }

    private fun requestPermissions() {
        // Open app settings instead of individual permission screens
        openAppSettings()
    }

    private fun blockApp(packageName: String) {
        blockAppImmediately(packageName)
    }

    private fun getAppName(packageName: String): String {
        return try {
            val packageManager = applicationContext.packageManager
            val applicationInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(applicationInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }
    
    private fun handleBlockedAppIntent() {
        // Don't handle any intents that would open MyTask app
        // Just log for debugging purposes
        val blockedApp = intent.getStringExtra("blocked_app")
        if (blockedApp != null) {
            android.util.Log.d("MainActivity", "Blocked app intent received: $blockedApp")
        }
    }
    
    private fun initializeDeviceAdmin() {
        devicePolicyManager = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        adminComponent = ComponentName(this, AppProtectionDeviceAdminReceiver::class.java)
    }
    
    private fun startUninstallProtection() {
        try {
            val intent = Intent(this, UninstallProtectionService::class.java)
            startService(intent)
            
            // Also start bypass detection service
            val bypassIntent = Intent(this, BypassDetectionService::class.java)
            startService(bypassIntent)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start protection services: ${e.message}")
        }
    }
    
    private fun stopProtectionServices() {
        try {
            // Stop UninstallProtectionService
            val intent = Intent(this, UninstallProtectionService::class.java)
            stopService(intent)
            
            // Stop BypassDetectionService
            val bypassIntent = Intent(this, BypassDetectionService::class.java)
            stopService(bypassIntent)
            
            // Stop CommitmentMonitoringService if running
            val monitoringIntent = Intent(this, CommitmentMonitoringService::class.java)
            stopService(monitoringIntent)
            
            // Disable Device Admin if no commitment active
            if (isDeviceAdminEnabled() && !commitmentManager.isCommitmentActive()) {
                isCommitmentActive = false
                try {
                    // Remove uninstall block for MyTime app
                    devicePolicyManager?.setUninstallBlocked(adminComponent!!, packageName, false)
                    
                    // Remove Device Admin
                    devicePolicyManager?.removeActiveAdmin(adminComponent!!)
                    android.util.Log.d("MainActivity", "✅ Removed Device Admin (no active commitment)")
                } catch (e: Exception) {
                    android.util.Log.w("MainActivity", "Failed to remove Device Admin: ${e.message}")
                }
            }
            
            android.util.Log.d("MainActivity", "✅ Stopped all protection services")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to stop protection services: ${e.message}")
        }
    }
    
    private fun enableDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
        intent.putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent)
        intent.putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "Required to prevent app uninstallation during focus sessions")
        startActivity(intent)
    }
    
    private fun isDeviceAdminEnabled(): Boolean {
        return devicePolicyManager?.isAdminActive(adminComponent!!) ?: false
    }
    
    private fun setUninstallPrevention(prevent: Boolean) {
        if (isDeviceAdminEnabled()) {
            try {
                if (prevent) {
                    devicePolicyManager?.setUninstallBlocked(adminComponent!!, packageName, true)
                    devicePolicyManager?.setLockTaskPackages(adminComponent!!, arrayOf(packageName))
                    startLockTask()
                } else {
                    devicePolicyManager?.setUninstallBlocked(adminComponent!!, packageName, false)
                    stopLockTask()
                }
            } catch (e: Exception) {
                // Handle silently
            }
        }
    }
    
    private fun setUninstallBlocked(packageName: String, blocked: Boolean) {
        if (isDeviceAdminEnabled()) {
            try {
                devicePolicyManager?.setUninstallBlocked(adminComponent!!, packageName, blocked)
                android.util.Log.d("MainActivity", "Set uninstall blocked for $packageName: $blocked")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to set uninstall blocked for $packageName: ${e.message}")
            }
        }
    }
    
    private fun applyUninstallBlockToAllBlockedApps() {
        if (!isDeviceAdminEnabled()) return
        
        for (packageName in blockedApps) {
            try {
                devicePolicyManager?.setUninstallBlocked(adminComponent!!, packageName, true)
                android.util.Log.d("MainActivity", "✅ Applied uninstall block to: $packageName")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Failed to apply uninstall block to $packageName: ${e.message}")
            }
        }
        android.util.Log.d("MainActivity", "Applied uninstall blocking to ${blockedApps.size} apps")
    }
    
    // === Persistent Blocking Methods (Survives Reinstall) ===
    
    private fun saveBlockingSession(packageName: String, endTimeMillis: Long) {
        try {
            val prefs = getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            prefs.edit().putLong(packageName, endTimeMillis).apply()
            android.util.Log.d("MainActivity", "💾 Saved blocking session for $packageName until $endTimeMillis")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to save blocking session: ${e.message}")
        }
    }
    
    private fun removeBlockingSession(packageName: String) {
        try {
            val prefs = getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            prefs.edit().remove(packageName).apply()
            android.util.Log.d("MainActivity", "🗑️ Removed blocking session for $packageName")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to remove blocking session: ${e.message}")
        }
    }
    
    private fun getBlockingEndTime(packageName: String): Long? {
        return try {
            val prefs = getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            val endTime = prefs.getLong(packageName, 0L)
            if (endTime > 0L) endTime else null
        } catch (e: Exception) {
            null
        }
    }
    
    private fun isStillBlocked(packageName: String): Boolean {
        val endTime = getBlockingEndTime(packageName) ?: return false
        val now = System.currentTimeMillis()
        return now < endTime
    }
    
    private fun restoreActiveSessions() {
        try {
            val prefs = getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            var restoredCount = 0
            
            prefs.all.forEach { (packageName, endTime) ->
                if (endTime is Long && endTime > now) {
                    blockedApps.add(packageName)
                    blockedPackages.add(packageName)
                    val appName = getAppName(packageName)
                    blockedAppNames.add(appName.lowercase())
                    AppBlockingAccessibilityService.addBlockedApp(packageName)
                    restoredCount++
                }
            }
            
            if (restoredCount > 0) {
                startMonitoring()
                android.util.Log.d("MainActivity", "♻️ Restored $restoredCount active blocking sessions")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to restore active sessions: ${e.message}")
        }
    }

    private fun cleanupExpiredSessions() {
        try {
            val prefs = getSharedPreferences("BlockingSessions", Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val editor = prefs.edit()
            var count = 0
            
            prefs.all.forEach { (packageName, endTime) ->
                if (endTime is Long && now >= endTime) {
                    editor.remove(packageName)
                    count++
                }
            }
            
            if (count > 0) {
                editor.apply()
                android.util.Log.d("MainActivity", "🧹 Cleaned up $count expired blocking sessions")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to cleanup expired sessions: ${e.message}")
        }
    }
    
    // === Usage Limiter Integration ===
    
    private fun isAppLimited(packageName: String): Boolean {
        return limitedApps.contains(packageName)
    }
    
    fun addLimitedApp(packageName: String) {
        limitedApps.add(packageName)
        limitedPackages.add(packageName)  // Also add to companion for AccessibilityService
        android.util.Log.d("MainActivity", "📊 Added limited app: $packageName. Current list: $limitedPackages")
    }
    
    fun removeLimitedApp(packageName: String) {
        limitedApps.remove(packageName)
        limitedPackages.remove(packageName)  // Also remove from companion
        android.util.Log.d("MainActivity", "📊 Removed limited app: $packageName")
    }
    
    fun updateNativeUsage(packageName: String, usedMinutes: Int) {
        // Notify Flutter about usage update
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = MethodChannel(messenger, CHANNEL)
            handler.post {
                try {
                    channel.invokeMethod("updateUsage", mapOf(
                        "packageName" to packageName,
                        "usedMinutes" to usedMinutes
                    ))
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to update usage: ${e.message}")
                }
            }
        }
    }
    
    fun notifyAppLaunched(packageName: String) {
        // Notify Flutter that a limited app was launched
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = MethodChannel(messenger, CHANNEL)
            handler.post {
                try {
                    channel.invokeMethod("onLimitedAppLaunched", mapOf(
                        "packageName" to packageName
                    ))
                    android.util.Log.d("MainActivity", "📊 Notified Flutter: App launched - $packageName")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to notify app launched: ${e.message}")
                }
            }
        }
    }
    
    fun notifyAppClosed(packageName: String) {
        // Notify Flutter that a limited app was closed
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            val channel = MethodChannel(messenger, CHANNEL)
            handler.post {
                try {
                    channel.invokeMethod("onLimitedAppClosed", mapOf(
                        "packageName" to packageName
                    ))
                    android.util.Log.d("MainActivity", "📊 Notified Flutter: App closed - $packageName")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to notify app closed: ${e.message}")
                }
            }
        }
    }
    

    
    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings
            try {
                val fallbackIntent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
            } catch (fallbackE: Exception) {
                // Handle silently
            }
        }
    }
    
    private fun openAppSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback to general settings
            try {
                val fallbackIntent = Intent(android.provider.Settings.ACTION_SETTINGS).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(fallbackIntent)
            } catch (fallbackE: Exception) {
                // Handle silently
            }
        }
    }
    
    private fun startCommitmentMonitoring() {
        try {
            val intent = Intent(this, CommitmentMonitoringService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            android.util.Log.d("MainActivity", "Started commitment monitoring service")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start commitment monitoring", e)
        }
    }
    
    private fun requestBatteryOptimizationExemption() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            openBatteryOptimizationSettings()
        }
    }
    
    private fun isBatteryOptimizationIgnored(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }
    
    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val fallbackIntent = Intent(android.provider.Settings.ACTION_BATTERY_SAVER_SETTINGS)
                startActivity(fallbackIntent)
            } catch(fallbackE: Exception) {
                android.util.Log.e("MainActivity", "Failed to open battery settings", fallbackE)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleBlockedAppIntent()
    }
    
    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            applicationContext.packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }

    // Persistence: Monitor package installation
    private val packageReceiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == Intent.ACTION_PACKAGE_ADDED || 
                intent?.action == Intent.ACTION_PACKAGE_REPLACED) {
                
                val packageName = intent.data?.schemeSpecificPart
                if (packageName != null) {
                    android.util.Log.d("MainActivity", "📦 Package detected: $packageName")
                    
                    // Check if this app has an active blocking session in persistent storage
                    if (isStillBlocked(packageName)) {
                        val endTime = getBlockingEndTime(packageName)
                        val now = System.currentTimeMillis()
                        val remainingMinutes = ((endTime ?: now) - now) / 60000
                        
                        // Re-apply the block
                        blockedApps.add(packageName)
                        blockedPackages.add(packageName)
                        val appName = getAppName(packageName)
                        blockedAppNames.add(appName.lowercase())
                        AppBlockingAccessibilityService.addBlockedApp(packageName)
                        startRealTimeMonitoring()
                        
                        android.util.Log.d("MainActivity", "🔒 RE-APPLIED BLOCK on reinstalled app: $packageName (${remainingMinutes}min remaining)")
                        
                        // Notify Flutter if running
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            val channel = MethodChannel(messenger, CHANNEL)
                            handler.post {
                                channel.invokeMethod("onPackageInstalled", mapOf(
                                    "packageName" to packageName,
                                    "wasBlocked" to true,
                                    "remainingMinutes" to remainingMinutes
                                ))
                            }
                        }
                    } else {
                        // Check if session expired and clean up
                        val endTime = getBlockingEndTime(packageName)
                        if (endTime != null) {
                            removeBlockingSession(packageName)
                            android.util.Log.d("MainActivity", "🧹 Cleaned expired session for $packageName")
                        }
                        
                        // Notify Flutter (not blocked)
                        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                            val channel = MethodChannel(messenger, CHANNEL)
                            handler.post {
                                channel.invokeMethod("onPackageInstalled", mapOf(
                                    "packageName" to packageName,
                                    "wasBlocked" to false
                                ))
                            }
                        }
                    }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        instance = this
        val filter = android.content.IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addDataScheme("package")
        }
        registerReceiver(packageReceiver, filter)
    }

    override fun onResume() {
        super.onResume()
        // Critical: Check if commitment has expired every time app sends to foreground
        // This ensures Admin rights are removed immediately when user opens app after expiry
        try {
            if (::commitmentManager.isInitialized) {
                 commitmentManager.clearIfExpired()
            }
        } catch (e: Exception) {
            // Ignore init errors
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        instance = null
        try {
            unregisterReceiver(packageReceiver)
        } catch (e: Exception) {
            // Ignore
        }
    }
}