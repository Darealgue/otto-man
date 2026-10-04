class_name TrapCorridorTraps
extends RefCounted

## Tuzak Geçidi'nin ortak tuzak yardımcıları (labirent yerleşimi trap_maze_builder.gd'de). Gerçek zindan tuzak
## sistemini (traps_v2: TileTrapSpawner, TrapConfigV2, DungeonThemeStyle) level_generator'ın yaptığı gibi kullanır.


## Tuzağın grup boyu: temanın override'ı varsa o, yoksa seviye tablosu.
static func _group_size(t: TrapConfigV2.TrapType, level: int, theme: String, rng: RandomNumberGenerator) -> int:
	var ov: Vector2i = DungeonThemeStyle.get_trap_group_override(theme, TrapConfigV2.trap_name(t))
	var r: Vector2i = ov if ov != Vector2i.ZERO else TrapConfigV2.get_group_size_range(level)
	return rng.randi_range(maxi(r.x, 1), maxi(r.y, 1))


## level_generator ile aynı yol: TileTrapSpawner düğümü kurulur ve etkinleştirilir (konum = yüzey noktası).
static func _spawn(parent: Node2D, t: TrapConfigV2.TrapType, surface: TrapConfigV2.SurfaceType, pos: Vector2, level: int, theme: String) -> int:
	var spawner := Node2D.new()
	spawner.set_script(load("res://traps_v2/tile_trap_spawner.gd"))
	spawner.set("trap_type", t)
	spawner.set("surface_type", surface)
	spawner.set("current_level", level)
	spawner.set("dungeon_theme", theme)
	parent.add_child(spawner)
	spawner.global_position = pos
	spawner.call_deferred("activate")
	return 1
