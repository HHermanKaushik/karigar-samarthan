// integration_test/add_product_flow_test.dart
//
// FLOW UNDER TEST: Home -> Add Product wizard (Photo -> Voice/Price/Qty ->
// AI Processing -> Review/Publish)
//
// GETTING TO HOME: onboarding_provider.dart backs "onboarding complete" with
// SharedPreferences - purely device-local, never derived from Firestore.
// app_router.dart's redirect logic only ever checks that local flag; nothing
// routes to /login based on whether a phone number already has a profile.
// Combined with `patrol test`'s default --uninstall (wipes local storage
// before every run), every run starts fresh at LanguageScreen and must go
// through the full signup -> OTP bootstrap to reach Home, exactly like
// signup_flow_test.dart - there is no login shortcut available here, even
// though the test phone number now has a Firestore profile from earlier
// signup test runs. (One harmless internal difference: otp_screen.dart's
// doc.exists branch fires this time instead of the fresh-registration
// branch, but both lead to the same place, /home.)
//
// THE FIXED TEST IMAGE: this test intentionally reuses the SAME image file
// on every run - /sdcard/Pictures/karigar_test_product.png, pushed from
// "Karigar Samarthan Tester Kit/1_BlockPrintedCottonDupatta.png" - rather
// than picking whatever's newest in the device's real photo library. This
// is deliberate for run-to-run comparability: AI-analysis output and publish
// timing should be compared against a constant input, not a moving target.
// `adb push` preserves the source file's original mtime, so after pushing
// the file was `touch`-ed on-device and a MEDIA_SCANNER_SCAN_FILE broadcast
// was sent to force MediaStore to re-index it with a current date_added.
// Verified empirically (not assumed) via:
//   adb shell content query --uri content://media/external/images/media \
//     --projection _id:_display_name:date_added --sort "date_added DESC"
// ...which confirmed karigar_test_product.png is Row 0. Re-run that push +
// touch + broadcast sequence (see HOW TO RUN below) if this test ever starts
// failing to find an image at index 0 - e.g. because a newer photo/
// screenshot was added to the device after this file's timestamp.
//
// PHOTO PICKER - NATIVE UI: image_picker's gallery source opens Android's
// system photo picker, which lives outside the Flutter widget tree - the
// app's own widget keys can't reach it. This test uses Patrol's built-in
// NativeAutomator method `$.native.pickImageFromGallery(index: 0)`
// (patrol 3.20.0, package:patrol/src/native/native_automator.dart) rather
// than hand-rolled UIAutomator selectors. The camera capture path
// (`$.native.takeCameraPhoto`) was deliberately NOT used here - both camera
// and gallery sources feed the same `_takePhoto()` method in
// add_product_flow.dart, so gallery selection exercises identical app logic
// with a much less failure-prone native interaction (no shutter/preview
// timing to automate).
//
// WHAT THIS TEST MEASURES:
//   1. Functional correctness - does the wizard complete without crashing.
//   2. AI processing duration (voice/price/qty "Next" tap -> Review screen
//      populated) - this is a real Gemini API round trip, flagged as a
//      likely UX pain point worth measuring, not assuming.
//   3. AI-prefilled fields are actually non-empty (title/category/
//      description) - a functional check, not just timing. An AI failure
//      leaves these blank rather than crashing the app, so an empty field
//      is a silent failure mode worth catching explicitly.
//   4. Publish duration (Publish tap -> success/failure message) - this
//      triggers SEQUENTIAL Sarvam translation calls (title, category,
//      description, then per-tag) before the WooCommerce publish call,
//      flagged as a likely-slow point worth real measurement.
//
// WHAT THIS TEST DOES NOT MEASURE:
//   - Voice/STT input - the price and quantity fields are typed directly
//     via enterText, not spoken. Automating real speech-to-text input is a
//     separate, much harder automation problem (same category as camera
//     capture) and out of scope here. The voice transcript is left empty;
//     analyzeProduct() in ai_assistant_service.dart does not require a
//     non-empty transcript, so this does not block the AI step.
//   - Whether the Gemini/Sarvam calls themselves are fast - that's
//     Google/Sarvam API latency, outside this app's control. This test
//     measures wall-clock time as experienced by the user, not attributing
//     blame to a specific downstream service.

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
    'home -> add product -> photo -> AI processing -> publish completes successfully',
    ($) async {
      final metrics = <String, Duration>{};
      final stopwatch = Stopwatch();

      String textOf(Symbol key) =>
          $.tester.widget<TextField>($(key).finder).controller!.text;

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

      // --- Language screen ---
      // Defensive scrollTo() before the tap: on some screen sizes the
      // ListView's viewport is too short to fit all 5 language cards at
      // rest, clipping the last one(s) - confirmed via uiautomator dump
      // during the Tamil variant's root-cause investigation. English is
      // first in the list so it doesn't currently need this, but the
      // scroll is a no-op when the target is already visible, so it's safe
      // to add uniformly rather than relying on list position/screen size.
      await $('English').scrollTo();
      await $.tap($('English'));
      await $.pumpAndSettle();

      // Tapping the language card only selects it - navigation to /signup
      // happens on the separate "Continue" button.
      await $.tap($('Continue'));
      await $.pumpAndSettle();

      // --- Signup screen ---
      // No login shortcut is available here - see header note. The values
      // typed below don't end up mattering for this test's phone number:
      // otp_screen.dart will find an existing Firestore doc (from earlier
      // signup test runs) and load its stored profile instead.
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
      // Gallery path, not camera - see header note.
      await $(#add_product_gallery_button).tap();

      // Defensive check: on this device (Android API 36) + image_picker_android
      // 0.8.13+17, the gallery source should invoke Android's system Photo
      // Picker directly, which needs no runtime permission grant - confirmed
      // via `adb shell getprop ro.build.version.sdk` and pubspec.lock, not
      // assumed. This check costs one short timeout either way and protects
      // against that analysis being wrong on a given run/device.
      if (await $.native.isPermissionDialogVisible(
        timeout: const Duration(seconds: 2),
      )) {
        await $.native.grantPermissionWhenInUse();
      }

      // Patrol's default selector for pickImageFromGallery targets a
      // RESOURCE_ID (com.google.android.providers.media.module:id/
      // icon_thumbnail) that doesn't exist on this device: its system Photo
      // Picker is the newer Compose-based com.google.android.photopicker,
      // whose grid items carry no resource-id at all (confirmed via
      // `adb shell uiautomator dump` while the picker was open) - only a
      // contentDescription like "Photo taken on <date>". instance:0 among
      // matches of that pattern is our pushed image: it's the most recent
      // item (see header note on the fixed test image + its touched
      // timestamp), confirmed by the dump showing it at grid position 0.
      await $.native.pickImageFromGallery(
        imageSelector: Selector(
          className: 'android.view.View',
          contentDescriptionStartsWith: 'Photo taken on',
          instance: 0,
        ),
      );

      // pickImageFromGallery's own docs only mention automatic confirmation
      // handling for pickMultipleImagesFromGallery, not this single-image
      // method - and empirically (via `adb shell uiautomator dump` after
      // manually tapping the same thumbnail), this device's picker enters a
      // "1 photos or videos selected" state with a "Done" button rather than
      // returning immediately on tap. So the confirm tap has to happen here
      // explicitly.
      await $.native.tap(Selector(text: 'Done'));

      // A second permission check, after returning from the picker: logcat
      // from an earlier failed run showed GrantPermissionsActivity focused
      // and visible inside this app's own task right after the picker
      // closed - not before opening it, where the first check above already
      // looks. The manifest declares READ_EXTERNAL_STORAGE (a legacy
      // permission not needed by the modern picker flow itself), so
      // something in the app's post-pick code path is likely requesting it
      // explicitly once it has the picked URI in hand.
      if (await $.native.isPermissionDialogVisible(
        timeout: const Duration(seconds: 3),
      )) {
        await $.native.grantPermissionWhenInUse();
      }

      await $.pumpAndSettle();

      // Functional check that the picked image actually landed back in the
      // Flutter widget tree, not just that the native picker closed.
      // add_product_photo_addmore_button only renders once _imagePaths is
      // non-empty (add_product_flow.dart _stepPhoto()).
      expect($(#add_product_photo_addmore_button).exists, true,
          reason: 'Picked image did not register in the app after '
              'returning from the native gallery picker');

      await $(#add_product_photo_next_button).tap();
      await $.pumpAndSettle();

      // --- Step 1: Voice/Price/Qty ---
      // Voice transcript intentionally left empty - see header note.
      await $(#add_product_price_field).enterText('499');
      await $(#add_product_qty_field).enterText('10');

      // --- Step 2: AI Processing ---
      // Tapping "Next" here also triggers _runAi() (add_product_flow.dart).
      stopwatch.start();

      await $(#add_product_voice_next_button).tap();
      await $.pumpAndSettle();

      stopwatch.stop();
      metrics['ai_processing'] = stopwatch.elapsed;
      stopwatch.reset();

      // If AI processing fails, add_product_flow.dart shows
      // add_product_ai_error_message and drops back to step 1 - fail loudly
      // and specifically rather than let a blank review screen pass silently.
      expect(
        $(#add_product_ai_error_message).exists,
        false,
        reason: 'AI processing failed - check Gemini API config/key',
      );

      // --- Step 3: Review ---
      // AI-prefilled fields must actually be populated - an AI failure
      // leaves these blank rather than crashing, so this is a functional
      // check, not just a timing measurement.
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
      // Sequential Sarvam translation calls (title, category, description,
      // then per-tag) happen before the WooCommerce publish call - flagged
      // as a likely-slow point worth real measurement.
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
      print('--- ADD PRODUCT FLOW METRICS ---');
      metrics.forEach((step, duration) {
        // ignore: avoid_print
        print('$step: ${duration.inMilliseconds}ms');
      });
      // ignore: avoid_print
      print('--- ADD PRODUCT AI OUTPUT ---');
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
// 1. Push the fixed test image ONCE (or re-run if this test starts failing
//    to find it at gallery index 0 - e.g. a newer photo/screenshot landed
//    on the device after this file was last touched):
//
//      adb -s <device-id> push \
//        "/Users/heatherhome/Desktop/Karigar Samarthan Tester Kit/1_BlockPrintedCottonDupatta.png" \
//        /sdcard/Pictures/karigar_test_product.png
//      adb -s <device-id> shell touch /sdcard/Pictures/karigar_test_product.png
//      adb -s <device-id> shell am broadcast \
//        -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
//        -d file:///sdcard/Pictures/karigar_test_product.png
//
//    Verify it resolves to index 0 (most recent) before trusting a run:
//
//      adb -s <device-id> shell content query \
//        --uri content://media/external/images/media \
//        --projection _id:_display_name:date_added --sort "date_added DESC"
//
//    ...and confirm karigar_test_product.png is Row 0.
//
// 2. Run on the connected device:
//      patrol test --target integration_test/add_product_flow_test.dart -d <device-id>
//
// 3. print() output does not reach patrol's CLI stdout - pull it from
//    logcat instead:
//      adb -s <device-id> logcat -d | grep "flutter.*PATROL_LOG\|METRICS\|title:\|category:\|description:"
//
// 4. Patrol CLI 3.6.0 has no built-in --record flag. For a screen recording
//    for the Claude UX-judgment pass, run this in the background before the
//    test and stop it after:
//      adb -s <device-id> shell screenrecord /sdcard/add_product_test.mp4
//      ... (run the test) ...
//      adb -s <device-id> shell killall -SIGINT screenrecord
//      adb -s <device-id> pull /sdcard/add_product_test.mp4
