# ProgressionSystem API

Autoload singleton that tracks pawn significance through **impact points** earned from deterministic actions (building, teaching, etc.).

## Current Phase
Phase 4 - Identity & Meaning

## Signals

| Signal | Parameters | Description |
|--------|-------------|-------------|
| `progression_changed` | `pawn_id: int` | Emitted when a pawn gains impact points. Connect UI panels to update instantly. |

## Tiers

| Tier | Name | Impact Required |
|------|------|-----------------|
| 0 | Unknown | 0 impact |
| 1 | Known | 10 impact |
| 2 | Remembered | 50 impact |
| 3 | Noticed | 200 impact |
| 4 | Influential | 1000 impact |
| 5 | Legendary | 5000 impact |

## Functions

### `record_impact(pawn_id, amount, reason) -> void`

Adds impact points to a pawn. Records the reason in WorldMemory event log.

**Parameters**:
- `pawn_id`: Target pawn ID
- `amount`: Points to award (positive integer)
- `reason`: Short description (e.g., "built_shelter", "taught_skill")

---

### `get_tier(pawn_id) -> int`

Returns the tier index (0-5) for the given pawn.

**Returns**: `int` - tier index (0=Unknown, 1=Known, 2=Remembered, 3=Noticed, 4=Influential, 5=Legendary)

---

### `get_tier_name(pawn_id) -> String`

Returns the human-readable tier name for the given pawn.

**Returns**: `String` - "Unknown", "Known", "Remembered", "Noticed", "Influential", or "Legendary"

---

### `get_impact(pawn_id) -> int`

Returns the current impact point total for the given pawn.

**Returns**: `int` - current impact points

---

### `get_tier_color(tier: int) -> Color`

Returns the display color for a tier index.

| Tier | Name | Color | Hex |
|------|------|-------|-----|
| 0 | Unknown | Gray | `#B4B4B4` |
| 1 | Known | Green | `#4CAF50` |
| 2 | Remembered | Blue | `#2196F3` |
| 3 | Noticed | Purple | `#9C27B0` |
| 4 | Influential | Gold | `#FFC107` |
| 5 | Legendary | Gold (bright) | `#FFD700` |

## UI Integration

### PawnInfoPanel.gd

The panel reads live tier data in `_refresh()`:

```gdscript
if ProgressionSystem:
    var tier: int = ProgressionSystem.get_tier(pawn_id)
    var tier_name: String = ProgressionSystem.get_tier_name(pawn_id)
    var impact: int = ProgressionSystem.get_impact(pawn_id)
    tier_label.text = "Status: [color=%s]%s[/color]" % [_color_to_hex(tier), tier_name]
    progress_bar.value = impact
    impact_detail_label.text = "%d Impact" % impact
else:
    tier_label.text = "Status: Unknown"
```

Connects to signal for live updates:
```gdscript
func _setup_signals() -> void:
    if ProgressionSystem:
        ProgressionSystem.progression_changed.connect(_on_progression_changed)

func _on_progression_changed(pawn_id: int) -> void:
    if _pawn != null and _pawn.data != null and int(_pawn.data.id) == pawn_id:
        _refresh()
```

## Impact Sources

| Action | Points | Notes |
|--------|--------|-------|
| Build shelter | +10 | First shelter gives bonus |
| Teach skill to pawn | +5 | Per lesson |
| Complete building | +3 | Per structure |
| Establish settlement | +20 | First settlement bonus |
| Discover technology | +15 | Per discovery |

## Design Notes

- **Deterministic**: Impact is awarded only for recorded actions in WorldMemory.
- **No RNG**: Points are fixed per action type.
- **Significance earned**: Tiers reflect meaningful contribution to the world, not time spent.
- **Graceful fallback**: If `ProgressionSystem` autoload is not present, UI shows "Status: Unknown".
