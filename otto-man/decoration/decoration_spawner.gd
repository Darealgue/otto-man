extends Node2D
class_name DecorationSpawner

# Dekorasyon spawner konfigürasyonu
@export var decoration_type: DecorationConfig.DecorationType = DecorationConfig.DecorationType.GOLD
@export var spawn_location: DecorationConfig.SpawnLocation = DecorationConfig.SpawnLocation.FLOOR_CENTER
@export var auto_spawn: bool = true
@export var spawn_chance: float = 0.8
@export var current_level: int = 1
@export var chunk_type: String = "basic"

# Opsiyonel konfigürasyon
@export var force_decoration_type: String = ""  # Eğer set edilirse, sadece bu tür dekorasyon spawn eder
@export var spawn_offset: Vector2 = Vector2.ZERO

# Internal variables
var _spawned_decoration: Node2D = null
var _decoration_config: DecorationConfig
var _is_active: bool = false

# Visual marker for editor
var spawn_marker: Node2D

# Debug toggle for this spawner (console prints only; no on-screen labels)
const DEBUG_DECOR: bool = false
const DEBUG_LOOT: bool = false

# Loot art paths
const COIN_SMALL_PATH: String = "res://assets/objects/dungeon/coin_small.png"
const POUCH_PATH: String = "res://assets/objects/dungeon/pouch.png"  # 2 frames: 0=air, 1=ground
const POT_SHEET_PATH: String = "res://assets/objects/dungeon/pot1.png"  # H-frames: first idle, last broken

func _ready() -> void:
	# DecorationConfig'i yükle
	_decoration_config = DecorationConfig.new()
	
	# Spawn marker'ı gizle (oyun içinde)
	spawn_marker = get_node_or_null("SpawnMarker")
	if spawn_marker:
		spawn_marker.visible = false
	
	if DEBUG_DECOR:
		print("[DecorationSpawner] Initialized - Type: %s, Location: %s" % [
		DecorationConfig.DecorationType.keys()[decoration_type], 
		DecorationConfig.SpawnLocation.keys()[spawn_location]
	])

func activate() -> bool:
	_is_active = true
	if auto_spawn:
		if randf() <= spawn_chance:
			_spawn_decoration()
			if DEBUG_DECOR:
				print("[DecorationSpawner] Activated and spawned")
			return true
		else:
			if DEBUG_DECOR:
				print("[DecorationSpawner] Activated but failed chance roll")
			_is_active = false
			return false
	if DEBUG_DECOR:
		print("[DecorationSpawner] Activated")
	return true

func deactivate() -> void:
	_is_active = false
	clear_decoration()
	if DEBUG_DECOR:
		print("[DecorationSpawner] Deactivated")

func _spawn_decoration() -> bool:
	# Bu lokasyon için uygun dekorasyonları al
	var available_decorations = _decoration_config.get_decorations_for_location(decoration_type, spawn_location)
	
	if available_decorations.is_empty():
		if DEBUG_DECOR:
			print("[DecorationSpawner] No decorations available for type: %s, location: %s" % [
			DecorationConfig.DecorationType.keys()[decoration_type], 
			DecorationConfig.SpawnLocation.keys()[spawn_location]
		])
		return false
	
	# Dekorasyon türünü seç
	var decoration_name: String
	if not force_decoration_type.is_empty() and force_decoration_type in available_decorations:
		decoration_name = force_decoration_type
	else:
		decoration_name = _decoration_config.select_random_decoration(available_decorations, decoration_type)
	
	if decoration_name.is_empty():
		if DEBUG_DECOR:
			print("[DecorationSpawner] Failed to select decoration")
		return false
	
	# Dekorasyon instance'ını oluştur
	var decoration_instance = create_decoration_instance(decoration_name, decoration_type)
	if not decoration_instance:
		if DEBUG_DECOR:
			print("[DecorationSpawner] Failed to create decoration instance: %s" % decoration_name)
		last_spawned_decoration = null
		return false
	
	# Store the spawned decoration for level_generator to access
	last_spawned_decoration = decoration_instance
	
	# Sahneye ekle
	get_parent().add_child(decoration_instance)
	
	# Konumunu ayarla
	var spawn_pos = global_position + spawn_offset
	decoration_instance.global_position = spawn_pos
	
	# Gate, pipe ve banner dekorları için kapı kontrolü yap (GERÇEK spawn pozisyonu ile)
	if decoration_name in ["gate1", "gate2", "pipe1", "pipe2", "banner1"]:
		var is_too_close = false
		if decoration_name == "banner1":
			is_too_close = _is_near_door_banner(spawn_pos)
		else:
			is_too_close = _is_near_door(spawn_pos)
		
		if is_too_close:
			decoration_instance.queue_free()
			last_spawned_decoration = null
			_spawned_decoration = null
			return false
	
	# Referansı sakla
	_spawned_decoration = decoration_instance
	_is_active = true
	
	if DEBUG_DECOR:
		print("[DecorationSpawner] Spawned %s at position %s" % [decoration_name, spawn_pos])
	return true

