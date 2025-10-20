package com.carepanion.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.content.pm.ServiceInfo
import androidx.core.app.NotificationCompat
import kotlin.jvm.Volatile

class ReminderForegroundService : Service() {

	companion object {
		private const val CHANNEL_ID = "carepanion_background_sync"
		private const val CHANNEL_NAME = "Reminder Background Sync"
		private const val NOTIFICATION_ID = 7042
		private const val EXTRA_STOP = "stop_service"

		@Volatile
		private var running: Boolean = false

		@JvmStatic
		fun isRunning(): Boolean = running

		@JvmStatic
		fun buildStopIntent(context: Context): Intent =
			Intent(context, ReminderForegroundService::class.java).apply {
				putExtra(EXTRA_STOP, true)
			}
	}

	override fun onCreate() {
		super.onCreate()
		running = true
		createChannel()
		startAsForeground()
	}

	override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
		val shouldStop = intent?.getBooleanExtra(EXTRA_STOP, false) ?: false
		if (shouldStop) {
			stopForegroundCompat()
			stopSelf()
			return START_NOT_STICKY
		}
		return START_STICKY
	}

	override fun onDestroy() {
		super.onDestroy()
		running = false
		stopForegroundCompat()
	}

	override fun onBind(intent: Intent?): IBinder? = null

	private fun buildNotification(): Notification {
		val openIntent = Intent(this, MainActivity::class.java).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
		}
		val pending = PendingIntent.getActivity(
			this,
			0,
			openIntent,
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
				PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
			else
				PendingIntent.FLAG_UPDATE_CURRENT
		)

		return NotificationCompat.Builder(this, CHANNEL_ID)
			.setSmallIcon(android.R.drawable.ic_dialog_info)
			.setContentTitle("CarePanion reminders active")
			.setContentText("Keeping task and guardian alerts running in the background.")
			.setOngoing(true)
			.setPriority(NotificationCompat.PRIORITY_LOW)
			.setContentIntent(pending)
			.setShowWhen(false)
			.build()
	}

	private fun createChannel() {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
			val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
			val channel = NotificationChannel(
				CHANNEL_ID,
				CHANNEL_NAME,
				NotificationManager.IMPORTANCE_LOW
			).apply {
				setShowBadge(false)
				setSound(null, null)
				enableVibration(false)
				description = "Ensures reminders stay active while the app is in background."
			}
			nm.createNotificationChannel(channel)
		}
	}

	private fun startAsForeground() {
		val notification = buildNotification()
		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
				startForeground(
					NOTIFICATION_ID,
					notification,
					ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
				)
			} else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
				startForeground(
					NOTIFICATION_ID,
					notification,
					ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
				)
			} else {
				startForeground(NOTIFICATION_ID, notification)
			}
		} catch (_: Exception) {
			startForeground(NOTIFICATION_ID, notification)
		}
	}

	private fun stopForegroundCompat() {
		try {
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
				stopForeground(STOP_FOREGROUND_REMOVE)
			} else {
				@Suppress("DEPRECATION")
				stopForeground(true)
			}
		} catch (_: Exception) {
		}
	}
}
