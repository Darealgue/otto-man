extends MarginContainer # .tscn dosyasındaki kök node türü

# Bu script, UI elemanlarını kod ile oluşturur ve günceller.

# Label referansları (@onready ile sahneden alınacak)
# ÖNEMLİ: Bu node isimlerinin (%GoldLabel%) .tscn dosyasındaki
# Label'ların "Unique Name in Owner" özelliği işaretlenerek verildiğini varsayar.
# Eğer işaretlenmediyse, get_node("StatusVBox/GoldLabel") gibi yolları kullan.
@onready var gold_label: Label = %GoldLabel
@onready var worker_label: Label = %WorkerLabel
@onready var asker_label: Label = %AskerLabel
@onready var wood_label: Label = %WoodLabel
@onready var stone_label: Label = %StoneLabel
@onready var food_label: Label = %FoodLabel
@onready var water_label: Label = %WaterLabel
@onready var metal_label: Label = %MetalLabel
@onready var bread_label: Label = %BreadLabel
var _water_row: Control = null
@onready var summary_container: HBoxContainer = %SummaryHBox
@onready var resource_list_container: HFlowContainer = %ResourceList
# Şeridin ortasındaki cam fanus (MoraleJarUI) metinlerin altında kalmasın diye
# sol/sağ grupları dengeleyen boşluklar.
@onready var _left_group: HBoxContainer = %LeftGroup
@onready var _right_group: HBoxContainer = %RightGroup
@onready var _outer_left_pad: Control = %OuterLeftPad
@onready var _outer_right_pad: Control = %OuterRightPad
# Events (Morale artık üst şeritteki cam fanus göstergesinde — MoraleJarUI.gd)
# EventsSlot: olay yokken bile sabit genişlikte boşluk bırakır, layout zıplamaz.
@onready var _events_slot: Control = %EventsSlot
@onready var events_label: Label = %EventsLabel
var housing_label: Label = null
# İleride eklenecek diğer label'lar için @onready değişkenler...

# Üretici script yolu eşlemeleri (sadece bu üreticiler yerleştirildiyse kaynak göster)
const PRODUCER_SCRIPTS := {
	"wood": "res://village/scripts/WoodcutterCamp.gd",
	"stone": "res://village/scripts/StoneMine.gd",
	"food": "res://village/scripts/HunterGathererHut.gd",
	"lumber": "res://village/scripts/Sawmill.gd",
	"brick": "res://village/scripts/Brickworks.gd",
	"metal": "res://village/scripts/Blacksmith.gd",
	"bread": "res://village/scripts/Bakery.gd",
	"cloth": "res://village/scripts/Weaver.gd",
	# Gelişmiş kaynaklar — silah seviyeleri (zırh sistemi kaldırıldı)
	"weapon_t1": "res://village/scripts/Gunsmith.gd",
	"weapon_t2": "res://village/scripts/Gunsmith.gd",
	"weapon_t3": "res://village/scripts/Gunsmith.gd",
	"garment": "res://village/scripts/Tailor.gd",
	"tea": "res://village/scripts/TeaHouse.gd",
	"soap": "res://village/scripts/SoapMaker.gd",
	"medicine": "res://village/scripts/Herbalist.gd"
}

var _extra_resource_labels: Dictionary = {}
var _cached_disaster_hints: Dictionary = {}

const StatChangeFX = preload("res://ui/stat_change_fx.gd")
## Oyuncu köyden uzaktayken (zindanda) değişen sayıları fark edebilsin diye,
## bu değerler her _update_labels çağrısında önceki değerle kıyaslanır; fark
## varsa StatChangeFX ile sallanma + renkli (+/-) popup oynatılır.
var _prev_soldier_count: int = -1
var _prev_housing_occupied: int = -1

# Icon sizing for resource rows
const RESOURCE_ICON_SIZE := Vector2(25, 25)
## İkon ile kendi sayısı arası sıkı boşluk (bir sonraki ikonla arayı ayırt etmek için).
const RESOURCE_ROW_SEPARATION := 3

# --- Periyodik Güncelleme ---
var update_interval: float = 0.5 # Saniyede 2 kez güncelle
var time_since_last_update: float = 0.0
# ---------------------------

var _parchment_debug: bool = false
var _canvas_layer: CanvasLayer
var _last_top_bar_size := Vector2.ZERO
## Alttaki siyah şerit sabit/dar (64px) — bar bunun üstüne taşmasın diye tavan burada.
const TOP_BAR_MAX_HEIGHT := 60.0

