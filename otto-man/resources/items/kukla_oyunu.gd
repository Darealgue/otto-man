# kukla_oyunu.gd
# UNCOMMON - Hasar aldığında %40 ihtimalle (8 sn aralıkla) hasar iade edilir, oyuncu vuranın
# uzağına ışınlanır ve eski yerinde 2 sn bir gölge bırakır. Hasar önlenmez, anında telafi edilir
# (gerçek bir "hasar öncesi" hook'u yok; bkz. refleks.gd).

extends ItemEffect

const DecoyScene = preload("res://effects/player_decoy.tscn")
const CHANCE := 0.4
const COOLDOWN := 8.0
const IFRAME_DURATION := 0.6
const DECOY_LIFETIME := 2.0
const HOP_DISTANCES := [200.0, 140.0, 80.0]

var _player: CharacterBody2D = null
var _cooldown_left: float = 0.0

func _init():
	item_id = "kukla_oyunu"
	item_name = tr("item.kukla_oyunu.name")
	description = tr("item.kukla_oyunu.description")
	flavor_text = "Perdenin arkasındaki el seni çeker"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["hit_puppet"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_cooldown_left = 0.0
	print("[Kukla Oyunu] ✅ Hasarda %40 ihtimalle iade + ışınlanma")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Kukla Oyunu] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= delta

# ItemManager player_took_damage'a otomatik bağlar
func _on_player_took_damage(amount: float, attacker: Node2D) -> void:
	if _cooldown_left > 0.0 or amount <= 0.0 or not is_instance_valid(_player):
		return
	if randf() >= CHANCE:
		return
	var ps := get_node_or_null("/root/PlayerStats")
	if ps == null or ps.get_current_health() <= 0.0:
		return
	_cooldown_left = COOLDOWN
	var old_pos: Vector2 = _player.global_position
	if _player.has_method("heal"):
		_player.heal(amount)
	if _player.hurtbox and _player.hurtbox.has_method("set_invincible"):
		_player.hurtbox.set_invincible(IFRAME_DURATION)
	_spawn_decoy(old_pos)
	_hop_away(attacker)
	print("[Kukla Oyunu] ⚡ Hasar iade edildi, ışınlanıldı")

func _hop_away(attacker: Node2D) -> void:
	var dir: float = 1.0
	if is_instance_valid(attacker):
		dir = 1.0 if _player.global_position.x >= attacker.global_position.x else -1.0
	elif _player.get("sprite"):
		dir = 1.0 if _player.sprite.flip_h else -1.0
	for d in HOP_DISTANCES:
		var motion := Vector2(dir * d, 0.0)
		if not _player.test_move(_player.global_transform, motion):
			_player.global_position += motion
			_player.velocity = Vector2.ZERO
			return

func _spawn_decoy(pos: Vector2) -> void:
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var decoy = DecoyScene.instantiate()
	decoy.lifetime_override = DECOY_LIFETIME
	tree.current_scene.add_child(decoy)
	var flip: bool = _player.sprite.flip_h if _player.get("sprite") else false
	decoy.setup(pos, flip, _player)
