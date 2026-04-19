extends Resource
class_name GoldDropConfig

# Basic gold drop composition and physics-tuning settings

# Total value range used when a breakable provides only a min/max count
@export var total_value_min: int = 10
@export var total_value_max: int = 30

# Hard limit on how many separate loot items we try to spawn for a single drop
@export var max_items: int = 6

# Candidate piece values (in gold units)
@export var coin_values: Array[int] = [1, 2, 3]
@export var pouch_values: Array[int] = [5, 10, 15]  # Lowered threshold to allow pouches for smaller drops

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

	# Prefer pouches for larger totals (lowered threshold from 10 to 5)
	while remaining >= 5 and result.size() < max_items:
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


## Elit düşman drop'u: aynı toplam; 5–15 arası "poşet" parçalara yüksek ağırlık, kalan madeni, sıra karışık.
func compose_items_elite_pouch_weighted(total_value: int) -> Array[int]:
	var cap: int = maxi(0, total_value)
	if cap == 0:
		return [1]
	var remaining: int = cap
	var result: Array[int] = []
	const POUCH_BIAS := 0.82
	const POUCH_MAX := 15
	const POUCH_MIN := 5

	while remaining > 0 and result.size() < max_items:
		if remaining < POUCH_MIN:
			var coin_opts: Array[int] = []
			for x in coin_values:
				if x <= remaining:
					coin_opts.append(x)
			if coin_opts.is_empty():
				break
			var c: int = coin_opts[randi() % coin_opts.size()]
			result.append(c)
			remaining -= c
			continue

		if randf() <= POUCH_BIAS:
			var hi: int = mini(POUCH_MAX, remaining)
			var chunk: int = randi_range(POUCH_MIN, hi)
			result.append(chunk)
			remaining -= chunk
		else:
			var coin_opts2: Array[int] = []
			for x in coin_values:
				if x <= remaining:
					coin_opts2.append(x)
			var c2: int = coin_opts2[randi() % coin_opts2.size()]
			result.append(c2)
			remaining -= c2

	if remaining != 0:
		if result.is_empty():
			result.append(cap)
		else:
			result[result.size() - 1] = result[result.size() - 1] + remaining

	while result.size() > max_items:
		var last: int = result.pop_back()
		result[result.size() - 1] = result[result.size() - 1] + last

	if result.is_empty():
		result.append(maxi(1, cap))

	result.shuffle()
	return result