func _ready() -> void:
	add_to_group("village_status_ui")
	# Node referanslarının alınıp alınmadığını kontrol et (güvenlik için)
	if not gold_label or not worker_label or not asker_label or not wood_label or \
	   not stone_label or not food_label or not water_label or not metal_label or \
	   not bread_label:
		printerr("VillageStatusUI Error: Label node'larından biri veya birkaçı bulunamadı! .tscn dosyasındaki isimleri (%NodeName%) veya 'Unique Name in Owner' ayarlarını kontrol edin.")
		return
	if not summary_container or not resource_list_container:
		printerr("VillageStatusUI Warning: SummaryHBox veya ResourceList bulunamadı! Düzen yerleşimini kontrol edin.")

	TextOutline.apply_to_tree(self)
	# Üst şerit artık parşömen değil, düz siyah — bu satırdaki metinler beyaz olmalı.
	_apply_top_bar_label_color(gold_label)
	_apply_top_bar_label_color(worker_label)
	_apply_top_bar_label_color(asker_label)

	# Wrap static labels with icons if icons exist
	_wrap_label_with_icon(wood_label, "wood")
	_wrap_label_with_icon(stone_label, "stone")
	_wrap_label_with_icon(food_label, "food")
	if water_label:
		_water_row = water_label.get_parent() as Control
		_hide_water_row()
	_wrap_label_with_icon(metal_label, "metal")
	_wrap_label_with_icon(bread_label, "bread")

	# Ek etiketler sahnede yoksa dinamik oluştur
	_ensure_extra_labels()

	# Sinyale bağlan — işçi ataması / kaynak değişince hasılat hemen güncellensin.
	if VillageManager.has_signal("village_data_changed"):
		VillageManager.village_data_changed.connect(_update_labels)

	# GlobalPlayerData için doğrudan sinyal yok, village_data_changed tetiklendiğinde
	# veya _process içinde periyodik olarak güncellenebilir. Şimdilik _update_labels içinde.

	# İlk Güncellemeyi Yap
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	_update_labels()
	_canvas_layer = get_parent().get_parent().get_parent() as CanvasLayer
	_apply_hud_parchment_textures()
	call_deferred("_sync_parchment_boxes_to_content")
	print("VillageStatusUI Ready. (F9 = parşömen overlay | F10 = ölçü raporu)")


## Üst siyah şerit için varsayılan (durum rengi yokken) metin rengi: beyaz + siyah kontur.
func _apply_top_bar_label_color(label: Label) -> void:
	if not is_instance_valid(label):
		return
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)


## Net üretim etiketi rengi: eksi kırmızı, artı yeşil, sıfır beyaz.
func _apply_net_label_color(label: Label, net_int: int) -> void:
	if not is_instance_valid(label):
		return
	var color: Color
	if net_int > 0:
		color = Color(0.45, 0.9, 0.5)
	elif net_int < 0:
		color = Color(1.0, 0.45, 0.45)
	else:
		color = Color(1, 1, 1, 1)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)


## LeftGroup (Altın/İşçi/Barınma) ile RightGroup (Asker) genişlikleri metne göre
## sürekli değiştiği için, aradaki JarGap'in ekran ortasında (fanusun altında)
## kalması için kısa taraf dış kenardan aynı miktarda içeri itilir.
func _balance_top_bar_groups() -> void:
	if not is_instance_valid(_left_group) or not is_instance_valid(_right_group):
		return
	if not is_instance_valid(_outer_left_pad) or not is_instance_valid(_outer_right_pad):
		return
	var left_w := _left_group.get_combined_minimum_size().x
	var right_w := _right_group.get_combined_minimum_size().x
	var diff := left_w - right_w
	_outer_left_pad.custom_minimum_size = Vector2(maxf(0.0, -diff), 1)
	_outer_right_pad.custom_minimum_size = Vector2(maxf(0.0, diff), 1)


func _on_locale_changed(_locale: String = "") -> void:
	_update_labels()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F9:
		_parchment_debug = not _parchment_debug
		_set_parchment_debug(_parchment_debug)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F10:
		_log_panel_measurements()
		get_viewport().set_input_as_handled()


