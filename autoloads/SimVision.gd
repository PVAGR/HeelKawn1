extends Node

## Long-horizon **design surface** — not authoritative simulation.
## Player travel, player-founded places, clans, religions, grand-strategy wars,
## and epoch-span (prehistory → modern) belong here as they graduate from design
## into code. Until then the deterministic kernel (WorldMemory, SettlementMemory,
## CulturalMemory, …) stays the source of truth; this node only names scope and
## offers debug text so creators do not confuse aspiration with shipped rules.

const NOTE_KERNEL: String = (
		"Kernel: append-only WorldMemory facts; emergence uses seeded streams (WorldRNG); "
		+ "derived layers read-only vs facts."
)


func roadmap_debug_block() -> String:
	return (
			"""SimVision (roadmap — long-horizon design surface; not a second sim loop)
%s

Shipped pillars (colony playtest): settlements + intent + trade + cultural reputation + scars/revival + pawn jobs/matrix/neural parity + observer tools + PlayerIntentQueue + FactionRegistry houses (real records). ReligionLens remains thin; grand campaigns / era stack / travel are future tiers.

Named future tiers (implementation TBD; each needs its own design pass vs kernel rules):
  • Player travel + shared world presence (netcode, persistence, anti-abuse)
  • Player-placed foundations vs autonomous SettlementPlanner (merge rules)
  • Clans / houses / dynasties (identity graph on top of SettlementRegistry)
  • Religion & ritual hooks (SacredMemory / MythMemory extension paths)
  • Grand campaigns (war goals, banners) — today: SettlementMemory war/edict stubs
  • Era stack (prehistory → modern) — calendar/SimTime extension + content gates

Nothing below this line executes as simulation yet.
"""
			% NOTE_KERNEL
	)


func feature_inventory_line() -> String:
	return "SimVision: roadmap autoload active; see F10 report \"27 · Vision scope\"."