func create_decoration_instance(decoration_name: String, decoration_type: DecorationConfig.DecorationType) -> Node2D:
	if DEBUG_DECOR:
		print("DECOR SPAWN DENEMESİ: " + decoration_name + " - " + str(decoration_type))
	if not _decoration_config:
		_decoration_config = DecorationConfig.new()
	var decoration_data = _decoration_config.get_decorations_for_type(decoration_type)[decoration_name]
	# If a scene is provided for this decor, instantiate that scene instead of building a Node2D+Sprite
	var scene_paths_array: Array[String] = []
	var scene_paths_var = decoration_data.get("scene_paths", null)
	if typeof(scene_paths_var) == TYPE_ARRAY:
		for v in (scene_paths_var as Array):
			scene_paths_array.append(String(v))
	elif typeof(scene_paths_var) == TYPE_PACKED_STRING_ARRAY:
		for v in (scene_paths_var as PackedStringArray):
			scene_paths_array.append(v)
	if scene_paths_array.size() > 0:
		var scene_path: String = scene_paths_array[randi() % scene_paths_array.size()]
		if ResourceLoader.exists(scene_path):
			var packed: PackedScene = load(scene_path) as PackedScene
			if packed:
				var inst: Node2D = packed.instantiate() as Node2D
				if inst:
					inst.name = decoration_name
					# Ensure a Sprite or visual child uses bottom-center anchoring so ground snap works
					var spr_try: Sprite2D = inst.get_node_or_null("Sprite") as Sprite2D
					if spr_try:
						# Compute delta of sprite center before changing anchor, so we can keep collisions aligned
						var was_centered := spr_try.centered
						var h_px := 0
						if spr_try.texture:
							if spr_try.texture is AtlasTexture:
								h_px = int((spr_try.texture as AtlasTexture).region.size.y)
							else:
								h_px = spr_try.texture.get_height()
						if spr_try.vframes > 1:
							h_px = int(floor(float(h_px) / float(max(1, spr_try.vframes))))
						# Compute old center Y: if centered=false, center is position.y + h/2; if centered=true, center is position.y
						var old_center_y := (spr_try.position.y + (h_px * 0.5)) if not was_centered else spr_try.position.y
						_apply_bottom_center_to_sprite(spr_try)
						# New sprite center after bottom-center align
						var new_center_y := spr_try.position.y + h_px * 0.5
						var delta_center_y := new_center_y - old_center_y
						# Shift all CollisionObject2D children by -delta to preserve authored alignment
						if abs(delta_center_y) > 0.01:
							var queue: Array[Node] = [inst]
							while queue.size() > 0:
								var nn: Node = queue.pop_back()
								for ch in nn.get_children():
									queue.append(ch)
									if ch is CollisionObject2D:
										var co2 := ch as CollisionObject2D
										# Move physics bodies by the same delta as sprite center so alignment is preserved
										co2.position.y += delta_center_y
					# Optional random horizontal flip including collisions for variety
					if randi() % 2 == 0:
						# Flip sprite visually (we're using bottom-center origin, so flip_h is enough)
						if spr_try:
							spr_try.flip_h = !spr_try.flip_h
						# Mirror CollisionShape2D horizontally around the instance origin
						var q: Array[Node] = [inst]
						while q.size() > 0:
							var n2: Node = q.pop_back()
							for ch2 in n2.get_children():
								q.append(ch2)
								if ch2 is CollisionShape2D:
									var cs := ch2 as CollisionShape2D
									cs.scale.x = -abs(cs.scale.x)
									# Also mirror local X position
									cs.position.x = -cs.position.x
					# Post-place fixup
					inst.set_meta("decoration_type", DecorationConfig.DecorationType.keys()[decoration_type].to_lower())
					call_deferred("_post_place_fixup", inst)
					# Auto z-index if top-level sprite exists
					var z_auto := _decoration_config.get_z_index_for_decoration(decoration_name)
					inst.z_index = z_auto
					# Ensure platform collisions are on the PLATFORM layer so the player can stand on them
					var stack: Array[Node] = []
					stack.append(inst)
					while stack.size() > 0:
						var n: Node = stack.pop_back()
						for ch in n.get_children():
							stack.append(ch)
							if ch is CollisionObject2D:
								var co := ch as CollisionObject2D
								# Ensure the platform is detectable by the player and world
								co.collision_layer = co.collision_layer | CollisionLayers.PLATFORM | CollisionLayers.WORLD
								co.collision_mask = co.collision_mask | CollisionLayers.PLAYER
								# Keep other existing masks untouched
					return inst

	# Fallback: build Node2D with Sprite
	var decoration_node = Node2D.new()
	decoration_node.name = decoration_name
	var sprite = Sprite2D.new()
	sprite.name = "Sprite"
	sprite.z_index = _decoration_config.get_z_index_for_decoration(decoration_name)
	sprite.modulate = Color(1, 1, 1, 1)
	var sprites = decoration_data.get("sprites", [])
	var sprite_path = sprites[randi() % sprites.size()] if sprites.size() > 0 else ""
	var texture = null
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		texture = load(sprite_path) as Texture2D
	if not texture:
		var image = Image.create(16, 16, false, Image.FORMAT_RGB8)
		match decoration_type:
			DecorationConfig.DecorationType.GOLD:
				image.fill(Color.YELLOW)
			DecorationConfig.DecorationType.PLATFORM:
				image.fill(Color.GRAY)
			DecorationConfig.DecorationType.BREAKABLE:
				image.fill(Color(0.4, 0.26, 0.13))
			DecorationConfig.DecorationType.BACKGROUND:
				image.fill(Color(0.41, 0.41, 0.41, 1.0))
			_:
				image.fill(Color.RED)
		var imgtex = ImageTexture.create_from_image(image)
		texture = imgtex
	sprite.texture = texture
	_apply_bottom_center_to_sprite(sprite)
	decoration_node.add_child(sprite)
	decoration_node.set_meta("decoration_type", DecorationConfig.DecorationType.keys()[decoration_type].to_lower())
	call_deferred("_post_place_fixup", decoration_node)
	# Tip özel ayarları
	match decoration_type:
		DecorationConfig.DecorationType.BACKGROUND:
			_setup_background_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.GOLD:
			_setup_gold_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.PLATFORM:
			_setup_platform_decoration(decoration_node, decoration_data)
		DecorationConfig.DecorationType.BREAKABLE:
			_setup_breakable_decoration(decoration_node, decoration_data)
	return decoration_node

func _setup_background_decoration(node: Node2D, data: Dictionary) -> void:
	# Sadece görsel, collision yok
	node.set_meta("decoration_type", "background")
	
	# Z-index otomatik olarak create_decoration_instance'da ayarlandı
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		node.z_index = sprite.z_index
		# Random flip for visual variety
		if randi() % 2 == 0:
			sprite.flip_h = !sprite.flip_h
		# For floor-based decors, align sprite bottom to node origin so it sits on the floor
		if node.name == "box2" or node.name == "gate1" or node.name == "gate2" or node.name == "pipe1" or node.name == "pipe2" or node.name == "banner1" or node.name == "sculpture1" or String(node.get_meta("decor_name", "")) in ["box2", "gate1", "gate2", "pipe1", "pipe2", "banner1", "sculpture1"]:
			sprite.centered = false
			var h := 0
			if sprite.texture:
				if sprite.texture is Texture2D:
					h = (sprite.texture as Texture2D).get_height()
			# Seat 5px lower for better grounding
			sprite.position = Vector2(0, -h + 5)
		# Gates, Pipes, Banners, Sculptures: z-index otomatik olarak ayarlandı
	# Group for overlap checks
	node.add_to_group("background_decor")

