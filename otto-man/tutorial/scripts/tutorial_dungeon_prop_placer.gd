extends Node2D
## Tutorial zindanında dekorları `LevelGenerator` ile ana oyundaki kurallarla yerleştirir;
## yoğunluk, sadece zemin anchor'ları ve performans için ayrı kısıtlar uygulanır.

const _LevelGenerator := preload("res://scenes/level_generator.gd")

@export var tiles_node_name: StringName = &"tiles"
## Sadece `floor_surface` / `floor` / `floor_breakable` / `forest_floor_surface` etiketli hücreler (duvardaki örümcek ağı vb. yok).
@export var decor_floor_anchors_only: bool = true
## Tüm `chance` değerleri bununla çarpılır.
@export_range(0.02, 0.5, 0.01) var decor_chance_scale: float = 0.11
## Başarılı spawn üst sınırı; 0 = sınırsız.
@export_range(0, 400, 1) var decor_max_spawns: int = 36
@export var decor_skip_ceiling: bool = true
@export var decor_skip_gold_and_breakable: bool = true
@export var decor_require_loadable_visual: bool = true
@export var decor_skip_heavy_blocking: bool = true
## Tutorialda `get_nodes_in_group("doors")` + tile taraması atlanır (açılış hızı).
@export var decor_skip_door_proximity: bool = true
## Tek parça haritada chunk komşu kenarı kontrolü atlanır (`get_used_rect` + grid).
@export var decor_skip_chunk_edge_check: bool = true
## Zemin küçük dekorlarda `_find_supported_position` araması atlanır.
@export var decor_skip_support_search: bool = true


func _ready() -> void:
	call_deferred("_run_decor")


func _run_decor() -> void:
	var scene_root := get_parent() as Node2D
	if scene_root == null:
		push_warning("[TutorialDungeonPropPlacer] Üst düğüm yok.")
		return
	var tiles := scene_root.get_node_or_null(NodePath(String(tiles_node_name))) as TileMapLayer
	if tiles == null:
		push_warning("[TutorialDungeonPropPlacer] '%s' adlı TileMapLayer bulunamadı." % String(tiles_node_name))
		return
	var gen := _LevelGenerator.new()
	gen.set_meta("_tutorial_decor_only", true)
	add_child(gen)
	var opts := {
		"floor_anchors_only": decor_floor_anchors_only,
		"chance_scale": decor_chance_scale,
		"max_spawns": decor_max_spawns,
		"skip_ceiling": decor_skip_ceiling,
		"skip_gold_breakable": decor_skip_gold_and_breakable,
		"require_loadable_visual": decor_require_loadable_visual,
		"skip_heavy_blocking": decor_skip_heavy_blocking,
		"skip_tutorial_door_proximity": decor_skip_door_proximity,
		"skip_tutorial_chunk_edge": decor_skip_chunk_edge_check,
		"skip_tutorial_support_search": decor_skip_support_search,
	}
	gen.run_tutorial_tile_decorations(tiles, self, scene_root, opts)
	gen.queue_free()
