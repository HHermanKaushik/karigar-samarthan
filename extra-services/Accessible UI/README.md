# Karigar Samarthan

Multilingual AI-assisted seller platform for Indian Karigars (artisans).

## Setup

```bash
flutter pub get
flutter run
```

If a platform folder (android/ios) is missing, regenerate with:

```bash
flutter create --platforms=android,ios .
```

This preserves `lib/`, `pubspec.yaml`, and `assets/` while adding native shells.

## Architecture

- State: Riverpod
- Routing: go_router (modal-first; sub-screens are bottom sheets / overlays over a persistent StoreShell)
- Backend: WooCommerce REST (`services/woocommerce_service.dart`) — products are
  published via the WordPress media library (`/wp/v2/media`, Application
  Password auth) + `/wc/v3/products`. See `.env.example` for required keys.
- User profiles: synced to Firestore (`users/{uid}`) and linked to a
  WooCommerce customer via `services/user_sync_service.dart`. Auth is
  currently Firebase Anonymous (bridge until real Phone Auth is added).
- Voice (AI Assistant chat): Sarvam AI STT/TTS via `services/sarvam_service.dart`
  (`record` for mic capture, `audioplayers` for playback), driven by the
  user's selected `AppLanguage`. Other screens (add-product voice input,
  onboarding/profile TTS) still use on-device `speech_to_text` / `flutter_tts`
  pending a follow-up sweep.
- AI: Gemini (`services/ai_assistant_service.dart`) for chat + product-photo
  analysis, with an app "knowledge base" and live account/product/order
  context injected into prompts.
- Diagnostics: `services/sync_logger.dart` logs backend-sync failures to
  Firebase Crashlytics + a `sync_errors` Firestore collection.
- Connectivity: `core/services/connectivity_service.dart` +
  `core/widgets/network_error_view.dart` for fast offline detection and
  friendly error UI.
- Help & Support: `features/support/help_support_screen.dart` (Call Support
  + FAQ), reachable from the Home screen "Help" button.
- i18n: AppLanguage enum + LanguageNotifier persisted via SharedPreferences

## UX Philosophy

Modal-first, voice-first, minimal typing, no-fear UX. See `AGENTS.md`.
