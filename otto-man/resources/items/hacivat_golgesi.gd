# hacivat_golgesi.gd
# RARE - Ortaoyunu decoy'u elemental saldırılarını taklit eder. Oyuncu elemental vurdukça decoy da kendi yönüne elemental saldırır.

extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "hacivat_golgesi"
	item_name = "Hacivat'ın Gölgesi"
	description = "Ortaoyunu gölgesi elemental saldırılarını taklit eder. Zehir, ateş, buz veya şimşek vurdukça gölge de aynı elementi uygular."
	flavor_text = "Elemental gölge"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["decoy_elemental"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_performed"):
		if not player.is_connected("player_attack_performed", _on_attack_performed):
			player.connect("player_attack_performed", _on_attack_performed)
	print("[Hacivat Gölgesi] Decoy elemental saldırı taklit eder")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("player_attack_performed") and _player.is_connected("player_attack_performed", _on_attack_performed):
			_player.disconnect("player_attack_performed", _on_attack_performed)
	_player = null

func _get_elemental_type() -> String:
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return ""
	if im.has_active_item("zehirli_tirnak") or im.has_active_item("zehirli_dev"):
		return "poison"
	if im.has_active_item("atesli_yumruk"):
		return "fire"
	if im.has_active_item("buzlu_kilic"):
		return "frost"
	if im.has_active_item("simsek_parmagi") or im.has_active_item("gok_gurultusu") or im.has_active_item("yildirim_dususu"):
		return "lightning"
	return ""

func _on_attack_performed(attack_name: String, damage: float):
	# Fall attack: gölge melee yapmasın, sadece fall-attack efektleri (zehir bulutu vb.) taklit edilir
	if attack_name == "fall_attack":
		return
	# Sadece elemental (zehir/ateş/buz/şimşek) varken taklit et; fiziksel vuruşlara karışma (Karagöz halleder).
	var elem = _get_elemental_type()
	if elem.is_empty():
		return
	_decoy_attack_elemental(damage, elem, attack_name)

func _decoy_attack_elemental(damage: float, element: String, attack_name: String) -> void:
	var tree = get_tree()
	if not tree:
		return
	var decoys = tree.get_nodes_in_group("player_decoy")
	for d in decoys:
		if is_instance_valid(d) and d.has_method("attack_elemental"):
			d.attack_elemental(damage, element, attack_name)
