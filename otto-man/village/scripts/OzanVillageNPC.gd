# OzanVillageNPC.gd
# Gezgin ozan. Yürüme/oturma/uyuma ve etkileşim iskeleti falcıyla aynı (FalciVillageNPC),
# farklı olan: başlık ve açtığı pencere (ozan türküsü: yemek karşılığı zindan ipucu).
#
# GEÇİCİ SANAT: sprite'lar şimdilik tüccarınkiler, sıcak turuncu tonla ayrışıyor. Ozanın kendi
# sheet'leri gelince OzanVillageNPC.tscn içindeki dört texture yolunu değiştirip
# _apply_placeholder_tint() çağrısını silmek yeterli.
extends "res://village/scripts/FalciVillageNPC.gd"

const OZAN_TINT := Color(1.0, 0.78, 0.5)


func _apply_placeholder_tint() -> void:
	for spr in [idle_sprite, walk_sprite, sit_sprite, sleep_sprite]:
		if is_instance_valid(spr):
			spr.modulate = OZAN_TINT


func _title_key() -> String:
	return "ozan.title"


func _open_popup(host: VillageWorldPopups) -> void:
	if host.has_method("open_ozan"):
		host.open_ozan()
