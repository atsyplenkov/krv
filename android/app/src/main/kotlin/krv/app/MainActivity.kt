package krv.app

import android.content.ClipData
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "krv.app/actions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openUrl" -> {
                        try {
                            val uri = Uri.parse(call.arguments as String)
                            require(uri.scheme == "https" || uri.scheme == "mailto")
                            val intent = Intent(if (uri.scheme == "mailto") Intent.ACTION_SENDTO else Intent.ACTION_VIEW, uri)
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            result.success(null)
                        } catch (e: Exception) { result.error("OPEN_FAILED", e.message, null) }
                    }
                    "shareFiles" -> {
                        val paths = call.argument<List<String>>("paths") ?: emptyList()
                        val text = call.argument<String>("text")
                        val subject = call.argument<String>("subject")
                        Thread {
                            try {
                                require(paths.isNotEmpty())
                                val folder = File(cacheDir, "share_plus/${UUID.randomUUID()}")
                                check(folder.mkdirs())
                                val uris = ArrayList<Uri>()
                                val extensions = mutableSetOf<String>()
                                paths.forEach { path ->
                                    val source = File(path).canonicalFile
                                    // Only app-owned exports may be shared through this channel.
                                    require(source.path.startsWith(cacheDir.canonicalPath + File.separator) || source.path.startsWith(applicationInfo.dataDir + File.separator))
                                    val itemFolder = File(folder, UUID.randomUUID().toString())
                                    check(itemFolder.mkdirs())
                                    val copy = File(itemFolder, source.name)
                                    source.copyTo(copy, overwrite = false)
                                    extensions.add(source.extension.lowercase())
                                    uris.add(FileProvider.getUriForFile(this, "$packageName.flutter.share_provider", copy))
                                }
                                val mime = if (extensions.size != 1) "*/*" else when (extensions.first()) { "pdf" -> "application/pdf"; "csv" -> "text/csv"; else -> "application/octet-stream" }
                                runOnUiThread {
                                    try {
                                        val send = Intent(if (uris.size == 1) Intent.ACTION_SEND else Intent.ACTION_SEND_MULTIPLE)
                                        send.type = mime
                                        if (uris.size == 1) send.putExtra(Intent.EXTRA_STREAM, uris[0]) else send.putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                                        if (text != null) send.putExtra(Intent.EXTRA_TEXT, text)
                                        if (subject != null) send.putExtra(Intent.EXTRA_SUBJECT, subject)
                                        send.clipData = ClipData.newUri(contentResolver, "WDC export", uris[0]).also { clip -> uris.drop(1).forEach { clip.addItem(ClipData.Item(it)) } }
                                        send.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
                                        val chooser = Intent.createChooser(send, null)
                                        chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        startActivity(chooser)
                                        result.success(null)
                                    } catch (e: Exception) { result.error("SHARE_FAILED", e.message, null) }
                                }
                            } catch (e: Exception) { runOnUiThread { result.error("SHARE_FAILED", e.message, null) } }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
