import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  // Ловим любые необработанные ошибки, чтобы вместо белого экрана показать причину.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    runApp(_ErrorApp(error: '${details.exception}\n\n${details.stack}'));
  };

  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    NotificationService? notifications;
    try {
      notifications = NotificationService();
      await notifications.init();
    } catch (e, st) {
      debugPrint('NotificationService init failed: $e\n$st');
      notifications = null;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: <Override>[
          if (notifications != null)
            notificationServiceProvider.overrideWithValue(notifications),
          sharedPreferencesProvider.overrideWith((Ref ref) => prefs),
        ],
        child: const TimeManagerApp(),
      ),
    );
  }, (Object error, StackTrace stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
    runApp(_ErrorApp(error: '$error\n\n$stack'));
  });
}

class _ErrorApp extends StatelessWidget {
  const _ErrorApp({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Ошибка запуска',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    error,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
