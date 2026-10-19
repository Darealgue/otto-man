class_name VillagerShowActor
extends RefCounted

## Bir köylüyü (oyuncu köyündeki Worker ya da ziyaret köyündeki VisitVillager) kısa süreliğine "kukla gibi" sürer:
## yürütür, animasyon oynatır, yöne çevirir. Köylünün kendi mantığı (Worker fiziği / VisitVillager güncellemesi) bu sürede
## durdurulur; bitince köylü normal rutinine kaldığı yerden döner. Yeni karakter çizimi gerekmez: hepsi mevcut animasyonlar
## (idle, walk, walk_tool, walk_carry, sit, lie, drink) ve kodla çizilen küçük efektlerdir. Etkinlikler VillageShowDirector'dadır.

const IDLE_FRAME: int = 6                    # yürüme şeridinde bacakların birleşik olduğu dik duruş karesi
const WORKER_BAND_MIN: float = 5.0           # Worker.VERTICAL_RANGE_MIN
const WORKER_BAND_MAX: float = 30.0          # Worker.VERTICAL_RANGE_MAX
const WORKER_IDLE_STATES: Array[int] = [1, 7]  # Worker.State.AWAKE_IDLE, Worker.State.SOCIALIZING
const BUCKET_TEXTURE: Texture2D = preload("res://assets/tools/walk_work_tool_bucket.png")

var node: Node2D = null       # hareket ettirilen düğüm (Worker ya da VisitVillager)
var body: Node2D = null       # play_animation sahibi Worker (VisitVillager'da _body)
var is_worker: bool = true
var cancelled: bool = false
var speed: float = 55.0
var _begun: bool = false
# Kilitli animasyon: köylünün kendi kancaları (saat başı olayları, boşta zamanlayıcısı) araya girip başka bir animasyon
# (ör. "sit"/"lie") oynatırsa yürürken/beklerken geri konur. _lock_item elde taşınan nesne ("bucket"/"bundle"/"").
var _lock_anim: String = ""
var _lock_item: String = ""
# Üstsüz mod (yüzen erkek köylüler): giysi katmanı her animasyon değişiminde ve karede gizli tutulur.
var strip_clothing: bool = false


## Erkek mi (kadın köylülerde Worker._is_female_villager true döner; ziyaret köylülerinde cinsiyet bilgisi yok = erkek).
func is_male() -> bool:
	if body != null and is_instance_valid(body) and body.has_method("_is_female_villager"):
		return not bool(body.call("_is_female_villager"))
	return true


func set_shirtless(on: bool) -> void:
	strip_clothing = on
	if on:
		_apply_strip()


func _apply_strip() -> void:
	if not strip_clothing or body == null or not is_instance_valid(body) or not ("clothing_sprite" in body):
		return
	var cs: Variant = body.get("clothing_sprite")
	if cs is Sprite2D and is_instance_valid(cs) and (cs as Sprite2D).visible:
		(cs as Sprite2D).hide()


static func for_worker(worker: Node2D) -> VillagerShowActor:
	var a := VillagerShowActor.new()
	a.node = worker
	a.body = worker
	a.is_worker = true
	a.speed = float(worker.get("move_speed")) if "move_speed" in worker else 55.0
	return a


static func for_visit(villager: Node2D) -> VillagerShowActor:
	var a := VillagerShowActor.new()
	a.node = villager
	a.body = villager.get("_body") as Node2D
	a.is_worker = false
	a.speed = float(villager.get("_speed")) if "_speed" in villager else 55.0
	return a


## Düğüm hâlâ sahnede mi (yok edilmişse etkinlik hemen bırakılır).
func alive() -> bool:
	return not cancelled and is_instance_valid(node) and node.is_inside_tree() and (body == null or is_instance_valid(body))


## Köylünün kendi rutini araya girdi (uyku saati, konuşma penceresi, yeni vardiya...): etkinlik toparlanıp bırakılmalı.
func should_stop() -> bool:
	if not alive():
		return true
	if is_worker:
		if not (int(node.get("current_state")) in WORKER_IDLE_STATES):
			return true
		var nw: Variant = node.get("_npc_window_ref") if "_npc_window_ref" in node else null
		if nw != null and is_instance_valid(nw) and (nw as Node).visible:
			return true
		return false
	var hour: float = float(node.get("scene_ref").call("current_hour_value")) if node.get("scene_ref") != null else 12.0
	return node.call("place_key_for", hour) != node.get("place_key")


func begin() -> void:
	if _begun or not alive():
		return
	_begun = true
	if is_worker:
		node.set_physics_process(false)
		var timer: Variant = node.get("idle_activity_timer")
		if timer is Timer:
			(timer as Timer).stop()
		node.set("_is_briefly_idling", false)
		node.set("_current_idle_activity", "show")
	else:
		node.set("show_puppet", true)


## Etkinlik bitti: köylü normal rutinine döner. Worker'ın yürünebilir bant dışında kalması anında ışınlanmaya yol açar;
## o yüzden etkinlikler end() öncesi return_to_band() çağırır.
func end() -> void:
	if not _begun:
		return
	_begun = false
	_lock_anim = ""
	_lock_item = ""
	strip_clothing = false
	if not is_instance_valid(node):
		return
	_clear_held()
	if is_worker:
		if is_instance_valid(body):
			node.set("move_target_x", node.global_position.x)
			node.set("_target_global_y", node.global_position.y)
		node.set("_current_idle_activity", "")
		node.visible = true
		node.set_physics_process(true)
		if int(node.get("current_state")) in WORKER_IDLE_STATES:
			node.call("_start_next_idle_step")
	else:
		node.set("show_puppet", false)
		node.visible = true
		node.call("_enter_idle", randf_range(1.0, 3.0))


