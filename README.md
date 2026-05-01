# Shift My OCD

A Flutter app helping people with OCD/checking anxiety. Users tap NFC tags
or scan QR codes attached to household objects to register that they've
checked them, building trust in their own memory and reducing repetitive
checking behavior.

Built for Shift Hackathon 2025/26.

## Features

- NFC and QR-code based check-ins for tagged objects
- Trust Score
- Anxiety-pattern analytics (app opens vs. physical checks)
- PDF export designed for sharing with a therapist
- Anonymous auth — no signup friction

## Tech Stack

- **Flutter** (Android + iOS)
- **Firebase**: Firestore, Auth, (optionally Cloud Functions)
- **Packages**: `nfc_manager`, `mobile_scanner`, `fl_chart`, `pdf`

## Getting Started

### Prerequisites

- Flutter SDK 3.5+
- Android Studio or VS Code with Flutter extension
- A Firebase project (ask team lead for access)

### Setup

#### Install and Run Flutter

- Go to <https://docs.flutter.dev/install/quick> and install it manually
- Add Flutter to path
- Add Flutter extension to VSCode

#### Allow Phone to emulate

- Enable USB debugging (flutter -devices to confirm if the device is listed)
- Choose the correct device in the VSCode tab bellow

#### Clone Repository

```bash
git clone https://github.com/elme-engineer/shiftmyocd.git
cd shiftmyocd
flutter pub get
```

### Firebase configuration

Each developer must connect to the shared Firebase project:

```bash
npm install -g firebase-tools         # if not installed
dart pub global activate flutterfire_cli # Add flutterfire to path (See the output)
firebase login # Team members need to accept the invitation on firebase console
flutterfire configure --project=shiftmyocd 
```

This generates `lib/firebase_options.dart` and platform configs locally.

#### Commands

```bash
flutter doctor  # (checks correct instalation of flutter)
flutter run # (runs the app)
flutter clean # (clean build files)
flutter pub get # (update dependencies)
```

## Project Structure
