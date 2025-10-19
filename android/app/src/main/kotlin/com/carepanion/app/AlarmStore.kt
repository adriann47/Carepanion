package com.carepanion.app

import android.content.Context
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

data class StoredAlarm(val id: Int, val whenUtc: Long, val payload: String?)

object AlarmStore {
    private const val PREFS = "carepanion_prefs"
    private const val KEY = "scheduled_alarms"

    fun add(context: Context, id: Int, whenUtc: Long, payload: String?) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString(KEY, "[]"))
            // Remove any existing with same id
            val filtered = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optInt("id") != id) filtered.put(obj)
            }
            val obj = JSONObject()
            obj.put("id", id)
            obj.put("whenUtc", whenUtc)
            if (payload != null) obj.put("payload", payload)
            filtered.put(obj)
            prefs.edit().putString(KEY, filtered.toString()).apply()
            Log.i("AlarmStore", "saved alarm id=$id when=$whenUtc")
        } catch (e: Exception) {
            Log.w("AlarmStore", "failed saving alarm", e)
        }
    }

    fun remove(context: Context, id: Int) {
        try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString(KEY, "[]"))
            val filtered = JSONArray()
            for (i in 0 until arr.length()) {
                val obj = arr.getJSONObject(i)
                if (obj.optInt("id") != id) filtered.put(obj)
            }
            prefs.edit().putString(KEY, filtered.toString()).apply()
            Log.i("AlarmStore", "removed alarm id=$id")
        } catch (e: Exception) {
            Log.w("AlarmStore", "failed removing alarm", e)
        }
    }

    fun list(context: Context): List<StoredAlarm> {
        return try {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val arr = JSONArray(prefs.getString(KEY, "[]"))
            buildList {
                for (i in 0 until arr.length()) {
                    val obj = arr.getJSONObject(i)
                    add(
                        StoredAlarm(
                            id = obj.optInt("id"),
                            whenUtc = obj.optLong("whenUtc"),
                            payload = if (obj.has("payload")) obj.optString("payload") else null
                        )
                    )
                }
            }
        } catch (e: Exception) {
            Log.w("AlarmStore", "failed listing alarms", e)
            emptyList()
        }
    }
}
