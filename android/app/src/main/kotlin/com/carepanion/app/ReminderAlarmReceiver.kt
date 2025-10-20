package com.carepanion.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat

class ReminderAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "carepanion_reminders"
        const val NOTIF_ID = 1001
        const val STICKY_BASE_ID = 2000
    }

    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra("payload")
        val id = intent.getIntExtra("id", -1)
        if (intent.action == "com.carepanion.app.ACTION_DISMISS") {
            try {
                if (id >= 0) {
                    val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    nm.cancel(2000 + id)
                    AlarmScheduler.cancel(context, id)
                    AlarmStore.remove(context, id)
                }
            } catch (e: Exception) {
                Log.w("ReminderAlarmReceiver", "dismiss action failed", e)
            }
            return
        }
        Log.i("ReminderAlarmReceiver", "onReceive payload=$payload")
        if (id != -1) {
            try { AlarmStore.remove(context, id) } catch (_: Exception) {}
        }

        // Extract friendly title/body from payload for better notification text
        var notifTitle = "Task Reminder"
        var notifBody = "Tap to view your reminder"
        try {
            if (payload != null) {
                val obj = org.json.JSONObject(payload)
                val t = obj.optString("task_title")
                val n = obj.optString("task_note")
                if (!t.isNullOrBlank()) notifTitle = t
                if (!n.isNullOrBlank()) notifBody = n else notifBody = "It's time to do this task."
            }
        } catch (_: Exception) { }

        // Build intent to launch the full-screen activity
        val fullScreenIntent = Intent(context, ReminderFullScreenActivity::class.java).apply {
            putExtra("reminder_payload", payload)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        // PendingIntent for the full-screen intent
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags = flags or PendingIntent.FLAG_IMMUTABLE
        val fullScreenPendingIntent = PendingIntent.getActivity(context, 0, fullScreenIntent, flags)

        // Ensure notification channel exists (Android O+)
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Task Reminders",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Reminder notifications for due tasks"
                vibrationPattern = longArrayOf(0, 300, 200, 300)
                enableVibration(true)
            }
            nm.createNotificationChannel(channel)
        }

        val notif = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle(notifTitle)
            .setContentText(notifBody)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            // Ensure tapping the notification opens the app even if full-screen isn't shown
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        // Post the notification (this will also trigger the full-screen intent on supported devices)
        nm.notify(NOTIF_ID + (System.currentTimeMillis() % 1000).toInt(), notif)
        Log.i("ReminderAlarmReceiver", "Posted full-screen notification for payload")

        // Additionally, post a regular sticky notification that remains visible in the shade.
        // Some OEMs auto-clear the full-screen entry; this ensures a persistent banner remains.
        val mainIntent = Intent(context, MainActivity::class.java).apply {
            putExtra("reminder_payload", payload)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val mainPendingIntent = PendingIntent.getActivity(
            context,
            (id.takeIf { it >= 0 } ?: 0) + 1,
            mainIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        // Provide an explicit "Dismiss" action to cancel the notification and any pending alarm
        val dismissIntent = Intent(context, ReminderAlarmReceiver::class.java).apply {
            action = "com.carepanion.app.ACTION_DISMISS"
            putExtra("id", id)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            (id.takeIf { it >= 0 } ?: 0) + 2,
            dismissIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            else
                PendingIntent.FLAG_UPDATE_CURRENT
        )

        val sticky = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(notifTitle)
            .setContentText(notifBody)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notifBody))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setOnlyAlertOnce(true)
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(mainPendingIntent)
            .addAction(0, "Dismiss", dismissPendingIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()

        val stickyId = if (id >= 0) STICKY_BASE_ID + id else STICKY_BASE_ID
        nm.notify(stickyId, sticky)
        Log.i("ReminderAlarmReceiver", "Posted sticky reminder notification id=$stickyId")
    }
}
