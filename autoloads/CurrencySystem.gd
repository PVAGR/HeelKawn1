extends Node

## Wrapper for WorldEconomyManager.

func get_phase() -> int:
	return WorldEconomyManager.get_currency_phase()

func record_trade(item_a: int, item_b: int, qty_a: int, qty_b: int) -> void:
	WorldEconomyManager.record_market_trade(item_a, item_b, qty_a, qty_b)

func establish_mint(settlement_id: int, mint_name: String) -> void:
	WorldEconomyManager.establish_mint(settlement_id, mint_name)

func get_approximate_value(item_type: int) -> int:
	return WorldEconomyManager.get_item_value(item_type)
