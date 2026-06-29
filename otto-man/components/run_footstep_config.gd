class_name RunFootstepConfig
extends RefCounted
## `run` animasyonu — ayak yere değdiği Sprite2D kareleri (0–9 loop, step 0.067s).
## Görsel farklıysa bu diziyi Godot'ta bir kare oynatıp güncelle.

const RUN_ANIM := &"run"
const CONTACT_FRAMES: Array[int] = [3, 8]

static func is_foot_contact_frame(frame: int) -> bool:
	return frame in CONTACT_FRAMES
