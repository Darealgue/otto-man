# item_selection.gd
# UI for selecting items (adapted from powerup_selection)

extends CanvasLayer

signal item_selected(item_scene: PackedScene)

@onready var item_container = $Control/CenterContainer/VBoxContainer/ItemContainer
@onready var info_label = $Control/CenterContainer/VBoxContainer/InfoLabel
@onready var title_label = $Control/CenterContainer/VBoxContainer/Label

const GOLD_ICON := preload("res://assets/Icons/gold_icon.png")
## Dükkânda kesenin bakiyesi: başlığın altında, altın ikonu + büyük sayı.
var _gold_row: HBoxContainer = null
var _gold_amount_label: Label = null

var item_buttons: Array[Button] = []
var selected_index: int = 0
var is_processing_selection := false
var selection_hold_time := 0.0
var scenes_to_show: Array[PackedScene] = []
const SELECTION_HOLD_DURATION := 0.2

var navigation_repeat_timer_up := 0.0
var navigation_repeat_timer_down := 0.0
const NAVIGATION_INITIAL_DELAY := 0.25
const NAVIGATION_REPEAT_DELAY := 0.12

# Kart giriş animasyonu: 3 kart, kart başına 0.08 gecikme + 0.45 süre (bkz. CardVisualUtil).
# Kartlar tam görünür olmadan seçim kabul edilmesin.
const SELECT_LOCKOUT_DURATION := 0.65
var _select_lockout := 0.0
var _jump_released_once := false

# Unlock modu: run içi kart seçimi değil, kalıcı koleksiyona item ekleme.
# Seçilen item bu run'da aktifleşmez; sonraki run'larda kart olarak çıkmaya başlar.
var _unlock_mode := false
var _unlock_ids: Array[String] = []
var _unlock_theme := ""
var _unlock_tier := ""

# Dükkân modu: zindan marketinin kart vitrini. Seçim bedava değil, altınla ödenir.
var _shop_mode := false
var _shop_ids: Array[String] = []
var _shop_prices: Array[int] = []
var _shop_scenes: Array[PackedScene] = []
var _buy_handler: Callable = Callable()
var _refusal_timer := 0.0
var _sold_out := false
signal shop_closed(bought_item_id: String)

# Tema adları WorldManager'dan okunur (tek kaynak), burada ayrıca tutulmaz.

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	show_ui(false)

func _input(event: InputEvent) -> void:
	if !visible or is_processing_selection:
		return

	if InputManager.is_event_action(event, &"ui_left") or InputManager.is_event_action(event, &"ui_right"):
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if !visible or is_processing_selection:
		return

	if _shop_mode:
		if _refusal_timer > 0.0:
			_refusal_timer -= delta
			if _refusal_timer <= 0.0:
				_update_info()
		# Dükkândan eli boş çıkabilmek gerek: draft ekranından farkı bu
		if InputManager.is_ui_cancel_just_pressed():
			_leave_shop()
			return

	# Update navigation timers
	if navigation_repeat_timer_up > 0.0:
		navigation_repeat_timer_up -= delta
	if navigation_repeat_timer_down > 0.0:
		navigation_repeat_timer_down -= delta

	# Kartlar artık yatay sıralı; seçim sol/sağ ile yapılıyor (isimler eski up/down'dan kalma).
	if InputManager.is_ui_left_just_pressed():
		_move_selection(-1)
		navigation_repeat_timer_up = NAVIGATION_INITIAL_DELAY
	elif InputManager.is_ui_left_pressed():
		if navigation_repeat_timer_up <= 0.0:
			_move_selection(-1)
			navigation_repeat_timer_up = NAVIGATION_REPEAT_DELAY
	else:
		navigation_repeat_timer_up = 0.0

	if InputManager.is_ui_right_just_pressed():
		_move_selection(1)
		navigation_repeat_timer_down = NAVIGATION_INITIAL_DELAY
	elif InputManager.is_ui_right_pressed():
		if navigation_repeat_timer_down <= 0.0:
			_move_selection(1)
			navigation_repeat_timer_down = NAVIGATION_REPEAT_DELAY
	else:
		navigation_repeat_timer_down = 0.0
	
	# Selection: Use jump button. İki koruma var, ikisi de aynı sorunu kapatıyor:
	#  1) Kart giriş animasyonu bitene kadar seçim sayılmaz.
	#  2) UI açılırken zıplama zaten basılıysa, bir kez BIRAKILANA kadar sayılmaz. Eskiden
	#     oyundan devreden basılı zıplama tuşu kartlar görünmeden 0.2s'de rastgele seçim
	#     yapıyordu (is_jump_pressed basılı durumu okuyor, "yeni basıldı"yı değil).
	var jump_held := InputManager.is_jump_pressed()
	if not _jump_released_once:
		if jump_held:
			jump_held = false
		else:
			_jump_released_once = true
	if _select_lockout > 0.0:
		_select_lockout -= delta
		jump_held = false

	var selecting := jump_held
	if selecting:
		selection_hold_time += delta
		if selection_hold_time >= SELECTION_HOLD_DURATION:
			if selected_index >= 0 and selected_index < item_buttons.size():
				select_item(selected_index)
		# Update button progress
		if selected_index >= 0 and selected_index < item_buttons.size():
			item_buttons[selected_index].set_progress(selection_hold_time / SELECTION_HOLD_DURATION)
	else:
		selection_hold_time = 0.0
		# Reset button progress
		if selected_index >= 0 and selected_index < item_buttons.size():
			item_buttons[selected_index].set_progress(0.0)

