# Spell Duel 🧙

Campus Quest – Track D (eigen idee). Twee spelers duelleren met
handgebaren via een videogesprek. Een zelf getraind Teachable
Machine-model herkent de spreuk.

| Spreuk | Gebaar | Wint van | Verliest van |
|---|---|---|---|
| ❄️ IJs | vuist | 🔥 Vuur | ⚡ Bliksem |
| 🔥 Vuur | open hand naar voren | ⚡ Bliksem | ❄️ IJs |
| ⚡ Bliksem | 2 vingers | ❄️ IJs, 🛡️ Schild | 🔥 Vuur |
| 🛡️ Schild (1× per spel) | beide handen omhoog | 🔥 Vuur, ❄️ IJs | ⚡ Bliksem |

- 3 levens per speler; wie een ronde verliest, verliest 1 leven.
- Zelfde spreuk of schild tegen schild: niemand verliest een leven.

## Starten

```
flutter pub get
flutter run                                          # echte Firebase + WebRTC
flutter run --dart-define=BACKEND=mock               # bot als tegenstander, geen Firebase
flutter run --dart-define=BACKEND=mock --dart-define=CAMERA=off   # mock zonder camera (simulator)
```

## Structuur

```
lib/
├── models/        game_rules, game_state, spell_info, player_profile, duel_summary…
├── navigators/    app_router (named routes)
├── providers/     GameProvider (backend + herkenning), ProfileProvider (profiel, vrienden)
├── screens/       onboarding, home, lobby, duel, result, friends, leaderboard, settings, debug
├── services/      game/ (mock + Firebase/WebRTC), recognition/, storage/
├── theme/         kleuren, typografie, thema, transities
├── utils/         constanten, extensies, rondetekst
├── validators/    kamercode, spelersnaam
└── widgets/       generic/ + één map per feature
```

Camera en microfoon worden gevraagd vóór er een kamer gemaakt wordt
(`services/permissions/camera_permission_service.dart`). Wie weigert, krijgt
uitleg en een knop naar de instellingen (native kanaal `spell_duel/app_settings`
in `MainActivity.kt` en `AppDelegate.swift`).

Gebarenherkenning: MediaPipe Gesture Recognizer met het eigen model
`assets/models/gesture_recognizer.task` (labels fire, ice, lightning, shield,
none), 2 handen, VIDEO-modus (`services/recognition/mediapipe_spell_recognizer.dart`).
Twee handen met de polsen dicht bij elkaar tellen als shield
(`services/recognition/gesture_logic.dart`). Bijstellen in
`lib/utils/gesture_constants.dart`: `shieldDistance`, `minScore`,
`stableFrames` en `debug` (debug-overlay op je eigen camera tijdens het duel).
Android heeft minstens Android 9 (API 28) nodig voor MediaPipe.
Zonder model of camera cast je door op een spreuk te tikken.

Firebase-setup, datamodel en hoe de frontend de backend gebruikt:
zie [docs/BACKEND.md](docs/BACKEND.md). Het oorspronkelijke concept staat in [docs/CONCEPT.md](docs/CONCEPT.md).

## Stack

- Flutter (Android/iOS)
- Teachable Machine (Image project) → TensorFlow Lite
- Firebase Realtime Database + Anonymous Auth
- WebRTC (`flutter_webrtc`) voor het videogesprek

## TODO (in te vullen)

- Hoe we de dataset maakten
- Faaltabel (3 situaties)
- Reflectie (max. 200 woorden)
- AI-verantwoording
