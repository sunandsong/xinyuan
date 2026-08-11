// 心愿详情页「N 人也想做 · M 人已实现」：有数据才显示，没人/失败整行消失
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xinyuan/api/api.dart';
import 'package:xinyuan/pages/wish_pages.dart';

http.Response _json(Map<String, dynamic> body) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: Scaffold(body: CrowdStatsLine(title: '看一次极光')),
  ));
  await tester.pumpAndSettle();
}

void main() {
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
}
