import 'package:flutter/material.dart';
import 'package:pocker_in_phone/core/app_settings.dart';
import 'package:pocker_in_phone/core/i18n.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _openTelegram() async {
    final uri = Uri.parse('https://t.me/aid_dushka');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettingsScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'settings'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(context, 'language'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            SegmentedButton<AppLanguage>(
              segments: [
                ButtonSegment(
                  value: AppLanguage.ru,
                  label: Text(tr(context, 'russian')),
                ),
                ButtonSegment(
                  value: AppLanguage.en,
                  label: Text(tr(context, 'english')),
                ),
              ],
              selected: {settings.language},
              onSelectionChanged: (value) => settings.setLanguage(value.first),
            ),
            const SizedBox(height: 24),
            Text(
              tr(context, 'about_dev'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text('Разработчик: Мамадалиев Рустам'),
            TextButton(
              onPressed: _openTelegram,
              child: const Text('Telegram: https://t.me/aid_dushka'),
            ),
            const SizedBox(height: 8),
            const Text('Разработчик: Азимджанов Жахонгир'),
            TextButton(
              onPressed: _openTelegram,
              child: const Text('Telegram: https://t.me/aid_dushka'),
            ),
          ],
        ),
      ),
    );
  }
}
