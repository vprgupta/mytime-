# Quick Fix for Compilation Errors

## Problem
The app won't compile because 4 helper methods are missing from MainActivity.kt.

## Solution

### Step 1: Open MainActivity.kt
Open: `android/app/src/main/kotlin/com/example/mytime/MainActivity.kt`

### Step 2: Find the insertion point
Search for this line (around line 674):
```kotlin
override fun onNewIntent(intent: Intent) {
```

### Step 3: Insert the helper methods
**BEFORE** the `override fun onNewIntent` line, paste the following code:

```kotlin
    private fun startCommitmentMonitoring() {
        try {
            val intent = Intent(this, CommitmentMonitoringService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            android.util.Log.d("MainActivity", "Started commitment monitoring service")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to start commitment monitoring", e)
        }
    }
    
    private fun requestBatteryOptimizationExemption() {
        try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            openBatteryOptimizationSettings()
        }
    }
    
    private fun isBatteryOptimizationIgnored(): Boolean {
        return try {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                powerManager.isIgnoringBatteryOptimizations(packageName)
            } else {
                true
            }
        } catch (e: Exception) {
            false
        }
    }
    
    private fun openBatteryOptimizationSettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            try {
                val fallbackIntent = Intent(android.provider.Settings.ACTION_BATTERY_SAVER_SETTINGS)
                startActivity(fallbackIntent)
            } catch(fallbackE: Exception) {
                android.util.Log.e("MainActivity", "Failed to open battery settings", fallbackE)
            }
        }
    }
    
```

### Step 4: Save and rebuild
After pasting:
1. Save MainActivity.kt
2. Run: `flutter run`

The app should now compile successfully!

---

## What These Methods Do

1. **startCommitmentMonitoring()** - Starts the foreground service with persistent notification
2. **requestBatteryOptimizationExemption()** - Opens battery settings for the user
3. **isBatteryOptimizationIgnored()** - Checks if battery optimization is disabled
4. **openBatteryOptimizationSettings()** - Opens battery optimization settings page

These methods are called by the new commitment mode features.
