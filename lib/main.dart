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

  // Android 15+ (SDK 35+) draws edge-to-edge by default and deprecates the
  // old solid-color status/navigation bar APIs. Without this, the app falls
  // back to a plain opaque black system navigation bar that clashes with
  // the app's cream theme instead of properly extending app content behind
  // transparent system bars (confirmed visually on a real SDK 36 device -
  // this is also what Play Console's pre-launch report flags). Every screen
  // that needs to avoid the status/navigation bar already uses SafeArea,
  // which reads the insets this exposes.
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

  // Ensure a Firebase user exists so Storage/Firestore writes are authenticated.
  // Requires Anonymous sign-in enabled in Firebase Console → Authentication → Sign-in methods.
  if (FirebaseAuth.instance.currentUser == null) {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint('Anonymous sign-in failed (check Firebase Console): $e');
    }
  }

  // Temporary diagnostic — remove after confirming env loads correctly
  debugPrint(
      'ENV CHECK: WP_USERNAME="${dotenv.env['WP_USERNAME']}" WP_APP_PASSWORD is ${(dotenv.env['WP_APP_PASSWORD'] ?? '').isEmpty ? 'EMPTY' : 'SET (${dotenv.env['WP_APP_PASSWORD']!.length} chars)'} WOOCOMMERCE_BASE_URL="${dotenv.env['WOOCOMMERCE_BASE_URL']}"');

  print('Firebase connected successfully');

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
