# AI Keyboard

A native-style iPhone keyboard with on-demand AI rewriting, powered by Google
Gemini. Type normally; tap **AI** for three rewrites; swipe between them like
Photos; pick a tone; tap a rewrite to instantly replace your text.

## Layout

- `AIKeyboard/` — companion app (SwiftUI): status, setup steps, Gemini API key
  configuration (Keychain + App Group), settings, about.
- `Keyboard/` — the keyboard extension (UIKit): native-style QWERTY keyboard,
  suggestion bar with the AI button, sliding AI panel, rewrite engine.
- `Shared/` — code compiled into both targets: `AIProvider` abstraction,
  `GeminiProvider`, provider factory, `SecretStore` (Keychain/App Group),
  `SettingsStore`.

## Build (GitHub Actions → unsigned IPA)

1. Push this repository to GitHub (branch `main`).
2. Run the **Build Unsigned IPA** workflow (or push to `main`).
3. Download the `AIKeyboard-unsigned-ipa` artifact.
4. Sign and install with Sideloadly.

## Setup on device

1. Open the AI Keyboard app.
2. In **Gemini API & Settings**, paste your Gemini API key (get one free at
   ai.google.dev), tap **Save**, then **Test Connection** → "Gemini Connected".
3. Settings → General → Keyboard → Keyboards → **Add New Keyboard** → AI Keyboard.
4. Tap AI Keyboard in the keyboard list and enable **Allow Full Access**
   (required for network calls to Gemini).
5. In any app, long-press the globe key to switch to AI Keyboard.

## Notes for sideloading

- Free Apple IDs cannot use App Groups across apps signed with different
  provisioning. Sideloadly signs the app and its extension together, and
  `SecretStore` falls back to App Group `UserDefaults` when shared-Keychain
  access is unavailable, so the key still reaches the keyboard.
- If the keyboard shows "Turn on Allow Full Access", do step 4 above.
- The API key is never stored in this repository and never hardcoded.
