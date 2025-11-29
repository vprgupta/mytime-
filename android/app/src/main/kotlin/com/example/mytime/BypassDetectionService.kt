package com.example.mytime

import android.app.Service
import android.content.Intent
import android.content.IntentFilter
import android.content.BroadcastReceiver
import android.content.Context
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log

class BypassDetectionService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var isMonitoring = false
    private val bypassReceiver = BypassDetectionReceiver()
    private lateinit var advancedDetection: AdvancedBypassDetection
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onCreate() {
        super.onCreate()
        advancedDetection = AdvancedBypassDetection(this)
        registerBypassDetection()
        startBypassMonitoring()
        advancedDetection.startMonitoring()
    }
    
    private fun registerBypassDetection() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addAction(Intent.ACTION_AIRPLANE_MODE_CHANGED)
            addAction(Intent.ACTION_BOOT_COMPLETED)
            addAction(Intent.ACTION_REBOOT)
            addAction(Intent.ACTION_SHUTDOWN)
            addAction("android.intent.action.PACKAGE_NEEDS_VERIFICATION")
            addDataScheme("package")
        }
        registerReceiver(bypassReceiver, filter)
    }
    
    private fun startBypassMonitoring() {
        isMonitoring = true
        monitorBypassAttempts()
    }
    
    private fun monitorBypassAttempts() {
        handler.post(object : Runnable {
            override fun run() {
                if (isMonitoring) {
                    checkForBypassAttempts()
                    handler.postDelayed(this, 30000) // Check every 30 seconds
                }
            }
        })
    }
    
    private fun checkForBypassAttempts() {
        try {
            // Perform comprehensive security check
            val securityResult = advancedDetection.performSecurityCheck()
            
            // Only check bypass methods if blocking is active
            if (MainActivity.blockedPackages.isNotEmpty()) {
                if (isAirplaneModeOn()) {
                    handleBypassAttempt("Airplane mode enabled")
                }
                
                if (isDeveloperOptionsEnabled()) {
                    handleBypassAttempt("Developer options enabled")
                }
                
                if (isUsbDebuggingEnabled()) {
                    handleBypassAttempt("USB debugging enabled")
                }
                
                if (isSafeModeActive()) {
                    handleBypassAttempt("Safe mode active")
                }
            }
            
            // Only check advanced security threats if blocking is active
            if (MainActivity.blockedPackages.isNotEmpty()) {
                if (securityResult.isRooted) {
                    handleBypassAttempt("Root access detected")
                }
                
                if (securityResult.isEmulator) {
                    handleBypassAttempt("Emulator detected")
                }
                
                if (securityResult.hasHookFrameworks) {
                    handleBypassAttempt("Hook frameworks detected")
                }
                
                if (securityResult.hasBatteryOptimization) {
                    handleBypassAttempt("Battery optimization enabled")
                }
                
                if (!securityResult.hasNotificationPermission) {
                    handleBypassAttempt("Notification permission disabled")
                }
                
                if (securityResult.isGuestMode) {
                    handleBypassAttempt("Guest mode detected")
                }
                
                if (securityResult.isSecondaryUser) {
                    handleBypassAttempt("Secondary user account detected")
                }
            }
            
        } catch (e: Exception) {
            Log.e("BypassDetection", "Error checking bypass attempts: ${e.message}")
        }
    }
    
    private fun isAirplaneModeOn(): Boolean {
        return Settings.Global.getInt(contentResolver, Settings.Global.AIRPLANE_MODE_ON, 0) != 0
    }
    
    private fun isDeveloperOptionsEnabled(): Boolean {
        return Settings.Global.getInt(contentResolver, Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0
    }
    
    private fun isUsbDebuggingEnabled(): Boolean {
        return Settings.Global.getInt(contentResolver, Settings.Global.ADB_ENABLED, 0) != 0
    }
    
    private fun isSafeModeActive(): Boolean {
        return try {
            val pm = packageManager
            pm.isSafeMode()
        } catch (e: Exception) {
            false
        }
    }
    
    private fun handleBypassAttempt(method: String) {
        Log.w("BypassDetection", "Bypass attempt detected: $method")
        
        // Log the bypass attempt but don't open MyTask app
        // Just ensure monitoring continues
        
        // Restart monitoring if stopped
        if (!isMonitoring) {
            startBypassMonitoring()
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        isMonitoring = false
        advancedDetection.stopMonitoring()
        
        try {
            unregisterReceiver(bypassReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
        
        // Restart service if destroyed during blocking
        if (MainActivity.blockedPackages.isNotEmpty()) {
            try {
                val intent = Intent(this, BypassDetectionService::class.java)
                startService(intent)
            } catch (e: Exception) {
                Log.e("BypassDetection", "Failed to restart service: ${e.message}")
            }
        }
    }
    
    inner class BypassDetectionReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_PACKAGE_REMOVED -> {
                    val packageName = intent.data?.schemeSpecificPart
                    if (packageName == context?.packageName) {
                        // Our app is being uninstalled - prevent it
                        handleBypassAttempt("App uninstallation attempted")
                    }
                }
                Intent.ACTION_AIRPLANE_MODE_CHANGED -> {
                    if (isAirplaneModeOn()) {
                        handleBypassAttempt("Airplane mode enabled")
                    }
                }
                Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_REBOOT -> {
                    // Restart protection after reboot
                    if (MainActivity.blockedPackages.isNotEmpty()) {
                        startBypassMonitoring()
                    }
                }
                Intent.ACTION_SHUTDOWN -> {
                    // Log shutdown attempt during blocking
                    if (MainActivity.blockedPackages.isNotEmpty()) {
                        handleBypassAttempt("Device shutdown during blocking")
                    }
                }
            }
        }
    }
}