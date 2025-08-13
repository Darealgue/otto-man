extends Resource
class_name GoldDropConfig

# Basic gold drop composition and physics-tuning settings

# Total value range used when a breakable provides only a min/max count
@export var total_value_min: int = 10
@export var total_value_max: int = 30

# Hard limit on how many separate loot items we try to spawn for a single drop
@export var max_items: int = 6

# Candidate piece values (in gold units)
@export var coin_values: Array[int] = [1, 2, 5]
@export var pouch_values: Array[int] = [10, 15, 25]

# Lifetime and physics sleep
@export var despawn_seconds: float = 60.0
@export var ground_sleep_after_s: float = 0.7

# Global active cap hint (per-scene). Enforcement left to caller.
@export var active_cap_hint: int = 40

func pick_total_from_range(min_v: int, max_v: int) -> int:
	var lo: int = min(min_v, max_v)
	var hi: int = max(min_v, max_v)
	return randi() % (hi - lo + 1) + lo

func compose_items_for_total(total_value: int) -> Array[int]:
	# Greedy + random mix of pouches then coins; capped by max_items
	var remaining: int = max(0, total_value)
	var result: Array[int] = []

	# Prefer pouches for larger totals
	while remaining >= 10 and result.size() < max_items:
		var p: int = pouch_values[randi() % pouch_values.size()]
		if p <= remaining:
			result.append(p)
			remaining -= p
		else:
			break

	# Fill rest with coins
	while remaining > 0 and result.size() < max_items:
		var c: int = coin_values[randi() % coin_values.size()]
		if c > remaining:
			# Fit smallest coin if possible
			var smallest: int = int(coin_values.min())
			if smallest <= remaining:
				c = smallest
			else:
				break
		result.append(c)
		remaining -= c

	# If nothing fit due to tiny total, at least drop 1 coin
	if result.is_empty():
		result.append(1)
	return result
