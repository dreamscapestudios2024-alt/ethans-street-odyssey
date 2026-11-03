# Architecture

## Layers (all visual parallax is cosmetic; gameplay never reads it)
1 distant (0.2×) · 2 local scenery (0.4×) · 3 gameplay ground (1.0×) · 4 characters/objects
(same world coordinates as 3, driven by velocity) · 5 foreground (1.5×, separate high CanvasLayer).
Built in `scripts/environment/parallax_world.gd`; scene assembly in `scripts/gameplay/venice_beach.gd`.

## World coordinates
Side-on, +y down. A flat sidewalk's top is y = 0. A `StreetModule`'s origin is the left end of
its entry ground line; `end_offset()` gives where the next module's origin belongs, so
`CourseBuilder` chains modules (stairs/descending ramps lower the cursor). Art (`_draw` /
optional textures) and collision (`CollisionShape2D`/`CollisionPolygon2D`) are built separately.
Physics layers: 1 world, 2 player, 3 hazard.

## Player
`scripts/player/ethan.gd`: `CharacterBody2D`; origin = board contact point. States are an enum
with per-phase physics (`_physics_ground/_air/_grind/_fall`). Pure math is in `movement_math.gd`.
Ethan emits signals (`jumped`, `landed`, `grind_started/ended`, `fell`, `recovered`) and does not
touch persistent data.

## Persistent state
`GameState` autoload (`scripts/systems/game_state.gd`) holds score, health, energy, wellbeing,
reputation, followers, backpack (6 slots), relationships, missions and JSON save/load. It has no
dependency on any body node, so a future `CharacterBody3D` controller (separate `scenes/3d/` scenes)
can share it. Levels connect Ethan's signals to GameState.

## Grinding
`GrindRail` nodes join group `grind_rails`; Ethan polls them while airborne using a swept
crossing test (so fast falls can't tunnel through the line). Ledges/handrails/stair-rails add one
automatically.

## Future hybrid level assembly
`CourseBuilder.build(parent, layout)` takes plain dictionaries; a generator can produce layouts
(fixed set pieces + random fillers) with no change to modules.

## Inputs
Actions are registered in code (`input_setup.gd`) so tests and builds share them.