func _set_parchment_debug(enabled: bool) -> void:
	if _canvas_layer == null:
		return
	var pf := _canvas_layer.get_node_or_null("TopBarPanel") as ParchmentFrame
	if pf:
		pf.debug_layout = enabled
	print("\n[VillageStatusUI] Parşömen debug: %s (kırmızı=kenar, yeşil=esneyen orta, mavi=içerik)\n" % ("AÇIK" if enabled else "KAPALI"))
	if enabled:
		_log_panel_measurements()


func _log_panel_measurements() -> void:
	if _canvas_layer == null:
		_canvas_layer = get_parent().get_parent().get_parent() as CanvasLayer
	if _canvas_layer == null:
		return
	await get_tree().process_frame
	var lines: PackedStringArray = PackedStringArray([
		"",
		"========== VillageStatusUI ÖLÇÜ RAPORU ==========",
		"(Parşömen PNG çizerken: köşe patch + bu kutulara yakın boyut)",
		"",
	])
	_log_one_panel(lines, "TopBarPanel (üst status)", _canvas_layer.get_node_or_null("TopBarPanel") as ParchmentFrame, summary_container)
	lines.append("Sahne dosyası offset (tasarım):")
	lines.append("  TopBarPanel: 765 x 53  (anchor üst-orta)")
	lines.append("Öneri: texture boyutu ≈ 'parşömen kutusu' veya içerik+patch; 96x72 envanter için dar kalabilir.")
	lines.append("==================================================")
	print("\n".join(lines))


func _log_one_panel(lines: PackedStringArray, title: String, panel: ParchmentFrame, content: Control) -> void:
	lines.append("--- %s ---" % title)
	if panel == null:
		lines.append("  (panel bulunamadı)")
		return
	var pm := panel.get_patch_margins()
	var gr := panel.get_global_rect()
	lines.append("  Parşömen kutusu (runtime): %.0f x %.0f px" % [panel.size.x, panel.size.y])
	lines.append("  Ekranda global: pos %.0f,%.0f  boyut %.0f x %.0f" % [gr.position.x, gr.position.y, gr.size.x, gr.size.y])
	lines.append("  patch margin L,T,R,B: %d,%d,%d,%d  |  content_margin: %d" % [pm.x, pm.y, pm.z, pm.w, panel.content_margin])
	var stretch_center := Vector2(
		maxf(0.0, panel.size.x - float(pm.x + pm.z)),
		maxf(0.0, panel.size.y - float(pm.y + pm.w))
	)
	lines.append("  NinePatch orta (esneyen): %.0f x %.0f px" % [stretch_center.x, stretch_center.y])
	if content:
		var content_min := content.get_combined_minimum_size()
		lines.append("  İçerik minimum (label/icon satırları): %.0f x %.0f px" % [content_min.x, content_min.y])
		var needed_w := content_min.x + float(pm.x + pm.z + panel.content_margin * 2)
		var needed_h := content_min.y + float(pm.y + pm.w + panel.content_margin * 2)
		lines.append("  Parşömen için önerilen texture (≈1:1 esneme): %.0f x %.0f px" % [needed_w, needed_h])
		if panel.size.x + 2.0 < needed_w or panel.size.y + 2.0 < needed_h:
			lines.append("  UYARI: Kutu içerikten KÜÇÜK — taşma veya sıkışma olur; sahne offset artır veya texture küçük patch.")
	var tex: Texture2D = panel.parchment_texture
	if tex == null:
		var np := panel.get_node_or_null("NinePatch") as NinePatchRect
		if np and np.texture:
			tex = np.texture
	if tex:
		lines.append("  Aktif texture: %s (kaynak %.0f x %.0f)" % [
			tex.resource_path.get_file(), tex.get_width(), tex.get_height()
		])
	lines.append("")


func _calc_parchment_frame_size(panel: ParchmentFrame, inner: Control) -> Vector2:
	var pm := panel.get_patch_margins()
	var sz := inner.get_combined_minimum_size()
	return Vector2(
		sz.x + float(pm.x + pm.z + panel.content_margin * 2),
		sz.y + float(pm.y + pm.w + panel.content_margin * 2)
	)


## Parşömen kutusunu içeriğe göre boyutlandır; üst-orta konum sabit kalır.
func _sync_parchment_boxes_to_content() -> void:
	if _canvas_layer == null:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_sync_top_bar_to_content()


