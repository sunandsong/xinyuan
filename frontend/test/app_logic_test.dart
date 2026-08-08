// 全 App 核心逻辑单测：心愿 / 里程碑 / 笔记照片 / 任务日历 / 连续打卡 / 时光胶囊 /
// 成就 / 里程碑模板。不联网、不开模拟器，`flutter test` 直接跑。
// 界面交互见 widget_test.dart，真机流程见 integration_test/app_test.dart。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/pages/tree_page.dart';
import 'package:xinyuan/presets.dart';
import 'package:xinyuan/theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 点亮成就会写本地存储，测试里给个内存版，不然 unlockAchvs 会炸
  SharedPreferences.setMockInitialValues({});
  final d = AppData.I;

  // 每个用例都从空数据开始，互不干扰（AppData 是单例，构造时会塞 50 个默认心愿）
  setUp(() {
    d.wishes.clear();
    d.tasks.clear();
    d.letters.clear();
    d.achvUnlocked.clear();
  });

  const red = Color(0xFFE05A5A);
  const blue = Color(0xFF6FA8DC);

  group('心愿', () {
    test('新建的心愿默认未完成，进行中列表里能找到', () {
      final w = d.addWish('跑完五公里', red, desc: '慢慢来');
      expect(w.done, isFalse);
      expect(w.desc, '慢慢来');
      expect(d.activeWishes, contains(w));
      expect(d.doneWishes, isEmpty);
    });

    test('完成心愿：记完成时间，空感言用兜底文案，配图下标取模不越界', () {
      final w = d.addWish('看一次日出', red);
      d.completeWish(w, quote: '', location: '', heroIndex: 999);
      expect(w.done, isTrue);
      expect(w.doneAt, isNotNull);
      expect(w.quote, '这一天，终于到了。', reason: '没写感言应该给一句兜底');
      expect(w.location, isNull, reason: '空字符串地点应存成 null，地图上不落点');
      expect(w.heroIndex, 999 % AppData.heroes.length);
      expect(d.activeWishes, isEmpty);
      expect(d.doneWishes, [w]);
    });

    test('反悔：撤销完成会清掉时间和地点，但当时写的话留着', () {
      final w = d.addWish('去看一次海', red);
      d.completeWish(w, quote: '终于见到了', location: '青岛', heroIndex: 0);
      d.uncompleteWish(w);
      expect(w.done, isFalse);
      expect(w.doneAt, isNull);
      expect(w.location, isNull);
      expect(w.quote, '终于见到了', reason: '感言是记忆，不该跟着撤销一起没');
    });

    test('已完成心愿按完成时间倒序，序号按正序从 1 开始', () {
      final a = d.addWish('第一个', red);
      final b = d.addWish('第二个', blue);
      d.completeWish(a, quote: 'a', heroIndex: 0);
      a.doneAt = DateTime(2026, 1, 1);
      d.completeWish(b, quote: 'b', heroIndex: 0);
      b.doneAt = DateTime(2026, 6, 1);

      expect(d.doneWishes.first, b, reason: '最近完成的排最前');
      expect(d.doneNumberOf(a), 1);
      expect(d.doneNumberOf(b), 2);
    });

    test('删除是软删除：本地立刻消失，但带着 deleted 标记同步给云端', () {
      final w = d.addWish('学会游泳', red);
      d.deleteWish(w);
      expect(d.wishes, isEmpty);
      expect(w.deleted, isTrue, reason: '标记要留着，否则云端不知道这条被删了');
    });

    test('批量删除一次清掉多个', () {
      final list = [
        d.addWish('a', red),
        d.addWish('b', red),
        d.addWish('c', red),
      ];
      d.deleteWishes(list.take(2));
      expect(d.wishes.length, 1);
      expect(d.wishes.single.title, 'c');
    });
  });

  group('里程碑', () {
    test('拆解后进度随勾选变化，全勾完是 1.0', () {
      final w = d.addWish('学会开车拿到驾照', red);
      d.addSteps(w, ['报名驾校', '通过科目一', '拿到驾照']);
      expect(w.steps.length, 3);
      expect(w.stepProgress, 0);

      d.toggleStep(w, w.steps[0]);
      expect(w.doneStepCount, 1);
      expect(w.stepProgress, closeTo(1 / 3, 1e-9));
      expect(w.steps[0].doneAt, isNotNull);

      d.toggleStep(w, w.steps[1]);
      d.toggleStep(w, w.steps[2]);
      expect(w.stepProgress, 1.0);
    });

    test('取消勾选会把完成时间也清掉', () {
      final w = d.addWish('学一门乐器', red);
      final s = d.addStep(w, '买一把吉他');
      d.toggleStep(w, s);
      d.toggleStep(w, s);
      expect(s.done, isFalse);
      expect(s.doneAt, isNull);
    });

    test('没有里程碑时进度是 null（界面据此不显示进度条）', () {
      final w = d.addWish('随便想想', red);
      expect(w.stepProgress, isNull);
    });

    test('改名和删除', () {
      final w = d.addWish('出国旅行一次', red);
      final s = d.addStep(w, '办护照');
      d.renameStep(w, s, '办护照和签证');
      expect(w.steps.single.title, '办护照和签证');
      d.deleteStep(w, s);
      expect(w.steps, isEmpty);
    });
  });

  group('笔记与照片', () {
    test('笔记新的排在前面', () {
      final w = d.addWish('读完 100 本书', red);
      d.addNote(w, '第一条');
      d.addNote(w, '第二条');
      expect(w.notes.map((n) => n.text).toList(), ['第二条', '第一条']);
    });

    test('删笔记只删指定那条', () {
      final w = d.addWish('写点什么', red);
      final n1 = d.addNote(w, '留着');
      d.addNote(w, '删掉');
      d.deleteNote(w, w.notes.first);
      expect(w.notes.single, n1);
    });

    test('设封面 = 把照片挪到最后（展示处取 photos.last）', () {
      final w = d.addWish('学会拍照与修图', red);
      d.addWishPhoto(w, 'a.jpg');
      d.addWishPhoto(w, 'b.jpg');
      d.addWishPhoto(w, 'c.jpg');
      d.setCoverPhoto(w, 'a.jpg');
      expect(w.photos, ['b.jpg', 'c.jpg', 'a.jpg']);

      d.removeWishPhoto(w, 'c.jpg');
      expect(w.photos, ['b.jpg', 'a.jpg']);
    });

    test('给不存在的照片设封面不会动数据', () {
      final w = d.addWish('拍照', red);
      d.addWishPhoto(w, 'a.jpg');
      d.setCoverPhoto(w, '不存在.jpg');
      expect(w.photos, ['a.jpg']);
    });
  });

  group('任务与日历', () {
    test('按天取任务只认同一天，跨天不串', () {
      final today = DateTime.now();
      final t1 = d.addTask('晨跑', today);
      d.addTask('明天的事', today.add(const Duration(days: 1)));
      expect(d.tasksOn(today), [t1]);
    });

    test('任务颜色：自己的 > 关联心愿的 > 灰色兜底', () {
      final w = d.addWish('跑步', blue);
      final own = d.addTask('自带色', DateTime.now(), color: red);
      final fromWish = d.addTask('跟心愿', DateTime.now(), wishId: w.id);
      final bare = d.addTask('杂事', DateTime.now());

      expect(d.taskColor(own), red);
      expect(d.taskColor(fromWish), blue);
      expect(d.taskColor(bare), T.grey);
      expect(d.wishOf(bare), isNull);
    });

    test('日历圆点取当天第一个有色任务，全无色则灰', () {
      final day = DateTime.now();
      expect(d.dotOn(day), isNull, reason: '当天没任务不该有点');
      d.addTask('杂事', day);
      expect(d.dotOn(day), T.grey);
      d.addTask('有色', day, color: red);
      expect(d.dotOn(day), red);
    });

    test('心愿下的任务按日期倒序', () {
      final w = d.addWish('备考', red);
      final old = d.addTask('早的', DateTime(2026, 1, 1), wishId: w.id);
      final recent = d.addTask('晚的', DateTime(2026, 6, 1), wishId: w.id);
      expect(d.tasksOfWish(w.id), [recent, old]);
    });

    test('删任务是软删除，列表里没了但标记还在', () {
      final t = d.addTask('临时', DateTime.now());
      d.deleteTask(t);
      expect(d.tasks, isEmpty);
      expect(t.deleted, isTrue);
    });
  });

  group('连续打卡天数', () {
    Task doneOn(int daysAgo) {
      final t = d.addTask(
          '第 $daysAgo 天', DateTime.now().subtract(Duration(days: daysAgo)));
      t.done = true;
      return t;
    }

    test('今天还没动不清零：从昨天起算', () {
      doneOn(1);
      expect(d.streakDays, 1, reason: '今天还没打卡，昨天攒的连续不该直接归零');
    });

    test('不只任务：实现心愿、景区打卡也算一天记录', () {
      final w = d.addWish('去看海', const Color(0xFFE05A5A));
      w.doneAt = DateTime.now().subtract(const Duration(days: 1));
      w.done = true;
      d.checkIn('故宫'); // 今天
      expect(d.streakDays, greaterThanOrEqualTo(2),
          reason: '昨天实现心愿 + 今天打卡 = 至少连续 2 天');
      d.checkins.clear();
    });

    test('从今天往前连着数', () {
      doneOn(0);
      doneOn(1);
      doneOn(2);
      expect(d.streakDays, 3);
    });

    test('中间断一天就停在断点前', () {
      doneOn(0);
      doneOn(1);
      // 第 2 天空着
      doneOn(3);
      expect(d.streakDays, 2);
    });

    test('同一天完成多个任务只算一天', () {
      doneOn(0);
      doneOn(0);
      expect(d.streakDays, 1);
      expect(d.doneTaskCount, 2);
    });

    test('没勾完成的任务不算数', () {
      d.addTask('光建了没做', DateTime.now());
      expect(d.streakDays, 0);
    });
  });

  group('时光胶囊', () {
    test('没到开启日期就打不开，到了或过了就能开', () {
      final future = d.addLetter('给十年后', 'hi', DateTime.now().add(
          const Duration(days: 3650)));
      final past = d.addLetter('去年写的', 'hi', DateTime(2020, 1, 1));
      expect(d.isLetterOpen(future), isFalse);
      expect(d.isLetterOpen(past), isTrue);
    });

    test('开启时间正好是此刻算能开（边界不卡人）', () {
      final l = d.addLetter('刚好', 'hi',
          DateTime.now().subtract(const Duration(seconds: 1)));
      expect(d.isLetterOpen(l), isTrue);
    });
  });

  group('成就', () {
    test('阈值到了才算达成', () {
      for (var i = 0; i < 9; i++) {
        d.addTask('t$i', DateTime.now()).done = true;
      }
      final at9 = achievements(d).firstWhere((a) => a.name == '渐入佳境');
      expect(at9.met, isFalse, reason: '9 个任务还差一个');

      d.addTask('t10', DateTime.now()).done = true;
      final at10 = achievements(d).firstWhere((a) => a.name == '渐入佳境');
      expect(at10.met, isTrue);
    });

    test('点亮记录让成就永久亮着，哪怕条件后来不满足了', () {
      d.unlockAchvs(['first_task']); // 传 slug，不是显示名
      expect(d.achvUnlocked.containsKey('first_task'), isTrue);
      final a = achievements(d).firstWhere((x) => x.name == '初试身手');
      expect(a.met, isFalse, reason: '现在一个任务都没有');
      expect(a.done, isTrue, reason: '但拿到过就永久算拿到');
    });

    test('重复点亮不覆盖第一次的时间', () {
      d.unlockAchvs(['first_wish']);
      final first = d.achvUnlocked['first_wish'];
      d.unlockAchvs(['first_wish']);
      expect(d.achvUnlocked['first_wish'], first);
    });

    test('每个成就都有奖杯图标名，且互不重复', () {
      final slugs = achievements(d).map((a) => a.slug).toList();
      expect(slugs.every((s) => s.isNotEmpty), isTrue);
      expect(slugs.toSet().length, slugs.length, reason: '图标文件名不能撞');
    });

    test('14 枚奖杯图标都真的打进包里了', () async {
      for (final a in achievements(d)) {
        expect(await rootBundle.load(a.icon).then((_) => true, onError: (_) => false),
            isTrue,
            reason: '${a.name} 的图标 ${a.icon} 找不到——'
                '要么文件没放，要么 slug 和文件名对不上');
      }
    });
  });

  group('里程碑模板（本地拆解，不走付费 AI）', () {
    test('收录过的心愿走精确模板', () {
      expect(stepTemplateFor('看一次日出'), isNotEmpty);
      expect(stepTemplateFor('看一次日出').first, '选好一个看日出的地方');
    });

    test('没收录的靠关键词兜底', () {
      final steps = stepTemplateFor('学会滑雪');
      expect(steps, isNotEmpty, reason: '「学会」应该命中关键词模板');
      expect(steps.first, '找到教程或老师');
    });

    test('实在匹配不上就返回空，界面不硬塞不相干的步骤', () {
      expect(stepTemplateFor('qwerty'), isEmpty);
    });
  });

  group('防撞车 / 老数据迁移', () {
    test('连续生成的 id 互不相同，且带随机段（多设备同毫秒也不会撞）', () {
      final ids = <String>{};
      for (var i = 0; i < 500; i++) {
        ids.add(d.addWish('心愿$i', red).id);
      }
      expect(ids.length, 500, reason: '同一进程内不能撞');

      // 结构：w_<毫秒36><序号36><4 位随机36>
      final one = ids.first;
      expect(one.startsWith('w_'), isTrue);
      expect(one.length, greaterThan(10), reason: '光靠毫秒+序号太短，必须带随机段');

      // 两条同毫秒生成的 id，去掉随机段之后可能一样，带上就不一样了
      final tails = ids.map((s) => s.substring(s.length - 4)).toSet();
      expect(tails.length, greaterThan(1), reason: '随机段得真的在变');
    });

    test('老数据用中文名当 key，加载后自动迁移成 slug，时间不丢', () {
      d.achvUnlocked
        ..clear()
        ..addAll({'初试身手': 1730000000000, 'first_wish': 1740000000000});
      d.migrateAchvKeysForTest();

      expect(d.achvUnlocked.containsKey('初试身手'), isFalse, reason: '中文名 key 要换掉');
      expect(d.achvUnlocked['first_task'], 1730000000000, reason: '点亮时间不能丢');
      expect(d.achvUnlocked['first_wish'], 1740000000000, reason: '已经是 slug 的原样保留');

      // 迁移后成就仍然是点亮状态（改文案不会让勋章熄灭）
      final a = achievements(d).firstWhere((x) => x.name == '初试身手');
      expect(a.done, isTrue);
      expect(a.recordedAt, 1730000000000);
    });

    test('同一枚成就两种 key 都有时，保留更早的那次点亮', () {
      d.achvUnlocked
        ..clear()
        ..addAll({'初试身手': 1700000000000, 'first_task': 1750000000000});
      d.migrateAchvKeysForTest();
      expect(d.achvUnlocked['first_task'], 1700000000000,
          reason: '拿到即永久，应该记最早那次');
    });
  });
}
