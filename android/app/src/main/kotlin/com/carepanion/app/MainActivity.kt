package com.carepanion.app

import android.content.Intent
import android.content.Context
import android.os.Bundle
import android.util.Log
import android.os.Build
import android.provider.Settings
import android.net.Uri
import org.json.JSONObject
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val CHANNEL = "carepanion.reminder"

	// Queue payloads that arrive before the Flutter engine is ready
	private val pendingPayloads: MutableList<String> = mutableListOf()

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		// Install method handler for scheduling/cancelling alarms
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "scheduleAlarm" -> {
                        val epoch = call.argument<Long>("when") ?: 0L
                        val id = call.argument<Int>("id") ?: 0
                        val payloadArg = call.argument<String>("payload")
                        AlarmScheduler.scheduleExact(this.applicationContext, epoch, id, payloadArg)
                        result.success(null)
                    }
                    "cancelAlarm" -> {
                        val id = call.argument<Int>("id") ?: 0
                        AlarmScheduler.cancel(this.applicationContext, id)
                        result.success(null)
                    }
                    "requestExactAlarmPermissionIfNeeded" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            try {
                                val am = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
                                val can = am.canScheduleExactAlarms()
                                if (!can) {
                                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                                        data = Uri.parse("package:" + packageName)
                                    }
                                    startActivity(intent)
                                }
                                result.success(can)
                            } catch (e: Exception) {
                                Log.w("MainActivity", "requestExactAlarmPermissionIfNeeded failed", e)
                                result.error("exact_alarm_settings_error", e.localizedMessage, null)
                            }
                        } else {
                            result.success(true)
                        }
                    }
                    "popSavedReminder" -> {
                        // Read and clear the saved reminder payload from SharedPreferences
                        try {
                            val prefs = this.getSharedPreferences("carepanion_prefs", Context.MODE_PRIVATE)
                            val saved = prefs.getString("saved_reminder", null)
							if (saved != null) {
								prefs.edit().remove("saved_reminder").apply()
							}
							result.success(saved)
						} catch (e: Exception) {
							result.error("prefs_error", e.localizedMessage, null)
						}
					}
					else -> result.notImplemented()
				}
			} catch (e: Exception) {
				Log.e("MainActivity", "Alarm method failed", e)
				result.error("alarm_error", e.localizedMessage, null)
			}
		}

		// Forward any reminder payload contained in the launch intent; if the engine/messenger
		// isn't ready yet, queue the payload and flush later.
		intent?.getStringExtra("reminder_payload")?.let { payload ->
			Log.i("MainActivity", "launch intent has reminder_payload=$payload")
			forwardOrQueuePayload(flutterEngine, payload)
		}

		// Flush any pending payloads now that the engine is configured
		flushPendingPayloads(flutterEngine)
	}

	override fun onNewIntent(intent: Intent) {
		super.onNewIntent(intent)
		// When activity receives a new intent, forward payload if present
		intent.getStringExtra("reminder_payload")?.let { payload ->
			// If flutterEngine is available, forward; otherwise queue
			forwardOrQueuePayload(flutterEngine, payload)
		}
	}

	private fun forwardOrQueuePayload(flutterEngine: FlutterEngine?, payload: String) {
		try {
			val taskId = try { JSONObject(payload).optString("task_id") } catch (e: Exception) { "" }
			Log.i("MainActivity", "forwardOrQueuePayload payload=$payload taskId=$taskId")
			if (flutterEngine?.dartExecutor?.binaryMessenger != null) {
				val messenger = flutterEngine.dartExecutor.binaryMessenger
				if (!taskId.isNullOrEmpty()) {
					MethodChannel(messenger, CHANNEL).invokeMethod("showReminder", taskId)
				} else {
					MethodChannel(messenger, CHANNEL).invokeMethod("showReminder", payload)
				}
			} else {
				// Engine not ready — queue payload
				pendingPayloads.add(payload)
				Log.i("MainActivity", "engine not ready, queued payload. pendingCount=${pendingPayloads.size}")
			}
		} catch (e: Exception) {
			Log.e("MainActivity", "Failed to forward reminder payload", e)
			// On any parsing error, queue as raw
			pendingPayloads.add(payload)
		}
	}

	private fun flushPendingPayloads(flutterEngine: FlutterEngine) {
		if (pendingPayloads.isEmpty()) return
		val messenger = flutterEngine.dartExecutor.binaryMessenger
		val channel = MethodChannel(messenger, CHANNEL)
		val iter = pendingPayloads.iterator()
		while (iter.hasNext()) {
			val p = iter.next()
			try {
				val taskId = try { JSONObject(p).optString("task_id") } catch (e: Exception) { "" }
				Log.i("MainActivity", "flushing pending payload p=$p taskId=$taskId")
				if (!taskId.isNullOrEmpty()) {
					channel.invokeMethod("showReminder", taskId)
				} else {
					channel.invokeMethod("showReminder", p)
				}
				iter.remove()
			} catch (e: Exception) {
				Log.w("MainActivity", "Failed to flush pending payload, keeping it queued", e)
			}
		}
	}
}
