// integration_test/ai_assistant_navigation_test.dart
//
// FLOW UNDER TEST: AI Assistant chat -> a navigation-triggering message ->
// response text -> (nominally) TTS -> navigation to a target screen. This
// was flagged early on as worth checking for a "does the chained response ->
// TTS -> navigate sequence feel laggy" UX read.
//
// TEST NAME - KEEP IT PLAIN: a patrolTest() description containing "+" or
// "/" reproducibly crashed the native JUnit bridge before any Dart test code
// ran (found and fixed in home_connectivity_test.dart). This name is plain
// words only - do not add punctuation back into it.
//
// MAJOR FINDING - THE "TTS GATE" IS LIKELY NOT A REAL WAIT: _send() in
// ai_assistant_screen.dart does `await _speak(response.text, lang)` before
// checking response.navigateTo and popping, so the *sequence* (text -> speak
// -> navigate) is real, confirmed in code. But flutter_tts 4.2.5's actual
// Android source (FlutterTtsPlugin.kt) shows `awaitSpeakCompletion` defaults
// to false and is only set true via an explicit Dart-side call - grepped the
// whole app, that call is never made. TTSService.speak() also passes a no-op
// completion handler when the caller doesn't supply one, and _speak() here
// doesn't supply one. Net effect: `await _tts.speak(text)` almost certainly
// resolves once playback STARTS, not when it finishes - meaning navigation
// likely fires within milliseconds of the response text appearing, with TTS
// audio continuing in the background, unrelated to navigation timing. This
// test measures whatever the real gap actually is rather than assuming it
// will be TTS-duration-scale. A near-zero gap is not a test bug - it would
// be evidence the code inventory's "navigation waits for TTS" premise
// doesn't hold as coded. There is no observable "isSpeaking" state anywhere
// in the app (grepped for isSpeaking/ttsProvider/speakingProvider - none
// exist), so real TTS playback duration itself cannot be measured from here.
//
// NAVIGATION IS GEMINI FUNCTION-CALLING, NOT DETERMINISTIC CODE: confirmed
// in ai_assistant_service.dart - the system prompt declares a navigate_to
// tool and instructs the model to call it for certain phrasings, with
// explicit example phrasing baked in: "show my orders" / "check my orders"
// -> orders (see _appKnowledge in that file). This test types that exact
// example phrase verbatim, not a paraphrase, to maximize reliability - but
// it is still the live model's judgment each run, not guaranteed. If
// navigation doesn't fire, this test reports the actual response text
// rather than failing silently.
//
// GETTING TO HOME: same full bootstrap + signup -> OTP flow as the other
// three tests - onboarding_provider.dart's SharedPreferences flag gets wiped
// by patrol test's default --uninstall before every run, so there's no login
// shortcut.
//
// ENTRY POINT: home_ask_ai_button and bottom_nav_voice_button both route to
// the identical _openAssistant() -> AiAssistantScreen (confirmed in
// store_shell.dart). Using home_ask_ai_button - a plain TextButton.icon,
// nothing voice-specific to worry about.
//
// SUBMITTING VIA KEYBOARD ACTION, NOT A BUTTON: confirmed in
// ai_assistant_screen.dart - there is no send button; the TextField's
// onSubmitted: _send fires only on the keyboard's submit/done action. Patrol
// finders' own enterText() calls tester.testTextInput.reset() right after
// typing (to support re-entering text into the same field later in a test),
// which could interfere with then firing a submit action against that same
// connection. To avoid that ambiguity, this test uses the raw WidgetTester
// (`$.tester`) directly for this one interaction - tester.enterText() then
// tester.testTextInput.receiveAction(TextInputAction.done) - the standard
// Flutter-test pattern for triggering onSubmitted, rather than patrol's
// wrapper.
//
// MESSAGE INDEXING (confirmed in ai_assistant_screen.dart): _messages starts
// with one AI greeting at index 0. The first user message becomes index 1,
// the first AI response index 2 - so the response we're waiting for is
// ai_assistant_response_text_2.
//
// LANDING VERIFICATION HAS NO KEY TO USE: orders_screen.dart has no keys at
// all (the earlier keying task missed this screen) - grepped for Key( and
// found nothing. Verifying landing via the screen's visible heading text
// instead: tr('myOrders') resolves to "My Orders" in English
// (core/il8n/app_strings.dart), a stable, unique string on that screen.
//
// CAPTURING THE TRANSITION - WHY NOT pumpAndSettle(): same reasoning as
// home_connectivity_test.dart's reconcile-race capture - pumpAndSettle()
// would blow straight past the response-appears -> navigation-fires gap
// this test exists to measure. Uses waitUntilVisible() for the response
// text (pumps in 100ms steps, returns as soon as hit-testable - confirmed
// via patrol_tester.dart source) then polls in a manual pump loop watching
// for "My Orders" to appear, timestamping the gap directly.
//
// WHAT THIS TEST MEASURES:
//   1. Response latency: message submit -> response text appearing.
//   2. Navigation delay: response text appearing -> navigation firing (the
//      actual "is the chain laggy" question - expected to be near-zero per
//      the TTS-gate finding above, not a long wait).
//   3. Total end-to-end: submit -> landing on Orders screen.
//   4. Whether navigation fired at all - reported with the actual response
//      text either way, since Gemini's routing isn't guaranteed.
//
// WHAT THIS TEST DOES NOT MEASURE:
//   - Actual TTS audio playback duration - no observable hook exists for it
//     (see finding above).
//   - Voice/STT input - text input only, per the known constraint that there
//     is no send button and voice would require unproven native mic
//     automation for no clear benefit over text for exercising the same
//     downstream Gemini call.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:karigar_samarthan/firebase_options.dart';
import 'package:karigar_samarthan/main.dart' as app;

