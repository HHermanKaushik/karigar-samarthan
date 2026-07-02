# Karigar Samarthan

Karigar Samarthan is a voice-first, AI-assisted mobile application for Indian artisans (karigars) who sell handmade goods through a WooCommerce marketplace. The app is designed to be usable by people who are not comfortable with smartphones, may have limited literacy, and are encountering digital commerce tools for the first time. Rather than building a separate storefront, it acts as an accessible mobile interface over an existing WordPress and WooCommerce backend, so artisans can create and manage their product listings, view orders, and get help from an AI assistant in their own language.

This project was developed as a third-year group Computer Science capstone project.

---

## What the app does

A karigar opens the app, selects their preferred language during onboarding, and from that point forward can interact primarily through voice. The AI assistant, accessible from the home screen, understands questions like "how do I add a product?" or "show me my orders" and responds in speech in the selected language. Product creation starts with a photo: the karigar takes or selects an image, Gemini AI analyzes it and generates a suggested title, category, description, and tags, and the karigar can review or edit those before publishing. Published products are synced to WooCommerce with their photos uploaded to Firebase Storage. Orders placed through the WooCommerce storefront appear in the app's orders screen. Profile changes (name, store name, phone, UPI ID) are saved locally and synced to both Firestore and the WooCommerce customer record. If the device is offline, the app detects this immediately and shows a clear, friendly message rather than freezing or showing a technical error.

The app supports English, Hindi, Marathi, Bengali, and Tamil throughout the interface, in the AI assistant's voice responses, and in speech recognition.

---

## Technology stack

**Frontend:** Flutter, Riverpod (state management), go_router (navigation)

**Backend and cloud:** Firebase Authentication, Cloud Firestore, Firebase Storage, Firebase Crashlytics, WooCommerce REST API (`/wc/v3`), WordPress Media Library API (`/wp/v2/media`)

**AI and voice:** Google Gemini (product image analysis, conversational assistant), Sarvam AI (speech-to-text via `saarika:v2`, text-to-speech via `bulbul:v3`, supporting all five app languages)

**Audio:** `flutter_sound` (microphone recording), `audioplayers` (TTS playback)

**Local storage:** SharedPreferences

---

## Architecture

### Navigation

go_router drives a modal-first navigation pattern. A persistent `StoreShell` sits underneath all screens. Every sub-screen (product creation, orders, AI assistant, profile, help and support) opens as a bottom sheet over the shell rather than replacing it. This means the karigar always has a sense of where they are and can dismiss anything without losing their place.

### State management

Riverpod manages all shared state. Key providers include `userProvider` (local profile state), `productsProvider` (local product list), `ordersProvider`, `languageProvider` (persisted to SharedPreferences), and service providers for WooCommerce, Sarvam, and the AI assistant.

### Product publishing

