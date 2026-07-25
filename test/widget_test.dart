import 'package:flutter_test/flutter_test.dart';
import 'package:xinyuan/main.dart';

void main() {
  testWidgets('app boots to calendar', (tester) async {
    await tester.pumpWidget(const XinyuanApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('任务'), findsOneWidget);
    expect(find.text('心愿'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('今天'), findsOneWidget);
  });
}
