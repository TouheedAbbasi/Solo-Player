package com.touheed.solo_player

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.media.MediaMetadata
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder

/**
 * Foreground service that shows the music notification (title, artist, cover,
 * previous / play-pause / next / close) and a lock-screen media session.
 * The real player lives in Dart; every button press is sent back to Dart.
 */
class MediaPlaybackService : Service() {

    companion object {
        const val CHANNEL_ID = "solo_player_playback"
        const val NOTIFICATION_ID = 4711
        const val ACTION_UPDATE = "com.touheed.solo_player.UPDATE"
        const val ACTION_PLAYPAUSE = "com.touheed.solo_player.PLAYPAUSE"
        const val ACTION_NEXT = "com.touheed.solo_player.NEXT"
        const val ACTION_PREV = "com.touheed.solo_player.PREV"
        const val ACTION_STOP = "com.touheed.solo_player.STOP"

        @Volatile
        var instance: MediaPlaybackService? = null

        /** Set by MainActivity; forwards a button press to Dart. */
        var actionHandler: ((String) -> Unit)? = null

        var title: String = ""
        var artist: String = ""
        var playing: Boolean = false
        var positionMs: Long = 0L
        var durationMs: Long = 0L
        var speed: Float = 1f
        var art: Bitmap? = null

        fun show(
            context: Context,
            newTitle: String,
            newArtist: String,
            isPlaying: Boolean,
            position: Long,
            duration: Long,
            newSpeed: Float,
            cover: Bitmap?
        ) {
            title = newTitle
            artist = newArtist
            playing = isPlaying
            positionMs = position
            durationMs = duration
            speed = newSpeed
            art = cover

            val running = instance
            if (running != null) {
                running.refresh()
                return
            }
            if (!isPlaying) return
            val intent = Intent(context, MediaPlaybackService::class.java)
            intent.action = ACTION_UPDATE
            if (Build.VERSION.SDK_INT >= 26) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun hide(context: Context) {
            val running = instance
            if (running != null) {
                running.shutdown()
            } else {
                context.stopService(Intent(context, MediaPlaybackService::class.java))
            }
        }
    }

    private var session: MediaSession? = null
    private var foreground = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createChannel()
        val s = MediaSession(this, "SoloPlayer")
        s.setFlags(MediaSession.FLAG_HANDLES_MEDIA_BUTTONS or MediaSession.FLAG_HANDLES_TRANSPORT_CONTROLS)
        s.setCallback(object : MediaSession.Callback() {
            override fun onPlay() {
                dispatch("playpause")
            }

            override fun onPause() {
                dispatch("playpause")
            }

            override fun onSkipToNext() {
                dispatch("next")
            }

            override fun onSkipToPrevious() {
                dispatch("prev")
            }

            override fun onStop() {
                dispatch("stop")
            }

            override fun onSeekTo(pos: Long) {
                dispatch("seek:$pos")
            }
        })
        s.isActive = true
        session = s
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_PLAYPAUSE -> dispatch("playpause")
            ACTION_NEXT -> dispatch("next")
            ACTION_PREV -> dispatch("prev")
            ACTION_STOP -> dispatch("stop")
            else -> refresh()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        session?.release()
        session = null
        instance = null
        super.onDestroy()
    }

    private fun dispatch(action: String) {
        actionHandler?.invoke(action)
    }

    fun refresh() {
        updateSession()
        val n = buildNotification()
        if (playing) {
            enterForeground(n)
        } else {
            if (!foreground) enterForeground(n)
            stopForeground(false)
            foreground = false
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.notify(NOTIFICATION_ID, n)
        }
    }

    private fun enterForeground(n: Notification) {
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
        foreground = true
    }

    fun shutdown() {
        stopForeground(true)
        foreground = false
        stopSelf()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channel = NotificationChannel(CHANNEL_ID, "Music playback", NotificationManager.IMPORTANCE_LOW)
        channel.setShowBadge(false)
        channel.description = "Controls for the song that is playing"
        nm.createNotificationChannel(channel)
    }

    private fun updateSession() {
        val s = session ?: return
        val state = if (playing) PlaybackState.STATE_PLAYING else PlaybackState.STATE_PAUSED
        val actions = PlaybackState.ACTION_PLAY or
            PlaybackState.ACTION_PAUSE or
            PlaybackState.ACTION_PLAY_PAUSE or
            PlaybackState.ACTION_SKIP_TO_NEXT or
            PlaybackState.ACTION_SKIP_TO_PREVIOUS or
            PlaybackState.ACTION_STOP or
            PlaybackState.ACTION_SEEK_TO
        val ps = PlaybackState.Builder()
            .setActions(actions)
            .setState(state, positionMs, if (playing) speed else 0f)
            .build()
        s.setPlaybackState(ps)

        val md = MediaMetadata.Builder()
            .putString(MediaMetadata.METADATA_KEY_TITLE, title)
            .putString(MediaMetadata.METADATA_KEY_ARTIST, artist)
            .putLong(MediaMetadata.METADATA_KEY_DURATION, durationMs)
        val cover = art
        if (cover != null) md.putBitmap(MediaMetadata.METADATA_KEY_ALBUM_ART, cover)
        s.setMetadata(md.build())
    }

    private fun pending(action: String, code: Int): PendingIntent {
        val intent = Intent(this, MediaPlaybackService::class.java)
        intent.action = action
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getService(this, code, intent, flags)
    }

    private fun buildNotification(): Notification {
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val iconId = resources.getIdentifier("ic_stat_solo", "drawable", packageName)
        b.setSmallIcon(if (iconId != 0) iconId else android.R.drawable.ic_media_play)
        b.setContentTitle(title)
        b.setContentText(artist)
        val cover = art
        if (cover != null) b.setLargeIcon(cover)
        b.setShowWhen(false)
        b.setOnlyAlertOnce(true)
        b.setOngoing(playing)
        b.setVisibility(Notification.VISIBILITY_PUBLIC)
        if (Build.VERSION.SDK_INT < 26) b.setPriority(Notification.PRIORITY_LOW)

        val launch = packageManager.getLaunchIntentForPackage(packageName)
        if (launch != null) {
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) flags = flags or PendingIntent.FLAG_IMMUTABLE
            b.setContentIntent(PendingIntent.getActivity(this, 0, launch, flags))
        }
        b.setDeleteIntent(pending(ACTION_STOP, 4))

        b.addAction(Notification.Action.Builder(android.R.drawable.ic_media_previous, "Previous", pending(ACTION_PREV, 1)).build())
        if (playing) {
            b.addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "Pause", pending(ACTION_PLAYPAUSE, 2)).build())
        } else {
            b.addAction(Notification.Action.Builder(android.R.drawable.ic_media_play, "Play", pending(ACTION_PLAYPAUSE, 2)).build())
        }
        b.addAction(Notification.Action.Builder(android.R.drawable.ic_media_next, "Next", pending(ACTION_NEXT, 3)).build())
        b.addAction(Notification.Action.Builder(android.R.drawable.ic_menu_close_clear_cancel, "Close", pending(ACTION_STOP, 5)).build())

        val style = Notification.MediaStyle().setShowActionsInCompactView(0, 1, 2)
        val token = session?.sessionToken
        if (token != null) style.setMediaSession(token)
        b.setStyle(style)
        return b.build()
    }
}
