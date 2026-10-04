# perde_arkasi.gd
# UNCOMMON - Gölge Dönüşü ile ışınlandıktan sonra 1.5 sn düşmanların görüş menzili %80 kısalır
# (Sessiz Adım / Gölgeye Karışma ile aynı stealth hattı) ve sonraki vuruşun %50 fazla hasar verir.
# Ön koşul: Gölge Dönüşü.

extends ItemEffect

const DURATION := 1.5
const VISION_MULT := 0.2
const NEXT_HIT_MULT := 1.5

var _player: CharacterBody2D = null
var _time_left: float = 0.0
var _applied_vision: bool = false
var _applied_vision_value: float = 1.0
var _bonus_applied: bool = false

func _init():
	item_id = "perde_arkasi"
	item_name = tr("item.perde_arkasi.name")
	description = tr("item.perde_arkasi.description")
	flavor_text = "Perdenin arkasındakini kimse görmez"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["return_stealth"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_time_left = 0.0
	print("[Perde Arkası] ✅ Gölge dönüşü sonrası gizlilik + güçlü vuruş")

func deactivate(player: CharacterBody2D):
	_end_effect()
	super.deactivate(player)
	_player = null
	print("[Perde Arkası] ❌ Kaldırıldı")

# golge_donusu.gd -> ItemManager.notify_item_event
func _on_shadow_return(_from_pos: Vector2, _to_pos: Vector2) -> void:
	if not is_instance_valid(_player):
		return
	if _time_left <= 0.0:
		_begin_effect()
	_time_left = DURATION

func _begin_effect() -> void:
	# Paylaşılan alanlara atama değil çarpım; bitişte yalnızca kendi payımızı geri alırız.
	var cur = _player.get("stealth_enemy_vision_mult")
	if cur != null:
		_applied_vision_value = float(cur) * VISION_MULT
		_player.stealth_enemy_vision_mult = _applied_vision_value
		_applied_vision = true
	var hb = _player.get_node_or_null("Hitbox")
	if hb and hb.get("next_attack_bonus_multiplier") != null:
		hb.next_attack_bonus_multiplier *= NEXT_HIT_MULT
		_bonus_applied = true

func _end_effect() -> void:
	if not is_instance_valid(_player):
		_applied_vision = false
		_bonus_applied = false
		return
	if _applied_vision:
		# Başka bir item (Sessiz Adım) değeri değiştirdiyse ona dokunma
		var cur = _player.get("stealth_enemy_vision_mult")
		if cur != null and is_equal_approx(float(cur), _applied_vision_value):
			_player.stealth_enemy_vision_mult = clampf(_applied_vision_value / VISION_MULT, 0.0, 1.0)
		_applied_vision = false
	if _bonus_applied:
		var hb = _player.get_node_or_null("Hitbox")
		# Vuruş yapıldıysa çarpan zaten tüketilip 1.0'a dönmüştür; değilse payımızı geri al
		if hb and hb.get("next_attack_bonus_multiplier") != null and hb.next_attack_bonus_multiplier >= NEXT_HIT_MULT - 0.001:
			hb.next_attack_bonus_multiplier /= NEXT_HIT_MULT
		_bonus_applied = false
	_time_left = 0.0

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end_effect()
