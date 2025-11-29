package com.example.mytime

import android.os.Build

data class ManufacturerInfo(
    val manufacturer: String,
    val model: String,
    val androidVersion: Int,
    val batteryOptimizationInstructions: String,
    val settingsDeepLink: String?
)

object ManufacturerDetector {
    
    fun detect(): ManufacturerInfo {
        val manufacturer = Build.MANUFACTURER.lowercase()
        val model = Build.MODEL
        val androidVersion = Build.VERSION.SDK_INT
        
        return when {
            manufacturer.contains("oneplus") -> onePlusInfo(model, androidVersion)
            manufacturer.contains("samsung") -> samsungInfo(model, androidVersion)
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco") -> xiaomiInfo(model, androidVersion)
            manufacturer.contains("oppo") -> oppoInfo(model, androidVersion)
            manufacturer.contains("vivo") -> vivoInfo(model, androidVersion)
            manufacturer.contains("realme") -> realmeInfo(model, androidVersion)
            manufacturer.contains("huawei") || manufacturer.contains("honor") -> huaweiInfo(model, androidVersion)
            else -> genericInfo(manufacturer, model, androidVersion)
        }
    }
    
    private fun onePlusInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "OnePlus",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                OnePlus (OxygenOS) Battery Optimization:
                1. Settings → Battery → Battery Optimization → MyTime → Don't Optimize
                2. Settings → Apps → MyTime → Battery → Background Activity → Allow
                3. Settings → Apps → Special Access → App Auto-Launch → MyTime → Enable
                4. Settings → Battery → Smart charging → OFF (recommended)
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun samsungInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Samsung",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Samsung (One UI) Battery Optimization:
                1. Settings → Apps → MyTime → Battery → Optimize Battery Usage → OFF
                2. Settings → Device Care → Battery → App Power Management → MyTime → Unrestricted
                3. Settings → Apps → MyTime → Mobile Data → Allow background data usage
                4. Disable "Put unused apps to sleep"
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun xiaomiInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Xiaomi/Redmi/Poco",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Xiaomi (MIUI) Battery Optimization:
                1. Settings → Apps → Manage Apps → MyTime → Battery Saver → No Restrictions
                2. Settings → Apps → Manage Apps → MyTime → Autostart → Enable
                3. Security → Battery → App Battery Saver → MyTime → No Restrictions
                4. Settings → Additional Settings → Privacy → Special Permissions → Battery Optimization → MyTime → Don't Optimize
            """.trimIndent(),
            settingsDeepLink = "miui.intent.action.APP_PERM_EDITOR"
        )
    }
    
    private fun oppoInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Oppo",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Oppo (ColorOS) Battery Optimization:
                1. Settings → Battery → App Battery Management → MyTime → Don't Optimize
                2. Settings → Apps → MyTime → App Battery → Allow background activity
                3. Settings → Apps → MyTime → Startup Manager → Enable
                4. Phone Manager → Privacy Permissions → Startup Manager → MyTime → Enable
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun vivoInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Vivo",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Vivo (Funtouch OS) Battery Optimization:
                1. Settings → Battery → Background Power Consumption Management → MyTime → High Background Power Consumption
                2. Settings → Apps → MyTime → Battery → Allow background activity
                3. i Manager → App Manager → MyTime → Auto-start → Enable
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun realmeInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Realme",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Realme (Realme UI) Battery Optimization:
                1. Settings → Battery → App Battery Management → MyTime → Unrestricted
                2. Settings → Apps → MyTime → App Battery Usage → Unrestricted
                3. Settings → Apps → MyTime → Startup Manager → Enable
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun huaweiInfo(model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = "Huawei/Honor",
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Huawei (EMUI) Battery Optimization:
                1. Settings → Battery → App Launch → MyTime → Manage Manually → Enable all switches
                2. Settings → Apps → MyTime → Battery → Power-intensive prompt → OFF
                3. Phone Manager → App Launch → MyTime → Manage Manually
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    private fun genericInfo(manufacturer: String, model: String, version: Int): ManufacturerInfo {
        return ManufacturerInfo(
            manufacturer = manufacturer.replaceFirstChar { it.uppercase() },
            model = model,
            androidVersion = version,
            batteryOptimizationInstructions = """
                Standard Android Battery Optimization:
                1. Settings → Apps → MyTime → Battery → Battery Optimization → Don't Optimize
                2. Settings → Apps → MyTime → Mobile Data & Wi-Fi → Allow background data
                3. Ensure the app is not restricted in battery settings
            """.trimIndent(),
            settingsDeepLink = "android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS"
        )
    }
    
    fun isOnePlus(): Boolean {
        return Build.MANUFACTURER.lowercase().contains("oneplus")
    }
    
    fun isSamsung(): Boolean {
        return Build.MANUFACTURER.lowercase().contains("samsung")
    }
    
    fun isXiaomi(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()
        return manufacturer.contains("xiaomi") || manufacturer.contains("redmi") || manufacturer.contains("poco")
    }
}
