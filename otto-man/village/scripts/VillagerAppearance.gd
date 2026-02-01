# VillagerAppearance.gd
extends Resource
class_name VillagerAppearance

# --- Body ---
@export var body_texture: CanvasTexture = null
@export var body_tint: Color = Color.WHITE # Default White = no tinting

# --- Pants ---
@export var pants_texture: CanvasTexture = null
@export var pants_tint: Color = Color.WHITE # Pantolon rengi

# --- Clothes ---
@export var clothing_texture: CanvasTexture = null
@export var clothing_tint: Color = Color.WHITE

# --- Mouth ---
@export var mouth_texture: CanvasTexture = null

# --- Eyes ---
@export var eyes_texture: CanvasTexture = null

# --- Beard (Optional) ---
@export var beard_texture: CanvasTexture = null
# Sakal rengi için saç rengini kullanabiliriz veya ayrı bir tint ekleyebiliriz:
# @export var beard_tint: Color = Color.WHITE

# --- Hair ---
@export var hair_texture: CanvasTexture = null
@export var hair_tint: Color = Color.WHITE # Default White = no tinting

# Add more parts as needed (e.g., nose, mouth, accessories)

# Save/Load için Dictionary'ye dönüştür
func to_dict() -> Dictionary:
	var dict: Dictionary = {}
	# CanvasTexture'ların diffuse ve normal texture path'lerini kaydet
	if body_texture != null:
		if body_texture.diffuse_texture != null:
			dict["body_texture_diffuse_path"] = body_texture.diffuse_texture.resource_path
		if body_texture.normal_texture != null:
			dict["body_texture_normal_path"] = body_texture.normal_texture.resource_path
	dict["body_tint"] = {"r": body_tint.r, "g": body_tint.g, "b": body_tint.b, "a": body_tint.a}
	
	if pants_texture != null:
		if pants_texture.diffuse_texture != null:
			dict["pants_texture_diffuse_path"] = pants_texture.diffuse_texture.resource_path
		if pants_texture.normal_texture != null:
			dict["pants_texture_normal_path"] = pants_texture.normal_texture.resource_path
	dict["pants_tint"] = {"r": pants_tint.r, "g": pants_tint.g, "b": pants_tint.b, "a": pants_tint.a}
	
	if clothing_texture != null:
		if clothing_texture.diffuse_texture != null:
			dict["clothing_texture_diffuse_path"] = clothing_texture.diffuse_texture.resource_path
		if clothing_texture.normal_texture != null:
			dict["clothing_texture_normal_path"] = clothing_texture.normal_texture.resource_path
	dict["clothing_tint"] = {"r": clothing_tint.r, "g": clothing_tint.g, "b": clothing_tint.b, "a": clothing_tint.a}
	
	if mouth_texture != null:
		if mouth_texture.diffuse_texture != null:
			dict["mouth_texture_diffuse_path"] = mouth_texture.diffuse_texture.resource_path
		if mouth_texture.normal_texture != null:
			dict["mouth_texture_normal_path"] = mouth_texture.normal_texture.resource_path
	
	if eyes_texture != null:
		if eyes_texture.diffuse_texture != null:
			dict["eyes_texture_diffuse_path"] = eyes_texture.diffuse_texture.resource_path
		if eyes_texture.normal_texture != null:
			dict["eyes_texture_normal_path"] = eyes_texture.normal_texture.resource_path
	
	if beard_texture != null:
		if beard_texture.diffuse_texture != null:
			dict["beard_texture_diffuse_path"] = beard_texture.diffuse_texture.resource_path
		if beard_texture.normal_texture != null:
			dict["beard_texture_normal_path"] = beard_texture.normal_texture.resource_path
	
	if hair_texture != null:
		if hair_texture.diffuse_texture != null:
			dict["hair_texture_diffuse_path"] = hair_texture.diffuse_texture.resource_path
		if hair_texture.normal_texture != null:
			dict["hair_texture_normal_path"] = hair_texture.normal_texture.resource_path
	dict["hair_tint"] = {"r": hair_tint.r, "g": hair_tint.g, "b": hair_tint.b, "a": hair_tint.a}
	
	return dict

