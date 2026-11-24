# Spell Duel – backend

Firebase Realtime Database (rooms, rounds, scores) + WebRTC (video call).
Models live in `lib/models/`, the backend in `lib/services/game/`.

| File | What it does |
|---|---|
| `models/game_rules.dart` | Spells, who beats whom, `resolveRound()`. Pure Dart, fully tested. |
| `models/game_state.dart` | `GameState` the UI listens to: phase, lives, round result… |
| `services/game/game_backend.dart` | **The interface the frontend uses.** |
| `services/game/mock_game_backend.dart` | Offline version with a bot opponent, for UI work. |
| `services/game/commit_reveal.dart` | Hash trick so nobody can read the opponent's spell early. |
| `services/game/firebase/firebase_game_backend.dart` | The real backend. |
| `services/game/firebase/webrtc_call.dart` | Video call, signaling via Firebase. |
| `services/game/firebase/ice_config.dart` | STUN/TURN servers. |
| `database.rules.json` (repo root) | Firebase security rules. |
| `screens/debug/backend_debug_page.dart` | Simple test screen (not the real UI). |

## For Jonathan (frontend)

```dart
final GameBackend backend = FirebaseGameBackend(); // default in main.dart
// final GameBackend backend = MockGameBackend();   // no Firebase needed

final code = await backend.createRoom(playerName: 'Maarten'); // show code
await backend.joinRoom('K7QX', playerName: 'Jonathan');      // other phone

backend.gameState.listen((s) { /* rebuild UI */ });
backend.localStream;   // own camera  -> RTCVideoRenderer.srcObject
backend.remoteStream;  // opponent    -> RTCVideoRenderer.srcObject

// Model: ~5x per second, only while s.canCast
final png = await backend.captureLocalFrame(); // run TFLite on this
await backend.submitSpell(Spell.vuur);         // once >90% for 0.5 s
```

- **Do not open the camera with the `camera` plugin.** The video call owns
  it; use `captureLocalFrame()` (PNG bytes) for the model.
- `GameState.phase`:
  `waitingForOpponent → countdown → cast → resolving → roundResult → countdown …
  → finished`. The backend emits each phase change on time.
- **Blur the opponent's video** during `countdown`, `cast` and `resolving`,
  otherwise you can see their hand and react.
- Countdown text: `s.castAt.difference(DateTime.now())`. `castAt` is already
  corrected to this phone's clock, so both phones hit CAST together.
- `s.canCast`, `s.myShieldAvailable`, `s.lastResult`, `s.iWon`, `s.error`.
- `submitSpell` throws `GameBackendException` when it's too early/late, you
  already cast, or the shield is used up.
- Firebase is the default: `flutter run`. With the mock:
  `flutter run --dart-define=BACKEND=mock`.

## Rules (in `game_rules.dart`)

| Spell | Gesture | Beats | Loses to |
|---|---|---|---|
| ijs | fist | vuur | bliksem |
| vuur | open hand forward | bliksem | ijs |
| bliksem | 2 fingers | ijs, schild | vuur |
| schild (1×) | both hands up | vuur, ijs | bliksem |

- 3 lives. Loser of a round loses 1 life. Same spell (also shield vs shield):
  nobody loses a life. A cast shield is used up, even in a draw.
- **Decision we made in code, check with Jonathan:** casting nothing in time
  (or a second shield) loses against any spell; nobody casting is a draw.
- Timing (`GameConfig`): 3 s countdown, 2 s cast window, 3 s result pause.

## How a round works

1. Host phone writes `rounds/{n}/castAt` (server time).
2. At CAST each phone writes only a **commit**: `sha256(spell:salt)` plus the
   server time it arrived (`at`). The rules force `at` to be the real server
   time, so you can't fake being on time.
3. When both commits are in (or the window closed), each phone **reveals**
   spell + salt.
4. Host checks: commit within the cast window (+600 ms network tolerance),
   hash matches → otherwise "no spell". Then `resolveRound()` and one atomic
   update for result, lives and shields.
5. After 3 s the host starts round n+1. At 0 lives: `status: finished` and
   each phone adds a win/loss to its own `leaderboard/{uid}`.

Why commit-reveal: the database is readable by both players. Without it you
could read the opponent's spell in the database and cast the counter.

## Setup (once)

1. [console.firebase.google.com](https://console.firebase.google.com) → new
   project (Spark plan, free).
2. **Build → Authentication → Sign-in method → Anonymous → enable.**
3. **Build → Realtime Database → create** (location `europe-west1`), start in
   locked mode.
4. Realtime Database → **Rules** → paste `database.rules.json` → Publish.
5. In the project root:
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   This replaces the placeholder `lib/firebase_options.dart` and adds the
   Android/iOS config files.
   If the database URL is in another region than the default, check that
   `databaseURL` is filled in in `firebase_options.dart`.
6. TURN (needed on 4G/5G): make a free account at Metered (free plan, no
   credit card) and create a TURN credential. Then:
   - copy `config.example.json` to `config.json` (git-ignored) and fill in
     the URLs, username and credential from the Metered dashboard
     (several TURN URLs: separate them with commas);
   - run or build with that file:
     ```
     flutter run --dart-define-from-file=config.json
     flutter build apk --release --dart-define-from-file=config.json
     ```
   These are compile-time values: normal OS environment variables are not
   read by the app.

## Testing

- `flutter test` – rules (all 16 spell pairs), commit-reveal, mock game.
- Two phones: both `--dart-define-from-file=config.json`, one "Kamer maken", other
  "Joinen" with the code. Test on the same wifi first, then one phone on 4G.

## Known limits

- The host phone is trusted: it decides results. A modified host app could
  cheat. Fine for a school project; a Cloud Function would fix it but needs
  the paid Blaze plan.
- Rejoining after the app was killed restores the game state but not the
  video call: leave and make a new room.
- Old rooms are not cleaned up automatically.
- Privacy: video and audio go phone-to-phone (or via TURN, encrypted). Firebase
  only sees names, spell names, hashes and scores.
