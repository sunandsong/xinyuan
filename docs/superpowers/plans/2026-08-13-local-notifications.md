# 本地通知 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 Flutter App 加上四类本地通知（任务到期、心愿期限、胶囊开启、沉睡唤回），零后端参与，可测、可关闭。

**Architecture:** 纯函数 `computeNotifications()` 算出该排哪些通知（可脱离设备单测）；`NotificationScheduler` 执行层调 `flutter_local_notifications` 落地，管权限与开关；接入点是 `AppData` 里三个 `_touch*` 方法和 `initSession()`。

**Tech Stack:** Flutter, `flutter_local_notifications`, `timezone`, `shared_preferences`（已有依赖）。

## Global Constraints

- 依据 `docs/superpowers/specs/2026-08-13-local-notifications-design.md`（唯一需求来源，以下数值全部来自它）。
- 只排未来 14 天内的事件。
- 通知 ID 规则（决定幂等）：
  - 任务到期：`_stableId('task_day_' + dayStr)`
  - 心愿 3 天前：`_stableId('wish_3d_' + wishId)`
  - 心愿当天：`_stableId('wish_due_' + wishId)`
  - 胶囊开启：`_stableId('letter_' + letterId)`
  - 沉睡唤回：固定 `999999`
- 默认提醒时间：任务/心愿 9:00，胶囊 10:00，沉睡唤回 9:00。
- 权限只在 `rescheduleAll()` 发现有非空通知列表且未问过时申请一次（`SharedPreferences` 键 `notif_permission_asked`），不管结果如何都不再问。
- Android 用 `AndroidScheduleMode.inexactAllowWhileIdle`，不申请精确闹钟权限。
- 设置开关键名：`notif_enabled`（总开关，默认 true）、`notif_tasks`、`notif_wishes`、`notif_letters`、`notif_dormant`（默认全 true）。
- 通知点击只需打开 App 到默认首页，不做深链。
- **调度触发不依赖登录态**：`AppData` 的 `_touchWish/_touchTask/_touchLetter` 在触碰数据时无条件调用通知重排（哪怕未登录的本地预览模式也要生效），复用同款 300ms 防抖但用独立的 `Timer` 字段（不能借用 `_pushTimer`，那个只在 `signedIn` 时才启动，会漏掉未登录场景）。
- 不做：打卡挽留提醒、通知内容动态刷新、深链、服务器推送。
- 每个任务结束跑 `cd frontend && flutter analyze` 和相关 `flutter test`，零报错。

---

### Task 1: 纯函数 `computeNotifications` + 单测

**Files:**
- Create: `frontend/lib/notifications.dart`
- Test: `frontend/test/notifications_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class PlannedNotification {
    const PlannedNotification({
      required this.id,
      required this.category, // 'task' | 'wish' | 'letter' | 'dormant'
      required this.title,
      required this.body,
      required this.at, // DateTime，本地时间
    });
    final int id;
    final String category;
    final String title;
    final String body;
    final DateTime at;
  }

  List<PlannedNotification> computeNotifications({
    required List<Task> tasks,
    required List<Wish> wishes,
    required List<Letter> letters,
    required DateTime now,
    required Set<String> enabledCategories, // 子集 of {'task','wish','letter','dormant'}
  });

  int stableNotificationId(String key); // 供 Task 3 复用同一套 ID 规则
  ```
- Consumes: `Task`/`Wish`/`Letter` 来自 `frontend/lib/data.dart`（字段：`Task.day/title/done/deleted`；`Wish.title/done/deleted/targetAt`；`Letter.title/openAt/deleted`）。

- [ ] **Step 1: 写失败的测试——任务到期单条**

