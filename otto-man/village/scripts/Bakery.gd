extends Node2D

# --- Building Properties ---
var building_name: String = "Fırın"
@export var level: int = 1
@export var max_workers: int = 1 # Başlangıçta 1 işçi alabilir
@export var assigned_workers: int = 0
@export var worker_stays_inside: bool = true #<<< YENİ (Fırın için true)
var assigned_worker_ids: Array[int] = [] #<<< DÜZELTİLDİ: Tekil referans yerine diğer binalarla tutarlı ID listesi

# <<< YENİ: Fetching Durumu >>>
var is_fetcher_out: bool = false # Aynı anda sadece 1 işçi dışarı çıkabilir
# <<< YENİ SONU >>>

# Gerekli temel kaynaklar (üretim için)
# Artık dictionary olarak tanımlıyoruz: {"kaynak_adı": miktar}
var required_resources: Dictionary = {"food": 1}

# Üretilen gelişmiş kaynak
var produced_resource: String = "bread"

# --- ZAMAN BAZLI EKMEK ÜRETİMİ ---
var bread_production_progress: float = 0.0
const BREAD_PRODUCTION_TIME: float = 1650.0 # tam çalışma günü (07-18, 11 saat) = 1 işçi başına 1 ekmek

# --- INPUT FETCH/BUFFER ---
var input_buffer: Dictionary = {"food": 0}
var fetch_timer: Timer = null
var fetch_target: String = ""
const FETCH_TIME_PER_UNIT: float = 3.0

# --- Upgrade State ---
var is_upgrading: bool = false
var upgrade_timer: Timer = null
var upgrade_time_seconds: float = 12.0
@export var max_level: int = 3

# --- UI Bağlantıları (Eğer varsa, yolları ayarla) ---
# @onready var worker_label: Label = %WorkerLabel

# --- Çalışan figürü animasyonu (front/back katmanları arasında) ---
@onready var fig_sprite: Sprite2D = $FigSprite
var fig_anim_timer: Timer = null
const FIG_FRAME_TIME: float = 0.18

# --- Baca dumanı ---
const SMOKE_SCENE: PackedScene = preload("res://village/scenes/SmokePuff.tscn")
## Bacanın binaya göre yerel konumu — sanatçı sol üstteki taş çıkıntıya göre ayarladı,
## kendi çiziminde tam hizalanmadıysa buradan (editörde de) oynatılabilir.
@export var smoke_spawn_offset: Vector2 = Vector2(-172, -130)
var smoke_timer: Timer = null

func _ready() -> void:
	_update_ui()
	print("%s hazır." % building_name)
	# Upgrade timer kurulum
	# Upgrade timer kurulum
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true
	upgrade_timer.timeout.connect(_on_upgrade_finished)
	add_child(upgrade_timer)
	# Fetch timer kurulum
	fetch_timer = Timer.new()
	fetch_timer.one_shot = true
	fetch_timer.timeout.connect(_on_fetch_timeout)
	add_child(fetch_timer)
	# Figür animasyon zamanlayıcısı kurulum
	fig_anim_timer = Timer.new()
	fig_anim_timer.wait_time = FIG_FRAME_TIME
	fig_anim_timer.timeout.connect(_on_fig_anim_timeout)
	add_child(fig_anim_timer)
	# Baca dumanı zamanlayıcısı kurulum
	smoke_timer = Timer.new()
	smoke_timer.wait_time = 0.5 # saniyede 2 duman
	smoke_timer.timeout.connect(_on_smoke_timer_timeout)
	add_child(smoke_timer)

