# yildirim_zinciri.gd
# RARE - Şimşek elementiyle vurulmuş bir düşman ölürse, yıldırım 150px
# içindeki en yakın düşmana sıçrar ve onu da işaretler — zincir devam
# edebilir. "was_lightning_hit" meta işareti ItemManager.apply_element_to_enemy()'de
# konur (şimşeğin poison/frost gibi kalıcı bir stack'i yok).

extends ItemEffect

const CHAIN_RADIUS := 150.0
const CHAIN_DAMAGE := 10.0
const _LightningBoltLineScript = preload("res://effects/lightning_bolt_line.gd")
const _ElementHitFlashScript = preload("res://effects/element_hit_flash.gd")

func _init():
	item_id = "yildirim_zinciri"
	item_name = tr("item.yildirim_zinciri.name")
	description = tr("item.yildirim_zinciri.description")
	flavor_text = "Bir ölüm, bir kıvılcım daha doğurur"
	rarity = ItemRarity.RARE
	category = ItemCategory.SPECIAL
	affected_stats = ["lightning_kill_chain"]

func activate(player: CharacterBody2D):
	super.activate(player)
	print("[Yıldırım Zinciri] ✅ Şimşekle ölen düşman, yıldırımı bir sonrakine sıçratır")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	print("[Yıldırım Zinciri] ❌ Kaldırıldı")

func on_enemy_killed(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if not (enemy.has_meta("was_lightning_hit") and bool(enemy.get_meta("was_lightning_hit"))):
		return
	var tree = get_tree()
	if not tree:
		return
	var origin: Vector2 = enemy.global_position
	var nearest: Node2D = null
	var nearest_dist := CHAIN_RADIUS
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == enemy:
			continue
		if node.get("current_behavior") == "dead":
			continue
		if not node.has_method("take_damage"):
			continue
		var d: float = origin.distance_to(node.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = node
	if nearest:
		nearest.take_damage(CHAIN_DAMAGE, 0.0, 0.0, true)
		nearest.set_meta("was_lightning_hit", true)
		_spawn_chain_visual(origin, nearest.global_position)


## Basit placeholder görsel: zincirin sıçradığı iki düşman arasında çentikli
## bir bolt çizgisi + yeni hedefte kısa bir element halkası (bkz.
## effects/lightning_bolt_line.gd, effects/element_hit_flash.gd).
func _spawn_chain_visual(from_pos: Vector2, to_pos: Vector2) -> void:
	var tree = get_tree()
	if not tree or not tree.current_scene:
		return
	var bolt = Node2D.new()
	bolt.set_script(_LightningBoltLineScript)
	tree.current_scene.add_child(bolt)
	bolt.setup(from_pos, to_pos)
	var flash = Node2D.new()
	flash.set_script(_ElementHitFlashScript)
	tree.current_scene.add_child(flash)
	flash.setup(to_pos, "lightning")