# Altın için Area2D oluşturur ve toplama sinyalini bağlar
func _setup_gold_decoration(node: Node2D, data: Dictionary) -> void:
	node.set_meta("decoration_type", "gold")
	var gold_value: int = data.get("gold_value", 1)
	node.set_meta("gold_value", gold_value)
	
	var area: Area2D = Area2D.new()
	area.name = "CollectArea"
	# Pooled loot ile aynı: katman NONE, mask ALL; filtreyi handler yapar
	area.collision_layer = CollisionLayers.NONE
	area.collision_mask = CollisionLayers.ALL
	area.monitoring = true
	area.monitorable = true
	var col: CollisionShape2D = CollisionShape2D.new()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = 22.0
	col.shape = shape
	# Pooled loot ile aynı merkez hizası
	col.position = Vector2.ZERO
	area.add_child(col)
	node.add_child(area)

	# Görseli değere göre ayarla (coin vs pouch)
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		_apply_gold_visual(sprite, gold_value, true)
		_apply_bottom_center_to_sprite(sprite)
		# Flip occasionally
		if randi() % 3 == 0:
			sprite.flip_h = !sprite.flip_h
	
	# Sinyaller: hem body hem area ile toplanmayı destekle
	area.body_entered.connect(_on_gold_collected.bind(node, gold_value))
	area.area_entered.connect(_on_gold_area_entered.bind(node, gold_value))
	# Reuse pooled pickup logic signature
	
	# Z-index otomatik olarak create_decoration_instance'da ayarlandı
	if sprite:
		node.z_index = sprite.z_index
	# Pickup alanı zaten merkezde; pooled loot ile aynı
	if DEBUG_DECOR:
		print("[DecorationSpawner] GOLD ready at ", node.global_position, " value=", gold_value)

# Platform ve kırılabilir için dikdörtgen şekil oluşturucu
func _create_rect_shape(size: Vector2) -> RectangleShape2D:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = size
	return shape

# Statik platform
func _setup_platform_decoration(node: Node2D, data: Dictionary) -> void:
	node.set_meta("decoration_type", "platform")
	var size: Vector2 = data.get("collision_size", Vector2(64, 32))
	
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "PlatformBody"
	# Varsayılan katmanlar genelde yeterli; player ile çarpışması için layer 1'de kalsın
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = _create_rect_shape(size)
	# Align rectangle so its bottom sits at node origin and it's centered horizontally
	col.position = Vector2(0, -size.y * 0.5)
	body.add_child(col)
	node.add_child(body)
	
	# Z-index otomatik olarak create_decoration_instance'da ayarlandı
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		node.z_index = sprite.z_index

# Kırılabilir obje
func _setup_breakable_decoration(node: Node2D, data: Dictionary) -> void:
	node.set_meta("decoration_type", "breakable")
	node.set_meta("hp", data.get("hp", 1))
	node.set_meta("gold_drop", data.get("gold_drop", {}))
	var size: Vector2 = data.get("collision_size", Vector2(48, 48))
	# Reset manual position offset; bottom-center anchoring handles grounding now
	node.set_meta("position_offset_px", Vector2.ZERO)
	
	# Fiziksel gövde (oyuncuyu engeller)
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "BreakableBody"
	# Kullanıcı isteği: kırılabilir objenin collision'ı olmasın (sadece vurulabilir olsun)
	body.collision_layer = 0
	body.collision_mask = 0
	var body_col: CollisionShape2D = CollisionShape2D.new()
	body_col.shape = _create_rect_shape(size)
	body_col.disabled = true
	body.add_child(body_col)
	node.add_child(body)
	
	# Hasar algılama için Area2D (hitbox'larla çakışır)
	var hurt: Area2D = Area2D.new()
	hurt.name = "BreakableHurtbox"
	# Player hitbox'ı Layer 5 (16) ve Mask 6 (32) kullanıyor.
	# Burada kırılabilir hurtbox'ı Layer 6 (32), Mask 5 (16) yapıyoruz ki iki yönlü temas oluşsun.
	hurt.collision_layer = CollisionLayers.ENEMY_HURTBOX
	# Detect everything (özellikle player hitbox katmanı 5=16 dahil)
	hurt.collision_mask = 0
	hurt.collision_mask = CollisionLayers.ALL
	hurt.monitoring = true
	hurt.monitorable = true
	# Hem area_entered hem body_entered bağla (bazı saldırılar body olabilir)
	var hurt_col: CollisionShape2D = CollisionShape2D.new()
	hurt_col.shape = _create_rect_shape(size)
	# Same bottom-center alignment for hurtbox
	hurt_col.position = Vector2(0, -size.y * 0.5)
	hurt.add_child(hurt_col)
	node.add_child(hurt)
	
	# Sinyal: önce node'u bağlayıp sonra sinyalin area parametresini alırız
	hurt.area_entered.connect(_on_breakable_area_entered.bind(node))
	hurt.body_entered.connect(_on_breakable_body_entered.bind(node))
	
	# Z-index otomatik olarak create_decoration_instance'da ayarlandı
	var sprite: Sprite2D = node.get_node_or_null("Sprite") as Sprite2D
	if sprite:
		node.z_index = sprite.z_index
	print("[DecorationSpawner] BREAKABLE ready HP=", node.get_meta("hp", 0), " at ", node.global_position)

	# Pot animasyonlarını hazırla (varsa)
	_setup_pot_animation(node)

func _is_player_node(n: Node) -> bool:
	if n == null:
		return false
	# Group tolerant check ("player" anywhere in the group names)
	for g in n.get_groups():
		if String(g).to_lower() == "player":
			return true
	# Parent check for inner areas under the player
	if n.get_parent() != null:
		for g2 in n.get_parent().get_groups():
			if String(g2).to_lower() == "player":
				return true
	if n is CollisionObject2D:
		var lay := (n as CollisionObject2D).collision_layer
		if (lay & CollisionLayers.PLAYER) != 0:
			return true
	return false

func _on_gold_collected(body: Node2D, node: Node2D, gold_value: int) -> void:
	if _is_player_node(body):
		print("[DecorationSpawner] Gold collected: %d at %s" % [gold_value, str(node.global_position)])
		
		# Check if we're in dungeon/forest - add to dungeon_gold, not global gold
		var scene_manager = get_node_or_null("/root/SceneManager")
		var is_combat_scene = false
		if scene_manager:
			var current_scene = scene_manager.get("current_scene_path")
			if current_scene:
				var dungeon_scene = scene_manager.get("DUNGEON_SCENE")
				var forest_scene = scene_manager.get("FOREST_SCENE")
				is_combat_scene = (current_scene == dungeon_scene or current_scene == forest_scene)
		
		# Add to dungeon gold if in combat scene, otherwise to global gold
		if GlobalPlayerData:
			if is_combat_scene:
				GlobalPlayerData.add_dungeon_gold(gold_value)
			else:
				GlobalPlayerData.add_gold(gold_value)
		
		# Altın toplama efekti
		_create_collection_effect(node.global_position)
		
		# Node'u sil
		node.queue_free()
		_spawned_decoration = null

