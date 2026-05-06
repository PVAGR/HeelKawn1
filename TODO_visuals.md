# HeelKawn Visuals & Art - Make World Liveable
## Approved Plan: Custom pixel sprites (10px medieval pixel art), World.gd tints (foliage/weather), particles (fire/smoke), UI vignette/icons.

### 1. Create Assets (10px PNGs, earthy/medieval palette: browns/greens/golds/rusts)
- [ ] assets/sprites/items/paper.png (stack of sheets)
- [ ] assets/sprites/items/leather.png (tanned hide)
- [ ] assets/sprites/items/ink.png (inkwell)
- [ ] assets/sprites/items/pen.png (quill)
- [ ] assets/sprites/items/book.png (closed book)
- [ ] assets/sprites/items/written_book.png (open/decorated)
- [ ] assets/sprites/decor/banner_settlement.png (fabric flag)
- [ ] assets/sprites/decor/shrine_stone.png (small altar)
- [ ] assets/sprites/decor/foliage_grass.png (clump)
- [ ] assets/sprites/decor/fire_smoke.png (campfire particles)
- [ ] *.import files (copy from berry.png.import)

### 2. Enhance World Rendering (scenes/world/World.gd)
- [ ] Add _apply_foliage_tint (grass sway, 20% biomes)
- [ ] Add _apply_weather_tint (fog/rain overlay)
- [ ] Patch GPUParticles2D for fire/smoke at features.FIRE_PIT

### 3. Visual Ambiance (autoloads/MeaningAmbianceController.gd)
- [ ] Impl get_particle_density_multiplier_for_region → WorldEnvironment
- [ ] Add saturation/brightness methods

### 4. UI Polish (scenes/ui/ColonyHUD.tscn, Main.gd)
- [ ] Custom .tres icons for HUD
- [ ] Meaning vignette ColorRect (scarred=desat, grave=dark)

### 5. Integrate Placed Items (scripts/items/Book.gd, PlaceableItem.gd)
- [ ] Sprite2D + custom tints for placed books/decor

### 6. Test
- [ ] Run project: Check tints/particles/UI
- [ ] Polish colors (medieval: muted earth tones)

Updated on completion. Current phase: Assets.

