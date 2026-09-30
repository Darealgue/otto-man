# golge_nisanci.gd
# RARE - Fall attack yere değdiği noktadan aşağı yönlü bir mermi fırlatır;
# Ateş Topu Düşüşü/Buz Çağı/Zehirli Düşüş gibi kardeşlerinden farklı olarak
# alanda patlamaz, altındaki katmanlara doğru YOLUNA devam eder — çok katlı
# zindan bölümlerinde iniş noktasının altındakileri de vurur.
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY) —
# Mermi alt-dalının Tetik katmanı, ItemManager.spawn_upgraded_projectile()
# üzerinden Sürü Oku/Ağır Mermi/Peşine Düşen/Ruh Mermisi gibi diğer mermi
# yükseltmelerinden de aynı şekilde yararlanır.

extends ItemEffect

const DAMAGE_RATIO := 0.6

var _player: CharacterBody2D = null

func _init():
	item_id = "golge_nisanci"
	item_name = tr("item.golge_nisanci.name")
	description = tr("item.golge_nisanci.description")
	flavor_text = "Düşüş de bir nişan alma şeklidir"
	rarity = ItemRarity.RARE
	category = ItemCategory.FALL_ATTACK
	affected_stats = ["fall_attack_projectile"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	print("[Gölge Nişancı] ✅ Fall attack aşağı yönlü mermi fırlatır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	print("[Gölge Nişancı] ❌ Kaldırıldı")

func _on_fall_attack_impacted(position: Vector2) -> void:
	if not _player or not is_instance_valid(_player):
		return
	var stamina_bar = get_tree().get_first_node_in_group("stamina_bar") if get_tree() else null
	if not stamina_bar or not stamina_bar.use_charge():
		return
	var tree = _player.get_tree()
	if not tree or not tree.current_scene:
		return
	var im = get_node_or_null("/root/ItemManager")
	if not im:
		return
	var damage: float = _player.hitbox.damage * DAMAGE_RATIO if _player.hitbox else 10.0
	im.spawn_upgraded_projectile(tree.current_scene, position, Vector2.DOWN, damage)