```dart
// frontend/test/notifications_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/notifications.dart';

void main() {
  final now = DateTime(2026, 8, 13, 8);
  const red = Color(0xFFE05A5A);

  Task task(String id, DateTime day, {bool done = false, String title = '任务'}) =>
      Task(id: id, title: title, day: day, done: done);
  Wish wish(String id, {DateTime? targetAt, bool done = false, String title = '心愿'}) =>
      Wish(id: id, title: title, color: red, targetAt: targetAt, done: done);
  Letter letter(String id, DateTime openAt, {String title = '信'}) =>
      Letter(id: id, title: title, content: '内容', openAt: openAt);

  const allCats = {'task', 'wish', 'letter', 'dormant'};

  group('任务到期', () {
    test('当天单条未完成任务：排一条，文案是任务标题', () {
      final result = computeNotifications(
        tasks: [task('t1', DateTime(2026, 8, 13), title: '晨跑')],
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.category, 'task');
      expect(result.first.body, '晨跑');
      expect(result.first.at, DateTime(2026, 8, 13, 9, 0));
    });
  });
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: 编译失败（`notifications.dart` 不存在）或断言失败。

- [ ] **Step 3: 写最小实现（先只覆盖任务到期单条场景）**

```dart
// frontend/lib/notifications.dart
import 'data.dart';

class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.at,
  });
  final int id;
  final String category;
  final String title;
  final String body;
  final DateTime at;
}

/// 字符串哈希取正整数当通知 ID：同一个 key 永远算出同一个 ID，
/// 用来在重排时精确覆盖/取消上一版，不用维护额外的 ID 映射表。
int stableNotificationId(String key) {
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return hash;
}

DateTime _dOnly(DateTime d) => DateTime(d.year, d.month, d.day);

