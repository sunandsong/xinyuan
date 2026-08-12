import 'dart:async';
import 'api/api.dart';

/// 轻量行为埋点：内存队列攒批，满 10 条就上报；App 进后台时由 AppData 调 flush()
/// 把剩下的清掉。上报失败静默丢弃——埋点丢了就丢了，绝不能打扰用户或攒着占内存。
class Analytics {
  Analytics._();
  static final Analytics I = Analytics._();

  static const _batchSize = 10;
  final List<Map<String, dynamic>> _queue = [];
  bool _sending = false;

  /// 未登录时的埋点直接丢弃（/events 需要登录态，攒着等登录意义不大）
  bool enabled = false;

  void track(String event, [Map<String, dynamic>? props]) {
    if (!enabled) return;
    _queue.add({
      'event': event,
      if (props != null) 'props': props,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    if (_queue.length >= _batchSize) unawaited(flush());
  }

  Future<void> flush() async {
    if (_sending || _queue.isEmpty || !enabled) return;
    _sending = true;
    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();
    try {
      await EventsApi.track(batch);
    } catch (_) {
      // 静默丢弃：埋点不重要到值得重试排队
    } finally {
      _sending = false;
    }
  }
}
