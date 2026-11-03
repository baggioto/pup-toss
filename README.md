# Pup Toss

An iOS game where you fling dog-head pieces called **Noggins** onto a lawn with a slingshot. When two or more of the same breed and size come to rest near each other, they merge into one bigger Noggin. Merge two Good Boys into a Top Dog and it celebrates, then pops off the lawn for a big bonus.

Everything runs on the device: no backend, no accounts, scores stay local.

- Architecture & tech decisions: [Pup Toss — Architecture & Tech Decisions](https://claude.ai/artifact/ApDWHUuXYbEKeNXQts5Eq4)
- Visual ideas (character sheet, screens, merge storyboard): [Pup Toss — Visual Ideas](https://claude.ai/artifact/NSnwvKrFsEjK8u2GgC5b6b)

## How it plays

The app opens on a home screen with your personal best in the corner. **Play** starts a round; the pause button in the game offers Resume, Restart and Home, and the game-over card offers Play again and Home. Quitting mid-round still saves the score if it beats your best.


- **Throw:** pull back on the slingshot. How far you pull sets power, the angle sets direction, and the shape of your drag sets curve: pull back in an arc and the throw bends the opposite way. A dotted line previews the path; the landing ring turns gold when the throw would complete a group.
- **Merge:** 2 or more Noggins of the same breed and size merge when their edges are within the merge gap, anywhere on the lawn, with no alignment needed.
- **Sizes:** only Pups are thrown. 2 Pups → Good Boy. 2 Good Boys → Top Dog, which plays a celebration and pops for the bonus. Top Dogs never stay on the lawn.
- **Chains:** merge checks run throughout every throw, so slow pieces merge as soon as they meet. A new piece calls nearby matching pieces over, and its shockwave can knock others into new groups.
- **Turn end:** a turn ends only when nothing moves, no merge is animating, and a final check finds nothing left to merge.
- **Fouls:** a Noggin resting behind the dashed foul line at the end of a turn is removed and counts as a foul. 3 fouls ends the game.

### Breeds per round

Every round starts with **Stray, Iggy, Shiba and Husky**. **Pug** joins at 500 points and **Dalmatian** at 1,500, each announced with a "New breed!" banner. The pool lives in `BreedPool.standard`.

### Saving and sound

- **Continue:** leaving the app (or going Home mid-round) pauses and saves the round; the home screen then offers Continue and New game. Game over clears the save.
- **Sound:** every effect is synthesised in code at launch (`SoundEngine`), so the app ships no audio files: bonks and thuds scaled to impact and Noggin size, the band's ticks and snap, merge pops that rise with the chain, a Top Dog fanfare, barks, a Bone chomp, puddle splashes, foul, goal and unlock chimes. It uses the ambient audio session (respects the silent switch, mixes with music). The pause menu has a Sound toggle.

### Chains

- **Merge on contact:** matching Noggins merge the moment they touch, at any speed.
- **Momentum:** the merged piece carries on with 80% of its parents' motion, so it can hit the next match.
- **Matchmaker shockwave:** a merge's shockwave half-steers each nearby piece toward its own nearest match and half pushes it outward. Shockwaves grow with the chain.
- **Chain timer:** merges within 2.5 s of each other keep the chain going, even across throws; a meter on the chain badge drains toward the deadline.
- **Chain pay:** ×1, ×2, ×4, ×7, ×11… From ×3 the screen shakes and a COMBO stamp appears.
- **Whistle:** reaching a ×4 chain earns one (up to 3). Tap the Whistle button, then tap the lawn, and every Noggin within reach runs to that spot.

### A lively lawn

- **Idle scoots:** while you aim, every 3.5 s or so a Noggin edges toward a match up to 60 pt beyond merge range, closing half the gap (you finish the merge), or shuffles a little on its own.
- **Smarter queue:** breeds are dealt from a shuffled bag so none goes missing, with a 35% lean toward breeds that have a lonely Pup on the lawn.

### Pressure

- **Strays wander in:** every 4 throws at first (one throw sooner per 1,500 points, never more often than every 2), a random Pup trots onto the lawn by itself.
- **Sleepy dogs:** a Noggin that hasn't merged in 21 turns falls asleep: closed eyes and floating Z's, three times heavier, and it can't merge. A solid hit wakes it, dizzy.
- **Gusts:** from the 6th throw, 30% of turns bring wind. An arrow and drifting leaves show it; it pushes every moving Noggin and bends the aim line for that turn.
- **Squirrel dash:** from the 9th throw, now and then a squirrel runs across the upper lawn and dogs near its path chase it a short way.
- **Mystery Pups:** from the 9th piece, 12% of Pups show as "?" in Next and in the slingshot. The breed is revealed when it lands, and the aim ring never lights for one.

### Gameplay extras

- **Aim line bounces:** the preview reflects once off the hedge or a rock, so bank shots can be lined up.
- **Almost a match:** while aiming, a pulsing dotted line joins matching pairs that are just outside merge range.
- **Special Noggins** (from the 6th piece on: Wild Pup 6%, Bone 4%, Bulldog 4%):
  - **Wild Pup:** rainbow fur; merges with any breed's Pup and becomes that breed's Good Boy. It takes the breed of the Pup it bumps into; resting, it pairs with the nearest Pup that has no partner (otherwise the nearest Pup). A "Wild Pup → Husky!" label shows what it became.
  - **Bone:** once it stops, nearby Noggins rush toward it for 1.6 s; it's eaten at the end of the turn.
  - **Bulldog:** four times the weight, ploughs through the lawn, never merges, and trots off at the end of the turn.
  - Specials never cause a foul.
- **Goals:** one at a time under the top bar (×3 chain +300, 3 merges in one throw +300, 4 Good Boys +300, pop a Top Dog +500), in a random order each round.
- **Lawn features**, rearranged each round above the foul line:
  - **Sand dig spot:** 2.4× friction, pieces in sand get +24 pt merge reach, and merges there pay ×2.
  - **Puddle:** 0.3× friction; a Noggin that crossed water shakes itself dry when it stops, nudging nearby pieces toward their matches.
  - **Rocks:** solid and bouncy.
  - **Bowl:** a gentle slope (shown as a faint worn patch) pulls rolling Noggins toward the middle of the upper lawn; the aim line bends with it.

### Feel

- **Faces:** Noggins blink, wince on solid hits, go dizzy after big ones, grin when a match is close by, and look nervous when the band is pulled tight.
- **Haptics (Core Haptics):** a rumble that builds as you pull the band, a sharp snap on release, and thuds scaled to impact strength (duller against the hedge). Devices without Core Haptics get simple taps.
- **Particles:** grass flecks behind fast rolls, skid marks on hard curves, dust on impacts, confetti on merges, and sparkles on a celebrating Top Dog's crown.
- **Home screen:** tap a Noggin and it hops, grins and barks.

### Breeds

Shiba, Pug, Dalmatian, Husky, Stray (a black street dog with flopped-over ear tips, a grey muzzle and a white bib; it's also the app icon) and Iggy (a black-and-white Boston Terrier with huge yellow-lined bat ears, heavy-lidded blue eyes and a toothy grin). Every breed has identical physics; breed only matters for matching.

### Scoring

| Event | Points |
| --- | --- |
| Merge into Good Boy (2 Pups) | 30 |
| Top Dog (2 Good Boys): celebrates, then pops | 500 |
| Each piece beyond 2 in a group | +50% of that group's points |
| Chain step *n* within one throw | × *n* |

## Tech

| Area | Choice |
| --- | --- |
| Engine | SpriteKit for the lawn, SwiftUI for the HUD and menus (`SpriteView`) |
| Language | Swift 6, main-actor isolation by default; game rules are `nonisolated` |
| Platform | iOS 18+, iPhone, portrait |
| Physics | SpriteKit bodies for collisions; custom `RollingPhysics` for grass friction, curve and spin decay, stepped at a fixed 120 Hz |
| Art | Dog heads drawn in code with Core Graphics, cached as textures |
| Saving | `UserDefaults` for the best score (SwiftData later for the Kennel) |
| Project | Generated by XcodeGen from `project.yml` |
| Tests | Swift Testing |

### Default tuning

Tuned for a swift game with the aiming autoplay (about 1.2 s from release to a settled lawn). Every value has a slider in the debug tuning panel.

| Parameter | Value |
| --- | --- |
| Grass friction | 560 pt/s² |
| Drag | 1.1 /s |
| Throw power | 1.25× |
| Curve strength | 11 pt/s² per rad/s |
| Max spin | 9 rad/s |
| Bounciness: Noggin / hedge / rocks | 0.62 / 0.55 / 0.8 |
| Merge gap between edges: Pup / Good Boy | 14 / 21 pt |
| Merge while slower than | 80 pt/s |
| Merge animation / settle wait | 0.14 s / 0.15 s |
| Chain window | 2.5 s |
| Radius: Pup / Good Boy / Top Dog | 22 / 31 / 41 pt |
| Strays | every 4 throws at first |
| Gust / squirrel chance per turn | 30% / 12% |

## Code layout

Each layer depends only on the one below it, so the game rules can be tested without a simulator.

```
SwiftUI views     PupToss/UI      RootView (home ↔ game), HomeView, GameView, HUD, pause, game over
GameModel         PupToss/Model   score, chain, fouls, queue, best score (@Observable)
Scene layer       PupToss/Scene   GameScene, Slingshot, NogginNode, NogginArt, Effects
Game rules        PupToss/Core    MergeEngine, Scoring, RollingPhysics, CurveGesture
```

- `PupToss/App`: app entry point and the debug-only icon exporter.
- `PupToss/Assets.xcassets`: the app icon.
- `PupTossTests`: tests for merge grouping, scoring, rolling physics and the curve gesture.
- `PupTossUITests`: taps through Home → Play → Pause → Resume → Home.

## Build and run

Requires Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
brew install xcodegen
xcodegen generate
open PupToss.xcodeproj
```

The `.xcodeproj` is generated and not committed: run `xcodegen generate` after cloning or after changing `project.yml`.

If the project sits in an iCloud-synced folder (such as `~/Documents`), code signing can fail with "resource fork, Finder information, or similar detritus not allowed". Keep DerivedData outside that folder (Xcode's default location is fine); from the command line pass `-derivedDataPath` somewhere else.

Run the tests:

```sh
xcodebuild -project PupToss.xcodeproj -scheme PupToss \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

### Tuning panel (debug builds only)

Pause ▸ **Tuning (debug)** opens live sliders for friction, drag, curve, max spin, throw power, the three bounces, both merge gaps, the merge speed, Bone pull, Bulldog weight, and sand and puddle friction. Changes apply immediately and are remembered between launches. **Copy values** puts the set on the clipboard as Swift, ready to paste into `Tuning`'s defaults in `PupToss/Core/Tuning.swift`; **Reset to defaults** restores the shipped values.

### Debug launch arguments (debug builds only)

| Argument | Effect |
| --- | --- |
| `-autoplay` | Throws automatically and logs every turn to the console |
| `-debugGoodBoys` | Starts with 3 Good Boys side by side |
| `-debugChain` | 2 Pups that merge into a Good Boy next to another Good Boy |
| `-debugChain -far` | Same, with the other Good Boy about 120 pt away |
| `-debugLawn` | A random lawn with resting near-miss pairs and a Wild Pup, for checking hints and features |
| `-uiTesting` | Clean start for UI tests: no saved round |
| `-debugWild` | A Wild Pup rolling into a lone Husky with a Shiba beside it |
| `-debugHUD` | Starts with a 6-digit score and a ×4 chain, for checking the top bar |
| `-exportIcon` | Renders the 1024 × 1024 app icon (light, dark and tinted) into the app's Documents folder |
| `-exportSheet` | Renders every breed at every size into `Sheet.png` in the Documents folder, for reviewing art |
| `-exportFaces` | Renders every breed in every expression into `Faces.png` |

`-autoplay` and the `-debug…` options skip the home screen and start in the game.

### Regenerating the app icon

The icon is drawn from the in-game art (a Stray Top Dog on the lawn), so regenerate it after changing `NogginArt`:

```sh
xcrun simctl launch booted com.baggioto.PupToss -exportIcon
DATA="$(xcrun simctl get_app_container booted com.baggioto.PupToss data)/Documents"
cp "$DATA"/AppIcon*.png PupToss/Assets.xcassets/AppIcon.appiconset/
```

It writes `AppIcon.png` (light), `AppIcon-Dark.png` and `AppIcon-Tinted.png` (greyscale) for the iOS 18+ home-screen appearances, all opaque, as the App Store requires.

## Roadmap

- [ ] **1. Prototype:** slingshot with curve, rolling physics, collisions with squish, dust and haptics, merges with shockwaves and chains, Top Dog pops, fouls, game over, local best score *(in progress)*
- [ ] **2. Tuning:** debug tuning panel; playtest physics values and merge gaps
- [ ] **3. Feel:** sound, Core Haptics, better art and animation frames
- [ ] **4. Meta:** ~~home screen with personal best, navigation, app icon~~ (done); results screen, Daily Lawn, Kennel collection
- [ ] **5. Polish and TestFlight:** onboarding, app icon, App Store assets, build automation
