extends Node2D
## Oyuncu death zone’a girince [respawn_marker] konumunda yeniden çıkar.
## NodePath boşsa: `tutorial_parkour_death` / `tutorial_parkour_respawn` grupları veya
## (auto_discover açıkken) üst düğüm + sahne içinde export’taki ada göre Area2D / işaret düğümü; ada `DeathZoneParkour` gibi farklıysa isim listesi veya adında "death" geçen Area2D kardeşi; respawn yoksa isteğe bağlı olarak bu checkpoint konumu.

@export var death_zone: NodePath
@export var respawn_marker: NodePath
@export_range(0, 2000, 1, "suffix:ms") var reset_cooldown_ms: int = 250
## Beat trigger’larla aynı: layer 0, mask oyuncu (2).
@export var auto_configure_death_zone: bool = true
@export var poll_physics_overlap: bool = true
@export var player_fallback_path: NodePath = NodePath("^%Player")
@export_group("Çarpışma olmuyorsa (yedek)")
@export var respawn_below_global_y: bool = false
@export var global_y_below_falls_through: float = 4000.0
@export_group("Teşhis")
@export var debug_log: bool = false
## Her çalıştırmada tek satır konsol (F8 çıktısında görünür).
@export var startup_log: bool = true
@export_group("Otomatik bul (path/grup boşsa)")
@export var auto_discover: bool = true
## Önce [ParkourCheckpoint] ile aynı üst düğümde bu adlar denenir, sonra tüm sahne.
@export var death_zone_search_names: PackedStringArray = PackedStringArray(
	["DeathZoneParkour", "DeathZone", "ParkourDeathZone", "ParkourPit", "PitArea", "DeathArea"]
)
@export var respawn_marker_search_names: PackedStringArray = PackedStringArray(
	["ParkourRespawn", "ParkourStart", "RespawnMarker", "ParkourSpawn"]
)
## Path / grup / isim bulunamazsa oyuncu bu Node2D’nin global_position değerine çıkar (sahne köküne Marker koymadan test için).
@export var respawn_fallback_use_checkpoint_position: bool = true

const _LAYER_PLAYER: int = 1 << 1

var _last_respawn_ms: int = -999999
var _dbg_frame: int = 0

var _area: Area2D
var _marker: Node2D


func _ready() -> void:
	call_deferred("_setup")


func _setup() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame

	_area = _resolve_death_zone()
	_marker = _resolve_respawn_marker()

	if _area == null:
		push_error(
			"[ParkourCheckpoint] death_zone yok. Inspector’dan Area2D bağla, `tutorial_parkour_death` grubuna ekle VEYA auto_discover ad listesine uygun bir Area2D adı ver."
		)
		_startup_msg(false, "death_zone null")
		return
	if _marker == null:
		push_error(
			"[ParkourCheckpoint] respawn_marker yok. Marker/Node2D bağla, `tutorial_parkour_respawn` grubuna ekle VEYA auto_discover ad listesine uygun bir Marker2D/boş Node2D adı ver."
		)
		_startup_msg(false, "respawn_marker null")
		return

	if auto_configure_death_zone:
		_area.collision_layer = 0
		_area.collision_mask = _LAYER_PLAYER
		_area.monitorable = true
		_area.monitoring = true

	var has_active_shape := _area_has_nonempty_shape(_area)
	if not has_active_shape:
		push_warning("[ParkourCheckpoint] death_zone’da etkin CollisionShape / Polygon yok.")

	if not _area.body_entered.is_connected(_on_death_zone_body_entered):
		_area.body_entered.connect(_on_death_zone_body_entered.bind())

	if _marker == self:
		push_warning(
			"[ParkourCheckpoint] respawn_marker atanmadı; yeniden doğuş konumu olarak bu checkpoint düğümünün konumu kullanılıyor. İstersen Marker2D ekle veya respawn_fallback_use_checkpoint_position seçeneğini kapat."
		)

	set_physics_process(poll_physics_overlap)
	_startup_msg(true, "area=%s marker=%s mask=%d" % [_area.name, _marker.name, _area.collision_mask])


