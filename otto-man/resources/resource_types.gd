class_name ResourceType

const WOOD := "wood"
const STONE := "stone"
const WATER := "water"
const FOOD := "food"

static func all() -> Array:
	return [WOOD, STONE, WATER, FOOD]

static func is_valid(value: String) -> bool:
	return value in all()

