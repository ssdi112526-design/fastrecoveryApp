import 'package:flutter/material.dart';
import 'Service/SharedPreferenceService.dart';
import 'Splash_screen/Splash_screen.dart';
import 'Auth/Login/Login_page.dart';
import 'Screen/home.dart';

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier =
ValueNotifier(ThemeMode.light);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SharedPreferences
  await SharedPreferenceService.init();

  // Load saved theme
  final savedTheme =
  SharedPreferenceService.getString('theme_mode');

  if (savedTheme == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.light;
  }

  runApp(const MyApp());
}

// Change theme
Future<void> toggleTheme(bool isDark) async {
  themeNotifier.value =
  isDark ? ThemeMode.dark : ThemeMode.light;

  await SharedPreferenceService.setString(
    'theme_mode',
    isDark ? 'dark' : 'light',
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,

          title: 'Kartik Repossession Agency',

          themeMode: currentMode,

          // =========================
          // LIGHT THEME
          // =========================
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),

          // =========================
          // DARK THEME
          // =========================
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),

          // =========================
          // ROUTES
          // =========================
          routes: {
            '/splash': (_) => const SplashScreen(),
            '/login': (_) => const LoginScreen(),
            '/home': (_) => const HomeScreen(),
          },

          // App always starts from Splash
          initialRoute: '/splash',
        );
      },
    );
  }
}