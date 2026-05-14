import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'database/app_database.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDatabase.instance.initializeIfSupported();
  runApp(const MakosoApp());
}

class MakosoApp extends StatelessWidget {
  const MakosoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Makoso',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
      ],
      locale: const Locale('fr'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
