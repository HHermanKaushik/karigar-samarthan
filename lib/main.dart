import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routes/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/language_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env optional during prototype
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