func _apply_hud_parchment_textures() -> void:
	if _canvas_layer == null:
		return
	var top_bar := _canvas_layer.get_node_or_null("TopBarPanel") as ParchmentFrame
	if top_bar:
		var bar_tex := ParchmentTextures.resolve_hud_bar()
		if bar_tex:
			top_bar.parchment_texture = bar_tex
			top_bar.patch_margin_left = 16
			top_bar.patch_margin_right = 16
			top_bar.patch_margin_top = 8
			top_bar.patch_margin_bottom = 8
		else:
			var compact_tex := ParchmentTextures.load_if_exists(ParchmentTextures.COMPACT)
			if compact_tex:
				top_bar.parchment_texture = compact_tex
				top_bar.patch_margin_left = 20
				top_bar.patch_margin_right = 20
				top_bar.patch_margin_top = 8
				top_bar.patch_margin_bottom = 8
		top_bar.apply_style_now()


func _calc_top_bar_frame_size(top_bar: ParchmentFrame) -> Vector2:
	var pm := top_bar.get_patch_margins()
	var row_sz := summary_container.get_combined_minimum_size()
	var pad := Vector2(8.0, 4.0)
	var ui_margin := summary_container.get_parent() as MarginContainer
	if ui_margin:
		pad.x = float(ui_margin.get_theme_constant("margin_left") + ui_margin.get_theme_constant("margin_right"))
		pad.y = float(ui_margin.get_theme_constant("margin_top") + ui_margin.get_theme_constant("margin_bottom"))
	return Vector2(
		row_sz.x + pad.x + float(pm.x + pm.z + top_bar.content_margin * 2),
		row_sz.y + pad.y + float(pm.y + pm.w + top_bar.content_margin * 2)
	)


func _sync_top_bar_to_content() -> void:
	if _canvas_layer == null or summary_container == null:
		return
	var top_bar := _canvas_layer.get_node_or_null("TopBarPanel") as ParchmentFrame
	if top_bar == null:
		return
	top_bar.clip_contents = false
	var sz := _calc_top_bar_frame_size(top_bar)
	# Şerit sabit (daraltılmış) kalsın diye bar'ın yüksekliği bu aralıkla sınırlı tutuluyor;
	# içerik daha fazlasını isterse şeridin dışına taşmak yerine bu boyuta sığdırılıyor.
	sz.y = clampf(sz.y, 56.0, TOP_BAR_MAX_HEIGHT)
	# Metin uzayınca (ikmal, barınma vb.) genişliği tekrar aç
	if _last_top_bar_size != Vector2.ZERO:
		if sz.x <= _last_top_bar_size.x + 1.0 and absf(sz.y - _last_top_bar_size.y) < 2.0:
			return
	_last_top_bar_size = sz
	var half_w := sz.x * 0.5
	top_bar.offset_left = -half_w
	top_bar.offset_right = half_w
	top_bar.offset_top = -sz.y
	top_bar.offset_bottom = 0.0


func _process(delta: float) -> void:
	# Zamanı artır
	time_since_last_update += delta

	# Eğer interval dolduysa UI'ı güncelle
	if time_since_last_update >= update_interval:
		# print("VillageStatusUI: Updating UI via _process timer") # Opsiyonel Debug
		_update_labels()
		time_since_last_update = 0.0 # Sayacı sıfırla

