extends Node
## Köy roguelite kart sistemi — mekanik efekt katmanı.
## VillageCardManager sadece hangi kartların alındığını tutar (SSOT: docs/VILLAGE_ROGUELITE_CARDS.md).
## Bu dosya o kartların gerçek oyun etkisini var olan sistemlere bağlar: moral, üretim,
## depo, konut, inşa, savaş (CombatResolver), yağma (WorldManager), cariye görevleri.
##
## Bazı kartların tam açıklaması (bina-bazlı serbest asker üretimi, oyuncunun seçtiği
## bir ham kaynak, yeni bina türleri vb.) bu sistemlerde karşılığı olmayan altyapı ister;
## bu kartlar en yakın güvenli mekanik karşılığa (nüfus/kaynak/moral/altın etkisi)
## indirgendi — davranış kalıcı ve test edilebilir, sadece anlatı biraz sadeleşti.

signal state_changed

# ---- Autoload erişimi (sıra bağımlılığından kaçınmak için cache'lemiyoruz) ----
func _cm() -> Node: return get_node_or_null("/root/VillageCardManager")
func _vm() -> Node: return get_node_or_null("/root/VillageManager")
func _wm() -> Node: return get_node_or_null("/root/WorldManager")
func _mm() -> Node: return get_node_or_null("/root/MissionManager")
func _gpd() -> Node: return get_node_or_null("/root/GlobalPlayerData")
func _tm() -> Node: return get_node_or_null("/root/TimeManager")

func has_card(id: String) -> bool:
	var cm := _cm()
	return cm != null and cm.has_card(id)

func path() -> String:
	var cm := _cm()
	return cm.chosen_path if cm else ""

func _population() -> int:
	var vm := _vm()
	return int(vm.total_workers) if vm else 0

func _morale() -> float:
	var vm := _vm()
	return float(vm.village_morale) if vm else 80.0

func _add_gold(amount: int) -> void:
	var gpd := _gpd()
	if gpd:
		gpd.add_gold(amount)

func _gold() -> int:
	var gpd := _gpd()
	return int(gpd.gold) if gpd else 0

func _add_villager() -> void:
	var vm := _vm()
	if vm:
		vm.total_workers += 1
		vm.idle_workers += 1

func _add_resource(resource_type: String, amount: int) -> void:
	var vm := _vm()
	if vm and amount != 0:
		vm.resource_levels[resource_type] = max(0, int(vm.resource_levels.get(resource_type, 0)) + amount)


func _ready() -> void:
	var tm := _tm()
	if tm and tm.has_signal("day_changed") and not tm.day_changed.is_connected(_on_day_changed):
		tm.day_changed.connect(_on_day_changed)
	var cm := _cm()
	if cm and cm.has_signal("card_taken") and not cm.card_taken.is_connected(_on_card_taken):
		cm.card_taken.connect(_on_card_taken)


func _on_card_taken(card: Dictionary) -> void:
	var cid := String(card.get("id", ""))
	match cid:
		"pasa_sirca_kosk":
			_sirca_kosk_pending = true
		"pasa_rehin_diplomasi":
			_try_rehin_diplomasi()
		"pasa_sahte_skandal":
			_try_sahte_skandal()


# ============================================================
# MORAL
# ============================================================

## VillageManager._get_morale_multiplier()'ın son değerini filtreler.
func get_morale_multiplier(base: float) -> float:
	if has_card("pasa_sadakat_yemini"):
		return 1.0
	return base


## Moral değişimlerini (delta negatifse kayıp) kart etkisine göre yumuşat/sertleştir.
## context: "raid_loss" | "battle_loss" | "raid_win" | "battle_win" | "shortage"
func adjust_morale_delta(delta: float, context: String) -> float:
	if delta < 0.0 and (context == "raid_loss" or context == "battle_loss"):
		if has_card("eskiya_savasci_ruhu"):
			return 0.0
		if has_card("eskiya_safak_vakti_kacisi"):
			delta *= 1.6
		elif has_card("eskiya_dilemma_sadik_cete"):
			delta *= 0.5
	return delta


func get_morale_ceiling() -> float:
	return 70.0 if has_card("koylu_siki_disiplin") else 100.0


