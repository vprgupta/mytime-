package com.example.mytime

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

class AppBlockingAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private val isProcessing = AtomicBoolean(false)
    private val lastUsageNotificationTime = mutableMapOf<String, Long>()
    private var currentLimitedApp: String? = null
    
    // Usage Limiter Logic
    private val usageLimits = mutableMapOf<String, Int>() // Package -> Limit in minutes
    private val usageToday = mutableMapOf<String, Int>()  // Package -> Used minutes
    private var usageTrackingStartTime = 0L
    private val usageUpdateRunnable = object : Runnable {
        override fun run() {
            if (currentLimitedApp != null) {
                val now = System.currentTimeMillis()
                val elapsedMillis = now - usageTrackingStartTime
                
                if (elapsedMillis >= 60000) { // 1 minute
                    incrementUsage(currentLimitedApp!!)
                    usageTrackingStartTime = now
                }
                
                // Check again in 10 seconds (adaptive check)
                handler.postDelayed(this, 10000)
            }
        }
    }

    companion object {
        var isBlockingActive = false
        
        @JvmStatic
        fun addBlockedApp(packageName: String) {
            isBlockingActive = true
            android.util.Log.d("AccessibilityService", "🚫 Added blocked app: $packageName")
        }
        
        @JvmStatic
        fun removeBlockedApp(packageName: String) {
            android.util.Log.d("AccessibilityService", "✅ Removed blocked app: $packageName")
        }
        
        @JvmStatic
        fun updateAppLimit(packageName: String, limitMinutes: Int, usedMinutes: Int) {
            instance?.let { service ->
                service.usageLimits[packageName] = limitMinutes
                service.usageToday[packageName] = usedMinutes
                android.util.Log.d("AccessibilityService", "Updated limit for $packageName: $usedMinutes/$limitMinutes")
                
                // Immediate check
                if (usedMinutes >= limitMinutes) {
                    addBlockedApp(packageName)
                    if (service.currentLimitedApp == packageName) {
                        service.triggerGlobalActionHome()
                    }
                }
            }
        }
        
        var instance: AppBlockingAccessibilityService? = null
    }
    
    private fun incrementUsage(packageName: String) {
        val currentUsage = usageToday[packageName] ?: 0
        val newUsage = currentUsage + 1
        usageToday[packageName] = newUsage
        
        val limit = usageLimits[packageName] ?: Int.MAX_VALUE
        
        android.util.Log.d("AccessibilityService", "⏳ Usage for $packageName: $newUsage/$limit minutes")
        
        // Notify Flutter to keep UI in sync
        try {
            MainActivity.instance?.updateNativeUsage(packageName, newUsage)
        } catch (e: Exception) {
            // Ignore
        }
        
        if (newUsage >= limit) {
            android.util.Log.d("AccessibilityService", "🚫 Limit reached for $packageName! Blocking now.")
            addBlockedApp(packageName)
            triggerGlobalActionHome()
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        // Only process window state changes and content changes for more responsive blocking
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            // Debounce processing to avoid CPU spikes
            if (isProcessing.compareAndSet(false, true)) {
                processEvent(event)
                // Reset flag after a short delay
                handler.postDelayed({ isProcessing.set(false) }, 50)
            }
        }
    }

    private fun processEvent(event: AccessibilityEvent) {
        try {
            val packageName = event.packageName?.toString() ?: return
            
            // 1. Check if this is a blocked app
            if (MainActivity.blockedPackages.contains(packageName)) {
                android.util.Log.d("AccessibilityService", "🚫 Blocking detected app: $packageName")
                triggerGlobalActionHome()
                return
            }
            
            // 2. Security Hardening: Block "Clear Data" and "Disable Service" in Settings for MyTime
            if (packageName == "com.android.settings") {
                val text = event.text?.toString()?.lowercase() ?: ""
                
                // Only enforce strict protection if Commitment Mode is active
                if (MainActivity.isCommitmentActive) {
                    // Check if user is interacting with MyTime settings
                    if (text.contains("mytime") || text.contains("mytask")) {
                        // Block critical actions: Storage, Uninstall, Force Stop, Accessibility Disable
                        if (text.contains("storage") || text.contains("data") || 
                            text.contains("clear") || text.contains("cache") ||
                            text.contains("stop") || text.contains("force") ||
                            text.contains("uninstall") || text.contains("disable") ||
                            text.contains("accessibility") || text.contains("service") ||
                            text.contains("off") || text.contains("turn off")) {
                             
                             android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Prevented tampering in Settings")
                             triggerGlobalActionHome()
                             return
                        }
                    }
                }
            }

            // 3. Usage Limiter Tracking
            if (currentLimitedApp != null && currentLimitedApp != packageName) {
                // App switched away from limited app
                handler.removeCallbacks(usageUpdateRunnable)
                try {
                    MainActivity.instance?.notifyAppClosed(currentLimitedApp!!)
                } catch (e: Exception) {}
                currentLimitedApp = null
            }

            if (MainActivity.limitedPackages.contains(packageName)) {
                if (currentLimitedApp != packageName) {
                    // New limited app opened
                    currentLimitedApp = packageName
                    usageTrackingStartTime = System.currentTimeMillis()
                    
                    // Start tracking
                    handler.postDelayed(usageUpdateRunnable, 60000) // Check in 1 minute
                    
                    try {
                        MainActivity.instance?.notifyAppLaunched(packageName)
                    } catch (e: Exception) {}
                }
            }

        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Error processing event: ${e.message}")
        }
    }

    override fun onInterrupt() {
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
    }
    
    fun triggerGlobalActionHome() {
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        restoreBlockedApps()
        android.util.Log.d("AccessibilityService", "Service connected safely")
    }
    
    private fun restoreBlockedApps() {
        try {
            val prefs = applicationContext.getSharedPreferences("BlockingSessions", android.content.Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            var restoredCount = 0
            
            prefs.all.forEach { (packageName, endTime) ->
                if (endTime is Long && endTime > now) {
                    MainActivity.blockedPackages.add(packageName)
                    restoredCount++
                }
            }
            
            if (restoredCount > 0) {
                isBlockingActive = true
                android.util.Log.d("AccessibilityService", "♻️ Restored $restoredCount blocked apps from persistence")
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore blocked apps: ${e.message}")
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
        instance = null
    }
}