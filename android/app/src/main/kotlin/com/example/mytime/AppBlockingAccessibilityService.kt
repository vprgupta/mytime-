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
                                 // Samsung/OneUI
                                 packageName.contains("samsung") ||
                                 // Xiaomi/MIUI
                                 packageName.contains("miui") ||
                                 packageName.contains("securitycenter") ||
                                 // OnePlus/ColorOS/Oppo
                                 packageName.contains("coloros") ||
                                 packageName.contains("safecenter") ||
                                 packageName.contains("oneplus") ||
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
                    var isMyTimeScreen = combinedText.contains("mytime") || combinedText.contains("mytask") || 
                                         combinedText.contains("my time") || combinedText.contains("my task") ||
                                         combinedText.contains("com.example.mytime")
                    
                    // If not found in text, scan the window content
                    if (!isMyTimeScreen) {
                        val rootNode = rootInActiveWindow
                        if (rootNode != null) {
                            isMyTimeScreen = isScreenRelatedToApp(rootNode)
                        }
                    }
                    
                    // STEP 2: Only block if it's MyTime-related
                    if (isMyTimeScreen) {
                        android.util.Log.d("AccessibilityService", "🔍 MyTime screen detected: $combinedText")
                        
                        // Block 1: Accessibility Settings for MyTime
                        // Comprehensive detection across ALL manufacturers:
                        // Stock Android: "accessibility", "service", "turn off"
                        // Samsung: "deactivate", "stop using"
                        // Xiaomi: "stop", "revoke"
                        // OnePlus: "turn off", "disable"
                        // Vivo/Oppo: "close", "shut down"
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
                        
                        // Block 2: App Info / Uninstall for MyTime
                        // Manufacturer variations:
                        // Stock: "uninstall", "app info"
                        // Samsung: "remove", "delete app"
                        // Xiaomi: "delete", "remove app"
                        // All: "force stop", "clear data"
                        if (combinedText.contains("app info") || 
                            combinedText.contains("application info") ||
                            combinedText.contains("app details") ||      // Some OEMs
                            combinedText.contains("uninstall") ||
                            combinedText.contains("remove") ||           // Samsung
                            combinedText.contains("delete") ||           // Xiaomi
                            combinedText.contains("delete app") ||
                            combinedText.contains("remove app") ||
                            combinedText.contains("force stop") ||
                            combinedText.contains("force close") ||      // Older Android
                            combinedText.contains("clear data") ||
                            combinedText.contains("clear storage") ||
                            combinedText.contains("erase") ||            // Some OEMs
                            combinedText.contains("wipe data")) {        // Some OEMs
                            android.util.Log.d("AccessibilityService", "🛡️ Blocked: MyTime App Info/Uninstall")
                            triggerGlobalActionHome(true)
                            return
                        }
                        
                        // Block 3: Device Admin for MyTime
                        if (combinedText.contains("device admin") || 
                            combinedText.contains("device policy") ||
                            combinedText.contains("admin app") ||
                            combinedText.contains("deactivate") ||
                            combinedText.contains("activate")) {
                            android.util.Log.d("AccessibilityService", "🛡️ Blocked: MyTime Device Admin")
                            triggerGlobalActionHome(true)
                            return
                        }
                        
                        // Block 4: Package Installer for MyTime
                        if (packageName.contains("packageinstaller")) {
                            android.util.Log.d("AccessibilityService", "🛡️ Blocked: MyTime Uninstall Dialog")
                            triggerGlobalActionHome(true)
                            return
                        }
                        
                        // If MyTime screen but no dangerous action, allow it
                        android.util.Log.d("AccessibilityService", "✅ MyTime screen but safe action, allowing")
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
                android.widget.Toast.makeText(
                    applicationContext,
                    "⚠️ Cannot uninstall: Active commitments in place!",
                    android.widget.Toast.LENGTH_LONG
                ).show()
            }
        } catch (e: Exception) {
            android.util.Log.e("AccessibilityService", "Error showing warning", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        handler.removeCallbacksAndMessages(null)
        isProcessing.set(false)
        instance = null
    }
}