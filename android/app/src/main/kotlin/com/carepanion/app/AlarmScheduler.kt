package com.carepanion.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

object AlarmScheduler {
    fun scheduleExact(context: Context, triggerAtMillis: Long, requestCode: Int, payload: String?) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
        intent.putExtra("payload", payload)
        // Use UPDATE_CURRENT so repeated scheduling with same id updates the existing PendingIntent
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Prefer immutable where we don't need to modify the PendingIntent
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val pi = PendingIntent.getBroadcast(context, requestCode, intent, flags)
        Log.i("AlarmScheduler", "scheduleExact id=$requestCode at=$triggerAtMillis payload=$payload flags=$flags")
        // From Android M (23) onwards, use setExactAndAllowWhileIdle to bypass Doze deferral
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        } else {
            am.setExact(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    fun cancel(context: Context, requestCode: Int) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, ReminderAlarmReceiver::class.java)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        val pi = PendingIntent.getBroadcast(context, requestCode, intent, flags)
        Log.i("AlarmScheduler", "cancel id=$requestCode flags=$flags")
        am.cancel(pi)
    }
}
