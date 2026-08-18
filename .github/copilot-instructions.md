# HEELKAWN Copilot Instructions

Project rules:
- Preserve deterministic behavior.
- Facts first, meaning second.
- Do not introduce unseeded random historical state (use named `WorldRNG` streams where randomness is required).
- Prefer the smallest reversible change.
- Inspect existing files before creating new systems.
- Do not drift into generic survival crafting, hero fantasy, morality systems, or spectacle-first design.
- Do not add fake convenience UI that overrides world truth.
- Performance fixes are always welcome. The game must run at 200x without lag.
