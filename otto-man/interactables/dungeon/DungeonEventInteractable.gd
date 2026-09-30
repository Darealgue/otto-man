class_name DungeonEventInteractable
extends Area2D
## Zindan yan yol mini-event: tüccar veya lanetli sunak.

const CollisionLayers = preload("res://resources/CollisionLayers.gd")

const GROUP_NAME: StringName = &"dungeon_event_interactable"
const EVENT_Z_INDEX: int = 3

var event_type: String = "merchant"
var level: int = 1
var _resolved: bool = false
var _player_in_range: bool = false
var _dialog_open: bool = false
var _placeholder: Polygon2D
var _sprite: Sprite2D
var _hint: Label

## Marketin kart vitrini (bkz. docs/ITEM_UNLOCK_SISTEMI.md bölüm 8).
## Sattığı kartlar RUN İÇİ: kalıcı unlock değil. Altınla kalıcı koleksiyon alınabilseydi
## oyuncu en kolay zindanı farmlayıp her şeyi satın alır, zindan coğrafyası çökerdi.
var _card_stock: Array[String] = []
var _ground_snapped: bool = false
const CARD_STOCK_SIZE: int = 3
## Zemin arama menzili: yukarı doğru biraz pay, aşağı doğru bir kaç karo.
const GROUND_SNAP_UP: float = 96.0
const GROUND_SNAP_DOWN: float = 320.0
## Işının bulduğu zeminin bu kadar üstüne oturur. Kapı çerçevesinin alt kenarı
## zemin karosunun üst pikselleriyle çakışmasın diye (göz kararı ayar).
const GROUND_SNAP_LIFT: float = 4.0
const _MARKET_UI := preload("res://ui/item_selection.tscn")

## Market fiyatları KASITLI OLARAK FAHİŞ. Run altını çıkışta köye taşınıyor
## (DungeonRunState.gold_multiplier_accumulated), yani buradan kart almak doğrudan
## köy geliştirmesinden feragat etmek demek. Ucuz olsaydı seçim olmazdı.
const CARD_PRICE_BY_RARITY: Array[int] = [45, 70, 110, 180]
const CARD_PRICE_PER_LEVEL: int = 6

## Market bir KAPI. Zindanın kendi kapı sanatını kullanır (door_1.png, 8 kareli sheet;
## kapalı kare 0 gösterilir). Sandık/varil değil: oyuncu kapıyı açıp içeri girdiğinde
## market açılıyormuş hissi veriyor.
const MERCHANT_TEXTURE_PATHS: Array[String] = [
	"res://assets/objects/dungeon/door_1.png",
]
const MERCHANT_DOOR_HFRAMES: int = 8
## CampDoor.tscn ile birebir: düğüm zeminde, sprite 97 piksel yukarıda.
const MERCHANT_DOOR_SPRITE_OFFSET := Vector2(0.0, -97.0)
const CURSE_TEXTURE_PATHS: Array[String] = [
	"res://assets/decorations/crystal_1.png",
	"res://assets/decorations/pillar_1.png",
	"res://assets/decorations/stone_block_1.png",
]


func setup(type: String, dungeon_level: int = 1) -> void:
	event_type = type if type == "curse" else "merchant"
	level = maxi(1, dungeon_level)


