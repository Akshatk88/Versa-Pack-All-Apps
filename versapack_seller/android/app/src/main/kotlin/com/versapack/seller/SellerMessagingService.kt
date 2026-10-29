//package com.versapack.seller
//
//import android.app.PendingIntent
//import android.content.Intent
//import android.util.Log
//import androidx.core.app.NotificationCompat
//import androidx.core.app.NotificationManagerCompat
//import com.google.firebase.messaging.RemoteMessage
//import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
//
///**
// * Native Firebase Messaging Service.
// *
// * New order behaviour:
// *
// * 1. New orderId:
// *      -> Accept + Reject notification
// *      -> orderId saved in SharedPreferences
// *      -> ringtone starts
// *
// * 2. Same orderId again:
// *      -> No Accept + Reject notification
// *      -> ringtone can still start
// *
// * 3. Different/new orderId:
// *      -> Accept + Reject notification again
// *
// * This works even when the Flutter app is backgrounded/killed.
// */
//class SellerMessagingService : FlutterFirebaseMessagingService() {
//
//    override fun onMessageReceived(message: RemoteMessage) {
//
//        val data = message.data
//        val type = data["type"].orEmpty()
//
//        Log.d(TAG, "========================================")
//        Log.d(TAG, "FCM MESSAGE RECEIVED")
//        Log.d(TAG, "type = $type")
//        Log.d(TAG, "notification payload = ${message.notification}")
//        Log.d(TAG, "data = $data")
//
//        when (type) {
//
//            // =========================================================
//            // NEW ORDER
//            // =========================================================
//
//            TYPE_NEW_ORDER -> {
//
//                val orderId =
//                    data["orderId"]
//                        .takeUnless { it.isNullOrBlank() }
//                        ?: data["orderMongoId"].orEmpty()
//
//                val displayId =
//                    data["orderDisplayId"].orEmpty()
//
//                val customerName =
//                    data["customerName"].orEmpty()
//
//                val itemCount =
//                    data["itemCount"].orEmpty()
//
//                val body =
//                    data["body"].orEmpty()
//
//                // -----------------------------------------------------
//                // ORDER ID CHECK
//                // -----------------------------------------------------
//
//                if (orderId.isBlank()) {
//
//                    Log.w(
//                        TAG,
//                        "NEW ORDER HAS NO ORDER ID"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "Accept/Reject notification will NOT be shown"
//                    )
//
//                    super.onMessageReceived(message)
//                    return
//                }
//
//                Log.d(TAG, "----------------------------------------")
//                Log.d(TAG, "NEW ORDER")
//                Log.d(TAG, "orderId = $orderId")
//                Log.d(TAG, "displayId = $displayId")
//                Log.d(TAG, "customerName = $customerName")
//                Log.d(TAG, "itemCount = $itemCount")
//                Log.d(TAG, "body = $body")
//                Log.d(TAG, "----------------------------------------")
//
//                // =====================================================
//                // OVERLAY
//                // =====================================================
//
//                if (AppForeground.isForeground) {
//
//                    Log.d(
//                        TAG,
//                        "APP IS FOREGROUND"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "NewOrderOverlay skipped"
//                    )
//
//                } else {
//
//                    Log.d(
//                        TAG,
//                        "APP IS BACKGROUND"
//                    )
//
//                    val shown =
//                        NewOrderOverlay.show(
//                            context = this,
//                            orderId = orderId,
//                            displayId = displayId,
//                            customerName = customerName,
//                            itemCount = itemCount,
//                            body = body,
//                        )
//
//                    if (shown) {
//
//                        Log.d(
//                            TAG,
//                            "NewOrderOverlay shown"
//                        )
//
//                    } else {
//
//                        Log.d(
//                            TAG,
//                            "NewOrderOverlay unavailable"
//                        )
//
//                        Log.d(
//                            TAG,
//                            "Using ringtone as fallback"
//                        )
//                    }
//                }
//
//                // =====================================================
//                // ACCEPT + REJECT
//                // =====================================================
//                //
//                // IMPORTANT:
//                //
//                // We DO NOT check:
//                //
//                // message.notification != null
//                //
//                // because both notification messages and data-only
//                // messages may reach this service depending on the
//                // FCM payload.
//                //
//                // We only check ORDER ID.
//                //
//                // =====================================================
//
//                val alreadyShown =
//                    hasActionNotificationForOrder(orderId)
//
//                Log.d(TAG, "----------------------------------------")
//                Log.d(TAG, "ORDER ID CHECK")
//                Log.d(TAG, "orderId = $orderId")
//                Log.d(TAG, "alreadyShown = $alreadyShown")
//                Log.d(TAG, "----------------------------------------")
//
//                if (!alreadyShown) {
//
//                    // -------------------------------------------------
//                    // FIRST TIME FOR THIS ORDER ID
//                    // -------------------------------------------------
//
//                    Log.d(
//                        TAG,
//                        "NEW ORDER ID DETECTED"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "SHOWING ACCEPT + REJECT"
//                    )
//
//                    showAndroidNotification(
//                        orderId = orderId,
//                        displayId = displayId,
//                        customerName = customerName,
//                        itemCount = itemCount,
//                        body = body,
//                    )
//
//                    // Save orderId AFTER posting notification.
//                    markActionNotificationShown(
//                        orderId = orderId
//                    )
//
//                    Log.d(
//                        TAG,
//                        "ORDER ID SAVED"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "saved orderId = $orderId"
//                    )
//
//                } else {
//
//                    // -------------------------------------------------
//                    // DUPLICATE FOR SAME ORDER ID
//                    // -------------------------------------------------
//
//                    Log.d(
//                        TAG,
//                        "DUPLICATE ORDER ID"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "orderId = $orderId"
//                    )
//
//                    Log.d(
//                        TAG,
//                        "ACCEPT + REJECT WILL NOT BE SHOWN"
//                    )
//                }
//
//                // =====================================================
//                // FCM INFO
//                // =====================================================
//
//                Log.d(
//                    TAG,
//                    "FCM priority = ${message.priority}"
//                )
//
//                Log.d(
//                    TAG,
//                    "message.notification != null = ${message.notification != null}"
//                )
//
//                // =====================================================
//                // START RINGTONE
//                // =====================================================
//
//                Log.d(
//                    TAG,
//                    "STARTING NEW ORDER RINGTONE"
//                )
//
//                Log.d(
//                    TAG,
//                    "ringtone orderId = $orderId"
//                )
//
//                NewOrderAlarmService.start(
//                    this,
//                    orderId,
//                )
//
//                Log.d(
//                    TAG,
//                    "RINGTONE START REQUEST SENT"
//                )
//            }
//
//            // =========================================================
//            // ORDER CANCELLED / TAKEN / EXPIRED
//            // =========================================================
//
//            TYPE_ORDER_CANCELLED,
//            TYPE_ORDER_TAKEN,
//            TYPE_ORDER_EXPIRED -> {
//
//                Log.d(
//                    TAG,
//                    "ORDER WITHDRAWN"
//                )
//
//                Log.d(
//                    TAG,
//                    "type = $type"
//                )
//
//                Log.d(
//                    TAG,
//                    "Stopping ringtone"
//                )
//
//                NewOrderAlarmService.stop(this)
//
//                Log.d(
//                    TAG,
//                    "Dismissing overlay"
//                )
//
//                NewOrderOverlay.dismiss(this)
//            }
//
//            // =========================================================
//            // UNKNOWN TYPE
//            // =========================================================
//
//            else -> {
//
//                Log.d(
//                    TAG,
//                    "UNKNOWN FCM TYPE"
//                )
//
//                Log.d(
//                    TAG,
//                    "type = $type"
//                )
//            }
//        }
//
//        // =============================================================
//        // SEND MESSAGE TO FLUTTER
//        // =============================================================
//
//        Log.d(
//            TAG,
//            "Forwarding FCM message to Flutter"
//        )
//
//        super.onMessageReceived(message)
//
//        Log.d(
//            TAG,
//            "========================================"
//        )
//    }
//
//    // =================================================================
//    // CHECK ORDER ID
//    // =================================================================
//
//    /**
//     * Checks whether Accept + Reject notification
//     * has already been shown for this orderId.
//     */
//    private fun hasActionNotificationForOrder(
//        orderId: String,
//    ): Boolean {
//
//        val prefs =
//            getSharedPreferences(
//                PREFS_NAME,
//                MODE_PRIVATE,
//            )
//
//        val key =
//            ORDER_KEY_PREFIX + orderId
//
//        val result =
//            prefs.getBoolean(
//                key,
//                false,
//            )
//
//        Log.d(
//            TAG,
//            "SharedPreferences READ"
//        )
//
//        Log.d(
//            TAG,
//            "orderId = $orderId"
//        )
//
//        Log.d(
//            TAG,
//            "key = $key"
//        )
//
//        Log.d(
//            TAG,
//            "result = $result"
//        )
//
//        return result
//    }
//
//    // =================================================================
//    // SAVE ORDER ID
//    // =================================================================
//
//    /**
//     * Saves this orderId so the same order
//     * doesn't get another Accept + Reject notification.
//     */
//    private fun markActionNotificationShown(
//        orderId: String,
//    ) {
//
//        val prefs =
//            getSharedPreferences(
//                PREFS_NAME,
//                MODE_PRIVATE,
//            )
//
//        val key =
//            ORDER_KEY_PREFIX + orderId
//
//        prefs.edit()
//            .putBoolean(
//                key,
//                true,
//            )
//            .apply()
//
//        Log.d(
//            TAG,
//            "SharedPreferences WRITE"
//        )
//
//        Log.d(
//            TAG,
//            "orderId = $orderId"
//        )
//
//        Log.d(
//            TAG,
//            "key = $key"
//        )
//    }
//
//    // =================================================================
//    // SHOW ACCEPT + REJECT NOTIFICATION
//    // =================================================================
//
//    private fun showAndroidNotification(
//        orderId: String,
//        displayId: String,
//        customerName: String,
//        itemCount: String,
//        body: String,
//    ) {
//
//        Log.d(
//            TAG,
//            "========================================"
//        )
//
//        Log.d(
//            TAG,
//            "CREATING CUSTOM ACTION NOTIFICATION"
//        )
//
//        Log.d(
//            TAG,
//            "orderId = $orderId"
//        )
//
//        // =============================================================
//        // ACCEPT INTENT
//        // =============================================================
//
//        val openIntent =
//            Intent(
//                this,
//                MainActivity::class.java,
//            ).apply {
//
//                action =
//                    ACTION_OPEN_ORDER
//
//                flags =
//                    Intent.FLAG_ACTIVITY_NEW_TASK or
//                            Intent.FLAG_ACTIVITY_SINGLE_TOP
//
//                putExtra(
//                    "orderId",
//                    orderId,
//                )
//
//                putExtra(
//                    "notificationAction",
//                    "accept",
//                )
//            }
//
//        val openPendingIntent =
//            PendingIntent.getActivity(
//                this,
//                orderId.hashCode() * 31 + 1,
//                openIntent,
//                PendingIntent.FLAG_UPDATE_CURRENT or
//                        PendingIntent.FLAG_IMMUTABLE,
//            )
//
//        // =============================================================
//        // REJECT INTENT
//        // =============================================================
//
//        val rejectIntent =
//            Intent(
//                this,
//                MainActivity::class.java,
//            ).apply {
//
//                action =
//                    ACTION_REJECT_ORDER
//
//                flags =
//                    Intent.FLAG_ACTIVITY_NEW_TASK or
//                            Intent.FLAG_ACTIVITY_SINGLE_TOP
//
//                putExtra(
//                    "orderId",
//                    orderId,
//                )
//
//                putExtra(
//                    "notificationAction",
//                    "reject",
//                )
//            }
//
//        val rejectPendingIntent =
//            PendingIntent.getActivity(
//                this,
//                orderId.hashCode() * 31 + 2,
//                rejectIntent,
//                PendingIntent.FLAG_UPDATE_CURRENT or
//                        PendingIntent.FLAG_IMMUTABLE,
//            )
//
//        // =============================================================
//        // NOTIFICATION TEXT
//        // =============================================================
//
//        val title =
//            displayId.ifBlank {
//                "New order"
//            }
//
//        val summary =
//            if (customerName.isNotBlank()) {
//                customerName
//            } else {
//                "Customer"
//            }
//
//        val notificationMessage =
//            body.ifBlank {
//                "${itemCount.ifBlank { "1" }} item(s) waiting"
//            }
//
//        // =============================================================
//        // BUILD NOTIFICATION
//        // =============================================================
//
//        val notification =
//            NotificationCompat.Builder(
//                this,
//                NEW_ORDER_CHANNEL_ID,
//            )
//                .setSmallIcon(
//                    android.R.drawable.ic_dialog_info,
//                )
//                .setContentTitle(
//                    title,
//                )
//                .setContentText(
//                    "$summary · $notificationMessage",
//                )
//                .setPriority(
//                    NotificationCompat.PRIORITY_HIGH,
//                )
//                .setCategory(
//                    NotificationCompat.CATEGORY_ALARM,
//                )
//                .setAutoCancel(true)
//                .setContentIntent(
//                    openPendingIntent,
//                )
//
//                // -----------------------------------------------------
//                // ACCEPT
//                // -----------------------------------------------------
//
//                .addAction(
//                    android.R.drawable.ic_menu_add,
//                    "Accept",
//                    openPendingIntent,
//                )
//
//                // -----------------------------------------------------
//                // REJECT
//                // -----------------------------------------------------
//
//                .addAction(
//                    android.R.drawable.ic_delete,
//                    "Reject",
//                    rejectPendingIntent,
//                )
//
//                .build()
//
//        // =============================================================
//        // POST NOTIFICATION
//        // =============================================================
//
//        NotificationManagerCompat
//            .from(this)
//            .notify(
//                orderId.hashCode(),
//                notification,
//            )
//
//        Log.d(
//            TAG,
//            "CUSTOM NOTIFICATION POSTED SUCCESSFULLY"
//        )
//
//        Log.d(
//            TAG,
//            "orderId = $orderId"
//        )
//
//        Log.d(
//            TAG,
//            "Accept = YES"
//        )
//
//        Log.d(
//            TAG,
//            "Reject = YES"
//        )
//
//        Log.d(
//            TAG,
//            "========================================"
//        )
//    }
//
//    // =================================================================
//    // CONSTANTS
//    // =================================================================
//
//    private companion object {
//
//        const val TAG =
//            "FCM"
//
//        const val TYPE_NEW_ORDER =
//            "new_order"
//
//        const val TYPE_ORDER_CANCELLED =
//            "order_cancelled"
//
//        const val TYPE_ORDER_TAKEN =
//            "order_taken"
//
//        const val TYPE_ORDER_EXPIRED =
//            "order_expired"
//
//        const val ACTION_OPEN_ORDER =
//            "com.versapack.seller.OPEN_ORDER"
//
//        const val ACTION_REJECT_ORDER =
//            "com.versapack.seller.REJECT_ORDER"
//
//        // =============================================================
//        // NOTIFICATION CHANNEL
//        // =============================================================
//
//        const val NEW_ORDER_CHANNEL_ID =
//            "new_order_channel"
//
//        // =============================================================
//        // SHARED PREFERENCES
//        // =============================================================
//
//        const val PREFS_NAME =
//            "seller_notification_preferences"
//
//        const val ORDER_KEY_PREFIX =
//            "action_notification_order_"
//    }
//}
//
//
package com.versapack.seller

