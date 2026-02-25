# karagoz_laneti.gd
# RARE - Ortaoyunu decoy'u fiziksel saldırılarını taklit eder. Oyuncu vurdukça decoy da kendi yönüne saldırır.

extends ItemEffect

var _player: CharacterBody2D = null

func _init():
	item_id = "karagoz_laneti"
	item_name = "Karagöz'ün Laneti"
	description = "Ortaoyunu gölgesi fiziksel saldırılarını taklit eder. Sen vurdukça gölge de kendi yönüne saldırır."
	flavor_text = "Gölge yumruğu"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["decoy_physical"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_attack_performed"):
		if not player.is_connected("player_attack_performed", _on_attack_performed):
			player.connect("player_attack_performed", _on_attack_performed)
	print("[Karagöz Laneti] Decoy fiziksel saldırı taklit eder")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player:
		if _player.has_signal("player_attack_performed") and _player.is_connected("player_attack_performed", _on_attack_performed):
			_player.disconnect("player_attack_performed", _on_attack_performed)
	_player = null

# Hacivat'ın kopyaladığı elemental itemlerden biri varsa bu saldırı "elemental" sayılır; sadece Hacivat taklit etsin.
func _is_elemental_attack() -> bool:
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return false
	return im.has_active_item("zehirli_tirnak") or im.has_active_item("atesli_yumruk") or im.has_active_item("buzlu_kilic") or im.has_active_item("simsek_parmagi") or im.has_active_item("gok_gurultusu") or im.has_active_item("yildirim_dususu")

func _on_attack_performed(attack_name: String, damage: float):
	# Fall attack: gölge melee yapmasın, sadece fall-attack efektleri (zehir bulutu vb.) taklit edilir
	if attack_name == "fall_attack":
		return
	# Sadece fiziksel (melee) hasarı taklit et; elemental/patlama vb. Hacivat'a bırak.
	if _is_elemental_attack():
		return
	_decoy_attack_physical(damage, attack_name)

func _decoy_attack_physical(damage: float, attack_name: String) -> void:
	var tree = get_tree()
	if not tree:
		return
	var decoys = tree.get_nodes_in_group("player_decoy")
	for d in decoys:
		if is_instance_valid(d) and d.has_method("attack_physical"):
			d.attack_physical(damage, attack_name)
