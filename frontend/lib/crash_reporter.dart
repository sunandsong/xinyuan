import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api.dart';
import 'version.dart';

/// 极简崩溃上报。
///
/// 能抓什么、抓不到什么，先说清楚：
/// - **Dart 层未捕获异常**（null 错误、类型错误、async 异常……）：进程没死，
///   有完整堆栈，抓得全。这类占 Flutter App 问题的绝大多数。
/// - **原生崩溃**（SIGSEGV / OOM 被杀 / iOS watchdog）：进程瞬间没了，
///   这里抓不到现场。只能靠「启动写标记、正常退出清除」反推出**上次异常退出过**，
///   拿得到次数和机型版本，拿不到堆栈。要堆栈得上 xCrash/KSCrash 那套 native 方案。
///
/// 关键设计：**崩溃当下只写本地，不发网络**。进程可能马上就没了，网络请求发不完；
/// 而且用户可能没网。所以一律先落 SharedPreferences，下次启动再补发。
class CrashReporter {
  CrashReporter._();
  static final CrashReporter I = CrashReporter._();

  static const _kPending = 'crash_pending';
  static const _kAlive = 'crash_session_alive';
  static const _kAliveMeta = 'crash_session_meta';

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

    await _checkLastSession();
    unawaited(flush());
  }

  /// 上次会话有没有正常收尾：启动时置 alive，正常退到后台时清掉。
  /// 启动发现 alive 还在 → 上次是被强杀/崩溃/系统回收，记一条 abnormal_exit。
  Future<void> _checkLastSession() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_kAlive) ?? false) {
        final meta = p.getString(_kAliveMeta) ?? '';
        await _record(
          kind: 'abnormal_exit',
          type: 'AbnormalExit',
          message: meta.isEmpty ? '上次运行异常结束' : '上次运行异常结束（$meta）',
          stack: '',
        );
      }
      await p.setBool(_kAlive, true);
      await p.setString(
        _kAliveMeta,
        'v$kAppVersion ${Platform.operatingSystem}',
      );
    } catch (_) {
      // 崩溃上报自己绝不能再制造崩溃
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
          'at': DateTime.now().millisecondsSinceEpoch,
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
