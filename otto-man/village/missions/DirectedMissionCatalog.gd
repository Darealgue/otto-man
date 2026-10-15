extends RefCounted
class_name DirectedMissionCatalog
## Oyuncunun haritada hex seçerek cariye yolladığı görevlerin şablonları.
## Rol (Concubine.Role) + hedef türü -> seçenek listesi. Bkz. docs/CONCUBINE_MAP_MISSIONS_PLAN.md.
##
## Hedef türleri (target_kind):
##   "fog"       keşfedilmemiş hex (yalnız Ajan)
##   "village"   komşu köy
##   "dungeon"   zindan
##   "challenge" harita meydan okuması
##   "landmark"  harita simgesi (harabe, kervan, mülteci)
##   "camp"      haydut kampı (poi_type == "bandit_camp")
##   "wild"      boş arazi (ova/orman/dağ/akarsu)
##
## Her seçenek bir Dictionary:
##   id, title (tr anahtarı), desc (tr anahtarı), mission_type, difficulty,
##   base_minutes + per_hex_minutes (süre), chance (taban başarı), rewards, penalties,
##   soldiers {min, max, rec} (yoksa 0 = asker sormaz), gift {res, step, max} (yoksa hediye sormaz),
##   executor, effect (MissionManager._apply_directed_effect okur).

const KIND_FOG := "fog"
const KIND_VILLAGE := "village"
const KIND_DUNGEON := "dungeon"
const KIND_CHALLENGE := "challenge"
const KIND_LANDMARK := "landmark"
const KIND_CAMP := "camp"
const KIND_WILD := "wild"
const KIND_HOME := "home"

## match kalıplarında sabit olarak kullanılabilsin diye rol sabitleri.
const R_NONE := Concubine.Role.NONE
const R_KOMUTAN := Concubine.Role.KOMUTAN
const R_AJAN := Concubine.Role.AJAN
const R_DIPLOMAT := Concubine.Role.DİPLOMAT
const R_TUCCAR := Concubine.Role.TÜCCAR
const R_TIBBIYECI := Concubine.Role.TIBBIYECI

const EXEC_CARIYE_ONLY := "cariye_only"
const EXEC_PLAYER_OR_KOMUTAN := "player_or_komutan"

## Rol rengi: seçim çerçevesi ve haritadaki cariye rotası aynı rengi kullanır (oyuncu rotası beyaz).
static func role_color(role: int, fallback: Color = Color(0.95, 0.55, 0.2)) -> Color:
	match role:
		R_KOMUTAN:
			return Color(0.95, 0.4, 0.35)
		R_AJAN:
			return Color(0.72, 0.5, 0.95)
		R_DIPLOMAT:
			return Color(0.45, 0.7, 1.0)
		R_TUCCAR:
			return Color(1.0, 0.82, 0.3)
		R_TIBBIYECI:
			return Color(0.45, 0.95, 0.85)
	return fallback


## Hex'in tile sözlüğünden hedef türü. discovered=false ise poi_type ASLA okunmaz (sis sızdırmasın).
static func target_kind_for_tile(tile: Dictionary) -> String:
	if tile.is_empty():
		return ""
	if not bool(tile.get("discovered", false)):
		return KIND_FOG
	var poi: String = String(tile.get("poi_type", ""))
	match poi:
		"player_village":
			return KIND_HOME
		"neighbor_village":
			return KIND_VILLAGE
		"dungeon":
			return KIND_DUNGEON
		"challenge":
			return KIND_CHALLENGE
		"bandit_camp":
			return KIND_CAMP
	if poi.begins_with("landmark_"):
		return KIND_LANDMARK
	if String(tile.get("terrain_type", "")) == "deniz":
		return ""
	return KIND_WILD


