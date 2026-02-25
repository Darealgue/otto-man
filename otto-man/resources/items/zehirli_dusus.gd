# zehirli_dusus.gd
# UNCOMMON - Fall attack zehir bulutu bırakır (10 sn cooldown)

extends ItemEffect

const CLOUD_COOLDOWN_DURATION := 10.0
const CLOUD_RADIUS := 120.0
const CLOUD_DURATION := 4.0

var _player: CharacterBody2D = null
var _cloud_cooldown := 0.0

func _init():
	item_id = "zehirli_dusus"
	item_name = "Zehirli Düşüş"
	description = "Fall attack zehir bulutu bırakır (10 sn cooldown)"
	flavor_text = "Zehirli düşüş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_poison_cloud"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cloud_cooldown = 0.0
	if player.has_signal("fall_attack_impacted"):
		if not player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			player.connect("fall_attack_impacted", _on_fall_attack_impacted)
	print("[Zehirli Düşüş] ✅ Fall attack zehir bulutu (10 sn cooldown)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("fall_attack_impacted"):
		if _player.is_connected("fall_attack_impacted", _on_fall_attack_impacted):
			_player.disconnect("fall_attack_impacted", _on_fall_attack_impacted)
	_player = null
	print("[Zehirli Düşüş] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if _cloud_cooldown > 0:
		_cloud_cooldown -= delta

func _on_fall_attack_impacted(position: Vector2) -> void:
	apply_fall_attack_effect_at(position, false)

func apply_fall_attack_effect_at(position: Vector2, is_decoy: bool) -> void:
	if not is_decoy:
		if _cloud_cooldown > 0:
			return
		_cloud_cooldown = CLOUD_COOLDOWN_DURATION
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var cloud = Node2D.new()
	cloud.set_script(preload("res://effects/poison_cloud.gd"))
	tree.current_scene.add_child(cloud)
	cloud.global_position = position
