# Asset specifications
- PNG with alpha. Gameplay art strictly side-on (no isometric/3-4 view).
- **Ethan**: drop frames at `assets/characters/ethan/<anim>_<NN>.png`. Animations: idle, push, cruise, speed, brake, drift, crouch, jump, airborne, landing, grind, fall. Same canvas size for every frame; the bottom-centre pixel is the board's ground contact (the sprite origin). Any size works (offset is computed from the first idle frame).
- **Street modules**: `StreetModule.texture_left/middle/right` (tileable middle with seamless horizontal join) or `texture_single`. The module origin is the top-left of the top surface; art is drawn from there. Collision never comes from art.
- **Backgrounds**: `PlaceholderBackdrop.texture` per layer (layer1/2/5 folders), horizontally tileable at tile width 3840 px for seamless mirroring.
- Audio: `assets/audio/` (OGG for music/SFX).

## Source material (Google Drive folder, supplied by the creative director)
Ethan 1.jpeg, Ethan 2.jpeg, Street Worker.jpeg (character concepts, JPEG = no alpha);
Elements – Transparent Layer 2/3 elements.png, Elements – Transparent reusable Street elements.png,
Elements – Loopable Level 3 elements.png; Backgrounds – Generic 1.png, Backgrounds – Hollywood Boulevard.png;
plus songs. These were NOT importable in the build sandbox (Drive blocked), so none are used yet.
Workflow: download them, run `python3 tools/slice_sheet.py "<sheet>.png" out_dir`
(validates real alpha first; refuses opaque sheets), review `slices.json`, check each piece is
side-on, then copy into the folders above. JPEG sheets need a chroma-key or re-export.
