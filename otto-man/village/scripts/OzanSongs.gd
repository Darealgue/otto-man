class_name OzanSongs
extends RefCounted

## Ozan türküsü: keşfedilmemiş bir zindanın yerini BULANIK anlatır. Koordinat vermez; yalnızca
## köye göre yön (8 yön) ve uzaklık (yakın/orta/uzak) söyler, zindanın temasını da türkünün
## sözlerine gömer ("kalkanı sağlam olanın yoludur" = buz). Aynı zindan iki kez anlatılmaz
## (ItemManager.ozan_sung_dungeon_keys, kayda yazılır).

## Ozana verilen yiyecek (köy deposundan).
const FOOD_COST: int = 3
## Köye hex uzaklığı: <= NEAR yakın, <= MID orta, üstü uzak.
const DIST_NEAR_MAX: int = 18
const DIST_MID_MAX: int = 28
## Yön dilimleri: açı 0 = doğu, saat yönünde artar (ekranda y aşağı), 45 derecelik 8 dilim.
const DIR_KEYS: Array[String] = ["ozan.dir.e", "ozan.dir.se", "ozan.dir.s", "ozan.dir.sw",
		"ozan.dir.w", "ozan.dir.nw", "ozan.dir.n", "ozan.dir.ne"]


static func _node(path: String) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(path)


## Köyün hex koordinatı ("player_village" POI'si); bulunamazsa boş sözlük.
static func _village_pos(wm: Node) -> Dictionary:
	for key in wm.world_map_tiles:
		var tile: Dictionary = wm.world_map_tiles[key]
		if String(tile.get("poi_type", "")) == "player_village":
			return {"q": int(tile.get("q", 0)), "r": int(tile.get("r", 0))}
	return {}


## Anlatılabilecek zindanlar: keşfedilmemiş, tutorial olmayan, daha önce söylenmemiş.
static func candidate_keys() -> Array[String]:
	var out: Array[String] = []
	var wm := _node("WorldManager")
	var im := _node("ItemManager")
	if wm == null or im == null:
		return out
	for key in wm.world_map_tiles:
		var tile: Dictionary = wm.world_map_tiles[key]
		if String(tile.get("poi_type", "")) != "dungeon":
			continue
		if bool(tile.get("tutorial_dungeon", false)) or bool(tile.get("discovered", false)):
			continue
		if String(key) in im.ozan_sung_dungeon_keys:
			continue
		out.append(String(key))
	return out


## Rastgele bir zindan seçer ve ipucunu döndürür:
## {"dungeon_key", "theme", "dir_key", "dist_key"}; anlatılacak zindan kalmadıysa boş sözlük.
static func pick_clue() -> Dictionary:
	var keys := candidate_keys()
	if keys.is_empty():
		return {}
	var wm := _node("WorldManager")
	var village := _village_pos(wm)
	if village.is_empty():
		return {}
	var key: String = keys[randi() % keys.size()]
	var tile: Dictionary = wm.world_map_tiles[key]
	return clue_for(village, tile, key)


## Köy ile zindan karosundan ipucu üretir (test edilebilsin diye ayrı).
static func clue_for(village: Dictionary, tile: Dictionary, key: String) -> Dictionary:
	var dq: int = int(tile.get("q", 0)) - int(village.get("q", 0))
	var dr: int = int(tile.get("r", 0)) - int(village.get("r", 0))
	# Düz tepeli hex ekranı (WorldMapScene._axial_to_pixel): x ~ 1.5q, y ~ sqrt3 * (r + q/2)
	var x: float = 1.5 * float(dq)
	var y: float = 1.7320508 * (float(dr) + float(dq) * 0.5)
	var sector: int = posmod(int(round(atan2(y, x) / (PI / 4.0))), 8)
	var dist: int = (absi(dq) + absi(dr) + absi(dq + dr)) / 2
	var dist_key := "ozan.dist.far"
	if dist <= DIST_NEAR_MAX:
		dist_key = "ozan.dist.near"
	elif dist <= DIST_MID_MAX:
		dist_key = "ozan.dist.mid"
	return {
		"dungeon_key": key,
		"theme": String(tile.get("dungeon_theme", "ates")),
		"dir_key": DIR_KEYS[sector],
		"dist_key": dist_key,
	}


## Türkünün söylenecek metni (tema türküsü + yön + uzaklık).
static func song_text(clue: Dictionary) -> String:
	if clue.is_empty():
		return TranslationServer.translate("ozan.none")
	var song_key := "ozan.song.%s" % String(clue.get("theme", "ates"))
	var template: String = TranslationServer.translate(song_key)
	if template == song_key:
		template = TranslationServer.translate("ozan.song.ates")
	return template % [
		TranslationServer.translate(String(clue["dir_key"])),
		TranslationServer.translate(String(clue["dist_key"])),
	]


## Türkü söylendi: zindanı "söylenmiş" listesine ekler.
static func mark_sung(clue: Dictionary) -> void:
	var im := _node("ItemManager")
	var key: String = String(clue.get("dungeon_key", ""))
	if im != null and not key.is_empty() and key not in im.ozan_sung_dungeon_keys:
		im.ozan_sung_dungeon_keys.append(key)
