# kader_ani.gd
# LEGENDARY - Havadayken (is_on_floor()==false) yaptığın HER saldırı garanti
# kritik olur VE aktif elementini uygular. Eşik/sayaç yok — havadaki ilk
# vuruştan itibaren koşulsuz güçlü (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.4,
# kullanıcı geri bildirimiyle basitleştirildi: eski "5 vuruşluk zincir" şartı
# kaldırıldı).

extends ItemEffect

const CRIT_MULTIPLIER := 1.75  # Keskin Nazar ile aynı çarpan, tutarlılık için

var _player: CharacterBody2D = null
var _hitbox: Node = null

func _init():
	item_id = "kader_ani"
	item_name = tr("item.kader_ani.name")
	description = tr("item.kader_ani.description")
	flavor_text = "Yerçekimi seni bulamaz"
	rarity = ItemRarity.LEGENDARY
	category = ItemCategory.HEAVY_ATTACK
	affected_stats = ["air_crit", "air_element"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	var hitbox = player.get_node_or_null("Hitbox")
	if hitbox:
		_hitbox = hitbox
		_hitbox.force_air_crit_multiplier = CRIT_MULTIPLIER
	if player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_player_attack_landed):
			player.connect("player_attack_landed", _on_player_attack_landed)
	print("[Kader Anı] ✅ Havadaki her vuruş garanti kritik + aktif element")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _hitbox and is_instance_valid(_hitbox):
		_hitbox.force_air_crit_multiplier = 1.0
	_hitbox = null
	if _player and _player.has_signal("player_attack_landed"):
		if _player.is_connected("player_attack_landed", _on_player_attack_landed):
			_player.disconnect("player_attack_landed", _on_player_attack_landed)
	_player = null
	print("[Kader Anı] ❌ Kaldırıldı")

func _on_player_attack_landed(_attack_type: String, _damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only":
		return
	if not is_instance_valid(_player) or _player.is_on_floor():
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var elements: Array = im.get_active_elements()
	if elements.is_empty():
		return
	for t in targets:
		var enemy = _resolve_enemy_node(t)
		if enemy and is_instance_valid(enemy):
			for element in elements:
				im.apply_element_to_enemy(enemy, element)

func _resolve_enemy_node(target: Node) -> Node:
	if not is_instance_valid(target):
		return null
	if target.has_method("take_damage"):
		return target
	var p = target.get_parent()
	if p and p.has_method("take_damage"):
		return p
	if p and p.get_parent() and p.get_parent().has_method("take_damage"):
		return p.get_parent()
	return null
