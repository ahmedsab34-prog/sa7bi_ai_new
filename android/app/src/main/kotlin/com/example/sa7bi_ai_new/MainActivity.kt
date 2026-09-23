package com.example.sa7bi_ai_new

import android.graphics.Bitmap
import android.media.MediaMetadataRetriever
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.ryanheise.audioservice.AudioServiceActivity
import java.io.ByteArrayOutputStream

class MainActivity : AudioServiceActivity() {

    private val videoChannel = "sa7bi_ai/video"

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            videoChannel
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "extractFrames" -> {

                    val path =
                        call.argument<String>("path")

                    if (
                        path == null ||
                        path.trim().isEmpty()
                    ) {
                        result.error(
                            "INVALID_PATH",
                            "Video path is empty",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val timesMs =
                        call.argument<List<Any>>("timesMs")

                    val requestedTimes =
                        timesMs
                            ?.mapNotNull { value ->
                                when (value) {
                                    is Int -> value.toLong()
                                    is Long -> value
                                    is Double -> value.toLong()
                                    is Float -> value.toLong()
                                    else -> null
                                }
                            }
                            ?: listOf(
                                0L,
                                5000L,
                                10000L,
                                15000L
                            )

                    try {

                        val frames =
                            extractVideoFrames(
                                path,
                                requestedTimes
                            )

                        result.success(frames)

                    } catch (e: Exception) {

                        result.error(
                            "VIDEO_FRAME_ERROR",
                            e.message
                                ?: "Unable to extract video frames",
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun extractVideoFrames(
        path: String,
        timesMs: List<Long>
    ): List<ByteArray> {

        val retriever =
            MediaMetadataRetriever()

        val result =
            mutableListOf<ByteArray>()

        try {

            val uri =
                if (
                    path.startsWith("content://") ||
                    path.startsWith("file://")
                ) {
                    Uri.parse(path)
                } else {
                    Uri.fromFile(
                        java.io.File(path)
                    )
                }

            if (uri.scheme == "content") {

                retriever.setDataSource(
                    this,
                    uri
                )

            } else {

                val realPath =
                    if (uri.scheme == "file") {
                        uri.path ?: path
                    } else {
                        path
                    }

                retriever.setDataSource(
                    realPath
                )
            }

            val durationMs =
                retriever.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )
                    ?.toLongOrNull()
                    ?: 0L

            val safeDuration =
                if (durationMs > 0L) {
                    durationMs
                } else {
                    15000L
                }

            val maxTime =
                maxOf(
                    0L,
                    safeDuration - 100L
                )

            val uniqueTimes =
                timesMs
                    .map { time ->
                        time.coerceIn(
                            0L,
                            maxTime
                        )
                    }
                    .distinct()

            for (timeMs in uniqueTimes) {

                val bitmap =
                    retriever.getFrameAtTime(
                        timeMs * 1000L,
                        MediaMetadataRetriever
                            .OPTION_CLOSEST_SYNC
                    )
                        ?: continue

                var scaledBitmap: Bitmap? = null

                try {

                    val scaled =
                        scaleBitmap(
                            bitmap,
                            720
                        )

                    scaledBitmap = scaled

                    val output =
                        ByteArrayOutputStream()

                    scaled.compress(
                        Bitmap.CompressFormat.JPEG,
                        62,
                        output
                    )

                    val bytes =
                        output.toByteArray()

                    if (bytes.isNotEmpty()) {
                        result.add(bytes)
                    }

                    if (result.size >= 4) {
                        break
                    }

                } finally {

                    if (
                        scaledBitmap != null &&
                        scaledBitmap !== bitmap
                    ) {
                        scaledBitmap.recycle()
                    }

                    bitmap.recycle()
                }
            }

            return result

        } finally {

            try {
                retriever.release()
            } catch (_: Exception) {
                // Ignore release errors.
            }
        }
    }

    private fun scaleBitmap(
        bitmap: Bitmap,
        maxWidth: Int
    ): Bitmap {

        val width =
            bitmap.width

        val height =
            bitmap.height

        if (width <= maxWidth) {
            return bitmap
        }

        val newHeight =
            (
                height.toFloat() *
                    maxWidth.toFloat() /
                    width.toFloat()
            ).toInt()
                .coerceAtLeast(1)

        return Bitmap.createScaledBitmap(
            bitmap,
            maxWidth,
            newHeight,
            true
        )
    }
}