func _startup_msg(ok: bool, detail: String) -> void:
	if not startup_log:
		return
	if ok:
		print("[ParkourCheckpoint] READY ", detail)
	else:
		print("[ParkourCheckpoint] FAILED ", detail)


func _resolve_death_zone() -> Area2D:
	if not death_zone.is_empty():
		var n := _resolve_best(death_zone)
		if n is Area2D:
			return n as Area2D
	var g := get_tree().get_first_node_in_group("tutorial_parkour_death")
	if g is Area2D:
		return g as Area2D
	if auto_discover:
		var par := get_parent()
		var by_parent := _find_area_under_parent(par, death_zone_search_names)
		if by_parent != null:
			return by_parent
		var by_kw := _find_area_sibling_death_keyword(par)
		if by_kw != null:
			return by_kw
		var root := get_tree().current_scene
		if root == null:
			root = _approx_scene_root(self)
		if root != null:
			var found := _find_area_by_names_dfs(root, death_zone_search_names)
			if found != null:
				return found
			var by_kw_dfs := _find_area_dfs_death_keyword(root)
			if by_kw_dfs != null:
				return by_kw_dfs
	return null


func _resolve_respawn_marker() -> Node2D:
	if not respawn_marker.is_empty():
		var n := _resolve_best(respawn_marker)
		if n is Node2D:
			return n as Node2D
	var g := get_tree().get_first_node_in_group("tutorial_parkour_respawn")
	if g is Node2D:
		return g as Node2D
	if auto_discover:
		var par := get_parent()
		var by_parent := _find_marker_under_parent(par, respawn_marker_search_names)
		if by_parent != null:
			return by_parent
		var root := get_tree().current_scene
		if root == null:
			root = _approx_scene_root(self)
		if root != null:
			var found := _find_marker_by_names_dfs(root, respawn_marker_search_names)
			if found != null:
				return found
		if respawn_fallback_use_checkpoint_position:
			return self
	return null


func _find_area_sibling_death_keyword(p: Node) -> Area2D:
	if p == null:
		return null
	for c in p.get_children():
		if not (c is Area2D):
			continue
		var ln := str(c.name).to_lower()
		if ln.contains("death") and not ln.contains("beat"):
			return c as Area2D
	return null


func _find_area_dfs_death_keyword(node: Node) -> Area2D:
	if node is Area2D:
		var ln := str(node.name).to_lower()
		if ln.contains("death") and not ln.contains("beat"):
			return node as Area2D
	for c in node.get_children():
		var r := _find_area_dfs_death_keyword(c)
		if r != null:
			return r
	return null


func _find_area_under_parent(p: Node, names: PackedStringArray) -> Area2D:
	if p == null:
		return null
	for nm in names:
		if str(nm).is_empty():
			continue
		var ch := p.get_node_or_null(NodePath(str(nm)))
		if ch is Area2D:
			return ch as Area2D
	return null


func _find_marker_under_parent(p: Node, names: PackedStringArray) -> Node2D:
	if p == null:
		return null
	for nm in names:
		if str(nm).is_empty():
			continue
		var ch := p.get_node_or_null(NodePath(str(nm)))
		var sm := _as_spawn_marker(ch)
		if sm != null:
			return sm
	return null


func _as_spawn_marker(n: Node) -> Node2D:
	if n is Marker2D:
		return n as Node2D
	if n is Node2D:
		if n is CharacterBody2D or n is Area2D or n is TileMap or n is CollisionObject2D:
			return null
		return n as Node2D
	return null


func _find_area_by_names_dfs(node: Node, names: PackedStringArray) -> Area2D:
	if node is Area2D and _node_name_in_list(node.name, names):
		return node as Area2D
	for c in node.get_children():
		var r := _find_area_by_names_dfs(c, names)
		if r != null:
			return r
	return null


