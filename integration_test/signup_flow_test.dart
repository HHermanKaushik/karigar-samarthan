// integration_test/signup_flow_test.dart
//
// FLOW UNDER TEST: Signup -> OTP -> Home
//
// WHY THIS FLOW: this is the app's mandatory onboarding path. Every new user
// must pass through it, and it's the flow with the most-flagged latency risk
// in the codebase (Firebase phone-auth round trips gate every submit button).
//
// NOTE ON PAYMENT SETUP: /payment-setup is only reachable via the auto-verify
// branch in signup_screen.dart (verificationCompleted), which Firebase test
// phone numbers deliberately never trigger. The manual-OTP path exercised
// here (otp_screen.dart) intentionally sends fresh registrants straight to
// /home, deferring payment setup - confirmed as intended app behavior, not
// a bug. A separate test would be needed to exercise the auto-verify path.
//
// WHAT THIS TEST MEASURES:
//   1. Functional correctness  - does the flow complete without crashing,
//      given valid input at each step.
//   2. Wall-clock timing per step - how long each async gate (signup submit,
//      OTP verify) actually takes on this run. These numbers feed directly
//      into your "latency" metrics table.
//   3. Screen recording - captured separately via `patrol test --record`
//      (see notes at bottom of file) for the Claude UX-judgment pass.
//
// WHAT THIS TEST DOES NOT MEASURE (be ready to say this in viva):
//   - Whether the OTP SMS itself arrives quickly - that's outside your app,
//     it's Firebase/telecom-network latency. This test uses a known
//     test phone number configured in the Firebase console
//     (Firebase Auth > Sign-in method > Phone > Phone numbers for testing)
//     so OTP delivery is instant and deterministic, not real-world SMS timing.
//   - Real-device performance - this runs on an emulator. Note this as a
//     limitation, and pair it with your weekly Firebase Test Lab run for a
//     real-device comparison point.
//   - UX/coherence judgment - this file only proves the flow *works*. The
//     "does this feel slow/confusing" judgment is a separate pass where you
//     feed the recording to Claude (next step, not in this file).

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:karigar_samarthan/firebase_options.dart';
import 'package:karigar_samarthan/main.dart' as app;

void main() {
  patrolTest(
    'signup -> otp -> home completes successfully',
    ($) async {
      final metrics = <String, Duration>{};
      final stopwatch = Stopwatch();

      // --- Replicate main.dart's bootstrap ---
      // pumpWidgetAndSettle(KarigarApp()) skips main() entirely, so anything
      // main() sets up before runApp() has to happen here too.
      await dotenv.load(fileName: '.env');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (FirebaseAuth.instance.currentUser == null) {
        await FirebaseAuth.instance.signInAnonymously();
      }

      // --- Launch app ---
      await $.pumpWidgetAndSettle(
        const ProviderScope(child: app.KarigarApp()),
      );

      // --- Language screen (entry point) ---
      // Assumes English is selectable; adjust if your default differs.
      // Defensive scrollTo() before the tap - on some screen sizes the
      // ListView's viewport is too short to fit all 5 cards at rest,
      // clipping the last one(s) (confirmed via uiautomator dump during the
      // Tamil variant's root-cause investigation). English is first in the
      // list so it isn't currently affected, but scrollTo() is a no-op when
      // already visible.
      await $('English').scrollTo();
      await $.tap($('English')); // TODO: replace with a keyed finder once
      // LanguageScreen is in scope, or find.text if language options are
      // not literal-English-only. Left as a placeholder deliberately -
      // this screen was outside the keying task's scope.
      await $.pumpAndSettle();

      // Tapping the language card only selects it (setLanguage) - navigation
      // to /signup happens on the separate "Continue" button.
      await $.tap($('Continue'));
      await $.pumpAndSettle();

      // --- Signup screen ---
      stopwatch.start();

      await $(#signup_fullname_field).enterText('Test User');
      await $(#signup_storename_field).enterText('Test Store');
      // NOTE: entering local digits only, assuming the phone field UI has a
      // fixed +91 prefix (common pattern for India-only apps) and the field
      // itself only accepts the 10-digit number. If signup_phone_field
      // actually expects the full E.164 string, change this to
      // '+918448041541' instead. Verify against the actual widget before
      // relying on this - I haven't seen that screen's code.
      await $(#signup_phone_field)
          .enterText('8448041541'); // Firebase test number (+91)

      await $(#signup_terms_checkbox).tap();
      await $(#signup_submit_button).tap();

      // Wait until the async submit resolves (spinner disappears, navigation
      // settles, etc). pumpAndSettle() blocks until the widget tree stops
      // changing - this duration IS the metric we care about.
      await $.pumpAndSettle();

      stopwatch.stop();
      metrics['signup_submit'] = stopwatch.elapsed;
      stopwatch.reset();

      // Fail loudly and specifically if an error message appeared instead
      // of navigating on - don't let this pass silently.
      expect(
        $(#signup_verification_error_message).exists,
        false,
        reason: 'Signup submit produced a verification error instead of '
            'proceeding to OTP screen',
      );

      // --- OTP screen ---
      stopwatch.start();

      await $(#otp_input_field).enterText('123456'); // Firebase test OTP
      await $(#otp_verify_button).tap();
      await $.pumpAndSettle();

      stopwatch.stop();
      metrics['otp_verify'] = stopwatch.elapsed;
      stopwatch.reset();

      expect(
        $(#otp_verification_error_message).exists,
        false,
        reason: 'OTP verification failed - check test phone/code config '
            'in Firebase console',
      );

      // --- Confirm we landed on Home ---
      // Manual-OTP path (otp_screen.dart) sends fresh registrants straight
      // to Home, deferring payment setup - see file header note.
      expect($(#home_refresh_indicator).exists, true,
          reason: 'Did not land on HomeScreen after OTP verification');

      // --- Print metrics for capture in CI logs / your results table ---
      // ignore: avoid_print
      print('--- SIGNUP FLOW METRICS ---');
      metrics.forEach((step, duration) {
        // ignore: avoid_print
        print('$step: ${duration.inMilliseconds}ms');
      });
    },
  );
}

// -----------------------------------------------------------------------
// HOW TO RUN
// -----------------------------------------------------------------------
// 1. Add to pubspec.yaml (dev_dependencies):
//      patrol: ^3.x.x
//    Then: flutter pub get
//    And: dart run patrol bootstrap   (one-time, sets up native harness)
//
// 2. Place this file in: integration_test/signup_flow_test.dart
//
// 3. Firebase test phone number is already configured: +91 8448041541 / 123456
//    (Firebase Console > Authentication > Sign-in method > Phone >
//    "Phone numbers for testing"). Confirm the country code (+91) is set
//    exactly as registered there, or verification will silently fail.
//
// 4. Run on an emulator:
//      patrol test --target integration_test/signup_flow_test.dart
//
// 5. To get a screen recording for the Claude judgment pass:
//      patrol test --target integration_test/signup_flow_test.dart --record
//    (Check current Patrol docs for the exact recording flag - this has
//    moved between versions; verify before you write it into your paper.)
//
// -----------------------------------------------------------------------
// NEXT STEP (separate from this file)
// -----------------------------------------------------------------------
// Feed the recording + this test's printed metrics + a short description
// of "what should happen" to Claude, and ask it to produce a UX-coherence
// verdict. That prompt is a separate step - ask for it when you're ready.
