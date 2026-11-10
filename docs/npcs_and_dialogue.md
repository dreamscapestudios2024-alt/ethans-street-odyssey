# NPCs, dialogue and credibility

## Skating both ways
Ethan can skate backwards. Left brakes him, stops him, then keeps pushing him left (top reverse speed `max_reverse_speed`).
Right does the same in the other direction. His sprite mirrors to face the way he travels. Grinds currently work left-to-right only.
An invisible wall stops him at both ends of the street.

## Gus and the hot dog vendor
- **Gus** (by his tent) greets Ethan with a speech bubble ("Hey man! Got any food?"). Slow down beside him and a conversation opens.
- Ethan chooses a reply (tap it, or press 1 / 2 / 3):
  1. **Scram ya bum!** -> **Gangsta Cred +5**.
  2. **Sure man! Here ya go bro!** -> costs **$5**, **Street Cred +5** (unavailable if Ethan has less than $5).
  3. **I got nothing but let me go to a shop and grab ya something homie!** -> starts a mission. Ethan must skate **backwards** to the **hot dog vendor**
     (behind Gus), buy a hot dog (**$4**), skate back and hand it to Gus -> **Moral Cred +10**.
- Ethan starts with **$20**. Money, the three credibility types and the current objective show under the score.
- NPCs face Ethan, have no collision and never block him.

## Where the data lives
- `GameState` (autoload): `money`, `street_cred`, `gangsta_cred`, `moral_cred`, `backpack` (items), `missions` (id -> state), `relationships`. All saved by `to_dict()`.
- `resources/dialogue/gus.json`, `resources/dialogue/vendor.json`: everything the characters say, no code needed.

## Dialogue file format
Each NPC file has `id`, `name`, `prompt`, `barks` (greetings shown in a bubble as Ethan rolls up) and a list of `conversations`.
The **first** conversation whose `when` matches is played:
```json
{
  "when": {"mission": "gus_food", "is": "active", "has_item": "hot_dog"},
  "lines": [
    {"speaker": "ethan", "text": "Here you go, Gus."},
    {"speaker": "gus", "text": "You're a good one."}
  ],
  "effects": {"take_item": "hot_dog", "mission": {"gus_food": "done"}, "cred": {"moral": 10}, "banner": "Moral Cred +10"}
}
```
- `when` (optional): `mission` + `is` (a state or list of states; no state yet = `"none"`), `has_item`, `not_has_item`, `met`.
- `lines`: `{"speaker": "ethan" | <npc>, "text": ...}`, or a **choice**: `{"choice": [{"id", "text", "requires": {"money": 5}, "need_text", "cost_text"}]}`.
- `branches`: for a choice, `{"<id>": {"effects": {...}, "lines": [...]}}` - the picked branch's lines play next.
- `effects`: `cred` (`street` / `gangsta` / `moral`), `money` (+/-), `mission` (`{id: state}`), `give_item`, `take_item`, `meet`, `banner`, `travel` (`{"x": ...}`, fade + move Ethan; unused now that he can reverse).

## Adding another NPC
1. Copy a dialogue file and change `id`, `name` and the conversations.
2. Cut the character out (`assets/characters/npcs/`; `FRAMES- Characters.png` has many more: a woman with a dog, police, security, tourists...).
3. In `scripts/gameplay/venice_beach.gd`, create an `Npc`, set `dialogue_path` / `texture_path` / `height_px`, and place it.

## Ideas this sets up
Other missions use the same pieces (items, money, mission states, credibility). The `DialogueBox` can also drive the later interactive comic-book scenes.
