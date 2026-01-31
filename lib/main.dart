import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:mychatolic_app/features/auth/pages/splash_page.dart';
import 'package:mychatolic_app/features/auth/pages/reset_password_page.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/providers/theme_provider.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mychatolic_app/bible/presentation/bible_view_model.dart';

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
  await initializeDateFormatting('id', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BibleViewModel()),
      ],
      child: const MyChatolicApp(),
    ),
  );
}

class MyChatolicApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const MyChatolicApp({super.key});

  @override
  State<MyChatolicApp> createState() => _MyChatolicAppState();
}

class _MyChatolicAppState extends State<MyChatolicApp> {
  StreamSubscription<AuthState>? _authSub;
  bool _recoveryPushed = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (_recoveryPushed) return;
        _recoveryPushed = true;
        MyChatolicApp.navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => const ResetPasswordPage()))
            .then((_) => _recoveryPushed = false);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MyCatholic',
      navigatorKey: MyChatolicApp.navigatorKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      theme: MyCatholicTheme.lightTheme,
      darkTheme: MyCatholicTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashPage(),
    );
  }
}

// ================== MAIN SCREEN (Navigation) ==================
// This class is deprecated. See HomePage for the new Standard Navigation.
