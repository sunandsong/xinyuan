package com.xinyuan.xinyuan

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 除了常规 FlutterActivity，还多挂一个 channel：把 xCrash 写在
 * filesDir/tombstones/ 里的原生崩溃现场捞给 Dart 层，由 crash_reporter 统一上报。
 * 原生库只负责写盘，捞取和上报都在 Dart 那边，省得两套上报逻辑。
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "xinyuan/native_crash"
        /** 单条墓碑截断长度：头部（信号、fault addr）+ backtrace 都在前面，
         * 后面的内存映射表对定位没用，截掉省流量，后端也只存 8000 字 */
        private const val MAX_CHARS = 6000
    }

    private fun tombstoneDir(): File = File(filesDir, "tombstones")

    /**
     * 把 xCrash 墓碑压成「崩溃类型 + signal 行 + backtrace」。
     *
     * 为什么不能把墓碑原文整个传上去：后端按堆栈前几帧算指纹做归并，
     * 而墓碑开头有 dumper 路径（含每次安装都变的 APK 哈希）和时间戳，
     * 同一个崩溃在不同设备/重装后会算出不同指纹，归并不到一起。
     */
    /**
     * 去掉 backtrace 帧里的 APK 安装路径。
     * `/data/app/~~<随机>/<包名>-<随机>/base.apk!/lib/...` 里那两段随机串
     * **每台设备、每次重装都不一样**，留着的话同一个崩溃会按设备拆成很多条，
     * 归并就废了。只保留 `base.apk!/lib/arm64-v8a/libflutter.so` 这种稳定部分。
     */
    private fun normalizeFrame(line: String): String =
        line.replace(Regex("/data/app/~~[^/]+/[^/]+/"), "")

    private fun summarize(text: String): Pair<String, String> {
        val lines = text.lines()
        var name = "NativeCrash"
        val out = mutableListOf<String>()

        // "Crash type: 'native'" / "'anr'" / "'java'"
        lines.firstOrNull { it.startsWith("Crash type:") }?.let { l ->
            l.substringAfter(':').trim().trim('\'').takeIf { it.isNotEmpty() }?.let {
                name = "native:$it"
            }
        }
        // "signal 11 (SIGSEGV), code 0 (SI_USER ...), fault addr ..."
        lines.firstOrNull { it.startsWith("signal ") }?.let { l ->
            out.add(l.trim())
            Regex("\\((SIG[A-Z]+)\\)").find(l)?.groupValues?.getOrNull(1)?.let { name = it }
        }
        // java 崩溃的墓碑里是异常类名行
        lines.firstOrNull { it.startsWith("java.") || it.contains("Exception:") }?.let {
            out.add(it.trim())
        }

        // backtrace 段：从 "backtrace:" 到下一个空行
        val start = lines.indexOfFirst { it.trim() == "backtrace:" }
        if (start >= 0) {
            out.add("backtrace:")
            for (i in (start + 1) until lines.size) {
                val l = lines[i]
                if (l.isBlank()) break
                out.add(normalizeFrame(l.trim()))
            }
        }

        if (out.isEmpty()) {
            // 兜底：格式没认出来就把开头几行带上，总比空着强（去掉含安装路径的那行）
            out.addAll(lines.filter { it.isNotBlank() && !it.contains("/data/app/") }.take(15))
        }
        return name to out.joinToString("\n")
    }

    private fun listTombstones(): List<File> =
        tombstoneDir().listFiles()?.filter { it.isFile }?.sortedBy { it.lastModified() } ?: emptyList()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "takeReports" -> {
                    val out = mutableListOf<Map<String, Any>>()
                    try {
                        for (f in listTombstones()) {
                            val text = try {
                                f.readText()
                            } catch (t: Throwable) {
                                continue
                            }
                            val (name, stack) = summarize(text)
                            out.add(
                                mapOf(
                                    "name" to name,
                                    "at" to f.lastModified(),
                                    "content" to stack.take(MAX_CHARS),
                                ),
                            )
                        }
                    } catch (t: Throwable) {
                        // 读不到就当没有，别让崩溃上报本身抛异常
                    }
                    result.success(out)
                }

                "clearReports" -> {
                    try {
                        listTombstones().forEach { it.delete() }
                    } catch (t: Throwable) {
                    }
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}
