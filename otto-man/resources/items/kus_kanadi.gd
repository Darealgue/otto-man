# kus_kanadi.gd
# COMMON item - Triple jump. Bonus (3.) zıplama artık air control bedeli değil,
# 2 stamina hücresi harcıyor (bkz. player/states/air/jump_state.gd
# _consume_kus_kanadi_bonus_jump_stamina). İlk hava zıplaması (herkesin sahip
# olduğu bedava çift zıplamayla aynı) bedelsiz kalıyor — sadece gerçek bonus
# olan 2. hava zıplaması (3. zıplama) stamina harcıyor.

extends ItemEffect

func _init():
	item_id = "kus_kanadi"
	item_name = tr("item.kus_kanadi.name")
	description = tr("item.kus_kanadi.description")
	flavor_text = "Kuş gibi zıplama"
	rarity = ItemRarity.COMMON
	category = ItemCategory.JUMP
	affected_stats = ["jump_count"]

var _player: CharacterBody2D = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Set meta on player to enable triple jump
	player.set_meta("kus_kanadi_active", true)
	player.set_meta("kus_kanadi_jump_count", 0)
	print("[Kuş Kanadı] ✅ Triple jump aktif (bonus zıplama 2 stamina hücresi)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_meta("kus_kanadi_active"):
			_player.remove_meta("kus_kanadi_active")
		if _player.has_meta("kus_kanadi_jump_count"):
			_player.remove_meta("kus_kanadi_jump_count")
	_player = null
	print("[Kuş Kanadı] ❌ Kuş Kanadı kaldırıldı")