List<PlannedNotification> computeNotifications({
  required List<Task> tasks,
  required List<Wish> wishes,
  required List<Letter> letters,
  required DateTime now,
  required Set<String> enabledCategories,
}) {
  final result = <PlannedNotification>[];
  final today = _dOnly(now);
  final windowEnd = today.add(const Duration(days: 14));

  if (enabledCategories.contains('task')) {
    final byDay = <DateTime, List<String>>{};
    for (final t in tasks) {
      if (t.done || t.deleted) continue;
      final d = _dOnly(t.day);
      if (d.isBefore(today) || !d.isBefore(windowEnd)) continue;
      byDay.putIfAbsent(d, () => []).add(t.title);
    }
    byDay.forEach((day, titles) {
      final dayStr = '${day.year}-${day.month}-${day.day}';
      final body = titles.length == 1
          ? titles.first
          : '今天有 ${titles.length} 件事在等你：${titles.take(3).join('、')}${titles.length > 3 ? '…' : ''}';
      result.add(PlannedNotification(
        id: stableNotificationId('task_day_$dayStr'),
        category: 'task',
        title: '今天有任务要做',
        body: body,
        at: DateTime(day.year, day.month, day.day, 9),
      ));
    });
  }

  return result;
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: PASS

- [ ] **Step 5: 补测试——任务多条合并**

```dart
    test('当天 2 条未完成任务：合并成一条，列出标题', () {
      final result = computeNotifications(
        tasks: [
          task('t1', DateTime(2026, 8, 13), title: '晨跑'),
          task('t2', DateTime(2026, 8, 13), title: '写周报'),
        ],
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.body, '今天有 2 件事在等你：晨跑、写周报');
    });

    test('4 条任务合并：超过 3 条用省略号收尾', () {
      final result = computeNotifications(
        tasks: [
          task('t1', DateTime(2026, 8, 13), title: 'A'),
          task('t2', DateTime(2026, 8, 13), title: 'B'),
          task('t3', DateTime(2026, 8, 13), title: 'C'),
          task('t4', DateTime(2026, 8, 13), title: 'D'),
        ],
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.first.body, '今天有 4 件事在等你：A、B、C…');
    });

    test('已完成的任务不排', () {
      final result = computeNotifications(
        tasks: [task('t1', DateTime(2026, 8, 13), done: true)],
        wishes: [], letters: [], now: now, enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('14 天窗口外的任务不排，窗口内（第 14 天）排', () {
      final result = computeNotifications(
        tasks: [
          task('t1', DateTime(2026, 8, 28)), // 第 15 天，超窗口
          task('t2', DateTime(2026, 8, 27)), // 第 14 天，边界内
        ],
        wishes: [], letters: [], now: now, enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.id, stableNotificationId('task_day_2026-8-27'));
    });

    test('分类开关关闭时任务类不排', () {
      final result = computeNotifications(
        tasks: [task('t1', DateTime(2026, 8, 13))],
        wishes: [], letters: [], now: now,
        enabledCategories: {'wish', 'letter', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });
}
```

- [ ] **Step 6: 跑全部任务测试确认通过**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: 全部 PASS（先跑过再进下一步，任务合并/超 3 条/已完成/窗口边界/开关 5 个新用例）

- [ ] **Step 7: 心愿期限——写失败测试**

```dart
  group('心愿期限', () {
    test('目标日期前 3 天：排一条"还有 3 天到期"', () {
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 16), title: '看极光')],
        now: now, enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.category, 'wish');
      expect(result.first.body, '『看极光』还有 3 天到期');
      expect(result.first.at, DateTime(2026, 8, 13, 9, 0));
    });

    test('目标日期当天：排一条"就是今天了"', () {
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13), title: '看极光')],
        now: now, enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.body, '『看极光』就是今天了');
      expect(result.first.at, DateTime(2026, 8, 13, 9, 0));
    });

    test('目标日期前 3 天且恰好是当天（3天倒计时=0）：两条规则命中同一天只应各自独立判断，不重复', () {
      // targetAt 就是 now 那天：应该只命中"当天"这条规则，不会同时命中"3天前"
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13))],
        now: now, enabledCategories: allCats,
      );
      expect(result.length, 1);
    });

    test('已完成的心愿不排', () {
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 16), done: true)],
        now: now, enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('没设期限的心愿不排', () {
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1')],
        now: now, enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('心愿开关关闭时不排', () {
      final result = computeNotifications(
        tasks: [], letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13))],
        now: now, enabledCategories: {'task', 'letter', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });
```

- [ ] **Step 8: 跑测试确认失败**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: FAIL（`wish` 分类还没实现）

- [ ] **Step 9: 补实现——心愿期限**

在 `computeNotifications` 里 `return result;` 之前加：

```dart
  if (enabledCategories.contains('wish')) {
    for (final w in wishes) {
      if (w.done || w.deleted || w.targetAt == null) continue;
      final target = _dOnly(w.targetAt!);
      if (target.isBefore(today) || !target.isBefore(windowEnd)) continue;
      final daysLeft = target.difference(today).inDays;
      if (daysLeft == 0) {
        result.add(PlannedNotification(
          id: stableNotificationId('wish_due_${w.id}'),
          category: 'wish',
          title: '心愿到期',
          body: '『${w.title}』就是今天了',
          at: DateTime(today.year, today.month, today.day, 9),
        ));
      } else if (daysLeft == 3) {
        result.add(PlannedNotification(
          id: stableNotificationId('wish_3d_${w.id}'),
          category: 'wish',
          title: '心愿到期提醒',
          body: '『${w.title}』还有 3 天到期',
          at: DateTime(today.year, today.month, today.day, 9),
        ));
      }
    }
  }
```

- [ ] **Step 10: 跑测试确认通过**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: 全部 PASS

- [ ] **Step 11: 胶囊开启——写失败测试**

```dart
  group('胶囊开启', () {
    test('开启日当天：排一条固定文案，时间 10:00', () {
      final result = computeNotifications(
        tasks: [], wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 13))],
        now: now, enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.category, 'letter');
      expect(result.first.body, '你写给自己的信，今天可以打开了');
      expect(result.first.at, DateTime(2026, 8, 13, 10, 0));
    });

    test('开启日还没到：不排', () {
      final result = computeNotifications(
        tasks: [], wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 20))],
        now: now, enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('开启日已过：不排', () {
      final result = computeNotifications(
        tasks: [], wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 10))],
        now: now, enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('胶囊开关关闭时不排', () {
      final result = computeNotifications(
        tasks: [], wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 13))],
        now: now, enabledCategories: {'task', 'wish', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });
```

- [ ] **Step 12: 跑测试确认失败，然后补实现**

Run: `cd frontend && flutter test test/notifications_test.dart` → FAIL

在同一处加：

```dart
  if (enabledCategories.contains('letter')) {
    for (final l in letters) {
      if (l.deleted) continue;
      final openDay = _dOnly(l.openAt);
      if (openDay != today) continue;
      result.add(PlannedNotification(
        id: stableNotificationId('letter_${l.id}'),
        category: 'letter',
        title: '时光胶囊',
        body: '你写给自己的信，今天可以打开了',
        at: DateTime(today.year, today.month, today.day, 10),
      ));
    }
  }
```

- [ ] **Step 13: 跑测试确认通过**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: 全部 PASS

- [ ] **Step 14: 沉睡唤回——写失败测试**

沉睡唤回不依赖 `computeNotifications`（它是"每次启动排一条 7 天后"的独立逻辑，不是扫数据算出来的），改成给 `computeNotifications` 加一个可选的 `activeWishCount`：不对——按设计，沉睡唤回的调度时机和内容都和"现在"绑定，不是"未来某天该不该提醒"，所以把它单独放一个函数更清楚：

```dart
  group('沉睡唤回', () {
    test('有进行中心愿：排一条 7 天后的，文案带数量', () {
      final n = dormantRecallNotification(activeWishCount: 48, now: now);
      expect(n, isNotNull);
      expect(n!.id, 999999);
      expect(n.body, '你的 48 个心愿还在等你');
      expect(n.at, DateTime(2026, 8, 20, 9, 0));
    });

    test('没有进行中心愿：不排', () {
      final n = dormantRecallNotification(activeWishCount: 0, now: now);
      expect(n, isNull);
    });

    test('唤回开关关闭：不排', () {
      final n = dormantRecallNotification(
        activeWishCount: 48, now: now, enabled: false,
      );
      expect(n, isNull);
    });
  });
```

- [ ] **Step 15: 跑测试确认失败，然后补实现**

Run: `cd frontend && flutter test test/notifications_test.dart` → FAIL（`dormantRecallNotification` 未定义）

在 `computeNotifications` 后面加一个新的顶层函数：

```dart
/// 沉睡唤回单独成函数：它排的是"7 天后"，不是"未来某天该不该提醒"，
/// 跟 computeNotifications 的"扫数据算日期"逻辑不是一回事，混在一起会让两边都难懂。
PlannedNotification? dormantRecallNotification({
  required int activeWishCount,
  required DateTime now,
  bool enabled = true,
}) {
  if (!enabled || activeWishCount == 0) return null;
  final at = now.add(const Duration(days: 7));
  return PlannedNotification(
    id: 999999,
    category: 'dormant',
    title: '好久不见',
    body: '你的 $activeWishCount 个心愿还在等你',
    at: DateTime(at.year, at.month, at.day, 9),
  );
}
```

- [ ] **Step 16: 跑全部测试确认通过**

Run: `cd frontend && flutter test test/notifications_test.dart`
Expected: 全部 PASS（Task 1 完整覆盖：任务 5 例、心愿 6 例、胶囊 4 例、唤回 3 例 = 18 例）

- [ ] **Step 17: `flutter analyze` 确认零警告**

Run: `cd frontend && flutter analyze lib/notifications.dart test/notifications_test.dart`
Expected: `No issues found!`

- [ ] **Step 18: Commit**

```bash
cd frontend && git add lib/notifications.dart test/notifications_test.dart
git commit -m "feat: 本地通知——纯函数 computeNotifications + 单测

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: 接依赖 + NotificationScheduler 执行层

**Files:**
- Modify: `frontend/pubspec.yaml`
- Create: `frontend/lib/notification_scheduler.dart`
- Modify iOS: `frontend/ios/Runner/AppDelegate.swift`（如需要，见 Step 5）
- Modify Android: `frontend/android/app/src/main/AndroidManifest.xml`（POST_NOTIFICATIONS 权限声明）

**Interfaces:**
- Consumes: Task 1 的 `PlannedNotification`、`computeNotifications`、`dormantRecallNotification`、`stableNotificationId`。
- Produces:
  ```dart
  class NotificationScheduler {
    NotificationScheduler._();
    static final NotificationScheduler I = NotificationScheduler._();

    Future<void> init(); // App 启动时调一次，注册插件+时区
    Future<void> rescheduleAll({
      required List<Task> tasks,
      required List<Wish> wishes,
      required List<Letter> letters,
    }); // Task 3 的唯一调用入口
  }
  ```

- [ ] **Step 1: 加依赖**

在 `frontend/pubspec.yaml` 的 `dependencies:` 块里（`url_launcher` 那行之后）加：

```yaml
  flutter_local_notifications: ^22.3.0
  timezone: ^0.11.1
```

（这两个版本号已实测校验过 API 签名，下面 Step 6 的 `zonedSchedule` 调用是照这个版本的真实签名写的——顶层 `FlutterLocalNotificationsPlugin.zonedSchedule` 全部是命名参数，没有位置参数，别按旧版教程的写法传位置参数。）

Run: `cd frontend && flutter pub get`
Expected: 成功，无版本冲突报错。

- [ ] **Step 2: 写 NotificationScheduler 骨架（先只做 init，不做真实排程）**

```dart
// frontend/lib/notification_scheduler.dart
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

  Future<void> rescheduleAll({
    required List<Task> tasks,
    required List<Wish> wishes,
    required List<Letter> letters,
  }) async {
    // Step 5 补完整实现
  }
}
```

- [ ] **Step 3: `flutter analyze` 确认骨架编译通过**

Run: `cd frontend && flutter analyze lib/notification_scheduler.dart`
Expected: `No issues found!`

- [ ] **Step 4: 补开关读取辅助方法**

在 `NotificationScheduler` 类里加：

```dart
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
```

- [ ] **Step 5: 补权限申请辅助方法**

```dart
  Future<bool> _ensurePermission() async {
    final p = await SharedPreferences.getInstance();
    final asked = p.getBool(_kAskedKey) ?? false;
    if (asked) return true; // 问过了，不管结果如何都不再拦
    var granted = true;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      granted = await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? false;
    }
    await p.setBool(_kAskedKey, true);
    return granted;
  }