func _on_gold_area_entered(area: Area2D, node: Node2D, gold_value: int) -> void:
	# Player'ın altındaki etkileşim alanı veya hurtbox gibi alanlarla da toplanabilsin
	if not area:
		return
	var owner: Node = area.get_parent()
	if owner and _is_player_node(owner):
		_on_gold_collected(owner, node, gold_value)

# Hitbox çarpınca kırılabilir objeye hasar uygula
func _on_breakable_area_entered(area: Area2D, node: Node2D) -> void:
	# Hitbox grubu zorunlu değil; has_method yeterli
	if not area:
		return
	# Yalnızca saldırı hitbox'larını kabul et: get_damage var ve etkin ise
	if not area.has_method("get_damage"):
		return
	if area.has_method("is_enabled") and not area.is_enabled():
		return
	var damage: int = int(area.get_damage())
	print("[DecorationSpawner] BREAKABLE hit by ", area.name, " damage=", damage)
	_apply_breakable_damage(node, damage)

func _on_breakable_body_entered(body: Node2D, node: Node2D) -> void:
	# Eğer vurma body üzerinden gelirse ve body bir hitbox parent'ıysa hasar topla
	if not body:
		return
	if not body.has_method("get_damage"):
		return
	if body.has_method("is_enabled") and not body.is_enabled():
		return
	var damage: int = int(body.get_damage())
	print("[DecorationSpawner] BREAKABLE body hit by ", body.name, " damage=", damage)
	_apply_breakable_damage(node, damage)

# --- Breakable damage & break helpers (local, manager bağımsız) ---
func _apply_breakable_damage(node: Node2D, damage: int) -> void:
	if not node:
		return
	if node.get_meta("broken", false):
		return
	var hp: int = int(node.get_meta("hp", 1))
	hp -= max(1, damage)
	node.set_meta("hp", hp)
	if hp <= 0:
		node.set_meta("broken", true)
		_break_breakable(node)

func _break_breakable(node: Node2D) -> void:
	if not node:
		return
	# Önce artık hasar almasın
	var hurt: Area2D = node.get_node_or_null("BreakableHurtbox")
	if hurt and hurt is Area2D:
		(hurt as Area2D).monitoring = false

	# Kırılma animasyonu varsa oynat
	_play_pot_break_animation(node)

	# Havuz tabanlı drop
	var cfg: GoldDropConfig = GoldDropConfig.new()
	var total: int = 0
	
	# Önce gold_value meta'sını kontrol et (eski sistem için)
	if node.has_meta("gold_value"):
		total = int(node.get_meta("gold_value", 0))
	
	# Eğer gold_value yoksa veya 0 ise, gold_drop meta'sını kullan
	if total <= 0:
		var gold_drop: Dictionary = node.get_meta("gold_drop", {})
		if gold_drop.has("min") and gold_drop.has("max"):
			total = cfg.pick_total_from_range(gold_drop["min"], gold_drop["max"])
		else:
			# Fallback: default değerler
			total = cfg.pick_total_from_range(cfg.total_value_min, cfg.total_value_max)
	
	var parts: Array[int] = cfg.compose_items_for_total(total)
	var loot_pool: Node = get_node_or_null("/root/Loots")
	if not loot_pool:
		print("[DecorationSpawner] ERROR: Loots autoload not found! Cannot spawn loot.")
		return
	if DEBUG_DECOR:
		print("[DecorationSpawner] Breaking breakable, total gold: ", total, " parts: ", parts)
	print("[DecorationSpawner] Spawning ", parts.size(), " loot items from breakable")
	for v in parts:
		var is_pouch: bool = v > 5
		var body: RigidBody2D = null
		if loot_pool:
			body = loot_pool.call("acquire", is_pouch)
		if body == null:
			print("[DecorationSpawner] WARNING: Failed to acquire loot body for value ", v)
			continue
		if not body:
			print("[DecorationSpawner] WARNING: Acquired body is null for value ", v)
			continue
		print("[DecorationSpawner] Acquired loot body for value ", v, " at position ", body.global_position, " visible=", body.visible)
		body.set_meta("gold_value", v)
		body.set_meta("collected", false)  # Flag to prevent double collection
		var spr: Sprite2D = body.get_node_or_null("Sprite") as Sprite2D
		_apply_gold_visual(spr, v, false)
		# Loot visuals should align to physics/area center (RigidBody origin)
		if spr:
			spr.centered = true
			spr.position = Vector2.ZERO
		var collect: Area2D = body.get_node_or_null("CollectArea") as Area2D
		if collect == null:
			# Fallback: first Area2D child
			for child in body.get_children():
				if child is Area2D:
					collect = child
					break
		# Reuse-safe: remove previous connections from pooled node
		if collect:
			_disconnect_all_signals(collect, "body_entered")
			_disconnect_all_signals(collect, "area_entered")
			collect.body_entered.connect(_on_dropped_gold_collected.bind(body))
			collect.area_entered.connect(_on_dropped_gold_area_entered.bind(body))
			# Delay monitoring to prevent instant pickup from initial overlaps
			collect.monitoring = false
			collect.monitorable = true
			if collect is CollisionObject2D:
				(collect as CollisionObject2D).collision_layer = CollisionLayers.NONE
				(collect as CollisionObject2D).collision_mask = CollisionLayers.ALL
			if DEBUG_LOOT:
				print("[LootDebug] Collect area ready monitoring=", collect.monitoring,
					" layer=", (collect as CollisionObject2D).collision_layer,
					" mask=", (collect as CollisionObject2D).collision_mask)
		else:
			if DEBUG_DECOR:
				print("[DecorationSpawner] WARNING: Loot body missing Area2D child")
		_disconnect_all_signals(body, "body_entered")
		_disconnect_all_signals(body, "body_exited")
		if spr:
			# Ensure the rigidbody reports contacts
			body.contact_monitor = true
			body.max_contacts_reported = 4
			body.body_entered.connect(_on_dropped_gold_body_entered.bind(spr, body))
			body.body_exited.connect(_on_dropped_gold_body_exited.bind(spr, body))
		# Ensure non-blocking vs player; only collide with world/platform
		body.collision_layer = CollisionLayers.ITEM
		body.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
		# Spawn slightly above breakable to avoid spawning inside walls
		var spawn_offset = Vector2(randf_range(-10, 10), randf_range(-20, -10))
		body.global_position = node.global_position + spawn_offset
		get_tree().current_scene.add_child(body)
		# Launch: differentiate coin vs pouch behavior
		var launch: Vector2
		if v <= 5:
			# Coins: more lively scatter with higher bounce feel
			launch = Vector2(randf_range(-180.0, 180.0), randf_range(-280.0, -160.0))
			body.angular_damp = 0.8
		else:
			# Pouches: subdued throw, land quickly
			launch = Vector2(randf_range(-90.0, 90.0), randf_range(-200.0, -140.0))
			body.angular_damp = 3.0
		body.freeze = false
		body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		body.apply_impulse(launch)
		body.z_index = (node.z_index + 2) if node else 2
		# Enable collection after a brief moment so they can visibly scatter
		if collect:
			var enable_timer := Timer.new()
			enable_timer.one_shot = true
			enable_timer.wait_time = (0.15 if v <= 5 else 0.25)
			body.add_child(enable_timer)
			enable_timer.timeout.connect(func():
				if is_instance_valid(collect) and is_instance_valid(body):
					collect.monitoring = true
					# Double-check that monitoring is actually enabled
					if not collect.monitoring:
						print("[DecorationSpawner] WARNING: Failed to enable collection monitoring for loot at ", body.global_position)
			)
			enable_timer.start()
		# Sleep & despawn scheduling via pool helpers
		if loot_pool:
			loot_pool.call("schedule_ground_sleep", body, cfg.ground_sleep_after_s)
			loot_pool.call("schedule_despawn", body, cfg.despawn_seconds)
			# Don't enforce cap immediately - let despawn timer handle cleanup
			# Cap enforcement was causing newly spawned loot to disappear
			if DEBUG_LOOT:
				var dbg := Timer.new()
				dbg.one_shot = true
				dbg.wait_time = 0.25
				body.add_child(dbg)
				dbg.timeout.connect(func():
					if not is_instance_valid(body):
						return
					var area := (body.get_node_or_null("CollectArea") as Area2D)
					if area == null:
						for c in body.get_children():
							if c is Area2D:
								area = c
								break
					var bcnt := (area.get_overlapping_bodies().size() if area else -1)
					var acnt := (area.get_overlapping_areas().size() if area else -1)
					var player := get_tree().get_first_node_in_group("player")
					var dist := (body.global_position.distance_to(player.global_position) if player else -1.0)
					print("[LootDebug] +0.25s ", body.name, " pos=", body.global_position, " lv=", body.linear_velocity,
						" freeze=", body.freeze, " sleeping=", body.sleeping,
						" overlaps bodies=", bcnt, " areas=", acnt, " dist_to_player=", dist)
				)
				dbg.start()
	# Pot sahnede kalsın; kırık halde görünmeye devam etsin


