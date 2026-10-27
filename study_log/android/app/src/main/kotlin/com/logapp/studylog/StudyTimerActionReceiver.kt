package com.logapp.studylog

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StudyTimerActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            StudyTimerNotificationManager.ACTION_TOGGLE_TIMER -> {
                val (isRunning, remainingSeconds) = StudyTimerNotificationManager.toggleState(context)
                val action = if (isRunning) "resume_session" else "pause_session"
                MainActivity.sendTimerActionToFlutter(action, remainingSeconds)
            }
            StudyTimerNotificationManager.ACTION_STOP_TIMER -> {
                StudyTimerNotificationManager.dismissNotification(context)
                MainActivity.sendTimerActionToFlutter("stop_session", 0)
            }
        }
    }
}
