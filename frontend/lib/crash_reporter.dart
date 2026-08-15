import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api.dart';
import 'version.dart';

/// 崩溃上报，三层覆盖：
///
/// 1. **Dart 层未捕获异常**（null 错误、类型错误、async 异常……）：进程没死，
///    有完整可读堆栈，抓得最全。这类占 Flutter App 问题的绝大多数。
/// 2. **原生崩溃**（EXC_BAD_ACCESS、SIGSEGV、OOM 被杀）：进程瞬间就没了，Dart 层
///    抓不到。**只有 iOS 有**——KSCrash 装 Mach 异常端口 + 信号处理器把现场写盘，
///    下次启动经 `xinyuan/native_crash` channel 捞出来一起上报。
///    Android 侧曾用 xCrash，因为它的 .so 是 4KB 页对齐、过不了 Google Play 的
///    16KB 页要求，2026-08-15 摘掉了（详见 android/app/build.gradle.kts 注释）；
///    Android 上这个 channel 没有实现，调用会走 catch 分支静默跳过。
///    ⚠️ 拿到的是**未符号化**的地址堆栈，看得出崩在哪个库、崩了多少次、什么机型
///    版本，但读不出具体哪一行——要那个得建符号化流水线（按版本归档 dSYM，
///    服务端跑 atos）。
/// 3. **异常退出兜底**：启动写 alive 标记、正常退到后台清除。下次启动发现标记还在
///    就记一条——上面两层都没抓到、但进程确实非正常结束的情况（比如被系统直接回收）。
///
/// 关键设计：**崩溃当下只写本地，不发网络**。进程可能马上就没了，网络请求发不完；
/// 而且用户可能没网。所以一律先落 SharedPreferences，下次启动再补发。
class CrashReporter {
  CrashReporter._();
  static final CrashReporter I = CrashReporter._();

  static const _kPending = 'crash_pending';
  static const _kAlive = 'crash_session_alive';
  static const _kAliveMeta = 'crash_session_meta';

  /// 跟 Android MainActivity / iOS AppDelegate 两侧同名同协议
  static const _native = MethodChannel('xinyuan/native_crash');

  /// 本地最多攒这么多条，超了丢最老的——崩溃循环时别把存储撑爆
  static const _maxPending = 30;

  /// 当前登录用户，上报时带上（未登录就是空串）。由 AppData 在登录/登出时更新。
  String account = '';

  bool _installed = false;

  /// 挂钩子 + 处理上一次会话的遗留。在 runApp 之前调用。
  Future<void> init() async {
    if (_installed) return;
    _installed = true;

    // Flutter framework 内部错误（build/layout/paint）
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      prevOnError?.call(details);
      unawaited(
        _record(
          kind: 'dart_error',
          type: details.exception.runtimeType.toString(),
          message: details.exceptionAsString(),
          stack: details.stack?.toString() ?? '',
        ),
      );
    };