import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Native Firebase Messaging Service.
 *
 * NEW ORDER FLOW:
 *
 * New orderId:
 *   -> Heads-Up notification
 *   -> Accept + Reject buttons
 *   -> Ringtone starts
 *   -> orderId saved in SharedPreferences
 *
 * Same orderId again:
 *   -> No duplicate Accept + Reject notification
 *   -> Ringtone behaviour remains
 *
 * Different/new orderId:
 *   -> Accept + Reject again
 */
class SellerMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {

        val data = message.data
        val type = data["type"].orEmpty()

        Log.d(TAG, "========================================")
        Log.d(TAG, "FCM MESSAGE RECEIVED")
        Log.d(TAG, "type = $type")
        Log.d(TAG, "notification payload = ${message.notification}")
        Log.d(TAG, "data = $data")

        when (type) {

            // =========================================================
            // NEW ORDER
            // =========================================================

            TYPE_NEW_ORDER -> {

                val orderId =
                    data["orderId"]
                        .takeUnless { it.isNullOrBlank() }
                        ?: data["orderMongoId"].orEmpty()

                val displayId =
                    data["orderDisplayId"].orEmpty()

                val customerName =
                    data["customerName"].orEmpty()

                val itemCount =
                    data["itemCount"].orEmpty()

                val body =
                    data["body"].orEmpty()

                val address =
                    data["address"].orEmpty()

                val itemsList =
                    data["itemsList"].orEmpty()

                val total =
                    data["total"].orEmpty()

                // -----------------------------------------------------
                // ORDER ID CHECK
                // -----------------------------------------------------

                if (orderId.isBlank()) {

                    Log.w(
                        TAG,
                        "NEW ORDER HAS NO ORDER ID"
                    )

                    Log.d(
                        TAG,
                        "Accept/Reject notification will NOT be shown"
                    )

                    super.onMessageReceived(message)
                    return
                }

                Log.d(TAG, "----------------------------------------")
                Log.d(TAG, "NEW ORDER")
                Log.d(TAG, "orderId = $orderId")
                Log.d(TAG, "displayId = $displayId")
                Log.d(TAG, "customerName = $customerName")
                Log.d(TAG, "itemCount = $itemCount")
                Log.d(TAG, "address = $address")
                Log.d(TAG, "itemsList = $itemsList")
                Log.d(TAG, "total = $total")
                Log.d(TAG, "body = $body")
                Log.d(TAG, "----------------------------------------")

                // =====================================================
                // OVERLAY
                // =====================================================

                val shown =
                    NewOrderOverlay.show(
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

                // An overlay cannot draw above the lock screen, so a locked
                // phone also gets the full-screen-intent notification: that is
                // what wakes the screen and puts the order up over the keyguard.
                val locked =
                    (getSystemService(KEYGUARD_SERVICE) as KeyguardManager)
                        .isKeyguardLocked

                if (shown && !locked) {
                    Log.d(TAG, "NewOrderOverlay shown - skipping tray notification for new_order")
                } else {
                    Log.d(TAG, "overlay shown=$shown locked=$locked - posting full-screen notification")

                    val alreadyShown = hasActionNotificationForOrder(orderId)
                    if (!alreadyShown) {
                        showAndroidNotification(
                            orderId = orderId,
                            displayId = displayId,
                            customerName = customerName,
                            itemCount = itemCount,
                            body = body,
                        )
                        markActionNotificationShown(orderId = orderId)
                    }
                }

                // =====================================================
                // FCM INFO
                // =====================================================

                Log.d(
                    TAG,
                    "FCM priority = ${message.priority}"
                )

                Log.d(
                    TAG,
                    "message.notification != null = " +
                            "${message.notification != null}"
                )

                // =====================================================
                // START RINGTONE
                // =====================================================

                Log.d(
                    TAG,
                    "STARTING NEW ORDER RINGTONE"
                )

                Log.d(
                    TAG,
                    "ringtone orderId = $orderId"
                )

                NewOrderAlarmService.start(
                    this,
                    orderId,
                )

                Log.d(
                    TAG,
                    "RINGTONE START REQUEST SENT"
                )
            }

            // =========================================================
            // ORDER CANCELLED / TAKEN / EXPIRED
            // =========================================================

            TYPE_ORDER_CANCELLED,
            TYPE_ORDER_TAKEN,
            TYPE_ORDER_EXPIRED -> {

                Log.d(
                    TAG,
                    "ORDER WITHDRAWN"
                )

                Log.d(
                    TAG,
                    "type = $type"
                )

                Log.d(
                    TAG,
                    "Stopping ringtone"
                )

                NewOrderAlarmService.stop(this)

                Log.d(
                    TAG,
                    "Dismissing overlay"
                )

                NewOrderOverlay.dismiss(this)

                val withdrawnId =
                    data["orderId"]
                        .takeUnless { it.isNullOrBlank() }
                        ?: data["orderMongoId"].orEmpty()
                if (withdrawnId.isNotBlank()) {
                    NotificationManagerCompat.from(this).cancel(withdrawnId.hashCode())
                }
            }

            // =========================================================
            // UNKNOWN TYPE
            // =========================================================

            else -> {

                Log.d(
                    TAG,
                    "UNKNOWN FCM TYPE"
                )

                Log.d(
                    TAG,
                    "type = $type"
                )
            }
        }

        // =============================================================
        // SEND MESSAGE TO FLUTTER
        // =============================================================

        Log.d(
            TAG,
            "Forwarding FCM message to Flutter"
        )

        super.onMessageReceived(message)

        Log.d(
            TAG,
            "========================================"
        )
    }