When a karigar publishes a product, the photo is uploaded to Firebase Storage with the correct `Content-Type` metadata set (this is required for WooCommerce's sideload to succeed). The resulting public download URL is passed to `/wc/v3/products` as the image source. The WooCommerce product ID returned from that call is stored on the local `Product` model as `wooId`, so subsequent edits can be sent to `/wc/v3/products/{wooId}` via `PUT`. Products that have never been published to WooCommerce show a warning banner in the edit screen indicating they are local only.

### User profile sync

When a user saves their profile, `UserSyncService` writes the profile document to Firestore under `users/{uid}` and either creates or updates the corresponding WooCommerce customer record via `/wc/v3/customers`. If no Firebase Auth user is signed in, the service signs in anonymously first to get a stable `uid`. This anonymous auth session is forward-compatible with Phone Auth: when real OTP-based authentication is added, the anonymous account can be upgraded in place using `linkWithCredential`, keeping the same `uid` and the same Firestore and WooCommerce data without any migration.

### Voice and AI assistant

The AI assistant screen records audio using `flutter_sound` (16kHz mono WAV), sends it to Sarvam's `/speech-to-text` endpoint with the user's selected language code, and passes the resulting transcript to Gemini along with a built-in knowledge base describing the app's navigation and features, plus a live summary of the karigar's actual account data (profile, products listed, recent orders). The Gemini response is then converted to speech by Sarvam's `/text-to-speech` endpoint and played back in the correct language via `audioplayers`. This means the assistant can answer both general questions ("how do I add a product?") and account-specific questions ("what products have I listed?", "what is the status of my orders?") in the karigar's chosen language.

The Sarvam integration lives in `services/sarvam_service.dart`. It calls `api.sarvam.ai` via Dio with an `api-subscription-key` header and does not require a separate SDK.

### Product image analysis

During product creation, a photo is sent to Gemini for analysis. The model returns a structured JSON response containing a suggested title, category, description, and tags. This is presented to the karigar for review before they publish. Gemini also silently checks whether the image contains anything illegal or inappropriate, though this check does not surface to the user in the current version. Future versions will include verbal photo-taking tips for visually impaired or phone-uncomfortable users (framing guidance, lighting suggestions, and so on), generated alongside the product description.

### Sync error logging

Backend synchronization failures (Firebase Storage uploads, WooCommerce API calls, Firestore writes) are logged through `SyncLogger`, which records failures to both Firebase Crashlytics (for alerting) and a `sync_errors` Firestore collection (for queryable triage). Logging is best-effort: if Crashlytics or Firestore are themselves unavailable, the logging failure is caught and printed to the console but does not interrupt the operation that failed.

### Connectivity

`connectivity_plus` provides a fast local check for network availability. When the device is obviously offline (airplane mode, no SIM, wifi off), the app fails immediately with a clear human-readable message rather than waiting for a request timeout. The registration and payment setup flow saves locally first and only attempts the Firestore and WooCommerce sync if the network check passes, with a friendly snackbar if sync cannot be completed.

### Help and support

A Help and Support sheet is accessible from the Home screen. It provides a one-tap call button to the support phone number and an expandable FAQ covering the most common questions: adding a product, changing language, viewing orders, payment setup, and missing product photos.

### Internationalization

`AppLanguage` is an enum covering English (`en-IN`), Hindi (`hi-IN`), Marathi (`mr-IN`), Bengali (`bn-IN`), and Tamil (`ta-IN`). Each value carries both its display codes and its Sarvam BCP-47 code so the same enum drives both the UI and the voice API calls. `LanguageNotifier` persists the selected language to SharedPreferences so it survives app restarts.

---

## Repository structure

```
lib/
  core/
    routes/          go_router configuration
    services/        connectivity_service.dart
    theme/           app colors and theme
    widgets/         shared UI components (voice_button, network_error_view, app_modal)
  features/
    ai_assistant/    conversational AI assistant screen
    auth/            login, signup, payment setup screens
    home/            home screen
    onboarding/      language selection
    orders/          orders list and detail screens
    products/        add_product_flow, edit_product_screen
    profile/         profile screen
    store/           StoreShell (persistent navigation shell)
    support/         help_support_screen (FAQ and call support)
  models/            Product, Order, AppLanguage
  providers/         Riverpod providers (user, products, orders, language, onboarding)
  services/
    ai_assistant_service.dart   Gemini integration (chat and image analysis)
    sarvam_service.dart         Sarvam STT and TTS
    sync_logger.dart            Crashlytics and Firestore error logging
    user_sync_service.dart      Firestore and WooCommerce profile sync
    woocommerce_service.dart    product publish, update, image upload
    service_providers.dart      Riverpod service provider registration
  firebase_options.dart
  main.dart
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

Place your `google-services.json` (Android) at `android/app/google-services.json`. Firebase Firestore, Storage, Authentication, and Crashlytics must all be enabled in your Firebase project. Deploy the included `firestore.rules` and `storage.rules` before running against a production Firebase project.

---

## Known limitations and planned work

The following are intentional scoping decisions in the current version, not bugs.

**Phone Auth.** The app currently signs in via Firebase Anonymous Authentication to obtain a stable `uid` for Firestore and Storage access. Real phone-number OTP authentication is planned. The anonymous session is designed to upgrade cleanly when that work is added.

**AI conversational memory.** The assistant has access to the karigar's live account data on every message but does not retain memory of earlier turns within a single conversation. Each message is treated independently. Conversational memory across turns is planned for a future iteration.

**UPI validation and QR generation.** The karigar can enter and save a UPI ID, and this is synced to their profile. Format validation, QR code generation, and live payment processing are not implemented in this version.

**Photo tips for accessibility.** The image analyzer silently checks for inappropriate content but does not yet provide verbal guidance to visually impaired or phone-uncomfortable users about framing, lighting, or composition. This guidance is planned for a future version.

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
