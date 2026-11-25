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

// Emotes, any time both players are in the room
await backend.sendEmote(Emote.gg);
backend.opponentEmotes.listen((e) { /* show it + play its sound */ });
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
- Emotes live in `rooms/{code}/emotes/{uid}` (`{e, at}`, one slot per
  player, overwritten each time). Emotes older than 5 s when they arrive are
  not shown. After changing `database.rules.json`, deploy it:
  `firebase deploy --only database`.
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

## Friends

`services/social/` (`FriendsBackend`, Firebase + mock) and
`providers/friends_provider.dart`. Uses the same anonymous Firebase uid as
the game.

```
users/{uid}: {name, friendCode}
friendCodes/{code}: uid                       // 6 chars, unique
friendRequests/{toUid}/{fromUid}: {name, at}
friends/{uid}/{friendUid}: <server ms>         // stored on both sides
```

- Add by code (or the "+" next to a recent opponent) writes a request.
  If they already asked you, it accepts right away.
- Accept = one atomic update: both `friends/` entries + delete the request.
  The rules only allow a `friends/` entry while that request exists.
- Scorebord "Vrienden" = you + your friends' `leaderboard/{uid}` (live),
  "Global" = top 20 of everyone.
- "Recent gespeeld" on the Vrienden page is still local (this phone only).
- Players start as an anonymous **guest**; the uid is per install.
  Reinstalling (or clearing app data) as a guest gives a new uid, friend
  code and empty friend list.

## Challenges + push

`providers/challenge_provider.dart`, `services/push/push_service.dart`,
`cloudflare/push-worker/`.

```
invites/{toUid}/{fromUid}: {name, tag, roomCode, at}   // only between friends
fcmTokens/{uid}/{token}: true                          // only owner can read
pushLog/{toUid}/{fromUid}: at                          // worker only
```

- "Daag uit" (⚡ on a friend) makes a room, writes the invite and opens
  the lobby. The invite is removed when the friend joins or you leave.
- The friend sees a banner on Home, Vrienden and Scorebord (not in a
  room). "Speel" joins, "Weiger" removes it. Invites older than 3 minutes
  are hidden.
- Push: after writing the invite the app calls the **Cloudflare Worker**
  with its Firebase ID token. The worker checks the token, checks that
  the invite exists (so only friends can trigger a push), and sends it
  with FCM. Free: no Blaze plan needed. Without the worker (no
  `PUSH_WORKER_URL`) everything works except the notification.

Setup (once):
1. Firebase console → Project settings → **Service accounts → Generate
   new private key**. Keep the JSON file secret (not in git).
