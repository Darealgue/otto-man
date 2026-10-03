# kalkan_kirigi.gd
# UNCOMMON - Blok yaptığında saldırganı anında sersemletip saldırısını keser
# (hasar vermez — saf bir kesinti). enemy/base_enemy.gd'nin change_behavior()
# fonksiyonu zaten enemy'nin mevcut eylemini "hurt" durumuna zorla geçirip
# kesiyor (oyundaki her gerçek isabetin kullandığı mekanizmanın aynısı,
# sadece burada hasar olmadan tetikleniyor).

extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "kalkan_kirigi"
	item_name = tr("item.kalkan_kirigi.name")
	description = tr("item.kalkan_kirigi.description")
	flavor_text = "Kalkan durdurur, saldırıyı keser"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_interrupt"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_blocked"):
		if not player.is_connected("player_blocked", _on_player_blocked):
			player.connect("player_blocked", _on_player_blocked)
	print("[Kalkan Kırığı] ✅ Blok, saldırganın saldırısını kesiyor")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _player.has_signal("player_blocked"):
		if _player.is_connected("player_blocked", _on_player_blocked):
			_player.disconnect("player_blocked", _on_player_blocked)
	_player = null
	print("[Kalkan Kırığı] ❌ Kaldırıldı")

func _on_player_blocked(blocked_damage: float, attacker: Node2D) -> void:
	if blocked_damage <= 0.0 or not is_instance_valid(attacker):
		return
	var target: Node = attacker
	if not target.has_method("change_behavior") and target.get_parent():
		target = target.get_parent()
	if target and is_instance_valid(target) and target.has_method("change_behavior"):
		target.change_behavior("hurt", true)