```

- [ ] **Step 6: 补 `rescheduleAll` 完整实现**

替换 Step 2 里的占位方法体：

```dart
  Future<void> rescheduleAll({
    required List<Task> tasks,
    required List<Wish> wishes,
    required List<Letter> letters,
  }) async {
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
    await _plugin.cancelAll();
    if (planned.isEmpty) return;
    if (!await _ensurePermission()) return;

    for (final n in planned) {
      if (n.at.isBefore(now)) continue; // 保险：理论上 computeNotifications 不会算出过去时间
      // 注意：v22 的 zonedSchedule 全部是命名参数，没有位置参数写法
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
  }
```

**注意**：`_plugin.cancelAll()` 会连同别的插件排的通知一起清掉——但这个 App 目前只有这一套通知来源，可接受；如果以后加别的通知类型，这里要改成按 ID 精确取消。加一句注释说明这个简化。

- [ ] **Step 7: Android 权限声明**

打开 `frontend/android/app/src/main/AndroidManifest.xml`，在 `<manifest>` 标签内、`<application>` 标签之前加：

```xml
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" android:remove="true"/>
```

（第二行显式声明不要精确闹钟权限，避免插件的默认 manifest merge 意外带进来。）

- [ ] **Step 8: `flutter analyze` 全量检查**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 9: 真机/模拟器冒烟——iOS**

在 iOS 模拟器上跑：

```bash
cd frontend && flutter run -d <iOS设备ID>
```

用 Dart VM Service（参考本项目已有的 `drive.dart` 手法）或直接在 App 内触发一次 `NotificationScheduler.I.rescheduleAll(...)`（临时加一行调试按钮也可以，测完删掉），确认：
1. 弹出系统通知权限询问框；
2. 允许后，等一条排在 1 分钟后的测试通知（临时把某个 `PlannedNotification.at` 改成 `DateTime.now().add(Duration(minutes: 1))` 验证，验证完改回）能收到。

Expected: 收到通知，标题/正文与排程一致。测试完清理临时改动。

- [ ] **Step 10: Commit**

```bash
cd frontend && git add pubspec.yaml pubspec.lock lib/notification_scheduler.dart android/app/src/main/AndroidManifest.xml
git commit -m "feat: 本地通知——NotificationScheduler 执行层（权限/开关/排程）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: 接入 AppData（触发时机）

**Files:**
- Modify: `frontend/lib/data.dart`

**Interfaces:**
- Consumes: `NotificationScheduler.I.rescheduleAll(tasks:, wishes:, letters:)`（Task 2）。
- Produces: 无新增公开 API，只是内部接线。

- [ ] **Step 1: 加独立防抖定时器字段**

在 `frontend/lib/data.dart` 里 `Timer? _pushTimer;`（第 341 行附近）下面加一行：

```dart
  Timer? _notifTimer;
```

- [ ] **Step 2: 加触发方法**

在 `_scheduleFlush()` 方法（第 364-370 行）后面加一个新方法：

```dart
  /// 通知重排跟云推送是两回事：未登录的本地预览模式也该有通知，
  /// 不能借用只在 signedIn 时才启动的 _pushTimer。
  void _scheduleNotifRefresh() {
    _notifTimer?.cancel();
    _notifTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(NotificationScheduler.I.rescheduleAll(
        tasks: tasks,
        wishes: wishes,
        letters: letters,
      ));
    });
  }
```

在文件顶部 import 区加：

```dart
import 'notification_scheduler.dart';
```

- [ ] **Step 3: 接入三个 `_touch*` 方法**

修改 `_touchWish`（约第 343 行）：

```dart
  void _touchWish(Wish w) {
    w.updatedAt = DateTime.now();
    _scheduleNotifRefresh();
    if (!signedIn) return;
    _dirtyWishes.add(w);
    _scheduleFlush();
  }
```

`_touchTask`（约第 350 行）：

```dart
  void _touchTask(Task t) {
    t.updatedAt = DateTime.now();
    _scheduleNotifRefresh();
    if (!signedIn) return;
    _dirtyTasks.add(t);
    _scheduleFlush();
  }
```

`_touchLetter`（约第 357 行）：

```dart
  void _touchLetter(Letter l) {
    l.updatedAt = DateTime.now();
    _scheduleNotifRefresh();
    if (!signedIn) return;
    _dirtyLetters.add(l);
    _scheduleFlush();
  }
```

- [ ] **Step 4: App 启动时也排一次**

在 `initSession()` 方法末尾、`notifyListeners();` 之前（约第 1147 行）加：

```dart
    unawaited(NotificationScheduler.I.rescheduleAll(
      tasks: tasks,
      wishes: wishes,
      letters: letters,
    ));
```

- [ ] **Step 5: `flutter analyze` 确认**

Run: `cd frontend && flutter analyze lib/data.dart`
Expected: `No issues found!`

- [ ] **Step 6: 现有测试跑一遍确认没破坏**

Run: `cd frontend && flutter test`
Expected: 全部 PASS（`app_logic_test.dart`/`sync_test.dart` 等既有测试不应受影响——它们不启动真实插件调用链，`NotificationScheduler.I.rescheduleAll` 内部的 `_plugin` 调用在测试环境下会因为没有平台通道而可能抛异常；如果测试环境报错，见 Step 7）

- [ ] **Step 7: 如果测试环境下插件调用报错，加保护**

`flutter_local_notifications` 在纯 Dart test 环境（无平台绑定）调用会抛 `MissingPluginException`。给 `rescheduleAll` 包一层防御：

```dart
  Future<void> rescheduleAll({
    required List<Task> tasks,
    required List<Wish> wishes,
    required List<Letter> letters,
  }) async {
    try {
      await init();
      // ...原逻辑...
    } catch (_) {
      // 测试环境/插件不可用时静默跳过：通知是锦上添花，不能让它炸掉主流程
    }
  }
```

把 Task 2 Step 6 写的整个方法体包进 `try { ... } catch (_) {}`。

Run: `cd frontend && flutter test`
Expected: 全部 PASS

- [ ] **Step 8: Commit**

```bash
cd frontend && git add lib/data.dart lib/notification_scheduler.dart
git commit -m "feat: 本地通知——接入 AppData 触发时机（数据变更+启动时重排）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: 设置页

**Files:**
- Create: `frontend/lib/pages/notification_settings_page.dart`
- Modify: `frontend/lib/tabs/me_tab.dart`

**Interfaces:**
- Consumes: `SharedPreferences` 键 `notif_enabled/notif_tasks/notif_wishes/notif_letters/notif_dormant`（Task 2 定义）；`NotificationScheduler.I.rescheduleAll`；`AppData.I`（读 tasks/wishes/letters 供改开关后立即重排）。
- Produces: `NotificationSettingsPage` widget，供 `me_tab.dart` 路由跳转。

- [ ] **Step 1: 看现有页面写法作参考**

读 `frontend/lib/pages/misc_pages.dart` 或类似的简单设置页（如果存在），确认项目里 `Switch`/`SheetCard`/`T.` 主题 token 的用法风格。若没有现成简单页参考，直接用下面的实现（已按项目既有 `T.` token 命名习惯写）。

- [ ] **Step 2: 写设置页**

```dart
// frontend/lib/pages/notification_settings_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data.dart';
import '../notification_scheduler.dart';
import '../theme.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _enabled = true;
  bool _tasks = true;
  bool _wishes = true;
  bool _letters = true;
  bool _dormant = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _enabled = p.getBool('notif_enabled') ?? true;
      _tasks = p.getBool('notif_tasks') ?? true;
      _wishes = p.getBool('notif_wishes') ?? true;
      _letters = p.getBool('notif_letters') ?? true;
      _dormant = p.getBool('notif_dormant') ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
    await NotificationScheduler.I.rescheduleAll(
      tasks: AppData.I.tasks,
      wishes: AppData.I.wishes,
      letters: AppData.I.letters,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: T.bg,
      appBar: AppBar(
        backgroundColor: T.bg,
        elevation: 0,
        title: const Text('通知提醒'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('接收通知'),
            value: _enabled,
            onChanged: (v) {
              setState(() => _enabled = v);
              _set('notif_enabled', v);
            },
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('任务到期提醒'),
            value: _tasks,
            onChanged: _enabled
                ? (v) {
                    setState(() => _tasks = v);
                    _set('notif_tasks', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('心愿期限提醒'),
            value: _wishes,
            onChanged: _enabled
                ? (v) {
                    setState(() => _wishes = v);
                    _set('notif_wishes', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('时光胶囊开启提醒'),
            value: _letters,
            onChanged: _enabled
                ? (v) {
                    setState(() => _letters = v);
                    _set('notif_letters', v);
                  }
                : null,
          ),
          SwitchListTile(
            title: const Text('好久没来提醒'),
            value: _dormant,
            onChanged: _enabled
                ? (v) {
                    setState(() => _dormant = v);
                    _set('notif_dormant', v);
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: 在「我的」页加入口**

打开 `frontend/lib/tabs/me_tab.dart`，在文件顶部 import 区加：

```dart
import '../pages/notification_settings_page.dart';
```

在 `_row(context, '时光胶囊', ...)`（第 58-63 行）后面、`_row(context, '意见反馈', ...)`（第 64 行）前面插入：

```dart
                    _row(
                      context,
                      '通知提醒',
                      '',
                      () => _push(context, const NotificationSettingsPage()),
                    ),
```

- [ ] **Step 4: `flutter analyze` 确认**

Run: `cd frontend && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Widget 测试——设置页开关联动**

```dart
// frontend/test/notification_settings_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinyuan/pages/notification_settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('总开关关闭后，四个分开关禁用', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('接收通知'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile).first);
    await tester.pumpAndSettle();

    final taskSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, '任务到期提醒'),
    );
    expect(taskSwitch.onChanged, isNull);
  });

  testWidgets('读取已存的开关状态', (tester) async {
    SharedPreferences.setMockInitialValues({'notif_wishes': false});
    await tester.pumpWidget(
      const MaterialApp(home: NotificationSettingsPage()),
    );
    await tester.pumpAndSettle();

    final wishSwitch = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, '心愿期限提醒'),
    );
    expect(wishSwitch.value, isFalse);
  });
}
```

- [ ] **Step 6: 跑测试**

Run: `cd frontend && flutter test test/notification_settings_test.dart`
Expected: 全部 PASS（如果 `NotificationScheduler.I.rescheduleAll` 在测试环境报错，Task 3 Step 7 的 try/catch 已经兜住，这里不会因此失败）

- [ ] **Step 7: 全量测试 + analyze**

Run: `cd frontend && flutter analyze && flutter test`
Expected: 零警告，全部 PASS

- [ ] **Step 8: Commit**

```bash
cd frontend && git add lib/pages/notification_settings_page.dart lib/tabs/me_tab.dart test/notification_settings_test.dart
git commit -m "feat: 本地通知——设置页（总开关+4分类开关）

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: 真机验证 + 版本号 + 收尾

**Files:**
- Modify: `frontend/pubspec.yaml`（版本号递增，沿用既有惯例）
- Modify: `docs/HANDOFF.md`（勾掉路线第 3 项）

**Interfaces:** 无新增代码接口，验证与收尾任务。

- [ ] **Step 1: Android 真机/模拟器冒烟**

```bash
cd frontend && flutter run -d <Android设备ID>
```

验证：
1. 首次触发 `rescheduleAll`（比如新建一个当天到期的任务）时弹出系统通知权限询问；
2. 允许后临时把某条通知时间改到 1 分钟后验证收到（同 Task 2 Step 9 手法，测完改回）；
3. 「我的」→「通知提醒」页四个开关能正常勾/取消勾，关闭某类后新建对应类型数据不再触发通知（可通过临时日志或断点观察 `computeNotifications` 返回结果）。

Expected: 权限询问只出现一次（第二次操作不再弹），通知按时到达，开关生效。

- [ ] **Step 2: 验证「问过一次不再问」**

在已经同意过权限的状态下，再触发一次数据变更（新建任务），确认**不会**再弹系统权限框。

Expected: 无权限框弹出，通知正常排程（因为已授权）。

- [ ] **Step 3: 验证拒绝权限的情况不崩溃**

在一台新模拟器/清空 App 数据后，故意在系统权限询问框点「不允许」，然后正常使用 App（建任务、设心愿期限）。

Expected: App 功能完全正常，只是不会收到通知，无报错无崩溃。

- [ ] **Step 4: 递增版本号**

打开 `frontend/pubspec.yaml`，把 `version: 1.0.0+1` 递增到下一个 build number（例如 `1.0.0+2`，具体以仓库当前值为准，读文件确认后再改）。

- [ ] **Step 5: 更新 HANDOFF.md**

打开 `docs/HANDOFF.md`，把专业化路线第 3 项标记完成：

```markdown
3. ~~本地通知做成真功能...~~ ✅ 2026-08-13 完成
```

同时把第 4 项（增量拉取+缓存恢复）标注为下一步（参照第 2 项已完成后第 3 项的标注格式）。

- [ ] **Step 6: 全量检查**

Run: `cd frontend && flutter analyze && flutter test`
Expected: 零警告，全部 PASS

- [ ] **Step 7: Commit + push**

```bash
cd frontend && git add pubspec.yaml
git add ../docs/HANDOFF.md
git commit -m "chore: 本地通知功能验证完毕，版本号递增，路线标记完成

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
git push
```

---

## Self-Review

**Spec coverage**：四场景（任务/心愿/胶囊/唤回）Task 1 全覆盖；排程触发时机（启动+数据变更防抖）Task 3 覆盖；权限申请（挂在 rescheduleAll、问一次不再问、Android 非精确闹钟）Task 2 覆盖；设置页（总开关+4 分开关）Task 4 覆盖；通知点击打开首页——用的是插件默认行为（点击通知启动/唤起 App 到当前页面，不做自定义跳转），未写显式代码是因为"不做深链"就是"不做任何点击回调处理"，符合 spec 的 YAGNI 结论，无需额外任务。14 天窗口、ID 幂等规则、默认时间——均在 Task 1/2 的实现代码里体现。

**占位符扫描**：全部步骤含完整代码，无 TBD/TODO。Task 5 Step 4 版本号具体值留給实现者读取当前值后递增，是因为版本号会随其他并行工作变动，不是偷懒占位——已明确给出"读文件确认后再改"的动作指引。

**类型一致性**：`PlannedNotification`/`computeNotifications`/`dormantRecallNotification`/`stableNotificationId`/`NotificationScheduler.I.rescheduleAll` 的签名在 Task 1→2→3→4 之间保持一致，逐处核对过。

**API 真实性核对**：写完 Task 2 后下载了 `flutter_local_notifications` 22.3.0 的真实包源码核对（不是凭记忆/旧版教程写的），修正了两处会编译失败的错误：顶层 `FlutterLocalNotificationsPlugin.initialize()` 的 `settings` 是命名参数、`zonedSchedule()` 全部字段都是命名参数（没有位置参数）。`AndroidNotificationDetails(channelId, channelName, {...})` 前两个是位置参数、`requestNotificationsPermission()`/`requestPermissions()`/`AndroidScheduleMode.inexactAllowWhileIdle`/`cancelAll()` 均核对存在。`timezone` 定为 `^0.11.1`（当前最新）。
