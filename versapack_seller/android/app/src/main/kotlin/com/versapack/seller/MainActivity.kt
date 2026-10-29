package com.versapack.seller

import android.app.AlertDialog
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingLaunchOrderId: String? = null
    private var pendingLaunchAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyLockScreenMode(intent)
        createNewOrderChannel()
        createDefaultChannel()
        AppForeground.isForeground = true
        consumeLaunchOrderIfAny(intent)
    }

    override fun onResume() {
        super.onResume()
        AppForeground.isForeground = true
        consumeLaunchOrderIfAny(intent)
    }

    override fun onPause() {
        AppForeground.isForeground = false
        super.onPause()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        applyLockScreenMode(intent)
        consumeLaunchOrderIfAny(intent)
    }

    /**
     * Shows over the lock screen and wakes the display only when opened by the
     * new-order full-screen notification. Never for an ordinary launch: the
     * app holds orders and payouts, and must not be usable without unlocking.
     */
    private fun applyLockScreenMode(intent: Intent?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O_MR1) return
        val forOrder = intent?.action == ACTION_VIEW_ORDER
        setShowWhenLocked(forOrder)
        setTurnScreenOn(forOrder)
    }

    /**
     * Lets Dart drive the ringtone that the native service owns.
     *
     * The service is the only thing that ever plays it — in the foreground too
     * — so there is exactly one player in every app state and no way for two
     * copies to overlap.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ALARM_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startAlarm" -> {
                    val orderId = call.argument<String>("orderId").orEmpty()
                    if (orderId.isBlank()) {
                        result.error("no_order_id", "orderId is required", null)
                    } else {
                        NewOrderAlarmService.start(this, orderId)
                        result.success(true)
                    }
                }

                "stopAlarm" -> {
                    NewOrderAlarmService.stop(this)
                    result.success(true)
                }

                "isAlarmRinging" ->
                    result.success(NewOrderAlarmService.ringingOrderId != null)

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LAUNCH_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "consumeLaunchOrder" -> {
                    val orderId = consumeLaunchOrderIfAny(intent)
                    result.success(orderId)
                }

                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                "requestOverlayPermission" -> {
                    requestAlertPermissions()
                    result.success(true)
                }

                "dismissOverlay" -> {
                    NewOrderOverlay.dismiss(this)
                    result.success(true)
                }

                "showOverlay" -> {
                    val orderId = call.argument<String>("orderId").orEmpty()
                    val displayId = call.argument<String>("orderDisplayId").orEmpty()
                    val customerName = call.argument<String>("customerName").orEmpty()
                    val itemCount = call.argument<String>("itemCount").orEmpty()
                    val body = call.argument<String>("body").orEmpty()
                    val address = call.argument<String>("address").orEmpty()
                    val itemsList = call.argument<String>("itemsList").orEmpty()
                    val total = call.argument<String>("total").orEmpty()

                    val shown = NewOrderOverlay.show(
                        context = this,
                        orderId = orderId,
                        displayId = displayId,
                        customerName = customerName,
                        itemCount = itemCount,
                        body = body,
                        address = address,
                        itemsList = itemsList,
                        total = total,
                    )
                    result.success(shown)
                }

                else -> result.notImplemented()
            }
        }

        pendingLaunchOrderId?.let { orderId ->
            val action = pendingLaunchAction

            pendingLaunchOrderId = null
            pendingLaunchAction = null

            val channel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                LAUNCH_CHANNEL,
            )

            channel.invokeMethod(
                "onNativeLaunchOrder",
                mapOf(
                    "orderId" to orderId,
                    "action" to action,
                ),
            )
        }
    }

    /**
     * The channel every non-new-order push lands on.
     *
     * The backend sends `new_order_channel` only for new orders and
     * `high_importance_channel` for everything else — order cancelled, order
     * claimed, admin broadcasts, subscription and FSSAI reminders.
     *
     * This must exist. When a push names a channel the device does not have,
     * FCM falls back to `default_notification_channel_id` from the manifest, so
     * with only the new-order channel present *every* notification inherited
     * the custom ringtone. The whole point of this channel is that it uses the
     * system notification sound.
     */
    private fun createDefaultChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(DEFAULT_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            DEFAULT_CHANNEL_ID,
            "General notifications",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Order updates, payouts and announcements"
            // No setSound() call: a channel created without one uses the
            // device's default notification tone, which is exactly what these
            // are supposed to sound like.
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * Creates the channel the backend addresses new-order pushes to
     * (androidChannelId: new_order_channel).
     *
     * This is the only way a new order can make a noise while the app is
     * backgrounded or killed: Dart is not running then, so the looping in-app
     * alert cannot start and the channel's own sound is what the seller hears.
     *
     * Created here rather than left to FCM because a channel's sound and
     * importance are fixed at creation. If FCM auto-creates it first, the
     * alert arrives with the default tone at default importance and no later
     * code can change it — only a reinstall can.
     */
    private fun createNewOrderChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(NEW_ORDER_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            NEW_ORDER_CHANNEL_ID,
            "New orders",
            // HIGH so the alert is a heads-up with sound. Anything lower is
            // silently demoted to a tray entry the seller never notices.
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Orders waiting to be accepted"
            setSound(
                Uri.parse("android.resource://$packageName/raw/neworder"),
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    // Ringtone usage, not NOTIFICATION: it plays the whole
                    // asset and carries through Do Not Disturb exemptions the
                    // seller may have set for the app.
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .build(),
            )
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    /**
     * Walks the seller through the two switches the high-priority order prompt
     * needs: "Display over other apps" (the full-screen overlay) and, on
     * Android 14+, "full-screen notifications" (the lock-screen fallback).
     *
     * Both are Settings toggles, not runtime dialogs, so each is explained first
     * and then opened on this app's own page — the bare overlay intent lands on
     * a list of every installed app, where sellers never found ours.
     */
    private fun requestAlertPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
            explainThenOpen(
                title = "Allow order pop-up",
                message = "New orders appear as a full-screen pop-up over any app so you never " +
                    "miss one. On the next screen, turn ON \"Display over other apps\" for " +
                    "Versapack Seller.",
                settingsIntent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ),
            )
            return
        }

        if (Build.VERSION.SDK_INT >= 34) {
            val manager = getSystemService(NotificationManager::class.java)
            if (manager != null && !manager.canUseFullScreenIntent()) {
                explainThenOpen(
                    title = "Allow lock-screen alerts",
                    message = "So new orders can light up the screen and show over the lock " +
                        "screen, turn ON full-screen notifications for Versapack Seller.",
                    settingsIntent = Intent(
                        Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                        Uri.parse("package:$packageName"),
                    ),
                )
            }
        }
    }

    private fun explainThenOpen(title: String, message: String, settingsIntent: Intent) {
        if (isFinishing) return
        AlertDialog.Builder(this)
            .setTitle(title)
            .setMessage(message)
            .setCancelable(false)
            .setPositiveButton("Allow") { _, _ ->
                runCatching { startActivity(settingsIntent) }.onFailure {
                    // Some ROMs reject the package-scoped form; fall back to
                    // the app's details page, where the toggle also lives.
                    runCatching {
                        startActivity(
                            Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    }
                }
            }
            .setNegativeButton("Later", null)
            .show()
    }

    private fun consumeLaunchOrderIfAny(intent: Intent?): String? {
        val orderId = intent?.getStringExtra("orderId")

        if (orderId.isNullOrBlank()) return null

        val action = intent.getStringExtra("notificationAction")

        intent.removeExtra("orderId")
        intent.removeExtra("notificationAction")
        intent.removeExtra("autoAccept")

        pendingLaunchOrderId = orderId
        pendingLaunchAction = action

        val channel = flutterEngine?.dartExecutor?.binaryMessenger

        if (channel != null) {
            pendingLaunchOrderId = null
            pendingLaunchAction = null

            MethodChannel(
                channel,
                LAUNCH_CHANNEL,
            ).invokeMethod(
                "onNativeLaunchOrder",
                mapOf(
                    "orderId" to orderId,
                    "action" to action,
                ),
            )
        }

        return orderId
    }

    private companion object {
        const val ALARM_CHANNEL = "com.quick.seller/new_order_alarm"
        const val LAUNCH_CHANNEL = "com.versapack.seller/launch_order"

        /** Set by SellerMessagingService on the full-screen order intent. */
        const val ACTION_VIEW_ORDER = "com.versapack.seller.VIEW_ORDER"

        /** Custom ringtone. Backend uses this for `type == "new_order"` only. */
        const val NEW_ORDER_CHANNEL_ID = "new_order_channel"

        /** System sound. Backend's `FCM_DEFAULT_CHANNEL_ID` for everything else. */
        const val DEFAULT_CHANNEL_ID = "high_importance_channel"
    }
}
