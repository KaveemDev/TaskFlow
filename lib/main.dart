import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/root_screen.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'services/widget_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WidgetService.init();
  await NotificationService().init();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Ignore initialization errors
  }

  runApp(const ProviderScope(child: KronomApp()));
}

class KronomApp extends ConsumerWidget {
  const KronomApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final accent = ref.watch(accentProvider);

    return MaterialApp(
      title: 'Kronom',
      themeMode: themeMode,
      theme: AppTheme.light(accent),
      darkTheme: AppTheme.dark(accent),
      home: const RootScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
