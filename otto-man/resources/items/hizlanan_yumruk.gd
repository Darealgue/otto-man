# UNCOMMON - Light attack vurdukça 2 sn %20 hareket hızı
extends ItemEffect

const SPEED_BONUS_MULT := 1.2
const DURATION := 2.0
var _player: CharacterBody2D = null
var _boost_timer := 0.0

func _init():
	item_id = "hizlanan_yumruk"
	item_name = "Hızlanan Yumruk"
	description = "Light attack vurdukça 2 sn %20 hareket hızı"
	flavor_text = "Vur, kaç"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_speed"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_boost_timer = 0.0
	print("[Hızlanan Yumruk] ✅ Light attack hız bonusu")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _boost_timer > 0:
		_player.speed_multiplier = 1.0
	_player = null
	_boost_timer = 0.0
	print("[Hızlanan Yumruk] ❌ Kaldırıldı")

func process(player: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(player):
		return
	if _boost_timer > 0:
		_boost_timer -= delta
		player.speed_multiplier = SPEED_BONUS_MULT
		if _boost_timer <= 0:
			player.speed_multiplier = 1.0

func _on_player_attack_landed(attack_type: String, _damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "elemental_only":
		return  # Karagöz gölgesi: sadece fiziksel; hızlanan yumruk uygulanmasın
	if not _player or attack_type != "normal":
		return
	if not targets.is_empty():
		_boost_timer = DURATION
