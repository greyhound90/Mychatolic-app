import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:mychatolic_app/features/auth/pages/splash_page.dart';
import 'package:mychatolic_app/features/auth/pages/reset_password_page.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/core/theme.dart';
import 'package:mychatolic_app/providers/theme_provider.dart';
import 'package:mychatolic_app/providers/locale_provider.dart';
import 'package:mychatolic_app/core/log/app_logger.dart';
import 'package:mychatolic_app/core/ui/app_state.dart';
import 'package:mychatolic_app/core/ui/app_state_view.dart';
import 'package:mychatolic_app/core/analytics/analytics_service.dart';
import 'package:mychatolic_app/core/analytics/analytics_observer.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mychatolic_app/bible/presentation/bible_view_model.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    final message = kDebugMode
        ? "Terjadi kesalahan pada tampilan. ${details.exceptionAsString()}"
        : "Terjadi kesalahan. Silakan coba lagi.";
    return Material(
      color: Colors.white,
      child: Center(
        child: AppStateView(
          state: AppViewState.error,
          error: AppError(title: "Oops", message: message),
        ),
      ),
    );
  };

  FlutterError.onError = (details) {
    AppLogger.logError(
      "FlutterError",
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    AppLogger.logError("Platform error", error: error, stackTrace: stack);
    return true;
  };

  runZonedGuarded(() async {
    await _bootstrap();
  }, (error, stack) {
    AppLogger.logError("Zone error", error: error, stackTrace: stack);
  });
}

Future<void> _bootstrap() async {
  // Load Environment Variables
  await dotenv.load(fileName: ".env");

  // Setup Time Ago
  timeago.setLocaleMessages('id', timeago.IdMessages());

  // Initialize Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  await AnalyticsService.instance.init();

  // Initialize Date Formatting Locale
  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('id', null);
  await initializeDateFormatting('en_US', null);
  await initializeDateFormatting('en', null);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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

class _MyChatolicAppState extends State<MyChatolicApp>
    with WidgetsBindingObserver {
  StreamSubscription<AuthState>? _authSub;
  bool _recoveryPushed = false;
  bool _sessionRedirecting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AnalyticsService.instance.startSessionIfNeeded(force: true);
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        if (_recoveryPushed) return;
        _recoveryPushed = true;
        MyChatolicApp.navigatorKey.currentState
            ?.push(MaterialPageRoute(builder: (_) => const ResetPasswordPage()))
            .then((_) => _recoveryPushed = false);
        return;
      }

      if (data.event == AuthChangeEvent.signedOut && !_sessionRedirecting) {
        _sessionRedirecting = true;
        final nav = MyChatolicApp.navigatorKey;
        final ctx = nav.currentContext;
        if (ctx != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(content: Text("Sesi berakhir")),
          );
        }
        nav.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
        _sessionRedirecting = false;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AnalyticsService.instance.startSessionIfNeeded();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AnalyticsService.instance.flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appName,
      navigatorKey: MyChatolicApp.navigatorKey,
      navigatorObservers: [AnalyticsObserver(AnalyticsService.instance)],
      builder: (context, child) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          behavior: HitTestBehavior.translucent,
          child: child,
        );
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeProvider.locale,
      localeResolutionCallback: (locale, supportedLocales) {
        final code = (locale?.languageCode ?? 'en').toLowerCase();
        if (code == 'id' || code == 'in') {
          return const Locale('id', 'ID');
        }
        return const Locale('en', 'US');
      },
      theme: MyCatholicTheme.lightTheme,
      darkTheme: MyCatholicTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: const SplashPage(),
    );
  }
}

// ================== MAIN SCREEN (Navigation) ==================
// This class is deprecated. See HomePage for the new Standard Navigation.
