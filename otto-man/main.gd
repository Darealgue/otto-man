func _ready() -> void:
    var ui_layer = CanvasLayer.new()
    add_child(ui_layer)
    
    var health_display = preload("res://ui/health_display.tscn").instantiate()
    ui_layer.add_child(health_display) 