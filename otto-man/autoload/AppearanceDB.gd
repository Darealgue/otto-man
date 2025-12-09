# AppearanceDB.gd
extends Node

# <<< DEĞİŞTİ: Tekrar preload ve class_name kullan >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")

# --- Define Asset Paths ---
# Replace these with your actual asset paths once created
const BODY_TEXTURES = [
	"res://assets/character_parts/body/body_walk_gray.png" 
	# Add more body types if you have them
]
const HAIR_TEXTURES = [
	"res://assets/character_parts/hair/hair_style1_walk_gray.png",
	"res://assets/character_parts/hair/hair_style2_walk_gray.png"
	# Add more hair styles
]
const BEARD_TEXTURES = [
	"res://assets/character_parts/beard/beard_style1_walk_gray.png",
	"res://assets/character_parts/beard/beard_style2_walk_gray.png"
]
const EYES_TEXTURES = [
	"res://assets/character_parts/eyes/eyes1_walk.png",
	"res://assets/character_parts/eyes/eyes2_walk.png"
	# Add more eye styles
]
const CLOTHES_TEXTURES = [ # Üst Kıyafet
	"res://assets/character_parts/clothing/shirt_walk_gray.png",
	"res://assets/character_parts/clothing/shirtless_walk_gray.png" #<<< DOĞRU
]
const PANTS_TEXTURES = [
	"res://assets/character_parts/pants/pants_basic_walk_gray.png",
	"res://assets/character_parts/pants/pants_short_walk_gray.png" #<<< DOĞRU
]
const MOUTH_TEXTURES = [
	"res://assets/character_parts/mouth/mouth1_walk.png", #<<< DOĞRU
	"res://assets/character_parts/mouth/mouth2_walk.png" #<<< DOĞRU
]

# --- Define Color Palettes ---
const SKIN_TONES = [
	Color("#ffdbac"), Color("#f1c27d"), Color("#e0ac69"), 
	Color("#c68642"), Color("#a0522d"), Color("#8d5524") # Added Sienna
]
const HAIR_COLORS = [
	Color.BLACK, Color.SADDLE_BROWN, Color("#b8860b"), # DarkGoldenrod
	Color.DARK_GRAY, Color.GRAY, Color.DIM_GRAY,
	Color("#ff4500") # Orangey Red
]
const CLOTHING_COLORS = [
	Color.STEEL_BLUE, Color.DARK_GREEN, Color.FIREBRICK, 
	Color.INDIGO, Color.SADDLE_BROWN, Color.DARK_SLATE_GRAY
]
const PANTS_COLORS = [
	Color.DARK_SLATE_GRAY, Color.SADDLE_BROWN, Color.DIM_GRAY,
	Color.DARK_OLIVE_GREEN, Color.MIDNIGHT_BLUE
]

# <<< YENİ: Yardımcı Fonksiyon (Dışarı Taşındı) >>>
# Verilen görsel texture yolundan normal map yolunu türetir.
func derive_normal_path(base_path: String) -> String:
	if base_path.is_empty(): return ""
	# Extract filename: e.g., "hair_style1_walk_gray.png"
	var filename = base_path.get_file()
	# Get base name without extension: e.g., "hair_style1_walk_gray"
	var base_name = filename.get_basename()
	# Get extension: e.g., "png"
	var extension = filename.get_extension()
	# Construct new filename: e.g., "hair_style1_walk_gray_normal.png"
	var normal_filename = base_name + "_normal." + extension
	# Construct new path using the dedicated normals directory
	var normal_path = "res://assets/character_parts/character_parts_normals/" + normal_filename
	return normal_path
# <<< YENİ SONU >>>

