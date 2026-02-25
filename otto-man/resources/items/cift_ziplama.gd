# cift_ziplama.gd
# COMMON - Double jump +1 (3 zıplama). 3. zıplama altında patlama + can gider.

extends ItemEffect

const ThirdJumpExplosionScript = preload("res://effects/third_jump_explosion.gd")
const THIRD_JUMP_HEALTH_COST_PERCENT := 0.08  # %8 max can

var _player: CharacterBody2D = null

func _init():
	item_id = "cift_ziplama"
	item_name = "Çift Zıplama"
	description = "3. zıplama hakkı; 3. zıplamada altında patlama olur, can gider"
	flavor_text = "Ekstra zıplama"
	rarity = ItemRarity.COMMON
	category = ItemCategory.JUMP
	affected_stats = ["jump_count"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Her yere basınca 3. zıplama hakkı açılır (fall_state'de kontrol)
	player.set_meta("cift_ziplama_active", true)
	player.set_meta("cift_ziplama_available", true)
	print("[Çift Zıplama] ✅ 3 zıplama (3. zıplamada patlama + can)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		_player.remove_meta("cift_ziplama_active")
		_player.remove_meta("cift_ziplama_available")
	_player = null
	print("[Çift Zıplama] ❌ Kaldırıldı")

func process(player: CharacterBody2D, _delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Yerdeyken 3. zıplama hakkını ver (sonra havada 1 kez kullanılır)
	if player.is_on_floor():
		player.set_meta("cift_ziplama_available", true)
