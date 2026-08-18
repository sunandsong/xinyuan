import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'consent.dart';
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

  /// 弹系统权限框之前，先由界面层解释一句"要通知权限干嘛"。
  /// 由 HomePage 注入（这个类里没有 BuildContext，也不该有）。
  /// 返回 false = 用户不想开，那就连系统框都别弹。
  Future<bool> Function()? permissionExplainer;

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
    // 管理端把通知功能整个关了：连权限都不该要。
    // configLoaded 一起判：showNotif 默认 true，新装用户在 /config 回来之前会被
    // 当成「功能开着」，于是权限框先弹了出来，而功能其实是关的。宁可晚一步问。
    if (!AppData.I.configLoaded || !AppData.I.showNotif) return false;

    // 没同意隐私政策之前，一个系统权限框都不许弹。
    // 2026-08-18 在 Android 模拟器上实测：冷启动时通知权限框会盖在隐私同意弹窗
    // **前面**——用户还没看到隐私政策就先被要权限。「同意前不得申请权限」是国内
    // 审核的红线之一，这里必须挡住。同意之后数据一有变动就会重新排程，会再走到这。
    if (!ConsentState.I.consented) return false;

    final p = await SharedPreferences.getInstance();
    final asked = p.getBool(_kAskedKey) ?? false;
    if (asked) return true; // 问过了，不管结果如何都不再拦

    // 裸弹系统权限框同样过不了审，要先有场景说明。
    // 说明都被拒了就别再弹系统框，也别下次再问——反复纠缠比不问更招人烦。
    // 界面层还没来得及注册解释函数（HomePage.initState 里注册）就别申请——
    // 否则弹出去的是一个没有任何前因后果的系统权限框，正是要避免的那种。
    // 这次跳过不记 asked，下次数据变动重排时会再走到这里。
    final explain = permissionExplainer;
    if (explain == null) return false;
    if (!await explain()) {
      await p.setBool(_kAskedKey, true);
      return false;
    }
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
      // 功能被管理端关掉：不光不排新的，还得把之前排好的清干净——
      // 否则用户那边开关虽然"关了"，旧提醒到点照样弹出来
      if (!AppData.I.showNotif) {
        await _plugin.cancelAll();
        return;
      }
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