## Dükkân modu girişi. Zindan marketi (DungeonEventInteractable) çağırır.
## Kartlar fiyat rozetiyle gösterilir; parası yetmeyen seçilemez, Escape ile çıkılır.
## `buy_handler` senkron çağrılır: (item_id, price) -> bool. true dönerse kart tezgâhtan
## kalkar ve dükkân AÇIK KALIR — oyuncu parası yettiği sürece alışverişe devam edebilir.
## (Tek alışverişte kapanması playtest'te "başka almama izin vermedi" diye geri geldi.)
func setup_shop(
	item_scenes: Array[PackedScene],
	item_ids: Array[String],
	prices: Array[int],
	buy_handler: Callable = Callable()
) -> void:
	_shop_mode = true
	_shop_ids = item_ids.duplicate()
	_shop_prices = prices.duplicate()
	_buy_handler = buy_handler
	_shop_scenes = item_scenes.duplicate()
	setup_items(item_scenes)
	_refresh_shop_visuals()


func _refresh_shop_visuals() -> void:
	for i in item_buttons.size():
		if i < _shop_prices.size() and item_buttons[i].has_method("set_price_tag"):
			item_buttons[i].set_price_tag(_shop_prices[i], _can_afford(_shop_prices[i]))
	_update_gold_row()
	_update_info()
	update_selection()


## Başlığın altına altın ikonu + bakiye. Cümle yerine sembol: bir bakışta okunuyor.
func _update_gold_row() -> void:
	if not _shop_mode or title_label == null:
		return
	if _gold_row == null:
		_gold_row = HBoxContainer.new()
		_gold_row.name = "GoldRow"
		_gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_gold_row.add_theme_constant_override("separation", 10)
		_gold_row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon := TextureRect.new()
		icon.texture = GOLD_ICON
		icon.custom_minimum_size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gold_row.add_child(icon)

		_gold_amount_label = Label.new()
		_gold_amount_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_gold_amount_label.add_theme_font_size_override("font_size", 44)
		_gold_amount_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35))
		_gold_amount_label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.02))
		_gold_amount_label.add_theme_constant_override("outline_size", 6)
		_gold_amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gold_row.add_child(_gold_amount_label)

		var parent := title_label.get_parent()
		parent.add_child(_gold_row)
		parent.move_child(_gold_row, title_label.get_index() + 1)
	if _gold_amount_label:
		_gold_amount_label.text = str(_current_gold())


func _current_gold() -> int:
	var gpd = get_node_or_null("/root/GlobalPlayerData")
	if gpd == null:
		return 0
	if gpd.has_method("uses_dungeon_loot_wallet") and gpd.uses_dungeon_loot_wallet():
		return int(gpd.get("dungeon_gold"))
	return int(gpd.get("gold"))


