# Karigar Samarthan

**Karigar Samarthan** is a multilingual, AI-assisted mobile application designed to help Indian Karigars (artisans) independently manage and sell their handmade products through an existing WooCommerce marketplace.

The application reduces technological barriers by combining voice interaction, multilingual support, AI assistance, and a simplified mobile interface. Rather than replacing an existing e-commerce platform, Karigar Samarthan acts as an accessible mobile layer over a WordPress/WooCommerce backend, enabling artisans with varying levels of digital literacy to participate more confidently in digital commerce.

This project was developed as a final-year Software Engineering capstone project.

---

## Key Features

* Voice-first, multilingual user experience
* AI-powered conversational assistant
* Product creation, editing, and publishing
* WooCommerce marketplace integration
* Firebase user profile synchronization
* Product image upload and AI-assisted image analysis
* Order viewing and management
* Direct UPI payment configuration for artisans
* User profile management
* Offline connectivity detection and recovery
* Built-in Help & FAQ support
* Accessible, low-complexity interface designed for first-time digital sellers

---

## Technology Stack

### Frontend

* Flutter
* Riverpod
* go_router

### Backend & Cloud Services

* Firebase Authentication
* Cloud Firestore
* Firebase Crashlytics
* WooCommerce REST API
* WordPress Media Library API

### Artificial Intelligence

* Google Gemini
* Sarvam AI (Speech-to-Text, Text-to-Speech, and Translation services)

### Local Storage

* SharedPreferences

---

## Architecture

### State Management

Riverpod

### Navigation

go_router (modal-first navigation with persistent StoreShell)

### Marketplace Backend

WooCommerce REST API (`services/woocommerce_service.dart`)

Products are published using the WordPress Media Library (`/wp/v2/media`) together with the WooCommerce Products API (`/wc/v3/products`).

See `.env.example` for the required API credentials.

### User Profiles

User profiles are synchronized between Firestore (`users/{uid}`) and WooCommerce using:

`services/user_sync_service.dart`

### Voice Services

The AI Assistant uses Sarvam AI for Speech-to-Text and Text-to-Speech through:

`services/sarvam_service.dart`

Voice interaction currently powers the conversational AI assistant, while some supporting screens continue using Flutter's native speech and TTS packages.

### Artificial Intelligence

Google Gemini powers:

* Conversational AI assistant
* Product image analysis
* Context-aware responses using live user, product, and order information

### Diagnostics

Backend synchronization failures are recorded through:

* Firebase Crashlytics
* Firestore `sync_errors` collection

using:

`services/sync_logger.dart`

### Connectivity

Offline detection and recovery are handled through:

* `core/services/connectivity_service.dart`
* `core/widgets/network_error_view.dart`

### Help & Support

A built-in Help & Support section provides:

* FAQ
* Contact Support

Accessible from the application's Home screen.

### Internationalization

Application language is managed using:

* `AppLanguage`
* `LanguageNotifier`

Language preferences are persisted using SharedPreferences.

---

## User Experience Philosophy

Karigar Samarthan follows a **voice-first, mobile-first, and accessibility-first** design philosophy.

The application minimizes typing, reduces navigation complexity, and presents clear workflows that support artisans with varying levels of digital literacy. Wherever possible, tasks are designed to be completed through guided interactions and voice assistance rather than requiring extensive technical knowledge.

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


---

## Installation

Clone the repository and install dependencies:

```bash
flutter pub get
flutter run
```

If the Android or iOS platform folders are missing, regenerate them using:

```bash
flutter create --platforms=android,ios .
```

This preserves the Flutter source code (`lib/`), assets, and `pubspec.yaml` while recreating the native platform projects.

---

## Future Enhancements

Potential future improvements include:

* Logistics and shipping integration
* Payment gateway integration
* Enhanced analytics and reporting
* Expanded multilingual support

---

## Project Goal

Karigar Samarthan demonstrates how AI, multilingual voice interaction, and accessible mobile design can reduce barriers to digital commerce for traditional artisans while leveraging existing marketplace infrastructure through WooCommerce integration.