# Tüm etiketleri güncelleyen fonksiyon
func _update_labels() -> void:
	# Node referanslarının hala geçerli olup olmadığını kontrol etmek iyi bir pratiktir
	if not is_instance_valid(gold_label):
		printerr("VillageStatusUI Error: Label node referansları geçersiz!")
		# Belki sinyal bağlantısını kesmek gerekir:
		# if VillageManager.is_connected("village_data_changed", Callable(self, "_update_labels")):
		#     VillageManager.disconnect("village_data_changed", Callable(self, "_update_labels"))
		return

	# Global Veriler — Altın/İşçi/Barınma artık ikon+sayı, kelime öneki yok.
	gold_label.text = ": %d" % GlobalPlayerData.gold
	var soldier_count = _get_soldier_count()
	asker_label.text = ": %d" % soldier_count
	if _prev_soldier_count >= 0 and soldier_count != _prev_soldier_count:
		StatChangeFX.bump(asker_label, soldier_count - _prev_soldier_count)
	_prev_soldier_count = soldier_count
	# Diğer gelişmiş kaynaklar...

	# VillageManager Verileri
	worker_label.text = ": %d" % VillageManager.idle_workers
	var projected_nets: Dictionary = {}
	if VillageManager.has_method("get_projected_daily_resource_nets"):
		projected_nets = VillageManager.get_projected_daily_resource_nets()
	_cached_disaster_hints = {}
	if VillageManager.has_method("get_resource_disaster_hints"):
		_cached_disaster_hints = VillageManager.get_resource_disaster_hints()

	# Barınma kapasitesi göstergesi (ikon+sayı, kelime öneki yok)
	# X = barınak arayan TÜM köylü sayısı (nüfus), Y = toplam EV kapasitesi (kamp ateşi HARİÇ —
	# kamp ateşi artık gerçek bir barınak sayılmıyor, sadece ev bulunana kadar bekleyen
	# misafir köylüler için geçici bir alan).
	# X, Y'den büyük olabilir — bu durumda barınak yetersiz demektir ve etiket kırmızıya döner.
	if is_instance_valid(housing_label) and VillageManager.has_method("get_housing_summary"):
		var hs: Dictionary = VillageManager.get_housing_summary()
		var h_pop: int = int(hs.get("population", hs.get("occupied", 0)))
		var h_cap: int = int(hs.get("house_capacity", 0))
		housing_label.text = ": %d/%d" % [h_pop, h_cap]
		if _prev_housing_occupied >= 0 and h_pop != _prev_housing_occupied:
			StatChangeFX.bump(housing_label, h_pop - _prev_housing_occupied)
		_prev_housing_occupied = h_pop
		# Nüfus kapasiteyi aşıyorsa (barınaksız köylü var) kırmızı; tam doluysa sarı.
		if h_cap > 0 and h_pop > h_cap:
			TextOutline.apply_label_color(housing_label, Color(1, 0.35, 0.3))
			housing_label.tooltip_text = "Barınak yetersiz — %d köylünün yatacak yeri yok" % (h_pop - h_cap)
		elif h_cap > 0 and h_pop >= h_cap:
			TextOutline.apply_label_color(housing_label, Color(1, 0.85, 0.2))
			housing_label.tooltip_text = ""
		else:
			_apply_top_bar_label_color(housing_label)
			housing_label.tooltip_text = ""

	_set_resource_visible_and_update(wood_label, "wood", true, false, projected_nets)
	_set_resource_visible_and_update(stone_label, "stone", true, false, projected_nets)
	_set_resource_visible_and_update(food_label, "food", true, false, projected_nets)
	_hide_water_row()
	_set_resource_visible_and_update(metal_label, "metal", false, true, projected_nets)
	_set_resource_visible_and_update(bread_label, "bread", false, true, projected_nets)

	_update_dynamic_resource_label("lumber", projected_nets)
	_update_dynamic_resource_label("brick", projected_nets)
	_update_dynamic_resource_label("weapon_t1", projected_nets)
	_update_dynamic_resource_label("weapon_t2", projected_nets)
	_update_dynamic_resource_label("weapon_t3", projected_nets)
	_update_dynamic_resource_label("garment", projected_nets)
	_update_dynamic_resource_label("cloth", projected_nets)
	_update_dynamic_resource_label("tea", projected_nets)
	_update_dynamic_resource_label("soap", projected_nets)
	_update_dynamic_resource_label("medicine", projected_nets)

	# Aktif olaylar
	var tm = get_node_or_null("/root/TimeManager")
	var day: int = tm.get_day() if tm and tm.has_method("get_day") else 0
	var summaries = VillageManager.get_active_events_summary(day)
	if is_instance_valid(events_label):
		if summaries.is_empty():
			events_label.text = ""
		else:
			var lines: Array[String] = []
			for s in summaries:
				var level_name: String = s.get("level_name", "")
				if level_name.is_empty():
					var sev = float(s.get("severity", 0.0))
					if sev < 0.2:
						level_name = tr("severity.low")
					elif sev < 0.3:
						level_name = tr("severity.medium")
					else:
						level_name = tr("severity.high")
				lines.append(tr("hud.event_line") % [String(s["type"]).capitalize(), level_name, int(s["days_left"])])
			events_label.text = ", ".join(lines)

	_balance_top_bar_groups()
	call_deferred("_sync_top_bar_to_content")


func _hide_water_row() -> void:
	if _water_row:
		_water_row.visible = false
	elif water_label:
		water_label.visible = false


