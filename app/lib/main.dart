import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config.dart';
import 'telas/entrada.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (firebaseConfigurado) {
    await Firebase.initializeApp(options: opcoesFirebase);
  }
  runApp(const BibliotecaApp());
}

ThemeData _tema() {
  final cores = ColorScheme.fromSeed(seedColor: const Color(0xFF8D4B2F));
  final base = ThemeData(colorScheme: cores, useMaterial3: true);
  return base.copyWith(
    textTheme: base.textTheme.apply(fontSizeFactor: 1.05),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2)),
    cardTheme: const CardThemeData(margin: EdgeInsets.symmetric(vertical: 6)),
  );
}

class BibliotecaApp extends StatelessWidget {
  const BibliotecaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biblioteca',
      debugShowCheckedModeBanner: false,
      theme: _tema(),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: firebaseConfigurado ? const Portao() : const ConfiguracaoPendente(),
    );
  }
}