    // =================================================================
    // NOTIFICATION CHANNEL
    // =================================================================

    /**
     * Creates HIGH importance notification channel.
     *
     * HIGH importance allows Android to show the notification
     * as a Heads-Up popup at the top of the screen.
     */
    private fun createNotificationChannel() {

        Log.d(
            TAG,
            "Creating/checking notification channel"
        )

        val channel =
            NotificationChannel(
                NEW_ORDER_CHANNEL_ID,
                "New Orders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {

                description =
                    "New order notifications"

                enableVibration(true)
            }

        val notificationManager =
            getSystemService(
                NotificationManager::class.java
            )

        notificationManager.createNotificationChannel(
            channel
        )

        Log.d(
            TAG,
            "Notification channel ready"
        )

        Log.d(
            TAG,
            "channelId = $NEW_ORDER_CHANNEL_ID"
        )

        Log.d(
            TAG,
            "importance = HIGH"
        )
    }

    // =================================================================
    // CHECK ORDER ID
    // =================================================================

    /**
     * Checks whether Accept + Reject notification
     * was already shown for this orderId.
     */
    private fun hasActionNotificationForOrder(
        orderId: String,
    ): Boolean {

        val prefs =
            getSharedPreferences(
                PREFS_NAME,
                MODE_PRIVATE,
            )

        val key =
            ORDER_KEY_PREFIX + orderId

        val result =
            prefs.getBoolean(
                key,
                false,
            )

        Log.d(
            TAG,
            "SharedPreferences READ"
        )

        Log.d(
            TAG,
            "orderId = $orderId"
        )

        Log.d(
            TAG,
            "key = $key"
        )

        Log.d(
            TAG,
            "result = $result"
        )

        return result
    }

