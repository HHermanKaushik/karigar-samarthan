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
- Backend: WooCommerce REST (placeholder Dio client)
- Voice: speech_to_text + flutter_tts
- AI: abstracted service layer (Sarvam STT/TTS + GenAI placeholders)
- i18n: AppLanguage enum + LanguageNotifier persisted via SharedPreferences

## UX Philosophy

Modal-first, voice-first, minimal typing, no-fear UX. See `AGENTS.md`.
