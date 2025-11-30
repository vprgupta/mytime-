package com.example.mytime

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

class AppBlockingAccessibilityService : AccessibilityService() {
    private val handler = Handler(Looper.getMainLooper())
    private val lastBlockTime = mutableMapOf<String, Long>()
    private val isProcessing = AtomicBoolean(false)
    private var eventCount = 0
    private var lastEventTime = 0L
    
    companion object {
        var isBlockingActive = false
        private const val MAX_EVENTS_PER_SECOND = 10
        private const val MIN_BLOCK_INTERVAL = 500L // 0.5 seconds
        private const val MAX_RECURSION_DEPTH = 3
        
        // Static methods for managing blocked apps
        @JvmStatic
        fun addBlockedApp(packageName: String) {
            MainActivity.blockedPackages.add(packageName)
            isBlockingActive = true  // Auto-activate blocking
            android.util.Log.d("AccessibilityService", "✅ Added blocked app: $packageName, Active: $isBlockingActive")
        }
        
        @JvmStatic
        fun removeBlockedApp(packageName: String) {
            MainActivity.blockedPackages.remove(packageName)
            if (MainActivity.blockedPackages.isEmpty()) {
                isBlockingActive = false  // Auto-deactivate when no apps blocked
            }
            android.util.Log.d("AccessibilityService", "✅ Removed blocked app: $packageName, Active: $isBlockingActive, Remaining: ${MainActivity.blockedPackages.size}")
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        // OPTIMIZATION: Only process relevant event types
        // Ignore high-frequency events like SCROLL, HOVER, etc.
        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED && 
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            return
        }

        // Prevent excessive event processing that can cause kernel freeze
        val currentTime = System.currentTimeMillis()
        
        // Allow CONTENT_CHANGED events to pass through rate limit more easily if they are relevant
        // or just apply the same limit. 50ms is fast enough.
        if (currentTime - lastEventTime < 50) { 
            eventCount++
            if (eventCount > MAX_EVENTS_PER_SECOND) {
                return // Rate limit exceeded
            }
        } else {
            eventCount = 0
            lastEventTime = currentTime
        }
        
        // Prevent concurrent processing
        if (!isProcessing.compareAndSet(false, true)) {
            return
        }
        
        try {
            processEvent(event)
        } finally {
            isProcessing.set(false)
        }
    }
    
    // Optimization: Cache monitored packages for faster lookup
    private val monitoredPackages = hashSetOf(
        "com.android.settings",
        "com.google.android.packageinstaller",
        "com.android.packageinstaller",
        "com.samsung.android.packageinstaller",
        "com.sec.android.app.launcher",
        "com.samsung.android.app.launcher",
        "com.miui.packageinstaller",
        "com.android.launcher3",
        "com.google.android.apps.nexuslauncher",
        "com.android.vending"
    )
    
    // Optimization: Cache SharedPreferences to reduce disk reads
    private var cachedLockEndTime = 0L
    private var lastCacheUpdateTime = 0L
    private val CACHE_REFRESH_INTERVAL = 5000L // 5 seconds
    
    // Sticky Protection: Aggressively block uninstall attempts for a duration
    private var stickyProtectionUntil = 0L
    private var protectedPackageName: String? = null
    private val STICKY_PROTECTION_DURATION = 10000L // 10 seconds

    private fun processEvent(event: AccessibilityEvent?) {
        val eventType = event?.eventType
        val packageName = event?.packageName?.toString()
        val className = event?.className?.toString()
        
        if (packageName == null) return

        // OPTIMIZATION: Early exit if nothing is blocked and no global lock
        // We need to check cache first
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastCacheUpdateTime > CACHE_REFRESH_INTERVAL) {
            val prefs = applicationContext.getSharedPreferences("MyTaskPrefs", android.content.Context.MODE_PRIVATE)
            cachedLockEndTime = prefs.getLong("uninstall_lock_end_time", 0L)
            lastCacheUpdateTime = currentTime
        }
        val isGlobalLockActive = cachedLockEndTime > currentTime

        if (MainActivity.blockedPackages.isEmpty() && !isGlobalLockActive && stickyProtectionUntil < currentTime) {
            return
        }

        // STICKY PROTECTION: If we're in sticky protection mode, aggressively block any monitored package
        if (stickyProtectionUntil > currentTime && monitoredPackages.contains(packageName)) {
            performGlobalAction(GLOBAL_ACTION_BACK)
            performGlobalAction(GLOBAL_ACTION_HOME)
            performGlobalAction(GLOBAL_ACTION_BACK)
            android.util.Log.d("AccessibilityService", "🔒 STICKY PROTECTION: Blocked access to $packageName for ${protectedPackageName}")
            return
        }
        
