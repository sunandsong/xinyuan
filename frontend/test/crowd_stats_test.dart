// 心愿详情页「N 人也想做 · M 人已实现」：有数据才显示，没人/失败整行消失
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xinyuan/api/api.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/pages/wish_pages.dart';

http.Response _json(Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: CrowdStatsLine(title: '看一次极光')),
  ));
  await tester.pumpAndSettle();
  // CrowdStatsLine 现在会读 AppData.I.showRank（排行榜开关），首次触碰单例会走
  // 构造函数播种 50 条清单，顺带起一个 300ms 的通知刷新防抖定时器。
  // 泵过去让它烧完，否则测试收尾时报 pending timer。
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // 这些用例测的是「有数据时怎么显示」，登录态是前置条件，统一置上
  setUp(() {
    AppData.I.signedIn = true;
    AppData.I.showRank = true;
  });
  tearDown(() {
    AppData.I.signedIn = false;
    AppData.I.showRank = true;
  });

  testWidgets('有人也想做：显示人数，完成为 0 时不提已实现', (tester) async {
    ApiClient.http_ = MockClient((_) async => _json({'wanted': 3, 'done': 0}));
    await _pump(tester);
    expect(find.text('🌏 3 人也想做'), findsOneWidget);
  });

  testWidgets('也有人实现过：两段都显示', (tester) async {
    ApiClient.http_ = MockClient((_) async => _json({'wanted': 5, 'done': 2}));
    await _pump(tester);
    expect(find.text('🌏 5 人也想做 · 2 人已实现'), findsOneWidget);
  });

  testWidgets('没别人设过：整行不显示', (tester) async {
    ApiClient.http_ = MockClient((_) async => _json({'wanted': 0, 'done': 0}));
    await _pump(tester);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('接口失败（比如没登录）：整行不显示', (tester) async {
    ApiClient.http_ =
        MockClient((_) async => http.Response('{"error":"unauthorized"}', 401));
    await _pump(tester);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('排行榜开关关掉：整行不显示，也不发请求', (tester) async {
    var called = false;
    ApiClient.http_ = MockClient((_) async {
      called = true;
      return _json({'wanted': 9, 'done': 4});
    });
    AppData.I.showRank = false;
    await _pump(tester);
    expect(find.byType(Text), findsNothing);
    expect(called, isFalse, reason: '藏起来了就别再问后端要数据');
  });

  testWidgets('没登录：整行不显示，也不发请求', (tester) async {
    var called = false;
    ApiClient.http_ = MockClient((_) async {
      called = true;
      return _json({'wanted': 9, 'done': 4});
    });
    AppData.I.signedIn = false;
    await _pump(tester);
    expect(find.byType(Text), findsNothing);
    expect(called, isFalse, reason: '没登录这个接口本来就是 401，别白发');
  });
}
