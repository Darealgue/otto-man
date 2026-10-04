class_name ForestArenaDecorator
extends ForestLevelGenerator

## Orman challenge arenasını gerçek orman sahnesinin görünümüne kavuşturur: gökyüzü gradyanı, oyun
## saatine göre güneş/ay/yıldız ve ışık (DayNightController), dağ ve ağaç parallax'ları, bulutlar,
## yağmur, uçuşan yapraklar; zemin üstünde ağaç, çiçek, kelebek ve ateş böceği (orman dekoru).
## Bunların hepsi ForestLevelGenerator'da hazır olduğundan onu miras alıp yalnız yol üretimini
## (chunk'lar, düşmanlar, kaynaklar) devre dışı bırakıyoruz: _ready, _process ve girdi geçersiz kılındı.
## Not: "level_generator" grubuna GİRMEZ (tuzak/düşman kodu o grupla gerçek bir seviye arıyor).

## "forest" ya da "mountain" (Zirve Tırmanışı dağ parallax'ı kullanır); add_child'dan ÖNCE verilmeli.
var decor_biome: String = "forest"


func _ready() -> void:
	biome_type = decor_biome
	_decor_spawner = DecorationSpawner.new()
	add_child(_decor_spawner)
	_setup_day_night_system()


## Arena kökündeki "TileMapLayer" karolarının yüzeyine ağaç/çiçek/kelebek dekorunu sıraya alır.
func decorate(arena_root: Node2D) -> void:
	_populate_forest_decorations_for_chunk(arena_root)


func _process(_delta: float) -> void:
	_process_decor_spawn_queue()


func _physics_process(_delta: float) -> void:
	pass


func _input(_event: InputEvent) -> void:
	pass


func _unhandled_input(_event: InputEvent) -> void:
	pass
