package com.example.mytime

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat

class CommitmentMonitoringService : Service() {
    
    private lateinit var commitmentManager: CommitmentModeManager
    private val TAG = "CommitmentMonitoring"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "commitment_mode_channel"
    
    companion object {
        var isRunning = false
    }
    
    override fun onCreate() {
        super.onCreate()
        commitmentManager = CommitmentModeManager(this)
        createNotificationChannel()
        Log.d(TAG, "Service created")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (commitmentManager.isCommitmentActive()) {
            startForeground(NOTIFICATION_ID, createNotification())
            isRunning = true
            Log.d(TAG, "Service started in foreground")
            
            // Schedule periodic checks
            schedulePeriodicChecks()
        } else {
            // Commitment expired, stop service
            commitmentManager.clearIfExpired()
            stopSelf()
            isRunning = false
        }
        
        return START_STICKY // Restart if killed
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, "Commitment Mode", importance).apply {
                description = "Shows commitment mode status"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val remainingTime = commitmentManager.getRemainingTime()
        val hours = remainingTime / (1000 * 60 * 60)
        val minutes = (remainingTime / (1000 * 60)) % 60
        
        val contentText = if (hours > 0) {
            "Active: ${hours}h ${minutes}m remaining"
        } else {
            "Active: ${minutes}m remaining"
        }
        
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("🔒 Commitment Mode")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }
    
    private fun schedulePeriodicChecks() {
        // Use handler to check every minute
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        val runnable = object : Runnable {
            override fun run() {
                if (commitmentManager.isCommitmentActive()) {
                    // Update notification
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.notify(NOTIFICATION_ID, createNotification())
                    
                    // Check permissions and services
                    checkProtectionStatus()
                    
                    // Schedule next check
                    handler.postDelayed(this, 60 * 1000) // Every minute
                } else {
                    // Commitment expired - trigger cleanup
                    Log.d(TAG, "⏰ Commitment has EXPIRED! Triggering cleanup...")
                    commitmentManager.clearIfExpired()
                    Log.d(TAG, "🛑 Stopping monitoring service")
                    stopSelf()
                    isRunning = false
                }
            }
        }
        
        handler.post(runnable)
    }
    
    private fun checkProtectionStatus() {
        // Check if Accessibility Service is still enabled
        val isAccessibilityEnabled = PermissionHelper.isAccessibilityServiceEnabled(this)
        
        if (!isAccessibilityEnabled) {
            Log.w(TAG, "⚠️ Accessibility Service disabled during commitment!")
            showWarningNotification("Accessibility Service disabled", "App protection may not work")
        }
        
        // Validate commitment hasn't been tampered with
        if (!commitmentManager.validateCommitment()) {
            Log.w(TAG, "⚠️ Commitment validation failed - possible tampering!")
        }
    }
    
    private fun showWarningNotification(title: String, message: String) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .build()
        
        notificationManager.notify(NOTIFICATION_ID + 1, notification)
    }
    
    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        Log.d(TAG, "Service destroyed")
    }
}
