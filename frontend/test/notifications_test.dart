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
      Wish(
        id: id,
        title: title,
        color: red,
        createdAt: now,
        targetAt: targetAt,
        done: done,
      );
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
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('14 天窗口外的任务不排，窗口内的最后一天（第 13 天）排', () {
      // now = 8/13（第 0 天）。今天起 14 天覆盖第 0~13 天，即到 8/26；
      // 8/27 是第 14 天，超出窗口。
      final result = computeNotifications(
        tasks: [
          task('t1', DateTime(2026, 8, 27)), // 第 14 天，超窗口
          task('t2', DateTime(2026, 8, 26)), // 第 13 天，窗口内最后一天
        ],
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.id, stableNotificationId('task_day_2026-8-26'));
    });

    test('分类开关关闭时任务类不排', () {
      final result = computeNotifications(
        tasks: [task('t1', DateTime(2026, 8, 13))],
        wishes: [],
        letters: [],
        now: now,
        enabledCategories: {'wish', 'letter', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });

  group('心愿期限', () {
    test('目标日期前 3 天：排一条"还有 3 天到期"', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 16), title: '看极光')],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.category, 'wish');
      expect(result.first.body, '『看极光』还有 3 天到期');
      expect(result.first.at, DateTime(2026, 8, 13, 9, 0));
    });

    test('目标日期当天：排一条"就是今天了"', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13), title: '看极光')],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.body, '『看极光』就是今天了');
      expect(result.first.at, DateTime(2026, 8, 13, 9, 0));
    });

    test('目标日期就是今天：只命中"当天"这条规则，不重复', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13))],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
    });

    test('已完成的心愿不排', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 16), done: true)],
        now: now,
        enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('没设期限的心愿不排', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1')],
        now: now,
        enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('心愿开关关闭时不排', () {
      final result = computeNotifications(
        tasks: [],
        letters: [],
        wishes: [wish('w1', targetAt: DateTime(2026, 8, 13))],
        now: now,
        enabledCategories: {'task', 'letter', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });

  group('胶囊开启', () {
    test('开启日当天：排一条固定文案，时间 10:00', () {
      final result = computeNotifications(
        tasks: [],
        wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 13))],
        now: now,
        enabledCategories: allCats,
      );
      expect(result.length, 1);
      expect(result.first.category, 'letter');
      expect(result.first.body, '你写给自己的信，今天可以打开了');
      expect(result.first.at, DateTime(2026, 8, 13, 10, 0));
    });

    test('开启日还没到：不排', () {
      final result = computeNotifications(
        tasks: [],
        wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 20))],
        now: now,
        enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('开启日已过：不排', () {
      final result = computeNotifications(
        tasks: [],
        wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 10))],
        now: now,
        enabledCategories: allCats,
      );
      expect(result, isEmpty);
    });

    test('胶囊开关关闭时不排', () {
      final result = computeNotifications(
        tasks: [],
        wishes: [],
        letters: [letter('l1', DateTime(2026, 8, 13))],
        now: now,
        enabledCategories: {'task', 'wish', 'dormant'},
      );
      expect(result, isEmpty);
    });
  });

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
        activeWishCount: 48,
        now: now,
        enabled: false,
      );
      expect(n, isNull);
    });
  });
}