func get_morale_floor() -> float:
	if _feast_floor_until_day > _current_day():
		return 55.0
	return 30.0 if has_card("koylu_siki_disiplin") else 0.0


# ============================================================
# ÜRETİM
# ============================================================

## VillageManager'ın 3 üretim yolunda da resource_prod_multiplier ile çarpılan ek katsayı.
func get_resource_production_multiplier(resource_type: String) -> float:
	var mult := 1.0
	if has_card("koylu_ortak_kader"):
		mult *= 1.0 + clamp(0.005 * float(_population()), 0.0, 0.5)
	if has_card("koylu_herkes_icin_bir_sey") and _morale() >= 60.0:
		mult *= 1.15
	if has_card("koylu_siki_disiplin"):
		mult *= 1.1
	if has_card("koylu_nadas_bilgisi") and resource_type in ["wood", "stone", "food"]:
		mult *= 1.0 + _nadas_bonus
	if has_card("koylu_genis_tarla") and resource_type == "food":
		mult *= 1.15
	if has_card("koylu_saray_emrinde") and resource_type == "bread":
		mult *= 1.1
	if has_card("koylu_nesil_bilgisi"):
		mult *= 1.0 + _nesil_bonus
	if _yabanci_misafir_resource == resource_type and _current_day() < _yabanci_misafir_until_day:
		mult *= 2.0
	if has_card("koylu_dilemma_kutsal_toprak") and resource_type == KUTSAL_TOPRAK_RESOURCE:
		mult *= 1.3
	return mult


# ============================================================
# KONUT / DEPO
# ============================================================

func get_housing_capacity_per_floor_bonus() -> int:
	return 2 if has_card("eskiya_baraka_duzeni") else 0


func get_storage_capacity_multiplier() -> float:
	return 1.5 if has_card("koylu_kis_ambari") else 1.0


# ============================================================
# İNŞA
# ============================================================

func get_build_cost_multiplier() -> float:
	var mult := 1.0
	if has_card("koylu_saglam_temeller"):
		mult *= 0.5
	if has_card("pasa_vergi_reformu"):
		mult *= 2.0  # altın maliyeti katlanır (karşılığında kaynak istemez, bkz. get_build_resource_cost_waived)
	return mult


func get_build_resource_cost_waived() -> bool:
	return has_card("pasa_vergi_reformu")


func get_build_time_multiplier() -> float:
	var mult := 1.0
	if has_card("koylu_saglam_temeller"):
		mult *= 2.0
	if has_card("koylu_ortaklasa_insaat"):
		mult *= 0.85
	return mult


## Vergi Muafiyeti: bir kez, sıradaki inşaatı bedava yapar. Tüketildiğinde true döner.
func try_consume_free_build() -> bool:
	if has_card("pasa_vergi_muafiyeti") and not _vergi_muafiyeti_used:
		_vergi_muafiyeti_used = true
		state_changed.emit()
		return true
	return false


## try_consume_free_build ile aynı koşulu kontrol eder ama TÜKETMEZ — sadece önizleme/UI
## fiyat gösterimi için (örn. inşa popup'ı gerçek maliyeti göstersin diye).
func has_pending_free_build() -> bool:
	return has_card("pasa_vergi_muafiyeti") and not _vergi_muafiyeti_used


# ============================================================
# SAVAŞ (CombatResolver.resolve_battle içinden çağrılır)
# ============================================================