# Dictionary'den yükle
func from_dict(dict: Dictionary) -> void:
	# Body texture (yeni format: diffuse ve normal ayrı, eski format: tek path)
	if dict.has("body_texture_diffuse_path") or dict.has("body_texture_normal_path"):
		var body_canvas = CanvasTexture.new()
		if dict.has("body_texture_diffuse_path"):
			var diffuse = load(dict["body_texture_diffuse_path"])
			if diffuse != null:
				body_canvas.diffuse_texture = diffuse
			else:
				printerr("[VillagerAppearance] Body diffuse texture yüklenemedi: %s" % dict["body_texture_diffuse_path"])
		if dict.has("body_texture_normal_path"):
			var normal = load(dict["body_texture_normal_path"])
			if normal != null:
				body_canvas.normal_texture = normal
			else:
				printerr("[VillagerAppearance] Body normal texture yüklenemedi: %s" % dict["body_texture_normal_path"])
		body_texture = body_canvas
	elif dict.has("body_texture_path"):  # Eski format desteği
		var loaded = load(dict["body_texture_path"])
		if loaded is CanvasTexture:
			body_texture = loaded
	if dict.has("body_tint"):
		var tint = dict["body_tint"]
		if tint is Dictionary:
			body_tint = Color(tint["r"], tint["g"], tint["b"], tint["a"])
	
	# Pants texture
	if dict.has("pants_texture_diffuse_path") or dict.has("pants_texture_normal_path"):
		var pants_canvas = CanvasTexture.new()
		if dict.has("pants_texture_diffuse_path"):
			var diffuse = load(dict["pants_texture_diffuse_path"])
			if diffuse != null:
				pants_canvas.diffuse_texture = diffuse
		if dict.has("pants_texture_normal_path"):
			var normal = load(dict["pants_texture_normal_path"])
			if normal != null:
				pants_canvas.normal_texture = normal
		pants_texture = pants_canvas
	elif dict.has("pants_texture_path"):  # Eski format desteği
		var loaded = load(dict["pants_texture_path"])
		if loaded is CanvasTexture:
			pants_texture = loaded
	if dict.has("pants_tint") and dict["pants_tint"] is Dictionary:
		var tint = dict["pants_tint"]
		pants_tint = Color(tint["r"], tint["g"], tint["b"], tint["a"])
	
	# Clothing texture
	if dict.has("clothing_texture_diffuse_path") or dict.has("clothing_texture_normal_path"):
		var clothing_canvas = CanvasTexture.new()
		if dict.has("clothing_texture_diffuse_path"):
			var diffuse = load(dict["clothing_texture_diffuse_path"])
			if diffuse != null:
				clothing_canvas.diffuse_texture = diffuse
		if dict.has("clothing_texture_normal_path"):
			var normal = load(dict["clothing_texture_normal_path"])
			if normal != null:
				clothing_canvas.normal_texture = normal
		clothing_texture = clothing_canvas
	elif dict.has("clothing_texture_path"):  # Eski format desteği
		var loaded = load(dict["clothing_texture_path"])
		if loaded is CanvasTexture:
			clothing_texture = loaded
	if dict.has("clothing_tint") and dict["clothing_tint"] is Dictionary:
		var tint = dict["clothing_tint"]
		clothing_tint = Color(tint["r"], tint["g"], tint["b"], tint["a"])
	
	# Mouth texture
	if dict.has("mouth_texture_diffuse_path") or dict.has("mouth_texture_normal_path"):
		var mouth_canvas = CanvasTexture.new()
		if dict.has("mouth_texture_diffuse_path"):
			var diffuse = load(dict["mouth_texture_diffuse_path"])
			if diffuse != null:
				mouth_canvas.diffuse_texture = diffuse
		if dict.has("mouth_texture_normal_path"):
			var normal = load(dict["mouth_texture_normal_path"])
			if normal != null:
				mouth_canvas.normal_texture = normal
		mouth_texture = mouth_canvas
	elif dict.has("mouth_texture_path"):  # Eski format desteği
		var loaded = load(dict["mouth_texture_path"])
		if loaded is CanvasTexture:
			mouth_texture = loaded
	
	# Eyes texture
	if dict.has("eyes_texture_diffuse_path") or dict.has("eyes_texture_normal_path"):
		var eyes_canvas = CanvasTexture.new()
		if dict.has("eyes_texture_diffuse_path"):
			var diffuse = load(dict["eyes_texture_diffuse_path"])
			if diffuse != null:
				eyes_canvas.diffuse_texture = diffuse
		if dict.has("eyes_texture_normal_path"):
			var normal = load(dict["eyes_texture_normal_path"])
			if normal != null:
				eyes_canvas.normal_texture = normal
		eyes_texture = eyes_canvas
	elif dict.has("eyes_texture_path"):  # Eski format desteği
		var loaded = load(dict["eyes_texture_path"])
		if loaded is CanvasTexture:
			eyes_texture = loaded
	
	# Beard texture
	if dict.has("beard_texture_diffuse_path") or dict.has("beard_texture_normal_path"):
		var beard_canvas = CanvasTexture.new()
		if dict.has("beard_texture_diffuse_path"):
			var diffuse = load(dict["beard_texture_diffuse_path"])
			if diffuse != null:
				beard_canvas.diffuse_texture = diffuse
		if dict.has("beard_texture_normal_path"):
			var normal = load(dict["beard_texture_normal_path"])
			if normal != null:
				beard_canvas.normal_texture = normal
		beard_texture = beard_canvas
	elif dict.has("beard_texture_path"):  # Eski format desteği
		var loaded = load(dict["beard_texture_path"])
		if loaded is CanvasTexture:
			beard_texture = loaded
	
	# Hair texture
	if dict.has("hair_texture_diffuse_path") or dict.has("hair_texture_normal_path"):
		var hair_canvas = CanvasTexture.new()
		if dict.has("hair_texture_diffuse_path"):
			var diffuse = load(dict["hair_texture_diffuse_path"])
			if diffuse != null:
				hair_canvas.diffuse_texture = diffuse
		if dict.has("hair_texture_normal_path"):
			var normal = load(dict["hair_texture_normal_path"])
			if normal != null:
				hair_canvas.normal_texture = normal
		hair_texture = hair_canvas
	elif dict.has("hair_texture_path"):  # Eski format desteği
		var loaded = load(dict["hair_texture_path"])
		if loaded is CanvasTexture:
			hair_texture = loaded
	if dict.has("hair_tint") and dict["hair_tint"] is Dictionary:
		var tint = dict["hair_tint"]
		hair_tint = Color(tint["r"], tint["g"], tint["b"], tint["a"]) 
