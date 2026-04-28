# HEELKAWN Copilot Instructions

Read first before suggesting or editing code:
- docs/HEELKAWN_STATE.md
- docs/LLM_ONBOARDING.md
- HEELKAWN_KERNEL.md if relevant

Project rules:
- Preserve deterministic behavior.
- Facts first, meaning second.
- Do not introduce random historical state.
- Do not casually refactor autoload/kernel systems.
- Prefer the smallest reversible change.
- Inspect existing files before creating new systems.
- Do not drift into generic survival crafting, hero fantasy, morality systems, or spectacle-first design.
- Do not add fake convenience UI that overrides world truth.
- Do not commit or push unless explicitly asked.

When responding:
- Name files inspected first.
- State root cause before editing.
- Summarize exact edits after changing code.
- Report risks and assumptions.
