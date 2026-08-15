package com.xinyuan.xinyuan

import io.flutter.embedding.android.FlutterActivity

// 这里曾挂过 xinyuan/native_crash channel 把 xCrash 的墓碑捞给 Dart 层，
// 2026-08-15 随 xCrash 一起摘掉了（原因见 app/build.gradle.kts 里的注释：16KB 页对齐）。
// Dart 侧 CrashReporter 调这个 channel 拿不到实现会走 catch 分支静默跳过，
// 不影响 Dart 层异常和「异常退出」计数——不用为此保留一个空壳 handler。
class MainActivity : FlutterActivity()
