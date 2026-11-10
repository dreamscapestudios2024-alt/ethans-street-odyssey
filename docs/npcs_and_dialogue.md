# NPCs and dialogue

## Gus (first NPC)
Gus is a friendly local who has watched this stretch of Venice for years. He stands by his tent near the start of the course.
- Ethan rolling up -> Gus calls out his greeting in a speech bubble ("Hey man! Got any food?").
- Ethan slowing to a stop beside him -> a conversation opens (Ethan's controls pause until it ends).
- First meeting earns reputation and records the relationship in `GameState` (`relationships["gus"]`). Later chats use shorter lines and give no repeat reward.
- NPCs have no collision; they never block Ethan.

## Editing what Gus says
Everything he says is in `resources/dialogue/gus.json` - no code needed.
- `barks`: short greetings shown in a bubble as Ethan rolls up.
- `lines`: the first conversation. Each entry is `{"speaker": "gus", "text": "..."}` or `{"speaker": "ethan", "text": "..."}`.
- `repeat_lines`: the shorter conversation on later visits.
- `reputation`: reputation earned the first time they talk.
- `prompt`: the small hint that appears when Ethan is close.

## Adding another NPC
1. Copy `resources/dialogue/gus.json` and change `id`, `name` and the lines.
2. Cut the character out (see `tools/` and `assets/characters/npcs/`). `FRAMES- Characters.png` has many more: a woman with a dog, police, security, a statue, an Elvis impersonator, tourists, a hot-dog vendor and more.
3. In `scripts/gameplay/venice_beach.gd`, create another `Npc`, set `dialogue_path` / `texture_path` / `height_px`, and place it.

## Ideas this sets up
- A "bring Gus some food" mission (a hot dog from the vendor), using the backpack and relationship systems in `GameState`.
- The same `DialogueBox` can drive the later interactive comic-book scenes.
