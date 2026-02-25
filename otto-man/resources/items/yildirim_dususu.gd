# yildirim_dususu.gd
# UNCOMMON - Fall attack şimşek çakar (10 sn cooldown)

extends ItemEffect

const COOLDOWN_DURATION := 10.0
const LIGHTNING_RADIUS := 100.0
const LIGHTNING_DAMAGE := 6.0
const LightningFlashScript = preload("res://effects/lightning_flash.gd")

var _player: CharacterBody2D = null
var _cooldown := 0.0

func _init():
	item_id = "yildirim_dususu"
	item_name = "Yıldırım Düşüşü"
	description = "Fall attack şimşek çakar (10 sn cooldown)"
	flavor_text = "Şimşekli düşüş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_lightning"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown = 0.0
	if player.has_signal("fall_attack_impacted"):
		if not player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			player.connect("fall_attack_impacted", _on_fall_attack_impacted)
	print("[Yıldırım Düşüşü] ✅ Fall attack şimşek (10 sn cooldown)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("fall_attack_impacted"):
		if _player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			_player.disconnect("fall_attack_impacted", _on_fall_attack_impacted)
	_player = null
	print("[Yıldırım Düşüşü] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta

func _on_fall_attack_impacted(position: Vector2) -> void:
	apply_fall_attack_effect_at(position, false)

func apply_fall_attack_effect_at(position: Vector2, is_decoy: bool) -> void:
	if not is_decoy:
		if _cooldown > 0:
			return
		_cooldown = COOLDOWN_DURATION
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var flash = Node2D.new()
	flash.set_script(LightningFlashScript)
	tree.current_scene.add_child(flash)
	flash.global_position = position
	var enemies = tree.get_nodes_in_group("enemies")
	for node in enemies:
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if position.distance_to(node.global_position) <= LIGHTNING_RADIUS and node.has_method("take_damage"):
			node.take_damage(LIGHTNING_DAMAGE, 0.0, 0.0, true)
