// integration_test/home_connectivity_test.dart
//
// FLOW UNDER TEST: the Firestore -> WooCommerce reconcile race window
// flagged in the original code inventory: HomeScreen renders the Firestore
// snapshot immediately, then reconciles against a WooCommerce fetch a frame
// later. This test observes that transition directly rather than assuming
// its shape from the inventory summary.
//
// OFFLINE BANNER - DROPPED, NOT AUTOMATABLE ON THIS SETUP: this test
// originally also toggled airplane mode to time the offline_banner's
// appear/disappear. That was abandoned after empirical investigation showed
// it can't work reliably here: even with airplane_mode_on=1 (confirmed via
// `adb shell settings get global airplane_mode_on`), `adb shell dumpsys
// connectivity` still showed WiFi CONNECTED (Samsung One UI's "keep Wi-Fi on
// during airplane mode" behavior) AND cellular/LTE CONNECTED (an IMS-related
// exception), AND a USB network transport (rndis0) tied to the ADB
// connection this whole test harness depends on. connectivityProvider
// (connectivity_plus) only needs ANY transport connected to report "online"
// - so the app's offline detection was working correctly, the device just
// never actually went offline. Fixing this would require explicitly
// disabling WiFi and cellular too, and the USB/ADB transport itself would
// still be an open question. Decided not worth pursuing on this physical
// device-over-USB setup - if this matters later, verify the offline banner
// manually (toggle airplane mode by hand and watch the app) rather than via
// this automated test.
//
// TEST NAME - KEEP IT PLAIN: patrolTest()'s description string ends up as
// part of a dynamically-generated JUnit test-case identifier
// (runDartTest[<file> <description>]). A description containing "+" or "/"
// (e.g. "offline banner timing + Firestore/WooCommerce reconcile race")
// reproducibly crashed the native instrumentation process before any Dart
// test code ran at all - confirmed via bisection: an otherwise-identical
// bootstrap-only test crashed with that description and passed immediately
// once the description was simplified to plain words. Don't add slashes or
// plus signs back into this string.
//
// GETTING TO HOME: same as signup_flow_test.dart and add_product_flow_test.dart
// - onboarding_provider.dart backs "onboarding complete" with SharedPreferences
// (device-local), and patrol test's default --uninstall wipes it before every
// run, so every run starts fresh at LanguageScreen and must go through the
// full signup -> OTP bootstrap. No login shortcut exists here either.
//
// THE RECONCILE RACE (verified against home_screen.dart + products_provider.dart,
// not assumed from the inventory note alone): it's more specific than "Firestore
// stream vs WooCommerce fetch". ProductsNotifier's constructor calls
// _loadFromFirestore() - a ONE-TIME .get() (not a live snapshot listener) - state
// starts as [] and updates once that resolves. Separately, HomeScreen.initState()
// schedules _syncProducts() via addPostFrameCallback (one frame after first
// build), which fetches WooCommerce's active product IDs and calls
// productsProvider.notifier.refresh(activeIds) - this re-fetches Firestore AGAIN
// and, critically, DELETES any Firestore product doc whose wooId isn't in the
// active WooCommerce list, then updates state to the filtered set. So the
// reconcile can permanently remove data, not just re-render it.
//
// CAPTURING THE TRANSITION - WHY NOT pumpAndSettle(): pumpAndSettle() pumps
// until the widget tree stops changing at all, which would blow straight past
// the very transition this test exists to observe (it doesn't return early once
// a specific widget appears - confirmed by reading patrol_finders' pumpAndSettle
// implementation). Instead, this test uses waitUntilVisible() to advance to
// Home's first paint (confirmed via patrol_tester.dart: it pumps in 100ms
// increments and returns as soon as the target widget is hit-testable, without
// continuing to settle further - exactly what's needed here), takes a product-tile
// count snapshot, pumps a bit more, snapshots again, then lets everything fully
// settle and snapshots the final reconciled state. The comparison that matters is
// the delta between the pre-reconcile and post-reconcile counts, not the exact
// shape of the intermediate frame (that part is inherently racy by nature, since
// _loadFromFirestore() and _syncProducts() are two independent async chains with
// no ordering guarantee between them).
//
// STAGED DATA FOR THIS RUN: by design, all products published via
// add_product_flow_test.dart runs remain active on WooCommerce afterward, so a
// fresh Home load normally shows no visible reconcile difference - there's
// nothing mismatched to filter out. To make the race condition's effect
// observable at all, one of those previously-published test products was
// manually trashed in the WooCommerce admin before running this test (trashing,
// not deleting outright - WooCommerce's `status=any` query in
// fetchActiveProductIds() excludes trashed products per WordPress core's 'any'
// status semantics, confirmed against woocommerce_service.dart, so a trashed
// product's Firestore doc is exactly what refresh() will filter/delete).
//
// WHAT THIS TEST MEASURES:
//   Whether the Firestore -> WooCommerce reconcile produces a visible
//   product-count change on this run's staged data, and what specifically
//   changed (logged, not just asserted pass/fail).
//
// WHAT THIS TEST DOES NOT MEASURE:
//   - The exact frame-by-frame shape of the race on "clean" data (all products
//     matching WooCommerce) - that case produces no visible difference by
//     design, so there's nothing to observe without staging a mismatch first.
//   - The offline banner - see note above.

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
    'home connectivity and reconcile test',
    ($) async {
      int productTileCount() => find
          .byWidgetPredicate((widget) {
            final key = widget.key;
            return key is ValueKey &&
                key.value.toString().startsWith('home_product_tile_');
          })
          .evaluate()
          .length;

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

      // --- Capture the Home-load race window ---
      // Deliberately NOT pumpAndSettle() here - see header note. This advances
      // just far enough for Home's first frame, without continuing to settle
      // past the transition being observed.
      await $(#home_refresh_indicator).waitUntilVisible();

      expect(
        $(#otp_verification_error_message).exists,
        false,
        reason: 'OTP verification failed - check test phone/code config '
            'in Firebase console',
      );

      final countAtFirstPaint = productTileCount();

      // Give _loadFromFirestore()'s one-time .get() a moment to resolve if it
      // hadn't already by first paint.
      await $.tester.pump(const Duration(milliseconds: 500));
      final countAfterFirestoreLoad = productTileCount();

      // Now let the WooCommerce fetch + refresh() reconcile fully complete.
      await $.pumpAndSettle();
      final countAfterReconcile = productTileCount();

      // ignore: avoid_print
      print('--- HOME RECONCILE RACE ---');
      // ignore: avoid_print
      print('product tiles at first paint: $countAtFirstPaint');
      // ignore: avoid_print
      print(
          'product tiles after 500ms (pre-reconcile): $countAfterFirestoreLoad');
      // ignore: avoid_print
      print(
          'product tiles after full settle (post-reconcile): $countAfterReconcile');

      // The reconcile only ever removes products (see refresh() in
      // products_provider.dart), never adds - this invariant holds regardless
      // of exact timing between the two independent async chains.
      expect(countAfterReconcile <= countAfterFirestoreLoad, true,
          reason: 'Product count increased after reconcile, which refresh() '
              'should never do - investigate products_provider.dart');

      if (countAfterReconcile < countAfterFirestoreLoad) {
        // ignore: avoid_print
        print(
            'Reconcile removed ${countAfterFirestoreLoad - countAfterReconcile} '
            'product(s) - staged WooCommerce mismatch was detected correctly.');
      } else {
        // ignore: avoid_print
        print('No reconcile-driven change observed on this run\'s data.');
      }
    },
  );
}

// -----------------------------------------------------------------------
// HOW TO RUN
// -----------------------------------------------------------------------
// 1. Before running, stage a WooCommerce/Firestore mismatch so the reconcile
//    race has something observable to filter out: in the WooCommerce admin,
//    trash (not permanently delete) one of the products previously published
//    by add_product_flow_test.dart runs. Without this, this test will
//    correctly report "no change observed" since clean data has nothing to
//    reconcile away.
//
// 2. Run on the connected device:
//      patrol test --target integration_test/home_connectivity_test.dart -d <device-id>
//
// 3. print() output does not reach patrol's CLI stdout - pull it from
//    logcat instead:
//      adb -s <device-id> logcat -d | grep "flutter.*PATROL_LOG\|RACE\|reconcile"
//
// 4. Patrol CLI 3.6.0 has no built-in --record flag. For a screen recording:
//      adb -s <device-id> shell screenrecord /sdcard/home_connectivity_test.mp4
//      ... (run the test) ...
//      adb -s <device-id> shell killall -SIGINT screenrecord
//      adb -s <device-id> pull /sdcard/home_connectivity_test.mp4
