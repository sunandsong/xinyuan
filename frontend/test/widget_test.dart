// 纯逻辑单测（不需要模拟器）：数据序列化 + 成就计算。
// 界面流程由 integration_test/app_test.dart 在真机上覆盖。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/pages/tree_page.dart';

void main() {
  // AppData 构造时会注册生命周期观察者，需要先初始化测试绑定
  TestWidgetsFlutterBinding.ensureInitialized();

  test('心愿序列化能原样还原', () {
    final w = Wish(
      id: 'w1',
      title: '跑完五公里',
      color: const Color(0xFFA8B8F8),
      createdAt: DateTime(2026, 1, 1),
      desc: '慢慢来',
    )
      ..done = true
      ..doneAt = DateTime(2026, 8, 2)
      ..location = '杭州'
      ..quote = '做到了'
      ..steps.add(WishStep(id: 's1', title: '先跑一公里', done: true))
      ..notes.add(WishNote(id: 'n1', text: '今天状态不错', at: DateTime(2026, 5, 1)))
      ..photos.add('https://x/a.jpg');

    final back = Wish.fromJson(w.toJson());
    expect(back.title, w.title);
    expect(back.color.toARGB32(), w.color.toARGB32());
    expect(back.done, isTrue);
    expect(back.doneAt, w.doneAt);
    expect(back.location, '杭州');
    expect(back.steps.single.done, isTrue);
    expect(back.notes.single.text, '今天状态不错');
    expect(back.photos.single, 'https://x/a.jpg');
    expect(back.doneStepCount, 1);
    expect(back.stepProgress, 1.0);
  });

  test('任务与时光胶囊序列化能原样还原', () {
    final t = Task(
      id: 't1',
      title: '晨跑',
      day: DateTime(2026, 8, 2),
      wishId: 'w1',
      done: true,
      color: const Color(0xFF5EB87C),
    );
    final tb = Task.fromJson(t.toJson());
    expect(tb.title, '晨跑');
    expect(tb.done, isTrue);
    expect(tb.wishId, 'w1');
    expect(sameDay(tb.day, t.day), isTrue);

    final l = Letter(
      id: 'l1',
      title: '给十年后的自己',
      content: '你好',
      openAt: DateTime(2036, 1, 1),
    );
    final lb = Letter.fromJson(l.toJson());
    expect(lb.title, '给十年后的自己');
    expect(lb.openAt, l.openAt);
    expect(AppData.I.isLetterOpen(lb), isFalse); // 还没到开启日
  });

  test('成就：完成任务后进度跟着涨，点亮记录让它永久亮着', () {
    final d = AppData.I;
    final before = achievements(d).firstWhere((a) => a.name == '初试身手');
    expect(before.goal, 1);

    final task = d.addTask('测试任务', DateTime.now());
    d.toggleTask(task); // 完成
    final after = achievements(d).firstWhere((a) => a.name == '初试身手');
    expect(after.met, isTrue, reason: '完成 1 个任务应满足「初试身手」');

    // 断签模拟：把任务删掉，条件不再满足
    d.deleteTask(task);
    final gone = achievements(d).firstWhere((a) => a.name == '初试身手');
    expect(gone.met, isFalse);
    // 但只要有点亮记录，勋章依然算点亮（拿到即永久）
    d.achvUnlocked['初试身手'] = 1730000000000;
    final kept = achievements(d).firstWhere((a) => a.name == '初试身手');
    expect(kept.done, isTrue);
    d.achvUnlocked.remove('初试身手');
  });
}