func _ensure_extra_labels() -> void:
	# Sahnede yoksa EventsLabel oluşturur (Morale artık MoraleJarUI'da)
	var container: Node = summary_container if is_instance_valid(summary_container) else (bread_label.get_parent() if bread_label and bread_label.get_parent() else self)
	if not is_instance_valid(events_label):
		events_label = Label.new()
		events_label.name = "EventsLabel"
		# EventsSlot sabit genişlikte bir boşluk: olay yokken de yer kaplar, layout zıplamaz.
		var events_parent: Node = _events_slot if is_instance_valid(_events_slot) else (_right_group if is_instance_valid(_right_group) else container)
		events_parent.add_child(events_label)
		events_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		events_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		events_label.clip_text = true
		TextOutline.apply_font_to_control(events_label)
		_apply_top_bar_label_color(events_label)
	if not is_instance_valid(housing_label):
		housing_label = Label.new()
		housing_label.name = "HousingLabel"
		# WorkerLabel artık kendi ikon satırının (WorkerRow) içinde; barınmayı
		# LeftGroup'a, o satırdan hemen sonra ekle (WorkerRow'un içine değil).
		var group_parent: Node = _left_group if is_instance_valid(_left_group) else container
		var worker_row: Node = worker_label.get_parent() if is_instance_valid(worker_label) else null
		var anchor: Node = worker_row if (is_instance_valid(worker_row) and worker_row.get_parent() == group_parent) else worker_label
		group_parent.add_child(housing_label)
		var anchor_idx: int = group_parent.get_children().find(anchor)
		if anchor_idx >= 0:
			group_parent.move_child(housing_label, anchor_idx + 1)
		TextOutline.apply_font_to_control(housing_label)
		_apply_top_bar_label_color(housing_label)
		# İkon dosyası (house_icon.png) bulunduğu için kendi satırına sarılır.
		_wrap_label_with_icon(housing_label, "housing", false)

# Tek bir kaynak etiketini güncelleyen helper fonksiyonu
func _disaster_hint_suffix(resource_key: String) -> String:
	var parts: Array = _cached_disaster_hints.get(resource_key, [])
	if parts.is_empty():
		return ""
	return " " + " ".join(parts)

func _apply_gather_uncertainty_tooltip(label_node: Label, resource_key: String) -> void:
	if not VillageManager.has_method("is_gather_projection_uncertain"):
		label_node.tooltip_text = ""
		return
	if VillageManager.is_gather_projection_uncertain(resource_key):
		label_node.tooltip_text = tr("hud.gather_uncertain_tooltip")
	else:
		label_node.tooltip_text = ""

func _update_resource_label(label_node: Label, resource_key: String, projected_nets: Dictionary = {}) -> void:
	if not is_instance_valid(label_node):
		return

	var resource_display_name := LocaleManager.get_resource_name(resource_key)
	var current: int = VillageManager.get_resource_level(resource_key)
	var cap: int = VillageManager.get_storage_capacity_for(resource_key)
	# Sade net göstergesi: ayrı, renkli bir etikette "(+1)" / "(-2)" — miktarın rengini karıştırmaz.
	var net_int := int(round(float(projected_nets.get(resource_key, 0.0))))
	var disaster_suffix := _disaster_hint_suffix(resource_key)
	var uncertain := VillageManager.has_method("is_gather_projection_uncertain") and VillageManager.is_gather_projection_uncertain(resource_key)
	# Check if label has icon_only meta, or if it's in a Row container with an icon
	var icon_only := false
	if label_node.has_meta("icon_only"):
		icon_only = bool(label_node.get_meta("icon_only"))
	else:
		# Check if parent is a Row container with TextureRect (icon)
		var parent = label_node.get_parent()
		if is_instance_valid(parent) and parent is HBoxContainer:
			if parent.name.ends_with("Row") or parent.name.ends_with("RowDynamic"):
				for child in parent.get_children():
					if child is TextureRect:
						icon_only = true
						# Set meta for future checks
						label_node.set_meta("icon_only", true)
						break
	
	if cap > 0:
		if icon_only:
			label_node.text = ": %d/%d" % [current, cap]
		else:
			label_node.text = tr("hud.resource_cap") % [resource_display_name, current, cap, disaster_suffix]

		# Highlight when full; felaket uyarısı turuncu
		var ratio := (float(current) / float(cap)) if cap > 0 else 0.0
		if current >= cap:
			TextOutline.apply_label_color(label_node, Color(1, 0.85, 0.2))
		elif not disaster_suffix.is_empty() or uncertain:
			TextOutline.apply_label_color(label_node, Color(1, 0.72, 0.28))
		elif ratio >= 0.8:
			TextOutline.apply_label_color(label_node, Color(1.0, 0.95, 0.6))
		else:
			_apply_top_bar_label_color(label_node)
	else:
		if icon_only:
			label_node.text = ": %d" % current
		else:
			label_node.text = tr("hud.resource_amount") % [resource_display_name, current, disaster_suffix]
		if not disaster_suffix.is_empty() or uncertain:
			TextOutline.apply_label_color(label_node, Color(1, 0.72, 0.28))
		else:
			_apply_top_bar_label_color(label_node)

	var net_label := _ensure_net_label(label_node)
	if is_instance_valid(net_label):
		if net_int == 0:
			net_label.text = ""
		else:
			net_label.text = "(%s%d)" % ["+" if net_int >= 0 else "", net_int]
			_apply_net_label_color(net_label, net_int)

	_apply_gather_uncertainty_tooltip(label_node, resource_key)

