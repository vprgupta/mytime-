package com.example.mytime

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log

class BatteryOptimizationManager(private val context: Context) {
    private val tag = "BatteryOptimizationManager"
    
    fun optimizeForBatteryLife() {
        Log.d(tag, "Optimizing app for battery life")
        
        // Reduce monitoring frequency when battery is low
        if (isBatteryLow()) {
            Log.d(tag, "Battery low - reducing monitoring frequency")
            // This could trigger a configuration change
        }
        
        // Check if app is whitelisted from battery optimization
        if (!isBatteryOptimizationDisabled()) {
            Log.w(tag, "App not whitelisted from battery optimization")
        }
    }
    
    private fun isBatteryLow(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isPowerSaveMode
        } else {
            false
        }
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(context.packageName)
        } else {
            true
        }
    }
    
    fun shouldReduceMonitoring(): Boolean {
        return MonitoringConfig.REDUCE_BACKGROUND_ACTIVITY && 
               (isBatteryLow() || !isBatteryOptimizationDisabled())
    }
    
    fun getOptimizedCheckInterval(): Long {
        return if (shouldReduceMonitoring()) {
            MonitoringConfig.CRITICAL_CHECK_INTERVAL * 2 // Double the interval
        } else {
            MonitoringConfig.CRITICAL_CHECK_INTERVAL
        }
    }
}