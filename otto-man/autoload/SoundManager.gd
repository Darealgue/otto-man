extends Node

var master_volume_db: float = 0.0
var music_volume_db: float = 0.0
var sfx_volume_db: float = 0.0

func _ready() -> void:
	print("[SoundManager] Placeholder active (no audio playback)")

func play_ui(_sound_id: String) -> void:
	# Placeholder: add audio playback later
	pass

func play_music(_track_id: String, _loop := true) -> void:
	# Placeholder: implement streaming audio here in future
	pass

func stop_music() -> void:
	pass

func play_sfx(_sfx_id: String, _position := Vector2.ZERO) -> void:
	# Placeholder for 2D positional SFX
	pass

func set_master_volume_db(db: float) -> void:
	master_volume_db = db

func set_music_volume_db(db: float) -> void:
	music_volume_db = db

func set_sfx_volume_db(db: float) -> void:
	sfx_volume_db = db

