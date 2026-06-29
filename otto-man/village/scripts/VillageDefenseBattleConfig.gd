class_name VillageDefenseBattleConfig
extends RefCounted
## Kışla asker sayısı → BattleScene birim dağılımı.

const MAX_UNITS_PER_SIDE: int = 36
const MIN_UNITS_IF_ANY: int = 4


static func build_rosters(
	player_soldiers: int,
	attacker_strength: int,
	alliance_defender: bool = false,
	alliance_defender_count: int = 0
) -> Dictionary:
	var player_total: int = clampi(player_soldiers, 0, MAX_UNITS_PER_SIDE)
	if alliance_defender and alliance_defender_count > 0:
		var bonus: int = maxi(2 * alliance_defender_count, int(round(float(player_total) * 0.2 * float(alliance_defender_count))))
		player_total = clampi(player_total + bonus, 0, MAX_UNITS_PER_SIDE)
	var enemy_total: int = clampi(attacker_strength, MIN_UNITS_IF_ANY, MAX_UNITS_PER_SIDE)
	if player_total > 0:
		player_total = maxi(MIN_UNITS_IF_ANY, player_total)
	return {
		"player": _distribute_units(player_total),
		"enemy": _distribute_units(enemy_total),
	}


static func _distribute_units(total: int) -> Dictionary:
	if total <= 0:
		return {
			"shieldbearer": 0,
			"spearman": 0,
			"swordsman": 0,
			"archer": 0,
			"cavalry": 0,
			"total": 0,
		}
	var shield: int = maxi(1, int(round(float(total) * 0.14)))
	var spear: int = maxi(1, int(round(float(total) * 0.22)))
	var sword: int = maxi(1, int(round(float(total) * 0.28)))
	var archer: int = maxi(1, int(round(float(total) * 0.20)))
	var cavalry: int = maxi(0, int(round(float(total) * 0.12)))
	var sum: int = shield + spear + sword + archer + cavalry
	while sum > total:
		if cavalry > 0:
			cavalry -= 1
		elif archer > 1:
			archer -= 1
		elif sword > 1:
			sword -= 1
		elif spear > 1:
			spear -= 1
		elif shield > 1:
			shield -= 1
		else:
			break
		sum = shield + spear + sword + archer + cavalry
	while sum < total:
		sword += 1
		sum += 1
	return {
		"shieldbearer": shield,
		"spearman": spear,
		"swordsman": sword,
		"archer": archer,
		"cavalry": cavalry,
		"total": sum,
	}


static func apply_to_battle_scene(battle: Node, rosters: Dictionary) -> void:
	if battle == null:
		return
	var player: Dictionary = rosters.get("player", {})
	var enemy: Dictionary = rosters.get("enemy", {})
	battle.set("ordered_spawn", true)
	battle.set("formation_depth", 4)
	battle.set("player_shieldbearer_count", int(player.get("shieldbearer", 0)))
	battle.set("player_spearman_count", int(player.get("spearman", 0)))
	battle.set("player_swordsman_count", int(player.get("swordsman", 0)))
	battle.set("player_archer_count", int(player.get("archer", 0)))
	battle.set("player_cavalry_count", int(player.get("cavalry", 0)))
	battle.set("enemy_shieldbearer_count", int(enemy.get("shieldbearer", 0)))
	battle.set("enemy_spearman_count", int(enemy.get("spearman", 0)))
	battle.set("enemy_swordsman_count", int(enemy.get("swordsman", 0)))
	battle.set("enemy_archer_count", int(enemy.get("archer", 0)))
	battle.set("enemy_cavalry_count", int(enemy.get("cavalry", 0)))