# Her frame'de ekmek üretimini kontrol et
func _process(delta: float) -> void:
	# Zaman ölçeğini uygula (TimeManager ile tutarlı olması için)
	var scaled_delta = delta * Engine.time_scale

	# Debug: Bakery _process çağrıldığında delta değerini kontrol et
	if Engine.time_scale >= 16.0 and delta > 0.1:
		print("🍞 Bakery _process - Delta: %.3f, Scaled Delta: %.3f, Time Scale: %.1f, Workers: %d" % [delta, scaled_delta, Engine.time_scale, assigned_workers])

	# Fırıncı figürü ve baca dumanı sadece işçi içerideyken ve çalışma saatinde aktif olsun.
	# NOT: assigned_workers'a göre türetiliyor (ayrı bir is_producing bayrağına değil) — o bayrak
	# sadece add_worker() içinde set ediliyordu ve kayıttan/sahne yeniden yüklemeden sonra
	# assigned_workers doğru restore olsa bile false kalıp üretimi/animasyonu kilitli bırakıyordu.
	var actively_working := assigned_workers > 0 and TimeManager.is_work_time() and not is_upgrading
	_set_fig_animating(actively_working)
	_set_smoke_active(actively_working)

	# Çalışma saatleri kontrolü - sadece 7:00-18:00 arası üretim yapılır
	if not TimeManager.is_work_time():
		return # Çalışma saatleri dışında üretim yok

	if assigned_workers > 0:
		# Gerekli kaynaklar var mı kontrol et
		# Önce yerel buffer'ı kontrol et; eksikse fetch başlat
		for resource_name in required_resources.keys():
			var need := int(required_resources[resource_name])
			var have_local := int(input_buffer.get(resource_name, 0))
			if have_local < need:
				# Fetch koşulları: üretici varlığı ve global stok
				if not is_fetcher_out and (not fetch_timer or not fetch_timer.is_stopped() == false):
					pass # Zamanlayıcı durumunu normalleştirmek için
				if not is_fetcher_out and (fetch_timer == null or fetch_timer.is_stopped()):
					var global_have := int(VillageManager.get_available_resource_level(resource_name))
					if global_have > 0:
						# Fetch başlat
						if can_i_fetch():
							fetch_target = resource_name
							fetch_timer.wait_time = FETCH_TIME_PER_UNIT
							fetch_timer.start()
							# Basit simülasyon: işçi binadan ayrıldı
							break
		
		# Üretim ilerlemesini artır: işçi sayısı kadar hız
		bread_production_progress += scaled_delta * float(assigned_workers)
		# Debug: Ekmek üretim ilerlemesini göster
		if Engine.time_scale >= 16.0 and bread_production_progress > 0:
			print("🍞 Ekmek üretim ilerlemesi: %.2f/%.1f (%.1f%%)" % [bread_production_progress, BREAD_PRODUCTION_TIME, (bread_production_progress / BREAD_PRODUCTION_TIME) * 100])

		# 1 ekmek üretildi mi?
		if bread_production_progress >= BREAD_PRODUCTION_TIME:
			# Önce buffer yeterli mi?
			var ok := true
			for res in required_resources.keys():
				var need := int(required_resources[res])
				if int(input_buffer.get(res, 0)) < need:
					ok = false
					break
			if ok:
				# Buffer'dan tüket
				for res2 in required_resources.keys():
					var need2 := int(required_resources[res2])
					input_buffer[res2] = int(input_buffer.get(res2, 0)) - need2
				# Ekmek üret
				VillageManager.resource_levels["bread"] = VillageManager.resource_levels.get("bread", 0) + 1
				VillageManager.emit_signal("village_data_changed")
			
			# İlerlemeyi sıfırla
			bread_production_progress = 0.0
			
			print("%s: 1 ekmek üretildi! Toplam ekmek: %d" % [building_name, VillageManager.resource_levels.get("bread", 0)])
			# Toplam kaynakları göster
			print("📊 TOPLAM KAYNAKLAR: Odun:%d, Taş:%d, Yiyecek:%d, Metal:%d, Ekmek:%d" % [
				VillageManager.resource_levels.get("wood", 0),
				VillageManager.resource_levels.get("stone", 0), 
				VillageManager.resource_levels.get("food", 0),
				VillageManager.resource_levels.get("metal", 0),
				VillageManager.resource_levels.get("bread", 0)
			])
		# Not: Kaynak yoksa üretim ilerler ama çıkış için buffer beklenir

