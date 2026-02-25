# UNCOMMON - Her 3. light attack %50 ek hasar
extends ItemEffect

const BONUS_DAMAGE_RATIO := 0.5
var _player: CharacterBody2D = null
var _light_attack_count := 0

func _init():
	item_id = "ucuncu_vurus"
	item_name = "Üçüncü Vuruş"
	description = "Her 3. light attack %50 ek hasar verir"
	flavor_text = "Üçün bir gücü"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_third"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_light_attack_count = 0
	print("[Üçüncü Vuruş] ✅ Her 3. vuruş ek hasar")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Üçüncü Vuruş] ❌ Kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "elemental_only":
		return  # Karagöz gölgesi: sadece fiziksel; üçüncü vuruş bonusu uygulanmasın
	if not _player or attack_type != "normal":
		return
	_light_attack_count += 1
	if _light_attack_count % 3 != 0:
		return
	var extra = damage * BONUS_DAMAGE_RATIO
	for target in targets:
		if not is_instance_valid(target):
			continue
		var node = target
		if not node.has_method("take_damage"):
			node = node.get_parent() if node.get_parent() and node.get_parent().has_method("take_damage") else null
		if node and node.has_method("take_damage"):
			node.take_damage(extra, 0.0, 0.0, false)
