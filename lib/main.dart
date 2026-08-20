import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/language_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Android 15+ draws edge-to-edge by default; without this the nav bar
  // renders as plain opaque black instead of matching the app theme.
  // Screens handle the insets via SafeArea.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint(
        'WARNING: Failed to load .env — API features will be disabled: $e');
  }

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensures a Firebase user exists so Storage/Firestore writes are authenticated.
  // Requires Anonymous sign-in enabled in Firebase Console.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed (check Firebase Console): $e');
    }
  }

  runApp(
    const ProviderScope(
      child: KarigarApp(),
    ),
  );
}

class KarigarApp extends ConsumerWidget {
  const KarigarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(languageProvider);
    return MaterialApp.router(
      title: 'Karigar Samarthan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
