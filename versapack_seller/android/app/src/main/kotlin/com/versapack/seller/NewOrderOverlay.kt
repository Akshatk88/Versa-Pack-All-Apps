package com.versapack.seller

import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.app.NotificationManagerCompat
import com.example.quick_commerce_seller.R

/**
 * Full-screen, high-priority new-order prompt drawn over every other app.
 *
 * The window covers the whole screen with a dimmed scrim and swallows touches,
 * so the seller cannot miss it or tap past it — it stays until they accept,
 * reject, or the server withdraws the order (cancelled / taken / expired).
 *
 * Needs "Display over other apps". Without it [show] returns false and the
 * caller falls back to a full-screen-intent notification.
 */
object NewOrderOverlay {
    private const val TAG = "NEW_ORDER_OVERLAY"
    private const val WAKE_MS = 15_000L

    private val main = Handler(Looper.getMainLooper())
    private var currentOrderId: String? = null
    private var window: View? = null
    private var windowManager: WindowManager? = null

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    fun show(
        context: Context,
        orderId: String,
        displayId: String = "",
        customerName: String = "",
        itemCount: String = "",
        body: String = "",
        address: String = "",
        itemsList: String = "",
        total: String = "",
    ): Boolean {
        if (orderId.isBlank()) return false
        val appContext = context.applicationContext
        if (!canDraw(appContext)) {
            Log.w(TAG, "overlay permission denied for $orderId. User must grant 'Display over other apps' permission.")
            return false
        }

        main.post {
            try {
                val root = LayoutInflater.from(appContext)
                    .inflate(R.layout.overlay_new_order, null)
                bind(appContext, root, orderId, displayId, customerName, itemCount, body, address, itemsList, total)

                val wm = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
                // One prompt at a time: a newer order replaces the one on screen
                // rather than stacking a second window on top of it.
                window?.let { old -> runCatching { windowManager?.removeViewImmediate(old) } }

                currentOrderId = orderId
                window = root
                windowManager = wm
                wm.addView(root, layoutParams())
                wakeScreen(appContext)
                Log.d(TAG, "overlay successfully shown on UI thread for $orderId")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to show overlay on UI thread: ${e.message}", e)
                window = null
                currentOrderId = null
            }
        }
        return true
    }

    /** Takes the prompt down, whichever order it is showing. */
    fun dismiss(context: Context) {
        main.post {
            val wm = windowManager
            val view = window
            if (wm != null && view != null) runCatching { wm.removeViewImmediate(view) }
            window = null
            windowManager = null
            currentOrderId = null
            Log.d(TAG, "overlay dismissed")
        }
    }

    private fun bind(
        context: Context,
        root: View,
        orderId: String,
        displayId: String,
        customerName: String,
        itemCount: String,
        body: String,
        address: String,
        itemsList: String,
        total: String,
    ) {
        root.findViewById<TextView>(R.id.overlayDisplayId).text = when {
            displayId.isNotBlank() ->
                if (displayId.startsWith("Order", ignoreCase = true)) displayId else "Order #$displayId"
            else -> "Order #${orderId.takeLast(8).uppercase()}"
        }

        root.findViewById<TextView>(R.id.overlayCustomer).showOrHide(
            customerName.takeIf { it.isNotBlank() }?.let { "👤 $it" },
        )
        root.findViewById<TextView>(R.id.overlayAddress).showOrHide(
            address.takeIf { it.isNotBlank() }?.let { "📍 $it" },
        )
        root.findViewById<TextView>(R.id.overlayItems).text = when {
            itemsList.isNotBlank() -> "📦 $itemsList"
            body.isNotBlank() -> "📦 $body"
            itemCount.isNotBlank() -> "📦 $itemCount item(s)"
            else -> "📦 New order waiting"
        }
        root.findViewById<TextView>(R.id.overlayPrice).showOrHide(
            total.takeIf { it.isNotBlank() }?.let { if (it.startsWith("₹")) it else "₹$it" },
        )

        root.findViewById<Button>(R.id.overlayAccept).setOnClickListener {
            Log.d(TAG, "ACCEPT tapped for $orderId")
            answer(context, orderId, "accept")
        }
        root.findViewById<Button>(R.id.overlayReject).setOnClickListener {
            Log.d(TAG, "REJECT tapped for $orderId")
            answer(context, orderId, "reject")
        }
    }

    private fun answer(context: Context, orderId: String, action: String) {
        NewOrderAlarmService.stop(context)
        dismiss(context)
        // The lock-screen / fallback notification for the same order must not
        // outlive the answer.
        runCatching { NotificationManagerCompat.from(context).cancel(orderId.hashCode()) }
        openOrderWithAction(context, orderId, action)
    }

    private fun layoutParams(): WindowManager.LayoutParams {
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }
        @Suppress("DEPRECATION")
        return WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            // Full screen and touch-modal: the scrim catches every tap, so the
            // seller has to answer the order. NOT_FOCUSABLE only keeps the
            // keyboard of the app underneath from being stolen.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        )
    }

    /**
     * Overlay windows cannot turn the screen on by themselves (that flag only
     * works for activities), so a phone lying face-down would ring with a dark
     * screen. A short wake lock lights it up so the prompt is actually seen.
     */
    @Suppress("DEPRECATION")
    private fun wakeScreen(context: Context) {
        runCatching {
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (pm.isInteractive) return
            pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "versapack:new_order",
            ).acquire(WAKE_MS)
        }.onFailure { Log.w(TAG, "could not wake screen: $it") }
    }

    private fun openOrderWithAction(context: Context, orderId: String, action: String) {
        // Explicit component: a launcher intent against an existing task is
        // delivered as a plain resume and the extras are dropped.
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP,
            )
            putExtra("orderId", orderId)
            putExtra("notificationAction", action)
        }
        runCatching { context.startActivity(intent) }
            .onFailure { Log.e(TAG, "could not open app for $orderId: $it") }
    }

    private fun TextView.showOrHide(value: String?) {
        if (value.isNullOrBlank()) {
            visibility = View.GONE
        } else {
            text = value
            visibility = View.VISIBLE
        }
    }
}
