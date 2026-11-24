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
flutter run                                  # mock-backend met een bot
flutter run --dart-define=BACKEND=firebase   # echte Firebase + WebRTC
```

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
