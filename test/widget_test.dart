// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:pocker_in_phone/core/app_settings.dart';

import 'package:pocker_in_phone/main.dart';

void main() {
  testWidgets('Home screen has host and join actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MentalPokerApp(settings: AppSettings(AppLanguage.ru)),
    );
    expect(find.text('Создать стол'), findsOneWidget);
    expect(find.text('Подключиться'), findsOneWidget);
  });
}
