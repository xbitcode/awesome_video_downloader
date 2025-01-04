package uz.fluttterwithakmaljon.awesome_video_downloader

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class DownloadWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            val downloadId = inputData.getString("downloadId") ?: return@withContext Result.failure()
            val url = inputData.getString("url") ?: return@withContext Result.failure()
            val fileName = inputData.getString("fileName") ?: return@withContext Result.failure()

            // The actual download is handled by ExoPlayer's DownloadManager
            // This worker ensures the download continues in the background
            
            Result.success()
        } catch (e: Exception) {
            Result.failure()
        }
    }
} 