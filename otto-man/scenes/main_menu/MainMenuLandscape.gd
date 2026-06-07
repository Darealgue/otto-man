extends Control
## Ana menü manzarası — sürekli sağa akan sonsuz X parallax (uzak hızlı, yakın yavaş).

@export var scroll_speed: float = 48.0
@export var start_centered: bool = true
## 1.0 = tam sığdır; daha düşük = üst/alt siyah bant (sinematik çerçeve).
@export_range(0.55, 1.0, 0.01) var scene_height_ratio: float = 0.86

@onready var _layer_root: Control = $Layers

var _layer_entries: Array[Dictionary] = []
var _scroll_x: float = 0.0
var _parallax_active: bool = true
var _last_viewport_size: Vector2 = Vector2.ZERO

const LAYER_SPEEDS: Dictionary = {
	"Gokyuzu": 1.00,
	"Bulutlar": 0.90,
	"Deniz": 0.82,
	"EnArkaTepe": 0.72,
	"ArkaTepe": 0.60,
	"OrtaTepe": 0.45,
	"OnTepe": 0.08,
	"Agac": 0.08,
	"AgacYapraklari": 0.08,
}

const LINKED_LAYER_GROUPS: Array = [
	["OnTepe", "Agac", "AgacYapraklari"],
]

const TILE_COUNT: int = 3


func _ready() -> void:
	_layer_root.resized.connect(_on_layer_root_resized)
	call_deferred("_rebuild_layers")


func _on_layer_root_resized() -> void:
	var size := _layer_root.size
	if size.x <= 0.0 or size.y <= 0.0 or size.is_equal_approx(_last_viewport_size):
		return
	call_deferred("_rebuild_layers")


func set_parallax_active(active: bool) -> void:
	_parallax_active = active


func _rebuild_layers() -> void:
	var viewport_size := _layer_root.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	_last_viewport_size = viewport_size
	_layer_entries.clear()

	for child in _layer_root.get_children():
		if child is Control:
			_build_layer_tiles(child as Control, viewport_size)

	_apply_scroll()


func _build_layer_tiles(layer: Control, viewport_size: Vector2) -> void:
	var source := layer.get_node_or_null("Texture") as TextureRect
	if source == null or source.texture == null:
		return

	var texture: Texture2D = source.texture
	source.visible = false
	var layout := _fit_layout_for(texture, viewport_size)

	var old_scroller := layer.get_node_or_null("Scroller")
	if old_scroller:
		old_scroller.queue_free()

	layer.clip_contents = false
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var scroller := Control.new()
	scroller.name = "Scroller"
	layer.add_child(scroller)

	for i in TILE_COUNT:
		var tile := TextureRect.new()
		tile.name = "Tile%d" % i
		tile.texture = texture
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tile.custom_minimum_size = layout.tile_frame_size
		tile.size = layout.tile_frame_size
		tile.position = Vector2(i * layout.tile_width, layout.y_offset)
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scroller.add_child(tile)

	_layer_entries.append({
		"name": layer.name,
		"scroller": scroller,
		"tile_width": layout.tile_width,
		"speed": float(LAYER_SPEEDS.get(layer.name, 0.5)),
		"viewport_width": viewport_size.x,
	})


func _fit_layout_for(texture: Texture2D, viewport_size: Vector2) -> Dictionary:
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return {
			"tile_frame_size": viewport_size,
			"tile_width": viewport_size.x,
			"y_offset": 0.0,
		}

	var target_height := viewport_size.y * scene_height_ratio
	var fit_scale := minf(
		viewport_size.x / tex_size.x,
		target_height / tex_size.y
	)
	var display_size := tex_size * fit_scale
	return {
		"tile_frame_size": display_size,
		"tile_width": display_size.x,
		"y_offset": (viewport_size.y - display_size.y) * 0.5,
	}


func _process(delta: float) -> void:
	if not _parallax_active or _layer_entries.is_empty():
		return

	_scroll_x += scroll_speed * delta
	_apply_scroll()


func _scroller_x(tile_width: float, viewport_width: float, speed: float) -> float:
	var loop_offset := fposmod(_scroll_x * speed, tile_width)
	var centered_base := 0.0
	if start_centered:
		centered_base = viewport_width * 0.5 - tile_width * 0.5
	return centered_base - loop_offset


func _apply_scroll() -> void:
	var linked_layers: Dictionary = {}

	for group in LINKED_LAYER_GROUPS:
		if group.is_empty():
			continue
		var anchor_entry: Dictionary = _find_entry(group[0])
		if anchor_entry.is_empty():
			continue
		var offset_x := _scroller_x(
			anchor_entry["tile_width"],
			anchor_entry["viewport_width"],
			anchor_entry["speed"]
		)
		for layer_name in group:
			linked_layers[layer_name] = offset_x

	for entry in _layer_entries:
		var layer_name: String = entry["name"]
		var scroller: Control = entry["scroller"]
		var offset_x: float
		if linked_layers.has(layer_name):
			offset_x = linked_layers[layer_name]
		else:
			offset_x = _scroller_x(
				entry["tile_width"],
				entry["viewport_width"],
				entry["speed"]
			)
		scroller.position = Vector2(offset_x, 0.0)


func _find_entry(layer_name: String) -> Dictionary:
	for entry in _layer_entries:
		if entry["name"] == layer_name:
			return entry
	return {}