## attacker_stats/defender_stats: _calculate_force_stats sonuçları (dict, mutasyona açık kopyalar).
## attacker/defender: force dict'leri (is_player_force taşıyabilir).
## Döndürdüğü {"attacker": stats, "defender": stats} resolve_battle'a geri yazılır.
func modify_battle_stats(attacker_stats: Dictionary, defender_stats: Dictionary, attacker: Dictionary, defender: Dictionary) -> Dictionary:
	var a := attacker_stats.duplicate()
	var d := defender_stats.duplicate()
	var player_is_attacker: bool = bool(attacker.get("is_player_force", false))
	var player_is_defender: bool = bool(defender.get("is_player_force", false))

	if player_is_attacker and has_card("eskiya_deli_cesaret") and int(a.get("unit_count", 0)) < int(d.get("unit_count", 0)):
		a["total_attack"] = float(a.get("total_attack", 0.0)) * 2.0
	if player_is_defender and has_card("eskiya_deli_cesaret") and int(d.get("unit_count", 0)) < int(a.get("unit_count", 0)):
		d["total_attack"] = float(d.get("total_attack", 0.0)) * 2.0

	if player_is_attacker and _zafer_ruzgari_until_day > _current_day():
		a["total_attack"] = float(a.get("total_attack", 0.0)) * 1.3
	if player_is_defender and has_card("pasa_dilemma_kendi_ordun"):
		d["total_attack"] = float(d.get("total_attack", 0.0)) * 1.1
		d["total_defense"] = float(d.get("total_defense", 0.0)) * 1.1

	return {"attacker": a, "defender": d}


## losses: {"attacker": int, "defender": int}. battle_result: {"victor": "attacker"|"defender", ...}
func modify_battle_losses(losses: Dictionary, attacker: Dictionary, defender: Dictionary, battle_result: Dictionary) -> Dictionary:
	var out := losses.duplicate()
	var player_is_attacker: bool = bool(attacker.get("is_player_force", false))
	var player_is_defender: bool = bool(defender.get("is_player_force", false))
	var victor := String(battle_result.get("victor", "defender"))
	var player_lost: bool = (player_is_attacker and victor != "attacker") or (player_is_defender and victor != "defender")
	var player_won: bool = (player_is_attacker and victor == "attacker") or (player_is_defender and victor == "defender")
	var player_loss_key := "attacker" if player_is_attacker else "defender"
	var enemy_loss_key := "defender" if player_is_attacker else "attacker"

	if player_lost and has_card("eskiya_safak_vakti_kacisi"):
		out[player_loss_key] = int(round(float(out.get(player_loss_key, 0)) * 0.3))
	if player_lost and has_card("eskiya_kurt_kardesligi"):
		var saved: int = int(out.get(player_loss_key, 0))
		out[player_loss_key] = 0
		for i in range(saved):
			_add_villager()
	if _mercenary_backup_active():
		out[player_loss_key] = int(round(float(out.get(player_loss_key, 0)) * 0.6))

	if player_won and has_card("eskiya_kesik_kulak"):
		var captured: int = int(round(float(out.get(enemy_loss_key, 0)) * 0.2))
		for i in range(captured):
			_add_villager()
	if player_won and has_card("eskiya_kolelik_duzeni"):
		var enslaved: int = int(round(float(out.get(enemy_loss_key, 0)) * 0.15))
		for i in range(enslaved):
			_add_villager()

	return out


func modify_battle_gains(gains: Dictionary, attacker: Dictionary, defender: Dictionary, battle_result: Dictionary) -> Dictionary:
	var player_is_attacker: bool = bool(attacker.get("is_player_force", false))
	var player_is_defender: bool = bool(defender.get("is_player_force", false))
	var victor := String(battle_result.get("victor", "defender"))
	var player_won: bool = (player_is_attacker and victor == "attacker") or (player_is_defender and victor == "defender")
	if player_won and has_card("eskiya_silah_kacakciligi"):
		_add_resource("weapon_t1", randi_range(2, 5))
	return gains


func _mercenary_backup_active() -> bool:
	return has_card("eskiya_dilemma_parali_kiliclar") and _mercenaries_paid_this_week


# ============================================================
# YAĞMA — gelen saldırı (WorldManager._process_defense_result)
# ============================================================

## Bir kayıp öncesi çağrılır; rüşvetle iptal edilirse true döner (çağıran gold_loss/morale_delta'yı sıfırlar).
func try_bribe_incoming_raid() -> bool:
	if not has_card("pasa_altin_kalkani"):
		return false
	var cost: int = 80
	if has_card("pasa_rusvet_agi"):
		cost = int(cost * 0.6)
	if _gold() < cost:
		return false
	_add_gold(-cost)
	if has_card("pasa_rusvet_agi") and randf() < 0.15:
		var vm := _vm()
		if vm:
			vm.village_morale = max(0.0, vm.village_morale - 5.0)
	return true


