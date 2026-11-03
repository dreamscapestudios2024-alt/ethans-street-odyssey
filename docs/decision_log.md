# Decision log
- Repo `ethans-street-odyssey` was empty; project created from scratch (Godot 4.3, GL Compatibility for Web/mac).
- Input actions registered in code, not project.godot, for testability.
- Level is assembled in code from a layout list; reusable pieces are scripts + two small scenes.
- Physics 120 Hz with interpolation enabled for smooth camera/sprite at any refresh rate.
- Web export single-threaded for GitHub Pages (no COOP/COEP headers available).
- Layout structure follows the brief; extra `tools/` and `scripts/ui/` added.
- Unresolved: final Ethan sprite dimensions, audio direction, jump/speed tuning by feel.
