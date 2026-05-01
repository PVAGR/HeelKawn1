# PVABazaar Export Interface Specification

## Overview

Defines the data format for exporting HeelKawn world state to pvabazaar.org.

## Export Trigger

Exports are initiated by the player through the Creator debug menu (F10) or a future dedicated export button. Exports go to `user://heelkawn_exports/`.

## Schema: world_seed.json

```json
{
  "schema_version": "1.0",
  "world_seed": 12345,
  "generated_at": "2026-05-01T00:00:00Z",
  "engine_version": "4.6",
  "game_version": "0.1",
  "map_size": {"width": 512, "height": 512},
  "biome_seed": 67890
}
```

## Schema: chronicle.json

```json
{
  "schema_version": "1.0",
  "world_seed": 12345,
  "tick_count": 50000,
  "events": [
    {
      "tick": 100,
      "type": "settlement_founded",
      "data": { "settlement_id": "s1", "region": "valley_1" }
    }
  ]
}
```

## Schema: chronicle_summary.txt

Plain-text human-readable summary:
- World seed and age
- Number of settlements (living/dead)
- Notable events timeline
- Population statistics

## Schema: settlements.json

```json
{
  "schema_version": "1.0",
  "settlements": [
    {
      "id": "s1",
      "name": "Example",
      "status": "living",
      "founded_tick": 100,
      "population": 12,
      "identity_tags": ["tag1", "tag2"],
      "houses": ["h1", "h2"],
      "history_event_count": 45
    }
  ]
}
```

## Schema: bloodlines.json

```json
{
  "schema_version": "1.0",
  "lineages": [
    {
      "pawn_id": "p1",
      "name": "Example",
      "parent_a": null,
      "parent_b": null,
      "children": ["p2", "p3"],
      "profession": "farmer",
      "status": "living"
    }
  ]
}
```

## Schema: artifacts.json

```json
{
  "schema_version": "1.0",
  "artifacts": [
    {
      "id": "a1",
      "type": "built_structure",
      "name": "Great Hall",
      "built_by_settlement": "s1",
      "built_tick": 5000,
      "significance": "cultural"
    }
  ]
}
```
