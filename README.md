# 🐟 Reef Feast

A *Feeding Frenzy* style arcade game built with Flutter for Google Play.

You start as a tiny fish. Eat anything smaller than you, fill the level bar,
and grow bigger and bigger — from minnow to apex predator. Get too close to a
creature larger than you and it bites back.

## Gameplay

- **Drag** to steer — hold your finger off-centre to swim that way and
  explore. The reef is a large scrolling world, several screens across and
  deep, from the sunlit surface down to the sea floor.
- Creatures with a **green glow** are smaller — eat them (the fish says *Yum!*).
- Creatures with a **red glow** are bigger — dodge them, or lose a life.
- Swim through drifting **bubbles** to pop them (*Pop!*).
- Eating fills the **XP bar**; fill it to **level up** and grow.
- Chain quick kills for a **combo multiplier** (up to x5).
- You have **3 lives**. Reach **Level 8** to become the Apex Predator.

Seven sea creatures swim the reef, smallest to largest:

🦐 Shrimp → 🐠 Fish → 🦀 Crab → 🪼 Jellyfish → 🐢 Turtle → 🐙 Octopus → 🐋 Whale

Every creature, the player, the reef and all the effects are drawn with vector
shapes on a `CustomPainter` — no sprite atlases. The four sound effects in
`assets/sounds/` are short synthesized WAV files.

## Run it

```bash
flutter pub get
flutter run                 # on a connected device or emulator
```

## Build for the Play Store

The release artifact is an Android App Bundle:

```bash
flutter build appbundle     # -> build/app/outputs/bundle/release/app-release.aab
```

Release signing:

1. Create an upload keystore once:
   ```bash
   keytool -genkey -v -keystore ~/reef-feast-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Copy `android/key.properties.example` to `android/key.properties` and fill
   in the passwords and keystore path.

When `android/key.properties` is absent the release build falls back to debug
signing, so `flutter build appbundle` still works for testing.

- **Application ID:** `com.jonbonmateo.reef_feast`
- **Version:** set in `pubspec.yaml` as `version: <name>+<code>` — bump the
  build number on every Play Store upload.
- **Launcher icon:** `assets/icon/icon.png` is a placeholder. Drop in final
  art and regenerate with `dart run flutter_launcher_icons`.

## Project layout

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry; locks to portrait |
| `lib/game/game_config.dart` | All gameplay tuning constants |
| `lib/game/creature_kind.dart` | The seven creature species & their stats |
| `lib/game/entities.dart` | Player, creature, bubble, particle, floater |
| `lib/game/game_world.dart` | Pure simulation — movement, eating, levels |
| `lib/game/game_painter.dart` | Renders the whole underwater scene |
| `lib/game/game_screen.dart` | Render loop, input, menus & HUD |
| `lib/game/audio_manager.dart` | Sound-effect playback |
| `lib/game/high_score_store.dart` | Best score persistence |

## Verified

- `flutter analyze` — no issues
- `flutter test` — passing
- `flutter build appbundle` — produces a release `.aab`