        // Handle both state changes and content changes for better detection
        if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED || 
            eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            // 0. Uninstall Protection Logic (Global Lock)
            
            // 0.1 Global Lock Logic (Protects MyTask and Admin)
            if (isGlobalLockActive) {
                // Whitelist: Allow PIN/Password/Lock screens
                if (className != null && (
                    className.contains("Password") || 
                    className.contains("Pin") || 
                    className.contains("Credential") || 
                    className.contains("Pattern") || 
                    className.contains("Lock") ||
                    className.contains("Biometric")
                )) {
                    // Do not block authentication screens
                    return
                }

                if (packageName == "com.android.settings") {
                    val text = event.text.toString().lowercase()
                    
                    // Only block specific dangerous keywords
                    // REMOVED: "delete" and "remove" which caused false positives with backspace/other settings
                    if (text.contains("admin") || 
                        text.contains("mytask") || 
                        text.contains("mytime") ||
                        text.contains("uninstall")) {
                        
                        performGlobalAction(GLOBAL_ACTION_BACK)
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        android.util.Log.d("AccessibilityService", "🛡️ Uninstall Protection Active: Blocked Settings Access")
                        return
                    }
                }
                
                if (packageName == "com.google.android.packageinstaller" || 
                    packageName == "com.android.packageinstaller") {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    return
                }
            }

            // 0.2 Blocked App Uninstall Protection
            // Optimization: Use HashSet for O(1) lookup instead of multiple string comparisons
            if (packageName != null && monitoredPackages.contains(packageName)) {
                
                // Optimization: Only convert text to string/lowercase if we are in a monitored package
                val text = event.text.toString().lowercase()
                
                // 1. Specific Check: Does the text contain the name of a blocked app?
                if (MainActivity.blockedAppNames.isNotEmpty()) {
                    for (appName in MainActivity.blockedAppNames) {
                        // Check if the text contains the app name
                        // We use a broader check: if the text contains the app name, AND we are in an installer/settings context
                        if (text.contains(appName)) {
                            
                            // If it's a launcher, we only care if "uninstall" or "remove" is also present
                            // or if we are in a popup/dialog
                            if (packageName.contains("launcher")) {
                                if (text.contains("uninstall") || text.contains("remove") || text.contains("app info")) {
                                    activateStickyProtection(appName)
                                    performGlobalAction(GLOBAL_ACTION_BACK)
                                    performGlobalAction(GLOBAL_ACTION_HOME)
                                    performGlobalAction(GLOBAL_ACTION_BACK)
                                    android.util.Log.d("AccessibilityService", "🛡️ Blocked Launcher Action for $appName")
                                    return
                                }
                            } else {
                                // In Settings/Installer, presence of app name is suspicious enough if we are in these packages
                                // But to be safe, let's also look for "uninstall" or "ok" or "delete" or just block it if it's the package installer
                                if (packageName.contains("packageinstaller")) {
                                    activateStickyProtection(appName)
                                    performGlobalAction(GLOBAL_ACTION_BACK)
                                    performGlobalAction(GLOBAL_ACTION_HOME)
                                    performGlobalAction(GLOBAL_ACTION_BACK)
                                    android.util.Log.d("AccessibilityService", "🛡️ Blocked Installer for $appName")
                                    return
                                }

                                // Google Play Store specific check
                                if (packageName == "com.android.vending") {
                                    if (text.contains("uninstall")) {
                                        activateStickyProtection(appName)
                                        performGlobalAction(GLOBAL_ACTION_BACK)
                                        performGlobalAction(GLOBAL_ACTION_HOME)
                                        performGlobalAction(GLOBAL_ACTION_BACK)
                                        android.util.Log.d("AccessibilityService", "🛡️ Blocked Play Store Action for $appName")
                                        return
                                    }
                                }
                                
                                // In Settings, we need to be more specific
                                if (text.contains("uninstall") || 
                                    text.contains("remove") || 
                                    text.contains("force stop")) {
                                     activateStickyProtection(appName)
                                     performGlobalAction(GLOBAL_ACTION_BACK)
                                     performGlobalAction(GLOBAL_ACTION_HOME)
                                     performGlobalAction(GLOBAL_ACTION_BACK)
                                     android.util.Log.d("AccessibilityService", "🛡️ Blocked Settings Action for $appName")
                                     return
                                }
                            }
                        }
                    }
                }
                
                // 2. Aggressive Check: If ANY app is blocked, be careful with "Uninstall" keywords
                if (MainActivity.blockedPackages.isNotEmpty()) {
                     // Check for keywords indicating uninstall or app management
                     if (text.contains("uninstall") || 
                         text.contains("remove") || 
                         text.contains("delete") ||
                         text.contains("app info") ||
                         text.contains("application info") ||
                         text.contains("force stop")) {
                         
                         // Check for class name to be sure it's an uninstall activity
                         if (className?.contains("UninstallAppProgress") == true || 
                             className?.contains("PackageInstallerActivity") == true ||
                             className?.contains("UninstallerActivity") == true ||
                             className?.contains("DeletePackageReceiver") == true) {
                             
                             activateStickyProtection("blocked_app")
                             performGlobalAction(GLOBAL_ACTION_BACK)
                             performGlobalAction(GLOBAL_ACTION_HOME)
                             performGlobalAction(GLOBAL_ACTION_BACK)
                             android.util.Log.d("AccessibilityService", "🛡️ Blocked App Uninstall Attempt Detected (Class Match)")
                             return
                         }
                         
                         // Also block "App Info" screen in Settings if it looks suspicious
                         if (className?.contains("InstalledAppDetails") == true || 
                             className?.contains("SubSettings") == true) {
                             
                             // If we see "uninstall" or "force stop" in the text, block it
                             if (text.contains("uninstall") || text.contains("force stop")) {
                                 activateStickyProtection("blocked_app")
                                 performGlobalAction(GLOBAL_ACTION_BACK)
                                 performGlobalAction(GLOBAL_ACTION_HOME)
                                 android.util.Log.d("AccessibilityService", "🛡️ Blocked Uninstall/ForceStop Button/Dialog")
                                 return
                             }
                         }
                     }
                }
            }

