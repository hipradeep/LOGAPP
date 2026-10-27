package com.logapp.studylog

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

object StudyTimerNotificationManager {
    const val CHANNEL_ID = "study_session_ongoing_channel"
    const val CHANNEL_NAME = "Active Study Session"
    const val NOTIFICATION_ID = 9999

    const val ACTION_TOGGLE_TIMER = "com.logapp.studylog.ACTION_TOGGLE_TIMER"
    const val ACTION_STOP_TIMER = "com.logapp.studylog.ACTION_STOP_TIMER"

    private var currentTitle: String = "Study Session"
    private var currentSubtitle: String = "Focus Timer"
    private var currentRemainingSeconds: Int = 0
    private var targetEndTimeMs: Long = 0L
    private var isCurrentlyRunning: Boolean = false

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows live countdown on lock screen and status bar when session is active."
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun showNotification(
        context: Context,
        title: String,
        subtitle: String,
        remainingSeconds: Int,
        isRunning: Boolean
    ) {
        createNotificationChannel(context)

        currentTitle = title
        currentSubtitle = subtitle
        currentRemainingSeconds = remainingSeconds
        isCurrentlyRunning = isRunning

        val remoteViews = RemoteViews(context.packageName, R.layout.notification_timer)

        // Title and Subtitle
        remoteViews.setTextViewText(R.id.notification_timer_title, title)
        if (subtitle.isNullOrBlank()) {
            remoteViews.setViewVisibility(R.id.notification_timer_subtitle, View.GONE)
        } else {
            remoteViews.setViewVisibility(R.id.notification_timer_subtitle, View.VISIBLE)
            remoteViews.setTextViewText(R.id.notification_timer_subtitle, subtitle)
        }

        // PendingIntent for clicking the round button
        val toggleIntent = Intent(context, StudyTimerActionReceiver::class.java).apply {
            action = ACTION_TOGGLE_TIMER
        }
        val togglePendingIntent = PendingIntent.getBroadcast(
            context,
            1001,
            toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )
        remoteViews.setOnClickPendingIntent(R.id.notification_timer_action_btn, togglePendingIntent)

        // Content intent (tap notification body to open app)
        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val contentPendingIntent = PendingIntent.getActivity(
            context,
            1000,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        if (isRunning) {
            // Live countdown ticking on lock screen natively via Chronometer
            remoteViews.setViewVisibility(R.id.notification_timer_chronometer, View.VISIBLE)
            remoteViews.setViewVisibility(R.id.notification_timer_static_time, View.GONE)
            remoteViews.setViewVisibility(R.id.notification_timer_pause_icon, View.VISIBLE)
            remoteViews.setViewVisibility(R.id.notification_timer_play_icon, View.GONE)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                remoteViews.setChronometerCountDown(R.id.notification_timer_chronometer, true)
            }
            targetEndTimeMs = SystemClock.elapsedRealtime() + (remainingSeconds * 1000L)
            val baseTime = targetEndTimeMs + 999L
            remoteViews.setChronometer(R.id.notification_timer_chronometer, baseTime, "%s", true)
        } else {
            // Paused static time
            remoteViews.setViewVisibility(R.id.notification_timer_chronometer, View.GONE)
            remoteViews.setViewVisibility(R.id.notification_timer_static_time, View.VISIBLE)
            remoteViews.setViewVisibility(R.id.notification_timer_pause_icon, View.GONE)
            remoteViews.setViewVisibility(R.id.notification_timer_play_icon, View.VISIBLE)

            val minutes = remainingSeconds / 60
            val seconds = remainingSeconds % 60
            val formattedTime = String.format("%02d:%02d", minutes, seconds)
            remoteViews.setTextViewText(R.id.notification_timer_static_time, formattedTime)
        }

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setCustomContentView(remoteViews)
            .setCustomBigContentView(remoteViews)
            .setStyle(NotificationCompat.DecoratedCustomViewStyle())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setContentIntent(contentPendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)

        with(NotificationManagerCompat.from(context)) {
            try {
                notify(NOTIFICATION_ID, builder.build())
            } catch (e: SecurityException) {
                // In case POST_NOTIFICATIONS is denied
            }
        }
    }

    fun dismissNotification(context: Context) {
        val manager = NotificationManagerCompat.from(context)
        manager.cancel(NOTIFICATION_ID)
    }

    fun toggleState(context: Context): Pair<Boolean, Int> {
        if (isCurrentlyRunning) {
            val remainingMs = targetEndTimeMs - SystemClock.elapsedRealtime()
            currentRemainingSeconds = maxOf(0, (remainingMs / 1000L).toInt())
            isCurrentlyRunning = false
        } else {
            isCurrentlyRunning = true
            targetEndTimeMs = SystemClock.elapsedRealtime() + (currentRemainingSeconds * 1000L)
        }
        showNotification(
            context,
            currentTitle,
            currentSubtitle,
            currentRemainingSeconds,
            isCurrentlyRunning
        )
        return Pair(isCurrentlyRunning, currentRemainingSeconds)
    }
}
