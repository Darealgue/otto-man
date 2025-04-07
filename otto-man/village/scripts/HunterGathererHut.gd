class_name HunterGathererHut
extends Node2D
#asdasd
# Bu binaya özgü değişkenler
var assigned_workers: int = 0
var max_workers: int = 1 # Şimdilik her kamp 1 işçi alabilsin

# Bu bina için bir işçi atamaya çalışır
func add_worker() -> bool:
	if is_upgrading: 
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers >= max_workers:
		print("Avcı Kulübesi: Kapasite dolu!")
		return false
	if VillageManager.idle_workers <= 0:
		print("Avcı Kulübesi: Boşta işçi yok!")
		return false
	assigned_workers += 1
	print("Avcı Kulübesi: İşçi atandı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.register_worker_assignment("food") # KAYNAK TÜRÜ: food
	return true 

# Bu binadan bir işçi çıkarır
func remove_worker() -> bool:
	if is_upgrading: 
		print("Avcı Kulübesi: Yükseltme sırasında işlem yapılamaz!")
		return false
	if assigned_workers <= 0:
		print("Avcı Kulübesi: Çıkarılacak işçi yok!")
		return false
	assigned_workers -= 1
	print("Avcı Kulübesi: İşçi çıkarıldı (%d/%d)" % [assigned_workers, max_workers])
	VillageManager.unregister_worker_assignment("food") # KAYNAK TÜRÜ: food
	return true 

# --- Yükseltme Değişkenleri ---
var level: int = 1
var max_level: int = 3 
var is_upgrading: bool = false
var upgrade_duration: float = 4.0 # Örnek süre

# Yükseltme maliyetleri: Seviye -> {kaynak: seviye_gereksinimi}
const UPGRADE_COSTS = {
	2: {"wood": 1},       # Seviye 2 için 1 Odun
	3: {"wood": 1, "stone": 1} # Seviye 3 için 1 Odun, 1 Taş
}

# --- Zamanlayıcı (Timer) ---
var upgrade_timer: Timer

# --- Sinyaller ---
signal upgrade_started 
signal upgrade_finished 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	upgrade_timer = Timer.new()
	upgrade_timer.one_shot = true 
	upgrade_timer.wait_time = upgrade_duration
	upgrade_timer.timeout.connect(finish_upgrade) 
	add_child(upgrade_timer) 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# --- Yeni Yükseltme Fonksiyonları ---
func get_next_upgrade_cost() -> Dictionary:
	var next_level = level + 1
	if UPGRADE_COSTS.has(next_level):
		return UPGRADE_COSTS[next_level]
	else:
		return {} 

func start_upgrade() -> bool:
	if is_upgrading: return false
	if level >= max_level: return false
	var cost = get_next_upgrade_cost()
	if cost.is_empty(): return false

	# --- Kaynak Kilitleme (YORUM SATIRI) ---
	if not VillageManager.lock_resources(cost, self): return false
	# --- Kaynak Kilitleme Bitti ---

	print("Avcı Kulübesi: Yükseltme başlatıldı (Seviye %d -> %d)" % [level, level + 1])
	is_upgrading = true
	upgrade_timer.start() 
	emit_signal("upgrade_started") 
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.YELLOW
	return true

func finish_upgrade() -> void:
	if not is_upgrading: return 
	print("Avcı Kulübesi: Yükseltme tamamlandı (Seviye %d)" % (level + 1))
	is_upgrading = false
	level += 1
	var cost = UPGRADE_COSTS.get(level, {}) 
	# --- Kaynakları Serbest Bırakma (YORUM SATIRI) ---
	VillageManager.unlock_resources(cost, self)
	# --- Kaynakları Serbest Bırakma Bitti ---
	emit_signal("upgrade_finished") 
	if get_node_or_null("Sprite2D") is Sprite2D: get_node("Sprite2D").modulate = Color.WHITE
	print("Avcı Kulübesi: Yeni seviye: %d, Maks İşçi: %d" % [level, max_workers])
