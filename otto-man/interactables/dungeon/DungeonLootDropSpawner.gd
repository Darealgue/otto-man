extends RefCounted
class_name DungeonLootDropSpawner
## Sefer loot ve zindan anahtarı için fiziksel düşüş (altın burst ile aynı his).

const _DropScript := preload("res://interactables/dungeon/DungeonPhysicalLootDrop.gd")
const _ExpeditionLootType = preload("res://resources/expedition_loot_types.gd")


static func spawn_expedition_loot(world_pos: Vector2, loot_type: String, amount: int = 1) -> void:
	if not _ExpeditionLootType.is_valid(loot_type):
		return
	_DropScript.spawn_expedition_loot(world_pos, loot_type, amount)


static func spawn_dungeon_key(world_pos: Vector2, key_id: String) -> void:
	if key_id.is_empty():
		return
	_DropScript.spawn_dungeon_key(world_pos, key_id)


static func pick_random_enemy_loot_type() -> String:
	var r := randf()
	if r < 0.55:
		return _ExpeditionLootType.RUSTY_WEAPON
	if r < 0.80:
		return _ExpeditionLootType.SKY_FEATHER
	return _ExpeditionLootType.HERB_BUNDLE
