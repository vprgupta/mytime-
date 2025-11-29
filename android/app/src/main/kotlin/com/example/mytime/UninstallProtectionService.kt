package com.example.mytime

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.IBinder
import android.util.Log

class UninstallProtectionService : Service() {
    
    private val uninstallReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                Intent.ACTION_PACKAGE_REMOVED,
                Intent.ACTION_PACKAGE_FULLY_REMOVED -> {
                    val packageName = intent.data?.schemeSpecificPart
                    if (packageName == context?.packageName) {
                        // Our app is being uninstalled - try to prevent it
                        preventUninstall(context)
                    }
                }

            }
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        registerUninstallReceiver()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY // Restart if killed
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    private fun registerUninstallReceiver() {
        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_REMOVED)
            addAction(Intent.ACTION_PACKAGE_FULLY_REMOVED)

            addDataScheme("package")
        }
        registerReceiver(uninstallReceiver, filter)
    }
    
    private fun preventUninstall(context: Context?) {
        try {
            // Bring app to foreground to interrupt uninstall
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("prevent_uninstall", true)
            }
            context?.startActivity(intent)
            
            Log.w("UninstallProtection", "Uninstall attempt detected and blocked")
        } catch (e: Exception) {
            Log.e("UninstallProtection", "Failed to prevent uninstall", e)
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(uninstallReceiver)
        } catch (e: Exception) {
            // Receiver might not be registered
        }
    }
}