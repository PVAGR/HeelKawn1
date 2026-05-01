# PVABazaar Integration Adapter

## Status: STUB — Not yet implemented

This folder contains the interface specification for future integration between HeelKawn and pvabazaar.org.

## What PVABazaar Is

pvabazaar.org is the planned web platform for HeelKawn. It will allow players to:
- Share world chronicles (read-only)
- Browse settlement histories
- View exported world states
- (Future) Async multiplayer or shared world events

## Design Principles

1. **Local-first**: The game runs entirely offline. PVABazaar consumes exports, not live data.
2. **Append-only exports**: Same rule as WorldMemory — exports are immutable snapshots.
3. **No real-time sync**: Data flows one way: game → export → website.
4. **Player-controlled**: The player chooses what to export and when.

## Export Interface (Spec)

```
game exports → user://heelkawn_exports/export_<timestamp>/
├── world_seed.json        # World generation parameters
├── chronicle.json         # WorldMemory facts (append-only)
├── chronicle_summary.txt  # Human-readable summary
├── settlements.json       # Settlement states and histories
├── bloodlines.json        # Lineage data
└── artifacts.json         # Notable objects and their histories
```

## TODO

- [ ] Create export pipeline from WorldPersistence
- [ ] Define JSON schema for each export type
- [ ] Build static site renderer for chronicles
- [ ] Add "Export to PVABazaar" button in Creator menu
- [ ] Implement upload/publish flow

## Adapter Files

- `export_interface.md` — This file (specification)
- Future: `export_pipeline.gd` — Godot script to produce exports
- Future: `pvabazaar_upload.ps1` — Script to push exports to website
