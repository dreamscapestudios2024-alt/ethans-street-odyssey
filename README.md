# Ethan's Skate Odyssey

Cartoon 2D side-scrolling skateboarding adventure. **Stage 1** (this repo) is a playable
prototype: Ethan skates a hand-built Venice Beach street with ramps, stairs, rails, ledges
and hazards. Story, relationships and 3D areas come in later stages.

## Requirements
- **Godot 4.3 (stable)** or newer 4.x. Developed and tested headless on 4.3.

The game opens on a splash screen: press any key, click or tap to start.

## Open & run (macOS)
1. Install Godot 4.3 from <https://godotengine.org/download> (the standard, non-.NET build).
2. `git clone https://github.com/dreamscapestudios2024-alt/ethans-street-odyssey`
3. Godot Project Manager → **Import** → pick `project.godot` → **Edit**.
4. Press **F5** (Play). The main scene is the Venice Beach demo.

(First launch imports assets; if macOS blocks Godot, right-click the app → Open.)

## Play in the browser (GitHub Pages)
The repo includes a Web export preset and `.github/workflows/deploy-pages.yml`.
One-time setup: GitHub repo → **Settings → Pages → Source: GitHub Actions**. Every push to
`main` then runs the tests, exports the game and publishes it at
`https://dreamscapestudios2024-alt.github.io/ethans-street-odyssey/`.
The export is single-threaded (no SharedArrayBuffer), which is what GitHub Pages supports.

## Controls
| Action | Keys |
|---|---|
| Push / accelerate | `D` or `→` |
| Brake | `A` or `←` |
| Drift / powerslide | hold `Shift` while braking at speed |
| Crouch (bigger ollie on release) | `S` or `↓` |
| Ollie / jump (hold = higher) | `Space`, `W` or `↑` |
| Drop off a rail | `S` / `↓` |
| Restart | `R` |
| Music on/off | `M` |

## What's implemented
- Ethan (`CharacterBody2D`) with an explicit state machine: idle, push, cruise, speed, brake,
  drift, crouch, ollie, airborne, landing, grind, fall/recovery.
- Variable-height ollie, coyote time, jump buffering, limited air control, ramp launch.
- Grinding: reusable `GrindRail` (entry tolerance, approach rules, friction, slope, exit/jump-off, score multiplier).
- 12 reusable street modules (`StreetModule`) with 3-piece extendable art support, side-on collision.
- Five-layer world: parallax 0.2× / 0.4×, gameplay 1.0×, entities in world space, foreground 1.5×.
- Speed-based camera look-ahead; score HUD; fall/recovery; restart.
- Production art: Ethan's animation frames, street modules and Venice Beach parallax layers are cut from the supplied sheets (`tools/`). Missing art falls back to generated placeholders.
- Headless test suite (`tests/run_tests.gd`) incl. gameplay simulation; GitHub Actions CI and Pages deploy.

## Run tests
```bash
godot --headless --path . --script tests/run_tests.gd
```

## Known limitations
- Still placeholder: pothole, plain stairs (no rail), Layer-1 sky/ocean/hills, ground fill under the sidewalk. Ethan has no animations for kickflip/180/boardslide yet (frames exist in the source sheets).
- Only the title song is in the game ("Ethan at the Curb"); sound effects and level music are pending.
- No touch controls yet (needed for phones, see roadmap).
- Ethan only travels left→right; no reverse. Only a basic 50-50 grind.
- Not yet play-felt on a real display by the author of this commit: physics tuned via headless simulation only. Expect tuning passes.
- Web build untested locally (export templates not available in the build sandbox); CI performs it.

## Next stage
Production sprites and audio, additional grind types and tricks, tuning from hands-on play,
level streaming/hybrid random assembly, then NPC dialogue and the first story beats.
See `docs/development_roadmap.md`.
