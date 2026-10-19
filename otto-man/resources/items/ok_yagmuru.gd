# RARE - Ağır saldırı ayrıca ileri doğru bir Top mermisi fırlatır (Uzun Menzil'in ağır karşılığı).
# Top: yavaş, iri, isabette güçlü knockback + çevresine alan hasarı (cannon_projectile.gd).
# Ateş Bombası aktifse bunun yerine zıplayan bir ateş bombası atılır (player_fire_bomb_projectile.gd).
# Mermi yükseltmeleri (Sürü Oku, Ruh Mermisi, element...) iki türde de aynı şekilde çalışır.
extends ItemEffect

const DAMAGE_RATIO := 0.5
const PROJECTILE_RANGE := 450.0  # Önceki 300'ün 1.5 katı
const UP_HEAVY_EXTRA_HEIGHT := 8.0  # Yukarı vuruşta yumruk daha yüksekte
const SPAWN_HEIGHT := 33.0  # Yerden yükseklik: çömelmiş heavy duruşunda gövde/el hizası (eskiden 22, duman zeminden çıkıyordu)

var _player: CharacterBody2D = null

func _init():
	item_id = "ok_yagmuru"
	item_name = tr("item.ok_yagmuru.name")
	description = tr("item.ok_yagmuru.description")
	flavor_text = "Gökten ok yağar"
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["heavy_attack_ranged"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func _on_heavy_attack_impact(attack_name: String) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var direction := Vector2(_player.facing_direction, 0.0)
	var height := SPAWN_HEIGHT
	if attack_name == "up_heavy":
		# Zıplatan yumruk: hafif up saldırısı gibi 45° yukarı (bkz. attack_state._get_light_attack_direction)
		direction = Vector2(_player.facing_direction, -1.0).normalized()
		height += UP_HEAVY_EXTRA_HEIGHT
	var damage: float = _player.hitbox.damage * DAMAGE_RATIO if _player.hitbox else 10.0
	var spawn_pos: Vector2 = _player.global_position + Vector2(_player.facing_direction * 20.0, -height)
	var kind := "bomb" if im.has_active_item("ates_bombasi") else "top"
	im.spawn_upgraded_projectile(tree.current_scene, spawn_pos, direction, damage, PROJECTILE_RANGE, kind, false, true)
