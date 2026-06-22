import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Central place to record failures from backend sync operations
/// (WooCommerce, WordPress media, Firestore profile sync, etc.)
///
/// Every failure is:
///  1. Printed to the console (useful in dev)
///  2. Sent to Firebase Crashlytics as a non-fatal error (alerting)
///  3. Written to the `sync_errors` Firestore collection (queryable log
///     for support/engineering to triage without needing device logs)
///
/// All of this is best-effort: if Crashlytics or Firestore themselves
/// fail (e.g. no network), logging never throws and never blocks the
/// calling operation.
class SyncLogger {
  Future<void> logError(
    String operation,
    Object error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) async {
    debugPrint('========== SYNC ERROR [$operation] ==========');
    debugPrint(error.toString());
    if (context != null) debugPrint('context: $context');
    debugPrint('===============================================');

    await _logToCrashlytics(operation, error, stackTrace, context);
    await _logToFirestore(operation, error, context);
  }

  Future<void> _logToCrashlytics(
    String operation,
    Object error,
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ) async {
    try {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: operation,
        information: [
          if (context != null) context.toString(),
        ],
        fatal: false,
      );
    } catch (e) {
      debugPrint('SyncLogger: failed to record to Crashlytics: $e');
    }
  }

  Future<void> _logToFirestore(
    String operation,
    Object error,
    Map<String, dynamic>? context,
  ) async {
    try {
      await FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'karigar',
      ).collection('sync_errors').add({
        'operation': operation,
        'error': error.toString(),
        'context': context ?? <String, dynamic>{},
        'platform': defaultTargetPlatform.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('SyncLogger: failed to write sync_errors doc: $e');
    }
  }
}
