extends Node

# Mission System Test Script
# MissionCenter UI smoke test (placeholder görev/cariye üretmez)

func _ready():
	print("=== MISSION SYSTEM TEST BAŞLADI ===")
	
	var mission_manager = get_node("/root/MissionManager")
	if mission_manager:
		print("✅ MissionManager bulundu")
		test_mission_center()
	else:
		print("❌ MissionManager bulunamadı!")

func test_mission_center():
	print("--- MissionCenter Test Ediliyor ---")
	
	var mission_center = get_tree().get_first_node_in_group("mission_center")
	if mission_center:
		print("✅ MissionCenter bulundu")
		mission_center.open_menu()
		print("✅ MissionCenter açıldı")
		await get_tree().create_timer(5.0).timeout
		mission_center.close_menu()
		print("✅ MissionCenter kapatıldı")
	else:
		print("❌ MissionCenter bulunamadı!")

func _input(event):
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_CTRL):
		var mission_center = get_tree().get_first_node_in_group("mission_center")
		if mission_center:
			if mission_center.visible:
				mission_center.close_menu()
			else:
				mission_center.open_menu()
