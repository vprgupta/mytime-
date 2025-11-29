package com.example.mytime

object MonitoringConfig {
    // Monitoring intervals (in milliseconds)
    const val CRITICAL_CHECK_INTERVAL = 60000L      // 60 seconds - accessibility service
    const val IMPORTANT_CHECK_INTERVAL = 120000L    // 2 minutes - time, battery
    const val NORMAL_CHECK_INTERVAL = 300000L       // 5 minutes - notifications, user switching
    
    // Alert cooldowns (in milliseconds)
    const val ACCESSIBILITY_ALERT_COOLDOWN = 600000L // 10 minutes
    const val GENERAL_ALERT_COOLDOWN = 60000L        // 1 minute
    
    // Performance settings
    const val MAX_MONITORING_THREADS = 1
    const val ERROR_RETRY_DELAY = 10000L             // 10 seconds
    
    // Battery optimization
    const val ENABLE_AGGRESSIVE_MONITORING = false   // Set to true only if needed
    const val REDUCE_BACKGROUND_ACTIVITY = true      // Optimize for battery life
    
    // Time manipulation thresholds
    const val TIME_JUMP_THRESHOLD = 300000L          // 5 minutes
    const val MINOR_TIME_JUMP_THRESHOLD = 60000L     // 1 minute
    
    // Feature toggles
    const val ENABLE_TIME_MONITORING = true
    const val ENABLE_BATTERY_MONITORING = false
    const val ENABLE_NOTIFICATION_MONITORING = true
    const val ENABLE_USER_SWITCH_MONITORING = true
    const val ENABLE_ACCESSIBILITY_MONITORING = true // Always keep this true
}