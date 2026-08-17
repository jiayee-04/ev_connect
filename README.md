# EV Connect (Flutter / Android Studio)

A green-themed EV charging station finder app for Malaysia, built as a
prototype using Flutter. Covers the modules from the project brief:
Charging Locator, Charging Management, and a Sustainability-adjacent
home screen (with an ad carousel for monetisation), plus authentication
and a simulated payment flow.

## Getting started

1. Install Flutter (https://docs.flutter.dev/get-started/install) and
   Android Studio with the Flutter/Dart plugins.
2. Copy this whole `ev_connect` folder into your Android Studio
   projects folder (or `File > Open` it directly - it's already a
   valid Flutter project, just missing the auto-generated
   android/ios/ platform folders).
3. In a terminal inside the folder, run:
   ```
   flutter create .
   ```
   This regenerates the platform-specific `android/`, `ios/`, `web/`
   etc. folders around the existing `lib/` and `pubspec.yaml` without
   touching your code.
4. Run:
   ```
   flutter pub get
   flutter run
   ```

## What's included

- **Auth**: Sign up / Login / Forgot password, backed by
  `SharedPreferences` (demo-only, no real backend). Email format,
  password length, phone number format and "passwords match" are all
  validated before submit.
- **Home**: Auto-sliding advertisement carousel (the monetisation
  slot you asked for, replacing the static banner), quick actions,
  and a nearby-stations preview.
- **Charging Station module**: List/Map toggle (map is a placeholder
  panel - wire up `google_maps_flutter` + an API key to show live
  pins), search with recent/popular suggestions, and a filter sheet
  (connector type, distance, availability, provider).
- **Station details**: connector tags, price per kWh, favourite
  toggle, "Book & Start Charging".
- **Fare calculator / booking confirm**: slider to estimate kWh,
  shows estimated time and fare.
- **Payment (simulated)**: choose TnG eWallet or Credit/Debit Card.
  - Card: 16-digit number with Luhn check, MM/YY expiry that
    rejects past dates, 3-digit CVV, cardholder name - all validated
    with inline error messages, plus a live card preview.
  - TnG: phone number pre-filled from the logged-in account.
  - Both show a short fake "processing" delay, then a receipt screen
    with a generated reference number.
- **Favourites**, **Charging History**, **My Vehicle / Edit Vehicle**,
  **Notifications**, **Profile / Edit Profile / Settings / Help &
  Support** - all in the same green theme with a consistent header
  (logo + title) and footer (Home / Stations / Vehicle / Alerts /
  Profile).

