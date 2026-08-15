package com.xinyuan.xinyuan

import android.app.Application
import android.content.Context
import xcrash.XCrash

/**
 * 只为初始化 xCrash 而存在的 Application。
 *
 * 继承的是 android.app.Application ——Flutter Gradle 插件里 `${applicationName}`
 * 占位符的默认值就是它（见 BaseApplicationHandler.DEFAULT_BASE_APPLICATION_NAME），
 * v2 embedding 的插件注册走 FlutterEngine 不走 Application，所以不需要 FlutterApplication。
 *
 * xCrash 必须在 attachBaseContext 里初始化：越早装上信号处理器，能覆盖的崩溃越多。
 */
class App : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        // 默认参数即覆盖 java 崩溃 / native 崩溃 / ANR 三类，日志写到 filesDir/tombstones/
        try {
            XCrash.init(this)
        } catch (t: Throwable) {
            // 崩溃采集自己绝不能把 App 搞挂：初始化失败就当没有这个功能，
            // Dart 层的 crash_reporter 照常工作
        }
    }
}