# Helper: dinamik kaynak etiketi güncelle/oluştur
func _update_dynamic_resource_label(resource_key: String, projected_nets: Dictionary = {}) -> void:
	var label := _get_or_create_resource_label(resource_key)
	if not is_instance_valid(label):
		return
	var current: int = VillageManager.get_resource_level(resource_key)
	var should_show = current > 0
	_set_container_visibility(label, should_show)
	if should_show:
		_update_resource_label(label, resource_key, projected_nets)

# Helper: üretici bina var mı kontrol et
func _producer_exists(resource_key: String) -> bool:
	var script_path: String = String(PRODUCER_SCRIPTS.get(resource_key, ""))
	if script_path == "":
		return false
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return false
	var placed = scene.get_node_or_null("PlacedBuildings")
	if not placed:
		return false
	for b in placed.get_children():
		if b.has_method("get_script") and b.get_script() != null:
			var sp = b.get_script().resource_path
			if sp == script_path:
				return true
	return false

# Helper: görünürlük + güncelleme
func _set_resource_visible_and_update(label_node: Label, key: String, force_visible: bool, show_when_nonzero: bool = false, projected_nets: Dictionary = {}) -> void:
	if not is_instance_valid(label_node):
		return
	var current: int = VillageManager.get_resource_level(key)
	var visible_by_stock := show_when_nonzero and current > 0
	var should_show = force_visible or visible_by_stock
	if is_instance_valid(label_node):
		_set_container_visibility(label_node, should_show)
	if should_show:
		_update_resource_label(label_node, key, projected_nets)

# Helper: Parent container'ı (Row) gizle/göster
func _set_container_visibility(label_node: Label, visible: bool) -> void:
	if not is_instance_valid(label_node):
		return
	label_node.visible = visible
	var parent = label_node.get_parent()
	if is_instance_valid(parent) and (parent is HBoxContainer) and (parent.name.ends_with("Row") or parent.name.ends_with("RowDynamic")):
		parent.visible = visible

# Helper: Barracks'tan asker sayısını al
func _get_soldier_count() -> int:
	var scene = get_tree().current_scene
	if not is_instance_valid(scene):
		return 0
	var placed = scene.get_node_or_null("PlacedBuildings")
	if not placed:
		return 0
	for building in placed.get_children():
		if building.has_method("get_military_force"):  # Barracks-specific method
			# assigned_workers property'sine direkt erişmeyi dene
			if building.get("assigned_workers") != null:
				return building.assigned_workers
			return 0
	return 0

# Helper: ihtiyaç halinde label oluştur
func _get_or_create_resource_label(resource_key: String) -> Label:
	if _extra_resource_labels.has(resource_key):
		return _extra_resource_labels[resource_key]
	var container: Node = resource_list_container if is_instance_valid(resource_list_container) else (bread_label.get_parent() if bread_label and bread_label.get_parent() else self)
	var lbl := _create_resource_row_with_icon(resource_key, container)
	_extra_resource_labels[resource_key] = lbl
	return lbl