# ─── Sürme ───────────────────────────────────────────────────────────────────

func play(anim: String) -> void:
	_lock_anim = anim
	_lock_item = ""
	_apply_anim(anim)


## Kilitli animasyon başka biri tarafından değiştirildiyse geri koyar.
func _enforce_anim() -> void:
	_apply_strip()
	if _lock_anim == "" or body == null or not is_instance_valid(body) or not ("_current_animation_name" in body):
		return
	if String(body.get("_current_animation_name")) != _lock_anim:
		if _lock_item != "":
			_apply_item_anim(_lock_item)
		else:
			_apply_anim(_lock_anim)


func _apply_anim(anim: String) -> void:
	if body == null or not is_instance_valid(body) or not body.has_method("play_animation"):
		return
	body.call("play_animation", anim)
	_apply_strip()
	# Worker "idle" için klip oynatmaz ve yürüme dokusunun 0. karesini (adım atma pozu) bırakır: dik duruş karesini kur.
	if anim == "idle":
		for part in ["BodySprite", "PantsSprite", "ClothingSprite", "MouthSprite", "EyesSprite", "BeardSprite", "HairSprite", "HatSprite"]:
			var spr: Sprite2D = body.get_node_or_null(part) as Sprite2D
			if spr != null:
				spr.frame = IDLE_FRAME


## Elde taşınan nesneyi gösterir. "bucket": su kovası (walk_tool pozu), "bundle": bohça (walk_carry pozu).
func play_with_item(item: String) -> void:
	_lock_anim = "walk_tool" if item == "bucket" else "walk_carry"
	_lock_item = item
	_apply_item_anim(item)


func _apply_item_anim(item: String) -> void:
	if item == "bucket":
		_apply_anim("walk_tool")
		_set_held_texture(BUCKET_TEXTURE)
	else:
		_apply_anim("walk_carry")


func _set_held_texture(tex: Texture2D) -> void:
	var held: Variant = body.get("held_item_sprite") if is_instance_valid(body) and "held_item_sprite" in body else null
	if held is Sprite2D:
		var ct := CanvasTexture.new()
		ct.diffuse_texture = tex
		(held as Sprite2D).texture = ct
		(held as Sprite2D).modulate = Color.WHITE
		(held as Sprite2D).show()


func _clear_held() -> void:
	if not is_instance_valid(body):
		return
	var held: Variant = body.get("held_item_sprite") if "held_item_sprite" in body else null
	if held is Sprite2D:
		(held as Sprite2D).hide()
	var icon: Variant = body.get("carried_item_icon") if "carried_item_icon" in body else null
	if icon is Sprite2D:
		(icon as Sprite2D).hide()
	play("idle")


func face(dir: float) -> void:
	if dir == 0.0 or not is_instance_valid(node):
		return
	if is_worker:
		node.scale.x = dir
	elif is_instance_valid(body):
		body.scale.x = dir


func update_depth() -> void:
	if not is_instance_valid(node):
		return
	if is_worker and node.has_method("get_foot_y_position") and node.has_method("_calculate_z_index_from_foot_y"):
		node.z_index = int(node.call("_calculate_z_index_from_foot_y", node.call("get_foot_y_position")))
	elif not is_worker:
		node.z_index = int(VisitVillager.depth_z(node.global_position.y))


func _dt() -> float:
	return node.get_physics_process_delta_time() if is_instance_valid(node) else 0.016


## (x, y) noktasına yürür (anim: walk / walk_tool / walk_carry). Vardığında true; köylü araya girerse ya da yok olursa false.
func walk_to(x: float, y: float, anim: String = "walk", speed_mult: float = 1.0) -> bool:
	# "walk_tool" yürüyüşü elde kova varken play_with_item ile kurulur; burada sadece yürüme klibini kilitle.
	if anim == "walk_tool" and _lock_item == "bucket":
		_lock_anim = "walk_tool"
		_enforce_anim()
	elif anim == "walk_carry" and _lock_item == "bundle":
		_lock_anim = "walk_carry"
		_enforce_anim()
	else:
		play(anim)
	var target := Vector2(x, y)
	while alive():
		var pos: Vector2 = node.global_position
		var remaining: float = pos.distance_to(target)
		if remaining <= 2.5:
			node.global_position = target
			update_depth()
			return true
		face(signf(target.x - pos.x) if absf(target.x - pos.x) > 1.0 else 0.0)
		node.global_position = pos.move_toward(target, speed * speed_mult * _dt())
		update_depth()
		_enforce_anim()
		await node.get_tree().physics_frame
		if should_stop():
			return false
	return false


## Belirli süre bekler (köylü araya girerse erken döner). Süre dolduysa true.
func wait(seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if not alive() or should_stop():
			return false
		var step: float = minf(left, 0.25)
		await node.get_tree().create_timer(step).timeout
		left -= step
		_enforce_anim()
	return alive() and not should_stop()


## Worker'ın yürünebilir bandına (y 5..30) geri döner; bitmeden end() çağrılırsa köylü ışınlanır.
func return_to_band() -> void:
	if not alive():
		return
	var y: float = node.global_position.y
	if y >= WORKER_BAND_MIN and y <= WORKER_BAND_MAX:
		return
	var target_y: float = clampf(y, WORKER_BAND_MIN + 2.0, WORKER_BAND_MAX - 2.0)
	# should_stop'tan bağımsız yürür (uyku saati gelmiş olsa bile ışınlanmasın).
	play("walk")
	while alive():
		var pos: Vector2 = node.global_position
		if absf(pos.y - target_y) <= 1.5:
			break
		node.global_position = pos.move_toward(Vector2(pos.x, target_y), speed * _dt())
		update_depth()
		await node.get_tree().physics_frame