## Seçenekler. Rol/hedef kombinasyonunda hiçbir şey yoksa boş dizi (UI "bu hedefe yollanamaz" der).
static func get_options(role: int, target_kind: String, tile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var terrain: String = String(tile.get("terrain_type", "ova"))
	var MT := Mission.MissionType
	var DF := Mission.Difficulty

	if target_kind == KIND_FOG:
		if role == R_AJAN:
			out.append(_opt("agent_scout_fog", MT.KEŞİF, DF.ORTA, 150, 50, 0.62,
				{"reputation": 1}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, "reveal:3"))
		return out

	match target_kind:
		KIND_VILLAGE:
			match role:
				R_AJAN:
					out.append(_opt("agent_intel_village", MT.İSTİHBARAT, DF.ORTA, 150, 40, 0.66,
						{"reputation": 1}, {"reputation": -1}, {}, {}, EXEC_CARIYE_ONLY, "reveal:3"))
				R_DIPLOMAT:
					out.append(_opt("diplomat_gift", MT.DİPLOMASİ, DF.KOLAY, 150, 40, 0.74,
						{"reputation": 1}, {"reputation": -1}, {},
						{"res": "gold", "step": 5, "max": 100}, EXEC_CARIYE_ONLY, "relation:2"))
					out.append(_opt("diplomat_treaty", MT.DİPLOMASİ, DF.ORTA, 210, 50, 0.6,
						{"reputation": 2}, {"gold": -10, "reputation": -2}, {},
						{"res": "gold", "step": 10, "max": 100}, EXEC_CARIYE_ONLY, "relation:4"))
					# Köylü devşirme: altın ve köy ilişkisi harcar. Kişi başı 30 altın, her kişi için
					# ilişki -3; köyle ilişki en az 20 olmalı, aynı köyden 7 günde bir alınır.
					var recruit: Dictionary = _opt("diplomat_recruit", MT.DİPLOMASİ, DF.ORTA, 210, 50, 0.62,
						{}, {"reputation": -1}, {},
						{"res": "gold", "step": 30, "max": 90}, EXEC_CARIYE_ONLY, "recruit")
					recruit["recruit_gold_per"] = 30
					recruit["recruit_relation_per"] = 3
					recruit["relation_min"] = 20
					out.append(recruit)
				R_TUCCAR:
					# Köydeki malı komşu köye satar: altın kazancı = miktar x birim değer x ilişki x
					# cariyenin ticaret yeteneği/seviyesi (MissionManager._directed_sell_rate).
					# Birim değerler işçi verimine göre: odun/taş işçi başına günde 1, yiyecek 4.
					for good in [["wood", 1.0], ["stone", 1.5], ["food", 0.5]]:
						var deal: Dictionary = _opt("trader_sell_" + String(good[0]), MT.TİCARET, DF.ORTA, 180, 45, 0.72,
							{}, {"gold": -8}, {},
							{"res": String(good[0]), "step": 5, "max": 60}, EXEC_CARIYE_ONLY, "relation:1;trade_boost")
						deal["sell_value"] = float(good[1])
						out.append(deal)
					# Altınla mal da alabilir: alış fiyatı satış fiyatının iki katı, al-sat altın üretmez.
					for buy in [["wood", 3.0], ["stone", 4.0]]:
						var purchase: Dictionary = _opt("trader_buy_" + String(buy[0]), MT.TİCARET, DF.KOLAY, 150, 40, 0.78,
							{}, {"gold": -5}, {},
							{"res": "gold", "step": 10, "max": 100}, EXEC_CARIYE_ONLY, "")
						purchase["buy_item"] = String(buy[0])
						purchase["buy_price"] = float(buy[1])
						out.append(purchase)
				R_KOMUTAN:
					out.append(_opt("commander_support", MT.SAVAŞ, DF.ORTA, 150, 40, 0.68,
						{"reputation": 1}, {"army_losses": 1}, {"min": 1, "max": -1, "rec": 3}, {},
						EXEC_CARIYE_ONLY, "relation:2"))
					# Yağma: ganimet getirir ama köyle ilişkiyi ciddi bozar ve kayıp verdirir.
					var raid: Dictionary = _opt("commander_raid_village", MT.SAVAŞ, DF.ZOR, 180, 45, 0.55,
						{"gold": 25, "wood": 4, "stone": 3, "food": 8}, {"army_losses": 2, "cariye_injured": true},
						{"min": 3, "max": -1, "rec": 6}, {}, EXEC_PLAYER_OR_KOMUTAN, "relation:-8")
					raid["loot_scale"] = true
					out.append(raid)
				R_TIBBIYECI:
					out.append(_opt("medic_aid_village", MT.DİPLOMASİ, DF.KOLAY, 150, 40, 0.78,
						{"reputation": 1}, {"reputation": -1}, {},
						{"res": "medicine", "step": 1, "max": 10}, EXEC_CARIYE_ONLY, "relation:2"))
				_:
					out.append(_opt("none_envoy", MT.DİPLOMASİ, DF.KOLAY, 180, 45, 0.6,
						{"reputation": 1}, {"reputation": -1}, {}, {}, EXEC_CARIYE_ONLY, "relation:1"))
		KIND_DUNGEON:
			match role:
				R_AJAN:
					out.append(_opt("agent_infiltrate", MT.İSTİHBARAT, DF.ZOR, 180, 50, 0.58,
						{"reputation": 2}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, "dungeon_infiltrate"))
				R_KOMUTAN:
					out.append(_opt("commander_clear_dungeon", MT.SAVAŞ, DF.ZOR, 210, 50, 0.55,
						{"gold": 30}, {"army_losses": 2, "cariye_injured": true}, {"min": 2, "max": -1, "rec": 5}, {},
						EXEC_CARIYE_ONLY, "dungeon_clear"))
				_:
					out.append(_opt("any_scout_dungeon", MT.KEŞİF, DF.ORTA, 180, 50, 0.5,
						{"reputation": 1}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, ""))
		KIND_CHALLENGE, KIND_CAMP:
			var is_camp: bool = target_kind == KIND_CAMP
			if role == R_KOMUTAN:
				out.append(_opt("commander_clear_camp" if is_camp else "commander_challenge", MT.SAVAŞ, DF.ZOR, 210, 50, 0.58,
					{"gold": 40, "reputation": 2}, {"army_losses": 2, "cariye_injured": true},
					{"min": 2, "max": -1, "rec": 5}, {}, EXEC_PLAYER_OR_KOMUTAN, "camp_clear" if is_camp else "challenge_clear"))
			elif role == R_AJAN:
				out.append(_opt("agent_watch_camp" if is_camp else "agent_watch_challenge", MT.İSTİHBARAT, DF.ORTA, 150, 40, 0.65,
					{"reputation": 1}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, "reveal:2"))
			elif role == R_DIPLOMAT and is_camp:
				out.append(_opt("diplomat_parley", MT.DİPLOMASİ, DF.ZOR, 180, 45, 0.45,
					{"gold": 15, "reputation": 1}, {"gold": -15, "cariye_injured": true}, {},
					{"res": "gold", "step": 10, "max": 100}, EXEC_CARIYE_ONLY, ""))
		KIND_LANDMARK:
			if role == R_AJAN or role == R_NONE:
				out.append(_opt("any_inspect_landmark", MT.KEŞİF, DF.KOLAY, 120, 40, 0.75,
					{"gold": 8, "reputation": 1}, {}, {}, {}, EXEC_CARIYE_ONLY, "reveal:2"))
			elif role == R_TIBBIYECI:
				out.append(_opt("medic_help_landmark", MT.DİPLOMASİ, DF.KOLAY, 120, 40, 0.78,
					{"reputation": 2}, {}, {}, {"res": "medicine", "step": 1, "max": 10}, EXEC_CARIYE_ONLY, ""))
			elif role == R_TUCCAR:
				var barter: Dictionary = _opt("trader_landmark", MT.TİCARET, DF.KOLAY, 120, 40, 0.72,
					{}, {"gold": -5}, {}, {"res": "food", "step": 5, "max": 40}, EXEC_CARIYE_ONLY, "")
				barter["sell_value"] = 0.5
				out.append(barter)
			elif role == R_DIPLOMAT:
				out.append(_opt("diplomat_landmark", MT.DİPLOMASİ, DF.KOLAY, 120, 40, 0.72,
					{"reputation": 2}, {}, {}, {}, EXEC_CARIYE_ONLY, ""))
			elif role == R_KOMUTAN:
				out.append(_opt("commander_guard_landmark", MT.SAVAŞ, DF.KOLAY, 120, 40, 0.75,
					{"gold": 15, "reputation": 1}, {"army_losses": 1}, {"min": 1, "max": -1, "rec": 2}, {},
					EXEC_PLAYER_OR_KOMUTAN, ""))
		KIND_WILD:
			var res_a: String = "wood"
			if terrain == "dag":
				res_a = "stone"
			elif terrain == "ova":
				res_a = "food"
			match role:
				R_AJAN:
					out.append(_opt("agent_scout_wild", MT.KEŞİF, DF.KOLAY, 120, 35, 0.78,
						{"reputation": 1}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, "reveal:3"))
				R_KOMUTAN:
					# Boş arazide komutanın kaynak topladığı görev yok: yalnız bir köyün
					# toprağında (yakın komşu köy varsa) yağma yapılır, köyle ilişki bozulur.
					if String(tile.get("near_settlement_id", "")) != "":
						var pillage: Dictionary = _opt("commander_pillage_land", MT.SAVAŞ, DF.ORTA, 150, 40, 0.62,
							{res_a: _wild_yield(res_a, 1.0)}, {"army_losses": 1, "cariye_injured": true},
							{"min": 2, "max": -1, "rec": 4}, {}, EXEC_PLAYER_OR_KOMUTAN, "relation:-3")
						pillage["loot_scale"] = true
						out.append(pillage)
				R_TUCCAR:
					out.append(_opt("trader_route", MT.TİCARET, DF.KOLAY, 150, 40, 0.72,
						{"gold": 10}, {"gold": -5}, {}, {}, EXEC_CARIYE_ONLY, ""))
				R_TIBBIYECI:
					if terrain == "orman" or terrain == "dag" or terrain == "akarsu":
						out.append(_opt("medic_herbs", MT.KEŞİF, DF.KOLAY, 150, 40, 0.76,
							{"medicine": 3}, {}, {}, {}, EXEC_CARIYE_ONLY, ""))
				R_DIPLOMAT:
					pass
				_:
					out.append(_opt("none_scout_wild", MT.KEŞİF, DF.KOLAY, 120, 40, 0.7,
						{"reputation": 1}, {"cariye_injured": true}, {}, {}, EXEC_CARIYE_ONLY, "reveal:2"))
	return out


## Boş arazide bir görevin getirdiği temel kaynak. Ölçü: bir köylü günde 1 odun/taş ya da 4 yiyecek
## toplar, köylü başına günde 1 yiyecek yenir; bir görev yaklaşık 3 işçi-günü kadar getirir
## (ödül mesafeyle en çok x1.6). Ağır işi kaynak görevleri yapmasın, binalar baş yol kalsın.
static func _wild_yield(res: String, mult: float) -> int:
	var base: float = 6.0 if res == "food" else 3.0
	return maxi(1, int(round(base * mult)))


static func _opt(id: String, mission_type: int, difficulty: int, base_min: float, per_hex_min: float,
		chance: float, rewards: Dictionary, penalties: Dictionary, soldiers: Dictionary,
		gift: Dictionary, executor: String, effect: String) -> Dictionary:
	return {
		"id": id,
		"title_key": "dm.opt.%s.title" % id,
		"desc_key": "dm.opt.%s.desc" % id,
		"mission_type": mission_type,
		"difficulty": difficulty,
		"base_minutes": base_min,
		"per_hex_minutes": per_hex_min,
		"chance": chance,
		"rewards": rewards,
		"penalties": penalties,
		"soldiers": soldiers,
		"gift": gift,
		"executor": executor,
		"effect": effect,
	}