            // 1. Accessibility Protection: Only block when trying to disable MyTime's service
            // Allow access to Accessibility Settings for other apps/services
            if (packageName == "com.android.settings" && MainActivity.blockedPackages.isNotEmpty()) {
                val text = event.text.toString().lowercase()
                
                // Only block if text mentions MyTime/MyTask AND contains "off"/"stop"/"disable"
                // This allows accessing Accessibility Settings, but prevents disabling our service
                if ((text.contains("mytask") || text.contains("mytime")) && 
                    (text.contains("off") || text.contains("stop") || text.contains("disable"))) {
                    performGlobalAction(GLOBAL_ACTION_BACK)
                    performGlobalAction(GLOBAL_ACTION_HOME)
                    android.util.Log.d("AccessibilityService", "🛡️ Blocked attempt to disable MyTime Accessibility Service")
                    return
                }
            }

            // 2. App Blocking Logic (Only on STATE_CHANGED to avoid loops on content change)
            if (eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                if (packageName != null && 
                    MainActivity.blockedPackages.contains(packageName) &&
                    packageName != "com.example.mytask" &&
                    packageName != "com.android.systemui" &&
                    packageName != "android" &&
                    isBlockingActive) {
                    
                    // Block immediately without delay
                    blockAppSafely(packageName)
                }
                
                // 3. Usage Limiter Tracking
                if (packageName != null && MainActivity.limitedPackages.contains(packageName)) {
                    // App launched - get MainActivity instance and notify
                    try {
                        val mainActivity = applicationContext as? MainActivity
                        mainActivity?.notifyAppLaunched(packageName)
                    } catch (e: Exception) {
                        android.util.Log.e("AccessibilityService", "Failed to notify app launched: ${e.message}")
                    }
                }
            }
        }
    }
    
    private fun activateStickyProtection(appName: String) {
        stickyProtectionUntil = System.currentTimeMillis() + STICKY_PROTECTION_DURATION
        protectedPackageName = appName
        android.util.Log.d("AccessibilityService", "🔒 STICKY PROTECTION ACTIVATED for $appName (10s)")
    }
    
    private fun blockAppSafely(packageName: String) {
        try {
            val currentTime = System.currentTimeMillis()
            val lastTime = lastBlockTime[packageName] ?: 0
            
            // Reduced rate limit to allow faster blocking if user persists
            if (currentTime - lastTime < MIN_BLOCK_INTERVAL) {
                return
            }
            lastBlockTime[packageName] = currentTime
            
            // Double-check if app is still supposed to be blocked
            if (!MainActivity.blockedPackages.contains(packageName)) {
                return
            }
            
            // Safe blocking approach - single action only
            performGlobalAction(GLOBAL_ACTION_HOME)
            
            android.util.Log.d("AccessibilityService", "Safely blocked app: $packageName")
            
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Error blocking app: ${e.message}")
        }
    }

    override fun onInterrupt() {
        // Clean up resources
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
    }
    
    override fun onServiceConnected() {
        super.onServiceConnected()
        android.util.Log.d("AccessibilityService", "Service connected safely")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
    }
}