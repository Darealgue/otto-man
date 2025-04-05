extends Button
class_name BuildingButton

var building_type: String = "house"
var is_available: bool = true

@onready var name_label: Label = $HBoxContainer/NameLabel
@onready var cost_label: Label = $HBoxContainer/CostLabel
@onready var icon_texture: TextureRect = $HBoxContainer/IconTexture

func _ready() -> void:
	# Bina bilgilerini güncelle
	update_display()
	
	# Butona tıklama olayını bağla
	pressed.connect(_on_button_pressed)

func set_building_type(type: String) -> void:
	building_type = type
	update_display()

func set_enabled(enabled: bool) -> void:
	is_available = enabled
	
	# Butonun görsel durumunu güncelle
	disabled = !enabled
	
	# Eğer mevcut değilse grileştir
	if !enabled:
		modulate = Color(0.7, 0.7, 0.7, 0.7)
	else:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	
	update_display()

func update_display() -> void:
	# Bina adını göster
	if name_label:
		var building_name = ""
		match building_type:
			"house": building_name = "Ev"
			"farm": building_name = "Çiftlik"
			"lumberjack": building_name = "Oduncu Kulübesi"
			"well": building_name = "Kuyu"
			"mine": building_name = "Maden"
			"blacksmith": building_name = "Demirci"
			"tower": building_name = "Savunma Kulesi"
			_: building_name = building_type
		
		name_label.text = building_name
	
	# Maliyetleri göster
	if cost_label:
		var requirements = VillageManager.get_building_requirements(building_type)
		var cost_text = ""
		
		for resource_type in requirements:
			cost_text += resource_type + ": " + str(requirements[resource_type]) + " "
		
		cost_label.text = cost_text
	
	# İkonu güncelle
	if icon_texture:
		# Bu noktada bir ikon sistemi eklenebilir
		# Örnek: icon_texture.texture = load("res://assets/icons/" + building_type + ".png")
		pass

func _on_button_pressed() -> void:
	# Burada özel işlemler yapabilirsiniz
	# Örneğin, seçili olduğunu belirtmek için stil değiştirme
	modulate = Color(1.2, 1.2, 0.8) # Seçildiğinde rengini değiştir
	
	# Seçim işlemi üst script tarafından yönetiliyor
	# VillageUI._on_building_button_selected() ile 
