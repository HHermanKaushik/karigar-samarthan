// integration_test/add_product_flow_hindi_test.dart
//
// EXPLORATORY VARIANT of add_product_flow_test.dart - selects Hindi instead of
// English at the language step, so the publish step's Sarvam translation
// calls actually hit the network instead of short-circuiting. Everything else
// (fixed test image, tap sequence, assertions) is identical to the English
// version - see that file for the full flow rationale. This file exists to
// get ONE real (non-English) translation_phase_ms data point, not to replace
// or duplicate the English test as an ongoing regression check.
//
// WHY THIS VARIANT WAS NEEDED: three real timing runs on the English test all
// showed translation_phase_ms of 1-2ms regardless of tag count (7 or 11
// concurrent calls). Root cause, confirmed in sarvam_service.dart:110 -
// `if (sourceLanguageCode == targetLanguageCode) return text;` - an early
// return with no network call. The English test's toEnglish() always calls
// translateText(sourceLanguageCode: 'en-IN', targetLanguageCode: 'en-IN')
// since AppLanguage.english.sarvamCode is 'en-IN' - source always equals
// target, so every call short-circuits. Selecting Hindi makes
// sourceLanguageCode 'hi-IN' (AppLanguage.hindi.sarvamCode), genuinely
// different from the 'en-IN' target, so translateText() has to actually call
// Sarvam's /translate endpoint.
//
// THE TWO REQUIRED CHANGES, AND WHY (per the investigation requested before
// writing this file):
//
// 1. Language card tap - $('Hindi'), not native-script matching or index.
//    Confirmed in language_screen.dart: _LanguageCard renders lang.nativeName
//    AND lang.englishName as two SEPARATE Text widgets. For Hindi
//    (app_language.dart: hindi('hi', 'हिन्दी', 'Hindi')), englishName is the
//    literal string 'Hindi' - present verbatim in the widget tree as its own
//    Text widget regardless of the app's currently active language (these are
//    fixed enum properties, not translated via tr()). So $('Hindi') is exactly
//    as robust as the English test's $('English') was - no Unicode/encoding
//    risk (patrol's text finder does an in-memory string comparison, not
//    keyboard input, so native-script text would technically also have
//    worked) and no fragile position-based indexing needed either.
//
// 2. Continue button tap - $('आगे बढ़ें') (copied verbatim from
//    app_strings.dart's 'continueBtn'/'hi' entry, not retyped, to avoid
//    transcription risk), not $('Continue'). This one MATTERS: the Continue
//    button's label is tr('continueBtn'), which reactively re-renders in
//    whatever language was just selected - once the Hindi card is tapped
//    (calling languageProvider.notifier.setLanguage(hindi)), the button's text
//    immediately switches to Hindi. Reusing $('Continue') here would fail to
//    find the button and hang/timeout. This was the one step downstream of
//    language selection that depends on English text specifically - checked
//    every other tap in the sequence (signup, OTP, add-product wizard) and
//    they are all key-based (Key(...)), never text-based, so nothing else in
//    the flow needed changing.
//
// SANITY CHECK - WHERE DOES THE HINDI TEXT ACTUALLY COME FROM (per the
// investigation requested before writing this file): confirmed in
// ai_assistant_service.dart's analyzeProduct() prompt - Gemini is instructed
// to "Write ALL text output in $langName ONLY" where langName is resolved
// from the languageCode passed in (add_product_flow.dart's _runAi() passes
// ref.read(languageProvider).code, 'hi' here). So the AI-generated
// title/category/description come back FROM GEMINI ALREADY IN HINDI - not in
// English first and then translated. The Sarvam translation step exists
// specifically to convert this Hindi content back to English for the
// WooCommerce storefront listing (see the comment in add_product_flow.dart:
// "Listings must always be stored/published in English, regardless of which
// language the karigar used to create them"). This means the review screen's
// title/category/description fields will show Hindi script in this run - not
// a bug, expected given the language selection.
//
// ALSO CHECKED: the `language` parameter passed to woo.publishProduct() is
// stored as inert WooCommerce product metadata (_ks_language custom field,
// confirmed in woocommerce_service.dart) - no branching logic reads it, so
// passing 'hi' instead of 'en' here carries no behavioral risk.
//
// WHAT THIS DOES NOT CHANGE: the native gallery picker (Android's system
// Photo Picker) is a separate system app tied to the DEVICE's system locale,
// not this app's in-app languageProvider state - selecting Hindi in-app has
// no effect on the picker's own UI language, so the existing
// pickImageFromGallery selector (matching "Photo taken on" - an English
// system-locale string) is unaffected and unchanged here.

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
    'home add product hindi language publish completes successfully',
    ($) async {
      final metrics = <String, Duration>{};
      final stopwatch = Stopwatch();

      String textOf(Symbol key) =>
          $.tester.widget<TextField>($(key).finder).controller!.text;

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

      // --- Language screen: Hindi instead of English - see header note ---
      // Defensive scrollTo() before the tap - on some screen sizes the
      // ListView's viewport is too short to fit all 5 cards at rest,
      // clipping the last one(s) (confirmed via uiautomator dump during the
      // Tamil variant's root-cause investigation). Hindi is 2nd in the list
      // so it isn't currently affected, but scrollTo() is a no-op when
      // already visible, so it's added uniformly rather than relying on
      // list position/screen size.
      await $('Hindi').scrollTo();
      await $.tap($('Hindi'));
      await $.pumpAndSettle();

      // Continue button text is now Hindi (tr('continueBtn') reactively
      // re-rendered after selecting Hindi) - see header note for why this is
      // the one step that had to change beyond the language card itself.
      await $.tap($('आगे बढ़ें'));
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

      // --- Open Add Product wizard ---
      await $(#home_add_product_card).tap();
      await $.pumpAndSettle();

      // --- Step 0: Photo ---
      await $(#add_product_gallery_button).tap();

      if (await $.native.isPermissionDialogVisible(
        timeout: const Duration(seconds: 2),
      )) {
        await $.native.grantPermissionWhenInUse();
      }

      await $.native.pickImageFromGallery(
        imageSelector: Selector(
          className: 'android.view.View',
          contentDescriptionStartsWith: 'Photo taken on',
          instance: 0,
        ),
      );

      await $.native.tap(Selector(text: 'Done'));

      if (await $.native.isPermissionDialogVisible(
        timeout: const Duration(seconds: 3),
      )) {
        await $.native.grantPermissionWhenInUse();
      }

      await $.pumpAndSettle();

      expect($(#add_product_photo_addmore_button).exists, true,
          reason: 'Picked image did not register in the app after '
              'returning from the native gallery picker');

      await $(#add_product_photo_next_button).tap();
      await $.pumpAndSettle();

      // --- Step 1: Voice/Price/Qty ---
      await $(#add_product_price_field).enterText('499');
      await $(#add_product_qty_field).enterText('10');

      // --- Step 2: AI Processing ---
      stopwatch.start();

      await $(#add_product_voice_next_button).tap();
      await $.pumpAndSettle();

      stopwatch.stop();
      metrics['ai_processing'] = stopwatch.elapsed;
      stopwatch.reset();

      expect(
        $(#add_product_ai_error_message).exists,
        false,
        reason: 'AI processing failed - check Gemini API config/key',
      );

      // --- Step 3: Review ---
      // Expect Hindi script here - see header note on where the AI output
      // language actually comes from.
      final title = textOf(#add_product_title_field);
      final category = textOf(#add_product_category_field);
      final description = textOf(#add_product_description_field);

      expect(title.trim().isNotEmpty, true,
          reason: 'AI did not populate the title field');
      expect(category.trim().isNotEmpty, true,
          reason: 'AI did not populate the category field');
      expect(description.trim().isNotEmpty, true,
          reason: 'AI did not populate the description field');

      // --- Publish ---
      // This is the step under investigation: title/category/description are
      // in Hindi at this point, so toEnglish()'s Sarvam calls should actually
      // hit the network (sourceLanguageCode 'hi-IN' != targetLanguageCode
      // 'en-IN'), unlike the English test where they always short-circuit.
      stopwatch.start();

      await $(#add_product_publish_button).tap();
      await $.pumpAndSettle();

      stopwatch.stop();
      metrics['publish'] = stopwatch.elapsed;

      final publishFailed = $(#add_product_publish_failure_message).exists ||
          $(#add_product_publish_error_message).exists;
      expect(publishFailed, false,
          reason: 'Publish failed - check WooCommerce config/connectivity');

      expect($(#add_product_publish_success_message).exists, true,
          reason: 'Publish did not show a success message');

      // --- Print metrics for capture in CI logs / your results table ---
      // ignore: avoid_print
      print('--- ADD PRODUCT FLOW METRICS (HINDI) ---');
      metrics.forEach((step, duration) {
        // ignore: avoid_print
        print('$step: ${duration.inMilliseconds}ms');
      });
      // ignore: avoid_print
      print('--- ADD PRODUCT AI OUTPUT (HINDI) ---');
      // ignore: avoid_print
      print('title: $title');
      // ignore: avoid_print
      print('category: $category');
      // ignore: avoid_print
      print('description: $description');
    },
  );
}

// -----------------------------------------------------------------------
// HOW TO RUN
// -----------------------------------------------------------------------
// Same prerequisites as add_product_flow_test.dart (fixed test image already
// pushed and verified at gallery index 0 - see that file's HOW TO RUN).
//
//   patrol test --target integration_test/add_product_flow_hindi_test.dart -d <device-id>
//
// print() output (including the PUBLISH TIMING BREAKDOWN block printed by
// add_product_flow.dart itself) is in logcat, not patrol's CLI stdout:
//   adb -s <device-id> logcat -d | grep "PUBLISH TIMING BREAKDOWN\|ADD PRODUCT FLOW METRICS (HINDI)\|ADD PRODUCT AI OUTPUT (HINDI)" -A6