void main() {
  patrolTest(
    'ai assistant navigates to orders screen',
    ($) async {
      final metrics = <String, Duration>{};

      // --- Replicate main.dart's bootstrap ---
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

      // --- Language screen ---
      await $.tap($('English'));
      await $.pumpAndSettle();
      await $.tap($('Continue'));
      await $.pumpAndSettle();

      // --- Signup screen ---
      await $(#signup_fullname_field).enterText('Test User');
      await $(#signup_storename_field).enterText('Test Store');
      await $(#signup_phone_field).enterText('8448041541');
      await $(#signup_terms_checkbox).tap();
      await $(#signup_submit_button).tap();
      await $.pumpAndSettle();

      expect(
        $(#signup_verification_error_message).exists,
        false,
        reason: 'Signup submit produced a verification error instead of '
            'proceeding to OTP screen',
      );

      // --- OTP screen ---
      await $(#otp_input_field).enterText('123456');
      await $(#otp_verify_button).tap();
      await $.pumpAndSettle();

      expect(
        $(#otp_verification_error_message).exists,
        false,
        reason: 'OTP verification failed - check test phone/code config '
            'in Firebase console',
      );

      expect($(#home_refresh_indicator).exists, true,
          reason: 'Did not land on HomeScreen after OTP verification');

      // --- Open AI Assistant ---
      await $(#home_ask_ai_button).tap();
      await $.pumpAndSettle();

      // --- Submit navigation-triggering message via keyboard action ---
      // Using raw WidgetTester directly - see header note on why patrol's
      // enterText() wrapper is avoided for this specific interaction.
      await $.tester.enterText(
        find.byKey(const Key('ai_assistant_input_field')),
        'show my orders',
      );

      final submitStopwatch = Stopwatch()..start();
      await $.tester.testTextInput.receiveAction(TextInputAction.done);
      await $.tester.pump();

      // --- Wait for the response text (not pumpAndSettle - see header note) ---
      await $(#ai_assistant_response_text_2).waitUntilVisible(
        timeout: const Duration(seconds: 30),
      );
      submitStopwatch.stop();
      metrics['response_latency'] = submitStopwatch.elapsed;

      final responseText = $.tester
              .widget<SelectableText>(
                find.descendant(
                  of: find.byKey(const Key('ai_assistant_response_text_2')),
                  matching: find.byType(SelectableText),
                ),
              )
              .data ??
          '';

      // --- Time the response-appears -> navigation-fires gap ---
      // Manual pump loop, not pumpAndSettle, to catch this transition
      // directly rather than blow past it.
      final navStopwatch = Stopwatch()..start();
      const navTimeout = Duration(seconds: 15);
      var navigated = false;
      while (navStopwatch.elapsed < navTimeout) {
        await $.tester.pump(const Duration(milliseconds: 100));
        if ($('My Orders').exists) {
          navigated = true;
          break;
        }
      }
      navStopwatch.stop();

      if (navigated) {
        metrics['navigation_delay'] = navStopwatch.elapsed;
        metrics['total_end_to_end'] =
            metrics['response_latency']! + navStopwatch.elapsed;
      }

      // ignore: avoid_print
      print('--- AI ASSISTANT NAVIGATION ---');
      // ignore: avoid_print
      print('response text: $responseText');
      // ignore: avoid_print
      print('navigated to orders: $navigated');

      // ignore: avoid_print
      print('--- AI ASSISTANT METRICS ---');
      metrics.forEach((step, duration) {
        // ignore: avoid_print
        print('$step: ${duration.inMilliseconds}ms');
      });

      expect(navigated, true,
          reason: 'AI did not navigate to Orders screen within '
              '${navTimeout.inSeconds}s - Gemini routing is non-deterministic '
              '(see header note), so this may not fire every run. '
              'Actual response text was: "$responseText"');

      expect($('My Orders').exists, true,
          reason: 'Expected to land on Orders screen ("My Orders" heading)');
    },
  );
}

// -----------------------------------------------------------------------
// HOW TO RUN
// -----------------------------------------------------------------------
// 1. Run on the connected device:
//      patrol test --target integration_test/ai_assistant_navigation_test.dart -d <device-id>
//
// 2. print() output does not reach patrol's CLI stdout - pull it from
//    logcat instead:
//      adb -s <device-id> logcat -d | grep "flutter.*PATROL_LOG\|ASSISTANT\|response text:"
//
// 3. Patrol CLI 3.6.0 has no built-in --record flag. For a screen recording:
//      adb -s <device-id> shell screenrecord /sdcard/ai_assistant_test.mp4
//      ... (run the test) ...
//      adb -s <device-id> shell killall -SIGINT screenrecord
//      adb -s <device-id> pull /sdcard/ai_assistant_test.mp4
//
// 4. If this test fails with "AI did not navigate", check the printed
//    response text first - Gemini may have answered without calling
//    navigate_to (non-deterministic routing, not a code bug). Re-running
//    is a reasonable first response, not evidence of a real regression.
