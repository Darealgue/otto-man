# hizli_charge.gd  (Alev Dalgası)
# RARE - Ağır vuruş isabet edince vurduğun yönde yerde ilerleyen bir alev şeridi çıkar; şeritteki
# düşmanlar yanar. Eski "ağır saldırı hızı +%50" düz stat'ı bu fiille değiştirildi (id aynı kaldı).
# Gölgenin ağır vuruşu da şerit çıkarır (gölgenin konumundan, gölgenin baktığı yöne).

extends ItemEffect

const WAVE_LENGTH := 270.0
const WAVE_PATCHES := 6
const COOLDOWN_MSEC := 400

var _player: CharacterBody2D = null
var _ready_at: int = 0

func _init():
	item_id = "hizli_charge"
	item_name = tr("item.hizli_charge.name")
	description = tr("item.hizli_charge.description")
	flavor_text = "Kor yürür"
	category = ItemCategory.HEAVY_ATTACK
	tags = ["elemental_fire"]
	affected_stats = ["heavy_flame_wave"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_ready_at = 0

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null

func _on_player_attack_landed(attack_type: String, _damage: float, _targets: Array, _position: Vector2, _effect_filter: String = "all") -> void:
	if attack_type != "heavy" or not is_instance_valid(_player):
		return
	var now := Time.get_ticks_msec()
	if now < _ready_at:
		return
	var im := get_node_or_null("/root/ItemManager")
	if im == null:
		return
	_ready_at = now + COOLDOWN_MSEC
	var origin: Vector2 = _player.global_position
	var dir_x: float = float(_player.get("facing_direction")) if _player.get("facing_direction") != null else 1.0
	if im.is_shadow_hit():
		origin = im.shadow_hit_origin
		dir_x = im.shadow_hit_facing
	im.spawn_flame_wave(origin, dir_x, WAVE_LENGTH, WAVE_PATCHES)
