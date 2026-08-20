# Karigar Samarthan

Karigar Samarthan is a voice-first, AI-assisted mobile application for Indian artisans (karigars) who sell handmade goods through a WooCommerce marketplace. The app is designed to be usable by people who are not comfortable with smartphones, may have limited literacy, and are encountering digital commerce tools for the first time. Rather than building a separate storefront, it acts as an accessible mobile interface over an existing WordPress and WooCommerce backend, so artisans can create and manage their product listings, view orders, and get help from an AI assistant in their own language.

This project was developed as a third-year group Computer Science capstone project. Current app version: **1.1.1+7**.

---

## For evaluators — test credentials

**App login (phone OTP):** use test phone number `8448041541` with OTP `123456` (a Firebase test number — no real SMS is sent). Note that this is only a convenience: Firebase Phone Authentication is fully live and working, so any real phone number will also receive a real OTP and sign in normally.

**Karigar Camp Entry ("Version 2", offline camp tool):** this is a separate, live-deployed WordPress plugin, testable directly on the production site:

1. Log in at [jstrust.in/karigar-samarthan/ks-my-account](https://jstrust.in/karigar-samarthan/ks-my-account/) with:
   - Email: `2023ebcs142@online.bits-pilani.ac.in`
   - Password: `Testuser@142`
2. Click **"Karigar Camps"** in the site header, or go directly to [jstrust.in/volunteer-entry-for-karigar-camps-version-2](https://jstrust.in/volunteer-entry-for-karigar-camps-version-2/).

This tool is designed to work with zero internet connectivity after the page has loaded once — see [Karigar Camp Entry (offline volunteer tool)](#karigar-camp-entry-offline-volunteer-tool) below for how and why.

---

## What the app does

A karigar opens the app, selects their preferred language during onboarding, and from that point forward can interact primarily through voice. The AI assistant, accessible from the home screen, understands questions like "how do I add a product?" or "show me my orders" and responds in speech in the selected language. Product creation starts with a photo: the karigar takes or selects an image, Gemini AI analyzes it and generates a suggested title, category, description, and tags, and the karigar can review or edit those before publishing. Published products are synced to WooCommerce with their photos uploaded to Firebase Storage. Orders placed through the WooCommerce storefront appear in the app's orders screen. Profile changes (name, store name, phone, UPI ID) are saved locally and synced to both Firestore and the WooCommerce customer record. If the device is offline, the app detects this immediately and shows a clear, friendly message rather than freezing or showing a technical error.

The app supports English, Hindi, Marathi, Bengali, and Tamil throughout the interface, in the AI assistant's voice responses, and in speech recognition.

---

## Technology stack

**Frontend:** Flutter, Riverpod (state management), go_router (navigation)

**Backend and cloud:** Firebase Authentication (Phone OTP), Cloud Firestore (named database `karigar`), Firebase Storage, Firebase Crashlytics, Firebase Cloud Functions (Node.js — order webhook ingestion, order re-attribution, moderation review endpoint), WooCommerce REST API (`/wc/v3`), WordPress Media Library API (`/wp/v2/media`)

**AI and voice:** Google Gemini (`gemini-2.5-flash`, via direct REST) for product image analysis, content moderation, and the conversational assistant; Sarvam AI (speech-to-text via `saarika:v2`, text-to-speech via `bulbul:v3`, text translation via `/translate`), supporting all five app languages

**Audio:** `flutter_sound` (microphone recording), `audioplayers` (TTS playback)

**Local storage:** SharedPreferences

**Testing:** `flutter_test` (unit tests), Patrol (on-device integration tests)

**Companion tools (outside the Flutter app):** three WordPress plugins in `wordpress-plugins/` — see [WordPress companion plugins](#wordpress-companion-plugins) below.

---

## Architecture

### Navigation

go_router drives a modal-first navigation pattern. A persistent `StoreShell` sits underneath all screens. Every sub-screen (product creation, orders, AI assistant, profile, help and support) opens as a bottom sheet over the shell rather than replacing it. This means the karigar always has a sense of where they are and can dismiss anything without losing their place.

### State management

Riverpod manages all shared state. Key providers include `userProvider` (local profile state), `productsProvider` (local product list), `ordersProvider`, `languageProvider` (persisted to SharedPreferences), `chatProvider`/`chatSessionProvider` (AI assistant transcript and live Gemini session), and service providers for WooCommerce, Sarvam, and the AI assistant.

### Product publishing

When a karigar publishes a product, the photo is uploaded to Firebase Storage with the correct `Content-Type` metadata set (this is required for WooCommerce's sideload to succeed). The resulting public download URL is passed to `/wc/v3/products` as the image source. The WooCommerce product ID returned from that call is stored on the local `Product` model as `wooId`, so subsequent edits can be sent to `/wc/v3/products/{wooId}` via `PUT`. Products that have never been published to WooCommerce show a warning banner in the edit screen indicating they are local only. Products can also be archived (soft-deleted from the app and delisted from the public storefront via WooCommerce's `status: private`) and later restored via a WhatsApp request to support.

### User profile sync

When a user saves their profile, `UserSyncService` writes the profile document to Firestore under `users/{uid}` and either creates or updates the corresponding WooCommerce customer record via `/wc/v3/customers`. Identity is established via real Firebase Phone Authentication (OTP), not a stub.

### Voice and AI assistant

The AI assistant is a genuine function-calling agent built directly on Gemini's REST API (not the SDK, to avoid crashes from safety-category enums the SDK doesn't yet recognize), with a voice-first interface layered on top. Each open of the assistant creates or reuses a persistent chat session with real multi-turn memory of the conversation — it is not a single-shot Q&A. Every reply loop can chain up to six tool calls before returning text, executed against a live snapshot of the karigar's products and orders:

| Tool | What it does |
|---|---|
| `navigate_to` | Opens a screen (orders, add product, profile, help, FAQ, home) |
| `open_edit_product` | Resolves a spoken/typed product name or category and opens it for editing |
| `mark_order_shipped` | Records tracking number + carrier, notifies the customer, updates status |
| `list_orders` | Returns a filtered order list — new, shipped, delivered, or all |
| `get_order_details` | Full detail on one order, including tracking info if shipped |
| `suggest_price` | Aggregate pricing from similar listings across the whole marketplace |
| `get_product_link` | Returns the public storefront URL for one of the karigar's listings |

Spoken input is transcribed via Sarvam speech-to-text; the reply is synthesized by Sarvam TTS (voice "kavya"), with the device's native TTS as an automatic fallback if Sarvam is unreachable.

The Sarvam integration lives in `services/sarvam_service.dart`. It calls `api.sarvam.ai` via Dio with an `api-subscription-key` header and does not require a separate SDK.

### Product image analysis and content moderation

During product creation, a photo (plus the karigar's spoken description) is sent to Gemini for analysis. The model returns a structured JSON response containing a suggested title, category, description, and tags, presented to the karigar for review before they publish.

The same call runs a hard content-moderation gate: the photo is evaluated against six prohibited categories (firearms/ammunition/explosives, illegal drugs, wild-animal parts, alcohol/tobacco, sexually explicit content, counterfeit branded goods). If flagged, publishing is blocked outright — the karigar sees a spoken, un-dismissable dialog explaining why — and the attempt (photos, reason, account identity) is written to a `flagged_listings` Firestore/Storage audit trail for manual follow-up. There is currently no in-app admin review UI for this collection; a token-gated Cloud Function (`listFlaggedListings`) serves a read-only HTML review page instead.

If the AI vision call itself fails (network error, model outage, malformed response), the flow fails closed — the listing is not published — rather than silently letting an unscreened photo through.

### Sales / Tax Report

From My Account, a karigar can download a summary (current Indian Financial Year quarter or year) of their order count, total sales, and an itemized order list, for their own tax-filing reference. This is deliberately a data summary, not a tax calculation — the export includes an explicit disclaimer to consult a tax professional. Exported via the native share sheet.

### Sync error logging

Backend synchronization failures (Firebase Storage uploads, WooCommerce API calls, Firestore writes) are logged through `SyncLogger`, which records failures to both Firebase Crashlytics (for alerting) and a `sync_errors` Firestore collection (for queryable triage). Logging is best-effort: if Crashlytics or Firestore are themselves unavailable, the logging failure is caught and printed to the console but does not interrupt the operation that failed.

### Connectivity

`connectivity_plus` provides a fast local check for network availability. When the device is obviously offline (airplane mode, no SIM, wifi off), the app fails immediately with a clear human-readable message rather than waiting for a request timeout. Profile and product saves write locally first and only attempt the Firestore/WooCommerce sync if the network check passes, with a friendly notice if sync cannot be completed.

### Help and support

A Help and Support sheet is accessible from the Home screen. It provides a one-tap WhatsApp support link, the same AI assistant, and a searchable FAQ (with audio playback) covering the most common questions.

### Internationalization

`AppLanguage` is an enum covering English (`en-IN`), Hindi (`hi-IN`), Marathi (`mr-IN`), Bengali (`bn-IN`), and Tamil (`ta-IN`). Each value carries both its display codes and its Sarvam BCP-47 code so the same enum drives both the UI and the voice API calls. `LanguageNotifier` persists the selected language to SharedPreferences so it survives app restarts. Product content authored in one language is live-translated (via Sarvam, cached per session) when viewed in another.

### WordPress companion plugins

Three small WordPress plugins live in `wordpress-plugins/`, separate from the Flutter app, installed via the standard WP Admin plugin uploader:

- **`karigar-brand-logo/`** — renders a seller banner (photo, name, shop name, category filter) automatically on each karigar's WooCommerce Brand archive page.
- **`karigar-samarthan-volunteer-entry/`** — a fallback tool letting field volunteers create karigar/product records directly from a WordPress form when a karigar can't use the app themselves.
- **`karigar-samarthan-camp-session/`** — see below.

#### Karigar Camp Entry (offline volunteer tool)

A standalone plugin (independent of `karigar-samarthan-volunteer-entry/` — no shared code) purpose-built for camps with unreliable or no internet connectivity. A volunteer opens the page once while still connected (e.g. before leaving for the village), which loads the tool onto their phone; from that point on, every karigar and product they capture — including photos — is saved directly on the device via IndexedDB, entirely without a network connection. Once the phone regains connectivity at any point, everything queued syncs to WordPress automatically in the background, with per-item retry so one failed upload never blocks the rest of the batch. See [For evaluators](#for-evaluators--test-credentials) above for a live link to try it.

---

## Repository structure

```
lib/
  core/
    constants/       shared constants (legal links, etc.)
    il8n/             AppStrings — static UI translation table (5 languages)
    routes/           go_router configuration
    services/         connectivity_service.dart, tts_service.dart
    theme/            app colors and theme
    utils/            financial_year.dart, product_matching.dart — pure logic
                       extracted for unit testability
    widgets/          shared UI components (voice_button, network_error_view, app_modal)
  features/
    ai_assistant/     conversational AI assistant screen
    auth/             login, signup, OTP, payment setup screens
    home/             home screen
    onboarding/       language selection
    orders/           orders list and detail screens
    products/         add_product_flow, edit_product_screen, archived_products_screen
    profile/          profile screen, tax_report_screen
    store/            StoreShell (persistent navigation shell)
    support/          help_support_screen, faq_screen
  models/             Product, Order, AppLanguage
  providers/          Riverpod providers (user, products, orders, language, chat, onboarding)
  services/
    ai_assistant_service.dart   Gemini integration (chat, tools, image analysis, moderation)
    sarvam_service.dart         Sarvam STT, TTS, and translation
    sync_logger.dart            Crashlytics and Firestore error logging
    user_sync_service.dart      Firestore and WooCommerce profile sync
    woocommerce_service.dart    product publish, update, image upload, price stats
    service_providers.dart      Riverpod service provider registration
  firebase_options.dart
  main.dart
test/                 flutter_test unit tests (see Testing, below)
integration_test/     Patrol on-device integration tests
functions/             Firebase Cloud Functions (Node.js) — order webhook, backfill,
                       moderation review endpoint
wordpress-plugins/     three companion WordPress plugins (see above)
firestore.rules
storage.rules
```

---

## Setup

Clone the repository and install dependencies:

```bash
flutter pub get
flutter run
```

If the Android or iOS platform folders are missing, regenerate them without overwriting the source:

```bash
flutter create --platforms=android,ios .
```

Copy `.env.example` to `.env` and fill in your credentials:

```
WOOCOMMERCE_BASE_URL=https://your-store.example.com
WOOCOMMERCE_CONSUMER_KEY=ck_...
WOOCOMMERCE_CONSUMER_SECRET=cs_...
WP_APP_PASSWORD=xxxx xxxx xxxx xxxx xxxx xxxx
WP_USERNAME=your-wp-username
SARVAM_API_KEY=your-sarvam-key
GENAI_API_KEY=your-gemini-key
```

The WordPress Application Password is required for uploading product photos directly to the WordPress media library. Create one at WP Admin > Users > your user > Application Passwords. The user must have media upload permission (Editor or Administrator role).

Place your `google-services.json` (Android) at `android/app/google-services.json`. Firebase Firestore, Storage, Authentication (Phone sign-in enabled), and Crashlytics must all be enabled in your Firebase project. **Firestore uses a named, non-default database called `karigar`** — create it as such in the Firebase Console, not the default `(default)` database, or the app will not find any data. Deploy the included `firestore.rules` and `storage.rules` before running against a production Firebase project.

### Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions
```

Requires these values set as Firebase Functions secrets (not plaintext), via `firebase functions:secrets:set <NAME>`: `WOO_CONSUMER_KEY`, `WOO_CONSUMER_SECRET`, `KS_ADMIN_TOKEN` (gates the admin-only `backfillOrders` and `listFlaggedListings` endpoints).

---

## Testing

Unit tests (pure logic — Financial Year date math, AI assistant product matching):

```bash
flutter test
flutter test --coverage   # writes coverage/lcov.info
```

On-device integration tests (Patrol — requires a connected Android device):

```bash
patrol test
```

---

## Known limitations and planned work

The following are intentional scoping decisions or known open items, not oversights left undocumented.

**WooCommerce credentials ship inside the app.** The same consumer key/secret used server-side are also compiled into the Android app via `.env`, extractable from the shipped APK. Properly closing this means proxying every WooCommerce call through a Cloud Function instead of calling WooCommerce directly from the client — a larger architectural change than a quick fix.

**No push notifications.** New-order awareness is in-app-badge only; no `firebase_messaging`/FCM integration exists yet.

**No offline retry queue in the main app.** The Flutter app's local-first sync pattern has no durable background retry — a failed sync only re-attempts if the user revisits the same screen. (The separate Karigar Camp Entry WordPress tool, above, does have a full offline queue with background sync — that gap is closed there, not yet in the main app.)

**Unit test coverage is real but narrow.** 22 unit tests cover two extracted, pure-logic modules (Financial Year math, product matching) with 100% line coverage on both — the rest of the app (screens, providers, network-calling services) has no unit coverage and relies on the Patrol integration suite instead.

**No CI.** Nothing runs tests/lint/builds automatically on push — a deliberate choice for this submission, not an oversight.

**Category taxonomy is open-ended.** The AI generates a free-text category per listing rather than choosing from a fixed, controlled list, so near-duplicate categories can accumulate across sellers over time.

**Volunteer-submitted listings have no admin review workflow.** Both WordPress volunteer tools auto-publish immediately by design (a volunteer's fieldwork shouldn't wait on approval), and the moderation audit trail (`flagged_listings`) is a readable log, not an active accept/reject queue.

---

## Screenshots

### Login & Registration

<p align="center">
  <img src="https://github.com/user-attachments/assets/4ddf6b2c-5b54-41ab-9f14-a95446bf398c" width="220"/>
  <img src="https://github.com/user-attachments/assets/814e718d-21ba-4db7-aa46-155a6a35413f" width="220"/>
  <img src="https://github.com/user-attachments/assets/98f2ceaf-102e-4c04-b3d5-56240b62ec41" width="220"/>
  <img src="https://github.com/user-attachments/assets/fb756ce2-9548-443e-bab1-655b02c51fb4" width="220"/>
</p>

### Home Screen

<p align="center">
  <img src="https://github.com/user-attachments/assets/155ee318-2259-4025-a1b0-853e92a6d929" width="220"/>
</p>

### AI Assistant

<p align="center">
  <img src="https://github.com/user-attachments/assets/adad5159-741a-4738-8fa7-db3f19c2f144" width="220"/>
  <img src="https://github.com/user-attachments/assets/7fa27a99-5744-4e5e-b1f3-d91a9571b661" width="220"/>
</p>

### Product Creation

<p align="center">
  <img src="https://github.com/user-attachments/assets/6a067ab5-2aaa-44da-9bd0-cfa83df43046" width="220"/>
  <img src="https://github.com/user-attachments/assets/db2c60ee-ef05-47da-9cae-d853076f9997" width="220"/>
  <img src="https://github.com/user-attachments/assets/d2ec4e1f-af7b-4672-96e4-95c600753130" width="220"/>
  <img src="https://github.com/user-attachments/assets/28654888-a4e7-4b0d-991d-488297050bb1" width="220"/>
</p>

<p align="center">
  <img src="https://github.com/user-attachments/assets/bb48146a-8b15-49a8-babb-0e9ce11bf207" width="220"/>
  <img src="https://github.com/user-attachments/assets/0966e8f4-1f86-4de9-903b-0b6912e82f14" width="220"/>
</p>

### Product Management

<p align="center">
  <img src="https://github.com/user-attachments/assets/98668491-ebe5-4f75-9fd5-9a14c9dd8f80" width="220"/>
</p>

### Orders

<p align="center">
  <img src="https://github.com/user-attachments/assets/b1e4ca14-2573-468d-9811-37887c2c24e7" width="220"/>
  <img src="https://github.com/user-attachments/assets/8c598d3f-4d37-4dd2-a089-17afeac3695c" width="220"/>
</p>

### Profile

<p align="center">
  <img src="https://github.com/user-attachments/assets/7cbd64b9-bd5b-4427-be1d-10ba2a8f8131" width="220"/>
</p>
