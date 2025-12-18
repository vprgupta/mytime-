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
        
        // STRATEGY 4: Launcher context caching (prevent false negatives in long-press menus)
        @Volatile private var lastLauncherContext: String? = null
        @Volatile private var lastLauncherContextTime = 0L
        private const val LAUNCHER_CONTEXT_MEMORY_MS = 3000L  // Remember launcher context for 3 seconds
        
        // STRATEGY 5: App Info & Battery page context caching (instant blocking on background resume)
        @Volatile private var lastAppInfoContext: String? = null
        @Volatile private var lastAppInfoContextTime = 0L
        @Volatile private var lastBatteryContext: String? = null
        @Volatile private var lastBatteryContextTime = 0L
        private const val APP_INFO_CONTEXT_MEMORY_MS = 10000L  // Increase to 10s for more reliable background resume
        
        // UI Feedback Debounce
        @Volatile private var lastNotificationTime = 0L
        private const val NOTIFICATION_DEBOUNCE_MS = 2000L  // Show overlay/toast max once every 2s
        
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
            // Persist immediately
            instance?.saveLaunchLimits()
        }
        
        @JvmStatic
        fun removeLaunchLimit(packageName: String) {
            launchLimits.remove(packageName)
            launchCounts.remove(packageName)
            instance?.clearLaunchCount(packageName) // Ensure this method exists or remove if not needed
            
            // Remove from blocked list if it was blocked due to launch limit
            MainActivity.blockedPackages.remove(packageName)
            
            // Persist immediately
            instance?.saveLaunchLimits()
            android.util.Log.d("AccessibilityService", "🗑️ Removed launch limit for $packageName and unblocked if necessary")
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

        // --- NEW: Precision Filtering ---
        private val WHITELIST_PACKAGES = setOf(
            "com.google.android.gm",              // Gmail
            "com.google.android.apps.maps",        // Maps
            "com.google.android.apps.photos",      // Photos
            "com.google.android.apps.messaging",   // Google Messages
            "com.android.chrome",                  // Chrome
            "com.google.android.youtube",          // YouTube
            "com.google.android.calendar",         // Calendar
            "com.google.android.keep",             // Keep
            "com.google.android.apps.docs",        // Drive
            "com.whatsapp",                        // WhatsApp
            "com.slack",                           // Slack
            "com.microsoft.teams",                 // Teams
            "com.microsoft.office.outlook"         // Outlook
        )
        
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

        @JvmStatic
        fun isSettingsPackage(packageName: String?): Boolean {
            if (packageName == null) return false
            
            // CORE SYSTEM SECURITY PACKAGES
            if (packageName == "com.android.settings") return true
            if (packageName == "com.google.android.packageinstaller") return true
            if (packageName.contains("packageinstaller")) return true
            if (packageName == "com.android.systemui") return true
            
            // LAUNCHER / HOME SCREEN DETECTION (Critical for home screen uninstall blocking)
            if (packageName.contains("launcher") || 
                packageName.contains("home") || 
                packageName.contains("trebuchet") || 
                packageName.contains("nexuslauncher") || 
                packageName.contains("pixel") ||
                packageName.contains("touchwiz") ||
                packageName.contains("miui.home") ||
                packageName.contains("sec.android.app.launcher")) return true

            // MANUFACTURER SETTINGS
            if (packageName.contains("battery") || packageName.contains("power")) return true
            if (packageName.contains("devicecare") || packageName.contains("powerkeeper") || 
                packageName.contains("devicehealth") || packageName.contains("securitycenter") || 
                packageName.contains("safecenter") || packageName.contains("coloros") || 
                packageName.contains("oplus") || packageName.contains("miui") || 
                packageName.contains("samsung")) return true
            
            // Check for other manufacturer components
            val indicators = listOf(
                "permission", "vending", "batteryoptimize", "powermonitor",
                "oneplus", "vivo", "iqoo", "realme", "huawei", "honor", "motorola"
            )
            if (indicators.any { packageName.contains(it) }) return true
            
            // Handle google.android subpackages (except whitelisted ones)
            if (packageName.startsWith("com.google.android.") && !WHITELIST_PACKAGES.contains(packageName)) {
                return packageName.contains("settings") || packageName.contains("installer")
            }
            
            return false
        }
    }
    
    private fun saveLaunchLimits() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", android.content.Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            // Clear old values first to handle removals
            editor.clear()
            
            launchLimits.forEach { (pkg, limit) ->
                editor.putInt(pkg, limit)
            }
            editor.apply()
            android.util.Log.d("AccessibilityService", "💾 Saved ${launchLimits.size} launch limits")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save launch limits: ${e.message}")
        }
    }

    private fun restoreLaunchLimits() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchLimits", android.content.Context.MODE_PRIVATE)
            launchLimits.clear()
            
            prefs.all.forEach { (pkg, value) ->
                if (value is Int) {
                    launchLimits[pkg] = value
                }
            }
            android.util.Log.d("AccessibilityService", "♻️ Restored ${launchLimits.size} launch limits from persistence")
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore launch limits: ${e.message}")
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

        // 4. CRITICAL: Click Detection (Prioritized)
        // Process clicks BEFORE any other checks to ensure we catch "Uninstall" buttons immediately
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED || 
            event.eventType == AccessibilityEvent.TYPE_VIEW_LONG_CLICKED) {
            
            val clickedText = event.text?.toString()?.lowercase() ?: ""
            val clickedDesc = event.contentDescription?.toString()?.lowercase() ?: ""
            val clickedId = try { event.source?.viewIdResourceName ?: "" } catch (e: Exception) { "" }
            
            android.util.Log.d("AccessibilityService", "🖱️ CLICK: id=$clickedId, text=$clickedText, desc=$clickedDesc, pkg=${event.packageName}")
            
            // A. PROACTIVE CACHING: Catch clicks/long-clicks on "MyTime" in ANY app (especially Launchers)
            val combinedText = "$clickedText $clickedDesc".lowercase()
            // Relaxed check: 'contains' instead of 'equals' to catch list items like "MyTime 23MB" or "MyTime Installed"
            if (combinedText.contains("mytime") || combinedText.contains("my time")) {
                val now = System.currentTimeMillis()
                lastAppInfoContext = "mytime"
                lastAppInfoContextTime = now
                lastBatteryContext = "mytime"
                lastBatteryContextTime = now
                android.util.Log.d("AccessibilityService", "🖱️ PRE-EMPTIVE CACHE: User interacted with MyTime icon/item!")
            }
            
            // B. DANGEROUS CLICK DETECTION (Settings/Installer/Launcher)
            // We use the expanded isSettingsPackage() which now includes Launchers
            val isSecPackage = isSettingsPackage(packageName)
            if (isSecPackage) {
                // Check if we're in a MyTime context (Cached or current node)
                val rootNode = rootInActiveWindow
                val windowText = try { if (rootNode != null) getWindowText(rootNode).lowercase() else "" } catch (e: Exception) { "" }
                val isMyTimeContext = windowText.contains("mytime") || windowText.contains("my time") || 
                                     (lastAppInfoContext == "mytime" && System.currentTimeMillis() - lastAppInfoContextTime < 5000)
                
                if (isMyTimeContext) {
                    val combinedClickText = "$clickedText $clickedDesc $clickedId".lowercase()
                    val isDangerousClick = combinedClickText.contains("uninstall") || 
                                          combinedClickText.contains("disable") ||
                                          combinedClickText.contains("force") ||
                                          combinedClickText.contains("stop") ||
                                          combinedClickText.contains("clear") ||
                                          combinedClickText.contains("delete") ||
                                          combinedClickText.contains("remove")
                    
                    if (isDangerousClick) {
                        // Double check surgical precision before blocking a click
                        val isExplicitMyTime = windowText.contains("com.example.mytime") || 
                                              (windowText.contains("mytime") && !windowText.contains("search"))
                        
                        if (isExplicitMyTime && !windowText.contains("instagram") && !windowText.contains("facebook")) {
                            android.util.Log.e("AccessibilityService", "🚨 BLOCKED DANGEROUS CLICK (@Launcher/Settings): $combinedClickText")
                            showCommitmentWarning()
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                }
            }
            
            // Always process clicks immediately
            processEvent(event)
            return
        }
        
        // 0A. PROACTIVE SETTINGS CACHING - Cache MyTime context BEFORE app info/battery detection
        // This ensures instant blocking from any entry point (like launcher caching for accessibility)
        val isSettings = isSettingsPackage(packageName)
        if ((event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) &&
            isSettings) {
            
            val hasCommitment = checkCommitmentCached()
            if (hasCommitment) {
                try {
                    val rootNode = rootInActiveWindow
                    if (rootNode != null) {
                        val windowText = getWindowText(rootNode).lowercase()
                        val now = System.currentTimeMillis()
                        
                        // SURGICAL: Only cache if MyTime is the PRIMARY focus (Detail Page)
                        // Indicators: package name OR (mytime label AND detail keywords)
                        val isMyTimeVisible = windowText.contains("com.example.mytime") || 
                                             ((windowText.contains("mytime") || windowText.contains("my time")) && 
                                              (windowText.contains("force stop") || windowText.contains("uninstall") || 
                                               windowText.contains("mah") || windowText.contains("foreground")))
                        
                        if (isMyTimeVisible) {
                            // Determine if it's Battery or App Info
                            if (windowText.contains("mah") || windowText.contains("usage") || windowText.contains("battery")) {
                                lastBatteryContext = "mytime"
                                lastBatteryContextTime = now
                            } else {
                                lastAppInfoContext = "mytime"
                                lastAppInfoContextTime = now
                            }
                            android.util.Log.d("AccessibilityService", "📌 PROACTIVE (SURGICAL): Cached MyTime Detail Page")
                        } else {
                            // Clear old cache if MyTime not visible or it's just a list
                            if (now - lastAppInfoContextTime > APP_INFO_CONTEXT_MEMORY_MS) {
                                lastAppInfoContext = null
                            }
                            if (now - lastBatteryContextTime > APP_INFO_CONTEXT_MEMORY_MS) {
                                lastBatteryContext = null
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Ignore errors in proactive caching
                }
            }
        }
        
        // 0B. ULTRA-EARLY APP INFO & BATTERY BLOCKING - Uses the proactive cache set above
        if ((event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
             event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) &&
            isSettings) {
            
            // STRATEGY 1: Use cached commitment check (saves 5-10ms)
            val hasCommitment = checkCommitmentCached()  // ~0.1ms instead of ~10ms
            
            if (hasCommitment) {
                val now = System.currentTimeMillis()
                
                // CRITICAL FIX: If in Commitment Mode and in Settings/SystemUI, 
                // ALWAYS perform a quick scan if class heuristics fail or if resuming from background.
                // This removes dependency on activity class names which can be fuzzy.
                try {
                    val rootNode = rootInActiveWindow
                    val now = System.currentTimeMillis()
                    
                    // 1. FAST CACHE CHECK
                    val isMyTimeAppInfo = (lastAppInfoContext == "mytime" && now - lastAppInfoContextTime < APP_INFO_CONTEXT_MEMORY_MS)
                    val isMyTimeBattery = (lastBatteryContext == "mytime" && now - lastBatteryContextTime < APP_INFO_CONTEXT_MEMORY_MS)
                    
                    if (isMyTimeAppInfo || isMyTimeBattery) {
                         // SURGICAL: Verify it's still a detail page before using cache
                         val windowTextRaw = try { if (rootNode != null) getWindowText(rootNode).lowercase() else "" } catch (e: Exception) { "" }
                         val eventTextRaw = event.text?.toString()?.lowercase() ?: ""
                         val combinedTextRaw = "$windowTextRaw $eventTextRaw"
                         
                         // Must have explicit package name OR (MyTime app name AND a detail indicator)
                         val hasExplicitPackage = combinedTextRaw.contains("com.example.mytime")
                         val hasAppName = combinedTextRaw.contains("mytime") || combinedTextRaw.contains("my time")
                         
                         // Structural List Detection
                         val otherAppsCount = listOf("instagram", "facebook", "whatsapp", "chrome", "youtube", "gmail", "system", "android", "google", "settings").count { windowTextRaw.contains(it) }
                         val listHeadersStr = listOf("search apps", "app management", "all apps", "manage apps", "app list")
                         val hasListHeader = listHeadersStr.any { windowTextRaw.contains(it) }
                         val hasSearchBar = windowTextRaw.contains("search") || windowTextRaw.contains("query")
                         val isListScreen = (otherAppsCount >= 2 || hasListHeader || hasSearchBar)
                         
                         // Detail Indicators
                         val hasStrongIndicator = windowTextRaw.contains("force stop") || windowTextRaw.contains("uninstall") || windowTextRaw.contains("disable") || windowTextRaw.contains("accessibility")
                         val detailCountInt = listOf("storage & cache", "mobile data", "battery", "permissions", "notifications").count { windowTextRaw.contains(it) }
                         val isActualDetailPage = hasStrongIndicator || detailCountInt >= 2
                         
                         // BLOCK ONLY IF: It's MyTime AND definitively a detail page/dialog AND NOT a list
                         // Added "uninstall" confirmation dialog support
                         val isUninstallDialog = hasAppName && (windowTextRaw.contains("uninstall") || windowTextRaw.contains("ok") || windowTextRaw.contains("delete"))
                         val shouldBlock = ((hasExplicitPackage || hasAppName) && isActualDetailPage && !isListScreen) || isUninstallDialog
                         
                         if (shouldBlock) {
                             android.util.Log.e("AccessibilityService", "⚡ ULTRA-FAST CACHED BLOCK: MyTime Context (${if(isUninstallDialog) "Dialog" else "Detail"})!")
                             showCommitmentWarning()
                             triggerGlobalActionHome(immediate = true)
                             return
                         }
                    }
                    
                    // 2. IMMEDIATE SCAN
                    val eventText = event.text?.toString()?.lowercase() ?: ""
                    val eventDesc = event.contentDescription?.toString()?.lowercase() ?: ""
                    val combinedEventText = "$eventText $eventDesc"
                    
                    // Surgical detection: requires package name or specific detail indicators
                    val isExplicitPackage = combinedEventText.contains("com.example.mytime")
                    val isMyTimeDetail = (combinedEventText.contains("mytime") || combinedEventText.contains("my time")) && 
                                        (combinedEventText.contains("mah") || combinedEventText.contains("foreground") || 
                                         combinedEventText.contains("usage") || combinedEventText.contains("battery"))
                    
                    var isMyTimeDetected = isExplicitPackage || isMyTimeDetail
                    
                    if (!isMyTimeDetected && rootNode != null) {
                        isMyTimeDetected = findMyTimePackageNameFast(rootNode)
                        if (!isMyTimeDetected) {
                            val windowText = try { getWindowText(rootNode).lowercase() } catch (e: Exception) { "" }
                            val hasMyTime = windowText.contains("mytime") || windowText.contains("my time")
                            val isBatteryDetail = windowText.contains("mah") && windowText.contains("foreground")
                            isMyTimeDetected = (hasMyTime && isBatteryDetail) || (isExplicitPackage)
                        }
                    }
                    
                    if (isMyTimeDetected) {
                         // SURGICAL: Final verification that it's NOT a list before blocking
                         val rootNodeVer = rootInActiveWindow
                         val windowText = try { if (rootNodeVer != null) getWindowText(rootNodeVer).lowercase() else "" } catch (e: Exception) { "" }
                         val otherApps = listOf("instagram", "facebook", "whatsapp", "chrome", "youtube", "gmail", "system", "android", "google", "settings")
                         val otherAppCount = otherApps.count { windowText.contains(it) }
                         
                         val isExplicitDetail = windowText.contains("com.example.mytime") && 
                                               (windowText.contains("force stop") || windowText.contains("uninstall") || 
                                                windowText.contains("storage") || windowText.contains("data") || windowText.contains("accessibility"))
                         
                         val listHeaders = listOf("search apps", "app management", "all apps", "manage apps", "app list")
                         val hasListHeader = listHeaders.any { windowText.contains(it) }
                         val hasSearchBar = windowText.contains("search") || windowText.contains("query")
                         val isList = otherAppCount >= 2 || hasListHeader || hasSearchBar
                         
                         if ((!isList && isMyTimeDetected) || isExplicitDetail) {
                             // Update cache for future instant blocks
                             if (combinedEventText.contains("mah") || combinedEventText.contains("battery") || combinedEventText.contains("power")) {
                                 lastBatteryContext = "mytime"
                                 lastBatteryContextTime = now
                             } else {
                                 lastAppInfoContext = "mytime"
                                 lastAppInfoContextTime = now
                             }
                             
                             android.util.Log.e("AccessibilityService", "⚡ ULTRA-FAST INSTANT BLOCK: MyTime Settings/Battery! (Confirmed Surgical)")
                             showCommitmentWarning()
                             triggerGlobalActionHome(immediate = true)
                             return
                         }
                    }
                } catch (e: Exception) {
                    android.util.Log.e("AccessibilityService", "Error in ultra-early protection: ${e.message}")
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
        
        // 4. CRITICAL: Click Detection (Prioritized)
        // We process clicks BEFORE the general debounce or settings checks
        if (event.eventType == AccessibilityEvent.TYPE_VIEW_CLICKED || 
            event.eventType == AccessibilityEvent.TYPE_VIEW_LONG_CLICKED) {
            
            val clickedText = event.text?.toString()?.lowercase() ?: ""
            val clickedDesc = event.contentDescription?.toString()?.lowercase() ?: ""
            val clickedId = try { event.source?.viewIdResourceName ?: "" } catch (e: Exception) { "" }
            
            android.util.Log.d("AccessibilityService", "🖱️ CLICK: id=$clickedId, text=$clickedText, desc=$clickedDesc, pkg=${event.packageName}")
            
            // A. PROACTIVE CACHING: Catch clicks/long-clicks on "MyTime" in ANY app (especially Launchers)
            // If user interacts with MyTime icon, we pre-cache it as the target.
            val combinedText = "$clickedText $clickedDesc".lowercase()
            if (combinedText == "mytime" || combinedText == "my time" || combinedText.contains("com.example.mytime")) {
                val now = System.currentTimeMillis()
                lastAppInfoContext = "mytime"
                lastAppInfoContextTime = now
                lastBatteryContext = "mytime"
                lastBatteryContextTime = now
                android.util.Log.d("AccessibilityService", "🖱️ PRE-EMPTIVE CACHE: User interacted with MyTime icon!")
            }
            
            // B. DANGEROUS CLICK DETECTION (Settings/Installer/Launcher)
            if (isSettings) {
                // Check if we're in a MyTime context (Cached or current node)
                val rootNode = rootInActiveWindow
                val windowText = try { if (rootNode != null) getWindowText(rootNode).lowercase() else "" } catch (e: Exception) { "" }
                val isMyTimeContext = windowText.contains("mytime") || windowText.contains("my time") || 
                                     (lastAppInfoContext == "mytime" && System.currentTimeMillis() - lastAppInfoContextTime < 5000)
                
                if (isMyTimeContext) {
                    val combinedClickText = "$clickedText $clickedDesc $clickedId".lowercase()
                    val isDangerousClick = combinedClickText.contains("uninstall") || 
                                          combinedClickText.contains("disable") ||
                                          combinedClickText.contains("force") ||
                                          combinedClickText.contains("stop") ||
                                          combinedClickText.contains("clear") ||
                                          combinedClickText.contains("delete") ||
                                          combinedClickText.contains("remove")
                    
                    if (isDangerousClick) {
                        // Double check surgical precision before blocking a click
                        val isExplicitMyTime = windowText.contains("com.example.mytime") || 
                                              (windowText.contains("mytime") && !windowText.contains("search"))
                        
                        if (isExplicitMyTime && !windowText.contains("instagram") && !windowText.contains("facebook")) {
                            android.util.Log.e("AccessibilityService", "🚨 BLOCKED DANGEROUS CLICK (@Launcher/Settings): $combinedClickText")
                            showCommitmentWarning()
                            triggerGlobalActionHome(true)
                            return
                        }
                    }
                }
            }
            
            // Always process clicks immediately
            processEvent(event)
            return
        }
        
        // 5. CRITICAL SECURITY: Process Settings/Installer events immediately (No Debounce)
        if (isSettings) {
             // LOWER THROTTLE for high-frequency settings updates during commitment
             val now = System.currentTimeMillis()
             if (now - lastContentChangeCheck >= 50) { // 50ms instead of 200ms
                 lastContentChangeCheck = now
                 processEvent(event)
             }
             return
        }
        
        // 6. DEBOUNCED PROCESSING: For non-critical app usage tracking
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED) {
            
            if (isProcessing.compareAndSet(false, true)) {
                processEvent(event)
                handler.postDelayed({ isProcessing.set(false) }, 100)
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
                        triggerGlobalActionHome(false) // Relaxed block (not immediate)
                        return
                    }
                    lastLaunchedApp = packageName
                    lastLaunchTime = now
                }
            }
            
            // 1. Check if this is a blocked app (Manual Block)
            if (MainActivity.blockedPackages.contains(packageName)) {
                android.util.Log.d("AccessibilityService", "🚫 Blocking detected app: $packageName")
                triggerGlobalActionHome(false) // Relaxed block (not immediate)
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
                    triggerGlobalActionHome(false)
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
                            // CRITICAL: Check if we're in a MyTime-related screen BEFORE blocking
                            // This prevents blocking legitimate delete/remove actions in other apps (e.g., Gmail)
                            val rootNode = rootInActiveWindow
                            if (rootNode != null) {
                                val windowText = getWindowText(rootNode).lowercase()
                                val isMyTimeContext = windowText.contains("mytime") ||
                                                     windowText.contains("my time") ||
                                                     windowText.contains("com.example.mytime")
                                
                                if (isMyTimeContext) {
                                    android.util.Log.d("AccessibilityService", "🛡️ BLOCKED: Uninstall/Deactivate button click for MyTime!")
                                    showCommitmentWarning()
                                    triggerGlobalActionHome(true)
                                    return
                                } else {
                                    android.util.Log.d("AccessibilityService", "✅ Allowing uninstall/delete click - not MyTime context")
                                }
                            }
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
                    
                    // CRITICAL: Cache launcher context when on launcher
                    // This prevents false negatives when long-press menus don't show app name
                    if (isLauncher) {
                        val now = System.currentTimeMillis()
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            val windowText = getWindowText(rootNode).lowercase()
                            
                            // Check if MyTime is visible in launcher
                            if (windowText.contains("mytime") || 
                                windowText.contains("my time") || 
                                windowText.contains("com.example.mytime")) {
                                // Cache this context
                                lastLauncherContext = "mytime"
                                lastLauncherContextTime = now
                                android.util.Log.d("AccessibilityService", "📌 Cached MyTime launcher context")
                            } else {
                                // Clear cache if MyTime not visible and cache is old
                                if (now - lastLauncherContextTime > LAUNCHER_CONTEXT_MEMORY_MS) {
                                    lastLauncherContext = null
                                }
                            }
                        }
                    }
                    
                    if (isUninstallPackage || isLauncher) {
                        // Scan window for MyTime app name or package AND uninstall-related text
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            val windowText = getWindowText(rootNode).lowercase()
                            android.util.Log.d("AccessibilityService", "🔍 Window text: ${windowText.take(200)}")
                            
                            // CRITICAL FIX: If window text indicates we're in ANOTHER app's UI (not launcher),
                            // skip this check entirely to prevent false positives
                            val otherAppIndicators = listOf(
                                "inbox", "gmail", "email", "compose", "draft", "trash", "sent", // Gmail/Email
                                "whatsapp", "telegram", "message", "chat", "contact",           // Messaging
                                "chrome", "browser", "tab", "bookmark", "history",              // Browser
                                "youtube", "video", "play", "playlist", "library",              // Media
                                "camera", "photo", "gallery", "album",                          // Camera/Photos
                                "navigation", "maps", "directions", "location",                 // Navigation
                                "calendar", "event", "schedule", "meeting",                     // Productivity
                                "drive", "file", "document", "sheet", "slide"                   // Cloud/Office
                            )
                            
                            val isOtherAppContent = otherAppIndicators.any { windowText.contains(it) }
                            
                            if (isOtherAppContent) {
                                android.util.Log.d("AccessibilityService", "✅ Allowed: Other app content detected (not launcher)")
                                return@processEvent  // Skip MyTime detection for this event
                            }
                            
                            // Check for MyTime in current window first
                            var isMyTimeUninstall = windowText.contains("mytime") ||
                                                   windowText.contains("my time") ||
                                                   windowText.contains("com.example.mytime")
                            
                            // CRITICAL: Use cached launcher context ONLY if:
                            // 1. We're in launcher package
                            // 2. Current window looks like launcher (has app icons, not other app content)
                            // 3. Cache is recent
                            if (isLauncher && !isMyTimeUninstall) {
                                val now = System.currentTimeMillis()
                                
                                // Verify this is actually launcher UI, not another app showing in launcher
                                // Launcher UI typically contains app names, drawer, search bar
                                val looksLikeLauncher = windowText.contains("drawer") ||
                                                       windowText.contains("search") ||
                                                       windowText.contains("all categories") ||
                                                       windowText.contains("widget") ||
                                                       // Check for multiple app names (indicates app grid)
                                                       (windowText.split(" ").distinct().size > 10)
                                
                                if (looksLikeLauncher && 
                                    lastLauncherContext == "mytime" && 
                                    now - lastLauncherContextTime < LAUNCHER_CONTEXT_MEMORY_MS) {
                                    isMyTimeUninstall = true
                                    android.util.Log.d("AccessibilityService", "🔄 Using cached launcher context for MyTime detection")
                                }
                            }
                            
                            // Check for uninstall/dangerous text - be STRICT in launcher context
                            val hasUninstallText = if (isLauncher) {
                                // In launcher: Only check EXPLICIT uninstall keywords
                                // Don't check "settings", "disable", etc. as these appear in normal apps
                                windowText.contains("uninstall") ||
                                windowText.contains("remove") ||
                                windowText.contains("delete")
                            } else {
                                // In Settings/Package Installer: Check all dangerous keywords
                                windowText.contains("uninstall") ||
                                windowText.contains("remove") ||
                                windowText.contains("delete") ||
                                windowText.contains("disable") ||
                                windowText.contains("turn off") ||
                                windowText.contains("keep on")
                            }
                            
                            android.util.Log.d("AccessibilityService", "🎯 Is MyTime: $isMyTimeUninstall, Has uninstall text: $hasUninstallText")
                            
                            // EXPANDED: Block if MyTime is detected AND we see disable/uninstall-related text
                            // OR if Commitment Mode is active and we're in Settings (more aggressive)
                            if (isMyTimeUninstall) {
                                val shouldBlock = hasUninstallText || (hasAnyCommitment && !isLauncher)
                                
                                if (shouldBlock) {
                                    android.util.Log.d("AccessibilityService", "🛡️ BLOCKED: MyTime settings/uninstall screen detected! (HasUninstallText: $hasUninstallText, Commitment: $hasAnyCommitment)")
                                    showCommitmentWarning()
                                    triggerGlobalActionHome(true)
                                    return
                                }
                            }
                        } else {
                            android.util.Log.d("AccessibilityService", "⚠️ Root node is null")
                        }
                    }
                } else {
                    android.util.Log.d("AccessibilityService", "❌ No commitment active")
                }
                
                // PROACTIVE CACHING: Detect MyTime in Settings context (lists, search results, etc.)
                // This caches BEFORE user accesses app info or battery pages
                // Same strategy as launcher caching for accessibility blocking
                if (packageName.contains("settings")) {
                    val now = System.currentTimeMillis()
                    val rootNode = rootInActiveWindow
                    if (rootNode != null) {
                        val windowText = getWindowText(rootNode).lowercase()
                        
                        // SURGICAL: Only cache if MyTime is the PRIMARY focus (Detail Page)
                        val isMyTimeVisible = windowText.contains("com.example.mytime") || 
                                             ((windowText.contains("mytime") || windowText.contains("my time")) && 
                                              (windowText.contains("force stop") || windowText.contains("uninstall") || 
                                               windowText.contains("mah") || windowText.contains("foreground")))
                        
                        if (isMyTimeVisible) {
                            if (windowText.contains("mah") || windowText.contains("usage") || windowText.contains("battery")) {
                                lastBatteryContext = "mytime"
                                lastBatteryContextTime = now
                            } else {
                                lastAppInfoContext = "mytime"
                                lastAppInfoContextTime = now
                            }
                            android.util.Log.d("AccessibilityService", "📌 Cached MyTime Detail Page (from processEvent)")
                        } else {
                            // Clear cache if MyTime not visible and cache is old
                            if (now - lastAppInfoContextTime > APP_INFO_CONTEXT_MEMORY_MS) {
                                lastAppInfoContext = null
                            }
                            if (now - lastBatteryContextTime > APP_INFO_CONTEXT_MEMORY_MS) {
                                lastBatteryContext = null
                            }
                        }
                    }
                }
                
                
                val text = event.text?.toString()?.lowercase() ?: ""
                val contentDescription = event.contentDescription?.toString()?.lowercase() ?: ""
                val combinedText = "$text $contentDescription"
                
                // SURGICAL BLOCKING: Only block MyTime-specific actions
                // Allow everything else (other apps, general settings, etc.)
                
                // Expanded to cover ALL major Android manufacturers
                // Consolidated settings check
                val isSettings = isSettingsPackage(packageName)
                
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
                    
                    // STEP 1: Check if this screen is related to MyTime (Surgical)
                    // Must be the explicit package name OR specific mytime text WITHOUT list context
                    val rootNode = rootInActiveWindow
                    val windowTextSearch = try { if (rootNode != null) getWindowText(rootNode).lowercase() else "" } catch (e: Exception) { "" }
                    val commonAppCount = listOf("instagram", "facebook", "whatsapp", "chrome", "youtube", "gmail", "system", "android", "google", "settings").count { windowTextSearch.contains(it) }
                    
                    // WHITELIST: Explicitly allow "App management", "All apps", and "Search" screens
                    val listHeaders = listOf("search apps", "app management", "all apps", "app info", "manage apps", "app list", "app info search", "search result")
                    val hasSearchBar = windowTextSearch.contains("search") || windowTextSearch.contains("query") || windowTextSearch.contains("type to search")
                    val isAppListHeader = (listHeaders.any { windowTextSearch.contains(it) } || hasSearchBar) && (commonAppCount >= 2 || hasSearchBar)
                    
                    var isMyTimeScreen = (combinedText.contains("com.example.mytime") || 
                                         (windowTextSearch.contains("com.example.mytime"))) && !isAppListHeader
                    
                    // Strict MyTime text matching: only if it's NOT a list and NOT a search result
                    if (!isMyTimeScreen && !isAppListHeader) {
                        // In search results, MyTime might be the ONLY result. 
                        // So we MUST check for detail indicators even for "isMyTimeScreen"
                        val hasDetailIndicators = listOf("force stop", "uninstall", "storage & cache", "mobile data", "battery", "permissions").any { windowTextSearch.contains(it) }
                        
                        isMyTimeScreen = ((combinedText.contains("mytime") || combinedText.contains("my time")) && 
                                         !isAppListHeader && !hasSearchBar && hasDetailIndicators)
                    }
                    
                    // If not found in text, scan the window content
                    if (!isMyTimeScreen) {
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            isMyTimeScreen = isScreenRelatedToApp(rootNode)
                            
                            // Additional check: scan for package name in window
                            if (!isMyTimeScreen) {
                                val windowText = getWindowText(rootNode).lowercase()
                                isMyTimeScreen = windowText.contains("com.example.mytime") ||
                                                ((windowText.contains("mytime") || windowText.contains("my time")) && 
                                                 !windowText.contains("search") && !windowText.contains("result") && !windowText.contains("inbox"))
                                
                                if (isMyTimeScreen) {
                                    android.util.Log.d("AccessibilityService", "🔍 Found MyTime via package name scan")
                                }
                            }
                        }
                    }
                    
                    
                    // STEP 2: COMPLETE BLOCKING - Block entire MyTime settings screen during commitment
                    // This prevents force stop, clear data, uninstall, and all other dangerous actions
                    if (isMyTimeScreen && (packageName.contains("settings") || packageName.contains("systemui"))) {
                        
                        // SURGICAL: Must have detail indicators AND NOT be a list of other apps
                        // Look for specific App Info section headers/buttons
                        val detailIndicators = listOf("force stop", "force close", "uninstall", "disable", "storage & cache", "mobile data", "screen time", "battery", "open by default", "app details")
                        val indicatorCount = detailIndicators.count { combinedText.contains(it) }
                        
                        // To be an App Info page, we need at least one strong indicator (Force Stop/Uninstall) 
                        // OR multiple section indicators (Storage, Data, etc.)
                        val hasStrongIndicator = combinedText.contains("force stop") || combinedText.contains("uninstall") || combinedText.contains("disable")
                        val isAppInfoPage = (hasStrongIndicator || indicatorCount >= 2) && commonAppCount < 2
                        
                        if (isAppInfoPage) {
                            android.util.Log.e("AccessibilityService", "🚨 INSTANT BLOCK (SURGICAL): MyTime App Info screen detected!")
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
                    
                    // INSTANT BATTERY BLOCKING: MyTime-specific detection only
                    // Battery apps might be in different packages (com.oplus.battery, etc.)
                    if (isMyTimeScreen) {
                        val now = System.currentTimeMillis()
                        
                        // PRIORITY 1: Check cached context FIRST if in battery context
                        // But VERIFY it's MyTime's page, not another app's battery page
                        if (lastBatteryContext == "mytime") {
                            if (now - lastBatteryContextTime < APP_INFO_CONTEXT_MEMORY_MS) {
                                val isBatteryContext = packageName.contains("battery") ||
                                                      packageName.contains("power") ||
                                                      packageName.contains("devicecare") ||
                                                      packageName.contains("powerkeeper") ||
                                                      packageName.contains("powermonitor") ||
                                                      packageName.contains("settings")
                                
                                if (isBatteryContext) {
                                    // CRITICAL: Verify MyTime is still visible before blocking
                                    // This prevents blocking other apps' battery pages
                                    val rootNode = rootInActiveWindow
                                    if (rootNode != null) {
                                        val quickCheck = getWindowText(rootNode).lowercase()
                                        val isActuallyMyTime = quickCheck.contains("mytime") ||
                                                              quickCheck.contains("my time") ||
                                                              quickCheck.contains("com.example.mytime")
                                        
                                        if (isActuallyMyTime) {
                                            android.util.Log.d("AccessibilityService", "🔋 CACHED BLOCK: MyTime Battery!")
                                            showCommitmentWarning()
                                            triggerGlobalActionHome(true)
                                            return
                                        }
                                    }
                                }
                            }
                        }
                        
                        // PRIORITY 2: Direct detection for battery-specific packages
                        val isBatteryPackage = packageName.contains("battery") ||
                                              packageName.contains("power") ||
                                              packageName.contains("devicecare") ||
                                              packageName.contains("powerkeeper") ||
                                              packageName.contains("powermonitor")
                        
                        if (isBatteryPackage) {
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
                            
                            // ALSO check for package name visibility
                            val hasPackageName = combinedText.contains("com.example.mytime") ||
                                                windowText.contains("com.example.mytime")
                            
                            // Update cache and block if detected
                            // AGGRESSIVE: During commitment, block ANY MyTime-related detail page even if heuristics are fuzzy
                            val looksLikeMyTimeDetails = isDetailPage || hasPackageName || 
                                                       (hasAnyCommitment && windowText.contains("mah") && windowText.contains("foreground"))
                            
                            if (looksLikeMyTimeDetails) {
                                lastBatteryContext = "mytime"
                                lastBatteryContextTime = now
                                android.util.Log.d("AccessibilityService", "🔋 INSTANT BLOCK: MyTime Battery (detail page detected)")
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

    // --- Launch Count Persistence Helpers ---

    private fun saveLaunchCount(packageName: String, count: Int) {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchCounts", android.content.Context.MODE_PRIVATE)
            prefs.edit().putInt(packageName, count).apply()
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save launch count: ${e.message}")
        }
    }
    
    private fun clearLaunchCount(packageName: String) {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchCounts", android.content.Context.MODE_PRIVATE)
            prefs.edit().remove(packageName).apply()
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to clear launch count: ${e.message}")
        }
    }
    
    private fun saveCurrentDate() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchCounts", android.content.Context.MODE_PRIVATE)
            prefs.edit().putString("currentDate", currentDate).apply()
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to save date: ${e.message}")
        }
    }
    
    private fun restoreLaunchCounts() {
        try {
            val prefs = applicationContext.getSharedPreferences("LaunchCounts", android.content.Context.MODE_PRIVATE)
            
            // 1. Check Date
            val savedDate = prefs.getString("currentDate", "")
            val today = getCurrentDate()
            
            if (savedDate != today) {
                android.util.Log.d("AccessibilityService", "🌅 Application restart on new day ($today vs $savedDate) - clearing old counts")
                prefs.edit().clear().putString("currentDate", today).apply()
                launchCounts.clear()
                currentDate = today
                return
            }
            
            // 2. Restore Counts
            currentDate = today // Ensure current date matches
            launchCounts.clear()
            prefs.all.forEach { (key, value) ->
                if (key != "currentDate" && value is Int) {
                    launchCounts[key] = value
                }
            }
            android.util.Log.d("AccessibilityService", "♻️ Restored ${launchCounts.size} launch counts")
            
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Failed to restore launch counts: ${e.message}")
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
    
    // THROTTLE: Use different throttles for security vs routine blocking
    val throttleMs = if (immediate) 100 else 500
    if (now - lastBlockTriggerTime < throttleMs) {
        return
    }
    
    // PACKAGE-SPECIFIC DEBOUNCE: Continue to use 1s for normal apps
    if (!immediate) {
        val currentPackage = try { rootInActiveWindow?.packageName?.toString() } catch (e: Exception) { null }
        if (currentPackage != null && currentPackage == lastBlockedPackage && now - lastBlockTriggerTime < 1000) {
            return
        }
        lastBlockedPackage = currentPackage
    }
    
    lastBlockTriggerTime = now
    
    // CRITICAL: Perform the home action IMMEDIATELY
    try {
        performGlobalAction(GLOBAL_ACTION_HOME)
        
        if (immediate) {
            handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 40)
            handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 100)
            handler.postDelayed({ performGlobalAction(GLOBAL_ACTION_HOME) }, 200)
        }
    } catch (e: Exception) {
        android.util.Log.e("AccessibilityService", "Failed to perform home action: ${e.message}")
    }
    
    // UI FEEDBACK: Debounced separately to prevent continuous notifications/vibrations
    if (now - lastNotificationTime >= NOTIFICATION_DEBOUNCE_MS) {
        lastNotificationTime = now
        handler.post { showBlockedOverlay() }
    }
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
        restoreLaunchLimits() // Restore launch limit CONFIGURATION
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
        
        // REGRESSION FIX: Only count as "related" if it's an explicit app label or package name
        // Avoid matching "mytime" inside sentences or search results
        val hasExplicitLabel = text == "mytime" || text == "my time" || text == "com.example.mytime" ||
                              desc == "mytime" || desc == "my time" || desc == "com.example.mytime"
        
        if (hasExplicitLabel) return true
        
        // Deep scan for package name (more reliable than app name)
        if (text.contains("com.example.mytime") || desc.contains("com.example.mytime")) {
            return true
        }
        
        // CHECK CHILDREN - with depth limit for performance
        return scanChildrenForLabel(node, 0)
    }

    private fun scanChildrenForLabel(node: AccessibilityNodeInfo, depth: Int): Boolean {
        if (depth > 15) return false
        
        val count = node.childCount
        for (i in 0 until count) {
            val child = node.getChild(i) ?: continue
            val text = child.text?.toString()?.lowercase() ?: ""
            val desc = child.contentDescription?.toString()?.lowercase() ?: ""
            
            if (text == "mytime" || text == "my time" || text == "com.example.mytime" ||
                desc == "mytime" || desc == "my time" || desc == "com.example.mytime") {
                return true
            }
            
            if (scanChildrenForLabel(child, depth + 1)) return true
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
        val now = System.currentTimeMillis()
        if (now - lastNotificationTime < NOTIFICATION_DEBOUNCE_MS) return
        lastNotificationTime = now

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
                    "🛡️ Commitment Mode Active\nUninstallation and settings are locked"
                }

                android.widget.Toast.makeText(
                    applicationContext,
                    message,
                    android.widget.Toast.LENGTH_LONG
                ).show()
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Error showing warning: ${e.message}")
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