# Helper: disconnect all connections for a given signal name on an Object
func _disconnect_all_signals(obj: Object, signal_name: String) -> void:
	if not obj:
		return
	# Get list of connections and disconnect each
	var conns := obj.get_signal_connection_list(signal_name)
	for c in conns:
		# Each item is a Dictionary with keys: "target", "callable", etc.
		# Prefer callable if present (Godot 4)
		if c.has("callable") and c.callable is Callable:
			obj.disconnect(signal_name, c.callable)
		elif c.has("target") and c.has("method"):
			obj.disconnect(signal_name, Callable(c.target, c.method))

# Zemine hizalama (duvar/boşluk yerine gerçek zemin yüksekliği)
func _snap_node_to_ground(node: Node2D) -> void:
	if not node:
		return
	var ground_pos: Vector2 = _query_ground_position(node.global_position)
	if ground_pos != node.global_position:
		node.global_position = ground_pos + Vector2(0, -6) # hafif üstte dursun

# Raycast ile alttaki zemin noktasını bulur
func _query_ground_position(pos: Vector2) -> Vector2:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var from: Vector2 = pos + Vector2(0, -200)
	var to: Vector2 = pos + Vector2(0, 1000)
	var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	# Layer 1 (world) ve Layer 10 (platform)
	params.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var res: Dictionary = space.intersect_ray(params)
	if res and res.has("position"):
		return res.position
	return pos

# --- Pot animation helpers ---
func _get_image_from_texture(tex: Texture2D, fallback_path: String) -> Image:
	# Try to extract image data from the texture; if not possible, load from disk
	if tex and tex is ImageTexture:
		var it: ImageTexture = tex as ImageTexture
		var img: Image = it.get_image()
		if img:
			return img
	# Try CompressedTexture2D in 4.x (godot imports PNGs as compressed textures)
	if tex and tex.has_method("get_image"):
		var img2 = tex.call("get_image")
		if img2:
			return img2
	var img: Image = Image.new()
	var err: Error = img.load(fallback_path)
	if err == OK:
		return img
	return null

func _slice_regions_by_alpha(tex: Texture2D, src_path: String, expected_count: int) -> Array[Rect2]:
	var regions: Array[Rect2] = []
	var img: Image = _get_image_from_texture(tex, src_path)
	if img == null:
		return regions
	var w: int = img.get_width()
	var h: int = img.get_height()
	if w <= 0 or h <= 0:
		return regions
	var occupied: Array[bool] = []
	occupied.resize(w)
	var alpha_threshold: float = 0.01
	# Mark columns that have any visible pixel
	for x in range(w):
		var col_has_alpha: bool = false
		for y in range(h):
			var a: float = img.get_pixel(x, y).a
			if a > alpha_threshold:
				col_has_alpha = true
				break
		occupied[x] = col_has_alpha
	# Merge very small gaps as gutters (1-2px)
	var gap_merge_threshold: int = 2
	var x: int = 0
	while x < w:
		# Skip empty columns until content
		while x < w and not occupied[x]:
			x += 1
		if x >= w:
			break
		var start_x: int = x
		# Advance through content and tiny gaps
		while x < w:
			if occupied[x]:
				x += 1
				continue
			# Found a gap; see how wide
			var gap_start: int = x
			while x < w and not occupied[x]:
				x += 1
			var gap_width: int = x - gap_start
			if gap_width <= gap_merge_threshold:
				# Treat as gutter: continue the same region
				continue
			else:
				# Large gap: close region at gap start
				var end_x: int = gap_start - 1
				regions.append(Rect2(start_x, 0, max(1, end_x - start_x + 1), h))
				start_x = x
		# Close last region
		if start_x < w:
			regions.append(Rect2(start_x, 0, max(1, w - start_x), h))
	# If we got exactly expected_count, return
	if regions.size() == expected_count:
		return regions
	# Fallback: uniform slicing into expected_count regions
	var fallback: Array[Rect2] = []
	var fw: int = int(floor(float(w) / float(expected_count)))
	if fw <= 0:
		return regions # give up, return whatever we found
	var cursor: int = 0
	for i in range(expected_count):
		var width: int = fw if i < expected_count - 1 else (w - cursor)
		fallback.append(Rect2(cursor, 0, width, h))
		cursor += fw
	return fallback