# --- Worker Management --- 
func add_worker() -> bool:
	if assigned_workers >= max_workers:
		print("%s: Zaten maksimum işçi sayısına ulaşıldı." % building_name)
		return false
		
	# 1. Boşta İşçi Bul
	var worker_instance: Node = VillageManager.register_generic_worker()
	if not is_instance_valid(worker_instance):
		# Hata mesajı VillageManager'dan geldi
		return false # Boşta işçi yok

	# 2. Başarılı: İşçi Bilgilerini Ayarla ve Kaydet
	assigned_workers += 1
	assigned_worker_ids.append(worker_instance.worker_id) # İşçi ID'sini kaydet

	# İşçinin hedefini ve durumunu ayarla
	worker_instance.assigned_job_type = "bread"
	worker_instance.assigned_building_node = self
	worker_instance.move_target_x = self.global_position.x + worker_instance._building_arrival_x_offset(self)
	if worker_instance.should_start_shift_on_assignment():
		worker_instance.current_state = worker_instance.State.GOING_TO_BUILDING_FIRST
	else:
		worker_instance.current_state = worker_instance.State.AWAKE_IDLE
	
	# Üretimi başlat
	bread_production_progress = 0.0
	
	print("%s: İşçi (ID: %d) atandı ve üretim başladı (%d/%d). Gerekli kaynaklar: %s" % [
		building_name, worker_instance.worker_id, assigned_workers, max_workers, required_resources
	])
	_update_ui()
	VillageManager.notify_building_state_changed(self)
	return true

func remove_worker() -> bool:
	if assigned_workers <= 0 or assigned_worker_ids.is_empty():
		print("%s: Çıkarılacak işçi yok (Sayaç 0)." % building_name)
		return false

	var id: int = assigned_worker_ids.pop_back()
	assigned_workers = assigned_worker_ids.size()

	# Üretimi durdur (kalan işçi yoksa)
	if assigned_workers <= 0:
		bread_production_progress = 0.0

	if VillageManager.all_workers.has(id):
		var worker_to_remove = VillageManager.all_workers[id]["instance"]
		if is_instance_valid(worker_to_remove):
			# Bina bağlantısı hâlâ geçerliyken unregister et (idle_workers++) — bina alanlarını
			# bundan SONRA temizle, yoksa VillageManager işçinin zaten boşta olduğunu sanıp
			# sayacı artırmaz ve HUD'daki "boşta işçi" sayısı yanlış kalır.
			VillageManager.unregister_generic_worker(id)
			worker_to_remove.assigned_job_type = ""
			worker_to_remove.assigned_building_node = null
			worker_to_remove.move_target_x = worker_to_remove.global_position.x # Hedefi sıfırla
			# Eğer içerideyse veya işe gidiyorsa idle yap
			if worker_to_remove.current_state == worker_to_remove.State.WORKING_INSIDE or \
			   worker_to_remove.current_state == worker_to_remove.State.GOING_TO_BUILDING_FIRST:
				worker_to_remove.current_state = worker_to_remove.State.AWAKE_IDLE
				worker_to_remove.visible = true # Görünür yap

	print("%s: İşçi (ID: %d) çıkarıldı (%d/%d)." % [
		building_name, id, assigned_workers, max_workers
	])
	_update_ui()
	VillageManager.notify_building_state_changed(self)
	return true

# --- Üretim Mantığı - KALDIRILDI ---
# func _on_production_timer_timeout() -> void:
#    ... (eski kod)

# --- UI Update (Varsa) ---
func _update_ui() -> void:
	# if worker_label:
	#    worker_label.text = "%d / %d" % [assigned_workers, max_workers]
	pass # Label yoksa veya adı farklıysa hata vermesin

