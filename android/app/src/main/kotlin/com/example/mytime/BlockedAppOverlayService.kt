package com.example.mytime

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
    private val handler = Handler(Looper.getMainLooper())
    
    companion object {
        const val ACTION_SHOW = "com.example.mytime.ACTION_SHOW_OVERLAY"
        const val ACTION_HIDE = "com.example.mytime.ACTION_HIDE_OVERLAY"
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_HIDE) {
            hideOverlay()
            stopSelf()
            return START_NOT_STICKY
        }

        val appName = intent?.getStringExtra("appName") ?: "App"
        showOverlay(appName)
        
        return START_NOT_STICKY
    }

    private fun showOverlay(appName: String) {
        if (overlayView != null) return // Already showing

        try {
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS, // Cover status/nav bars
                PixelFormat.TRANSLUCENT
            )
            
            // Full screen coverage
            params.gravity = Gravity.CENTER

            // Root Layout - Opaque black background
            val rootLayout = FrameLayout(this)
            rootLayout.setBackgroundColor(Color.BLACK) // 100% opacity black
            rootLayout.setOnClickListener { 
                // Catch clicks to prevent interaction with app below
            }

            // Card Container
            val cardLayout = LinearLayout(this)
            cardLayout.orientation = LinearLayout.VERTICAL
            cardLayout.gravity = Gravity.CENTER
            val cardBackground = GradientDrawable()
            cardBackground.setColor(Color.parseColor("#1E1E1E")) // Dark gray card
            cardBackground.cornerRadius = 48f
            cardLayout.background = cardBackground
            cardLayout.setPadding(64, 80, 64, 80)
            
            val cardParams = FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT
            )
            cardParams.gravity = Gravity.CENTER
            // Removed margins for full screen effect
            rootLayout.addView(cardLayout, cardParams)

            // Lottie Animation
            val lottieView = com.airbnb.lottie.LottieAnimationView(this)
            lottieView.setAnimation("blocked_animation.json")
            lottieView.repeatCount = com.airbnb.lottie.LottieDrawable.INFINITE
            lottieView.playAnimation()
            
            // Increased size for better visibility
            val lottieParams = LinearLayout.LayoutParams(800, 800) 
            lottieParams.gravity = Gravity.CENTER
            cardLayout.addView(lottieView, lottieParams)
            
            // Spacer
            val spacer1 = View(this)
            cardLayout.addView(spacer1, LinearLayout.LayoutParams(1, 32))

            // Title
            val titleView = TextView(this)
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
            messageView.text = "$appName is currently blocked by your commitment settings."
            messageView.textSize = 16f
            messageView.setTextColor(Color.parseColor("#CCCCCC")) // Light gray
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
            btnBackground.setColor(Color.parseColor("#FF5252")) // Red accent
            btnBackground.cornerRadius = 24f
            button.background = btnBackground
            button.setOnClickListener {
                hideOverlay()
                stopSelf()
                // Also trigger home just in case
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
            
            overlayView = rootLayout
            windowManager?.addView(overlayView, params)
            
        } catch (e: Exception) {
            android.util.Log.e("OverlayService", "Error showing overlay: ${e.message}")
        }
    }

    private fun hideOverlay() {
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (e: Exception) {
                // Ignore
            }
            overlayView = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        hideOverlay()
    }
}
