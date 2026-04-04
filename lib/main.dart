import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/onboarding_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load CLAUDE_API_KEY from .env asset
  await dotenv.load(fileName: '.env');

  // Request iOS notification permissions + initialise flutter_local_notifications
  await NotificationService.initialize();

  runApp(const OnCallBalanceApp());
}

class OnCallBalanceApp extends StatelessWidget {
  const OnCallBalanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnCallBalance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const OnboardingScreen(),
    );
  }
}
