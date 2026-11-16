# Architecture & tech decisions

Pup Toss is a native iOS game with no backend: SpriteKit draws and collides the lawn, SwiftUI owns every screen around it, and the game rules are plain Swift that can be tested without a simulator.

## Layers

Each layer depends only on the one below it.

```
SwiftUI views   PupToss/UI      RootView (home ↔ game), HomeView, GameView, HUD, pause, game over
GameModel       PupToss/Model   the only shared state: score, chain, fouls, queue, goals (@Observable)
Scene layer     PupToss/Scene   GameScene, Slingshot, NogginNode, NogginArt, Effects, SoundEngine, Haptics
Game rules      PupToss/Core    MergeEngine, Scoring, RollingPhysics, CurveGesture, Goals, Lawn, Pressure
```

- **Game rules** are value types and pure functions with no UIKit or SpriteKit imports, so they're unit-tested directly.
- **The scene** reads touches, steps the physics, asks the rules what happens, and writes the results to `GameModel`.
- **SwiftUI** renders from `GameModel` and never touches SpriteKit nodes; buttons call into the scene (e.g. restart).

## Why SpriteKit + SwiftUI

| Option | Verdict | Why |
| --- | --- | --- |
| SpriteKit + SwiftUI | Chosen | Built into iOS, 2D physics included, `SpriteView` embeds the game in SwiftUI, small app, all Swift |
| Unity / Godot | Rejected | Larger runtime and weaker iOS integration (haptics, SwiftUI); only worth it for Android |
| RealityKit / SceneKit | Rejected | 3D art and physics cost for a top-down 2D game |

Because the rules live outside SpriteKit, only the collision layer would need replacing if SpriteKit's physics ever became a limit.

## Physics

SpriteKit handles collisions; a custom model handles everything else, so the **aim preview and the real throw run the same code**.

- **SpriteKit bodies:** circle-vs-circle and circle-vs-hedge collisions, bounciness, spin from glancing hits, precise collision detection for fast pieces. Built-in damping is off.
- **`RollingPhysics`:** grass friction (constant slowdown + speed-based drag), curve (spin pushes sideways at a constant force, so throws hook late like a bowling ball), spin decay, and per-surface friction (sand, puddle). `predictPath` reuses `step` to draw the aim line.
- **Fixed time step:** rolling physics runs in 1/120 s steps regardless of frame rate, so throws behave the same on every iPhone.
- **`CurveGesture`:** measures how far the slingshot drag bows away from a straight line, giving a bend in −1…1 that becomes spin.

## Merging

`MergeEngine.groups(in:)` clusters pieces of the same breed and tier whose edges are within the tier's merge gap using **union-find** (with path compression), so proximity is transitive: A near B near C is one group even if A and C are far apart. Wild Pups then pair with the nearest partnerless Pup they touch. `Scoring` turns groups and chain steps into points.

## Turn flow

1. Throw → pieces roll; merge checks run continuously, and slow pieces merge as soon as they form a group.
2. A merge pulls the pieces to their centroid, spawns the next tier (a Top Dog celebrates and pops), and fires a shockwave that can start a chain.
3. The turn ends only when nothing moves, no merge is animating, and a final check finds nothing to merge.
4. Fouls are checked once: any piece resting behind the foul line is removed; 3 fouls end the game.

## Concurrency model

Swift 6 language mode with **main-actor isolation by default** (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`). The game-rule types are marked `nonisolated` and `Sendable`, which keeps them free of UI isolation and usable from tests and any context.

## Art, audio, haptics

- **Art in code:** `NogginArt` draws every breed, size and expression with Core Graphics and caches the result as textures. The API is "breed + size + expression → image", so hand-drawn artwork can replace it later without touching the scene.
- **Audio in code:** `SoundEngine` synthesizes every effect at launch and plays them through a voice pool on `AVAudioEngine`; the app ships no audio files.
- **Haptics:** Core Haptics patterns (band tension rumble, release snap, impact thuds scaled to force), with a `UIImpactFeedbackGenerator` fallback.

## Persistence

All data stays on the device: best score and settings in `UserDefaults`, the in-progress round saved as JSON (`SaveStore`) so the home screen can offer Continue.

## Testing & tooling

- **Swift Testing** for the rules: merge grouping, scoring, rolling physics, chains, queue, gameplay specials (~58 tests).
- **XCUITest** smoke test: Home → Play → Pause → Resume → Home.
- **XcodeGen** generates the project from `project.yml`; the `.xcodeproj` isn't committed.
- **GitHub Actions** runs the unit tests on every push and pull request.
- **Debug tooling:** a live tuning panel for every physics value, and launch arguments that set up specific lawn states for testing.