func _setup_pot_animation(node: Node2D) -> void:
	var old_sprite: Node = node.get_node_or_null("Sprite")
	var tex: Texture2D = null
	if ResourceLoader.exists(POT_SHEET_PATH):
		tex = load(POT_SHEET_PATH) as Texture2D
	if tex == null:
		return
	# Create AnimatedSprite2D
	var anim: AnimatedSprite2D = AnimatedSprite2D.new()
	anim.name = "Anim"
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 0.0)
	frames.add_animation("break")
	frames.set_animation_loop("break", false)
	frames.set_animation_speed("break", 16.0)
	frames.add_animation("broken")
	frames.set_animation_loop("broken", false)
	frames.set_animation_speed("broken", 0.0)
	# Slice robustly by scanning alpha columns so trimming or uneven gutters don't break frames
	var expected_count: int = 5
	var regions: Array[Rect2] = _slice_regions_by_alpha(tex, POT_SHEET_PATH, expected_count)
	var count: int = regions.size()
	if count < 2:
		count = expected_count
		var w: int = tex.get_width()
		var h: int = tex.get_height()
		var fw: int = int(floor(float(w) / float(count)))
		for i in range(count):
			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, (fw if i < count - 1 else (w - i * fw)), h)
			at.filter_clip = true
			if i == 0:
				frames.add_frame("idle", at)
			frames.add_frame("break", at)
			if i == count - 1:
				frames.add_frame("broken", at)
	else:
		for i in range(count):
			var at: AtlasTexture = AtlasTexture.new()
			at.atlas = tex
			at.region = regions[i]
			at.filter_clip = true
			if i == 0:
				frames.add_frame("idle", at)
			frames.add_frame("break", at)
			if i == count - 1:
				frames.add_frame("broken", at)
	anim.sprite_frames = frames
	# Bottom-center anchor for animated sprite
	anim.centered = false
	# Compute frame height for pivot
	var first_region_h: int = 0
	var first_region_w: int = 0
	if frames.get_frame_count("idle") > 0:
		var tex0: Texture2D = frames.get_frame_texture("idle", 0)
		if tex0:
			if tex0 is AtlasTexture:
				first_region_h = int((tex0 as AtlasTexture).region.size.y)
				first_region_w = int((tex0 as AtlasTexture).region.size.x)
			elif tex0 is Texture2D:
				first_region_h = (tex0 as Texture2D).get_height()
				first_region_w = (tex0 as Texture2D).get_width()
	# Bottom-center align: center horizontally, place bottom at origin
	anim.position = Vector2(-first_region_w * 0.5, -first_region_h)
	anim.play("idle")
	if old_sprite and old_sprite is Node:
		old_sprite.queue_free()
	# Improve crispness and avoid bleeding
	anim.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	node.add_child(anim)
	# Z-index otomatik olarak create_decoration_instance'da ayarlandı
	anim.z_index = node.z_index

func _play_pot_break_animation(node: Node2D) -> void:
	var anim: AnimatedSprite2D = node.get_node_or_null("Anim") as AnimatedSprite2D
	if anim:
		anim.play("break")

# Dropped coin collection handler (local)
func _on_dropped_gold_collected(body: Node2D, coin: Node2D) -> void:
	if not coin:
		return
	# Prevent double collection
	if coin.get_meta("collected", false):
		return
	if body and _is_player_node(body):
		# Mark as collected immediately to prevent double collection
		coin.set_meta("collected", true)
		
		var gold_value = int(coin.get_meta("gold_value", 1))
		
		# Check if we're in dungeon/forest - add to dungeon_gold, not global gold
		var scene_manager = get_node_or_null("/root/SceneManager")
		var is_combat_scene = false
		if scene_manager:
			var current_scene = scene_manager.get("current_scene_path")
			if current_scene:
				var dungeon_scene = scene_manager.get("DUNGEON_SCENE")
				var forest_scene = scene_manager.get("FOREST_SCENE")
				is_combat_scene = (current_scene == dungeon_scene or current_scene == forest_scene)
		
		# Add to dungeon gold if in combat scene, otherwise to global gold
		if GlobalPlayerData:
			if is_combat_scene:
				GlobalPlayerData.add_dungeon_gold(gold_value)
			else:
				GlobalPlayerData.add_gold(gold_value)
		
		print("[DecorationSpawner] Dropped gold collected: %d at %s" % [gold_value, str(coin.global_position)])
		_create_collection_effect(coin.global_position)
		
		# Disconnect signals to prevent further collection attempts
		var collect: Area2D = coin.get_node_or_null("CollectArea")
		if collect:
			_disconnect_all_signals(collect, "body_entered")
			_disconnect_all_signals(collect, "area_entered")
			collect.monitoring = false
		
		if coin is RigidBody2D and get_node_or_null("/root/Loots"):
			get_node("/root/Loots").call("release", coin)
		else:
			coin.queue_free()

func _on_dropped_gold_area_entered(area: Area2D, coin: Node2D) -> void:
	# Filter strictly for player owner areas
	if not area:
		return
	# Prevent double collection
	if coin.get_meta("collected", false):
		return
	var owner := area.get_parent()
	if owner and owner.is_in_group("player"):
		_on_dropped_gold_collected(owner, coin)

func _create_collection_effect(pos: Vector2) -> void:
	# 4 yöne açılan çizgi-parlama (retro çizgi film hissi)
	var parent: Node = get_tree().current_scene
	var lines := []
	var dirs := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]
	var colors := [Color(1,1,0.6,1), Color(1,1,0.6,1), Color(1,1,1,1), Color(1,1,1,1)]
	for i in range(4):
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = colors[i]
		# Ensure effect renders in front of player sprites
		line.z_as_relative = false
		line.z_index = 1000
		# Leave default texture_mode; no texture is assigned
		line.add_point(pos)
		line.add_point(pos)  # başlangıçta sıfır uzunluk
		parent.add_child(line)
		lines.append({"node": line, "dir": dirs[i]})
	
	var duration := 0.22
	for entry in lines:
		var line: Line2D = entry.node
		var dir: Vector2 = entry.dir
		var tween := create_tween()
		tween.tween_method(func(t: float):
			if not is_instance_valid(line):
				return
			var end_pos: Vector2 = pos + dir * (t * 24.0)
			line.set_point_position(0, pos)
			line.set_point_position(1, end_pos)
			line.modulate.a = 1.0 - t
		, 0.0, 1.0, duration)
		tween.tween_callback(line.queue_free)