## _process_defense_result içinde gold_loss/morale_delta hesaplandıktan sonra çağrılır.
func modify_defense_result(gold_loss: int, morale_delta: int) -> Dictionary:
	if has_card("pasa_hazine_odasi"):
		gold_loss = 0
		var vm := _vm()
		if vm:
			for res in ["wood", "stone", "food"]:
				var cur: int = int(vm.resource_levels.get(res, 0))
				vm.resource_levels[res] = max(0, cur - int(cur * 0.1))
	if has_card("koylu_tas_siper"):
		gold_loss = int(gold_loss * 0.85)
	morale_delta = int(round(adjust_morale_delta(float(morale_delta), "raid_loss")))
	return {"gold_loss": gold_loss, "morale_delta": morale_delta}


## _get_attacker_force_for_defense içinde base_strength hesaplandıktan sonra çağrılır.
func modify_incoming_attacker_strength(base_strength: float) -> float:
	if has_card("pasa_sahte_zenginlik"):
		base_strength *= 0.85
	if has_card("pasa_nufuz_agi"):
		base_strength *= 0.92
	if has_card("koylu_tas_siper"):
		base_strength *= 0.95
	if _assassination_debuff_active:
		_assassination_debuff_active = false
		base_strength *= 0.5
	if has_card("pasa_sasaa_gosterisi"):
		if randf() < 0.15:
			base_strength *= 1.4  # hazırlıksız yakalanma cezası
		else:
			base_strength *= 0.9  # şaşaa gösterisi dikkat dağıtır
	return base_strength


## _check_shortages_and_apply_morale_penalties içinde ceza uygulanmadan önce çağrılır.
func soften_shortage_penalty(penalty: float) -> float:
	if penalty > 0.0 and has_card("koylu_ortak_ekin"):
		var vm := _vm()
		if vm:
			var wood: int = int(vm.resource_levels.get("wood", 0))
			var stone: int = int(vm.resource_levels.get("stone", 0))
			if wood >= 2 and stone >= 2:
				vm.resource_levels["wood"] = wood - 2
				vm.resource_levels["stone"] = stone - 2
				penalty *= 0.5
	return penalty


func notify_combat_occurred() -> void:
	_days_since_combat = 0


# ============================================================
# YAĞMA — giden saldırı (MissionManager.process_mission_results, raid tipi görevler)
# ============================================================

## Baskın (raid) görevi başarıyla tamamlanınca, altın ödülü uygulanmadan hemen önce çağrılır.
func modify_raid_mission_gold(amount: int) -> int:
	var gold := float(amount)
	if has_card("eskiya_kan_borcu"):
		gold *= 2.0
		if randf() < 0.2:
			_pending_retaliation = true
	if has_card("eskiya_talan_izni"):
		gold *= 0.7
		var vm := _vm()
		if vm:
			vm.village_morale = min(get_morale_ceiling(), vm.village_morale + 1.0)
	if has_card("eskiya_ates_ve_kul"):
		gold *= 0.8
	if has_card("eskiya_golgede_saklanma"):
		gold *= 0.9
	if has_card("eskiya_maskeli_soyguncular"):
		gold *= 1.2
	if has_card("eskiya_dilemma_tek_vurus"):
		gold *= 0.6
	if has_card("eskiya_dilemma_uzun_kusatma"):
		gold *= 1.8
	if has_card("eskiya_dilemma_karaborsa"):
		var diverted := gold * 0.4
		gold -= diverted
		_add_resource("wood", int(diverted / 4.0))
		_add_resource("stone", int(diverted / 4.0))
	_tefeci_ledger += gold * 0.05
	return int(gold)


## Baskın görevi başarıyla tamamlanınca (ödüller uygulandıktan sonra) çağrılır.
func notify_raid_mission_success() -> void:
	notify_combat_occurred()
	if has_card("eskiya_zafer_ruzgari"):
		_zafer_ruzgari_until_day = _current_day() + 3
	if has_card("eskiya_capulcu_sohreti"):
		notify_offensive_raid_success()


# ============================================================
# CARİYE GÖREVLERİ
# ============================================================