    // isolate 里未捕获的异步错误
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(
        _record(
          kind: 'dart_error',
          type: error.runtimeType.toString(),
          message: error.toString(),
          stack: stack.toString(),
        ),
      );
      return true; // 已处理，别再往上抛
    };

    // 先把 alive 标记读出来（下面判断异常退出要用），再立刻重新置上
    final hadAliveFlag = await _readAndRearmAliveFlag();

    // 捞 native 崩溃必须等第一帧之后：MethodChannel 的原生侧 handler 是在
    // Android configureFlutterEngine / iOS didInitializeImplicitFlutterEngine
    // 里注册的，不保证早于 Dart main()。在 main() 里直接调会静默失败
    // （踩过一次：tombstone 生成了但一直没被捞走）。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _drainNativeCrashes();
      // 已经捞到带堆栈的真现场了就别再记这条信息量更少的：同一次崩溃记两条纯属噪音
      if (hadAliveFlag && !_nativeDrained) {
        await _record(
          kind: 'abnormal_exit',
          type: 'AbnormalExit',
          message: _lastAliveMeta.isEmpty
              ? '上次运行异常结束'
              : '上次运行异常结束（$_lastAliveMeta）',
          stack: '',
        );
      }
      await flush();
    });
  }

  /// 把 native 层写在磁盘上的崩溃现场捞进本地队列。
  /// 必须排在 _checkLastSession 之前：原生崩溃同时也会让 alive 标记残留，
  /// 先捞到真现场，_checkLastSession 里就能跳过那条信息量更少的 abnormal_exit。
  Future<void> _drainNativeCrashes() async {
    try {
      final raw = await _native.invokeMethod<List<dynamic>>('takeReports');
      if (raw == null || raw.isEmpty) return;

      for (final r in raw) {
        if (r is! Map) continue;
        final content = r['content']?.toString() ?? '';
        if (content.isEmpty) continue;
        await _record(
          kind: 'native_crash',
          // 原生崩溃没有 Dart 那种异常类名，用文件名/报告名做区分依据，
          // 真正的归并靠后端对堆栈前几帧算指纹
          type: r['name']?.toString() ?? 'NativeCrash',
          message: '原生崩溃（未符号化）',
          stack: content,
          at: r['at'] is int ? r['at'] as int : null,
        );
      }
      _nativeDrained = true;
      // 捞进本地队列了才清 native 侧，避免上报前丢现场
      await _native.invokeMethod('clearReports');
    } catch (_) {
      // channel 没实现（比如跑在 test/desktop）或原生库没装上：忽略，
      // 另外两层照常工作
    }
  }

  /// 这次启动是否已经从 native 层捞到了真崩溃现场
  bool _nativeDrained = false;

  String _lastAliveMeta = '';

  /// 读出上次会话的 alive 标记（true = 上次没正常收尾），并立刻为本次会话重新置上。
  /// 读和重置必须在启动时一起做完，不能等到第一帧回调——万一第一帧之前又崩了，
  /// 标记还留着，下次启动照样能发现。
  Future<bool> _readAndRearmAliveFlag() async {
    try {
      final p = await SharedPreferences.getInstance();
      final had = p.getBool(_kAlive) ?? false;
      _lastAliveMeta = p.getString(_kAliveMeta) ?? '';
      await p.setBool(_kAlive, true);
      await p.setString(
        _kAliveMeta,
        'v$kAppVersion ${Platform.operatingSystem}',
      );
      return had;
    } catch (_) {
      // 崩溃上报自己绝不能再制造崩溃
      return false;
    }
  }

  /// App 正常进入后台时调：清掉 alive 标记，避免被误判成异常退出。
  Future<void> markCleanExit() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAlive, false);
    } catch (_) {}
  }

  /// 回到前台时重新置上，不然这次会话真崩了反而检测不出来。
  Future<void> markResumed() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kAlive, true);
    } catch (_) {}
  }

  Future<void> _record({
    required String kind,
    required String type,
    required String message,
    required String stack,

    /// 崩溃真实发生时间；不给就用当下（native 崩溃是上次会话发生的，得用文件时间）
    int? at,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_kPending) ?? [];
      list.add(
        jsonEncode({
          'kind': kind,
          'type': type,
          'message': message,
          'stack': stack,
          'appVersion': kAppVersion,
          'platform': Platform.operatingSystem,
          'osVersion': Platform.operatingSystemVersion,
          'at': at ?? DateTime.now().millisecondsSinceEpoch,
          'account': account,
        }),
      );
      // 超量丢最老的：崩溃循环时保住最近的现场就够了
      final trimmed = list.length > _maxPending
          ? list.sublist(list.length - _maxPending)
          : list;
      await p.setStringList(_kPending, trimmed);
    } catch (_) {}
  }

  bool _sending = false;

  /// 把本地攒的崩溃发出去，成功才清。发失败留着下次启动再试。
  Future<void> flush() async {
    if (_sending) return;
    _sending = true;
    try {
      final p = await SharedPreferences.getInstance();
      final list = p.getStringList(_kPending) ?? [];
      if (list.isEmpty) return;

      final batch = <Map<String, dynamic>>[];
      for (final s in list) {
        try {
          final m = jsonDecode(s);
          if (m is Map<String, dynamic>) batch.add(m);
        } catch (_) {
          // 单条坏了就跳过，别卡住整批
        }
      }
      if (batch.isEmpty) {
        await p.remove(_kPending);
        return;
      }

      await CrashApi.report(batch);
      await p.remove(_kPending); // 发成功才清
    } catch (_) {
      // 没网/后端挂了：留着，下次启动再发
    } finally {
      _sending = false;
    }
  }
}