func _create_resource_row_with_icon(resource_key: String, container: Node) -> Label:
	var row := HBoxContainer.new()
	row.name = resource_key.capitalize() + "RowDynamic"
	row.layout_mode = 2
	row.add_theme_constant_override("separation", RESOURCE_ROW_SEPARATION)

	var icon_path := _get_icon_path_for_resource(resource_key)
	if icon_path != "":
		var icon := TextureRect.new()
		icon.name = resource_key.capitalize() + "Icon"
		icon.layout_mode = 2
		icon.custom_minimum_size = RESOURCE_ICON_SIZE
		icon.texture = load(icon_path)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

	var lbl := Label.new()
	lbl.name = resource_key.capitalize() + "LabelDynamic"
	lbl.layout_mode = 2
	lbl.set_meta("icon_only", true)
	lbl.text = "-"
	row.add_child(lbl)
	TextOutline.apply_font_to_control(lbl)

	container.add_child(row)
	return lbl

func _get_icon_path_for_resource(resource_key: String) -> String:
	var candidates: Array[String] = []
	if resource_key == "tea":
		candidates = [
			"res://assets/Icons/coffee_icon.png",
			"res://assets/Icons/coffe_icon.png",
			"res://assets/Icons/tea_icon.png"
		]
	elif resource_key == "soap":
		candidates = [
			"res://assets/Icons/perfume_icon.png",
			"res://assets/Icons/soap_icon.png"
		]
	elif resource_key == "weapon_t1" or resource_key == "weapon_t2" or resource_key == "weapon_t3":
		candidates = ["res://assets/Icons/weapon_icon.png"]
	elif resource_key == "housing":
		candidates = [
			"res://assets/Icons/house_icon.png",
			"res://assets/Icons/housing_icon.png"
		]
	else:
		candidates = ["res://assets/Icons/%s_icon.png" % resource_key]
	for path in candidates:
		if ResourceLoader.exists(path):
			return path
	return ""

## has_net=true olan kaynaklar (odun, taş vb.) satırına ayrı, renkli bir net etiketi eklenir.
## Barınma gibi net üretimi olmayan göstergeler için has_net=false geçilir.
func _wrap_label_with_icon(label_node: Label, resource_key: String, has_net: bool = true) -> void:
	if not is_instance_valid(label_node):
		return

	var parent := label_node.get_parent()
	if not is_instance_valid(parent):
		return
	# Already wrapped with an icon? Check if parent is a Row container and has TextureRect
	if parent is HBoxContainer and (parent.name.ends_with("Row") or parent.name.ends_with("RowDynamic")):
		for child in parent.get_children():
			if child is TextureRect:
				# Already wrapped, just ensure icon_only meta is set
				label_node.set_meta("icon_only", true)
				if has_net:
					_ensure_net_label(label_node)
				return

	var icon_path := _get_icon_path_for_resource(resource_key)
	# İkon yoksa bile net etiketiyle sıkı gruplanabilmesi için yine de satıra sarılır.
	if icon_path == "" and not has_net:
		return
	var index: int = parent.get_children().find(label_node)
	if index < 0:
		return
	parent.remove_child(label_node)
	var row := HBoxContainer.new()
	row.name = resource_key.capitalize() + "Row"
	row.layout_mode = 2
	row.add_theme_constant_override("separation", RESOURCE_ROW_SEPARATION)
	if icon_path != "":
		var icon := TextureRect.new()
		icon.name = resource_key.capitalize() + "Icon"
		icon.layout_mode = 2
		icon.custom_minimum_size = RESOURCE_ICON_SIZE
		icon.texture = load(icon_path)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	row.add_child(label_node)
	parent.add_child(row)
	parent.move_child(row, index)
	# Force icon_only meta to ensure text is formatted correctly (just number)
	label_node.set_meta("icon_only", true)
	if has_net:
		_ensure_net_label(label_node)


## Bir miktar etiketinin yanına (varsa) hemen sonrasına, ayrı renklendirilebilen
## bir "net" etiketi ekler/yeniden kullanır. Aynı satırda, sıkı boşlukla durur.
func _ensure_net_label(amount_label: Label) -> Label:
	if amount_label.has_meta("net_label"):
		var existing = amount_label.get_meta("net_label")
		if is_instance_valid(existing):
			return existing
	var row := amount_label.get_parent()
	if not is_instance_valid(row):
		return null
	var net_lbl := Label.new()
	net_lbl.name = amount_label.name + "NetLabel"
	net_lbl.layout_mode = 2
	row.add_child(net_lbl)
	var idx: int = row.get_children().find(amount_label)
	if idx >= 0:
		row.move_child(net_lbl, idx + 1)
	TextOutline.apply_font_to_control(net_lbl)
	amount_label.set_meta("net_label", net_lbl)
	return net_lbl
