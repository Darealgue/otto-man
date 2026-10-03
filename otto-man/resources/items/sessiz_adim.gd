# sessiz_adim.gd
# COMMON - Çömelme (crouch/crawl) sırasında düşmanların görüş menzili %30
# kısalır. player.gd'nin zaten var olan stealth_enemy_vision_mult alanını
# kullanır — stealth_perception.gd:_get_effective_vision_range() bunu her
# düşman için otomatik okuyor, ayrı bir enemy-tarafı değişikliğe gerek yok.

extends ItemEffect

const CROUCH_VISION_MULT := 0.7

var _player: CharacterBody2D = null
var _applied := false

func _init():
	item_id = "sessiz_adim"
	item_name = tr("item.sessiz_adim.name")
	description = tr("item.sessiz_adim.description")
	flavor_text = "Eğilen, görülmeyi geciktirir"
	rarity = ItemRarity.COMMON
	category = ItemCategory.CROUCH
	affected_stats = ["crouch_stealth"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Sessiz Adım] ✅ Çömelirken düşman görüş menzili kısalıyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and is_instance_valid(_player):
		_player.stealth_enemy_vision_mult = 1.0
	_player = null
	print("[Sessiz Adım] ❌ Kaldırıldı")

func process(player: CharacterBody2D, _delta: float) -> void:
	if not is_instance_valid(player):
		return
	var sm = player.get_node_or_null("StateMachine")
	var is_crouching: bool = sm and sm.current_state and sm.current_state.name == "Crouch"
	# Alan başka item'larla paylaşılıyor (ör. Gölge Pelerini): sadece KENDİ koyduğumuz değeri
	# geri alıyoruz, her karede 1.0'a ezmiyoruz.
	if is_crouching:
		player.stealth_enemy_vision_mult = CROUCH_VISION_MULT
		_applied = true
	elif _applied:
		player.stealth_enemy_vision_mult = 1.0
		_applied = false