# --- Generation Function ---
func generate_random_appearance() -> VillagerAppearance:
	var new_appearance = VillagerAppearance.new() # Yeni kaynak oluştur

	# Body (Tek seçenek)
	if !BODY_TEXTURES.is_empty():
		var body_path = BODY_TEXTURES[0]
		var body_normal_path = derive_normal_path(body_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var body_canvas_texture = CanvasTexture.new()
		body_canvas_texture.diffuse_texture = load(body_path)
		
		body_canvas_texture.normal_texture = load(body_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.body_texture = body_canvas_texture #<<< DEĞİŞTİ
		
	if !SKIN_TONES.is_empty():
		new_appearance.body_tint = SKIN_TONES.pick_random()
	
	# Pants 
	if !PANTS_TEXTURES.is_empty():
		var pants_path = PANTS_TEXTURES.pick_random()
		var pants_normal_path = derive_normal_path(pants_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var pants_canvas_texture = CanvasTexture.new()
		pants_canvas_texture.diffuse_texture = load(pants_path)
		pants_canvas_texture.normal_texture = load(pants_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.pants_texture = pants_canvas_texture #<<< DEĞİŞTİ
		
		if !PANTS_COLORS.is_empty():
			new_appearance.pants_tint = PANTS_COLORS.pick_random()

	# Clothes (Üst)
	if !CLOTHES_TEXTURES.is_empty():
		var clothes_path = CLOTHES_TEXTURES.pick_random()
		var clothes_normal_path = derive_normal_path(clothes_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var clothes_canvas_texture = CanvasTexture.new()
		clothes_canvas_texture.diffuse_texture = load(clothes_path)
		
		clothes_canvas_texture.normal_texture = load(clothes_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.clothing_texture = clothes_canvas_texture #<<< DEĞİŞTİ
		
		if !CLOTHING_COLORS.is_empty():
			new_appearance.clothing_tint = CLOTHING_COLORS.pick_random()

	# Mouth
	if !MOUTH_TEXTURES.is_empty():
		var mouth_path = MOUTH_TEXTURES.pick_random()
		var mouth_normal_path = derive_normal_path(mouth_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var mouth_canvas_texture = CanvasTexture.new()
		
		mouth_canvas_texture.diffuse_texture = load(mouth_path)
		
		mouth_canvas_texture.normal_texture = load(mouth_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.mouth_texture = mouth_canvas_texture #<<< DEĞİŞTİ

	# Eyes
	if !EYES_TEXTURES.is_empty():
		var eyes_path = EYES_TEXTURES.pick_random()
		var eyes_normal_path = derive_normal_path(eyes_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var eyes_canvas_texture = CanvasTexture.new()
		eyes_canvas_texture.diffuse_texture = load(eyes_path)
		
		eyes_canvas_texture.normal_texture = load(eyes_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.eyes_texture = eyes_canvas_texture #<<< DEĞİŞTİ

	# Beard (Opsiyonel - örn. %50 ihtimal)
	if !BEARD_TEXTURES.is_empty() and randi() % 2 == 0:
		var beard_path = BEARD_TEXTURES.pick_random()
		var beard_normal_path = derive_normal_path(beard_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var beard_canvas_texture = CanvasTexture.new()
		beard_canvas_texture.diffuse_texture = load(beard_path)
		
		beard_canvas_texture.normal_texture = load(beard_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.beard_texture = beard_canvas_texture #<<< DEĞİŞTİ
		
		if !HAIR_COLORS.is_empty():
			pass # Sakal rengini ayarlamak için (varsa beard_tint) burası kullanılabilir

	# Hair
	if !HAIR_TEXTURES.is_empty():
		var hair_path = HAIR_TEXTURES.pick_random()
		var hair_normal_path = derive_normal_path(hair_path)
		# <<< YENİ: CanvasTexture Oluşturma >>>
		var hair_canvas_texture = CanvasTexture.new()
		hair_canvas_texture.diffuse_texture = load(hair_path)
		hair_canvas_texture.normal_texture = load(hair_normal_path)
		# <<< YENİ SONU >>>
		new_appearance.hair_texture = hair_canvas_texture #<<< DEĞİŞTİ
		
		if !HAIR_COLORS.is_empty():
			new_appearance.hair_tint = HAIR_COLORS.pick_random()

	return new_appearance 