func get_mission_success_bonus(mission_type: int) -> float:
	# Mission.MissionType: SAVAŞ=0, KEŞİF=1, DİPLOMASİ=2, TİCARET=3, İSTİHBARAT=4, BÜROKRASİ=5
	var bonus := 0.0
	if has_card("pasa_harem_siyaseti"):
		var mm := _mm()
		var count: int = int(mm.concubines.size()) if mm and "concubines" in mm else 0
		bonus += clamp(0.01 * float(count), 0.0, 0.15)
	match mission_type:
		2:  # DİPLOMASİ
			if has_card("pasa_elcilik"):
				bonus += 0.5
			if has_card("pasa_altinla_gecis"):
				bonus += 0.05
		4:  # İSTİHBARAT
			if has_card("pasa_casus_yuvasi"):
				bonus += 0.15
			if has_card("eskiya_golge_agi"):
				bonus += 0.2
		0:  # SAVAŞ (yağma görevleri de bu tipte)
			if has_card("eskiya_gece_baskini"):
				bonus += 0.15
		3:  # TİCARET
			if has_card("pasa_pazar_yeri"):
				bonus += 0.08
	return bonus


func get_trade_success_bonus() -> float:
	return get_mission_success_bonus(3)


## eskiya_dilemma_midas_eli ve koylu_dilemma_acik_pazar bilinçli olarak nötr/karşılaştırma
## tabanı: SSOT'ta da "—" / "nötr, esnek" olarak tanımlı, ek mekanik gerektirmiyor.


# ============================================================
# GÜNLÜK / HAFTALIK MİNİ SİSTEMLER (Dalga 2)
# ============================================================

var _nadas_bonus: float = 0.0
var _nesil_bonus: float = 0.0
var _nesil_streak_days: int = 0
var _last_population_snapshot: int = -1
var _days_since_combat: int = 0
var _fame_points: float = 0.0
var _tefeci_ledger: float = 0.0
var _mercenaries_paid_this_week: bool = false
var _zafer_ruzgari_until_day: int = -999
var _yabanci_misafir_until_day: int = -999
var _yabanci_misafir_resource: String = ""
var _feast_floor_until_day: int = -999
var _vergi_muafiyeti_used: bool = false
var _sirca_kosk_pending: bool = false
var _sirca_kosk_built: bool = false
var _assassination_debuff_active: bool = false
var _pending_retaliation: bool = false
var _last_day: int = 0

func _current_day() -> int:
	return _last_day


func notify_offensive_raid_success() -> void:
	if has_card("eskiya_capulcu_sohreti"):
		_fame_points += 1.0


func notify_successful_defense() -> void:
	notify_combat_occurred()


func _on_day_changed(new_day: int) -> void:
	_last_day = new_day
	_days_since_combat += 1
	_handle_daily_cards(new_day)
	if new_day % 7 == 0:
		_handle_weekly_cards(new_day)
	if _pending_retaliation:
		_pending_retaliation = false
		var wm := _wm()
		if wm and wm.has_method("_trigger_village_raid") and randf() < 0.5:
			wm.call("_trigger_village_raid", "Kan Davası Güttükleri", new_day)
	state_changed.emit()