func _find_marker_by_names_dfs(node: Node, names: PackedStringArray) -> Node2D:
	if _node_name_in_list(node.name, names):
		var sm := _as_spawn_marker(node)
		if sm != null:
			return sm
	for c in node.get_children():
		var r := _find_marker_by_names_dfs(c, names)
		if r != null:
			return r
	return null


func _node_name_in_list(node_name: StringName, list: PackedStringArray) -> bool:
	var ln := str(node_name).to_lower()
	for entry in list:
		if str(entry).to_lower() == ln:
			return true
	return false


func _physics_process(_delta: float) -> void:
	if not poll_physics_overlap:
		return
	if _area == null or _marker == null:
		return
	var pl := _resolve_player()
	if pl == null or not _living_player(pl):
		return
	var in_pit_y := respawn_below_global_y and pl.global_position.y >= global_y_below_falls_through
	var in_zone := _player_in_death_zone(pl)
	if debug_log:
		_dbg_frame += 1
		if _dbg_frame % 90 == 0:
			var ob := _area.get_overlapping_bodies().size()
			print(
				"[ParkourCheckpoint] tick pl=%s pos=%s overlaps=%s ob_count=%d"
				% [pl.name, str(pl.global_position), str(in_zone), ob]
			)
	if in_zone or in_pit_y:
		_do_respawn(pl)


func _player_in_death_zone(pl: CharacterBody2D) -> bool:
	if _area == null or not _area.monitoring or _area.get_world_2d() == null:
		return false
	if _area.overlaps_body(pl):
		return true
	for b in _area.get_overlapping_bodies():
		if b == pl:
			return true
	return false


func _on_death_zone_body_entered(body: Node2D) -> void:
	if body == null:
		return
	var pl := body as CharacterBody2D
	if pl == null:
		return
	if not _is_player(body):
		return
	if debug_log:
		print("[ParkourCheckpoint] body_entered ", body.name)
	_do_respawn(pl)


func _do_respawn(pl: CharacterBody2D) -> void:
	if _marker == null or not is_instance_valid(_marker):
		return
	if not _living_player(pl):
		return

	var now := Time.get_ticks_msec()
	if now - _last_respawn_ms < reset_cooldown_ms:
		return
	_last_respawn_ms = now

	if debug_log:
		print("[ParkourCheckpoint] RESPAWN ", pl.name, " -> ", _marker.global_position)

	pl.global_position = _marker.global_position
	pl.velocity = Vector2.ZERO


func _resolve_best(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var n := self.get_node_or_null(path)
	if n != null:
		return n
	var cs := get_tree().current_scene if get_tree() else null
	if cs != null and cs != self:
		n = cs.get_node_or_null(path)
		if n != null:
			return n
	var scn := _approx_scene_root(self)
	if scn != null and scn != self and scn != cs:
		return scn.get_node_or_null(path)
	return null


func _approx_scene_root(node: Node) -> Node:
	var x: Node = node
	while x != null:
		var p := x.get_parent()
		if p == null or p is Window or p.get_class() == "Viewport":
			return x
		if x.scene_file_path != "" and x.owner == x:
			return x
		if x.owner != null and x.owner == x:
			return x
		x = p
	return null


func _resolve_player() -> CharacterBody2D:
	var g := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if g != null:
		return g
	if not player_fallback_path.is_empty():
		var n := _resolve_best(player_fallback_path)
		if n != null:
			return n as CharacterBody2D
	return null


func _living_player(p: CharacterBody2D) -> bool:
	if p == null:
		return false
	var vd: Variant = p.get("is_dead")
	if typeof(vd) == TYPE_BOOL and bool(vd):
		return false
	return true


func _area_has_nonempty_shape(area: Area2D) -> bool:
	for child in area.get_children():
		if child is CollisionShape2D:
			var cs := child as CollisionShape2D
			if cs.disabled:
				continue
			if cs.shape != null:
				return true
		elif child is CollisionPolygon2D:
			var cp := child as CollisionPolygon2D
			if not cp.disabled and cp.polygon.size() >= 3:
				return true
	return false


func _is_player(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("player"):
		return true
	return node is CharacterBody2D and str(node.name) == "Player"
