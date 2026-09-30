# tavlanmis_celik.gd
# UNCOMMON - Blok yapınca kalkan kızarır; 3 sn içindeki blok saldırganı aktif
# elementinle etkiler. Eksi: kızgın kalkanla blok bir stamina hücresi daha harcar.
# Element Kalkanı köprüsü (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.3, §8.2 madde 3) —
# eskiden ateşe sabitti (Şimşek Kalkanı'nın ateş kardeşi), artık Temas Saldırısı'ndaki
# aktif elementi taşıyor, element yoksa sadece ısınma efekti kalır.

extends ItemEffect

const HOT_DURATION := 3.0

var _player: CharacterBody2D = null
var _hot_timer := 0.0

func _init():
	item_id = "tavlanmis_celik"
	item_name = tr("item.tavlanmis_celik.name")
	description = tr("item.tavlanmis_celik.description")
	flavor_text = "Tavında dövülen demir"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_element"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_hot_timer = 0.0
	print("[Tavlanmış Çelik] ✅ Blok kalkanı kızdırır; kızgın blok yakar (2x stamina)")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_player = null
	_hot_timer = 0.0
	print("[Tavlanmış Çelik] ❌ Kaldırıldı")

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _hot_timer > 0.0:
		_hot_timer -= delta

func _on_player_blocked(blocked_damage: float, attacker: Node2D) -> void:
	if blocked_damage <= 0.0:
		return
	if _hot_timer <= 0.0:
		# İlk blok: kalkan kızarır, henüz yakmaz
		_hot_timer = HOT_DURATION
		return

	# Kızgın kalkanla blok: saldırganı aktif elementinle etkiler, bedeli ekstra stamina
	_hot_timer = HOT_DURATION
	if is_instance_valid(attacker):
		var target: Node = attacker
		if not target.has_method("take_damage") and target.get_parent():
			target = target.get_parent()
		if target and is_instance_valid(target):
			var im = get_node_or_null("/root/ItemManager")
			if im:
				for element in im.get_active_elements():
					im.apply_element_to_enemy(target, element)
	var bar = get_tree().get_first_node_in_group("stamina_bar") if get_tree() else null
	if bar and bar.has_method("use_charge"):
		bar.use_charge()