2. Free account at [dash.cloudflare.com](https://dash.cloudflare.com).
3. ```
   cd cloudflare/push-worker
   npm install
   npx wrangler login
   npx wrangler secret put FIREBASE_SERVICE_ACCOUNT   # paste the whole JSON
   npx wrangler deploy
   ```
   `deploy` prints the URL, e.g. `https://spell-duel-push.<you>.workers.dev`.
4. Put it in `config.json` as `"PUSH_WORKER_URL"` and rebuild the app.
5. iOS only: APNs key in Firebase → Cloud Messaging (see Firebase docs).

Database rules: paste `database.rules.json` in the console, or
`firebase deploy --only database` (works on the free plan).

## Account (optional Google login)

`services/auth/` + `providers/account_provider.dart`, card in Instellingen.

- **Guest → Google**: `linkWithCredential` on the anonymous user. The uid
  stays the same, so friends, friend code and leaderboard carry over.
- **Google account that already has data** (e.g. a new phone):
  `credential-already-in-use` → sign in to that account instead. The
  guest's server data stays behind; friends reload for the new uid.
- **Uitloggen**: signs out of Google and continues as a new guest.
- XP, level, wins and last duel are synced to `users/{uid}/progress`
  (FriendsProvider). Normal start: the copy with the most XP wins. After
  switching account: that account's progress replaces the phone's.
- "Recent gespeeld" stays on the phone only.
- **A guest that never linked Google can't be recovered** after an
  uninstall: the anonymous account is gone with the app.

Setup (once):
1. Firebase console → Authentication → Sign-in method → **Google → enable**.
2. Project settings → Android app → **add SHA-1** of your signing key
   (`cd android && ./gradlew signingReport`; debug and release key).
3. Run `flutterfire configure` again so `google-services.json` gets the
   OAuth client (the `oauth_client` list must not be empty).
   Without it, pass the *Web client ID* from Authentication → Google as
   `"GOOGLE_SERVER_CLIENT_ID"` in `config.json`.
4. iOS: add `GoogleService-Info.plist` and the `REVERSED_CLIENT_ID` URL
   scheme in `ios/Runner/Info.plist` (see the `google_sign_in_ios` README).

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

## Badges

`models/badge.dart` (the 18 badges), `models/player_stats.dart` (lifetime
counters) and `ProfileProvider.recordGame`.

```
users/{uid}/progress/stats/{key}: number      // e.g. wins_vuur, reflects, fastestMs
users/{uid}/progress/badges/{badgeId}: <ms>   // when it was unlocked
```

- After every duel the stats are updated and every badge is checked; new
  ones pop up on the result screen (`showBadgeUnlocks`).
- They sync with the rest of the progress (FriendsProvider), so they
  survive a new phone once you log in with Google.
- **Publish `database.rules.json` again**: `progress` only accepts known
  fields, and `stats` and `badges` are new.

## VS intro

`widgets/duel/duel_intro.dart`, shown when the duel screen opens (also on
a rematch). The first round of every game starts `GameConfig.introLead`
(2.9 s) later, so the countdown only begins after the intro: in the mock
via `_startRound(intro: true)`, in Firebase by the host when `game`
changes.

## Toernooi (klas, knock-out)

Home → **TOERNOOI**. Iemand (meestal de leerkracht) maakt een toernooi en
krijgt een **5-tekencode**; tot 16 spelers doen mee met die code. De host
drukt op START: de loting maakt het schema en elke telefoon roept zijn
speler op ("JOUW DUEL!", na 5 s start het duel vanzelf).

```
tournaments/{code}:
  hostUid, status: lobby|running|finished|cancelled, createdAt, startedAt
  players/{uid}: {name, tag, joinedAt, online}   (online via onDisconnect)
  seeds: [uid | "_bye", …]                        de loting
  rooms/{matchId}: roomCode                       door de 1e speler van het duel
  results/{matchId}: {winner, at, walkover}       de eerste uitslag telt
```

- **Het schema wordt nooit opgeslagen**: elke telefoon rekent het uit uit
  `seeds` + `results` (`Bracket` in `lib/models/tournament.dart`). Zo kan
  het niet uit sync raken.
- **Oneven aantallen**: het schema wordt aangevuld tot 2, 4, 8 of 16 plaatsen
  met **vrijlotingen** (`_bye`). Die worden gespreid zodat nooit twee
  vrijlotingen tegen elkaar staan; wie er een heeft, gaat meteen door naar
  ronde 2. Voorbeeld: 6 spelers → 8 plaatsen, 2 vrijlotingen, 3 rondes.
- Een duel = een gewone kamer. De speler bovenaan in het duel maakt de kamer
  en schrijft de code in `rooms/`, de andere doet mee. Na het duel schrijft
  de telefoon de uitslag; het schema schuift vanzelf door.
- **Walk-over**: verlaat je tegenstander de kamer, dan win jij. Komt hij niet
  opdagen, dan mag je de winst opeisen na 20 s (offline) of 90 s (online
  maar weg). De **host** kan op elk duel tikken en zelf beslissen wie
  doorgaat (ook een uitslag aanpassen).
- Host verlaat de wachtkamer → toernooi gestopt voor iedereen. Na de start
  telt weggaan als offline (je tegenstander kan dan w.o. winnen).
- Kampioen: confetti voor iedereen, +250 XP en de badges *Toernooispeler*
  (1 toernooiduel) en *Toernooiwinnaar*.
- **Beamer** (tv-icoon): grote code + spelers in de wachtkamer, daarna het
  hele live schema schermvullend.
- Regels (`database.rules.json`): alleen spelers schrijven kamers en
  uitslagen, een uitslag maar één keer (de host mag overrulen), meedoen kan
  alleen in de wachtkamer, de winnaar moet een speler zijn. Max. 16 spelers
  wordt in de app gecontroleerd.

**Testen op één toestel**: `flutter run --dart-define=BACKEND=mock` →
Toernooi maken → **+3 test-bots** (zo vaak je wilt) → START. Bots spelen
onderling vanzelf; tegen jou speel je het gewone bot-duel.

## Killcam + gezichtseffecten

De laatste cast van een duel speelt niet op normale snelheid maar meteen
als **killcam**: de twee camera's worden groot, het beeld bevriest (een
foto van beide camera's op het moment van onthullen, `captureFrame`), de
spreuk speelt één keer aan 0,4× en eindigt op "K.O.!". Daarna opent het
resultaatscherm (`lib/widgets/duel/killcam.dart`).

Op die foto's zoekt **MediaPipe Face Landmarker** het gezicht
(`assets/models/face_landmarker.task`, Google's officiële float16-model,
sha256 `64184e22…bc9ff`; 478 punten). Daarmee:

- **IJs**: vorst groeit vanaf wangen en voorhoofd, blauwe lippen, ijspegels
  aan de wenkbrauwen, glazige ogen.
- **Vuur**: roet op wangen en voorhoofd, gloeiende rand, rook en vonken.
- **Bliksem**: witte flits, gloeiende ogen, vonken over het gezicht.
- **Schildslag**: sterretjes rond het hoofd, draaiende spiraalogen.
- De **winnaar**: ogen lichten op in de kleur van zijn spreuk.

**Elke ronde (hit-freeze):** de video loopt live door, dus een effect kan
niet op een bewegend gezicht plakken. Bij de onthulling neemt de app een
foto van de camera van wie verliest (en neemt nieuwe foto's tot het gezicht
in beeld is, bv. als een hand het bedekt). Bij de inslag bevriest die camera
even op die foto, het effect landt precies op het gezicht, daarna loopt de
video weer live. Gemeten op een Android-toestel: gezicht gevonden in
0,2–0,3 s, ruim vóór de inslag.

Het gezicht van wie geraakt wordt, komt na de inslag door het effect heen
(rondom bevroren/brandend, het gezicht zelf ook). Sommige telefoons geven
de camerafoto gedraaid: de stand wordt uit het gezicht zelf afgeleid (kin →
voorhoofd) en de foto rechtop getoond. Geen gezicht gevonden → het effect
speelt zoals vroeger over de hele camera.

Uitproberen zonder camera: Instellingen → Spreuk-effecten bekijken → de
paarse 🎬-knoppen (getekende gezichten). `FaceConstants.debug = true` tekent
alle gezichtspunten in de killcam, om de uitlijning op een toestel te
controleren. Getest op macOS met de echte MediaPipe: model laden ±0,3 s,
één gezicht zoeken 15–40 ms.
