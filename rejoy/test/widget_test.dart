import 'package:flutter_test/flutter_test.dart';
import 'package:rejoy/src/app.dart';

void main() {
  testWidgets('ReJoy app builds', (WidgetTester tester) async {
    await tester.pumpWidget(const ReJoyApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('ReJoy'), findsOneWidget);
    expect(find.text('เข้าสู่ระบบ'), findsOneWidget);
  });
}
