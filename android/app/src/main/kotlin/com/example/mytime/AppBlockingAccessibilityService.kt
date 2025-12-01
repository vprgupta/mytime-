package com.example.mytime

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper
import java.util.concurrent.atomic.AtomicBoolean

class AppBlockingAccessibilityService : AccessibilityService() {

    private val handler = Handler(Looper.getMainLooper())
    private val isProcessing = AtomicBoolean(false)
    private var currentLimitedApp: String? = null
    
    // Usage Limiter Logic
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
            // Update shared state in MainActivity
            MainActivity.usageLimits[packageName] = limitMinutes
            MainActivity.usageToday[packageName] = usedMinutes
            MainActivity.limitedPackages.add(packageName)
            
            android.util.Log.d("AccessibilityService", "✅ Updated limit for $packageName: $usedMinutes/$limitMinutes")
            
            // Persist immediately
            instance?.saveUsageStats(packageName)
            
            // Immediate check
            if (usedMinutes >= limitMinutes) {
                addBlockedApp(packageName)
                instance?.let { service ->
                    if (service.currentLimitedApp == packageName) {
                        service.triggerGlobalActionHome()
                    }
                }
            }
        }
        
        var instance: AppBlockingAccessibilityService? = null
    }
    
    private fun saveUsageStats(packageName: String) {
        try {
            val prefs = applicationContext.getSharedPreferences("UsageLimits", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            val limit = MainActivity.usageLimits[packageName] ?: 0
            val used = MainActivity.usageToday[packageName] ?: 0
            val accumulated = MainActivity.accumulatedUsage[packageName] ?: 0L
            
            editor.putInt("limit_$packageName", limit)
            editor.putInt("used_$packageName", used)
            editor.putLong("acc_$packageName", accumulated)
            editor.apply()
            
            android.util.Log.v("AccessibilityService", "💾 Saved stats for $packageName: $used/$limit (Acc: $accumulated)")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save usage stats: ${e.message}")
        }
    }
    
    private fun restoreUsageStats() {
        try {
            val prefs = applicationContext.getSharedPreferences("UsageLimits", Context.MODE_PRIVATE)
            val all = prefs.all
            
            var restoredCount = 0
            all.keys.forEach { key ->
                if (key.startsWith("limit_")) {
                    val packageName = key.removePrefix("limit_")
                    val limit = prefs.getInt(key, 0)
                    val used = prefs.getInt("used_$packageName", 0)
                    val accumulated = prefs.getLong("acc_$packageName", 0L)
                    
                    MainActivity.usageLimits[packageName] = limit
                    MainActivity.usageToday[packageName] = used
                    MainActivity.accumulatedUsage[packageName] = accumulated
                    MainActivity.limitedPackages.add(packageName)
                    
                    restoredCount++
                }
            }
            
            if (restoredCount > 0) {
                android.util.Log.d("AccessibilityService", "♻️ Restored usage stats for $restoredCount apps")
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore usage stats: ${e.message}")
        }
    }
    
    private fun incrementUsage(packageName: String) {
        val currentUsage = MainActivity.usageToday[packageName] ?: 0
        val newUsage = currentUsage + 1
        MainActivity.usageToday[packageName] = newUsage
        
        val limit = MainActivity.usageLimits[packageName] ?: Int.MAX_VALUE
        
        android.util.Log.d("AccessibilityService", "⏳ Usage for $packageName: $newUsage/$limit minutes")
        
        // Save state
        saveUsageStats(packageName)
        
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
                
                // Calculate partial usage before stopping
                val now = System.currentTimeMillis()
                val elapsedMillis = now - usageTrackingStartTime
                if (elapsedMillis > 0) {
                    val accumulated = (MainActivity.accumulatedUsage[currentLimitedApp!!] ?: 0L) + elapsedMillis
                    MainActivity.accumulatedUsage[currentLimitedApp!!] = accumulated
                    
                    // Save accumulated state
                    saveUsageStats(currentLimitedApp!!)
                    
                    // If accumulated > 1 minute, increment usage
                    if (accumulated >= 60000) {
                        val minutesToAdd = (accumulated / 60000).toInt()
                        val remainingMillis = accumulated % 60000
                        
                        // Add minutes
                        val currentUsage = MainActivity.usageToday[currentLimitedApp!!] ?: 0
                        val newUsage = currentUsage + minutesToAdd
                        MainActivity.usageToday[currentLimitedApp!!] = newUsage
                        MainActivity.accumulatedUsage[currentLimitedApp!!] = remainingMillis
                        
                        android.util.Log.d("AccessibilityService", "⏱️ Accumulated usage for ${currentLimitedApp!!}: +$minutesToAdd min (Total: $newUsage)")
                        
                        // Save updated state
                        saveUsageStats(currentLimitedApp!!)
                        
                        // Notify Flutter
                        try {
                            MainActivity.instance?.updateNativeUsage(currentLimitedApp!!, newUsage)
                        } catch (e: Exception) {}
                        
                        // Check limit
                        val limit = MainActivity.usageLimits[currentLimitedApp!!] ?: Int.MAX_VALUE
                        if (newUsage >= limit) {
                            addBlockedApp(currentLimitedApp!!)
                        }
                    }
                }
                
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
        // 1. Show overlay immediately to visually block interaction
        showBlockedOverlay()
        
        // 2. Wait a moment so user sees the message, then kick to home
        // Using a shorter delay (500ms) to be responsive but visible
        handler.postDelayed({
            performGlobalAction(GLOBAL_ACTION_HOME)
            
            // 3. Hide overlay shortly after kicking to home
            handler.postDelayed({
                hideBlockedOverlay()
            }, 1000)
        }, 500)
    }
    
    private fun showBlockedOverlay() {
        try {
            if (android.provider.Settings.canDrawOverlays(this)) {
                val intent = Intent(this, BlockedAppOverlayService::class.java)
                intent.action = BlockedAppOverlayService.ACTION_SHOW
                intent.putExtra("appName", "Blocked App") 
                startService(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to start overlay: ${e.message}")
        }
    }

    private fun hideBlockedOverlay() {
        try {
            val intent = Intent(this, BlockedAppOverlayService::class.java)
            intent.action = BlockedAppOverlayService.ACTION_HIDE
            startService(intent)
        } catch (e: Exception) {
            // Ignore
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        restoreBlockedApps()
        restoreUsageStats() // Restore usage limits and progress
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