func _can_afford(price: int) -> bool:
	return _current_gold() >= price


## Unlock modu girişi. ItemManager._show_unlock_selection() çağırır.
func setup_unlock(item_scenes: Array[PackedScene], item_ids: Array[String], theme: String, tier: String) -> void:
	_unlock_mode = true
	_unlock_ids = item_ids.duplicate()
	_unlock_theme = theme
	_unlock_tier = tier
	setup_items(item_scenes)


func setup_items(item_scenes: Array[PackedScene]) -> void:
	for child in item_container.get_children():
		child.queue_free()
	
	# Set states before starting any animations
	is_processing_selection = false
	selected_index = 0
	selection_hold_time = 0.0
	navigation_repeat_timer_up = 0.0
	navigation_repeat_timer_down = 0.0
	
	item_buttons.clear()
	
	is_processing_selection = false
	selected_index = 0
	selection_hold_time = 0.0
	navigation_repeat_timer_up = 0.0
	navigation_repeat_timer_down = 0.0
	
	_select_lockout = SELECT_LOCKOUT_DURATION
	_jump_released_once = false

	scenes_to_show = item_scenes.duplicate()
	
	# Create buttons for each item
	for scene in scenes_to_show:
		var item = scene.instantiate() as ItemEffect
		if !item:
			continue
			
		var button = preload("res://ui/item_button.tscn").instantiate()
		button.setup(scene)
		button.pressed.connect(_on_item_button_pressed.bind(scenes_to_show.find(scene)))
		
		item_container.add_child(button)
		item_buttons.append(button)
		
		item.queue_free()
	
	_update_info()
	show_ui(true)
	update_selection()
	# Container layout'unun oturmasını bekleyip kartların hedef pozisyonunu öyle yakala,
	# sonra soldan/sağdan/aşağıdan kayarak + hafif büyüyerek içeri giren giriş animasyonu oynat.
	await get_tree().process_frame
	CardVisualUtil.play_card_entrance(item_buttons)

func update_selection() -> void:
	for i in item_buttons.size():
		var button = item_buttons[i]
		# Dükkânda parası yetmeyen kart seçili olsa da soluk kalır — alınamayacağı belli olsun
		if _shop_mode and i < _shop_prices.size() and not _can_afford(_shop_prices[i]):
			button.modulate = Color(0.5, 0.42, 0.42) if i == selected_index else Color(0.32, 0.28, 0.28)
			continue
		button.modulate = Color.WHITE if i == selected_index else Color(0.4, 0.4, 0.4)

func _move_selection(direction: int) -> void:
	if item_buttons.is_empty():
		return
	
	var count := item_buttons.size()
	selected_index = (selected_index + direction + count) % count
	update_selection()
	get_viewport().set_input_as_handled()

func select_item(index: int) -> void:
	if is_processing_selection:
		return
		
	if _shop_mode:
		_try_buy(index)
		return

	is_processing_selection = true
	if _unlock_mode:
		# Kalıcı koleksiyona ekle — bu run'da aktifleşmez.
		if index >= 0 and index < _unlock_ids.size():
			ItemManager.unlock_item(_unlock_ids[index])
	else:
		var item_scene = scenes_to_show[index]
		ItemManager.activate_item(item_scene)

	# Slow time effect when exiting
	if get_node_or_null("/root/ScreenEffects"):
		ScreenEffects.slow_time(0.2, 0.3)

	# Seçilmeyen kartlar geldikleri yönün tersine hızlıca kayıp kaybolur, seçilen hafif öne çıkar.
	CardVisualUtil.play_card_exit(item_buttons, index)

	await get_tree().create_timer(0.25).timeout
	get_tree().paused = false
	queue_free()

