extends MarginContainer

@onready var time_label: Label = %TimeLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Label'ın başlangıçta boş olmaması için ilk güncellemeyi yapalım
	if time_label and TimeManager:
		time_label.text = TimeManager.get_time_string()
	elif not time_label:
		printerr("TimeDisplayUI Error: TimeLabel node not found!")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Her frame'de zamanı güncelle (Optimize edilebilir ama şimdilik yeterli)
	if time_label and TimeManager:
		time_label.text = TimeManager.get_time_string()
