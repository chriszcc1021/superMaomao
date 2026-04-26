# Data Layer Audit

Phase 4 keeps gameplay data in the existing Godot data modules:

- `data/constants.gd`: numeric constants, display lookup tables, rarity prices, expedition probabilities.
- `data/cards/weapon_cards.gd` and `data/cards/buff_cards.gd`: battle card definitions.
- `data/enemies/*.json` with `data/enemies/enemy_data.gd`: enemy definitions and JSON aggregation.
- `data/question_events.gd`: question-event text, choices, and effect descriptors.

Design-document alignment checked against `docs/游戏设计文档-v3.6.md`:

- Expedition is 6 layers, with the boss on layer 6.
- Normal battles last 90 seconds; elite battles use the 120-180 second range.
- Battle fish XP starts at 5 and increases by 10 per level.
- Expedition rewards remain 50 coins per win on success and 20 coins per win on failure.
- Active gene choice now triggers at Lv5, Lv10, and Lv15.
- Building costs and camp food values remain sourced from `GameConstants`.

Validation entry point:

```powershell
.\.tools\godot-4.2.2\Godot_v4.2.2-stable_win64_console.exe --headless --script res://tools/DataValidator.gd
```

The validator checks duplicate IDs, required fields, enemy JSON parsing, supported question-event effect types, and the key constants above.
