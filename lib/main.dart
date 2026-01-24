import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mychatolic_app/pages/splash_page.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load Environment Variables
  await dotenv.load(fileName: ".env");

  // Setup Time Ago
  timeago.setLocaleMessages('id', timeago.IdMessages());

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialize Date Formatting Locale
  await initializeDateFormatting('id_ID', null);

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyChatolicApp(),
    ),
  );
}

class MyChatolicApp extends StatelessWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyChatolicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyCatholic',
      navigatorKey: MyChatolicApp.navigatorKey,
      theme: MyCatholicTheme.lightTheme,
      darkTheme: MyCatholicTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashPage(),
    );
  }
}

// ================== MAIN SCREEN (Navigation) ==================
// This class is deprecated. See HomePage for the new Standard Navigation.