# --- Dropped pouch ground/air frame helpers ---
func _on_dropped_gold_body_entered(other: Node, sprite: Sprite2D, body: RigidBody2D) -> void:
	if not sprite:
		return
	var is_ground := false
	if other is CollisionObject2D:
		var layer := (other as CollisionObject2D).collision_layer
		is_ground = (layer & (CollisionLayers.WORLD | CollisionLayers.PLATFORM)) != 0
	else:
		# TileMap veya isim bazlı zemini yakala (TileMap collisionları için)
		if other.get_class() == "TileMap":
			is_ground = true
		else:
			var nl := other.name.to_lower()
			if nl.find("tile") != -1 or nl.find("ground") != -1 or nl.find("platform") != -1:
				is_ground = true
	if is_ground and sprite.hframes == 2:
		# Ground temasında görseli kilitle: kare 1 (ground), döndürmeyi kapat
		sprite.frame = 1
		if body:
			body.angular_velocity = 0
			body.angular_damp = 20.0
			body.freeze = false
			body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
			# Reassert non-blocking filters at contact (defensive)
			body.collision_layer = CollisionLayers.ITEM
			body.collision_mask = CollisionLayers.WORLD | CollisionLayers.PLATFORM

func _on_dropped_gold_body_exited(_other: Node, sprite: Sprite2D, body: RigidBody2D) -> void:
	# Yerden ayrıldığında (sekme olursa) tekrar havada dönsün ve air frame'e geçsin
	if not sprite:
		return
	if sprite.hframes == 2:
		sprite.frame = 0
	if body:
		body.freeze = false
		body.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		body.angular_damp = 1.0

# --- Visual helpers ---
func _apply_gold_visual(sprite: Sprite2D, gold_value: int, on_ground: bool) -> void:
	if gold_value <= 5:
		if ResourceLoader.exists(COIN_SMALL_PATH):
			sprite.texture = load(COIN_SMALL_PATH)
		sprite.hframes = 1
		sprite.vframes = 1
		sprite.frame = 0
	else:
		if ResourceLoader.exists(POUCH_PATH):
			sprite.texture = load(POUCH_PATH)
		sprite.hframes = 2
		sprite.vframes = 1
		sprite.frame = 1 if on_ground else 0
	# Loot visuals are centered; do not apply bottom-center offset

func _apply_bottom_center_to_sprite(sprite: Sprite2D) -> void:
	if not sprite:
		return
	sprite.centered = false
	var h := 0
	var w := 0
	if sprite.texture:
		if sprite.texture is AtlasTexture:
			var at := sprite.texture as AtlasTexture
			h = int(at.region.size.y)
			w = int(at.region.size.x)
		else:
			h = sprite.texture.get_height()
			w = sprite.texture.get_width()
	# If using hframes/vframes, divide height accordingly
	if sprite.vframes > 1:
		h = int(floor(float(h) / float(max(1, sprite.vframes))))
	# Bottom-center pivot: position sprite so bottom sits at origin
	var half_w := 0
	if sprite.hframes > 1:
		w = int(floor(float(w) / float(max(1, sprite.hframes))))
	half_w = int(floor(float(w) * 0.5))
	sprite.position = Vector2(-half_w, -h)

# --- Post placement safety adjustments (edge/wall) ---
func _post_place_fixup(node: Node2D) -> void:
	if not node:
		return
	# If not in tree/world yet, skip safety adjustments for now
	if not is_inside_tree() or get_tree() == null or get_world_2d() == null:
		return
	var dec_type: String = String(node.get_meta("decoration_type", ""))
	# Only adjust for floor-anchored like objects; heuristic via ground support test
	var vis := _estimate_visual_size(node)
	var half_w: float = max(4.0, vis.x * 0.5)
	# Try left-bias and vertical sampling to defeat right-edge overlaps
	node.global_position.x -= 10.0
	var ok := _has_ground_support_span_here(node.global_position, half_w)
	if ok:
		return
	# Try nudging inward up to 12 px
	var adj := _find_supported_position_here(node.global_position, half_w, 12.0, 3.0)
	if adj.ok:
		node.global_position = adj.pos
		return
	# If still bad, push away from immediate right wall overlap
	var pushed := _push_from_right_wall(node.global_position, half_w)
	if pushed.ok:
		node.global_position = pushed.pos

var last_spawned_decoration: Node2D = null

func get_last_spawned_decoration() -> Node2D:
	return last_spawned_decoration

func _is_near_door(spawn_position: Vector2) -> bool:
	# YENİ YAKLAŞIM: Tile-based kontrol - mesafe değil, tile pozisyonu!
	var spawner_tile_x = int(spawn_position.x / 32)
	var spawner_tile_y = int(spawn_position.y / 32)
	
	print("[DoorCheck] Spawner tile position: (", spawner_tile_x, ", ", spawner_tile_y, ")")
	
	# Sahnedeki tüm kapıları bul
	var doors = get_tree().get_nodes_in_group("doors")
	print("[DoorCheck] Found doors in group: ", doors.size())
	
	for door in doors:
		if door and is_instance_valid(door):
			var door_tile_x = int(door.global_position.x / 32)
			var door_tile_y = int(door.global_position.y / 32)
			
			print("[DoorCheck] Door tile position: (", door_tile_x, ", ", door_tile_y, ")")
			
			# 10 tile mesafe kontrolü (320 pixel)
			var tile_distance_x = abs(spawner_tile_x - door_tile_x)
			var tile_distance_y = abs(spawner_tile_y - door_tile_y)
			
			print("[DoorCheck] Tile distance: (", tile_distance_x, ", ", tile_distance_y, ")")
			
			# Kapının tam önünde mi kontrol et (X mesafesi çok küçük)
			if tile_distance_x <= 1 and tile_distance_y <= 5:
				print("[DoorCheck] TOO CLOSE! Directly in front of door!")
				return true
			
			# Banner1 için daha gevşek kontrol (3 tile), diğerleri için 5 tile
			var max_distance = 5
			if spawner_tile_x >= 0:  # Banner1 kontrolü için
				# Eğer bu bir banner1 spawn'ı ise (bunu decoration_name'den anlayamayız burada)
				# Bu yüzden genel olarak 3 tile yapalım
				max_distance = 3
			
			# Genel mesafe kontrolü
			if tile_distance_x <= max_distance or tile_distance_y <= max_distance:
				print("[DoorCheck] TOO CLOSE! Within ", max_distance, " tiles of door!")
				return true
	
	print("[DoorCheck] Safe distance from all doors")
	return false

