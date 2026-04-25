import 'package:flutter/material.dart';
import 'package:pocker_in_phone/core/app_settings.dart';

const Map<String, String> _ru = {
  'app_title': 'Покер по LAN',
  'create_table': 'Создать стол',
  'join_table': 'Подключиться',
  'settings': 'Настройки',
  'language': 'Язык',
  'russian': 'Русский',
  'english': 'English',
  'about_dev': 'О разработчике',
  'host_lobby': 'Лобби хоста',
  'join_lobby': 'Лобби подключения',
  'your_name': 'Ваше имя',
  'port': 'Порт',
  'start_table': 'Запустить стол',
  'join_address': 'Адрес для подключения',
  'starting_credits': 'Стартовые кредиты',
  'connected_players': 'Подключившиеся игроки',
  'start_game': 'НАЧАТЬ ИГРУ',
  'connect_game': 'ПОДКЛЮЧИТЬСЯ К ИГРЕ',
  'host_ip': 'IP хоста',
  'waiting_host': 'Подключено. Ожидание START GAME от хоста',
};

const Map<String, String> _en = {
  'app_title': 'LAN Poker',
  'create_table': 'Create Table',
  'join_table': 'Join',
  'settings': 'Settings',
  'language': 'Language',
  'russian': 'Russian',
  'english': 'English',
  'about_dev': 'About Developer',
  'host_lobby': 'Host Lobby',
  'join_lobby': 'Join Lobby',
  'your_name': 'Your Name',
  'port': 'Port',
  'start_table': 'Start Host',
  'join_address': 'Address to connect',
  'starting_credits': 'Starting credits',
  'connected_players': 'Connected players',
  'start_game': 'START GAME',
  'connect_game': 'JOIN GAME',
  'host_ip': 'Host IP',
  'waiting_host': 'Connected. Waiting for START GAME from host',
};

String tr(BuildContext context, String key) {
  final settings = AppSettingsScope.of(context);
  final dict = settings.language == AppLanguage.en ? _en : _ru;
  return dict[key] ?? key;
}
