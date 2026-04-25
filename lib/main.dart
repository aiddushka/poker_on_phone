import 'package:flutter/material.dart';
import 'package:pocker_in_phone/core/app_settings.dart';
import 'package:pocker_in_phone/core/i18n.dart';
import 'package:pocker_in_phone/ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  runApp(MentalPokerApp(settings: settings));
}

class MentalPokerApp extends StatelessWidget {
  const MentalPokerApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: AnimatedBuilder(
        animation: settings,
        builder: (context, _) {
          return MaterialApp(
            title: tr(context, 'app_title'),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF0D5B39),
                brightness: Brightness.dark,
              ),
              scaffoldBackgroundColor: const Color(0xFF0A1A12),
              useMaterial3: true,
            ),
            home: const HomePage(),
          );
        },
      ),
    );
  }
}