func _is_near_door_banner(spawn_position: Vector2) -> bool:
	# Banner1 için daha gevşek kapı kontrolü (sadece 2 tile mesafe)
	var spawner_tile_x = int(spawn_position.x / 32)
	var spawner_tile_y = int(spawn_position.y / 32)
	
	print("[BannerDoorCheck] Spawner tile position: (", spawner_tile_x, ", ", spawner_tile_y, ")")
	
	# Sahnedeki tüm kapıları bul
	var doors = get_tree().get_nodes_in_group("doors")
	print("[BannerDoorCheck] Found doors in group: ", doors.size())
	
	for door in doors:
		if door and is_instance_valid(door):
			var door_tile_x = int(door.global_position.x / 32)
			var door_tile_y = int(door.global_position.y / 32)
			
			print("[BannerDoorCheck] Door tile position: (", door_tile_x, ", ", door_tile_y, ")")
			
			var tile_distance_x = abs(spawner_tile_x - door_tile_x)
			var tile_distance_y = abs(spawner_tile_y - door_tile_y)
			
			print("[BannerDoorCheck] Tile distance: (", tile_distance_x, ", ", tile_distance_y, ")")
			
			# Banner1 için sadece kapının tam önünde olmasını engelle (1 tile)
			if tile_distance_x <= 1 and tile_distance_y <= 2:
				print("[BannerDoorCheck] TOO CLOSE! Directly in front of door!")
				return true
			
			# Banner1 için çok gevşek kontrol (sadece 2 tile)
			if tile_distance_x <= 2 or tile_distance_y <= 2:
				print("[BannerDoorCheck] TOO CLOSE! Within 2 tiles of door!")
				return true
	
	print("[BannerDoorCheck] Safe distance from all doors")
	return false

func _find_doors_in_scene() -> Array:
	# Sahnedeki tüm Door node'larını bul
	var doors = []
	var all_nodes = get_tree().get_nodes_in_group("doors")
	
	# Eğer group yoksa, manuel olarak ara
	if all_nodes.is_empty():
		var scene = get_tree().current_scene
		if scene:
			_find_doors_recursive(scene, doors)
	
	return doors

func _find_doors_recursive(node: Node, doors: Array) -> void:
	# Recursive olarak Door class'ına sahip node'ları bul
	if node.has_method("get") and node.get_script() and node.get_script().get_global_name() == "Door":
		doors.append(node)
	
	for child in node.get_children():
		_find_doors_recursive(child, doors)

func _estimate_visual_size(node: Node2D) -> Vector2:
	var spr := node.get_node_or_null("Sprite") as Sprite2D
	if spr and spr.texture:
		var w := 0
		var h := 0
		if spr.texture is AtlasTexture:
			var at := spr.texture as AtlasTexture
			w = int(at.region.size.x)
			h = int(at.region.size.y)
		else:
			w = spr.texture.get_width()
			h = spr.texture.get_height()
		if spr.vframes > 1:
			h = int(floor(float(h) / float(max(1, spr.vframes))))
		if spr.hframes > 1:
			w = int(floor(float(w) / float(max(1, spr.hframes))))
		return Vector2(w, h)
	var anim: AnimatedSprite2D = node.get_node_or_null("Anim") as AnimatedSprite2D
	if anim and anim.sprite_frames and anim.sprite_frames.get_frame_count("idle") > 0:
		var tex := anim.sprite_frames.get_frame_texture("idle", 0)
		if tex:
			if tex is AtlasTexture:
				var at2 := tex as AtlasTexture
				return Vector2(at2.region.size.x, at2.region.size.y)
			elif tex is Texture2D:
				return Vector2(tex.get_width(), tex.get_height())
	return Vector2(32, 32)

func _has_ground_support_span_here(center_pos: Vector2, half_w: float) -> bool:
	var world := get_world_2d()
	if world == null:
		return true
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	var mask: int = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var samples: int = 7
	var hits: int = 0
	var heights := [-16.0, -8.0, 0.0]
	for i in range(samples):
		var t: float = (i as float) / float(samples - 1)
		var x: float = lerp(center_pos.x - half_w, center_pos.x + half_w, t)
		for h in heights:
			var from: Vector2 = Vector2(x, center_pos.y + h)
			var to: Vector2 = Vector2(x, center_pos.y + h + 128)
			var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
			params.collision_mask = mask
			params.collide_with_areas = false
			params.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(params)
			if hit and hit.has("position"):
				hits += 1
				break
	return hits >= int(ceil(float(samples) * 0.5))

func _find_supported_position_here(center_pos: Vector2, half_w: float, max_nudge: float, step: float) -> Dictionary:
	var result := {"ok": false, "pos": center_pos}
	if _has_ground_support_span_here(center_pos, half_w):
		result.ok = true
		return result
	var dir := [-1.0, 1.0]
	var d := step
	while d <= max_nudge:
		for s in dir:
			var candidate := center_pos + Vector2(s * d, 0)
			if _has_ground_support_span_here(candidate, half_w):
				result.ok = true
				result.pos = candidate
				return result
		d += step
	return result

func _push_from_right_wall(center_pos: Vector2, half_w: float) -> Dictionary:
	var result := {"ok": false, "pos": center_pos}
	var world := get_world_2d()
	if world == null:
		return result
	var space: PhysicsDirectSpaceState2D = world.direct_space_state
	var mask: int = CollisionLayers.WORLD | CollisionLayers.PLATFORM
	var max_iters: int = 5
	var shift_per_hit: float = 2.0
	var check_offsets := [-4.0, -10.0, -16.0]
	var pos := center_pos
	for _i in range(max_iters):
		var any_hit := false
		for oy in check_offsets:
			var from: Vector2 = pos + Vector2(0, oy)
			var to: Vector2 = pos + Vector2(half_w + 6.0, oy)
			var params: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to)
			params.collision_mask = mask
			params.collide_with_areas = false
			params.collide_with_bodies = true
			var hit: Dictionary = space.intersect_ray(params)
			if hit and hit.has("position"):
				any_hit = true
				break
		if any_hit:
			pos.x -= shift_per_hit
		else:
			result.ok = true
			result.pos = pos
			return result
	return result

func get_spawned_decoration() -> Node2D:
	return _spawned_decoration

func clear_decoration() -> void:
	if _spawned_decoration and is_instance_valid(_spawned_decoration):
		_spawned_decoration.queue_free()
		_spawned_decoration = null

func set_level(level: int) -> void:
	current_level = level 
