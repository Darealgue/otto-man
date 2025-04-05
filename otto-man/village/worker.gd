extends CharacterBody2D
class_name Worker

signal worker_state_changed(new_state: String)

enum WorkerState { IDLE, WALKING, WORKING, RETURNING }

@export var move_speed: float = 100.0
@export var work_range: float = 20.0
@export var work_interval: float = 2.0 # Saniye başına kaynak toplama sıklığı

# İşçi özellikleri
var worker_id: int = -1
var worker_name: String = "Worker"
var worker_state: WorkerState = WorkerState.IDLE
var assigned_resource: String = ""
var resource_target_position: Vector2 = Vector2.ZERO
var home_position: Vector2 = Vector2.ZERO
var work_timer: float = 0.0
var working_efficiency: float = 1.0 # Verimlilik çarpanı

# Kaynak toplama sistemi
var current_resource_node: ResourceNode = null
var is_at_resource: bool = false
var target_work_position: Vector2 = Vector2.ZERO

@onready var animation_player = $AnimationPlayer if has_node("AnimationPlayer") else null
@onready var sprite = $Sprite2D if has_node("Sprite2D") else null

func _ready() -> void:
	# İşçinin başlangıç konumu
	home_position = global_position
	
	# Kayıt et
	if worker_id == -1:
		# VillageManager'a kaydet ve ID al
		worker_id = VillageManager.add_worker()
		
		# İşçi bilgilerini güncelle
		worker_name = "İşçi " + str(worker_id)
		
		# Verimliliği manuel olarak ayarla (eğer gerekliyse)
		if worker_id in VillageManager.get_workers_data():
			VillageManager.get_workers_data()[worker_id].efficiency = working_efficiency

func _physics_process(delta: float) -> void:
	match worker_state:
		WorkerState.IDLE:
			# İşçi boştayken
			_process_idle_state(delta)
		
		WorkerState.WALKING:
			# İşçi hedef kaynağa yürürken
			_process_walking_state(delta)
		
		WorkerState.WORKING:
			# İşçi kaynak toplarken
			_process_working_state(delta)
		
		WorkerState.RETURNING:
			# İşçi kaynakla eve dönerken
			_process_returning_state(delta)

func assign_to_resource(resource_type: String) -> void:
	if resource_type != assigned_resource:
		assigned_resource = resource_type
		
		# Eğer bir kaynak node'u ile çalışıyorsa, işçiyi kaldır
		if current_resource_node:
			current_resource_node.remove_worker(self)
			current_resource_node = null
		
		# Durum değiştir
		_change_state(WorkerState.IDLE)
		
		# VillageManager'a bildir
		VillageManager.assign_worker(worker_id, resource_type)

func _process_idle_state(delta: float) -> void:
	# Eğer bir kaynağa atandıysa, uygun bir kaynak node'u bul
	if assigned_resource != "":
		var nearest_resource = _find_nearest_resource_node(assigned_resource)
		
		if nearest_resource:
			current_resource_node = nearest_resource
			target_work_position = current_resource_node.get_available_position()
			_change_state(WorkerState.WALKING)
			
			# Kaynağa işçiyi ekle
			current_resource_node.add_worker(self)
		else:
			# Uygun kaynak bulunamazsa, evde bekle
			velocity = Vector2.ZERO
	else:
		# Atanmış kaynak yoksa, evde bekle
		velocity = Vector2.ZERO
	
	move_and_slide()

func _process_walking_state(delta: float) -> void:
	# Hedefe doğru hareket et
	var direction = (target_work_position - global_position).normalized()
	velocity = direction * move_speed
	
	# Spriteın yönünü ayarla
	if sprite and velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	
	move_and_slide()
	
	# Hedefe vardı mı kontrol et
	if global_position.distance_to(target_work_position) < 5.0:
		is_at_resource = true
		_change_state(WorkerState.WORKING)
		work_timer = 0

func _process_working_state(delta: float) -> void:
	# İşçi artık kaynakta, çalışıyor
	velocity = Vector2.ZERO
	move_and_slide()
	
	# Eğer çalışacak kaynak yoksa eve dön
	if !current_resource_node or !current_resource_node.is_active:
		_change_state(WorkerState.RETURNING)
		return
	
	# Belirli aralıklarla kaynak topla
	work_timer += delta
	if work_timer >= work_interval:
		work_timer = 0
		_collect_resource()

func _process_returning_state(delta: float) -> void:
	# Eve dönüş
	var direction = (home_position - global_position).normalized()
	velocity = direction * move_speed
	
	# Spriteın yönünü ayarla
	if sprite and velocity.x != 0:
		sprite.flip_h = velocity.x < 0
	
	move_and_slide()
	
	# Eve vardı mı kontrol et
	if global_position.distance_to(home_position) < 10:
		_change_state(WorkerState.IDLE)
		is_at_resource = false

func _collect_resource() -> void:
	# Kaynak topla ve VillageManager'a bildir
	var resource_amount = int(1 * working_efficiency)
	VillageManager.add_resource(assigned_resource, resource_amount)
	
	# Görsel efekt veya animasyon eklenebilir
	# Bu noktada işçi bir miktar daha çalışabilir veya eve dönebilir
	
	# Rastgele bir şekilde kaynağın tükenmesini simüle edelim
	# Gerçek uygulamada daha karmaşık bir sistem olabilir
	if randf() < 0.05: # %5 ihtimalle tüken
		current_resource_node.deplete()

func resource_depleted() -> void:
	# Kaynak tükendiğinde çağrılır
	is_at_resource = false
	_change_state(WorkerState.RETURNING)

func _find_nearest_resource_node(resource_type: String) -> ResourceNode:
	# En yakın uygun kaynak node'unu bul
	var resource_nodes = get_tree().get_nodes_in_group("resource_node")
	var nearest_node = null
	var nearest_distance = 999999.0
	
	for node in resource_nodes:
		if node is ResourceNode and node.resource_type == resource_type and node.can_add_worker():
			var distance = global_position.distance_to(node.global_position)
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_node = node
	
	return nearest_node

func _change_state(new_state: WorkerState) -> void:
	worker_state = new_state
	
	# Durum değişiminde animasyonu değiştir
	match new_state:
		WorkerState.IDLE:
			if animation_player and animation_player.has_animation("idle"):
				animation_player.play("idle")
		WorkerState.WALKING:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")
		WorkerState.WORKING:
			if animation_player and animation_player.has_animation("work"):
				animation_player.play("work")
		WorkerState.RETURNING:
			if animation_player and animation_player.has_animation("walk"):
				animation_player.play("walk")
	
	# Sinyali yayınla
	worker_state_changed.emit(WorkerState.keys()[new_state]) 
