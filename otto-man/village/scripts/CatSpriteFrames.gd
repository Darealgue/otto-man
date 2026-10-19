class_name CatSpriteFrames
extends RefCounted

## Kedinin gerçek animasyon çerçeveleri (idle, walk, run, jump_up, jump_down, sleep): assets/NPC/cat/cat_*_border.png sayfalarından
## üretilir (CatPrototype ile aynı sayfalar ve kare sayıları). Zindan eşlikçisi bunu kullanır; sayfalar yoksa yer tutucu .tres'e düşer.

const SHEETS: Array[Dictionary] = [
	{"name": "idle", "path": "res://assets/NPC/cat/cat_idle_border.png", "frames": 12, "speed": 12.0, "loop": true},
	{"name": "walk", "path": "res://assets/NPC/cat/cat_walk_border.png", "frames": 8, "speed": 10.0, "loop": true},
	{"name": "run", "path": "res://assets/NPC/cat/cat_run_border.png", "frames": 8, "speed": 14.0, "loop": true},
	{"name": "jump_up", "path": "res://assets/NPC/cat/cat_jump_up_border.png", "frames": 4, "speed": 9.0, "loop": false},
	{"name": "jump_down", "path": "res://assets/NPC/cat/cat_jump_down_border.png", "frames": 4, "speed": 9.0, "loop": false},
	{"name": "sleep", "path": "res://assets/NPC/cat/cat_sleep_border.png", "frames": 8, "speed": 6.0, "loop": true},
]
const FALLBACK: SpriteFrames = preload("res://village/resources/cat_default_sprite_frames.tres")

static var _cached: SpriteFrames = null


static func get_frames() -> SpriteFrames:
	if _cached != null:
		return _cached
	var frames := SpriteFrames.new()
	for sheet in SHEETS:
		if not ResourceLoader.exists(String(sheet["path"])):
			return FALLBACK
		var tex := load(String(sheet["path"])) as Texture2D
		if tex == null:
			return FALLBACK
		var count: int = int(sheet["frames"])
		var frame_w: int = int(floor(float(tex.get_width()) / float(count)))
		if frame_w <= 0:
			return FALLBACK
		var anim: StringName = StringName(String(sheet["name"]))
		frames.add_animation(anim)
		frames.set_animation_loop(anim, bool(sheet["loop"]))
		frames.set_animation_speed(anim, float(sheet["speed"]))
		for i in range(count):
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(Vector2(float(i * frame_w), 0.0), Vector2(float(frame_w), float(tex.get_height())))
			frames.add_frame(anim, at)
	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")
	_cached = frames
	return frames


## Görünen (şeffaf olmayan) alt kenarın çerçeve merkezine göre y konumu: sprite'ı ayaklar y=0'da olacak şekilde yerleştirmek için
## sprite.position.y = -bottom_offset kullanılır.
static func visible_bottom_offset(frames: SpriteFrames, anim: StringName = &"idle") -> float:
	if frames == null or not frames.has_animation(anim) or frames.get_frame_count(anim) <= 0:
		return 17.0
	var tex: Texture2D = frames.get_frame_texture(anim, 0)
	if tex == null:
		return 17.0
	var img: Image = tex.get_image()
	if img == null or img.is_empty():
		return float(tex.get_height()) * 0.5
	var used: Rect2i = img.get_used_rect()
	if used.size.y <= 0:
		return float(tex.get_height()) * 0.5
	return float(used.position.y + used.size.y) - float(tex.get_height()) * 0.5
