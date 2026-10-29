//package com.example.quick_commerce_seller
package com.versapack.seller
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.example.quick_commerce_seller.R

/**
 * Plays the new-order ringtone on a loop until the seller answers the order.
 *
 * A foreground service rather than a player inside the app, because the whole
 * point is to ring while the seller is not looking at the app. The Dart
 * isolate is not running then, so an in-app player cannot start, and a
 * notification channel sound plays exactly once — which is why the alert used
 * to stop after a single pass.
 *
 * This is the single owner of the ringtone in every app state. Nothing else
 * should play [R.raw.neworder]; two owners is how you get overlapping copies.
 */
class NewOrderAlarmService : Service() {

    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stop()
                return START_NOT_STICKY
            }
        }

        val orderId = intent?.getStringExtra(EXTRA_ORDER_ID).orEmpty()

        // The backend sends every new-order alert twice (a notification leg and
        // a data-only leg), and a redelivery can arrive later still. Restarting
        // here would clip the ringtone back to zero on each one.
        if (ringingOrderId == orderId && player != null) {
            Log.d(TAG, "already ringing for $orderId — ignoring duplicate")
            return START_STICKY
        }

        ringingOrderId = orderId
        startForegroundNotification(orderId)
        startLooping()
        Log.d(TAG, "ringtone started for $orderId")
        return START_STICKY
    }

    private fun startLooping() {
        // Any existing player is torn down first so a second order cannot layer
        // a second copy over the first.
        player?.runCatching { stop() }
        player?.release()

        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            val fd = resources.openRawResourceFd(R.raw.neworder) ?: return
            fd.use { setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            // The loop, and the reason this service exists.
            isLooping = true
            setOnErrorListener { _, what, extra ->
                Log.e(TAG, "player error what=$what extra=$extra")
                stop()
                true
            }
            prepare()
            start()
        }
    }

    private fun startForegroundNotification(orderId: String) {
        createChannel()

        val open = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra("orderId", orderId)
        }
        val pending = PendingIntent.getActivity(
            this,
            0,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification: Notification = Notification.Builder(this, ALARM_CHANNEL_ID)
            .setContentTitle("New order waiting")
            .setContentText("Tap to accept or reject")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    /**
     * Silent by design. The ringtone comes from this service's own player, so a
     * channel sound here would play a second, overlapping copy.
     */
    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(ALARM_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            ALARM_CHANNEL_ID,
            "Order alert in progress",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while the new-order alert is sounding"
            setSound(null, null)
            enableVibration(false)
        }
        manager.createNotificationChannel(channel)
    }

    private fun stop() {
        player?.runCatching { if (isPlaying) stop() }
        player?.release()
        player = null
        ringingOrderId = null
        Log.d(TAG, "ringtone stopped")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        player?.runCatching { if (isPlaying) stop() }
        player?.release()
        player = null
        ringingOrderId = null
        super.onDestroy()
    }

    companion object {
        private const val TAG = "NEW_ORDER_ALARM"
        private const val ALARM_CHANNEL_ID = "new_order_alarm_channel"
        private const val NOTIFICATION_ID = 90210
        private const val EXTRA_ORDER_ID = "orderId"
        private const val ACTION_STOP = "com.quick.seller.STOP_ALARM"

        /** The order currently ringing, so a duplicate push does not restart it. */
        @Volatile
        var ringingOrderId: String? = null
            private set

        fun start(context: Context, orderId: String) {
            val intent = Intent(context, NewOrderAlarmService::class.java)
                .putExtra(EXTRA_ORDER_ID, orderId)
            // startForegroundService is required from the background on O+; the
            // service calls startForeground immediately in onStartCommand.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            if (ringingOrderId == null) return
            val intent = Intent(context, NewOrderAlarmService::class.java)
                .setAction(ACTION_STOP)
            runCatching { context.startService(intent) }
        }
    }
}
