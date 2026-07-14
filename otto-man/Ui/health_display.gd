extends Control

const DEBUFF_X := 346
const SURVIVAL_X := 118

@onready var health_label = $BarContainer/HealthLabel
@onready var health_bar = $BarContainer/HealthBar
@onready var delayed_bar = $BarContainer/DelayedHealthBar
@onready var portrait: Control = $Portrait

var _last_health: float = 100.0
var _last_dungeon_gold: int = 0
var _last_village_level: int = 0

const DELAYED_BAR_SPEED = 2.0  # Speed at which delayed bar catches up
const FLASH_DURATION = 0.1     # Duration of flash effect
const FLASH_INTENSITY = 1.5    # Intensity of flash effect

# Color configurations
const HEALTH_COLORS = {
	"high": {
		"fill": Color(0.0, 0.8, 0.0),     # Green fill
		"border": Color(0.2, 1.0, 0.2)     # Light green border
	},
	"medium": {
		"fill": Color(0.8, 0.4, 0.0),     # Orange fill
		"border": Color(1.0, 0.6, 0.2)     # Light orange border
	},
	"low": {
		"fill": Color(0.8, 0.0, 0.0),     # Red fill
		"border": Color(1.0, 0.4, 0.4)     # Light red border
	}
}

var delayed_health: float = 100.0
var player_stats: Node
var debuff_container: VBoxContainer
var debuff_title_label: Label
var debuff_time_label: Label
var survival_container: VBoxContainer
var food_icon_label: Label
var food_bar: ProgressBar
var food_time_label: Label
var _survival_refresh_timer: float = 0.0
const SURVIVAL_REFRESH_INTERVAL: float = 0.35
const FOOD_WARNING_MINUTES: float = 720.0

func _ready() -> void:
	add_to_group("health_display")
	
	# Force visibility
	show()
	modulate.a = 1.0
	
	
	# Verify UI components
	
	if !health_label or !health_bar or !delayed_bar:
		push_error("[HealthDisplay] Missing UI components!")
		return
	
	_setup_debuff_ui()
		
	# Get PlayerStats singleton
	player_stats = get_node("/root/PlayerStats")
	
	if !player_stats:
		push_error("[HealthDisplay] PlayerStats singleton not found!")
		return
		
	# Initialize values from PlayerStats
	var current_health = player_stats.get_current_health()
	var max_health = player_stats.get_max_health()
	_last_health = current_health
	
	update_health_display(current_health, max_health)
	_sync_portrait_health_state()
	
	# Connect to PlayerStats signals
	if !player_stats.health_changed.is_connected(_on_health_changed):
		player_stats.health_changed.connect(_on_health_changed, CONNECT_DEFERRED)
	if !player_stats.stat_changed.is_connected(_on_stat_changed):
		player_stats.stat_changed.connect(_on_stat_changed, CONNECT_DEFERRED)
	if player_stats.has_signal("death_recovery_updated") and not player_stats.death_recovery_updated.is_connected(_on_death_recovery_updated):
		player_stats.death_recovery_updated.connect(_on_death_recovery_updated, CONNECT_DEFERRED)
	
	_connect_portrait_triggers()
	_refresh_debuff_ui()
	_refresh_survival_ui()
	call_deferred("_finalize_hud_layout")


func _finalize_hud_layout() -> void:
	await get_tree().process_frame
	_apply_hud_layout()
	await get_tree().process_frame
	await HudLayoutDebug.dump_health_display(self, "ready")


func _apply_hud_layout() -> void:
	var origin: Vector2 = HudLayout.HUD_ORIGIN
	HudLayout.apply_health_display(self, origin)
	_sync_sibling_stamina(origin)
	if portrait and portrait.has_method("refresh_atlases"):
		portrait.refresh_atlases()
	_relayout_village_resource_panel()


func _relayout_village_resource_panel() -> void:
	for node in get_tree().get_nodes_in_group("village_status_ui"):
		if node.has_method("_sync_resource_panel_to_content"):
			node.call_deferred("_sync_resource_panel_to_content")


func _sync_sibling_stamina(health_origin: Vector2) -> void:
	var parent_node := get_parent()
	if parent_node == null:
		return
	var stamina: Control = parent_node.get_node_or_null("StaminaBar") as Control
	var xp_bar: Control = parent_node.get_node_or_null("XpBar") as Control
	if not stamina:
		stamina = parent_node.get_node_or_null("UI/StaminaBar") as Control
	if not xp_bar:
		xp_bar = parent_node.get_node_or_null("UI/XpBar") as Control
	if stamina:
		HudLayout.apply_stamina_bar(stamina, health_origin)
	if xp_bar:
		HudLayout.apply_xp_bar(xp_bar, health_origin)


var _force_visible: bool = true  # Allow external control