func _ready() -> void:
	add_to_group(GROUP_NAME)
	collision_layer = CollisionLayers.ITEM
	collision_mask = CollisionLayers.PLAYER
	monitoring = true
	monitorable = true
	z_index = EVENT_Z_INDEX

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if event_type == "curse":
		rect.size = Vector2(80.0, 64.0)
	else:
		# Kapı gövdesiyle örtüşsün: zeminden yukarı doğru, sunağınkinden yüksek
		rect.size = Vector2(90.0, 120.0)
		shape.position = Vector2(0.0, -56.0)
	shape.shape = rect
	add_child(shape)

	_placeholder = Polygon2D.new()
	_placeholder.name = "Placeholder"
	if event_type == "curse":
		_placeholder.color = Color(0.45, 0.18, 0.55, 1.0)
		_placeholder.polygon = PackedVector2Array([
			Vector2(-20.0, 18.0), Vector2(20.0, 18.0), Vector2(28.0, 0.0),
			Vector2(16.0, -34.0), Vector2(-16.0, -34.0), Vector2(-28.0, 0.0),
		])
	else:
		_placeholder.color = Color(0.55, 0.42, 0.22, 1.0)
		_placeholder.polygon = PackedVector2Array([
			Vector2(-30.0, 10.0), Vector2(30.0, 10.0), Vector2(34.0, -8.0),
			Vector2(22.0, -26.0), Vector2(-22.0, -26.0), Vector2(-34.0, -8.0),
		])
	add_child(_placeholder)

	var is_curse: bool = event_type == "curse"
	if is_curse:
		_sprite = InteractableVisualHelper.attach_centered_sprite(
			self, CURSE_TEXTURE_PATHS, Vector2(0.0, -8.0), Vector2(64.0, 56.0), [_placeholder]
		)
	else:
		# Kapı GERÇEK kapılarla aynı ölçüde ve aynı şekilde oturur: ölçek 1, sprite
		# düğümün 97 piksel üstünde (CampDoor.tscn ile birebir). Küçültülüp merkeze
		# konduğunda hem cılız duruyordu hem yarısı zemine gömülüyordu.
		_sprite = InteractableVisualHelper.attach_centered_sprite(
			self,
			MERCHANT_TEXTURE_PATHS,
			MERCHANT_DOOR_SPRITE_OFFSET,
			Vector2.ZERO,  # ölçek sınırı yok, texture kendi boyutunda
			[_placeholder],
			MERCHANT_DOOR_HFRAMES,
			0
		)

	_hint = Label.new()
	_hint.name = "Hint"
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# İpucu kapının tepesinin üstünde dursun (kapı 194 piksel yüksek), sunakta eski yerinde
	_hint.position = Vector2(-64.0, -62.0) if event_type == "curse" else Vector2(-64.0, -216.0)
	_hint.size = Vector2(128.0, 22.0)
	_hint.add_theme_font_size_override("normal_font_size", 11)
	_hint.add_theme_color_override("font_color", Color(0.92, 0.82, 1.0))
	_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.12))
	_hint.add_theme_constant_override("outline_size", 3)
	_hint.visible = false
	add_child(_hint)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(_delta: float) -> void:
	if not _ground_snapped:
		_snap_to_ground()
	if _resolved or _dialog_open or not _player_in_range:
		return
	if InputManager.is_ui_up_just_pressed():
		_open_event_dialog()


## Kapıyı zemine oturtur. İlk karede bir kez çalışır — _ready() değil, çünkü hem
## level_generator hem dev konsolu global_position'ı add_child()'DAN SONRA atıyor.
##
## Neden gerekli: yerleştiren tarafın "zemin" referansı güvenilir değil.
## level_generator dekorasyon konvansiyonunu kullanıyor (zemin karosunun üstü eksi 20,
## artı 5) — küçük merkez pivotlu sandık için doğru ama alt kenarından hizalanan
## 192 piksellik kapı için 16 piksel boşluk bırakıyordu. Dev konsolu ise
## player.get_foot_position() kullanıyordu; o fonksiyon sprite'ın kendi -48 piksellik
## yerel ofsetini hesaba katmadığı için ayak hizasının epeyce ALTINI döndürüyor ve
## kapı zemine gömülüyordu. Aşağı doğru ışın atıp gerçek zemini bulmak ikisini de çözer.
func _snap_to_ground() -> void:
	_ground_snapped = true
	if event_type == "curse":
		return  # Sunak küçük ve merkez pivotlu, mevcut yerleşimi doğru
	var space := get_world_2d().direct_space_state
	if space == null:
		return
	var from: Vector2 = global_position + Vector2(0.0, -GROUND_SNAP_UP)
	var to: Vector2 = global_position + Vector2(0.0, GROUND_SNAP_DOWN)
	var query := PhysicsRayQueryParameters2D.create(from, to, CollisionLayers.WORLD)
	query.hit_from_inside = true
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return
	global_position.y = float(hit.position.y) - GROUND_SNAP_LIFT


func _on_body_entered(body: Node2D) -> void:
	if _resolved or not body.is_in_group(&"player"):
		return
	_player_in_range = true
	_hint.visible = true
	_hint.text = "[↑] %s" % tr("dungeon.event.curse" if event_type == "curse" else "dungeon.event.market")


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player"):
		_player_in_range = false
		if not _resolved:
			_hint.visible = false


