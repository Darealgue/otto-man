# karsi_mermi.gd
# LEGENDARY - Perfect parry, Mermi alt-dalını tetikler: saldırgana otomatik bir
# mermi fırlatır. SADECE Uzun Menzil ya da Ok Yağmuru aktifse anlamlı (Mermi
# hattı zaten onlarla açılıyor) — Savunma → Mermi köprüsü.

extends ItemEffect

const LightAttackProjectileScript = preload("res://effects/light_attack_projectile.gd")
const COUNTER_DAMAGE := 12.0

var _player: CharacterBody2D = null
var _last_parried_attacker: Node2D = null

func _init():
	item_id = "karsi_mermi"
	item_name = tr("item.karsi_mermi.name")
	description = tr("item.karsi_mermi.description")
	flavor_text = "Kalkanından mermi doğar"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.PARRY
	affected_stats = ["parry_projectile"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("perfect_parry"):
		if not player.is_connected("perfect_parry", _on_perfect_parry):
			player.connect("perfect_parry", _on_perfect_parry)
	print("[Karşı Mermi] ✅ Perfect parry mermi fırlatır (Uzun Menzil/Ok Yağmuru gerekir)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("perfect_parry"):
		if _player.is_connected("perfect_parry", _on_perfect_parry):
			_player.disconnect("perfect_parry", _on_perfect_parry)
	_player = null
	print("[Karşı Mermi] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if not is_instance_valid(_player):
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	if not (im.has_active_item("uzun_menzil") or im.has_active_item("ok_yagmuru")):
		return
	var block_state = _player.get_node_or_null("StateMachine/Block")
	var attacker: Node2D = null
	if block_state and block_state.get("_last_parried_attacker") != null:
		attacker = block_state.get("_last_parried_attacker")
	var direction := Vector2(-1.0 if _player.sprite and _player.sprite.flip_h else 1.0, 0.0)
	if attacker and is_instance_valid(attacker):
		direction = (attacker.global_position - _player.global_position).normalized()
		if direction == Vector2.ZERO:
			direction = Vector2(1.0, 0.0)
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var specialist_mult: float = im.get_specialist_multiplier("savunma")
	var proj = Node2D.new()
	proj.set_script(LightAttackProjectileScript)
	tree.current_scene.add_child(proj)
	proj.setup(_player.global_position + direction * 20.0, direction, COUNTER_DAMAGE * specialist_mult)
