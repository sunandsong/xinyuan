// 纯逻辑单测（不需要模拟器）：数据序列化 + 成就计算。
// 界面流程由 integration_test/app_test.dart 在真机上覆盖。
import 'package:flutter/material.dart';
import 'package:xinyuan/pages/rank_page.dart';
import 'package:xinyuan/api/api.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/pages/login_page.dart';
import 'package:xinyuan/tabs/me_tab.dart';
import 'package:xinyuan/ui.dart';
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
    d.achvUnlocked['first_task'] = 1730000000000;
    final kept = achievements(d).firstWhere((a) => a.name == '初试身手');
    expect(kept.done, isTrue);
    d.achvUnlocked.remove('first_task');
  });

  testWidgets('奖杯弹窗：能弹出、显示名称与进度，轻点收起', (tester) async {
    final a = achievements(AppData.I).firstWhere((x) => x.name == '三十而立');
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    showTrophyDialog(ctx, a);
    await tester.pumpAndSettle();
    expect(find.text('三十而立'), findsOneWidget);
    expect(find.text('连续 30 天完成任务'), findsOneWidget);
    expect(find.text('${a.value.clamp(0, a.goal)} / 30'), findsOneWidget,
        reason: '未点亮时底部应显示进度');

    await tester.tap(find.text('轻点任意处收起'));
    await tester.pumpAndSettle();
    expect(find.text('三十而立'), findsNothing);
  });

  testWidgets('注册表单：登录态只有一个密码框，注册态要两个且必须一致', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: LoginForm())),
    ));

    // 登录态：只有一个密码框
    expect(find.text('再输一次密码'), findsNothing);

    // 切到注册态：确认密码框出现
    await tester.tap(find.text('没有账号？去注册'));
    await tester.pumpAndSettle();
    expect(find.text('再输一次密码'), findsOneWidget);
    expect(find.text('注册并登录'), findsOneWidget);

    // 两次密码不一致：本地拦下，报错且不发请求（发了会因无网抛异常，报错文案就不是这句）
    await tester.enterText(find.byType(TextField).at(0), 'songzhang');
    await tester.enterText(find.byType(TextField).at(1), 'pw123456');
    await tester.enterText(find.byType(TextField).at(2), 'pw654321');
    await tester.tap(find.text('注册并登录'));
    await tester.pump();
    expect(find.text('两次输入的密码不一致'), findsOneWidget);

    // 切回登录态：确认框收起，之前填的确认密码被清掉
    await tester.tap(find.text('已有账号？去登录'));
    await tester.pumpAndSettle();
    expect(find.text('再输一次密码'), findsNothing);
    await tester.tap(find.text('没有账号？去注册'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text,
        isEmpty,
        reason: '来回切换后确认密码框应清空，避免残留旧值');
  });

  testWidgets('未登录预览：点击被拦下跳登录，滚动仍然能用', (tester) async {
    final d = AppData.I;
    d.signedIn = false;
    var blocked = 0;

    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewShield(
          onBlocked: () => blocked++,
          child: ListView(
            controller: scroll,
            children: [
              for (var i = 0; i < 50; i++)
                SizedBox(
                  height: 80,
                  child: GestureDetector(
                    onTap: () => fail('未登录时不该触发卡片自己的点击'),
                    child: Text('心愿 $i'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ));

    // 点击：被罩子接住，底下的卡片没反应
    await tester.tap(find.text('心愿 0'));
    await tester.pump();
    expect(blocked, 1, reason: '任何点击都该跳登录');

    // 滚动：手势输给列表，浏览不受影响
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    expect(scroll.offset, greaterThan(0), reason: '只读不等于不能翻');
    expect(blocked, 1, reason: '滑动不该被当成点击');

    // 登录后罩子整个消失
    d.signedIn = true;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PreviewShield(
          onBlocked: () => blocked++,
          child: const Text('内容'),
        ),
      ),
    ));
    expect(find.byType(GestureDetector), findsNothing, reason: '登录后不该还罩着');
    d.signedIn = false;
  });

  testWidgets('未登录点「我的」页的入口：不跳页，先弹登录', (tester) async {
    final d = AppData.I;
    d.signedIn = false;
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: MeTab())));
    await tester.pumpAndSettle();

    for (final entry in ['人生清单编辑', '荣誉陈列馆', '点亮世界', '时光胶囊']) {
      await tester.tap(find.text(entry));
      await tester.pumpAndSettle();
      expect(find.text('登录后，心愿与勋章将云端同步'), findsOneWidget,
          reason: '$entry 未登录时应该先弹登录，而不是直接进去');
      // 关掉弹层，确认没有跳走（「我的」页还在）
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('荣誉陈列馆'), findsOneWidget, reason: '不该离开「我的」页');
    }
  });

  testWidgets('平板整体放大：手机原样，平板按等效尺寸渲染再缩放', (tester) async {
    Future<MediaQueryData> mqAt(Size size, EdgeInsets padding) async {
      late MediaQueryData got;
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: size, padding: padding, viewPadding: padding),
        child: Builder(
          builder: (outer) => tabletTextScale(
            outer,
            Builder(builder: (inner) {
              got = MediaQuery.of(inner);
              return const SizedBox();
            }),
          ),
        ),
      ));
      return got;
    }

    // iPhone 16 Pro 逻辑尺寸：最短边 393 —— 一点不动
    final phone = await mqAt(const Size(393, 852), const EdgeInsets.only(top: 59));
    expect(phone.size, const Size(393, 852), reason: '手机上不该缩放');
    expect(phone.padding.top, 59);

    // iPad Pro 11 逻辑尺寸：最短边 834 —— 按 1.4 缩小逻辑尺寸，再整体放大回去
    final pad = await mqAt(const Size(834, 1210), const EdgeInsets.only(top: 24));
    expect(pad.size.width, closeTo(834 / 1.4, .01),
        reason: '布局要按等效窄屏来排，间距/行高才会跟着变大');
    expect(pad.padding.top, closeTo(24 / 1.4, .01),
        reason: '安全区也要一起缩，否则避让位置算错');
    expect(find.byType(Transform), findsWidgets, reason: '缩回真实尺寸靠 Transform');

    // 光看 MediaQuery 的值不够——外层是紧约束，孩子很可能仍按真实尺寸排版，
    // 再放大就整个溢出屏幕。必须验孩子真实拿到的布局宽度。
    final box = tester.renderObject<RenderBox>(find.byType(SizedBox).last);
    expect(box.size.width, closeTo(834 / 1.4, .01),
        reason: '孩子必须真的按等效窄屏排版，否则会被放大到屏幕外');
  });

  testWidgets('排行榜：四个榜可切换，我那行高亮，没上榜也显示自己的数字', (tester) async {
    final d = AppData.I;
    d.signedIn = true;
    final asked = <String>[];
    ApiClient.http_ = MockClient((req) async {
      final by = req.url.queryParameters['by'] ?? '';
      asked.add(by);
      return http.Response.bytes(
          utf8.encode(jsonEncode({
            'by': by,
            'top': by == 'place'
                ? []
                : [
                    {'rank': 1, 'nickname': '别人', 'count': 9, 'isMe': false},
                    {'rank': 2, 'nickname': '松之', 'count': 5, 'isMe': true},
                  ],
            'me': {'rank': by == 'place' ? null : 2, 'count': by == 'place' ? 0 : 5},
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
    showRankSheet(ctx); // 不能在 build 里调，会 setState during build
    await tester.pumpAndSettle();

    expect(asked, ['wish'], reason: '打开时只请求当前榜');
    expect(find.text('别人'), findsOneWidget);
    expect(find.text('松之（我）'), findsOneWidget, reason: '我那行要标出来');
    expect(find.text('第 2 名 · 5'), findsOneWidget);

    // 切到「奖杯」榜：换一次请求
    await tester.tap(find.text('奖杯'));
    await tester.pumpAndSettle();
    expect(asked, ['wish', 'achv']);

    // 切回「心愿」：已经拿过就不再请求
    await tester.tap(find.text('心愿'));
    await tester.pumpAndSettle();
    expect(asked, ['wish', 'achv'], reason: '看过的榜要走缓存，别白烧额度');

    // 空榜：给引导语，并且我的名次显示「还没上榜」
    await tester.tap(find.text('足迹'));
    await tester.pumpAndSettle();
    expect(find.text('还没有人上榜，你可以是第一个'), findsOneWidget);
    expect(find.text('还没上榜'), findsOneWidget);

    d.signedIn = false;
    ApiClient.http_ = http.Client();
  });
}