func _open_event_dialog() -> void:
	if _resolved or _dialog_open:
		return
	_dialog_open = true
	_hint.visible = false
	if event_type == "curse":
		_show_choice_dialog(
			"Lanetli Sunak",
			"Taşların arasında eski bir sunak. Dokunursan lanetlenebilirsin — ama hazinesi de cazip.",
			[
				{"id": "accept", "label": "Lanet kabul et (can kaybı, altın)"},
				{"id": "cleanse", "label": "Arındır (%d altın)" % _cleanse_cost()},
				{"id": "leave", "label": "Uzak dur"},
			]
		)
	else:
		_open_market()


## Market: kart vitrinini kart arayüzüyle (item_selection "dükkân" modu) açar.
## Stok event başına bir kez belirlenir; kapıyı kapatıp açmak vitrini yenilemez,
## yoksa oyuncu istediği kart çıkana kadar açıp kapatırdı.
func _open_market() -> void:
	var im: Node = get_node_or_null("/root/ItemManager")
	if not is_instance_valid(im) or not im.has_method("pick_merchant_stock"):
		_dialog_open = false
		return
	if _card_stock.is_empty():
		for id in im.call("pick_merchant_stock", CARD_STOCK_SIZE):
			_card_stock.append(String(id))
	if _card_stock.is_empty():
		_show_feedback(tr("dungeon.market.sold_out"))
		_dialog_open = false
		_resolved = true
		_finish_event()
		return

	var scenes: Array[PackedScene] = []
	var ids: Array[String] = []
	var prices: Array[int] = []
	for id in _card_stock:
		var meta: Dictionary = im.call("get_item_meta", id)
		if meta.is_empty() or not im.ITEM_SCENES.has(id):
			continue
		scenes.append(im.ITEM_SCENES[id])
		ids.append(id)
		prices.append(_card_cost(int(meta.get("rarity", 0))))
	if scenes.is_empty():
		_dialog_open = false
		return

	var shop = _MARKET_UI.instantiate()
	get_tree().root.add_child(shop)
	shop.shop_closed.connect(_on_market_closed)
	shop.setup_shop(scenes, ids, prices, Callable(self, "_try_purchase"))
	get_tree().paused = true


## Dükkân her satın almada bunu senkron çağırır. Ödeme geçerse true döner, kart tezgâhtan
## kalkar ve dükkân açık kalır — oyuncu parası yettiği sürece alışverişe devam eder.
func _try_purchase(item_id: String, price: int) -> bool:
	var im: Node = get_node_or_null("/root/ItemManager")
	if not is_instance_valid(im) or not im.ITEM_SCENES.has(item_id):
		return false
	if not _spend_run_gold(price):
		return false
	if im.has_method("activate_item"):
		im.call("activate_item", im.ITEM_SCENES[item_id])
	_card_stock.erase(item_id)
	return true


func _on_market_closed(_bought_item_id: String) -> void:
	_dialog_open = false
	if _card_stock.is_empty():
		# Tezgâh boşaldı: kapı kapanır
		_resolved = true
		_finish_event()
		return
	# Kalan mal var: kapı açık, oyuncu geri dönüp alabilir
	if _player_in_range:
		_hint.visible = true


func _show_choice_dialog(title: String, body: String, options: Array) -> void:
	var win := Window.new()
	win.title = title
	win.size = Vector2i(460, 240)
	win.unresizable = true
	win.transient = true
	win.exclusive = true
	win.process_mode = Node.PROCESS_MODE_ALWAYS
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	win.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	var label := Label.new()
	label.text = body
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(420, 64)
	vbox.add_child(label)
	for opt in options:
		if not (opt is Dictionary):
			continue
		var btn := Button.new()
		btn.text = String(opt.get("label", "Seç"))
		btn.custom_minimum_size = Vector2(420, 32)
		var choice_id: String = String(opt.get("id", "leave"))
		btn.pressed.connect(func() -> void:
			_on_dialog_choice(choice_id, win)
		)
		vbox.add_child(btn)
	get_tree().root.add_child(win)
	win.popup_centered()
	win.close_requested.connect(func() -> void:
		_on_dialog_choice("leave", win)
	)


