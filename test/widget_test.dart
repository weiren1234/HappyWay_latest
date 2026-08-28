import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyway/main.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://syvpbtsyfvhhbwsbwyhc.supabase.co',
      publishableKey: 'sb_publishable_QNnI3ZhpR5rQUX1r9dTLhg_Ihxp6ulC',
    );
  });

  testWidgets('HappyWay app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HappyWayApp());
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HappyWay'), findsWidgets);

    await tester.pump(const Duration(milliseconds: 3000));
  });
}