func _handle_daily_cards(day: int) -> void:
	if has_card("eskiya_savasci_ruhu") and _days_since_combat >= 3:
		var vm := _vm()
		if vm:
			vm.village_morale = max(get_morale_floor(), vm.village_morale - 3.0)
		_days_since_combat = 0

	if has_card("eskiya_kanun_kacagi_cenneti") and randf() < 0.08:
		_add_villager()
		var vm2 := _vm()
		if vm2:
			vm2.village_morale = max(get_morale_floor(), vm2.village_morale - 1.0)

	if has_card("koylu_gocmen_kapisi") and randf() < 0.10:
		_add_villager()
		_add_resource("food", -2)

	if has_card("koylu_bereket_duasi") and randf() < 0.15:
		var pool := ["wood", "stone", "food"]
		_add_resource(pool[randi() % pool.size()], 1)

	if has_card("eskiya_capulcu_sohreti") and _fame_points >= 5.0:
		_fame_points = 0.0
		_add_villager()

	if has_card("koylu_nesil_bilgisi"):
		var pop := _population()
		if pop == _last_population_snapshot:
			_nesil_streak_days += 1
			if _nesil_streak_days >= 10:
				_nesil_bonus = min(0.3, _nesil_bonus + 0.02)
		else:
			_nesil_streak_days = 0
			_nesil_bonus = 0.0
		_last_population_snapshot = pop

	if (has_card("pasa_comert_efendi") or has_card("koylu_emegin_karsiligi")) and _gold() >= 3:
		_add_gold(-3)
		var vm3 := _vm()
		if vm3:
			vm3.village_morale = min(get_morale_ceiling(), vm3.village_morale + 1.0)

	if (has_card("pasa_debbag_vergisi") or has_card("pasa_loncalar_vergisi")) and path() == "pasa":
		_add_gold(3)

	if has_card("pasa_yabanci_misafir") and day % 6 == 0:
		var pool2 := ["wood", "stone", "food", "lumber", "brick"]
		_yabanci_misafir_resource = pool2[randi() % pool2.size()]
		_yabanci_misafir_until_day = day + 3

	if has_card("pasa_tefeci_defteri"):
		_tefeci_ledger += 1.0
		if _tefeci_ledger >= 500.0:
			_tefeci_ledger = 0.0
			_add_gold(150)

	if has_card("pasa_suikast_parasi") and day % 10 == 0 and not _assassination_debuff_active:
		var cost := 300
		if _gold() >= cost and randf() < 0.6:
			_add_gold(-cost)
			_assassination_debuff_active = true

	if _sirca_kosk_pending and not _sirca_kosk_built:
		var cost2 := 200
		if _gold() >= cost2:
			_add_gold(-cost2)
			_sirca_kosk_built = true
			var vm4 := _vm()
			if vm4:
				vm4.village_morale = min(100.0, vm4.village_morale + 8.0)


func _handle_weekly_cards(day: int) -> void:
	_mercenaries_paid_this_week = false
	if has_card("eskiya_dilemma_parali_kiliclar"):
		var cost := 40
		if _gold() >= cost:
			_add_gold(-cost)
			_mercenaries_paid_this_week = true
		else:
			var barracks := _find_barracks()
			if barracks and barracks.has_method("remove_soldiers"):
				barracks.remove_soldiers(1)

	if has_card("pasa_dilemma_saray_fermani"):
		var tax := 30
		var vm := _vm()
		if _gold() >= tax:
			_add_gold(-tax)
		elif vm:
			vm.village_morale = max(0.0, vm.village_morale - 6.0)

	if has_card("pasa_toren_alayi") and _gold() >= 20:
		_add_gold(-20)
		var vm2 := _vm()
		if vm2:
			vm2.village_morale = min(get_morale_ceiling(), vm2.village_morale + 5.0)
		if randf() < 0.3:
			_add_villager()

	if has_card("koylu_solen_gelenegi"):
		var vm3 := _vm()
		if vm3:
			vm3.village_morale = min(100.0, vm3.village_morale + 15.0)
		_feast_floor_until_day = day + 3

	if has_card("koylu_nadas_bilgisi"):
		_nadas_bonus = min(0.5, _nadas_bonus + 0.02)


func _find_barracks() -> Node:
	var mm := _mm()
	if mm and mm.has_method("_find_barracks"):
		return mm.call("_find_barracks")
	return null


# ============================================================
# TEK SEFERLİK OTOMATİK AKSİYONLAR (Dalga 3)
# ============================================================
# Bu kartların tam anlatımı (belirli cariyeyi seçmek, belirli düşman komutanı hedeflemek)
# özel bir seçim arayüzü ister; burada kart alınır alınmaz otomatik ve güvenli bir
# hedef seçilerek aynı mekanik sonuç (kalıcı barış / rakip zayıflatma) tetiklenir.

