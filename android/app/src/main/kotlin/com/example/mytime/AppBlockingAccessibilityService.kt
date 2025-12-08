package com.example.mytime

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
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
        
        // Scheduler State
        data class TimeSchedule(val startHour: Int, val startMinute: Int, val endHour: Int, val endMinute: Int, val isEnabled: Boolean)
        val scheduledApps = mutableMapOf<String, TimeSchedule>()
        
        @JvmStatic
        fun setAppSchedule(packageName: String, startH: Int, startM: Int, endH: Int, endM: Int, enabled: Boolean) {
            scheduledApps[packageName] = TimeSchedule(startH, startM, endH, endM, enabled)
        }
        
        @JvmStatic
        fun removeAppSchedule(packageName: String) {
            scheduledApps.remove(packageName)
        }
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
            triggerGlobalActionHome(true)
        }
    }
    
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        
        val packageName = event.packageName?.toString()
        
        // 1. IMMEDIATE BLOCKING: Check if this is a blocked app FIRST (Bypass Debounce)
        if (MainActivity.blockedPackages.contains(packageName)) {
             processEvent(event)
             return
        }
        
        // CRITICAL SECURITY: Always process events from Settings or Package Installer immediately (No Debounce)
        // This prevents race conditions where a user taps fast or switches apps quickly
        if (packageName == "com.android.settings" || 
            packageName?.contains("packageinstaller") == true ||
            packageName == "com.google.android.packageinstaller") {
            processEvent(event)
            return
        }
        
        // CRITICAL: Process ALL click events immediately (no debounce)
        // This ensures we catch button taps in real-time
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            processEvent(event)
            return
        }
        
        // For other apps (Usage Tracking), use debounce to save battery
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
            
            // 0. WHITELIST: Never block MyTime itself
            if (packageName == "com.example.mytime") {
                return
            }
            
            // 1. Check if this is a blocked app (Manual Block)
            if (MainActivity.blockedPackages.contains(packageName)) {
                android.util.Log.d("AccessibilityService", "🚫 Blocking detected app: $packageName")
                triggerGlobalActionHome(true) // Immediate block
                return
            }
            
            // 1.5 Check Schedule (Auto Block)
            val schedule = AppBlockingAccessibilityService.scheduledApps[packageName]
            if (schedule != null && schedule.isEnabled) {
                // Check if CURRENT time is INSIDE the allowed window
                val now = java.util.Calendar.getInstance()
                val currentHour = now.get(java.util.Calendar.HOUR_OF_DAY)
                val currentMinute = now.get(java.util.Calendar.MINUTE)
                
                val currentTotal = currentHour * 60 + currentMinute
                val startTotal = schedule.startHour * 60 + schedule.startMinute
                val endTotal = schedule.endHour * 60 + schedule.endMinute
                
                var isAllowed = false
                if (startTotal <= endTotal) {
                    // Normal range (e.g. 09:00 - 17:00)
                    isAllowed = currentTotal in startTotal..endTotal
                } else {
                    // Overnight range (e.g. 22:00 - 06:00)
                    isAllowed = currentTotal >= startTotal || currentTotal <= endTotal
                }
                
                if (!isAllowed) {
                    android.util.Log.d("AccessibilityService", "🚫 Blocking scheduled app (Outside Window): $packageName")
                    triggerGlobalActionHome(true)
                    return
                }
            }
            
            // 2. Security Hardening: Block "Clear Data", "Disable Service", and "Uninstall"
            // We double check commitment state here to be safe
            if (!MainActivity.isCommitmentActive) {
                // Fallback check in case MainActivity was killed
                try {
                    val commitmentManager = CommitmentModeManager(applicationContext)
                    if (commitmentManager.isCommitmentActive()) {
                        MainActivity.isCommitmentActive = true
                    }
                } catch (e: Exception) {
                    // Ignore
                }
            }

            if (MainActivity.isCommitmentActive) {
                // PRIORITY 1: Detect CLICK events on uninstall-related buttons
                // This catches the moment the user taps "Uninstall" or "Deactivate"
                if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
                    val clickedNode = event.source
                    if (clickedNode != null) {
                        val viewId = clickedNode.viewIdResourceName?.lowercase() ?: ""
                        val text = clickedNode.text?.toString()?.lowercase() ?: ""
                        val desc = clickedNode.contentDescription?.toString()?.lowercase() ?: ""
                        val className = clickedNode.className?.toString() ?: ""
                        
                        android.util.Log.d("AccessibilityService", "🖱️ CLICK: id=$viewId, text=$text, desc=$desc, class=$className")
                        
                        // Detect uninstall button clicks by ID or text
                        val isUninstallClick = viewId.contains("uninstall") || 
                                              viewId.contains("delete") ||
                                              text.contains("uninstall") || 
                                              text.contains("remove") ||
                                              text.contains("delete") ||
                                              desc.contains("uninstall")
                        
                        // Detect deactivate admin button clicks
                        val isDeactivateClick = viewId.contains("deactivate") ||
                                               text.contains("deactivate") ||
                                               text.contains("remove admin") ||
                                               desc.contains("deactivate")
                        
                        if (isUninstallClick || isDeactivateClick) {
                            android.util.Log.d("AccessibilityService", "🛡️ BLOCKED CLICK: Uninstall/Deactivate button detected!")
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                }
                
                val text = event.text?.toString()?.lowercase() ?: ""
                val contentDescription = event.contentDescription?.toString()?.lowercase() ?: ""
                val combinedText = "$text $contentDescription"
                
                // GLOBAL SECURITY BLOCKS (Aggressive)
                // If Commitment Mode is active, we block these keywords GLOBALLY in Settings/Installers
                val isSettings = packageName.contains("settings") || packageName.contains("packageinstaller") || 
                                 packageName.contains("permission") || packageName.contains("vending")
                
                if (MainActivity.isCommitmentActive) {
                    // DEBUG LOGGING: Help us identify the exact package/text on OEM devices
                    android.util.Log.d("AccessibilityService", "🔍 Event: pkg=$packageName, text=$combinedText")
                
                if (isSettings) {
                        // 0. WHITELIST: Allow PIN/Password/Biometric screens
                        // This prevents false positives when accessing Hidden Folders, Private Safe, etc.
                        if (combinedText.contains("enter pin") || combinedText.contains("enter password") ||
                            combinedText.contains("unlock") || combinedText.contains("fingerprint") ||
                            combinedText.contains("face id") || combinedText.contains("confirm pin") ||
                            combinedText.contains("verify identity")) {
                            android.util.Log.d("AccessibilityService", "✅ Allowed PIN/Password screen")
                            return
                        }

                        // 1. Block Uninstall attempts
                        // Added "delete" and "ok" (often in confirmation dialogs) to be more aggressive
                        if (combinedText.contains("uninstall") || combinedText.contains("remove app") || 
                            (combinedText.contains("delete") && !combinedText.contains("delete account")) || // Avoid blocking account deletion if possible
                            (combinedText.contains("ok") && packageName.contains("packageinstaller"))) { // Common uninstallation confirmation
                            android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Prevented Uninstall action")
                            triggerGlobalActionHome(true) // Immediate block
                            return
                        }
                        
                        // 2. Block Admin Deactivation / Tampering
                        // Aggressively block ANY access to Device Admin settings for MyTime
                        if (combinedText.contains("device admin") || combinedText.contains("device policy") ||
                            combinedText.contains("admin app")) {
                            
                            // Block the "Activate device admin apps?" dialog entirely
                            if (combinedText.contains("activate") || combinedText.contains("deactivate") ||
                                combinedText.contains("this feature grants") || combinedText.contains("security risks")) {
                                android.util.Log.d("AccessibilityService", "🛡️ BLOCKED: Device Admin activation/deactivation dialog")
                                triggerGlobalActionHome(true)
                                return
                            }
                            
                            // If it mentions MyTime, or if we are on the specific "Activate/Deactivate" screen
                            if (combinedText.contains("mytime") || combinedText.contains("mytask") ||
                                combinedText.contains("remove")) {
                                android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Prevented Admin Access/Tampering")
                                triggerGlobalActionHome(true) // Immediate block
                                return
                            }
                        }
                        
                        // Refined Verification Code check (only if related to admin/mytime)
                        if (combinedText.contains("verification code") || combinedText.contains("captcha")) {
                             if (combinedText.contains("admin") || combinedText.contains("mytime")) {
                                 android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Prevented Verification Code")
                                 triggerGlobalActionHome(true)
                                 return
                             }
                        }
                        
                        // 3. Block Force Stop / Clear Data
                        if (combinedText.contains("force stop") || combinedText.contains("clear storage") || 
                            combinedText.contains("clear data") || combinedText.contains("clear cache")) {
                            android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Prevented Force Stop/Clear Data")
                            triggerGlobalActionHome(true) // Immediate block
                            return
                        }
                    }
                }

                // SPECIFIC SETTINGS PROTECTION (Enhanced with rootInActiveWindow)
                if (isSettings || packageName == "com.android.settings") {
                     // 0. Auto-Clear if Expired (Service-side check)
                    // This ensures that if the user is in Settings when time expires, 
                    // the Admin is removed immediately without needing to open the app.
                    try {
                        val manager = CommitmentModeManager(applicationContext)
                        manager.clearIfExpired()
                        // If we just cleared it, update our local flag
                        if (!manager.isCommitmentActive()) {
                            MainActivity.isCommitmentActive = false
                            return // Stop processing, let user do what they want
                        }
                    } catch (e: Exception) {
                        // Ignore
                    }

                    // Check if we are in a MyTime-related screen
                    // We check both the event text AND the actual screen content for robustness
                    var isMyTimeScreen = combinedText.contains("mytime") || combinedText.contains("mytask") || 
                                         combinedText.contains("my time") || combinedText.contains("my task")
                    
                    // Specific check for Accessibility Settings for MyTime
                    // This often appears as "MyTime" in the list or "MyTime" in the title
                    
                    // If event text doesn't have it (e.g. resume from background), check the window content
                    if (!isMyTimeScreen) {
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            isMyTimeScreen = isScreenRelatedToApp(rootNode)
                        }
                    }

                    if (isMyTimeScreen) {
                        // AGGRESSIVE BLOCK: If we are in the MyTime settings screen, BLOCK IMMEDIATELY.
                        // Do not wait for them to try to click the switch.
                        // This prevents the user from even seeing the toggle.
                        android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Aggressive Block - Prevented access to MyTime Settings")
                        triggerGlobalActionHome(true) // Immediate block
                        return
                    }
                    
                    // EXTRA AGGRESSIVE: Block "App Info" screen for MyTime
                    // If we see "App info" or indicators of the App Management screen AND "MyTime", block it.
                    // This prevents reaching the Uninstall/Force Stop buttons.
                    if (combinedText.contains("app info") || combinedText.contains("application info") ||
                        (combinedText.contains("storage") && combinedText.contains("cache")) || // Common on App Info
                         combinedText.contains("force stop")) {
                             
                        if (isMyTimeScreen) {
                             android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Blocked MyTime App Info Screen")
                             triggerGlobalActionHome(true)
                             return
                        }
                        
                        // Deep check for MyTime in window if not found in text
                        val rootNode = rootInActiveWindow
                        if (rootNode != null && isScreenRelatedToApp(rootNode)) {
                             android.util.Log.d("AccessibilityService", "🛡️ Commitment Mode: Blocked MyTime App Info Screen (Deep Check)")
                             triggerGlobalActionHome(true)
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
    
    private var lastBlockTriggerTime = 0L

    fun triggerGlobalActionHome(immediate: Boolean = false) {
        // Prevent double-triggering (debounce)
        val now = System.currentTimeMillis()
        if (now - lastBlockTriggerTime < 2000) {
            return
        }
        lastBlockTriggerTime = now

        // CRITICAL: Perform the home action IMMEDIATELY
        // This kicks the user out of the current screen
        try {
            performGlobalAction(GLOBAL_ACTION_HOME)
            android.util.Log.d("AccessibilityService", "✅ Performed GLOBAL_ACTION_HOME")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to perform home action: ${e.message}")
        }
        
        // THEN show overlay as visual feedback
        showBlockedOverlay()
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
        
        // Restore Commitment Mode State
        try {
            val commitmentManager = CommitmentModeManager(this)
            if (commitmentManager.isCommitmentActive()) {
                MainActivity.isCommitmentActive = true
                android.util.Log.d("AccessibilityService", "🔒 Restored Commitment Mode state: ACTIVE")
            } else {
                 MainActivity.isCommitmentActive = false
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore commitment state: ${e.message}")
        }

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
    
    private fun isScreenRelatedToApp(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        
        // Check current node text
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        
        if (text.contains("mytime") || text.contains("mytask") || 
            text.contains("my time") || text.contains("my task") ||
            desc.contains("mytime") || desc.contains("mytask") ||
            desc.contains("my time") || desc.contains("my task")) {
            return true
        }
        
        // Check children
        val count = node.childCount
        for (i in 0 until count) {
            val child = node.getChild(i)
            if (isScreenRelatedToApp(child)) {
                return true
            }
        }
        
        return false
    }

    private fun scanWindowForKeywords(node: AccessibilityNodeInfo?, keywords: List<String>): Boolean {
        if (node == null) return false
        
        val text = node.text?.toString()?.lowercase() ?: ""
        val desc = node.contentDescription?.toString()?.lowercase() ?: ""
        
        for (keyword in keywords) {
            if (text.contains(keyword) || desc.contains(keyword)) {
                return true
            }
        }
        
        val count = node.childCount
        for (i in 0 until count) {
            if (scanWindowForKeywords(node.getChild(i), keywords)) {
                return true
            }
        }
        return false
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
        instance = null
    }
}