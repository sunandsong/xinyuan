import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';
import 'notifications.dart';

const _kAskedKey = 'notif_permission_asked';
const _kEnabledKey = 'notif_enabled';
const _kTasksKey = 'notif_tasks';
const _kWishesKey = 'notif_wishes';
const _kLettersKey = 'notif_letters';
const _kDormantKey = 'notif_dormant';

class NotificationScheduler {
  NotificationScheduler._();
  static final NotificationScheduler I = NotificationScheduler._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // 权限申请挪到 rescheduleAll 里按需触发
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // 注意：initialize 的 settings 也是命名参数，不是位置参数
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<Set<String>> _enabledCategories() async {
    final p = await SharedPreferences.getInstance();
    if (!(p.getBool(_kEnabledKey) ?? true)) return {};
    final cats = <String>{};
    if (p.getBool(_kTasksKey) ?? true) cats.add('task');
    if (p.getBool(_kWishesKey) ?? true) cats.add('wish');
    if (p.getBool(_kLettersKey) ?? true) cats.add('letter');
    if (p.getBool(_kDormantKey) ?? true) cats.add('dormant');
    return cats;
  }

  Future<bool> _ensurePermission() async {
    final p = await SharedPreferences.getInstance();
    final asked = p.getBool(_kAskedKey) ?? false;
    if (asked) return true; // 问过了，不管结果如何都不再拦
    var granted = true;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted =
          await ios.requestPermissions(alert: true, badge: true, sound: true) ??
              false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    await p.setBool(_kAskedKey, true);
    return granted;
  }

  Future<void> rescheduleAll({
    required List<Task> tasks,
    required List<Wish> wishes,
    required List<Letter> letters,
  }) async {
    try {
      await init();
      final cats = await _enabledCategories();
      final now = DateTime.now();
      final planned = [
        ...computeNotifications(
          tasks: tasks,
          wishes: wishes,
          letters: letters,
          now: now,
          enabledCategories: cats,
        ),
        if (cats.contains('dormant'))
          dormantRecallNotification(
            activeWishCount: wishes.where((w) => !w.done && !w.deleted).length,
            now: now,
          ),
      ].whereType<PlannedNotification>().toList();

      // 先取消掉这套 ID 空间里全部可能存在的通知，再排新的——
      // 比维护"上次排过哪些 ID"的状态简单，反正取消不存在的 ID 是无操作。
      // ponytail: cancelAll 会连同别的插件排的通知一起清掉，目前 App
      // 只有这一套通知来源，可接受；以后加别的通知类型要改成按 ID 精确取消。
      await _plugin.cancelAll();
      if (planned.isEmpty) return;
      if (!await _ensurePermission()) return;

      for (final n in planned) {
        if (n.at.isBefore(now)) continue; // 保险：理论上不会算出过去时间
        await _plugin.zonedSchedule(
          id: n.id,
          title: n.title,
          body: n.body,
          scheduledDate: tz.TZDateTime.from(n.at, tz.local),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'reminders',
              '提醒',
              importance: Importance.defaultImportance,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (_) {
      // 通知是锦上添花，不能让排程失败（比如测试环境没有平台通道）炸掉主流程
    }
  }
}
