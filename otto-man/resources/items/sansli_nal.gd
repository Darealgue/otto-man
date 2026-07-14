# UNCOMMON - Perfect parry sonrası ilk vuruş ve Görünmezlik'in ilk vuruşu her zaman kritik
extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "sansli_nal"
	item_name = "Şanslı Nal"
	description = "Parry sonrası ilk vuruş ve görünmezlikten ilk vuruş her zaman kritik"
	flavor_text = "Şans, hazırlıklı olanı sever"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SPECIAL
	affected_stats = ["guaranteed_crit"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	player.sansli_nal_active = true
	print("[Şanslı Nal] ✅ Parry/görünmezlik vuruşları garanti kritik")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if is_instance_valid(player):
		player.sansli_nal_active = false
		player.sansli_nal_crit_next = false
	_player = null
	print("[Şanslı Nal] ❌ Kaldırıldı")

func _on_perfect_parry() -> void:
	if is_instance_valid(_player):
		_player.sansli_nal_crit_next = true