func _process(delta: float) -> void:
	if _is_world_map_scene():
		_force_visible = true
		visible = true
		show()
		modulate.a = 1.0

	if !_force_visible:
		return  # Don't force visibility if disabled
	
	if !visible and _force_visible:
		show()
		modulate.a = 1.0
		return
		
	if !health_bar or !delayed_bar:
		return
		
	# Update delayed bar
	if delayed_health > health_bar.value:
		delayed_health = move_toward(delayed_health, health_bar.value, player_stats.get_max_health() * DELAYED_BAR_SPEED * delta)
		delayed_bar.value = delayed_health
	
	_survival_refresh_timer -= delta
	if _survival_refresh_timer <= 0.0:
		_survival_refresh_timer = SURVIVAL_REFRESH_INTERVAL
		_refresh_survival_ui()

func _on_health_changed(new_health: float) -> void:
	if not is_inside_tree():
		return
	if _can_flash_portrait():
		if new_health > _last_health and portrait.has_method("flash_happy"):
			portrait.flash_happy()
		elif new_health < _last_health and portrait.has_method("flash_angry"):
			portrait.flash_angry()
	_last_health = new_health
	if player_stats:
		update_health_display(new_health, player_stats.get_max_health())
		_sync_portrait_health_state()

func _on_stat_changed(stat_name: String, _old_value: float, new_value: float) -> void:
	if stat_name == "max_health" and player_stats:
		update_health_display(player_stats.get_current_health(), new_value)
		_sync_portrait_health_state()


func _sync_portrait_health_state() -> void:
	if not is_inside_tree() or portrait == null or not portrait.has_method("update_health_portrait") or player_stats == null:
		return
	if not is_instance_valid(portrait) or not portrait.is_inside_tree():
		return
	portrait.update_health_portrait(
		player_stats.get_current_health(),
		player_stats.get_max_health()
	)


func _can_flash_portrait() -> bool:
	return (
		is_inside_tree()
		and portrait != null
		and is_instance_valid(portrait)
		and portrait.is_inside_tree()
	)

func _on_death_recovery_updated(_state: Dictionary) -> void:
	_refresh_debuff_ui()

func _setup_debuff_ui() -> void:
	if debuff_container:
		return
	var root = get_node_or_null("BarContainer")
	if root == null:
		return
	debuff_container = VBoxContainer.new()
	debuff_container.name = "DebuffContainer"
	debuff_container.position = Vector2(DEBUFF_X, 0)
	debuff_container.custom_minimum_size = Vector2(170, 44)
	root.add_child(debuff_container)
	
	debuff_title_label = Label.new()
	debuff_title_label.name = "DebuffTitle"
	debuff_title_label.text = "DEBUFF: -"
	debuff_container.add_child(debuff_title_label)
	
	debuff_time_label = Label.new()
	debuff_time_label.name = "DebuffTime"
	debuff_time_label.text = "Kalan: -"
	debuff_container.add_child(debuff_time_label)
	
	debuff_container.visible = false

func _setup_survival_ui() -> void:
	if survival_container:
		return
	var root = get_node_or_null("BarContainer")
	if root == null:
		return
	survival_container = VBoxContainer.new()
	survival_container.name = "SurvivalContainer"
	survival_container.position = Vector2(SURVIVAL_X, 70)
	survival_container.custom_minimum_size = Vector2(220, 28)
	root.add_child(survival_container)

	var food_row := HBoxContainer.new()
	food_row.name = "FoodRow"
	survival_container.add_child(food_row)
	food_icon_label = Label.new()
	food_icon_label.text = "🍎"
	food_row.add_child(food_icon_label)
	food_bar = ProgressBar.new()
	food_bar.custom_minimum_size = Vector2(132, 12)
	food_bar.max_value = 100.0
	food_bar.show_percentage = false
	food_row.add_child(food_bar)
	food_time_label = Label.new()
	food_time_label.text = "--"
	food_row.add_child(food_time_label)

func _refresh_survival_ui() -> void:
	if not player_stats:
		return
	if not survival_container:
		_setup_survival_ui()
	if not survival_container or not player_stats.has_method("get_world_expedition_survival_forecast"):
		return
	if not _is_world_map_scene():
		survival_container.visible = false
		return
	var fc: Dictionary = player_stats.call("get_world_expedition_survival_forecast")
	var food_minutes: int = int(fc.get("minutes_until_food_collapse", fc.get("minutes_until_food_hp_loss", 0)))
	var food_ratio: float = clampf(float(food_minutes) / FOOD_WARNING_MINUTES, 0.0, 1.0)
	food_bar.value = food_ratio * 100.0
	food_time_label.text = _format_minutes_short(food_minutes)
	_apply_survival_bar_color(food_bar, food_ratio)
	survival_container.visible = true

func _is_world_map_scene() -> bool:
	var sm := get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("is_world_map_ui_context_active"):
		return bool(sm.is_world_map_ui_context_active())
	if sm == null:
		return false
	var path: String = String(sm.get("current_scene_path"))
	return "worldmap" in path.to_lower()

