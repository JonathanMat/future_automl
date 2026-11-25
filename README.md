# Spell Duel 🧙

Campus Quest – Track D (eigen idee). Twee spelers duelleren met
handgebaren via een videogesprek. Een zelf getraind MediaPipe Gesture
Recognizer-model herkent de spreuk.

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
flutter run --dart-define-from-file=config.json     # echte Firebase + WebRTC (+ TURN en push)
flutter run --dart-define=BACKEND=mock               # bot als tegenstander, geen Firebase
flutter run --dart-define=BACKEND=mock --dart-define=CAMERA=off   # mock zonder camera (simulator)
```

`config.json` (niet in git) maak je door `config.example.json` te kopiëren en
in te vullen: de Metered TURN-gegevens (`TURN_URL`, `TURN_USERNAME`,
`TURN_CREDENTIAL`) en de URL van de push-worker (`PUSH_WORKER_URL`). Zonder
TURN werkt het videogesprek meestal alleen op hetzelfde wifi-netwerk; zonder
worker werkt alles behalve de pushmeldingen.

## Structuur

```
lib/
├── models/        game_rules, game_state, spell_info, player_profile, duel_summary…
├── navigators/    app_router (named routes), room_flow
├── providers/     game, profile, account, friends, challenge, tournament
├── screens/       onboarding, home, lobby, duel, result, friends, leaderboard,
│                  profile, badges, tournament, settings, debug
├── services/      game/ (mock + Firebase/WebRTC), recognition/, face/, audio/,
│                  auth/, social/, push/, tournament/, permissions/, storage/
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

- Flutter (Android/iOS), state management met `provider`
- MediaPipe Gesture Recognizer (`mediapipe_vision`) met een eigen getraind
  model voor de spreuken; MediaPipe Face Landmarker voor de gezichtseffecten
  in de killcam
- Firebase Realtime Database + Anonymous Auth (optioneel Google-login)
- WebRTC (`flutter_webrtc`) voor het videogesprek, met een TURN-server van
  [Metered](https://www.metered.ca/) zodat het ook over 4G/5G werkt
- Cloudflare Workers (`cloudflare/push-worker/`) die via Firebase Cloud
  Messaging pushmeldingen stuurt bij uitdagingen (gratis, geen Blaze-plan)
- `flutter_soloud` voor geluidseffecten

## Hoe we de dataset maakten

We hebben de dataset zelf gemaakt door foto's te nemen van elk gebaar.
Om het model robuust te maken, deden we dat met **meerdere personen** op
**meerdere plaatsen** (andere achtergronden en belichting), en telkens met
zowel de **linker- als de rechterhand**.

Per klasse namen we **rond de 1500 foto's**, voor 5 klassen:

| Klasse | Gebaar |
|---|---|
| `none` | geen gebaar (lege hand, gewone beweging, achtergrond) |
| `fire` | open hand naar voren |
| `ice` | vuist |
| `lightning` | 2 vingers |
| `shield` | beide handen omhoog |

## Faalsituaties

| # | Situatie | Wat er gebeurt | Waarom | Wat we eraan deden |
|---|---|---|---|---|
| 1 | _recognition met teachable machine_ | _De detectie was niet accuraat_ | _teachable machines was puur image recognition en niet speciek op gestures_ | _We zijn geswitched naar een MediaPipe Gesture Recognizer-model_ |
| 2 | _[situatie]_ | _[wat er misgaat]_ | _[oorzaak]_ | _[oplossing / aanpak]_ |
| 3 | _[situatie]_ | _[wat er misgaat]_ | _[oorzaak]_ | _[oplossing / aanpak]_ |

## Reflectie

_Max. 200 woorden per persoon._

### Maarten

_[in te vullen]_

### Jonathan

_[in te vullen]_

## AI-verantwoording

_[in te vullen]_
