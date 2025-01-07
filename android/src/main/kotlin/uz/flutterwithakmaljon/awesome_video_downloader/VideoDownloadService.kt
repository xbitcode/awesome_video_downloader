package uz.flutterwithakmaljon.awesome_video_downloader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.android.exoplayer2.offline.Download
import com.google.android.exoplayer2.offline.DownloadManager
import com.google.android.exoplayer2.offline.DownloadService
import com.google.android.exoplayer2.scheduler.Scheduler
import com.google.android.exoplayer2.ui.DownloadNotificationHelper

class VideoDownloadService : DownloadService(
    FOREGROUND_NOTIFICATION_ID,
    DEFAULT_FOREGROUND_NOTIFICATION_UPDATE_INTERVAL,
    CHANNEL_ID,
    R.string.exo_download_notification_channel_name,
    0
) {
    private lateinit var notificationHelper: DownloadNotificationHelper

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        notificationHelper = DownloadNotificationHelper(this, CHANNEL_ID)
    }

    override fun getDownloadManager(): DownloadManager {
        return VideoDownloadManager.getInstance(this).downloadManager
    }

    override fun getScheduler(): Scheduler? = null

    override fun getForegroundNotification(downloads: MutableList<Download>, notMetRequirements: Int): Notification {
        val context = this
        return notificationHelper.buildProgressNotification(
            context,
            R.drawable.ic_download,
            null,
            null,
            downloads,
            notMetRequirements
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = getString(R.string.exo_download_notification_channel_name)
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, name, importance)
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "video_download_channel"
        private const val FOREGROUND_NOTIFICATION_ID = 1
    }
} 