func _on_dialog_choice(choice_id: String, win: Window) -> void:
	if is_instance_valid(win):
		win.queue_free()
	_dialog_open = false
	if _resolved:
		return
	# Market artık metin diyaloğu değil kart arayüzü kullanıyor; buraya sadece sunak düşer.
	if event_type == "curse":
		_resolve_curse(choice_id)
	if _resolved:
		_finish_event()


func _resolve_curse(choice_id: String) -> void:
	match choice_id:
		"accept":
			var ps: Node = get_node_or_null("/root/PlayerStats")
			if ps and ps.has_method("set_current_health"):
				var dmg: float = 6.0 + float(level) * 1.5
				var cur: float = float(ps.get("current_health")) if "current_health" in ps else 100.0
				ps.set_current_health(maxf(1.0, cur - dmg))
			var gold_gain: int = randi_range(18, 30) + level * 2
			_credit_run_gold(gold_gain)
			var drs: Node = get_node_or_null("/root/DungeonRunState")
			if is_instance_valid(drs) and "gold_multiplier_accumulated" in drs:
				drs.gold_multiplier_accumulated -= 0.12
			_show_feedback("Lanet kabul edildi. +%d altın, çıkış altın çarpanı düştü." % gold_gain)
			_resolved = true
		"cleanse":
			var cost: int = _cleanse_cost()
			if not _spend_run_gold(cost):
				_show_feedback("Arındırma için %d altın gerekli." % cost)
				return
			var drs: Node = get_node_or_null("/root/DungeonRunState")
			if is_instance_valid(drs) and "gold_multiplier_accumulated" in drs:
				drs.gold_multiplier_accumulated += 0.08
			var heal_ps: Node = get_node_or_null("/root/PlayerStats")
			if heal_ps and heal_ps.has_method("set_current_health"):
				var cur_h: float = float(heal_ps.get("current_health")) if "current_health" in heal_ps else 100.0
				var max_h: float = float(heal_ps.call("get_max_health")) if heal_ps.has_method("get_max_health") else 100.0
				heal_ps.set_current_health(minf(max_h, cur_h + 8.0), false)
			_show_feedback("Sunak arındırıldı. Küçük bir bereket hissediyorsun.")
			_resolved = true
		_:
			pass



func _card_cost(rarity: int) -> int:
	var idx: int = clampi(rarity, 0, CARD_PRICE_BY_RARITY.size() - 1)
	return CARD_PRICE_BY_RARITY[idx] + level * CARD_PRICE_PER_LEVEL


func _cleanse_cost() -> int:
	return 10 + level


func _finish_event() -> void:
	_hint.visible = false
	if _sprite:
		_sprite.modulate = Color(0.55, 0.55, 0.58, 0.65)
	elif _placeholder:
		_placeholder.modulate = Color(0.55, 0.55, 0.58, 0.65)
	monitoring = false


func _show_feedback(message: String) -> void:
	print("[DungeonEvent] %s" % message)
	var hud: Node = get_tree().get_first_node_in_group("dungeon_hud")
	if hud and hud.has_method("show_toast"):
		hud.call("show_toast", message)
		return
	_hint.text = message
	_hint.visible = true
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if is_instance_valid(_hint) and _resolved:
			_hint.visible = false
	)


func _get_run_gold() -> int:
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd == null:
		return 0
	if gpd.has_method("uses_dungeon_loot_wallet") and gpd.uses_dungeon_loot_wallet():
		return int(gpd.get("dungeon_gold"))
	return int(gpd.get("gold"))


func _spend_run_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd == null:
		return false
	if gpd.has_method("uses_dungeon_loot_wallet") and gpd.uses_dungeon_loot_wallet():
		if int(gpd.get("dungeon_gold")) < amount:
			return false
		gpd.dungeon_gold = int(gpd.dungeon_gold) - amount
		if gpd.has_signal("dungeon_gold_changed"):
			gpd.dungeon_gold_changed.emit(gpd.dungeon_gold)
		return true
	if int(gpd.get("gold")) < amount:
		return false
	gpd.gold = int(gpd.gold) - amount
	return true


func _credit_run_gold(amount: int) -> void:
	if amount <= 0:
		return
	var gpd: Node = get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_method("credit_run_loot_gold"):
		gpd.credit_run_loot_gold(amount, global_position)
	elif gpd and gpd.has_method("add_dungeon_gold"):
		gpd.add_dungeon_gold(amount)
