extends Node

# Mission System Test Script
# Bu script MissionCenter'ı test etmek için kullanılır

func _ready():
	print("=== MISSION SYSTEM TEST BAŞLADI ===")
	
	# MissionManager'ı kontrol et
	var mission_manager = get_node("/root/MissionManager")
	if mission_manager:
		print("✅ MissionManager bulundu")
		
		# Test cariyeleri oluştur
		create_test_concubines()
		
		# Test görevleri oluştur
		create_test_missions()
		
		# MissionCenter'ı test et
		test_mission_center()
	else:
		print("❌ MissionManager bulunamadı!")

func create_test_concubines():
	print("--- Test Cariyeleri Oluşturuluyor ---")
	
	var mission_manager = get_node("/root/MissionManager")
	if not mission_manager:
		return
	
	# Mevcut fonksiyonu kullan
	mission_manager.create_initial_concubines()
	
	print("✅ Test cariyeleri oluşturuldu")

func create_test_missions():
	print("--- Test Görevleri Oluşturuluyor ---")
	
	var mission_manager = get_node("/root/MissionManager")
	if not mission_manager:
		return
	
	# Mevcut fonksiyonu kullan
	mission_manager.create_initial_missions()
	
	print("✅ Test görevleri oluşturuldu")

func test_mission_center():
	print("--- MissionCenter Test Ediliyor ---")
	
	# MissionCenter'ı bul
	var mission_center = get_tree().get_first_node_in_group("mission_center")
	if mission_center:
		print("✅ MissionCenter bulundu")
		
		# MissionCenter'ı aç
		mission_center.open_menu()
		print("✅ MissionCenter açıldı")
		
		# 5 saniye bekle
		await get_tree().create_timer(5.0).timeout
		
		# MissionCenter'ı kapat
		mission_center.close_menu()
		print("✅ MissionCenter kapatıldı")
	else:
		print("❌ MissionCenter bulunamadı!")

func _input(event):
	# Test kontrolleri
	if event.is_action_pressed("ui_accept") and Input.is_key_pressed(KEY_CTRL):
		print("=== TEST: MissionCenter Açılıyor ===")
		var mission_center = get_tree().get_first_node_in_group("mission_center")
		if mission_center:
			mission_center.open_menu()
	
	if event.is_action_pressed("ui_cancel") and Input.is_key_pressed(KEY_CTRL):
		print("=== TEST: MissionCenter Kapanıyor ===")
		var mission_center = get_tree().get_first_node_in_group("mission_center")
		if mission_center:
			mission_center.close_menu()
