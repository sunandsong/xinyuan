import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';

/// 目标日期提醒 —— 纯本地通知，不依赖服务端推送。
/// 设了「想在某天前做到」的心愿，会在到期当天早上 9 点提醒一次。
/// 没授权 / 平台不支持时全部静默跳过，绝不影响主流程。
class Notify {
  Notify._();
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static bool _allowed = false;

  static const _details = NotificationDetails(
    iOS: DarwinNotificationDetails(),
    android: AndroidNotificationDetails(
      'wish_target',
      '心愿提醒',
      channelDescription: '心愿目标日期到期提醒',
      importance: Importance.defaultImportance,
    ),
  );

  /// 首次用到时才初始化（顺带申请权限），避免一启动就弹系统弹窗
  static Future<bool> _ensure() async {
    if (_ready) return _allowed;
    _ready = true;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        settings: const InitializationSettings(
          iOS: DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: false,
            requestSoundPermission: true,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        _allowed =
            await ios.requestPermissions(alert: true, sound: true) ?? false;
      } else {
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        _allowed = await android?.requestNotificationsPermission() ?? true;
      }
    } catch (e) {
      debugPrint('notify init failed: $e');
      _allowed = false;
    }
    return _allowed;
  }

  /// 同一条心愿用同一个通知 id，重设日期会覆盖旧的
  static int _idOf(Wish w) => w.id.hashCode & 0x7fffffff;

  static Future<void> scheduleTarget(Wish w) async {
    await cancel(w);
    final target = w.targetAt;
    if (target == null || w.done) return;
    if (!await _ensure()) return;
    // 当天早上 9 点；已经过了就不再提醒
    final at = DateTime(target.year, target.month, target.day, 9);
    if (!at.isAfter(DateTime.now())) return;
    try {
      await _plugin.zonedSchedule(
        id: _idOf(w),
        title: '今天是你给「${w.title}」定的日子',
        body: '还想做的话，今天就是好时候',
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('notify schedule failed: $e');
    }
  }

  static Future<void> cancel(Wish w) async {
    if (!_ready) return; // 还没初始化过，自然也没有待发通知
    try {
      await _plugin.cancel(id: _idOf(w));
    } catch (e) {
      debugPrint('notify cancel failed: $e');
    }
  }
}

/// 页面里用的两个短名字
Future<void> scheduleWishReminder(Wish w) => Notify.scheduleTarget(w);
Future<void> cancelWishReminder(Wish w) => Notify.cancel(w);
