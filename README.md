# PockerLAN - Mental Poker (Flutter)

Кроссплатформенное LAN-приложение (Android/iOS) с многопользовательской покерной игрой (Texas Hold'em), локальной сетью, базовой криптографической подсистемой SRA и двуязычным интерфейсом (RU/EN).

## Возможности

- Хост и клиенты в одной Wi-Fi сети (LAN).
- Лобби хоста и лобби подключения по IP/порту.
- Ограничение стола: от 2 до 10 игроков.
- Игровой стол в landscape, лобби/меню в portrait.
- Раунды Texas Hold'em: Preflop, Flop, Turn, River, Showdown.
- Действия игрока: Fold, Check, Call, Raise.
- Экран результатов после раунда с возможностью начать новую игру.
- Управление пользователями в окне новой игры (для хоста).
- Локализация RU/EN с сохранением выбранного языка.
- Раздел "Помощь" с комбинациями и правилами.
- Настройка иконки приложения и названия для standalone APK/IPA.

## Технологии

- Flutter / Dart
- `dart:io` (TCP sockets) для LAN-соединения
- `shared_preferences` для сохранения языка
- `url_launcher` для внешних ссылок (Telegram)
- `flutter_launcher_icons` для генерации иконок приложения

## Структура проекта

- `lib/main.dart` - запуск приложения и подключение настроек/локализации.
- `lib/core/app_settings.dart` - хранение пользовательских настроек.
- `lib/core/i18n.dart` - словари RU/EN и перевод `tr()/trRead()`.
- `lib/network/lan_peer.dart` - LAN peer service (host/join/send/listen).
- `lib/game/playing_card.dart` - модель карт и генерация колоды.
- `lib/game/poker_hand.dart` - определение покерных комбинаций.
- `lib/crypto/sra.dart` - реализация SRA (ключи, encrypt/decrypt, encode/decode).
- `lib/ui/home_page.dart` - главное меню.
- `lib/ui/host_lobby_page.dart` - лобби хоста.
- `lib/ui/join_lobby_page.dart` - лобби клиента.
- `lib/ui/game_room_page.dart` - основной игровой экран.
- `lib/ui/settings_page.dart` - язык, информация о разработчиках.

## Требования

- Flutter SDK (стабильная версия)
- Android Studio / VS Code / Cursor
- Для Android: установлен Android SDK
- Для iOS: macOS + Xcode (только на Mac)

Проверка окружения:

```bash
flutter doctor
```

## Быстрый старт (локальный запуск)

1. Установить зависимости:

```bash
flutter pub get
```

2. Запустить на устройстве/эмуляторе:

```bash
flutter run
```

## Как играть по LAN

1. Подключите оба устройства к одной Wi-Fi сети.
2. На устройстве хоста откройте `Создать стол`, укажите порт (обычно `5055`) и нажмите запуск.
3. Скопируйте адрес подключения, который показывает хост (например `192.168.10.183:5055`).
4. На устройстве клиента откройте `Подключиться`, введите IP и порт хоста вручную.
5. После подключения хост запускает игру кнопкой `START GAME`.

## Состояние SRA в проекте

В проекте уже реализована отдельная криптографическая подсистема `lib/crypto/sra.dart`:

- Генерация параметров ключа SRA.
- Коммутативные операции шифрования/дешифрования через `modPow`.
- Кодирование/декодирование ID карты в `BigInt`.

Важно: текущая игровая сетевая логика в `lib/ui/game_room_page.dart` пока использует обычную раздачу `shuffle` и передачу идентификаторов карт. Полная интеграция SRA в сетевой протокол (многошаговое совместное шифрование/расшифрование между игроками) требует отдельного этапа.

## Локализация

- Выбор языка в `Настройки`.
- Язык сохраняется между перезапусками приложения.
- Словари находятся в `lib/core/i18n.dart`.

## Сборка Android APK

### Debug APK

```bash
flutter build apk --debug
```

Файл:
`build/app/outputs/flutter-apk/app-debug.apk`

### Release APK

1. Создать keystore (пример для PowerShell):

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\upload-keystore.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Создать `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:\\Users\\USERNAME\\upload-keystore.jks
```

3. Убедиться, что `android/app/build.gradle.kts` читает `key.properties` (в проекте уже настроено).
4. Собрать release:

```bash
flutter build apk --release
```

Файл:
`build/app/outputs/flutter-apk/app-release.apk`

## Сборка iOS

Только на macOS:

```bash
flutter build ipa --release
```

Выходные файлы находятся в `build/ios/ipa/`.

## Название и иконка приложения

- Название Android задается в `android/app/src/main/AndroidManifest.xml` через `android:label`.
- Иконка настраивается через `pubspec.yaml`:

```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
```

Затем сгенерировать иконки:

```bash
flutter pub run flutter_launcher_icons
```

## Тесты и анализ

```bash
flutter test
flutter analyze
```

## Известные ограничения

- Отсутствует полноценная интеграция SRA в online-раздачу (только криптомодуль без полного сетевого протокола mental poker).
- Победитель на showdown определяется по категории комбинации; детальная логика tie-break/split pot может требовать расширения.

## Лицензия

Учебный проект. Использование и модификация - по согласованию с авторами.