## Dükkân satın alma. Ödeme ve item aktivasyonu çağıran tarafta (market) yapılır;
## burada sadece karşılayabiliyor mu diye bakılır. Oyun duraklatılmış olduğu için
## bu iki an arasında altın değişemez.
func _try_buy(index: int) -> void:
	if index < 0 or index >= _shop_prices.size():
		return
	if not _can_afford(_shop_prices[index]):
		selection_hold_time = 0.0
		if index < item_buttons.size():
			item_buttons[index].set_progress(0.0)
		_refusal_timer = 1.4
		_update_info()
		return

	var bought_id: String = _shop_ids[index] if index < _shop_ids.size() else ""
	# Ödemeyi ve item aktivasyonunu market yapar; başarısızsa tezgâh olduğu gibi kalır.
	if _buy_handler.is_valid() and not bool(_buy_handler.call(bought_id, _shop_prices[index])):
		selection_hold_time = 0.0
		if index < item_buttons.size():
			item_buttons[index].set_progress(0.0)
		_refusal_timer = 1.4
		_update_info()
		return

	# Satılan kart tezgâhtan kalkar, dükkân açık kalır
	_shop_ids.remove_at(index)
	_shop_prices.remove_at(index)
	_shop_scenes.remove_at(index)
	selection_hold_time = 0.0
	if _shop_scenes.is_empty():
		_sold_out = true
		_leave_shop()
		return
	selected_index = clampi(index, 0, _shop_scenes.size() - 1)
	_rebuild_shop_cards()


func _rebuild_shop_cards() -> void:
	for child in item_container.get_children():
		child.queue_free()
	item_buttons.clear()
	for scene in _shop_scenes:
		var item = scene.instantiate() as ItemEffect
		if !item:
			continue
		var button = preload("res://ui/item_button.tscn").instantiate()
		button.setup(scene)
		button.pressed.connect(_on_item_button_pressed.bind(_shop_scenes.find(scene)))
		item_container.add_child(button)
		item_buttons.append(button)
		item.queue_free()
	selected_index = clampi(selected_index, 0, maxi(0, item_buttons.size() - 1))
	_select_lockout = SELECT_LOCKOUT_DURATION
	_jump_released_once = false
	_refresh_shop_visuals()


func _leave_shop() -> void:
	if is_processing_selection:
		return
	is_processing_selection = true
	shop_closed.emit("")
	get_tree().paused = false
	queue_free()


func _on_item_button_pressed(index: int) -> void:
	selected_index = index
	update_selection()

func show_ui(show: bool) -> void:
	visible = show

## Başlık moda göre değişir ve çeviriden gelir. Sahnede sabit "Choose Your Item" yazıyordu:
## hem İngilizceydi hem dükkânda yanlıştı (orada eşya seçmiyorsun, satın alıyorsun).
func _update_title() -> void:
	if title_label == null:
		return
	if _shop_mode:
		title_label.text = tr("item_selection.title.shop")
	elif _unlock_mode:
		title_label.text = tr("item_selection.title.unlock")
	else:
		title_label.text = tr("item_selection.title.draft")


func _update_info() -> void:
	_update_title()
	if !info_label:
		return

	if _shop_mode:
		# Kese bakiyesi artık başlığın altındaki ikon+sayı satırında; burada sadece yönerge.
		info_label.text = tr("item_selection.shop.poor") if _refusal_timer > 0.0 else tr("item_selection.shop.hint")
		return

	if _unlock_mode:
		var theme_name: String = WorldManager.get_dungeon_theme_display_name(_unlock_theme)
		var lead: String = tr("item_selection.unlock.kesif") if _unlock_tier == "kesif" else tr("item_selection.unlock.boss")
		var progress: Dictionary = ItemManager.get_theme_unlock_progress(_unlock_theme)
		info_label.text = "%s\n%s\n%d/%d" % [
			tr("item_selection.unlock.header") % [lead, theme_name],
			tr("item_selection.unlock.body"),
			int(progress.get("unlocked", 0)), int(progress.get("total", 0))
		]
		return

	var active_count = ItemManager.get_active_items().size()
	var info := tr("item_selection.active_items") + str(active_count)
	var sets := ItemManager.get_active_item_sets()
	if not sets.is_empty():
		info += "\n"
		for set_id in sets:
			var def: Dictionary = ItemManager.ITEM_SET_DEFINITIONS.get(set_id, {})
			info += "⚡ " + tr(String(def.get("name_key", set_id))) + "\n"
	info_label.text = info
