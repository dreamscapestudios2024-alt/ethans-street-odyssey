# Asset specifications
- PNG with alpha. Gameplay art strictly side-on (no isometric/3-4 view).
- **Ethan**: drop frames at `assets/characters/ethan/<anim>_<NN>.png`. Animations: idle, push, cruise, speed, brake, drift, crouch, jump, airborne, landing, grind, fall. Same canvas size for every frame; the bottom-centre pixel is the board's ground contact (the sprite origin). Any size works (offset is computed from the first idle frame).
- **Street modules**: `StreetModule.texture_left/middle/right` (tileable middle with seamless horizontal join) or `texture_single`. The module origin is the top-left of the top surface; art is drawn from there. Collision never comes from art.
- **Backgrounds**: `PlaceholderBackdrop.texture` per layer (layer1/2/5 folders), horizontally tileable at tile width 3840 px for seamless mirroring.
- Audio: `assets/audio/` (OGG for music/SFX).

## Source sheets and how they became game assets
All originals are in `assets/source_sheets/` (supplied by the creative director). Generated, committed outputs:
- **Ethan** (`assets/characters/ethan/<anim>_NN.png`): `python3 tools/extract_ethan_frames.py` cuts frames from `FRAMES- Ethans Core Movements 2/3`,
  removes labels/dividers, aligns the board contact point to the bottom-centre and applies per-animation scale factors (edit `SCALE` in the script).
  `Elements - Kick Push` provides the push (standard) and push_fast (aggressive, used above `fast_push_speed`) cycles; `Elements - Grinding`
  (rail row, rail cut away so feet sit on the rail line) provides the grind loop. The ledge and planter rows of that sheet are unused.
  `Elements - Wipeout Recovery` (12 frames) is the `fall` animation; the fall lasts as long as the animation (frames / fps).
  Unused so far: kickflip, 180, boardslide, nosegrind, celebrate, dance, profile and splash sheets.
- **Street modules** (`assets/street_modules/`): cut from `Elements - Transparent reusable Street elements`. Measurements (solid top, rail lines, stair
  geometry) live in `scripts/environment/street_art.gd`. `Elements - Loopable Level 3 elements` has richer tileable pieces (end caps, manholes, pothole,
  blue/red rails, half-pipes) not yet used.
- **Backgrounds** (`assets/backgrounds/layer1|2|5`): cut from `Elements - Transparent Layer 2 elements` and the street sheet (lamps). Layout in `scripts/environment/backdrop_art.gd`.
  `Backgrounds - *.png` (Venice, Hollywood, Crenshaw, Night, Generic) are opaque full-scene strips - not used yet; the Night variant suits a later time-of-day pass.
- Audio: songs (mp3) are kept off the repo for now; SFX pending.

## Lessons / gotchas
- Textures used inside `_draw()` must be strongly referenced (static cache); a local `load()` result is freed before the frame renders and draws as a white rectangle.
- JPEG concept sheets (Ethan 1/2, Street Worker) have no alpha and were not used.
