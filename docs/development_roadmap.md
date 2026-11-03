# Roadmap
- **Stage 1 (this)**: playable skating prototype, placeholder art, tests, Pages deploy.
- Stage 1.5: slice real sprites/backgrounds, SFX + music hookup, hands-on tuning, more tricks/grinds.
- Stage 2: hybrid fixed/random level assembly, more Venice Beach, collectibles + backpack UI.
- Stage 3: interactive comic dialogue, NPC relationships, missions, save/load UI.
- Stage 4: first 3D area (mall) with a CharacterBody3D sharing GameState.

## Added during Stage 1
- Real sprites/backgrounds wired in (see `asset_specifications.md`).

## Platform notes
- Desktop (macOS) and browser (GitHub Pages) are supported now.
- **Phones**: feasible with the current Godot 4 project (GL Compatibility renderer, landscape 1920x1080). Needed: on-screen touch controls
  (push/brake/jump/crouch via a touch input layer feeding the same input actions), UI scaling check, performance pass on device, then iOS/Android export.
  Web build on phones can be tested first.