    // =================================================================
    // SAVE ORDER ID
    // =================================================================

    /**
     * Saves orderId so the same order does not
     * receive another Accept + Reject notification.
     */
    private fun markActionNotificationShown(
        orderId: String,
    ) {

        val prefs =
            getSharedPreferences(
                PREFS_NAME,
                MODE_PRIVATE,
            )

        val key =
            ORDER_KEY_PREFIX + orderId

        prefs.edit()
            .putBoolean(
                key,
                true,
            )
            .apply()

        Log.d(
            TAG,
            "SharedPreferences WRITE"
        )

        Log.d(
            TAG,
            "orderId = $orderId"
        )

        Log.d(
            TAG,
            "key = $key"
        )
    }

    // =================================================================
    // SHOW ANDROID NOTIFICATION
    // =================================================================

    private fun showAndroidNotification(
        orderId: String,
        displayId: String,
        customerName: String,
        itemCount: String,
        body: String,
    ) {

        Log.d(
            TAG,
            "========================================"
        )

        Log.d(
            TAG,
            "CREATING CUSTOM ACTION NOTIFICATION"
        )

        Log.d(
            TAG,
            "orderId = $orderId"
        )

        // -------------------------------------------------------------
        // CREATE HIGH IMPORTANCE CHANNEL
        // -------------------------------------------------------------

        createNotificationChannel()

        // =============================================================
        // ACCEPT INTENT
        // =============================================================

        val openIntent =
            Intent(
                this,
                MainActivity::class.java,
            ).apply {

                action =
                    ACTION_OPEN_ORDER

                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP

                putExtra(
                    "orderId",
                    orderId,
                )

                putExtra(
                    "notificationAction",
                    "accept",
                )
            }

        val openPendingIntent =
            PendingIntent.getActivity(
                this,
                orderId.hashCode() * 31 + 1,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
            )

        // =============================================================
        // REJECT INTENT
        // =============================================================

        val rejectIntent =
            Intent(
                this,
                MainActivity::class.java,
            ).apply {

                action =
                    ACTION_REJECT_ORDER

                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP

                putExtra(
                    "orderId",
                    orderId,
                )

                putExtra(
                    "notificationAction",
                    "reject",
                )
            }

        val rejectPendingIntent =
            PendingIntent.getActivity(
                this,
                orderId.hashCode() * 31 + 2,
                rejectIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
            )

        // =============================================================
        // VIEW INTENT (tap / full-screen) — opens the order, decides nothing
        // =============================================================

        val viewIntent =
            Intent(
                this,
                MainActivity::class.java,
            ).apply {

                action =
                    ACTION_VIEW_ORDER

                flags =
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP

                putExtra(
                    "orderId",
                    orderId,
                )
            }

        val viewPendingIntent =
            PendingIntent.getActivity(
                this,
                orderId.hashCode() * 31 + 3,
                viewIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                        PendingIntent.FLAG_IMMUTABLE,
            )

        // =============================================================
        // NOTIFICATION TEXT
        // =============================================================

        val title =
            "🔔 New order " + displayId.ifBlank { "" }

        val summary =
            if (customerName.isNotBlank()) {
                customerName
            } else {
                "Customer"
            }

        val notificationMessage =
            body.ifBlank {
                "${itemCount.ifBlank { "1" }} item(s) waiting"
            }

        // =============================================================
        // BUILD NOTIFICATION
        // =============================================================

        val notification =
            NotificationCompat.Builder(
                this,
                NEW_ORDER_CHANNEL_ID,
            )
                .setSmallIcon(
                    android.R.drawable.ic_dialog_info,
                )
                .setContentTitle(
                    title,
                )
                .setContentText(
                    "$summary · $notificationMessage",
                )

                // HIGH = Heads-Up popup
                .setPriority(
                    NotificationCompat.PRIORITY_HIGH,
                )

                // CALL + full-screen intent: the same treatment as an incoming
                // call — on a locked or idle phone the app is launched over the
                // lock screen instead of a small tray entry being posted.
                .setCategory(
                    NotificationCompat.CATEGORY_CALL,
                )

                .setVisibility(
                    NotificationCompat.VISIBILITY_PUBLIC,
                )

                .setOngoing(true)

                .setAutoCancel(true)

                .setContentIntent(
                    viewPendingIntent,
                )

                .setFullScreenIntent(
                    viewPendingIntent,
                    true,
                )

                // -----------------------------------------------------
                // ACCEPT
                // -----------------------------------------------------

                .addAction(
                    android.R.drawable.ic_menu_add,
                    "Accept",
                    openPendingIntent,
                )

                // -----------------------------------------------------
                // REJECT
                // -----------------------------------------------------

                .addAction(
                    android.R.drawable.ic_delete,
                    "Reject",
                    rejectPendingIntent,
                )

                .build()

        // =============================================================
        // POST NOTIFICATION
        // =============================================================

        NotificationManagerCompat
            .from(this)
            .notify(
                orderId.hashCode(),
                notification,
            )

        Log.d(
            TAG,
            "CUSTOM NOTIFICATION POSTED"
        )

        Log.d(
            TAG,
            "orderId = $orderId"
        )

        Log.d(
            TAG,
            "Accept = YES"
        )

        Log.d(
            TAG,
            "Reject = YES"
        )

        Log.d(
            TAG,
            "Heads-Up = HIGH PRIORITY"
        )

        Log.d(
            TAG,
            "========================================"
        )
    }

    // =================================================================
    // CONSTANTS
    // =================================================================

    private companion object {

        const val TAG =
            "FCM"

        const val TYPE_NEW_ORDER =
            "new_order"

        const val TYPE_ORDER_CANCELLED =
            "order_cancelled"

        const val TYPE_ORDER_TAKEN =
            "order_taken"

        const val TYPE_ORDER_EXPIRED =
            "order_expired"

        const val ACTION_OPEN_ORDER =
            "com.versapack.seller.OPEN_ORDER"

        const val ACTION_REJECT_ORDER =
            "com.versapack.seller.REJECT_ORDER"

        const val ACTION_VIEW_ORDER =
            "com.versapack.seller.VIEW_ORDER"

        // =============================================================
        // NOTIFICATION CHANNEL
        // =============================================================

        const val NEW_ORDER_CHANNEL_ID =
            "new_order_channel"

        // =============================================================
        // SHARED PREFERENCES
        // =============================================================

        const val PREFS_NAME =
            "seller_notification_preferences"

        const val ORDER_KEY_PREFIX =
            "action_notification_order_"
    }
}

