class_name ResourceType

const WOOD := "wood"
const STONE := "stone"
const FOOD := "food"

static func all() -> Array:
	return [WOOD, STONE, FOOD]

static func is_valid(value: String) -> bool:
	return value in all()
