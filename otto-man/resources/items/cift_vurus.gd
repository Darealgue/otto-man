# cift_vurus.gd
# UNCOMMON item - Her light attack 2 kez vurur ama %60 hasara düşer

extends ItemEffect

const DAMAGE_MULTIPLIER = 0.6  # %60 hasar

func _init():
	item_id = "cift_vurus"
	item_name = "Çift Vuruş"
	description = "Light attack'lar 2 kez vurur (%60 hasar)"
	flavor_text = "İkili vuruş"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_double"]

var _player: CharacterBody2D = null
var _original_light_multiplier: float = 1.0
var _last_attack_id: String = ""

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Store original multiplier and apply 60% reduction
	_original_light_multiplier = player.light_attack_damage_multiplier
	player.light_attack_damage_multiplier = _original_light_multiplier * DAMAGE_MULTIPLIER
	
	# Connect to player_attack_landed signal
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
		print("[Çift Vuruş] ✅ Light attack'lar 2 kez vurur (%60 hasar)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	# Restore original multiplier
	if _player:
		_player.light_attack_damage_multiplier = _original_light_multiplier
	# Disconnect signal
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Çift Vuruş] ❌ Çift Vuruş kaldırıldı")

func _on_player_attack_landed(attack_type: String, damage: float, targets: Array, position: Vector2, effect_filter: String = "all"):
	if effect_filter == "elemental_only":
		return  # Karagöz gölgesi: sadece fiziksel; Çift Vuruş uygulanmasın
	if not _player or attack_type != "normal":
		return  # Only for light attacks
	
	# Prevent double triggering
	var attack_id = str(Time.get_ticks_msec())
	if attack_id == _last_attack_id:
		return
	_last_attack_id = attack_id
	
	# Wait a tiny bit then apply second hit
	await get_tree().create_timer(0.05).timeout
	
	# Second hit uses the same damage as first hit (already reduced to 60%)
	# Since first hit is already at 60%, second hit should be the same
	var second_hit_damage = damage
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# Try to damage the enemy
		if target.has_method("take_damage"):
			target.take_damage(second_hit_damage)
		elif target.has_node("Hurtbox"):
			var hurtbox = target.get_node("Hurtbox")
			if hurtbox.has_method("take_damage"):
				hurtbox.take_damage(second_hit_damage)
	
	# Signal emit ETME - yoksa Çift Vuruş kendi callback'ini tekrar tetikler, sonsuz döngü olur
