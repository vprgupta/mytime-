package com.example.mytime

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView

class BlockedAppOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var overlayParams: WindowManager.LayoutParams? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isOverlayAttached = false
    
    companion object {
        const val ACTION_SHOW = "com.example.mytime.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE = "com.example.mytime.ACTION_HIDE_OVERLAY"
        const val CHANNEL_ID = "app_blocking_overlay"
        const val NOTIFICATION_ID = 1001
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Start as foreground service to keep it alive
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            createNotificationChannel()
            val notification = createNotification()
            startForeground(NOTIFICATION_ID, notification)
        }
        
        // Pre-create overlay view for instant display
        prepareOverlayView()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Blocking Overlay",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps overlay service ready for instant blocking"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("MyTime Protection Active")
                .setContentText("App blocking is ready")
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("MyTime Protection Active")
                .setContentText("App blocking is ready")
                .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
                .build()
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_HIDE) {
            hideOverlay()
            return START_STICKY // Keep service alive
        }

        val appName = intent?.getStringExtra("appName") ?: "App"
        showOverlay(appName)
        
        return START_STICKY // Keep service alive for instant blocking
    }
    
    private fun prepareOverlayView() {
        try {
            // Create window layout params
            overlayParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                PixelFormat.TRANSLUCENT
            )
            overlayParams?.gravity = Gravity.CENTER
            
            // Pre-create the view structure
            overlayView = createOverlayView("Blocked App")
            overlayView?.visibility = View.GONE // Hidden initially
            
            // Attach to window manager (hidden)
            windowManager?.addView(overlayView, overlayParams)
            isOverlayAttached = true
            
            android.util.Log.d("OverlayService", "✅ Overlay view pre-created and ready")
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Error preparing overlay: ${e.message}")
        }
    }

    private fun showOverlay(appName: String) {
        try {
            if (isOverlayAttached && overlayView != null) {
                // Overlay already prepared, just make it visible INSTANTLY
                overlayView?.visibility = View.VISIBLE
                
                // Update app name asynchronously (non-blocking)
                handler.post {
                    updateOverlayContent(appName)
                }
                
                android.util.Log.d("OverlayService", "⚡ Overlay shown INSTANTLY for $appName")
            } else {
                // Fallback: create and show overlay (slower path)
                android.util.Log.w("OverlayService", "⚠️ Overlay not prepared, using fallback")
                
                overlayParams = WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                        WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                    else
                        WindowManager.LayoutParams.TYPE_PHONE,
                    WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                    PixelFormat.TRANSLUCENT
                )
                overlayParams?.gravity = Gravity.CENTER
                
                overlayView = createOverlayView(appName)
                windowManager?.addView(overlayView, overlayParams)
                isOverlayAttached = true
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Error showing overlay: ${e.message}")
        }
    }
    
    private fun createOverlayView(appName: String): View {
        // Root Layout - Opaque black background (shows INSTANTLY)
        val rootLayout = FrameLayout(this)
        rootLayout.setBackgroundColor(Color.BLACK)
        rootLayout.setOnClickListener { 
            // Catch clicks to prevent interaction with app below
        }

        // Card Container
        val cardLayout = LinearLayout(this)
        cardLayout.orientation = LinearLayout.VERTICAL
        cardLayout.gravity = Gravity.CENTER
        val cardBackground = GradientDrawable()
        cardBackground.setColor(Color.parseColor("#1E1E1E"))
        cardBackground.cornerRadius = 48f
        cardLayout.background = cardBackground
        cardLayout.setPadding(64, 80, 64, 80)
        
        val cardParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        )
        cardParams.gravity = Gravity.CENTER
        rootLayout.addView(cardLayout, cardParams)

        // Lottie Animation - Load asynchronously to not block display
        val lottieView = com.airbnb.lottie.LottieAnimationView(this)
        lottieView.id = View.generateViewId() // For later reference
        val lottieParams = LinearLayout.LayoutParams(800, 800) 
        lottieParams.gravity = Gravity.CENTER
        cardLayout.addView(lottieView, lottieParams)
        
        // Load animation asynchronously (non-blocking)
        handler.post {
            try {
                lottieView.setAnimation("blocked_animation.json")
                lottieView.repeatCount = com.airbnb.lottie.LottieDrawable.INFINITE
                lottieView.playAnimation()
            } catch (e: Exception) {
                android.util.Log.e("OverlayService", "Error loading animation: ${e.message}")
            }
        }
        
        // Spacer
        val spacer1 = View(this)
        cardLayout.addView(spacer1, LinearLayout.LayoutParams(1, 32))

        // Title
        val titleView = TextView(this)
        titleView.id = View.generateViewId()
        titleView.text = "Access Denied"
        titleView.textSize = 24f
        titleView.setTextColor(Color.WHITE)
        titleView.typeface = Typeface.DEFAULT_BOLD
        titleView.gravity = Gravity.CENTER
        cardLayout.addView(titleView)
        
        // Spacer
        val spacer2 = View(this)
        cardLayout.addView(spacer2, LinearLayout.LayoutParams(1, 16))

        // Message
        val messageView = TextView(this)
        messageView.id = View.generateViewId()
        messageView.text = "$appName is currently blocked by your commitment settings."
        messageView.textSize = 16f
        messageView.setTextColor(Color.parseColor("#CCCCCC"))
        messageView.gravity = Gravity.CENTER
        messageView.setPadding(16, 0, 16, 0)
        cardLayout.addView(messageView)
        
        // Spacer
        val spacer3 = View(this)
        cardLayout.addView(spacer3, LinearLayout.LayoutParams(1, 64))

        // Button
        val button = Button(this)
        button.text = "Close"
        button.setTextColor(Color.WHITE)
        val btnBackground = GradientDrawable()
        btnBackground.setColor(Color.parseColor("#FF5252"))
        btnBackground.cornerRadius = 24f
        button.background = btnBackground
        button.setOnClickListener {
            hideOverlay()
            // Trigger home just in case
            val homeIntent = Intent(Intent.ACTION_MAIN)
            homeIntent.addCategory(Intent.CATEGORY_HOME)
            homeIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(homeIntent)
        }
        
        val btnParams = LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT
        )
        btnParams.leftMargin = 32
        btnParams.rightMargin = 32
        cardLayout.addView(button, btnParams)
        
        return rootLayout
    }
    
    private fun updateOverlayContent(appName: String) {
        try {
            // Find and update the message TextView
            val rootLayout = overlayView as? FrameLayout
            val cardLayout = rootLayout?.getChildAt(0) as? LinearLayout
            
            cardLayout?.let { card ->
                for (i in 0 until card.childCount) {
                    val child = card.getChildAt(i)
                    if (child is TextView && child.text.contains("blocked by your commitment")) {
                        child.text = "$appName is currently blocked by your commitment settings."
                        break
                    }
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Error updating overlay content: ${e.message}")
        }
    }

    private fun hideOverlay() {
        if (overlayView != null) {
            try {
                // Just hide it instead of removing (keep it ready for next time)
                overlayView?.visibility = View.GONE
                android.util.Log.d("OverlayService", "🙈 Overlay hidden (kept ready)")
            } catch (e: Exception) {
                android.util.Log.e("OverlayService", "Error hiding overlay: ${e.message}")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Clean up overlay
        if (isOverlayAttached && overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                // Ignore
            }
        }
        overlayView = null
        isOverlayAttached = false
    }
}
