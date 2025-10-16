package com.carepanion.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.VibrationEffect
import android.os.Vibrator
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.os.Handler
import android.os.Looper
import java.util.Locale
import android.view.WindowManager
import android.util.Log

class ReminderFullScreenActivity : Activity() {
    private var tts: TextToSpeech? = null
    private var forwarded = false
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Turn screen on and show when locked
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

    // Accept either "reminder_payload" or legacy "payload" for compatibility
    val payload = intent.getStringExtra("reminder_payload") ?: intent.getStringExtra("payload")
    Log.i("ReminderFullScreenActivity", "onCreate payload=$payload")

        // Vibrate briefly to alert the user (respect device capabilities)
        try {
            val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
            vibrator?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    it.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE))
                } else {
                    @Suppress("DEPRECATION")
                    it.vibrate(400)
                }
            }
            Log.i("ReminderFullScreenActivity", "vibration attempted")
        } catch (_: Exception) {
            // Best-effort vibrate; ignore failures
            Log.w("ReminderFullScreenActivity", "vibration failed or not available")
        }

        // Best-effort native TextToSpeech fallback: speak a short reminder
        try {
            // Parse a friendly text from payload (try task_title then fall back)
            var speakText: String? = null
            try {
                if (payload != null) {
                    val obj = org.json.JSONObject(payload)
                    if (obj.has("task_title")) {
                        speakText = obj.optString("task_title")
                    } else if (obj.has("task_id")) {
                        speakText = "You have a reminder"
                    }
                }
            } catch (e: Exception) {
                // ignore JSON parse issues
            }

            tts = TextToSpeech(this.applicationContext) { status ->
                try {
                    if (status == TextToSpeech.SUCCESS) {
                        tts?.language = Locale.getDefault() ?: Locale.US
                        val toSpeak = speakText ?: "You have a reminder"
                        // queue the speech; use QUEUE_FLUSH so it plays immediately
                        tts?.setOnUtteranceProgressListener(object: UtteranceProgressListener() {
                            override fun onStart(utteranceId: String?) { }
                            override fun onDone(utteranceId: String?) {
                                runOnUiThread {
                                    try {
                                        tts?.shutdown()
                                    } catch (_: Exception) {}
                                    forwardToMain(payload)
                                }
                            }
                            @Deprecated("Deprecated in Java")
                            override fun onError(utteranceId: String?) {
                                runOnUiThread { forwardToMain(payload) }
                            }
                        })
                        tts?.speak(toSpeak, TextToSpeech.QUEUE_FLUSH, null, "reminder_tts_id")
                        Log.i("ReminderFullScreenActivity", "native tts spoken: $toSpeak")
                    } else {
                        Log.w("ReminderFullScreenActivity", "TTS init failed status=$status")
                        // If TTS failed to init, just forward immediately
                        forwardToMain(payload)
                    }
                } catch (e: Exception) {
                    Log.w("ReminderFullScreenActivity", "TTS speak failed", e)
                    forwardToMain(payload)
                }
            }
        } catch (e: Exception) {
            Log.w("ReminderFullScreenActivity", "native TTS setup failed", e)
            forwardToMain(payload)
        }

            // Persist the payload to SharedPreferences as a fallback in case Flutter
            // engine isn't yet ready (cold start). We'll store under key 'saved_reminder'.
            try {
                payload?.let {
                    val prefs = getSharedPreferences("carepanion_prefs", Context.MODE_PRIVATE)
                    prefs.edit().putString("saved_reminder", it).apply()
                    Log.i("ReminderFullScreenActivity", "saved payload to prefs")
                }
            } catch (e: Exception) {
                Log.w("ReminderFullScreenActivity", "failed to save payload to prefs", e)
            }

            // Fallback: if TTS does not call back within a short time, forward anyway
            Handler(Looper.getMainLooper()).postDelayed({
                forwardToMain(payload)
            }, 7000)
    }

    private fun forwardToMain(payload: String?) {
        if (forwarded) return
        forwarded = true
        try {
            val launchIntent = Intent(this, MainActivity::class.java)
            launchIntent.putExtra("reminder_payload", payload)
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            Log.i("ReminderFullScreenActivity", "forwarding payload to MainActivity and finishing")
            startActivity(launchIntent)
        } catch (e: Exception) {
            Log.w("ReminderFullScreenActivity", "failed to start MainActivity", e)
        } finally {
            try { finish() } catch (_: Exception) {}
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Do not forcibly stop TTS here to allow finishing the utterance
    }
}