# --- Fırıncı figürü animasyonu ---
func _set_fig_animating(active: bool) -> void:
	if fig_sprite == null or active == fig_sprite.visible:
		return
	fig_sprite.visible = active
	if active:
		fig_sprite.frame = 0
		fig_anim_timer.start()
	else:
		fig_anim_timer.stop()

func _on_fig_anim_timeout() -> void:
	fig_sprite.frame = (fig_sprite.frame + 1) % 4

# --- Baca dumanı ---
func _set_smoke_active(active: bool) -> void:
	if smoke_timer == null:
		return
	if active:
		if smoke_timer.is_stopped():
			smoke_timer.start()
			_spawn_smoke_puff() # aktif olur olmaz 1sn beklemeden ilk duman çıksın
	else:
		smoke_timer.stop()

func _on_smoke_timer_timeout() -> void:
	_spawn_smoke_puff()

func _spawn_smoke_puff() -> void:
	if not SMOKE_SCENE:
		return
	var puff: Sprite2D = SMOKE_SCENE.instantiate()
	# Konum, add_child()'dan ÖNCE atanmalı: add_child, puff._ready()'i senkron tetikliyor ve
	# SmokePuff._ready() sallanma hareketinin referans noktası olan _start_x'i o anki position.x'ten
	# okuyor. Sırayı tersine çevirirsen _start_x hep 0 kalır, duman her frame merkeze geri sıçrar.
	puff.position = smoke_spawn_offset
	puff.z_index = -1 # BackSprite ile aynı sırada — FrontSprite'ın (z=1) arkasında kalıp bacadan çıkıyormuş gibi görünsün
	add_child(puff)

func _on_fetch_timeout() -> void:
	if fetch_target == "":
		finished_fetching()
		return
	# Global stoktan 1 birim düş ve buffer'a ekle
	var cur:int = int(VillageManager.resource_levels.get(fetch_target, 0))
	if cur > 0:
		VillageManager.resource_levels[fetch_target] = cur - 1
		input_buffer[fetch_target] = int(input_buffer.get(fetch_target, 0)) + 1
		VillageManager.emit_signal("village_data_changed")
	finished_fetching()
	fetch_target = ""

# --- Upgrade API ---
func get_next_upgrade_cost() -> Dictionary:
	return BuildingUpgradeMixin.get_next_cost(self)

signal upgrade_started
signal upgrade_finished
signal state_changed

func start_upgrade() -> bool:
	return BuildingUpgradeMixin.start(self)

func _on_upgrade_finished() -> void:
	if not is_upgrading:
		return
	is_upgrading = false
	level += 1
	max_workers = level
	upgrade_finished.emit()
	state_changed.emit()
	VillageManager.notify_building_state_changed(self)
	print("Fırın: Yükseltme tamamlandı. Yeni seviye: %d" % level)

# --- TODO: Yükseltme Mantığı ---
# func upgrade():
#    ...

# <<< YENİ: Fetching İzin Fonksiyonları >>>
func can_i_fetch() -> bool:
	if not is_fetcher_out:
		is_fetcher_out = true
		# print("%s: Fetching permission granted." % building_name) # Debug
		return true
	else:
		# print("%s: Fetching permission denied (another worker is out)." % building_name) # Debug
		return false

func finished_fetching() -> void:
	if is_fetcher_out:
		is_fetcher_out = false
		# print("%s: Fetcher returned." % building_name) # Debug
	else:
		# Bu durumun olmaması lazım ama güvenlik için loglayalım
		printerr("%s: finished_fetching called but no fetcher was out?" % building_name)
# <<< YENİ SONU >>>

# Basit üretim bilgisini döndürür (UI için)
func get_production_info() -> String:
	var level_info := "Lv." + str(level)
	return level_info + " • İşçi:" + str(assigned_workers) + " • Ekmek (odun+yiyecek): 1/" + str(int(BREAD_PRODUCTION_TIME / max(1.0, float(assigned_workers)))) + "sn"
