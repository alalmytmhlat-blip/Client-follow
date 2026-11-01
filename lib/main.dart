import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'data.dart';
import 'notifications.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await Notifs.init();
  await Repo.i.init();
  await Repo.i.rescheduleAll();
  runApp(const ClientFollowApp());
}

class ClientFollowApp extends StatelessWidget {
  const ClientFollowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'متابع العملاء',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B6E79)),
        appBarTheme: const AppBarTheme(centerTitle: true),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const HomeShell(),
    );
  }
}
