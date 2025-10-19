package com.carepanion.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            Log.i("BootReceiver", "Device booted; rescheduling alarms")
            // Reschedule any future alarms; drop those in the past
            val now = System.currentTimeMillis()
            for (alarm in AlarmStore.list(context)) {
                if (alarm.whenUtc > now) {
                    AlarmScheduler.scheduleExact(context, alarm.whenUtc, alarm.id, alarm.payload)
                } else {
                    Log.i("BootReceiver", "Skipping past alarm id=${alarm.id}")
                }
            }
        }
    }
}