func _try_rehin_diplomasi() -> void:
	var wm := _wm()
	if not wm or not ("world_settlement_states" in wm):
		return
	var worst_id := ""
	var worst_rel := 999
	for sid in wm.world_settlement_states.keys():
		var sname: String = wm.call("_get_settlement_display_name", sid)
		var rel: int = wm.call("get_relation", "Köy", sname)
		if rel < worst_rel:
			worst_rel = rel
			worst_id = sid
	if worst_id == "":
		return
	var sname2: String = wm.call("_get_settlement_display_name", worst_id)
	wm.call("set_relation", "Köy", sname2, 80, true)
	var vm := _vm()
	if vm:
		vm.village_morale = max(0.0, vm.village_morale - 10.0)


func _try_sahte_skandal() -> void:
	var wm := _wm()
	if not wm or not ("world_settlement_states" in wm):
		return
	var worst_id := ""
	var worst_rel := 999
	for sid in wm.world_settlement_states.keys():
		var sname: String = wm.call("_get_settlement_display_name", sid)
		var rel: int = wm.call("get_relation", "Köy", sname)
		if rel < worst_rel:
			worst_rel = rel
			worst_id = sid
	if worst_id == "":
		return
	if randf() < 0.6:
		var state: Dictionary = wm.world_settlement_states[worst_id]
		state["stability"] = clamp(int(state.get("stability", 60)) - 15, 5, 100)
		wm.world_settlement_states[worst_id] = state
	else:
		var sname2: String = wm.call("_get_settlement_display_name", worst_id)
		wm.call("change_relation", "Köy", sname2, -10, false)


# ============================================================
# TRADER / KAYNAK KISITI (Kutsal Toprak)
# ============================================================

const KUTSAL_TOPRAK_RESOURCE := "food"

func is_resource_trade_blocked(resource_type: String) -> bool:
	return has_card("koylu_dilemma_kutsal_toprak") and resource_type == KUTSAL_TOPRAK_RESOURCE


# ============================================================
# KAYIT / YÜKLEME
# ============================================================

func serialize_for_save() -> Dictionary:
	return {
		"nadas_bonus": _nadas_bonus,
		"nesil_bonus": _nesil_bonus,
		"nesil_streak_days": _nesil_streak_days,
		"last_population_snapshot": _last_population_snapshot,
		"days_since_combat": _days_since_combat,
		"fame_points": _fame_points,
		"tefeci_ledger": _tefeci_ledger,
		"zafer_ruzgari_until_day": _zafer_ruzgari_until_day,
		"yabanci_misafir_until_day": _yabanci_misafir_until_day,
		"yabanci_misafir_resource": _yabanci_misafir_resource,
		"feast_floor_until_day": _feast_floor_until_day,
		"vergi_muafiyeti_used": _vergi_muafiyeti_used,
		"sirca_kosk_pending": _sirca_kosk_pending,
		"sirca_kosk_built": _sirca_kosk_built,
		"assassination_debuff_active": _assassination_debuff_active,
		"last_day": _last_day,
	}


func load_from_save(data: Dictionary) -> void:
	_nadas_bonus = float(data.get("nadas_bonus", 0.0))
	_nesil_bonus = float(data.get("nesil_bonus", 0.0))
	_nesil_streak_days = int(data.get("nesil_streak_days", 0))
	_last_population_snapshot = int(data.get("last_population_snapshot", -1))
	_days_since_combat = int(data.get("days_since_combat", 0))
	_fame_points = float(data.get("fame_points", 0.0))
	_tefeci_ledger = float(data.get("tefeci_ledger", 0.0))
	_zafer_ruzgari_until_day = int(data.get("zafer_ruzgari_until_day", -999))
	_yabanci_misafir_until_day = int(data.get("yabanci_misafir_until_day", -999))
	_yabanci_misafir_resource = String(data.get("yabanci_misafir_resource", ""))
	_feast_floor_until_day = int(data.get("feast_floor_until_day", -999))
	_vergi_muafiyeti_used = bool(data.get("vergi_muafiyeti_used", false))
	_sirca_kosk_pending = bool(data.get("sirca_kosk_pending", false))
	_sirca_kosk_built = bool(data.get("sirca_kosk_built", false))
	_assassination_debuff_active = bool(data.get("assassination_debuff_active", false))
	_last_day = int(data.get("last_day", 0))
	state_changed.emit()


func reset_for_new_game() -> void:
	load_from_save({})
