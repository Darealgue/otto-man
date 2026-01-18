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
# Worker cilt renkleri - açık gri base üzerine uygulanacak
# Oyuncunun ten rengine (#e2b27e) benzer canlı, sıcak tonlar
# İşçiler için ten renkleri - açık gri base üzerine uygulanacak
# Geniş renk aralığı - çok açık, çok koyu, orta tonlar hepsi eşit şansla
const SKIN_TONES = [
	# Çok açık tenler
	Color(0.96, 0.91, 0.86), # Beyaz ten
	Color(0.94, 0.88, 0.82), # Açık sarı ten
	Color(0.95, 0.89, 0.83), # Açık ten
	Color(0.93, 0.87, 0.81), # Açık orta ten
	# Oyuncunun ten rengine yakın tonlar (canlı, sıcak)
	Color(0.90, 0.72, 0.52), # Oyuncu teni (e2b27e'ye yakın)
	Color(0.89, 0.71, 0.51), # Oyuncu teni (varyasyon)
	Color(0.88, 0.70, 0.50), # Oyuncu teni (koyu varyasyon)
	Color(0.91, 0.73, 0.53), # Oyuncu teni (açık varyasyon)
	Color(0.87, 0.69, 0.49), # Oyuncu teni (daha koyu)
	# Sıcak, canlı ten tonları
	Color(0.92, 0.74, 0.54), # Sıcak açık ten
	Color(0.86, 0.68, 0.48), # Sıcak koyu ten
	Color(0.85, 0.67, 0.47), # Sıcak orta-koyu ten
	# Buğday/Altın tonları (canlı)
	Color(0.90, 0.77, 0.60), # Açık buğday ten
	Color(0.88, 0.75, 0.58), # Buğday ten
	Color(0.86, 0.73, 0.56), # Koyu buğday ten
	# Orta ten
	Color(0.86, 0.73, 0.56), # Orta ten
	Color(0.85, 0.72, 0.55), # Orta koyu ten
	# Bronz/Kavruk tonları (canlı)
	Color(0.84, 0.66, 0.46), # Bronz ten
	Color(0.83, 0.65, 0.45), # Koyu bronz ten
	Color(0.82, 0.64, 0.44), # Kavruk ten
	Color(0.81, 0.63, 0.43), # Koyu kavruk ten
	# Esmer tonları (canlı)
	Color(0.80, 0.62, 0.42), # Esmer
	Color(0.79, 0.61, 0.41), # Koyu esmer
	Color(0.78, 0.60, 0.40), # Çok koyu esmer
	# Koyu ten
	Color(0.76, 0.58, 0.38), # Koyu ten
	Color(0.74, 0.56, 0.36), # Çok koyu ten
	# Çok koyu ten
	Color(0.70, 0.52, 0.34), # En koyu ten
	Color(0.65, 0.48, 0.32), # Siyah ten
	Color(0.60, 0.44, 0.30)  # Çok siyah ten
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

# --- Cariye Asset Paths ---
# Worker sistemindeki pattern'i takip eder
# Ten rengi ve saç rengi tint ile ayarlanacak (gri asset'ler kullanılır)
const CONCUBINE_BODY_TEXTURES = [
	"res://assets/concubine assets/body/cariye_walk_body.png"
	# Birden fazla body tipi varsa buraya eklenebilir
]

const CONCUBINE_HAIR_TEXTURES = [
	"res://assets/concubine assets/hair/cariye_walk_hair0.png",
	"res://assets/concubine assets/hair/cariye_walk_hair1.png",
	"res://assets/concubine assets/hair/cariye_walk_hair2.png"
]

# Clothing ve Pants için henüz asset yok, worker asset'lerini kullanabiliriz veya boş bırakabiliriz
const CONCUBINE_CLOTHING_TEXTURES = [
	"res://assets/concubine assets/top/cariye_walk_top1.png",
	"res://assets/concubine assets/top/cariye_idle_top1.png"
	# Not: top0 sadece idle için mevcut, zindan bölümünde kullanılacak
]

const CONCUBINE_PANTS_TEXTURES = [
	"res://assets/concubine assets/bottom/cariye_walk_bottom1.png",
	"res://assets/concubine assets/bottom/cariye_idle_bottom1.png"
	# Not: bottom0 sadece idle için mevcut, zindan bölümünde kullanılacak
]

# Cariyeler için özel renk paletleri (kadın karakterler için daha uygun renkler)
# Sarı ve turuncu saç renkleri öncelikli
const CONCUBINE_HAIR_COLORS = [
	# Siyah saç
	Color(0.1, 0.1, 0.1), # Siyah
	Color(0.15, 0.15, 0.15), # Çok koyu siyah
	Color(0.2, 0.2, 0.2), # Koyu siyah
	# Kahverengi saç
	Color(0.3, 0.2, 0.15), # Koyu kahverengi
	Color(0.4, 0.3, 0.2), # Kahverengi
	Color(0.5, 0.35, 0.25), # Orta kahverengi
	Color(0.6, 0.45, 0.3), # Açık kahverengi
	Color(0.5, 0.4, 0.3), # Kestane
	Color(0.45, 0.35, 0.25), # Koyu kestane
	# Sarı saç
	Color(0.95, 0.9, 0.7), # Platin sarı
	Color(0.9, 0.85, 0.65), # Açık sarı
	Color(0.85, 0.8, 0.6), # Sarı
	Color(0.8, 0.75, 0.55), # Altın sarı
	Color(0.75, 0.7, 0.5), # Koyu sarı
	# Turuncu saç
	Color(0.9, 0.6, 0.3), # Turuncu
	Color(0.85, 0.55, 0.25), # Koyu turuncu
	Color(0.8, 0.5, 0.2), # Kızıl turuncu
	Color(0.75, 0.45, 0.15), # Koyu kızıl
	# Kızıl saç (ek)
	Color(0.7, 0.4, 0.2), # Kızıl
	Color(0.65, 0.35, 0.15), # Koyu kızıl
	# Kumral (ek)
	Color(0.6, 0.5, 0.4), # Kumral
	Color(0.55, 0.45, 0.35) # Koyu kumral
]

# Cariyeler için ten renkleri - açık gri base üzerine uygulanacak
# Oyuncunun ten rengine (#e2b27e) benzer canlı, sıcak tonlar - orta tonlar ağırlıklı
const CONCUBINE_SKIN_TONES = [
	# Oyuncunun ten rengine yakın tonlar (canlı, sıcak - en yaygın)
	Color(0.90, 0.72, 0.52), # Oyuncu teni (e2b27e'ye yakın)
	Color(0.89, 0.71, 0.51), # Oyuncu teni (varyasyon)
	Color(0.88, 0.70, 0.50), # Oyuncu teni (koyu varyasyon)
	Color(0.91, 0.73, 0.53), # Oyuncu teni (açık varyasyon)
	Color(0.87, 0.69, 0.49), # Oyuncu teni (daha koyu)
	# Sıcak, canlı ten tonları (oyuncu rengine benzer)
	Color(0.92, 0.74, 0.54), # Sıcak açık ten
	Color(0.86, 0.68, 0.48), # Sıcak koyu ten
	Color(0.85, 0.67, 0.47), # Sıcak orta-koyu ten
	# Buğday/Altın tonları (canlı)
	Color(0.88, 0.75, 0.58), # Buğday ten
	Color(0.87, 0.74, 0.57), # Koyu buğday ten
	Color(0.90, 0.77, 0.60), # Açık buğday ten
	# Orta ten (canlı)
	Color(0.86, 0.73, 0.56), # Orta ten
	Color(0.85, 0.72, 0.55), # Orta koyu ten
	# Bronz/Kavruk tonları (canlı)
	Color(0.84, 0.66, 0.46), # Bronz ten
	Color(0.83, 0.65, 0.45), # Koyu bronz ten
	Color(0.82, 0.64, 0.44), # Kavruk ten
	Color(0.81, 0.63, 0.43), # Koyu kavruk ten
	# Esmer tonları (canlı)
	Color(0.80, 0.62, 0.42), # Esmer
	Color(0.79, 0.61, 0.41), # Koyu esmer
	Color(0.78, 0.60, 0.40), # Çok koyu esmer
	# Koyu ten (azaltıldı)
	Color(0.76, 0.58, 0.38), # Koyu ten
	Color(0.74, 0.56, 0.36), # Çok koyu ten
	# Çok açık ten (azaltıldı - sadece 1-2 adet)
	Color(0.93, 0.76, 0.59), # Açık ten
	Color(0.94, 0.78, 0.61)  # Çok açık ten
]

const CONCUBINE_CLOTHING_COLORS = [
	Color("#b0c4de"), # Light Steel Blue (Açık Mavi)
	Color("#f0a0a0"), # Light Pink (Açık Pembe)
	Color("#ffb6c1"), # Light Pink (Açık Pembe)
	Color("#ffe4e1"), # Misty Rose (Açık Pembe)
	Color("#ffe4b5"), # Moccasin (Açık Sarı)
	Color("#fff8dc"), # Cornsilk (Açık Sarı)
	Color("#e0e0ff"), # Lavender (Açık Mor-Mavi)
	Color("#dda0dd"), # Plum (Açık Mor)
	Color("#f5deb3"), # Wheat (Açık Bej)
	Color("#d3d3d3"), # Light Gray (Açık Gri)
	Color("#c0c0c0"), # Silver (Gümüş)
	Color("#d2b48c"), # Tan (Açık Kahverengi)
	Color("#deb887"), # Burlywood (Açık Kahverengi)
	Color("#f5f5dc"), # Beige (Bej)
	Color("#e6e6fa")  # Lavender (Açık Mor)
]

const CONCUBINE_PANTS_COLORS = [
	Color("#d3d3d3"), # Light Gray (Açık Gri)
	Color("#c0c0c0"), # Silver (Gümüş)
	Color("#dda0dd"), # Plum (Açık Mor)
	Color("#e0e0ff"), # Lavender (Açık Mor-Mavi)
	Color("#f0a0a0"), # Light Pink (Açık Pembe)
	Color("#ffb6c1"), # Light Pink (Açık Pembe)
	Color("#ffe4e1"), # Misty Rose (Açık Pembe)
	Color("#b0c4de"), # Light Steel Blue (Açık Mavi)
	Color("#f5deb3"), # Wheat (Açık Bej)
	Color("#d2b48c"), # Tan (Açık Kahverengi)
	Color("#deb887"), # Burlywood (Açık Kahverengi)
	Color("#f5f5dc"), # Beige (Bej)
	Color("#e6e6fa")  # Lavender (Açık Mor)
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

# --- Cariye Görünüm Oluşturma Fonksiyonu ---
func generate_random_concubine_appearance() -> VillagerAppearance:
	"""
	Cariyeler için rastgele görünüm oluşturur.
	Worker sistemindeki generate_random_appearance() ile benzer mantık,
	ama cariye asset'lerini kullanır.
	"""
	var new_appearance = VillagerAppearance.new()

	# Body (Kadın vücut modeli) - Worker sistemindeki gibi
	if !CONCUBINE_BODY_TEXTURES.is_empty():
		var body_path = CONCUBINE_BODY_TEXTURES[0]
		var body_normal_path = derive_normal_path(body_path)
		var body_canvas_texture = CanvasTexture.new()
		body_canvas_texture.diffuse_texture = load(body_path)
		body_canvas_texture.normal_texture = load(body_normal_path)
		new_appearance.body_texture = body_canvas_texture
		
		# Cariyeler için daha açık ten renkleri kullan
		if !CONCUBINE_SKIN_TONES.is_empty():
			new_appearance.body_tint = CONCUBINE_SKIN_TONES.pick_random()
		elif !SKIN_TONES.is_empty():
			new_appearance.body_tint = SKIN_TONES.pick_random()
	else:
		printerr("[AppearanceDB] ERROR: CONCUBINE_BODY_TEXTURES boş!")

	# Pants (Alt kıyafet - kadın karakterler için)
	# Cariye pants asset'i yoksa null bırak (worker asset'leri kullanma)
	if !CONCUBINE_PANTS_TEXTURES.is_empty():
		var pants_path = CONCUBINE_PANTS_TEXTURES.pick_random()
		var pants_normal_path = derive_normal_path(pants_path)
		var pants_canvas_texture = CanvasTexture.new()
		pants_canvas_texture.diffuse_texture = load(pants_path)
		pants_canvas_texture.normal_texture = load(pants_normal_path)
		new_appearance.pants_texture = pants_canvas_texture
		
		if !CONCUBINE_PANTS_COLORS.is_empty():
			new_appearance.pants_tint = CONCUBINE_PANTS_COLORS.pick_random()
	# Eğer cariye pants asset'i yoksa pants_texture null kalacak (görünmez olacak)

	# Clothes (Üst kıyafet - kadın karakterler için)
	# Cariye clothing asset'i yoksa null bırak (worker asset'leri kullanma)
	if !CONCUBINE_CLOTHING_TEXTURES.is_empty():
		var clothes_path = CONCUBINE_CLOTHING_TEXTURES.pick_random()
		var clothes_normal_path = derive_normal_path(clothes_path)
		var clothes_canvas_texture = CanvasTexture.new()
		clothes_canvas_texture.diffuse_texture = load(clothes_path)
		clothes_canvas_texture.normal_texture = load(clothes_normal_path)
		new_appearance.clothing_texture = clothes_canvas_texture
		
		if !CONCUBINE_CLOTHING_COLORS.is_empty():
			new_appearance.clothing_tint = CONCUBINE_CLOTHING_COLORS.pick_random()
	# Eğer cariye clothing asset'i yoksa clothing_texture null kalacak (görünmez olacak)

	# Mouth - Cariyeler için worker suratları kullanılmaz (null bırak)
	# Cariyeler için mouth_texture null kalacak
	new_appearance.mouth_texture = null

	# Eyes - Cariyeler için worker gözleri kullanılmaz (null bırak)
	# Cariyeler için eyes_texture null kalacak
	new_appearance.eyes_texture = null

	# Beard - Cariyeler için genellikle sakal yok
	# Cariyeler için beard_texture null kalacak
	new_appearance.beard_texture = null

	# Hair (Saç - kadın karakterler için)
	if !CONCUBINE_HAIR_TEXTURES.is_empty():
		var hair_path = CONCUBINE_HAIR_TEXTURES.pick_random()
		var hair_normal_path = derive_normal_path(hair_path)
		var hair_canvas_texture = CanvasTexture.new()
		hair_canvas_texture.diffuse_texture = load(hair_path)
		hair_canvas_texture.normal_texture = load(hair_normal_path)
		new_appearance.hair_texture = hair_canvas_texture
		
		if !CONCUBINE_HAIR_COLORS.is_empty():
			new_appearance.hair_tint = CONCUBINE_HAIR_COLORS.pick_random()
	else:
		printerr("[AppearanceDB] ERROR: CONCUBINE_HAIR_TEXTURES boş!")

	return new_appearance
