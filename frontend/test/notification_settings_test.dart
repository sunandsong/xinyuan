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
