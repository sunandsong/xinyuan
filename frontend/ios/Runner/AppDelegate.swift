import Flutter
import UIKit
// CocoaPods 装出来是单个 KSCrash 模块（SPM 才拆成 KSCrashRecording 等多个）
import KSCrash

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// 把 KSCrash 存的原生崩溃报告捞给 Dart 层（crash_reporter 统一上报），
  /// 跟 Android 侧 MainActivity 的 channel 同名同协议。
  private static let crashChannelName = "xinyuan/native_crash"
  /// 单条截断：头部（异常类型、信号、fault address）和 backtrace 都在前面，
  /// 后面的线程/内存详情对定位帮助有限，截掉省流量，后端也只存 8000 字
  private static let maxChars = 6000

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    installCrashReporter()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 越早装越好：这之前发生的崩溃抓不到。
  /// 整个包在 try? 里——崩溃采集自己绝不能把 App 搞挂，装不上就当没有，
  /// Dart 层的 crash_reporter 照常工作。
  private func installCrashReporter() {
    let config = KSCrashConfiguration()
    // 只开真正抓崩溃的四类：Mach 异常（EXC_BAD_ACCESS 这些）、信号、C++ 异常、
    // NSException。Zombie/内存自省之类调试用的开关不开，线上有性能代价。
    config.monitors = [.machException, .signal, .cppException, .nsException]
    try? KSCrash.shared.install(with: config)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: AppDelegate.crashChannelName,
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "NativeCrash")!.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "takeReports":
        result(AppDelegate.takeReports())
      case "clearReports":
        KSCrash.shared.reportStore?.deleteAllReports()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func takeReports() -> [[String: Any]] {
    guard let store = KSCrash.shared.reportStore else { return [] }
    var out: [[String: Any]] = []
    for id in store.reportIDs {
      guard let report = store.report(for: id.int64Value) else { continue }
      let (name, stack) = summarize(report.value)
      out.append([
        "name": name,
        "at": crashTimeMillis(report.value),
        "content": String(stack.prefix(maxChars)),
      ])
    }
    return out
  }

  /// 把 KSCrash 的完整 JSON 报告压成「崩溃类型 + 出事线程的调用栈」。
  ///
  /// 为什么不能直接把整份 JSON 传上去：后端按堆栈前几帧算指纹做归并，
  /// 而 JSON 开头永远是 debug/user/system 这些通用结构，
  /// 所有崩溃会算出同一个指纹被错并成一条（踩过一次）。
  private static func summarize(_ report: [String: Any]) -> (name: String, stack: String) {
    let crash = report["crash"] as? [String: Any]
    let error = crash?["error"] as? [String: Any]

    // 崩溃类型：优先 Mach 异常名（EXC_BAD_ACCESS 这类），其次信号名
    var name = "NativeCrash"
    var headline = ""
    if let mach = error?["mach"] as? [String: Any],
       let excName = mach["exception_name"] as? String, !excName.isEmpty {
      name = excName
      headline = excName
    }
    if let sig = error?["signal"] as? [String: Any],
       let sigName = sig["name"] as? String, !sigName.isEmpty {
      if name == "NativeCrash" { name = sigName }
      headline += headline.isEmpty ? sigName : " / \(sigName)"
    }
    if let reason = error?["reason"] as? String, !reason.isEmpty {
      headline += " — \(reason)"
    }
    if let addr = error?["address"] as? NSNumber, addr.uint64Value != 0 {
      headline += String(format: " @0x%llx", addr.uint64Value)
    }

    // 出事线程的调用栈
    var lines: [String] = headline.isEmpty ? [] : [headline]
    let threads = crash?["threads"] as? [[String: Any]] ?? []
    let crashed = threads.first { ($0["crashed"] as? Bool) == true } ?? threads.first
    if let contents = (crashed?["backtrace"] as? [String: Any])?["contents"] as? [[String: Any]] {
      for (i, frame) in contents.enumerated() {
        let obj = frame["object_name"] as? String ?? "???"
        let sym = frame["symbol_name"] as? String ?? "???"
        let addr = (frame["instruction_addr"] as? NSNumber)?.uint64Value ?? 0
        lines.append(String(format: "#%02d %@  %@  0x%llx", i, obj, sym, addr))
      }
    }
    if lines.isEmpty { lines = ["(KSCrash 报告里没有可用的调用栈)"] }
    return (name, lines.joined(separator: "\n"))
  }

  /// 崩溃发生时间（不是上报时间）——报告里存的是秒级 Unix 时间戳
  private static func crashTimeMillis(_ report: [String: Any]) -> Int {
    if let r = report["report"] as? [String: Any],
       let ts = r["timestamp"] as? NSNumber {
      return Int(ts.doubleValue * 1000)
    }
    return Int(Date().timeIntervalSince1970 * 1000)
  }
}
