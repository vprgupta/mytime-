package com.example.mytime

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast
import android.util.Log

class AppProtectionDeviceAdminReceiver : DeviceAdminReceiver() {
    
    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Toast.makeText(context, "App protection enabled", Toast.LENGTH_SHORT).show()
    }
    
    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Toast.makeText(context, "App protection disabled", Toast.LENGTH_SHORT).show()
    }
    
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        // Check if there are any active commitments
        val commitmentInfo = checkActiveCommitments(context)
        
        return if (commitmentInfo != null) {
            "⚠️ COMMITMENT MODE ACTIVE\n\n" +
            "You have ${commitmentInfo.count} active commitment(s).\n" +
            "Longest commitment expires in ${commitmentInfo.maxDays} days.\n\n" +
            "Disabling app protection will break your commitments!\n\n" +
            "Are you sure you want to continue?"
        } else {
            "Disabling app protection will allow bypassing app blocking.\n\nContinue?"
        }
    }
    
    private fun checkActiveCommitments(context: Context): CommitmentInfo? {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val keys = prefs.all.keys
            
            var commitmentCount = 0
            var maxRemainingDays = 0
            
            // Check usage limiter commitments
            for (key in keys) {
                if (key.startsWith("flutter.usage_limit_durations_")) {
                    val value = prefs.getString(key, null)
                    if (value != null && value.contains("\"hasCommitment\":true")) {
                        commitmentCount++
                        
                        // Extract duration days and start date
                        val daysMatch = Regex("\"durationDays\":(\\d+)").find(value)
                        val dateMatch = Regex("\"startDate\":\"([^\"]+)\"").find(value)
                        
                        if (daysMatch != null && dateMatch != null) {
                            val durationDays = daysMatch.groupValues[1].toInt()
                            val startDate = dateMatch.groupValues[1]
                            
                            // Calculate remaining days
                            val startMillis = java.time.Instant.parse(startDate).toEpochMilli()
                            val expiryMillis = startMillis + (durationDays * 24 * 60 * 60 * 1000L)
                            val nowMillis = System.currentTimeMillis()
                            val remainingDays = ((expiryMillis - nowMillis) / (24 * 60 * 60 * 1000L)).toInt() + 1
                            
                            if (remainingDays > 0 && remainingDays > maxRemainingDays) {
                                maxRemainingDays = remainingDays
                            }
                        }
                    }
                }
            }
            
            // Check commitment mode (strict mode)
            val commitmentStatus = prefs.getString("flutter.commitment_status", null)
            if (commitmentStatus != null && commitmentStatus.contains("\"isActive\":true")) {
                commitmentCount++
                
                val endTimeMatch = Regex("\"endTime\":(\\d+)").find(commitmentStatus)
                if (endTimeMatch != null) {
                    val endTime = endTimeMatch.groupValues[1].toLong()
                    val remainingDays = ((endTime - System.currentTimeMillis()) / (24 * 60 * 60 * 1000L)).toInt() + 1
                    if (remainingDays > 0 && remainingDays > maxRemainingDays) {
                        maxRemainingDays = remainingDays
                    }
                }
            }
            
            return if (commitmentCount > 0) {
                CommitmentInfo(commitmentCount, maxRemainingDays)
            } else {
                null
            }
        } catch (e: Exception) {
            Log.e("DeviceAdmin", "Error checking commitments", e)
            return null
        }
    }
    
    private data class CommitmentInfo(val count: Int, val maxDays: Int)
}