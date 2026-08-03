// 全功能回归测试：在模拟器上真跑 App，逐个页面点过去。
// 跑法：flutter test integration_test/app_test.dart -d <设备ID>
//
// App 本身已经没有任何 mock/假数据了：没登录就只有登录页，内容全来自云端。
// 所以这里用 MockClient 顶掉网络层，喂一份固定的"云端返回"，
// 这样回归测试既不打生产库、也不产生垃圾账号，结果还稳定可复现。
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:xinyuan/api/api.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/main.dart' as app;
import 'package:xinyuan/pages/wish_pages.dart';
import 'package:xinyuan/presets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 页面里有循环动画（流光/极光），pumpAndSettle 会卡死，统一用定帧推进
  Future<void> settle(WidgetTester t, [int ms = 1200]) async {
    final end = DateTime.now().add(Duration(milliseconds: ms));
    while (DateTime.now().isBefore(end)) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  /// 假装云端有一个登录用户和一份心愿清单
  http.Response jsonRes(Map<String, dynamic> b) => http.Response.bytes(
      utf8.encode(jsonEncode(b)), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});

  void stubCloud() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final wishes = [
      for (var i = 0; i < 20; i++)
        {
          '_id': 'w$i',
          'title': lifeGoals[i],
          'color': 'A8B8F8',
          'createdAt': now,
          'updatedAt': now,
        }
    ];
    ApiClient.http_ = MockClient((req) async {
      final p = req.url.path;
      if (p.endsWith('/auth/login') || p.endsWith('/auth/register')) {
        return jsonRes({
          'token': 'it-token',
          'profile': {'nickname': '松之', 'createdAt': now},
        });
      }
      if (p.endsWith('/sync/pull')) {
        return jsonRes({
          'now': now,
          'wishes': wishes,
          'profile': {'nickname': '松之', 'createdAt': now},
        });
      }
      return jsonRes(const {});
    });
  }

  Future<void> boot(WidgetTester t) async {
    stubCloud();
    await AppData.I.initSession(); // 和 main() 一样先装会话，再挂界面
    // App 现在是强制登录的，先登进去才有主界面可测
    await AppData.I.loginOrRegister('itester', 'pw123456');
    await t.pumpWidget(const app.XinyuanApp());
    await settle(t, 3500); // 等开屏动画走完（默认落在人生清单页）
  }

  Future<void> tapIcon(WidgetTester t, IconData icon, {int n = 0}) async {
    final f = find.byIcon(icon);
    expect(f, findsWidgets, reason: '找不到图标 $icon');
    await t.tap(f.at(n));
    await settle(t);
  }

  Future<void> back(WidgetTester t) async {
    await tapIcon(t, Icons.arrow_back_ios_new_rounded);
  }

  testWidgets('启动 → 三个 tab 都能进', (t) async {
    await boot(t);
    // 开屏后默认就是人生清单页
    expect(find.text('不留遗憾，活成自己想要的样子'), findsOneWidget);
    expect(find.textContaining('已实现'), findsWidgets);

    await tapIcon(t, Icons.calendar_today_outlined); // 任务页
    expect(find.text('这天还没有安排'), findsOneWidget);

    await tapIcon(t, Icons.person_outline_rounded);
    expect(find.text('荣誉陈列馆'), findsOneWidget); // 我的页
    expect(find.text('点亮世界'), findsOneWidget);
    expect(find.text('时光胶囊'), findsOneWidget);
    expect(find.text('人生清单编辑'), findsOneWidget);
  });

  testWidgets('我的 → 荣誉殿堂：成就表算得出来', (t) async {
    await boot(t);
    await tapIcon(t, Icons.person_outline_rounded);
    await t.tap(find.text('荣誉陈列馆'));
    await settle(t, 1500);
    expect(find.text('荣 誉 殿 堂'), findsOneWidget);
    expect(find.text('初试身手'), findsOneWidget);
    expect(find.text('三日之约'), findsOneWidget);
    await back(t);
  });

  testWidgets('我的 → 点亮世界：分区和计数正确', (t) async {
    await boot(t);
    await tapIcon(t, Icons.person_outline_rounded);
    await t.tap(find.text('点亮世界'));
    await settle(t, 1500);
    expect(find.text('点 亮 世 界'), findsOneWidget);
    expect(find.textContaining('全球（已点亮'), findsOneWidget);
    expect(find.text('亚洲'), findsWidgets);
    await back(t);
  });

  testWidgets('我的 → 清单编辑：垃圾桶进多选', (t) async {
    await boot(t);
    await tapIcon(t, Icons.person_outline_rounded);
    await t.tap(find.text('人生清单编辑'));
    await settle(t, 1500);
    expect(find.text('左滑删除，轻点修改，右上角批量删除'), findsOneWidget);
    await tapIcon(t, Icons.delete_outline_rounded); // 右上角垃圾桶
    expect(find.text('取消'), findsOneWidget);
    expect(find.textContaining('已选'), findsOneWidget);
    await t.tap(find.text('取消'));
    await settle(t);
    await back(t);
  });

  testWidgets('我的 → 时光胶囊', (t) async {
    await boot(t);
    await tapIcon(t, Icons.person_outline_rounded);
    await t.tap(find.text('时光胶囊'));
    await settle(t, 1500);
    expect(find.text('时光胶囊'), findsWidgets);
    await back(t);
  });

  testWidgets('任务页 → 成绩单：月度/年度/总计三档 + 海报弹层', (t) async {
    await boot(t);
    await tapIcon(t, Icons.calendar_today_outlined); // 先切到任务页
    await tapIcon(t, Icons.ios_share_rounded); // 右上角分享
    expect(find.text('人生清单'), findsWidgets);
    expect(find.text('月度'), findsOneWidget);
    expect(find.text('年度'), findsOneWidget);
    expect(find.text('总计'), findsOneWidget);

    await t.tap(find.text('年度'));
    await settle(t);
    await t.tap(find.text('总计'));
    await settle(t);

    await t.tap(find.text('分享'));
    await settle(t, 1500);
    expect(find.text('分享图片'), findsOneWidget); // 海报弹层出来了
    await t.tapAt(const Offset(200, 60)); // 点空白关掉
    await settle(t);
  });

  testWidgets('人生清单页 → 分享海报', (t) async {
    await boot(t);
    await tapIcon(t, Icons.ios_share_rounded); // 人生清单页右上角分享
    await settle(t, 1500);
    expect(find.text('分享图片'), findsOneWidget);
    await t.tapAt(const Offset(200, 60));
    await settle(t);
  });

  testWidgets('心愿详情（进行中）能打开', (t) async {
    await boot(t);
    final title = AppData.I.activeWishes.first.title;
    await t.tap(find.text(title).first);
    await settle(t, 1500);
    expect(find.text(title), findsWidgets);
    await back(t);
  });

  testWidgets('完成心愿 → 已实现详情页各区块齐全', (t) async {
    await boot(t);
    final w = AppData.I.activeWishes.first;
    AppData.I.addNote(w, '测试笔记：一路上的记录');
    AppData.I.completeWish(w, quote: '这一天终于到了', location: '杭州', heroIndex: 0);
    await settle(t, 800);

    // 顶部统计区裹在 IgnorePointer 里、坐标随机型变动，直接推路由更稳
    Navigator.push(
      t.element(find.byType(Scaffold).first),
      MaterialPageRoute(builder: (_) => DoneWishPage(wish: w)),
    );
    await settle(t, 2000);

    expect(find.textContaining('第 '), findsWidgets); // 金色「第 N 个实现」徽章
    expect(find.text('这条心愿的一生'), findsOneWidget); // 时间线
    expect(find.textContaining('条记录'), findsOneWidget); // 过程笔记区标题
    expect(find.text('测试笔记：一路上的记录'), findsOneWidget); // 笔记正文
    expect(find.text('天走完'), findsOneWidget); // 数据条
  });

  testWidgets('完成任务 → 点亮成就弹窗 + 世界地图点亮', (t) async {
    await boot(t);
    // 「点亮世界」应当因为上一条用例填的地点而亮起中国/亚洲
    final task = AppData.I.addTask('测试任务', DateTime.now());
    await settle(t, 500);
    AppData.I.toggleTask(task); // 完成 → 触发「初试身手」
    await settle(t, 2500);
    expect(find.text('新 荣 誉 到 手'), findsOneWidget); // 奖杯弹窗
    expect(find.text('初试身手'), findsWidgets);
    await t.tap(find.text('轻点任意处收起'));
    await settle(t, 1000);
    AppData.I.deleteTask(task); // 收拾干净
  });
}
