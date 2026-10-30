package com.touheed.solo_player

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.provider.MediaStore
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {

    private var pendingPermission: MethodChannel.Result? = null
    private val artPool = Executors.newFixedThreadPool(3)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "senpai/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestMediaPermission(result)
                    "scan" -> {
                        val video = call.argument<Boolean>("video") ?: true
                        Thread {
                            try {
                                val data = queryMedia(video)
                                runOnUiThread { result.success(data) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("SCAN_FAILED", e.toString(), null) }
                            }
                        }.start()
                    }
                    "audioArt" -> {
                        val path = call.argument<String>("path") ?: ""
                        val size = call.argument<Int>("size") ?: 320
                        artPool.execute {
                            val bytes = loadArt(path, size)
                            runOnUiThread { result.success(bytes) }
                        }
                    }
                    "indexFiles" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList<String>()
                        Thread {
                            try {
                                if (paths.isNotEmpty()) {
                                    val latch = CountDownLatch(paths.size)
                                    MediaScannerConnection.scanFile(
                                        applicationContext,
                                        paths.toTypedArray(),
                                        null
                                    ) { _, _ -> latch.countDown() }
                                    latch.await(90, TimeUnit.SECONDS)
                                }
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("INDEX_FAILED", e.toString(), null) }
                            }
                        }.start()
                    }
                    "setBrightness" -> {
                        val v = (call.argument<Double>("value") ?: 0.5).toFloat()
                        val lp = window.attributes
                        lp.screenBrightness = v
                        window.attributes = lp
                        result.success(null)
                    }
                    "resetBrightness" -> {
                        val lp = window.attributes
                        lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp
                        result.success(null)
                    }
                    "getBrightness" -> {
                        val cur = window.attributes.screenBrightness
                        result.success(if (cur < 0f) 0.5 else cur.toDouble())
                    }
                    "keepScreenOn" -> {
                        val on = call.argument<Boolean>("on") ?: false
                        if (on) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ───────── runtime permission ─────────
    private fun requestMediaPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 23) {
            result.success(true)
            return
        }
        val wanted: Array<String> = if (Build.VERSION.SDK_INT >= 33) {
            arrayOf(Manifest.permission.READ_MEDIA_VIDEO, Manifest.permission.READ_MEDIA_AUDIO)
        } else if (Build.VERSION.SDK_INT >= 29) {
            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        } else {
            arrayOf(
                Manifest.permission.READ_EXTERNAL_STORAGE,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            )
        }
        val missing = wanted.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
        if (missing.isEmpty()) {
            result.success(true)
        } else {
            pendingPermission = result
            requestPermissions(missing.toTypedArray(), 7301)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 7301) {
            val ok = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermission?.success(ok)
            pendingPermission = null
        }
    }

    // ───────── MediaStore query ─────────
    private fun queryMedia(video: Boolean): List<Map<String, Any?>> {
        val uri = if (video) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val columns = if (video) {
            arrayOf("_id", "_data", "_display_name", "duration", "width", "height", "date_added", "_size")
        } else {
            arrayOf("_id", "_data", "_display_name", "duration", "date_added", "_size", "artist", "album")
        }
        val out = ArrayList<Map<String, Any?>>()
        val cursor = contentResolver.query(uri, columns, null, null, "date_added DESC") ?: return out
        cursor.use { c ->
            val iId = c.getColumnIndex("_id")
            val iData = c.getColumnIndex("_data")
            val iName = c.getColumnIndex("_display_name")
            val iDur = c.getColumnIndex("duration")
            val iW = c.getColumnIndex("width")
            val iH = c.getColumnIndex("height")
            val iAdded = c.getColumnIndex("date_added")
            val iSize = c.getColumnIndex("_size")
            val iArtist = c.getColumnIndex("artist")
            val iAlbum = c.getColumnIndex("album")
            while (c.moveToNext()) {
                val path = if (iData >= 0) c.getString(iData) else null
                if (path == null || path.isEmpty()) continue
                val file = File(path)
                val item = HashMap<String, Any?>()
                item["id"] = c.getLong(iId).toString()
                item["path"] = path
                item["title"] = (if (iName >= 0) c.getString(iName) else null) ?: file.name
                item["duration"] = if (iDur >= 0) c.getLong(iDur) else 0L
                item["width"] = if (iW >= 0) c.getInt(iW) else 0
                item["height"] = if (iH >= 0) c.getInt(iH) else 0
                item["added"] = if (iAdded >= 0) c.getLong(iAdded) else 0L
                item["size"] = if (iSize >= 0) c.getLong(iSize) else 0L
                item["folder"] = file.parentFile?.name ?: "Storage"
                item["dir"] = file.parent ?: ""
                item["artist"] = if (iArtist >= 0) c.getString(iArtist) else null
                item["album"] = if (iAlbum >= 0) c.getString(iAlbum) else null
                out.add(item)
            }
        }
        return out
    }

    // ───────── embedded cover art ─────────
    private fun loadArt(path: String, size: Int): ByteArray? {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val raw = r.embeddedPicture ?: return null
            val bounds = BitmapFactory.Options()
            bounds.inJustDecodeBounds = true
            BitmapFactory.decodeByteArray(raw, 0, raw.size, bounds)
            var sample = 1
            while (bounds.outWidth / (sample * 2) >= size && bounds.outHeight / (sample * 2) >= size) {
                sample *= 2
            }
            val opts = BitmapFactory.Options()
            opts.inSampleSize = sample
            val bmp = BitmapFactory.decodeByteArray(raw, 0, raw.size, opts) ?: return null
            val bos = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.JPEG, 85, bos)
            bmp.recycle()
            bos.toByteArray()
        } catch (e: Exception) {
            null
        } finally {
            try {
                r.release()
            } catch (e: Exception) {
            }
        }
    }
}
