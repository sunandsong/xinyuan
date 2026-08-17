// 登录弹层回归：登录成功后弹层必须自己关掉（用户报过「登录后停在登录界面」）
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xinyuan/api/api.dart';
import 'package:xinyuan/consent.dart';
import 'package:xinyuan/data.dart';
import 'package:xinyuan/home.dart';
import 'package:xinyuan/pages/login_page.dart';
import 'package:xinyuan/ui.dart';

http.Response _json(Map<String, dynamic> body, [int code = 200]) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), code,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('登录成功后弹层自动关闭', (tester) async {
    // 登录会先过隐私合规弹窗（未同意时），这两个用例测的是登录成功后弹层怎么关，
    // 不是合规弹窗本身——直接标记成已同意，跳过那一步
    SharedPreferences.setMockInitialValues({'privacy_consented_v1': true});
    await ConsentState.I.load();
    ApiClient.http_ = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/auth/login')) {
        return _json({
          'token': 'test-token',
          'profile': {'nickname': '松之', 'createdAt': 1730000000000},
        });
      }
      if (path.endsWith('/sync/pull')) return _json({'now': 1});
      return _json(const {});
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showBlurDialog(context, const LoginForm()),
              child: const Text('开登录'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('开登录'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginForm), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'testuser1');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('登录').last);
    await tester.pumpAndSettle();

    expect(find.byType(LoginForm), findsNothing,
        reason: '登录成功后弹层应该自动 pop，不能停在登录界面');
    expect(AppData.I.signedIn, isTrue);
  });

  testWidgets('真实主壳环境：登录成功（拉回已完成心愿触发奖杯）后弹层也要关', (tester) async {
    // 「我的」设置项一多，默认 800×600 的测试视口滚动定位就容易边缘失手
    // （见 git history：曾因固定步长 dragUntilVisible 在视口边缘判定不准）。
    // 给够高度让整页不用滚动就能测，不用跟设置项数量死磕滚动精度。
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues(
        {'achv_seeded': true, 'privacy_consented_v1': true});
    await ConsentState.I.load();
    AppData.I.signedIn = false;
    AppData.I.wishes.clear();
    ApiClient.http_ = MockClient((req) async {
      final path = req.url.path;
      if (path.endsWith('/auth/login')) {
        return _json({
          'token': 'test-token-2',
          'profile': {'nickname': '松之', 'createdAt': 1730000000000},
        });
      }
      if (path.endsWith('/sync/pull')) {
        return _json({
          'now': 1,
          'wishes': [
            {
              '_id': 'w1',
              'title': '去看一次海',
              'color': 'E05A5A',
              'done': true,
              'doneAt': 1730000000000,
              'location': 'Shinjuku City',
              'createdAt': 1730000000000,
              'updatedAt': 1730000000000,
            },
            {
              '_id': 'w2',
              'title': '看一次日出',
              'color': 'E05A5A',
              'done': true,
              'doneAt': 1730000001000,
              'location': 'Shinjuku City',
              'createdAt': 1730000000000,
              'updatedAt': 1730000000000,
            },
          ],
        });
      }
      return _json(const {});
    });

    await tester.pumpWidget(const MaterialApp(home: HomeShell(initialIndex: 2)));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('登录 / 注册'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(LoginForm), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'testuser1');
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('登录').last);
    // 主壳背景有循环动画，pumpAndSettle 永远不会停，手动多泵几帧
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.byType(LoginForm), findsNothing,
        reason: '登录成功后弹层应该自动 pop，不能停在登录界面');
    expect(AppData.I.signedIn, isTrue);
  });
}
