# RARE - Ağır saldırı ayrıca ileri doğru bir Top mermisi fırlatır (Uzun Menzil'in ağır karşılığı).
# Top: yavaş, iri, isabette güçlü knockback + çevresine alan hasarı (cannon_projectile.gd).
# Ateş Bombası aktifse bunun yerine zıplayan bir ateş bombası atılır (player_fire_bomb_projectile.gd).
# Mermi yükseltmeleri (Sürü Oku, Ruh Mermisi, element...) iki türde de aynı şekilde çalışır.
extends ItemEffect

const DAMAGE_RATIO := 0.5
const PROJECTILE_RANGE := 300.0

var _player: CharacterBody2D = null

func _init():
	item_id = "ok_yagmuru"
	item_name = tr("item.ok_yagmuru.name")
	description = tr("item.ok_yagmuru.description")
	flavor_text = "Gökten ok yağar"
	rarity = ItemRarity.RARE
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_attack_ranged"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Ok Yağmuru] ✅ Ağır saldırı projectile fırlatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Ok Yağmuru] ❌ Kaldırıldı")

func _on_heavy_attack_impact(_attack_name: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var direction := Vector2(_player.facing_direction, 0.0)
	var damage: float = _player.hitbox.damage * DAMAGE_RATIO if _player.hitbox else 10.0
	var spawn_pos: Vector2 = _player.global_position + Vector2(direction.x * 20.0, -22.0)
	var kind := "bomb" if im.has_active_item("ates_bombasi") else "top"
	im.spawn_upgraded_projectile(tree.current_scene, spawn_pos, direction, damage, PROJECTILE_RANGE, kind)
