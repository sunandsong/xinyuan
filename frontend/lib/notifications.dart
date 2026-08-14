import 'data.dart';

/// 一条待排的本地通知：只是数据，不碰任何插件 API，方便脱离设备单测。
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.at,
  });
  final int id;
  final String category; // 'task' | 'wish' | 'letter' | 'dormant'
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

/// 只排未来 14 天内的：够用又不会撞 iOS 64 条待定上限。
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

  return result;
}

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
