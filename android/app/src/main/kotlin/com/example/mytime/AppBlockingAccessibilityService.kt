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
    
    // Throttling for WINDOW_CONTENT_CHANGED to avoid excessive checks
    private var lastContentChangeCheck = 0L
    private val CONTENT_CHANGE_THROTTLE_MS = 200L  // Check at most every 200ms (faster response)
    
    // Launch counter state tracking
    private var lastLaunchedApp: String? = null
    private var lastLaunchTime = 0L
    
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
    
    // Periodic Refresh for Expired Timers
    private val refreshRunnable = object : Runnable {
        override fun run() {
            // Check and clear expired commitment mode
            try {
                val manager = CommitmentModeManager(applicationContext)
                manager.clearIfExpired()
                if (!manager.isCommitmentActive()) {
                    MainActivity.isCommitmentActive = false
                }
            } catch (e: Exception) {
                // Ignore errors during commitment check
            }
            
            // Schedule next check in 1 minute
            handler.postDelayed(this, 60000)
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
        
        // Instance reference
        var instance: AppBlockingAccessibilityService? = null
        
        // STRATEGY 1: Cache commitment status to avoid expensive checks every event
        @Volatile private var cachedCommitmentStatus = false
        @Volatile private var commitmentCacheTime = 0L
        private const val COMMITMENT_CACHE_TTL_MS = 30000L  // 30 seconds cache
        
        // STRATEGY 3: Pre-emptive tap detection (detect BEFORE UI loads)
        @Volatile private var lastClickedAppInList: String? = null
        @Volatile private var lastClickTime = 0L
        private const val CLICK_MEMORY_MS = 2000L  // Remember click for 2 seconds
        
        // Launch Counter State
        private val launchCounts = mutableMapOf<String, Int>()
        private val launchLimits = mutableMapOf<String, Int>()
        private var currentDate = getCurrentDate()
        
        @JvmStatic
        private fun getCurrentDate(): String {
            val calendar = java.util.Calendar.getInstance()
           return "${calendar.get(java.util.Calendar.YEAR)}-${calendar.get(java.util.Calendar.MONTH)+1}-${calendar.get(java.util.Calendar.DAY_OF_MONTH)}"
        }
        
        @JvmStatic
        fun setLaunchLimit(packageName: String, limit: Int) {
            launchLimits[packageName] = limit
            android.util.Log.d("AccessibilityService", "📊 Set launch limit for $packageName: $limit times/day")
        }
        
        @JvmStatic
        fun getLaunchCount(packageName: String): Int {
            checkAndResetIfNewDay()
            return launchCounts.getOrDefault(packageName, 0)
        }
        
        @JvmStatic
        fun getLaunchLimit(packageName: String): Int {
            return launchLimits.getOrDefault(packageName, 0)
       }
        
        @JvmStatic
        private fun checkAndResetIfNewDay() {
            val today = getCurrentDate()
            if (today != currentDate) {
                android.util.Log.d("AccessibilityService", "🌅 New day detected - resetting launch counters")
                
                // Unblock apps that were blocked due to launch limits
                val appsToUnblock = launchLimits.keys.toList()
                for (packageName in appsToUnblock) {
                    MainActivity.blockedPackages.remove(packageName)
                    android.util.Log.d("AccessibilityService", "✅ Unblocked $packageName for new day")
                }
                
                launchCounts.clear()
                currentDate = today
                // Persist the date change
                instance?.saveCurrentDate()
            }
        }
        
        @JvmStatic
        fun onAppLaunched(packageName: String): Boolean {
            checkAndResetIfNewDay()
            
            val limit = launchLimits.getOrDefault(packageName, 0)
            if (limit <= 0) {
                // No limit set for this app, don't count it
                return false
            }
           
            val count = launchCounts.getOrDefault(packageName, 0) + 1
            launchCounts[packageName] = count
            
            // Persist the updated count immediately
            instance?.saveLaunchCount(packageName, count)
            
            android.util.Log.d("AccessibilityService", "📱 App launched: $packageName ($count/$limit)")
            
            if (count > limit) {
                android.util.Log.d("AccessibilityService", "🚫 Launch limit exceeded for $packageName - adding to blocked list")
                // Add to blocked packages so it stays blocked for the rest of the day
                MainActivity.blockedPackages.add(packageName)
                addBlockedApp(packageName)
                return true // Block
            }
            
            return false // Allow
        }
        
        @JvmStatic
        fun removeLaunchLimit(packageName: String) {
            launchLimits.remove(packageName)
            launchCounts.remove(packageName)
            instance?.clearLaunchCount(packageName)
            
            // Remove from blocked list if it was blocked due to launch limit
            MainActivity.blockedPackages.remove(packageName)
            
            android.util.Log.d("AccessibilityService", "🗑️ Removed launch limit for $packageName and unblocked if necessary")
        }
        
        // Scheduler State
        data class TimeSchedule(val startHour: Int, val startMinute: Int, val endHour: Int, val endMinute: Int, val isEnabled: Boolean)
        val scheduledApps = mutableMapOf<String, TimeSchedule>()
        
       @JvmStatic
        fun setAppSchedule(packageName: String, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int, isEnabled: Boolean) {
            scheduledApps[packageName] = TimeSchedule(startHour, startMinute, endHour, endMinute, isEnabled)
            android.util.Log.d("AccessibilityService", "📅 Schedule set for $packageName: $startHour:$startMinute-$endHour:$endMinute (enabled=$isEnabled)")
        }
        
        @JvmStatic
        fun removeAppSchedule(packageName: String) {
            scheduledApps.remove(packageName)
            android.util.Log.d("AccessibilityService", "🗑️ Schedule removed for $packageName")
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
    
    private fun saveLaunchCount(packageName: String, count: Int) {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            editor.putInt("count_$packageName", count)
            editor.apply()
            android.util.Log.v("AccessibilityService", "💾 Saved launch count for $packageName: $count")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save launch count: ${e.message}")
        }
    }
    
    private fun clearLaunchCount(packageName: String) {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", Context.MODE_PRIVATE)
            prefs.edit().remove("count_$packageName").apply()
            android.util.Log.v("AccessibilityService", "🗑️ Cleared launch count for $packageName")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to clear launch count: ${e.message}")
        }
    }
    
    private fun restoreLaunchCounts() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", Context.MODE_PRIVATE)
            
            // Check if we need to reset for a new day
            val savedDate = prefs.getString("current_date", "")
            val today = AppBlockingAccessibilityService.getCurrentDate()
            
            if (savedDate != today) {
                // New day - clear all counts
                android.util.Log.d("AccessibilityService", "🌅 New day detected ($savedDate -> $today) - clearing launch counts")
                val editor = prefs.edit()
                editor.clear()
                editor.putString("current_date", today)
                editor.apply()
                AppBlockingAccessibilityService.currentDate = today
                return
            }
            
            // Same day - restore counts
            val all = prefs.all
            var restoredCount = 0
            
            all.keys.forEach { key ->
                if (key.startsWith("count_")) {
                    val packageName = key.removePrefix("count_")
                    val count = prefs.getInt(key, 0)
                    AppBlockingAccessibilityService.launchCounts[packageName] = count
                    restoredCount++
                }
            }
            
            if (restoredCount > 0) {
                android.util.Log.d("AccessibilityService", "♻️ Restored launch counts for $restoredCount apps")
            }
            
            AppBlockingAccessibilityService.currentDate = today
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore launch counts: ${e.message}")
        }
    }
    
    private fun saveCurrentDate() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", Context.MODE_PRIVATE)
            prefs.edit().putString("current_date", AppBlockingAccessibilityService.currentDate).apply()
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save current date: ${e.message}")
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
        
        // 0. ULTRA-EARLY APP INFO BLOCKING - Detects both initial load AND background resume
        // NO THROTTLING: With our optimizations (cached checks + fast scan), this is fast enough
        // to run on every event without performance issues
        if ((event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) &&
            packageName?.contains("settings") == true) {
            
            // STRATEGY 1: Use cached commitment check (saves 5-10ms)
            val hasCommitment = checkCommitmentCached()  // ~0.1ms instead of ~10ms
            
            if (hasCommitment) {
                val className = event.className?.toString() ?: ""
                
                // Instantly detect app info activity class
                val isAppInfo = className.contains("AppInfoDashboard") ||
                               className.contains("InstalledAppDetails") ||
                               className.contains("ApplicationInfo") ||
                               className.contains("AppDetails")
                
                if (isAppInfo) {
                    // SIMPLIFIED: Always check window content immediately (like battery detection)
                    // No tap tracking needed - window check is fast enough now (~5-10ms)
                    try {
                        val rootNode = rootInActiveWindow
                        
                        if (rootNode != null) {
                            // Quick check: event data first (fastest)
                            val eventText = event.text?.toString()?.lowercase() ?: ""
                            val eventDesc = event.contentDescription?.toString()?.lowercase() ?: ""
                            
                            if (eventText.contains("com.example.mytime") || 
                                eventDesc.contains("com.example.mytime") ||
                                (eventText.contains("mytime") && !eventText.contains("search")) ||
                                (eventDesc.contains("mytime") && !eventDesc.contains("search"))) {
                                
                                android.util.Log.e("AccessibilityService", "⚡ INSTANT BLOCK: MyTime App Info!")
                                showCommitmentWarning()
                                // CRITICAL: Use immediate=true to bypass debounce in triggerGlobalActionHome
                                // We WANT rapid repeated blocks for background resume!
                                triggerGlobalActionHome(immediate = true)
                                return
                            }
                            
                            // Fallback: Fast window scan if event data empty
                            val isMyTimeAppInfo = findMyTimePackageNameFast(rootNode)
                            if (isMyTimeAppInfo) {
                                android.util.Log.e("AccessibilityService", "⚡ FAST BLOCK: MyTime App Info!")
                                showCommitmentWarning()
                                triggerGlobalActionHome(immediate = true)  // Bypass debounce
                                return
                            }
                        }
                    } catch (e: Exception) {
                        android.util.Log.e("AccessibilityService", "Error in app info detection: ${e.message}")
                    }
                }
            }
        }
        
        // 1. IMMEDIATE BLOCKING: Check if this is a blocked app FIRST (Bypass ALL Debounce)
        // Process ANY event type for blocked apps instantly
        if (MainActivity.blockedPackages.contains(packageName)) {
             processEvent(event)
             return
        }
        
        // 2. Check scheduled apps - also needs instant blocking
        if (scheduledApps.containsKey(packageName)) {
            processEvent(event)
            return
        }
        
        // 3. Check usage limited apps - instant blocking when limit reached
       if (MainActivity.limitedPackages.contains(packageName)) {
            val currentUsage = MainActivity.usageToday[packageName] ?: 0
            val limit = MainActivity.usageLimits[packageName] ?: Int.MAX_VALUE
            if (currentUsage >= limit) {
                // Limit reached, block instantly
                processEvent(event)
                return
            }
        }
        
        // 4. Launch counter moved to processEvent() to only count actual app launches
        
        // CRITICAL SECURITY: Always process events from Settings or Package Installer immediately (No Debounce)
        // This prevents race conditions where a user taps fast or switches apps quickly
        if (packageName == "com.android.settings" || 
            packageName?.contains("packageinstaller") == true ||
            packageName == "com.google.android.packageinstaller") {
            processEvent(event)
            return
        }
        
        // CRITICAL: Detect and log ALL click events for debugging
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED) {
            val clickedText = event.text?.toString()?.lowercase() ?: ""
            val clickedDesc = event.contentDescription?.toString()?.lowercase() ?: ""
            val clickedId = try { event.source?.viewIdResourceName ?: "" } catch (e: Exception) { "" }
            
            android.util.Log.d("AccessibilityService", "🖱️ CLICK: id=$clickedId, text=$clickedText, desc=$clickedDesc, pkg=${event.packageName}")
            
            // IMMEDIATE BLOCK: If click contains dangerous keywords for MyTime
            val packageName = event.packageName?.toString() ?: ""
            if (packageName.contains("settings") || packageName.contains("systemui")) {
                val combinedClickText = "$clickedText $clickedDesc $clickedId".lowercase()
                
                // Check if this click is on a dangerous button for MyTime
                val isDangerousClick = combinedClickText.contains("force") ||
                                      combinedClickText.contains("stop") ||
                                      combinedClickText.contains("uninstall") ||
                                      combinedClickText.contains("disable") ||
                                      combinedClickText.contains("clear") ||
                                      combinedClickText.contains("delete") ||
                                      combinedClickText.contains("remove")
                
                if (isDangerousClick) {
                    // Check if MyTime context exists
                    val rootNode = rootInActiveWindow
                    if (rootNode != null) {
                        val windowText = getWindowText(rootNode).lowercase()
                        if (windowText.contains("mytime") || windowText.contains("my time")) {
                            android.util.Log.e("AccessibilityService", "🚨 BLOCKED DANGEROUS CLICK for MyTime: $combinedClickText")
                            showCommitmentWarning()
                            triggerGlobalActionHome(true)
                            handler.postDelayed({ triggerGlobalActionHome(false) }, 50)
                            handler.postDelayed({ triggerGlobalActionHome(false) }, 100)
                            return
                        }
                    }
                }
            }
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
            
            // 0.5 LAUNCH COUNTER: Only count actual app launches (not every event)
            // Only increment when window state changes AND it's a different app or enough time has passed
            if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                val now = System.currentTimeMillis()
                
                // Only count as new launch if:
                // 1. Different app AND at least 500ms since last count (prevents rapid switching noise), OR
                // 2. Same app but more than 2 seconds since last count (counts background->foreground as new launch)
                val isDifferentApp = packageName != lastLaunchedApp
                val timeSinceLastCount = now - lastLaunchTime
                
                val shouldCount = if (isDifferentApp) {
                    timeSinceLastCount > 500  // Different app: require 500ms gap
                } else {
                    timeSinceLastCount > 2000  // Same app: require 2 second gap (counts background resumes)
                }
                
                if (shouldCount) {
                    val shouldBlock = onAppLaunched(packageName)
                    if (shouldBlock) {
                        android.util.Log.d("AccessibilityService", "🚫 Blocking $packageName - launch limit exceeded")
                        triggerGlobalActionHome(true)
                        return
                    }
                    lastLaunchedApp = packageName
                    lastLaunchTime = now
                }
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
            // Check for ANY active commitments (strict mode OR usage limiter)
            val hasAnyCommitment = checkForAnyActiveCommitments()
            
            if (hasAnyCommitment) {
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
                        
                        // CRITICAL: Detect Force Stop button clicks
                        // This catches force stop from ANY screen (battery, app info, etc)
                        val isForceStopClick = viewId.contains("force_stop") ||
                                              viewId.contains("forcestop") ||
                                              text.contains("force stop") ||
                                              text.contains("force close") ||
                                              desc.contains("force stop") ||
                                              desc.contains("force close")
                        
                        if (isForceStopClick) {
                            // Check if we're in a MyTime-related screen
                            val rootNode = rootInActiveWindow
                            if (rootNode != null) {
                                val windowText = getWindowText(rootNode).lowercase()
                                val isMyTimeContext = windowText.contains("mytime") ||
                                                     windowText.contains("my time") ||
                                                     windowText.contains("com.example.mytime")
                                
                                if (isMyTimeContext) {
                                    android.util.Log.d("AccessibilityService", "🛡️ BLOCKED: Force Stop button click for MyTime!")
                                    showCommitmentWarning()
                                    triggerGlobalActionHome(true)
                                    return
                                }
                            }
                        }
                        
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
                            showCommitmentWarning()
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                }
                
                // UNIVERSAL UNINSTALL PROTECTION: Detect uninstall attempts from ANY source
                // This catches homescreen uninstalls, settings uninstalls, and any other method
                if (hasAnyCommitment) {
                    android.util.Log.d("AccessibilityService", "✅ Commitment active, checking package: $packageName")
                    
                    // Check if this is an uninstall-related package OR launcher (for homescreen uninstalls)
                    val isUninstallPackage = packageName.contains("packageinstaller") ||
                                            packageName.contains("uninstaller") ||
                                            packageName.contains("installer") ||
                                            packageName == "com.android.packageinstaller" ||
                                            packageName == "com.google.android.packageinstaller"
                    
                    val isLauncher = packageName.contains("launcher") ||
                                    packageName.contains("trebuchet") ||  // LineageOS
                                    packageName.contains("pixel") ||       // Pixel Launcher
                                    packageName.contains("nova") ||        // Nova Launcher
                                    packageName.contains("lawnchair")      // Lawnchair
                    
                    android.util.Log.d("AccessibilityService", "📦 Is uninstall package: $isUninstallPackage, Is launcher: $isLauncher")
                    
                    if (isUninstallPackage || isLauncher) {
                        // Scan window for MyTime app name or package AND uninstall-related text
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            val windowText = getWindowText(rootNode).lowercase()
                            android.util.Log.d("AccessibilityService", "🔍 Window text: ${windowText.take(200)}")
                            
                            val isMyTimeUninstall = windowText.contains("mytime") ||
                                                   windowText.contains("my time") ||
                                                   windowText.contains("com.example.mytime")
                            
                            val hasUninstallText = windowText.contains("uninstall") ||
                                                  windowText.contains("remove") ||
                                                  windowText.contains("delete")
                            
                            android.util.Log.d("AccessibilityService", "🎯 Is MyTime: $isMyTimeUninstall, Has uninstall text: $hasUninstallText")
                            
                            // Block if BOTH conditions are met: MyTime is mentioned AND uninstall action
                            if (isMyTimeUninstall && hasUninstallText) {
                                android.util.Log.d("AccessibilityService", "🛡️ BLOCKED: MyTime uninstall dialog detected!")
                                showCommitmentWarning()
                                triggerGlobalActionHome(true)
                                return
                            }
                        } else {
                            android.util.Log.d("AccessibilityService", "⚠️ Root node is null")
                        }
                    }
                } else {
                    android.util.Log.d("AccessibilityService", "❌ No commitment active")
                }
                
                val text = event.text?.toString()?.lowercase() ?: ""
                val contentDescription = event.contentDescription?.toString()?.lowercase() ?: ""
                val combinedText = "$text $contentDescription"
                
                // SURGICAL BLOCKING: Only block MyTime-specific actions
                // Allow everything else (other apps, general settings, etc.)
                
                // Expanded to cover ALL major Android manufacturers
                val isSettings = packageName.contains("settings") || 
                                 packageName.contains("packageinstaller") || 
                                 packageName.contains("permission") || 
                                 packageName.contains("vending") ||
                                 packageName.contains("battery") ||  // Battery settings (all OEMs)
                                 packageName.contains("power") ||     // Power/Battery management
                                 packageName.contains("devicehealth") ||     // Samsung
                                 packageName.contains("devicecare") ||       // Samsung One UI
                                 packageName.contains("powerkeeper") ||      // Xiaomi MIUI
                                 packageName.contains("powermonitor") ||     // OnePlus/ColorOS
                                 packageName.contains("batteryoptimize") ||  // Generic
                                 // Samsung/OneUI
                                 packageName.contains("samsung") ||
                                 // Xiaomi/MIUI
                                 packageName.contains("miui") ||
                                 packageName.contains("securitycenter") ||
                                 // OnePlus/ColorOS/Oppo
                                 packageName.contains("coloros") ||
                                 packageName.contains("safecenter") ||
                                 packageName.contains("oneplus") ||
                                 packageName.contains("oplus") ||  // OnePlus battery app
                                 // Vivo/FuntouchOS
                                 packageName.contains("vivo") ||
                                 packageName.contains("iqoo") ||
                                 // Realme/RealmeUI
                                 packageName.contains("realme") ||
                                 // Huawei/EMUI
                                 packageName.contains("huawei") ||
                                 packageName.contains("honor") ||
                                 // Motorola
                                 packageName.contains("motorola") ||
                                 // Google Pixel
                                 packageName.contains("google.android")
                
                if (hasAnyCommitment && isSettings) {
                    // Auto-clear if expired (strict mode only)
                    try {
                        val manager = CommitmentModeManager(applicationContext)
                        manager.clearIfExpired()
                        if (!manager.isCommitmentActive()) {
                            MainActivity.isCommitmentActive = false
                        }
                    } catch (e: Exception) {
                        // Ignore
                    }
                    
                    // STEP 1: Check if this screen is related to MyTime
                    // Check for both app name AND package name
                    var isMyTimeScreen = combinedText.contains("mytime") || combinedText.contains("mytask") || 
                                         combinedText.contains("my time") || combinedText.contains("my task") ||
                                         combinedText.contains("com.example.mytime")
                    
                    // If not found in text, scan the window content
                    if (!isMyTimeScreen) {
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            isMyTimeScreen = isScreenRelatedToApp(rootNode)
                            
                            // Additional check: scan for package name in window
                            if (!isMyTimeScreen) {
                                val windowText = getWindowText(rootNode).lowercase()
                                isMyTimeScreen = windowText.contains("com.example.mytime") ||
                                                windowText.contains("mytime") ||
                                                windowText.contains("my time")
                                
                                if (isMyTimeScreen) {
                                    android.util.Log.d("AccessibilityService", "🔍 Found MyTime via package name scan")
                                }
                            }
                        }
                    }
                    
                    
                    // STEP 2: COMPLETE BLOCKING - Block entire MyTime settings screen during commitment
                    // This prevents force stop, clear data, uninstall, and all other dangerous actions
                    if (isMyTimeScreen && (packageName.contains("settings") || packageName.contains("systemui"))) {
                        
                        // Refined check: Ensure we are actually on an App Info/Details screen, NOT just a list/search result
                        // We check for keywords typical of the App Info page
                        val isAppInfoPage = combinedText.contains("force stop") || 
                                           combinedText.contains("force close") ||
                                           combinedText.contains("uninstall") || 
                                           combinedText.contains("disable") ||
                                           combinedText.contains("open") ||
                                           combinedText.contains("storage") ||
                                           combinedText.contains("permissions") ||
                                           combinedText.contains("notifications") ||
                                           combinedText.contains("app info") ||
                                           combinedText.contains("application info")
                        
                        if (isAppInfoPage) {
                            android.util.Log.e("AccessibilityService", "🚨 INSTANT BLOCK: MyTime App Info screen detected!")
                            showCommitmentWarning()
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                    
                    // Separate check: Always block accessibility settings for MyTime
                    // This needs comprehensive detection for all manufacturers
                    if (isMyTimeScreen) {
                        val isAccessibilityScreen = combinedText.contains("accessibility") ||
                                                   combinedText.contains("service") ||
                                                   combinedText.contains("switch") ||
                                                   combinedText.contains("toggle") ||
                                                   combinedText.contains("turn off") ||
                                                   combinedText.contains("turn on") ||
                                                   combinedText.contains("disable") ||
                                                   combinedText.contains("enable") ||
                                                   combinedText.contains("keep on") ||
                                                   combinedText.contains("keep off") ||
                                                   combinedText.contains("deactivate") ||  // Samsung
                                                   combinedText.contains("activate") ||
                                                   combinedText.contains("stop") ||        // Xiaomi
                                                   combinedText.contains("revoke") ||      // Xiaomi
                                                   combinedText.contains("close") ||       // Vivo/Oppo
                                                   combinedText.contains("shut down") ||   // Vivo/Oppo
                                                   combinedText.contains("stop using") ||  // Samsung
                                                   combinedText.contains("allowed") ||     // Permission screens
                                                   combinedText.contains("permitted") ||
                                                   packageName.contains("accessibility")
                        
                        if (isAccessibilityScreen) {
                            android.util.Log.d("AccessibilityService", "🛡️ Blocked: MyTime Accessibility Settings")
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                    
                    // INSTANT BATTERY BLOCKING: Block MyTime battery detail page immediately on load
                    // This prevents force-stopping through battery settings
                    // CRITICAL: Only check battery blocking for ACTUAL battery packages, not Settings
                    // This prevents interference with Settings search bar
                    if (isMyTimeScreen) {
                        // STRICT CHECK: Only battery-specific packages, NOT general Settings
                        val isBatteryPackage = packageName.contains("battery") ||
                                              packageName.contains("power") ||
                                              packageName.contains("devicecare") ||
                                              packageName.contains("powerkeeper") ||
                                              packageName.contains("powermonitor")
                        
                        // DO NOT include "settings" here - causes search bar interference!
                        
                        if (isBatteryPackage) {
                            // Battery package detected - check if it's MyTime's detail page
                            // Count how many different apps are mentioned
                            val windowText = try {
                                val rootNode = rootInActiveWindow
                                if (rootNode != null) getWindowText(rootNode).lowercase() else ""
                            } catch (e: Exception) {
                                ""
                            }
                            
                            // If it's a list, multiple common app names will appear
                            val commonAppCount = listOf(
                                "instagram", "facebook", "whatsapp", "chrome", 
                                "youtube", "gmail", "twitter", "telegram"
                            ).count { windowText.contains(it) }
                            
                            // If less than 2 other apps mentioned, this is likely MyTime's detail page
                            val isDetailPage = commonAppCount < 2
                            
                            // ALSO check for package name visibility - detail pages often show package name
                            val hasPackageName = combinedText.contains("com.example.mytime") ||
                                                windowText.contains("com.example.mytime")
                            
                            if (isDetailPage || hasPackageName) {
                                android.util.Log.d("AccessibilityService", "🔋 INSTANT BLOCK: MyTime Battery Detail Page (commonApps=$commonAppCount, hasPkg=$hasPackageName)")
                                showCommitmentWarning()
                                triggerGlobalActionHome(true)
                                return
                            } else {
                                android.util.Log.d("AccessibilityService", "✅ ALLOWED: Battery list page (multiple apps: $commonAppCount)")
                            }
                        }
                    }
                    
                    // Separate check: Always block package installer for MyTime
                    if (isMyTimeScreen && packageName.contains("packageinstaller")) {
                        android.util.Log.d("AccessibilityService", "🛡️ Blocked: MyTime Uninstall Dialog")
                        showCommitmentWarning()
                        triggerGlobalActionHome(true)
                        return
                    }
                    // If not MyTime-related, ALLOW (do nothing, let it proceed)
                    else {
                        android.util.Log.d("AccessibilityService", "✅ Allowed: Not MyTime-related ($packageName)")
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
                } else {
                    // CONTINUOUS TRACKING: App is still active, check if we need to increment
                    val now = System.currentTimeMillis()
                    val elapsedMillis = now - usageTrackingStartTime
                    
                    // If 60 seconds have passed, increment usage
                    if (elapsedMillis >= 60000) {
                        val minutesPassed = (elapsedMillis / 60000).toInt()
                        
                        if (minutesPassed > 0) {
                            val currentUsage = MainActivity.usageToday[packageName] ?: 0
                            val newUsage = currentUsage + minutesPassed
                            MainActivity.usageToday[packageName] = newUsage
                            
                            // Reset tracking start time (keep remainder)
                            usageTrackingStartTime = now - (elapsedMillis % 60000)
                            
                            android.util.Log.d("AccessibilityService", "⏱️ Continuous: $packageName +$minutesPassed min (Total: $newUsage)")
                            
                            // Save state
                            saveUsageStats(packageName)
                            
                            // Notify Flutter
                            try {
                                MainActivity.instance?.updateNativeUsage(packageName, newUsage)
                            } catch (e: Exception) {}
                            
                            // Check if limit reached
                            val limit = MainActivity.usageLimits[packageName] ?: Int.MAX_VALUE
                            if (newUsage >= limit) {
                                android.util.Log.d("AccessibilityService", "🚫 Limit reached: $packageName")
                                triggerGlobalActionHome(false)
                                currentLimitedApp = null
                            }
                        }
                    }
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
    private var lastBlockedPackage: String? = null

    fun triggerGlobalActionHome(immediate: Boolean = false) {
    val now = System.currentTimeMillis()
    
    // Only debounce if NOT immediate and it's the SAME package being blocked repeatedly
    // immediate=true bypasses debounce (used for app info/battery detection)
    if (!immediate) {
        val currentPackage = rootInActiveWindow?.packageName?.toString()
        if (currentPackage == lastBlockedPackage && now - lastBlockTriggerTime < 1000) {
            // Same app blocked within 1 second, skip to prevent spam
            return
        }
        lastBlockTriggerTime = now
        lastBlockedPackage = currentPackage
    }

    // CRITICAL: Perform the home action IMMEDIATELY
    // This kicks the user out of the current screen
    try {
        performGlobalAction(GLOBAL_ACTION_HOME)
        val pkg = rootInActiveWindow?.packageName?.toString()
        android.util.Log.d("AccessibilityService", "✅ Performed GLOBAL_ACTION_HOME for $pkg (immediate=$immediate)")
    } catch (e: Exception) {
        android.util.Log.e("AccessibilityService", "Failed to perform home action: ${e.message}")
    }
    
    // THEN show overlay as visual feedback (non-blocking)
    handler.post { showBlockedOverlay() }
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
        
        // Start periodic refresh to check for expired timers
        handler.post(refreshRunnable)
        android.util.Log.d("AccessibilityService", "⏰ Started periodic refresh for timer expiry")

        restoreBlockedApps()
        restoreUsageStats() // Restore usage limits and progress
        restoreLaunchCounts() // Restore launch counts and daily tracking
        android.util.Log.d("AccessibilityService", "✅ Service connected and all data restored")
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
    
    /**
     * STRATEGY 1: Cached commitment check (saves 5-10ms per detection)
     * Only checks actual commitment status every 30 seconds
     */
    private fun checkCommitmentCached(): Boolean {
        val now = System.currentTimeMillis()
        
        // Check if cache is still valid
        if (now - commitmentCacheTime < COMMITMENT_CACHE_TTL_MS) {
            return cachedCommitmentStatus  // Return cached value (~0.1ms)
        }
        
        // Cache expired, recheck and update cache
        cachedCommitmentStatus = checkForAnyActiveCommitments()  // ~5-10ms
        commitmentCacheTime = now
        
        return cachedCommitmentStatus
    }
    
    /**
     * Check if there are ANY active commitments (strict mode OR usage limiter)
     */
    private fun checkForAnyActiveCommitments(): Boolean {
        try {
            // Check strict mode commitment
            if (MainActivity.isCommitmentActive) {
                return true
            }
            
            // Fallback check for strict mode
            try {
                val commitmentManager = CommitmentModeManager(applicationContext)
                if (commitmentManager.isCommitmentActive()) {
                    MainActivity.isCommitmentActive = true
                    return true
                }
            } catch (e: Exception) {
                // Ignore
            }
            
            // Check usage limiter commitments
            val prefs = applicationContext.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val keys = prefs.all.keys
            
            for (key in keys) {
                if (key.startsWith("flutter.usage_limit_durations_")) {
                    val value = prefs.getString(key, null)
                    if (value != null && value.contains("\"hasCommitment\":true")) {
                        // Found an active usage limiter commitment
                        android.util.Log.d("AccessibilityService", "🔒 Found active usage limiter commitment")
                        return true
                    }
                }
            }
            
            return false
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Error checking commitments", e)
            return false
        }
    }
    
    /**
     * OPTIMIZED: Fast targeted search for MyTime package/app name
     * Uses breadth-first search with depth limit and early exit
     * ~10x faster than getWindowText() on first access
     */
    private fun findMyTimePackageNameFast(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        
        val maxDepth = 8  // Limit search depth (package name usually near top)
        val queue = ArrayDeque<Pair<AccessibilityNodeInfo, Int>>()
        queue.add(Pair(node, 0))
        
        while (queue.isNotEmpty()) {
            val (currentNode, depth) = queue.removeFirst()
            
            // Check this node's text and content description
            val nodeText = currentNode.text?.toString()?.lowercase() ?: ""
            val nodeDesc = currentNode.contentDescription?.toString()?.lowercase() ?: ""
            
            // Early exit if found
            if (nodeText.contains("com.example.mytime") || 
                nodeDesc.contains("com.example.mytime") ||
                (nodeText.contains("mytime") && !nodeText.contains("search"))) {
                return true
            }
            
            // Stop if we've gone too deep
            if (depth >= maxDepth) continue
            
            // Add children to queue
            for (i in 0 until currentNode.childCount) {
                currentNode.getChild(i)?.let { child ->
                    queue.add(Pair(child, depth + 1))
                }
            }
        }
        
        return false
    }
    
    /**
     * Extract all text from a window node tree
     */
    private fun getWindowText(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        
        val textBuilder = StringBuilder()
        
        // Add this node's text
        node.text?.let { textBuilder.append(it).append(" ") }
        node.contentDescription?.let { textBuilder.append(it).append(" ") }
        
        // Recursively add children's text
        for (i in 0 until node.childCount) {
            textBuilder.append(getWindowText(node.getChild(i)))
        }
        
        return textBuilder.toString()
    }
    
    /**
 * Show a toast warning about active commitments
 */
private fun showCommitmentWarning() {
    try {
        handler.post {
            // Get remaining time for better UX
            val remainingTime = try {
                val manager = CommitmentModeManager(applicationContext)
                manager.getRemainingTime()
            } catch (e: Exception) {
                0L
            }
            
            val message = if (remainingTime > 0) {
                val hours = remainingTime / (1000 * 60 * 60)
                val minutes = (remainingTime % (1000 * 60 * 60)) / (1000 * 60)
                val timeStr = when {
                    hours > 0 -> "${hours}h ${minutes}m"
                    minutes > 0 -> "${minutes}m"
                    else -> "few seconds"
                }
                "🔒 Commitment Mode Active ($timeStr remaining)\nCannot modify app settings!"
            } else {
                "⚠️ Cannot modify app: Active commitments in place!"
            }
            
            android.widget.Toast.makeText(
                applicationContext,
                message,
                android.widget.Toast.LENGTH_LONG
            ).show()
        }
    } catch (e: Exception) {
        android.util.Log.e("AccessibilityService", "Error showing warning", e)
    }
}
    
    
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        // Service continues running even if app is swiped from recents
        // This ensures protection persists when commitment mode is active
        android.util.Log.d("AccessibilityService", "📱 App removed from recents, service continues")
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        handler.removeCallbacks(refreshRunnable) // Stop periodic refresh
        isProcessing.set(false)
        instance = null
        
        // If commitment is active, log warning
        if (checkForAnyActiveCommitments()) {
            android.util.Log.w("AccessibilityService", "⚠️ Service destroyed while commitment active!")
        }
    }
}