func _apply_survival_bar_color(bar: ProgressBar, ratio: float) -> void:
	if not bar:
		return
	var fill_style = bar.get_theme_stylebox("fill")
	var style: StyleBoxFlat = null
	if fill_style is StyleBoxFlat:
		style = (fill_style as StyleBoxFlat).duplicate()
	else:
		style = StyleBoxFlat.new()
	style.bg_color = Color(1.0 - ratio, ratio, 0.0, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(1, 1, 1, 0.45)
	bar.add_theme_stylebox_override("fill", style)

func _format_minutes_short(minutes_left: int) -> String:
	var m: int = maxi(0, minutes_left)
	var h: int = m / 60
	var mm: int = m % 60
	return "%02d:%02d" % [h, mm]

func _refresh_debuff_ui() -> void:
	if not player_stats or not debuff_container or not debuff_title_label or not debuff_time_label:
		return
	if not player_stats.has_method("get_death_recovery_state"):
		debuff_container.visible = false
		return
	var state: Dictionary = player_stats.get_death_recovery_state()
	var active: Array = state.get("active_debuffs", [])
	if active.is_empty():
		debuff_container.visible = false
		return
	var names: PackedStringArray = []
	var durations: PackedStringArray = []
	for deb in active:
		var dn: String = String(deb.get("name", "Yaralanma"))
		var mins_left: int = int(deb.get("minutes_left", 0))
		names.append(dn)
		durations.append("%s: %s" % [dn, _format_days_left(mins_left)])
	debuff_title_label.text = "DEBUFF: " + ", ".join(names)
	debuff_time_label.text = "Kalan: " + " | ".join(durations)
	debuff_container.visible = true

func _format_days_left(minutes_left: int) -> String:
	var tm := get_node_or_null("/root/TimeManager")
	var minutes_per_day: int = 1440
	if tm and "MINUTES_PER_HOUR" in tm and "HOURS_PER_DAY" in tm:
		minutes_per_day = int(tm.MINUTES_PER_HOUR) * int(tm.HOURS_PER_DAY)
	var days_left: int = int(ceil(float(maxi(0, minutes_left)) / float(maxi(1, minutes_per_day))))
	return "%d gun" % days_left

func update_health_display(current_health: float, max_health: float) -> void:
	
	if !health_label or !health_bar or !delayed_bar:
		push_error("[HealthDisplay] Missing UI components during update!")
		return
		
	# Update label
	health_label.text = "%d/%d" % [current_health, max_health]
	
	# Update progress bars
	health_bar.max_value = max_health
	delayed_bar.max_value = max_health
	health_bar.value = current_health
	
	# Handle delayed bar updates
	if current_health < delayed_bar.value:
		delayed_health = delayed_bar.value
		modulate = Color(FLASH_INTENSITY, 1, 1)
		create_tween().tween_property(self, "modulate", Color.WHITE, FLASH_DURATION)
	elif current_health > delayed_bar.value:
		delayed_health = current_health
		delayed_bar.value = current_health
		modulate = Color(1, FLASH_INTENSITY, 1)
		create_tween().tween_property(self, "modulate", Color.WHITE, FLASH_DURATION)
	
	# Update bar colors based on health percentage
	var health_percent = current_health / max_health
	var bar_style = health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	
	var colors
	if health_percent <= 0.2:
		colors = HEALTH_COLORS.low
	elif health_percent <= 0.5:
		colors = HEALTH_COLORS.medium
	else:
		colors = HEALTH_COLORS.high
	
	# Update both fill and border colors
	if bar_style:
		bar_style.bg_color = colors.fill
		bar_style.border_color = colors.border


func _connect_portrait_triggers() -> void:
	var gpd := get_node_or_null("/root/GlobalPlayerData")
	if gpd and gpd.has_signal("dungeon_gold_changed"):
		if "dungeon_gold" in gpd:
			_last_dungeon_gold = int(gpd.get("dungeon_gold"))
		if not gpd.dungeon_gold_changed.is_connected(_on_dungeon_gold_changed):
			gpd.dungeon_gold_changed.connect(_on_dungeon_gold_changed, CONNECT_DEFERRED)
	
	var gm := get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("village_level_updated"):
		if gm.has_method("get_village_level"):
			_last_village_level = int(gm.get_village_level())
		elif "village_data" in gm and gm.village_data is Dictionary:
			_last_village_level = int(gm.village_data.get("level", 0))
		if not gm.village_level_updated.is_connected(_on_village_level_updated):
			gm.village_level_updated.connect(_on_village_level_updated, CONNECT_DEFERRED)


func _on_dungeon_gold_changed(new_amount: int) -> void:
	if new_amount > _last_dungeon_gold and _can_flash_portrait() and portrait.has_method("flash_coin"):
		portrait.flash_coin()
	_last_dungeon_gold = new_amount


func _on_village_level_updated(new_level: int) -> void:
	if new_level > _last_village_level and _can_flash_portrait() and portrait.has_method("flash_happy"):
		portrait.flash_happy()
	_last_village_level = new_level
