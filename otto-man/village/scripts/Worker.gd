extends Node2D

@export var NPC_Info : Dictionary
# <<< YENİ: Appearance Resource >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")
@export var appearance: VillagerAppearance:
	set(value):
		appearance = value
		if is_node_ready(): # Eğer sahne hazırsa görselleri hemen güncelle
			update_visuals()

var worker_id: int = -1 # VillageManager tarafından atanacak

# <<< YENİ: Kenardan Başlama Pozisyonu >>>
var start_x_pos: float = 0.0 # VillageManager._assign_housing tarafından ayarlanacak
# <<< YENİ SONU >>>

# <<< YENİ: Önceki Durumu Takip İçin >>>
var _previous_state = -1 # Başlangıçta geçersiz bir değer
# <<< YENİ SONU >>>

# <<< YENİ: Boş Zaman Aktivitesi Takibi >>>
var _current_idle_activity: String = "wandering" # "wandering", "sit", "lie", "drink"
var idle_activity_timer: Timer
# <<< DÜZENLEME: Aktivite Süreleri Uzatıldı >>>
var idle_activity_duration_min: float = 10.0 # Min aktivite süresi (saniye) - Önceki: 5.0
var idle_activity_duration_max: float = 30.0 # Max aktivite süresi (saniye) - Önceki: 15.0
# <<< YENİ SONU >>>

# <<< YENİ: Animation Tracking >>>
var _current_animation_name: String = "" # Track the animation we told the player to play
var _pending_wander_target: Vector2 = Vector2.ZERO # Store target during brief idle
var _is_briefly_idling: bool = false # Flag for brief idle state
# <<< YENİ SONU >>>

# <<< YENİ: Dikey Hareket İçin >>>
var _target_global_y: float = 0.0 # Hedef global Y konumu
const VERTICAL_RANGE_MAX: float = 25.0 # Y ekseninde hareket aralığı (0 ile bu değer arası)
# <<< YENİ SONU >>>

# <<< YENİ: Debug Sayaç >>>
var _debug_frame_counter: int = 0
var _debug_anim_counter: int = 0 # <<< YENİ: Animasyon debug sayacı >>>
# <<< YENİ SONU >>>

# İşçinin olası durumları
enum State { 
	SLEEPING,         # Uyuyor (görünmez)
	AWAKE_IDLE,       # Uyanık, işsiz/boşta geziyor
	GOING_TO_BUILDING_FIRST, # İşe gitmek için ÖNCE binaya uğruyor
	WORKING_OFFSCREEN, # Ekran dışında çalışıyor
	WAITING_OFFSCREEN, # Ekran dışında iş bitimini beklerken
	WORKING_INSIDE,   # Binanın içinde çalışıyor (görünmez)
	RETURNING_FROM_WORK, # İşten dönüyor (ekran dışından BİNAYA doğru geliyor)
	SOCIALIZING,      # Köyde sosyalleşiyor/dolaşıyor
	GOING_TO_SLEEP,   # Uyumak için barınağa gidiyor
	FETCHING_RESOURCE, # Kaynak almaya gidiyor (görsel)
	WAITING_AT_SOURCE, # Kaynak binasında bekliyor (görünmez)
	RETURNING_FROM_FETCH # Kaynaktan binaya dönüyor (görsel)
} 
var current_state = State.AWAKE_IDLE # Başlangıç durumu (Tip otomatik çıkarılacak)

# Atama Bilgileri
var assigned_job_type: String = "" # "wood", "stone", etc. or "" for idle
var assigned_building_node: Node2D = null # Atandığı binanın node'u
var housing_node: Node2D = null # Kaldığı yer (CampFire veya House)

# Rutin Zamanlaması için Rastgele Farklar
var wake_up_minute_offset: int = randi_range(0, 15) 
var work_start_minute_offset: int = randi_range(0, 30)
var work_end_minute_offset: int = randi_range(0, 30) # 0-30 dk arası rastgelelik
var sleep_minute_offset: int = randi_range(0, 60) #<<< YENİ IDLE UYKU OFFSETİ
# TODO: Diğer rutinler (iş bitişi, uyku) için de offsetler eklenebilir

# Hareket Değişkenleri
var move_target_x: float = 0.0 # Sadece X ekseninde hareket edilecek hedef
var move_speed: float = randf_range(50.0, 70.0) # Pixel per second (ayarlanabilir)
var _offscreen_exit_x: float = 0.0 #<<< YENİ

# <<< YENİ: Kaynak Taşıma Zamanlayıcıları >>>
var fetching_timer: Timer # Dışarı çıkma aralığı için
var wait_at_source_timer: Timer # Kaynakta bekleme süresi için
var fetch_interval_min: float = 15.0 
var fetch_interval_max: float = 30.0 
var wait_at_source_duration: float = 1.5 # Kaynakta bekleme süresi (saniye)
var fetch_target_x_temp: float = 0.0 # Artık kullanılmıyor olabilir? Gözden geçir.
# <<< YENİ SONU >>>

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var body_sprite: Sprite2D = $BodySprite # Sahnedeki düğüm adlarıyla eşleşmeli!
@onready var pants_sprite: Sprite2D = $PantsSprite #<<< YENİ
@onready var clothing_sprite: Sprite2D = $ClothingSprite
@onready var mouth_sprite: Sprite2D = $MouthSprite #<<< YENİ
@onready var eyes_sprite: Sprite2D = $EyesSprite   #<<< YENİ
@onready var beard_sprite: Sprite2D = $BeardSprite # Bu opsiyonel, sahnede olmayabilir
@onready var hair_sprite: Sprite2D = $HairSprite
@onready var held_item_sprite: Sprite2D = $HeldItemSprite # Bu da opsiyonel

# <<< YENİ: Alet Texture\'ları için Dictionary >>>
var tool_textures = {
	"wood": preload("res://assets/tools/walk_work_tool_axe.png"), # Güncellendi
	"stone": preload("res://assets/tools/walk_work_tool_pickaxe.png"), # Güncellendi
	"food": preload("res://assets/tools/walk_work_tool_hoe.png"), # Güncellendi (Çapa varsayıldı)
	"water": preload("res://assets/tools/walk_work_tool_bucket.png"), # Güncellendi
	# Diğer iş tipleri için eklenebilir...
}
# <<< YENİ SONU >>>

# <<< YENİ: Walk/Work Texture Setleri >>>
var walk_work_textures = {
	"body": {
		"default": { # Stil adı dosya adından çıkarılacak ('body')
			"diffuse": preload("res://assets/character_parts/body/Body_walk_work_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Body_walk_work_gray_normal.png")
		}
	},
	"pants": {
		"basic": { # Stil adı dosya adından çıkarılacak ('basic')
			"diffuse": preload("res://assets/character_parts/pants/pants_basic_walk_work_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_basic_walk_work_gray_normal.png")
		},
		"short": { # Stil adı dosya adından çıkarılacak ('short')
			"diffuse": preload("res://assets/character_parts/pants/pants_short_walk_work_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_short_walk_work_gray_normal.png")
		}
	},
	"clothing": {
		"shirt": { # Stil adı dosya adından çıkarılacak ('shirt')
			"diffuse": preload("res://assets/character_parts/clothing/shirt_walk_work_gray.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/shirt_walk_work_gray_normal.png")
		},
		"shirtless": { # Stil adı dosya adından çıkarılacak ('shirtless')
			 "diffuse": preload("res://assets/character_parts/clothing/shirtless_walk_work_gray.png"),
			 "normal": preload("res://assets/character_parts/character_parts_normals/shirtless_walk_work_gray_normal.png")
		}
	},
	"mouth": {
		"1": { # Stil adı dosya adından çıkarılacak ('1')
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_walk_work.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_walk_work_normal.png") # Doğrulandı
		},
		"2": { # Stil adı dosya adından çıkarılacak ('2')
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_walk_work.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_walk_work_normal.png") # Doğrulandı
		}
	},
	"eyes": {
		"1": { # Stil adı dosya adından çıkarılacak ('1')
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_walk_work.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_walk_work_normal.png") # Doğrulandı
		},
		"2": { # Stil adı dosya adından çıkarılacak ('2')
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_walk_work.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_walk_work_normal.png") # Doğrulandı
		}
	},
	"beard": {
		"style1": { # Stil adı dosya adından çıkarılacak ('style1')
			"diffuse": preload("res://assets/character_parts/beard/beard_style1_walk_work_gray.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/beard_style1_walk_work_gray_normal.png") # Doğrulandı
		},
		"style2": { # Stil adı dosya adından çıkarılacak ('style2')
			"diffuse": preload("res://assets/character_parts/beard/beard_style2_walk_work_gray.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/beard_style2_walk_work_gray_normal.png") # Doğrulandı
		}
	},
	"hair": {
		"style1": { # Stil adı dosya adından çıkarılacak ('style1')
			# Dikkat: Diffuse dosyasında H büyük harf!
			"diffuse": preload("res://assets/character_parts/hair/Hair_style1_walk_work_gray.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair_style1_walk_work_gray_normal.png") # Doğrulandı
		},
		"style2": { # Stil adı dosya adından çıkarılacak ('style2')
			"diffuse": preload("res://assets/character_parts/hair/hair_style2_walk_work_gray.png"), # Doğrulandı
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style2_walk_work_gray_normal.png") # Doğrulandı
		}
	},
}

var tool_normal_textures = { # Aletlerin normal map'leri
	"wood": preload("res://assets/character_parts/character_parts_normals/walk_work_tool_axe_normal.png"),
	"stone": preload("res://assets/character_parts/character_parts_normals/walk_work_tool_pickaxe_normal.png"),
	"food": preload("res://assets/character_parts/character_parts_normals/walk_work_tool_hoe_normal.png"), # Çapa varsayıldı
	"water": preload("res://assets/character_parts/character_parts_normals/walk_work_tool_bucket_normal.png"),
	# Diğer iş tipleri için eklenebilir...
}
# <<< YENİ SONU >>>

# <<< YENİ: Animasyon Frame Sayıları (Genişletilmiş) >>>
var animation_frame_counts = {
	"idle": {"hframes": 12, "vframes": 1},
	"walk": {"hframes": 12, "vframes": 1},
	"walk_tool": {"hframes": 12, "vframes": 1},
	"walk_carry": {"hframes": 12, "vframes": 1},
	# --- YENİ AKTİVİTE ANİMASYONLARI (Varsayılan, GÜNCELLE!) ---
	"sit": {"hframes": 12, "vframes": 1},
	"lie": {"hframes": 12, "vframes": 1},
	"drink": {"hframes": 12, "vframes": 1},
	# ----------------------------------------------------------
	# Diğer animasyonlar buraya eklenebilir
}
# <<< YENİ SONU >>>

# <<< YENİ: Placeholder Texture Setleri (GÜNCELLE!) >>>
# Bu sözlükleri kendi texture yollarınızla doldurun.
# Yapı, walk_work_textures ile aynı olmalı.
var idle_sit_textures = {
	"body": {
		"default": {
			"diffuse": preload("res://assets/character_parts/body/body_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/body_sit_normal.png")
		}
	},
	"pants": {
		"basic": { # Assuming pants1 maps to basic
			"diffuse": preload("res://assets/character_parts/pants/pants1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants1_sit_normal.png")
		},
		"short": { # Assuming pants2 maps to short
			"diffuse": preload("res://assets/character_parts/pants/pants2_sit.png"),
			"normal": null # Normal map file not found
		} # No sit texture found for short pants
	},
	"clothing": {
		"shirt": { # Assuming Clothes1 maps to shirt
			"diffuse": preload("res://assets/character_parts/clothing/Clothes1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Clothes1_sit_normal.png")
		},
		"shirtless": { # Assuming Clothes2 maps to shirtless
			"diffuse": preload("res://assets/character_parts/clothing/Clothes2_sit.png"),
			"normal": null # Normal map file not found
		} # No sit texture found for shirtless
	},
	"mouth": {
		"1": { # Assuming mouth1 maps to 1
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_sit_normal.png")
		},
		"2": { 
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_sit.png"), 
			"normal": null # Normal map file not found
		}
	},
	"eyes": {
		"1": { # Assuming eyes1 maps to 1
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_sit_normal.png")
		},
		"2": { 
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_sit.png"), 
			"normal": null # Normal map file not found
		}
	},
	"beard": {
		"style1": { # Assuming beard1 maps to style1
			"diffuse": preload("res://assets/character_parts/beard/beard1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/beard1_sit_normal.png")
		},
		"style2": { 
			"diffuse": preload("res://assets/character_parts/beard/beard2_sit.png"), 
			"normal": null # Normal map file not found
		}
	},
	"hair": {
		"style1": { # Assuming Hair1 maps to style1
			"diffuse": preload("res://assets/character_parts/hair/Hair1_sit.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair1_sit_normal.png")
		},
		"style2": { 
			"diffuse": preload("res://assets/character_parts/hair/Hair2_sit.png"), 
			"normal": null # Normal map file not found
		}
	}
}
# NOTE: Diffuse textures for 'lie' and 'drink' animations were not found in the checked directories.
# Normal maps exist, but the diffuse parts are missing.
# Keep these dictionaries as placeholders until diffuse textures are available.
var idle_lie_textures = {
	"body": {
		"default": {
			"diffuse": preload("res://assets/character_parts/body/body_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/body_lie_normal.png")
		}
	},
	"pants": {
		"basic": { # Assuming pants1 maps to basic
			"diffuse": preload("res://assets/character_parts/pants/pants1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants1_lie_normal.png")
		},
		"short": { # Assuming pants2 maps to short
			"diffuse": preload("res://assets/character_parts/pants/pants2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants2_lie_normal.png")
		}
	},
	"clothing": {
		"shirt": { # Assuming Clothes1 maps to shirt
			"diffuse": preload("res://assets/character_parts/clothing/Clothes1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Clothes1_lie_normal.png")
		},
		"shirtless": { # Assuming Clothes2 maps to shirtless
			"diffuse": preload("res://assets/character_parts/clothing/Clothes2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Clothes2_lie_normal.png")
		}
	},
	"mouth": {
		"1": { # Assuming mouth1 maps to 1
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_lie_normal.png")
		},
		"2": { # Assuming mouth2 maps to 2
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_lie_normal.png")
		}
	},
	"eyes": {
		"1": { # Assuming eyes1 maps to 1
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_lie_normal.png")
		},
		"2": { # Assuming eyes2 maps to 2
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_lie_normal.png")
		}
	},
	"beard": {
		"style1": { # Assuming beard1 maps to style1
			"diffuse": preload("res://assets/character_parts/beard/beard1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/beard1_lie_normal.png")
		},
		"style2": { # Assuming beard2 maps to style2
			"diffuse": preload("res://assets/character_parts/beard/beard2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/beard2_lie_normal.png")
		}
	},
	"hair": {
		"style1": { # Assuming Hair1 maps to style1
			"diffuse": preload("res://assets/character_parts/hair/Hair1_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair1_lie_normal.png")
		},
		"style2": { # Assuming Hair2 maps to style2
			"diffuse": preload("res://assets/character_parts/hair/Hair2_lie.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair2_lie_normal.png")
		}
	}
}
var idle_drink_textures = {
	"body": {
		"default": {
			"diffuse": preload("res://assets/character_parts/body/body_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/body_drink_normal.png")
		}
	},
	"pants": {
		"basic": { # Assuming pants1 maps to basic
			"diffuse": preload("res://assets/character_parts/pants/pants1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants1_drink_normal.png")
		},
		"short": { # Assuming pants2 maps to short
			"diffuse": preload("res://assets/character_parts/pants/pants2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/pants2_drink_normal.png")
		}
	},
	"clothing": {
		"shirt": { # Assuming Clothes1 maps to shirt
			"diffuse": preload("res://assets/character_parts/clothing/Clothes1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Clothes1_drink_normal.png")
		},
		"shirtless": { # Assuming Clothes2 maps to shirtless
			"diffuse": preload("res://assets/character_parts/clothing/Clothes2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Clothes2_drink_normal.png")
		}
	},
	"mouth": {
		"1": { # Assuming mouth1 maps to 1
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_drink_normal.png")
		},
		"2": { # Assuming mouth2 maps to 2
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_drink_normal.png")
		}
	},
	"eyes": {
		"1": { # Assuming eyes1 maps to 1
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_drink_normal.png")
		},
		"2": { # Assuming eyes2 maps to 2
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_drink_normal.png")
		}
	},
	"beard": {
		"style1": { # Assuming beard1 maps to style1
			"diffuse": preload("res://assets/character_parts/beard/beard1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/beard1_drink_normal.png")
		},
		"style2": { # Assuming beard2 maps to style2
			"diffuse": preload("res://assets/character_parts/beard/beard2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/beard2_drink_normal.png")
		}
	},
	"hair": {
		"style1": { # Assuming Hair1 maps to style1
			"diffuse": preload("res://assets/character_parts/hair/Hair1_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair1_drink_normal.png")
		},
		"style2": { # Assuming Hair2 maps to style2
			"diffuse": preload("res://assets/character_parts/hair/Hair2_drink.png"),
			"normal": preload("res://assets/character_parts/character_parts_normals/Hair2_drink_normal.png")
		}
	}
	# Optional: Add held item textures if the drink animation requires one
	# "held_item": { "diffuse": preload("...path_to_cup.png"), "normal": preload("...path_to_cup_normal.png") }
}
# <<< YENİ SONU >>>

# <<< YENİ: Aletsiz Yürüme Texture Setleri (walk_textures) >>>
# walk_work_textures'a benzer, ancak aletsiz görselleri içermeli.
# Dosya yollarının doğru olduğunu kontrol edin!
var walk_textures = {
	"body": {
		"default": {
			# <<< DÜZELTME: Büyük/küçük harf düzeltildi >>>
			"diffuse": preload("res://assets/character_parts/body/body_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/body_walk_gray_normal.png") # _work yok
		}
	},
	"pants": {
		"basic": {
			"diffuse": preload("res://assets/character_parts/pants/pants_basic_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_basic_walk_gray_normal.png") # _work yok
		},
		"short": {
			"diffuse": preload("res://assets/character_parts/pants/pants_short_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/pants_short_walk_gray_normal.png") # _work yok
		}
	},
	"clothing": {
		"shirt": {
			"diffuse": preload("res://assets/character_parts/clothing/shirt_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/shirt_walk_gray_normal.png") # _work yok
		},
		"shirtless": {
			 "diffuse": preload("res://assets/character_parts/clothing/shirtless_walk_gray.png"), # _work yok
			 "normal": preload("res://assets/character_parts/character_parts_normals/shirtless_walk_gray_normal.png") # _work yok
		}
	},
	"mouth": {
		"1": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth1_walk.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth1_walk_normal.png") # _work yok
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/mouth/mouth2_walk.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/mouth2_walk_normal.png") # _work yok
		}
	},
	"eyes": {
		"1": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes1_walk.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes1_walk_normal.png") # _work yok
		},
		"2": {
			"diffuse": preload("res://assets/character_parts/eyes/eyes2_walk.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/eyes2_walk_normal.png") # _work yok
		}
	},
	"beard": {
		"style1": {
			"diffuse": preload("res://assets/character_parts/beard/beard_style1_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/beard_style1_walk_gray_normal.png") # _work yok
		},
		"style2": {
			"diffuse": preload("res://assets/character_parts/beard/beard_style2_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/beard_style2_walk_gray_normal.png") # _work yok
		}
	},
	"hair": {
		"style1": {
			# <<< DÜZELTME: Büyük/küçük harf düzeltildi >>>
			"diffuse": preload("res://assets/character_parts/hair/hair_style1_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style1_walk_gray_normal.png") # _work yok
		},
		"style2": {
			"diffuse": preload("res://assets/character_parts/hair/hair_style2_walk_gray.png"), # _work yok
			"normal": preload("res://assets/character_parts/character_parts_normals/hair_style2_walk_gray_normal.png") # _work yok
		}
	},
}
# <<< YENİ SONU >>>

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	randomize()
	# <<< YENİ: Timer Oluşturma >>>
	fetching_timer = Timer.new()
	fetching_timer.one_shot = true
	fetching_timer.timeout.connect(_on_fetching_timer_timeout)
	add_child(fetching_timer)
	
	wait_at_source_timer = Timer.new()
	wait_at_source_timer.one_shot = true
	wait_at_source_timer.wait_time = wait_at_source_duration
	wait_at_source_timer.timeout.connect(_on_wait_at_source_timer_timeout)
	add_child(wait_at_source_timer)
	# <<< YENİ SONU >>>

	# <<< YENİ: Boş Zaman Aktivite Zamanlayıcısı >>>
	idle_activity_timer = Timer.new()
	idle_activity_timer.one_shot = true
	idle_activity_timer.timeout.connect(_on_idle_activity_timer_timeout)
	add_child(idle_activity_timer)
	_current_idle_activity = "wandering" # Başlangıçta gezin
	# <<< YENİ SONU >>>

	# <<< DEBUG: HeldItemSprite kontrolü >>>
	#print("Worker %d - HeldItemSprite Node in _ready: " % worker_id, held_item_sprite)
	# <<< DEBUG SONU >>>

	# Başlangıçta görünür yapalım
	visible = true
	# <<< YENİ: Başlangıç Y Konumunu ve Hedefini Ayarla >>>
	global_position.y = randf_range(0.0, VERTICAL_RANGE_MAX)
	_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
	# <<< YENİ SONU >>>

	# <<< YENİ: Başlangıç Hedefini Ayarla >>>
	if is_instance_valid(housing_node):
		move_target_x = housing_node.global_position.x
	else:
		# Barınak yoksa (bir hata durumunda), hedefi kendi konumu yap
		move_target_x = global_position.x 
	# <<< ESKİ KOD >>>
	# move_target_x = global_position.x # Başlangıçta hedefi kendi konumu yap
	# <<< ESKİ KOD BİTİŞ >>>

	# <<< YENİ: HeldItemSprite için CanvasTexture oluştur/kontrol et >>>
	if is_instance_valid(held_item_sprite):
		# Eğer texture CanvasTexture değilse (veya null ise), yenisini ata.
		if not held_item_sprite.texture is CanvasTexture:
			##print("Worker %d: Initializing/Resetting HeldItemSprite texture to CanvasTexture." % worker_id) # Debug için
			held_item_sprite.texture = CanvasTexture.new()
		# Her durumda başlangıçta gizli olduğundan emin ol
		held_item_sprite.hide()
	# <<< YENİ SONU >>>

	# <<< YENİ: Görselleri Güncelle (eğer appearance atanmışsa) >>>
	if appearance:
		update_visuals()
	# <<< YENİ SONU >>>
	###TODO: Village Manager önce saveli villagerları loadlayıp sonra başlatmalı, initalize new villager sadece yeni villager doğduğunda çağırılmalı
	if NPC_Info.is_empty() == true:
		Initialize_New_Villager()
	else:
		$NamePlate.text = NPC_Info["Info"]["Name"]
func Save_Villager_Info():
	VillagerAiInitializer.Saved_Villagers.append(NPC_Info)
	
#func Load_Villager_Info(VillagerInfo:Dictionary):
	#NPC_Info = VillagerInfo

func Initialize_New_Villager():
	NPC_Info = VillagerAiInitializer.get_villager_info()
	$NamePlate.text = NPC_Info["Info"]["Name"]

func _physics_process(delta: float) -> void:
	# AI kamili workerların sağa sola dönmesini spriteları döndürmek yerine
	# tüm node'un X scale'ını değiştirerek yaptığı için böyle isim plakasını tersine çevirmemiz gerekti
	if scale.x < 0:
		$NamePlate.scale.x = -1
	else:
		$NamePlate.scale.x = 1
		
	# <<< YENİ: Mevcut Duruma Göre Animasyon Belirleme >>>
	var target_anim = "idle" # Varsayılan animasyon
	var target_pos = Vector2(move_target_x, _target_global_y)
	# Hareket durumu hesaplama
	var distance = global_position.distance_to(target_pos)
	var moving = distance > 1.0 # <<< DÜZELTME: Eşiği 1.0 yaptık >>>
	# Eğer idle/socializing durumunda ve aktivite gezinme değilse, hareket etme
	# <<< DEĞİŞİKLİK: Check _is_briefly_idling as well >>>
	if (current_state == State.AWAKE_IDLE or current_state == State.SOCIALIZING) and (_current_idle_activity != "wandering" or _is_briefly_idling):
		moving = false
	# Diğer hareketsiz durumlarda da hareket etme (Zaten moving = false olmalı ama garantiye alalım)
	elif current_state == State.SLEEPING or current_state == State.WORKING_INSIDE or \
		 current_state == State.WAITING_OFFSCREEN or current_state == State.WAITING_AT_SOURCE:
		moving = false

	# <<< YENİ DEBUG: Hareket Durumu Kontrolü >>>
	# <<< DEĞİŞİKLİK: 180 Frame\'de bir yazdır >>>
	#if _debug_frame_counter % 180 == 0:
		# <<< YENİ: Daha Detaylı Debug >>>
		#print("Worker %d [%s] - Pos: (%.1f, %.1f), Target: (%.1f, %.1f), Dist: %.1f, Moving: %s, Activity: %s, Job: %s" % [
			#worker_id,
			#State.keys()[current_state],
			#global_position.x, global_position.y,
			#move_target_x, _target_global_y,
			#distance,
			#moving,
			#_current_idle_activity,
			#assigned_job_type if assigned_job_type != "" else "None"
		#])
	# <<< YENİ DEBUG SONU >>>

	# Animasyon seçimi
	if moving:
		match current_state:
			State.GOING_TO_BUILDING_FIRST, \
			State.GOING_TO_SLEEP:
				target_anim = "walk"
			State.FETCHING_RESOURCE, \
			State.WORKING_OFFSCREEN, \
			State.RETURNING_FROM_WORK:
				target_anim = "walk_tool"
			State.RETURNING_FROM_FETCH:
				target_anim = "walk_carry"
			# AWAKE_IDLE ve SOCIALIZING için hareket sadece _current_idle_activity == "wandering" ise olur
			# (ve moving=true ise aktivite wander demektir)
			State.AWAKE_IDLE, State.SOCIALIZING:
				target_anim = "walk" # moving=true ise zaten wander aktivitesindedir
				# <<< YENİ DEBUG >>>
				# <<< YENİ DEBUG SONU >>>
			_:
				target_anim = "walk" # Bilinmeyen hareketli state için varsayılan
	else: # Hareket etmiyor (moving = false)
		match current_state:
			State.SLEEPING, State.WORKING_INSIDE, State.WAITING_OFFSCREEN, State.WAITING_AT_SOURCE:
				target_anim = ""
				visible = false
			State.AWAKE_IDLE, State.SOCIALIZING:
				# Mevcut boş zaman aktivitesine göre animasyon
				# Not: _choose_next_idle_activity non-wander seçtiyse animasyonu zaten başlattı,
				# bu yüzden burası çoğunlukla activity="wandering" ve moving=false için "idle" ayarlar.
				match _current_idle_activity:
					"wandering":
						target_anim = "idle" # Gezinme hedefine vardıysa idle
					"sit":
						# Burada tekrar ayarlamak sorun olmaz ama gereksiz olabilir.
						target_anim = "sit"
					"lie":
						# Zaten _choose_next_idle_activity içinde play_animation("lie") çağrıldı.
						target_anim = "lie"
					"drink":
						# Zaten _choose_next_idle_activity içinde play_animation("drink") çağrıldı.
						target_anim = "drink"
					"idling_briefly": # <<< YENİ / DEĞİŞTİ >>>
						target_anim = "idle" # Brief idle state uses idle animation
					_:
						target_anim = "idle" # Bilinmeyen aktivite
			_:
				target_anim = "idle" # Bilinmeyen hareketsiz state için varsayılan idle

	# <<< DEBUG #print: Idle/Socializing Animasyon Seçimi >>>
	_debug_frame_counter += 1
	#if current_state == State.AWAKE_IDLE or current_state == State.SOCIALIZING:
		# Sorunlu durumu yakala:
		#if not moving and target_anim == 'walk':
			##print("!!! Worker %d - PROBLEM? State: %s, Activity: '%s', Moving: False, TargetAnim: 'walk'" % [worker_id, State.keys()[current_state], _current_idle_activity])
		## Genel durumu seyreltilmiş olarak yazdır:
		#elif _debug_frame_counter % 180 == 0: # <<< DEĞİŞİKLİK: Her 180 frame'de bir >>>
			##print("Worker %d - State: %s, Activity: '%s', Moving: %s, TargetAnim: '%s' (Frame: %d)" % [worker_id, State.keys()[current_state], _current_idle_activity, moving, target_anim, _debug_frame_counter])
	# <<< DEBUG #print SONU >>>

	# Gizli state'ler dışındaysa görünür yap
	if target_anim != "":
		visible = true # Yeni mantıkta visible burada ayarlanıyor

	# Animasyonu ve texture'ları GÜNCELLE (State Machine'den ÖNCE)
	if target_anim != "":
		# <<< DEĞİŞİKLİK: Use _current_animation_name for check >>>
		if _current_animation_name != target_anim:
			# <<< YENİ DEBUG formatı >>>
			#print("Worker %d - Physics calling play_animation('%s') because _current_animation_name is '%s'" % [worker_id, target_anim, _current_animation_name])
			play_animation(target_anim)
		# else: # Already told player to play this animation
			# pass # Do nothing if already commanded
	else:
		# Eğer animasyon yoksa (target_anim == ""), AnimationPlayer'ı durdur
		if _current_animation_name != "" or animation_player.is_playing(): # Stop if we were playing something or player is active
			# #print("Physics: Stopping player because target_anim is empty.") # Debug
			animation_player.stop()
			_current_animation_name = "" # Reset tracked state

	# <<< STATE DEĞİŞİNCE DEBUG #print >>>
	if current_state != _previous_state:
		# State enum'ını string'e çevirmek için State.keys() kullan
		var state_string = "Unknown"
		if current_state >= 0 and current_state < State.size(): # Güvenlik kontrolü
			state_string = State.keys()[current_state]
		#print("Worker %d - State Change -> %s, Moving: %s, TargetAnim: '%s'" % [worker_id, state_string, moving, target_anim])
		_previous_state = current_state # Sadece #print ettiğimizde güncelle
	# <<< DEBUG #print SONU >>>

	# Hedef X'e göre yön belirleme
	var direction = 1.0 # Sağ
	if move_target_x < global_position.x:
		direction = -1.0 # Sol
	scale.x = direction
	
	# <<< YENİ: Vector2 ile Hareket (Sadece Gerekliyse) >>>
	if moving: # Sadece moving true ise hareket et
		global_position = global_position.move_toward(target_pos, move_speed * delta)
	# <<< YENİ SONU >>>
	
	match current_state:
		State.SLEEPING:
			# Uyanma zamanı geldi mi kontrol et
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			# WAKE_UP_HOUR sabitine ve işçiye özel offset'e göre kontrol
			if current_hour == TimeManager.WAKE_UP_HOUR and current_minute >= wake_up_minute_offset:
				# Uyandır!
				current_state = State.AWAKE_IDLE # Şimdilik direkt idle yapalım
				visible = true
				if is_instance_valid(housing_node): # Güvenlik kontrolü
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(housing_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
				else:
					#printerr("Worker %d: Housing node geçerli değil, başlangıç konumu ayarlanamadı!" % worker_id)
					move_target_x = global_position.x # Hedefi kendi konumu yap
					_target_global_y = global_position.y # Hedef Y'yi mevcut Y yap
					
				_current_idle_activity = "" # Reset activity state on wake up
				_is_briefly_idling = false # Reset flag
				_start_next_idle_step() # Decide initial action
				#print("Worker %d uyandı!" % worker_id) # Debug

		State.AWAKE_IDLE:
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			
			# 1. Uyku Zamanı Kontrolü
			if current_hour >= TimeManager.SLEEP_HOUR and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					#print("Worker %d (Idle) uyumaya gidiyor." % worker_id)
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
					idle_activity_timer.stop() # Aktiviteyi durdur
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					return

			# 2. İşe Gitme Zamanı Kontrolü
			elif assigned_job_type != "" and is_instance_valid(assigned_building_node):
				if current_hour == TimeManager.WORK_START_HOUR and current_minute >= work_start_minute_offset:
					#print("Worker %d işe gidiyor (%s)!" % [worker_id, assigned_job_type])
					current_state = State.GOING_TO_BUILDING_FIRST
					move_target_x = assigned_building_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
					idle_activity_timer.stop() # Aktiviteyi durdur
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					return

			# 3. Idle Aktivite Mantığı (Refactored)
			# Check if reached wander destination OR if doing nothing (initial state)
			# And ensure not already processing a brief idle transition
			if not _is_briefly_idling and ( (distance <= 10.0 and _current_idle_activity == "wandering") or _current_idle_activity == "" ):
				_start_next_idle_step() # Decide and initiate the next step

		State.GOING_TO_BUILDING_FIRST:
			# Binaya doğru hareket et (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Binaya vardıysa
				# Binaya vardı, bina türüne ve seviyesine göre karar ver
				if is_instance_valid(assigned_building_node) and assigned_building_node.has_method("get_script"):
					var building_node = assigned_building_node # Kısa isim
					var go_inside = false # Varsayılan: dışarı çık

					# 1. worker_stays_inside özelliğini kontrol et
					if "worker_stays_inside" in building_node and building_node.worker_stays_inside:
						go_inside = true
					else:
						# 2. Seviye ve İLK işçi kontrolü (sadece worker_stays_inside false ise)
						if "level" in building_node and building_node.level >= 2 and \
						   "assigned_worker_ids" in building_node and \
						   not building_node.assigned_worker_ids.is_empty() and \
						   worker_id == building_node.assigned_worker_ids[0]: #<<< DÜZELTİLDİ: [-1] yerine [0]
							go_inside = true

					# Karara göre state değiştir
					if go_inside:
						# --- İÇERİDE ÇALIŞMA MANTIĞI ---
						#print("Worker %d entering building %s (Level %d, FirstWorker=%s) to work inside." % [
							#worker_id, building_node.name, building_node.level if "level" in building_node else 1, 
							#(true if ("assigned_worker_ids" in building_node and not building_node.assigned_worker_ids.is_empty() and worker_id == building_node.assigned_worker_ids[0]) else false)
						#]) # DEBUG <<< DEĞİŞTİ: LastWorker yerine FirstWorker
						current_state = State.WORKING_INSIDE 
						visible = false # İşçiyi gizle
						global_position = building_node.global_position
					else:
						# --- DIŞARIDA ÇALIŞMA MANTIĞI (MEVCUT KOD) ---
						#print("Worker %d reached building %s (Level %d), going offscreen." % [
							#worker_id, building_node.name, building_node.level if "level" in building_node else 1
						#]) # DEBUG
						# <<< YENİ: Aleti Ayarla ve Göster >>>
						if assigned_job_type in tool_textures and is_instance_valid(held_item_sprite):
							# Texture ataması play_animation içine taşındı
							# held_item_sprite.texture = tool_textures[assigned_job_type] #<<< KALDIRILDI
							pass # play_animation halledecek
						else:
							if is_instance_valid(held_item_sprite): held_item_sprite.hide()
						# <<< YENİ SONU >>>
						current_state = State.WORKING_OFFSCREEN
						if global_position.x < 960:
							move_target_x = -2500.0
							_target_global_y = global_position.y # Hedef Y'yi mevcut Y yapalım ki sadece X ekseninde gitsin
						else:
							move_target_x = 2500.0
							_target_global_y = global_position.y # Hedef Y'yi mevcut Y yapalım ki sadece X ekseninde gitsin
				else:
					# Bina geçerli değil veya scripti yoksa varsayılan davranış
					#printerr("Worker %d reached target, but assigned_building_node is invalid or has no script!" % worker_id)
					current_state = State.AWAKE_IDLE # Güvenli bir duruma geç

				# <<< Reset idle flags on state change >>>
				idle_activity_timer.stop()
				_is_briefly_idling = false
				_current_idle_activity = ""

		State.WORKING_OFFSCREEN:
			# Ekran dışına doğru hareket et
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Ekran dışı hedefine vardıysa
				# Ekran dışına ulaştı
				#print("Worker %d ekran dışına çıktı, çalışıyor (beklemede)." % worker_id)
				_offscreen_exit_x = global_position.x
				if is_instance_valid(held_item_sprite): held_item_sprite.hide()
				visible = false
				current_state = State.WAITING_OFFSCREEN
				# <<< Reset idle flags >>>
				idle_activity_timer.stop()
				_is_briefly_idling = false
				_current_idle_activity = ""

		State.WORKING_INSIDE:
			_start_fetching_timer()
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			if current_hour == TimeManager.WORK_END_HOUR and current_minute >= work_end_minute_offset:
				#print("Worker %d finished working inside building." % worker_id)
				visible = true 
				if not fetching_timer.is_stopped():
					fetching_timer.stop()
				
				if is_instance_valid(assigned_building_node):
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(assigned_building_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
				else:
					pass 

				if current_hour >= TimeManager.SLEEP_HOUR:
					if is_instance_valid(housing_node):
						#print("Worker %d going to sleep from inside building." % worker_id)
						current_state = State.GOING_TO_SLEEP
						move_target_x = housing_node.global_position.x
						_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
						if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					else:
						#print("Worker %d finished work, no housing, socializing." % worker_id)
						current_state = State.SOCIALIZING
						_is_briefly_idling = false # <<< Reset flag >>>
						_current_idle_activity = "" # <<< Reset activity >>>
						_start_next_idle_step() # Start socializing behavior
						# var wander_range = 150.0 # Handled by _start_next_idle_step
						# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
						# _target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
						if is_instance_valid(held_item_sprite): held_item_sprite.hide()
				else:
					#print("Worker %d finished work, socializing." % worker_id)
					current_state = State.SOCIALIZING
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					_start_next_idle_step() # Start socializing behavior
					# var wander_range = 150.0 # Handled by _start_next_idle_step
					# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					# _target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()

		State.WAITING_OFFSCREEN:
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			if current_hour == TimeManager.WORK_END_HOUR and current_minute >= work_end_minute_offset:
				#print("Worker %d işten dönüyor." % worker_id)
				current_state = State.RETURNING_FROM_WORK
				visible = true
				var start_margin = 5.0
				var start_x = 0.0
				if _offscreen_exit_x < 0:
					start_x = _offscreen_exit_x - start_margin
				else:
					start_x = _offscreen_exit_x + start_margin
				# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
				global_position = Vector2(start_x, randf_range(0.0, VERTICAL_RANGE_MAX))
				
				if is_instance_valid(assigned_building_node):
					move_target_x = assigned_building_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
				else:
					#printerr("Worker %d: Returning from work but building is invalid! Socializing." % worker_id)
					current_state = State.SOCIALIZING
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					_start_next_idle_step() # Start socializing behavior
					# var wander_range = 150.0 # Handled by _start_next_idle_step
					# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					# _target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)

		State.RETURNING_FROM_WORK:
			# Binaya doğru hareket et (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Binaya vardıysa
				#print("Worker %d reached building after returning from work, socializing." % worker_id)
				current_state = State.SOCIALIZING
				_is_briefly_idling = false # <<< Reset flag >>>
				_current_idle_activity = "" # <<< Reset activity >>>
				_start_next_idle_step() # Start socializing behavior
				# var wander_range = 150.0 # Handled by _start_next_idle_step
				# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
				# _target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)

		State.SOCIALIZING:
			var current_hour = TimeManager.get_hour()
			# Uyku Zamanı Kontrolü
			if current_hour >= TimeManager.SLEEP_HOUR:
				if is_instance_valid(housing_node):
					#print("Worker %d uyumaya gidiyor." % worker_id)
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
					idle_activity_timer.stop() # Aktiviteyi durdur
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					return
				#else:
					#printerr("Worker %d: Uyuyacak yer (housing_node) yok!" % worker_id)

			# Sosyalleşme/Boşta Aktivite Mantığı (Refactored)
			# Check if reached wander destination AND ensure not already processing brief idle
			if not _is_briefly_idling and distance <= 10.0 and _current_idle_activity == "wandering":
				_start_next_idle_step() # Decide and initiate the next step

		State.GOING_TO_SLEEP:
			# Barınağa doğru hareket et (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Barınağa vardıysa
				#print("Worker %d barınağa ulaştı ve uykuya daldı." % worker_id)
				current_state = State.SLEEPING
				visible = false
				idle_activity_timer.stop() # <<< Stop timer >>>
				_is_briefly_idling = false # <<< Reset flag >>>
				_current_idle_activity = "" # <<< Reset activity >>>
				if is_instance_valid(housing_node):
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(housing_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))

		State.FETCHING_RESOURCE:
			# Hedef kaynak binasına git (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Hedefe vardıysa
				#print("Worker %d reached fetch destination, waiting..." % worker_id)
				current_state = State.WAITING_AT_SOURCE
				visible = false
				wait_at_source_timer.start()
				# <<< Reset idle flags >>>
				idle_activity_timer.stop()
				_is_briefly_idling = false
				_current_idle_activity = ""

		State.WAITING_AT_SOURCE:
			pass

		State.RETURNING_FROM_FETCH:
			# Binaya geri dön (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Binaya vardıysa
				#print("Worker %d returned to building after fetching." % worker_id)
				current_state = State.WORKING_INSIDE
				visible = false
				# <<< Reset idle flags >>>
				idle_activity_timer.stop()
				_is_briefly_idling = false
				_current_idle_activity = "" # No longer idling
				if is_instance_valid(assigned_building_node):
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(assigned_building_node.global_position.x, randf_range(0.0, VERTICAL_RANGE_MAX))
					if assigned_building_node.has_method("finished_fetching"):
						assigned_building_node.finished_fetching()
					#else:
						#printerr("Worker %d: Building %s has no finished_fetching method!" % [worker_id, assigned_building_node.name])
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()

		_:
			pass # Bilinmeyen veya henüz işlenmeyen durumlar

# Worker'ın scriptine set fonksiyonları eklemek daha güvenli olabilir:
# --- Worker.gd içine eklenecek opsiyonel set fonksiyonları ---
# func set_worker_id(id: int):
#     worker_id = id
# func set_housing_node(node: Node2D):
#     housing_node = node
# ---------------------------------------------------------

#func _on_animation_finished(anim_name):
#	if anim_name == "walk":
#		$AnimatedSprite2D.play("idle")

# <<< YENİ FONKSİYON BAŞLANGIÇ >>>
# Bina yükseltmesi tamamlandığında çağrılır (eğer bu işçi ilk işçiyse ve dışarıdaysa)
func switch_to_working_inside():
	if current_state == State.WORKING_OFFSCREEN or current_state == State.WAITING_OFFSCREEN:
		# #print("Worker %d switching from OFFSCREEN to WORKING_INSIDE due to building upgrade." % worker_id) #<<< KALDIRILDI
		current_state = State.WORKING_INSIDE
		visible = false
		# İsteğe bağlı: İşçiyi bina girişine yakın bir yere ışınlayabilir veya
		# sadece görünür yapıp animasyonu güncelleyebiliriz. Şimdilik görünür yapalım.
		#$AnimatedSprite2D.play("idle") # Veya uygun bir 'working_inside' animasyonu varsa o
	#else:
		# Zaten içerideyse veya başka bir durumdaysa işlem yapma
		# #print("Worker %d not switching state, current state: %s" % [worker_id, State.keys()[current_state]]) #<<< KALDIRILDI
# <<< YENİ FONKSİYON BİTİŞ >>>

# <<< YENİ FONKSİYON BAŞLANGIÇ: switch_to_working_offscreen >>>
# İşçi içeride çalışırken (WORKING_INSIDE) dışarıda çalışmaya geçirmek için
func switch_to_working_offscreen():
	if current_state == State.WORKING_INSIDE:
		# #print("Worker %d switching from INSIDE to WORKING_OFFSCREEN." % worker_id) #<<< KALDIRILDI
		current_state = State.WORKING_OFFSCREEN
		visible = true # Görünür yap
		# Binanın konumuna göre ekran dışı hedefini belirle
		if is_instance_valid(assigned_building_node):
			if assigned_building_node.global_position.x < 960: # Kabaca ekran merkezi
				move_target_x = -2500.0
			else:
				move_target_x = 2500.0
			# Pozisyonu bina konumu yap ki oradan yürümeye başlasın
			global_position = assigned_building_node.global_position
		else:
			# Bina geçerli değilse, bulunduğu yerden rastgele bir yöne gitsin? Güvenli varsayım:
			#printerr("Worker %d switching to OFFSCREEN but building node is invalid. Using current pos." % worker_id)
			if global_position.x < 960: 
				move_target_x = -2500.0
			else:
				move_target_x = 2500.0
		
		$AnimatedSprite2D.play("walk") # Yürüme animasyonunu başlat
	#else:
		# Zaten dışarıdaysa veya başka bir durumdaysa işlem yapma
		# #print("Worker %d not switching to OFFSCREEN, current state: %s" % [worker_id, State.keys()[current_state]]) #<<< KALDIRILDI
# <<< YENİ FONKSİYON BİTİŞ >>>

# <<< YENİ: Zamanlayıcı Sinyali İşleyici >>>
func _on_fetching_timer_timeout():
	# Sadece içeride çalışırken ve bina geçerliyse tetiklenmeli
	if current_state != State.WORKING_INSIDE or not is_instance_valid(assigned_building_node):
		return

	# <<< YENİ: İş Bitiş Saati Kontrolü >>>
	var current_hour = TimeManager.get_hour()
	if current_hour >= TimeManager.WORK_END_HOUR:
		#print("Worker %d stopping fetch timer, it's end of work time." % worker_id)
		# Fetch timer zaten doldu, tekrar başlatmaya gerek yok.
		# Doğrudan iş bitiş mantığını çalıştır (WORKING_INSIDE'dan kopyalandı/uyarlandı)
		visible = true # Görünür yap (eğer zaten değilse)
		
		# Konumu bina konumu yap
		if is_instance_valid(assigned_building_node):
			global_position = assigned_building_node.global_position
		
		# Uyku vakti mi?
		if current_hour >= TimeManager.SLEEP_HOUR:
			if is_instance_valid(housing_node):
				#print("Worker %d going to sleep directly after fetch timer (work end time)." % worker_id)
				current_state = State.GOING_TO_SLEEP
				move_target_x = housing_node.global_position.x
				if is_instance_valid(held_item_sprite): held_item_sprite.hide() # <<< YENİ: Fetch sonrası uykuya giderken aleti gizle
			else:
				#print("Worker %d finished work (fetch timer), no housing, socializing." % worker_id)
				current_state = State.SOCIALIZING
				var wander_range = 150.0
				move_target_x = global_position.x + randf_range(-wander_range, wander_range)
				if is_instance_valid(held_item_sprite): held_item_sprite.hide() # <<< YENİ: Fetch sonrası sosyalleşirken aleti gizle
			return # Fetch işlemine devam etme
	# <<< YENİ KONTROL SONU >>>
		
	# Binanın izin fonksiyonu var mı ve izin veriyor mu?
	if assigned_building_node.has_method("can_i_fetch") and assigned_building_node.can_i_fetch():
		# 1. Binanın hangi kaynaklara ihtiyacı olduğunu öğren
		var required = {}
		if assigned_building_node.has_method("get") and assigned_building_node.get("required_resources") is Dictionary:
			required = assigned_building_node.get("required_resources")
		
		if required.is_empty():
			#printerr("Worker %d: Cannot determine required resources for %s! Aborting fetch." % [worker_id, assigned_building_node.name])
			assigned_building_node.finished_fetching() # İzni geri ver
			_start_fetching_timer() # Zamanlayıcıyı yeniden başlat
			return
			
		# 2. İhtiyaç duyulan kaynaklardan birini rastgele seç
		var resource_to_fetch = required.keys()[randi() % required.size()]
		
		
		# 3. VillageManager'dan o kaynağı üreten binanın konumunu al
		var target_pos = VillageManager.get_source_building_position(resource_to_fetch)
		
		if target_pos == Vector2.ZERO:
			#print("Worker %d: Could not find a source building for '%s'. Skipping fetch." % [worker_id, resource_to_fetch])
			assigned_building_node.finished_fetching() # İzni geri ver
			_start_fetching_timer() # Zamanlayıcıyı yeniden başlat
			return
			
		# 4. Hareketi başlat
		#print("Worker %d starting resource fetch for '%s' towards %s..." % [worker_id, resource_to_fetch, target_pos])
		current_state = State.FETCHING_RESOURCE
		visible = true
		move_target_x = target_pos.x # Hedef X'i ayarla
	else:
		# İzin yok veya fonksiyon yok, tekrar bekle (ama saat kontrolü zaten yapıldı)
		_start_fetching_timer()
# <<< YENİ SONU >>>

# <<< YENİ: Zamanlayıcı Başlatma Fonksiyonu >>>
func _start_fetching_timer():
	# Sadece içeride çalışan ve işleme binasında olanlar için
	if current_state == State.WORKING_INSIDE and \
	   is_instance_valid(assigned_building_node) and \
	   assigned_building_node.has_method("get") and \
	   assigned_building_node.get("worker_stays_inside") == true: # Güvenli erişim
		
		if fetching_timer.is_stopped(): # Zaten çalışmıyorsa
			var wait_time = randf_range(fetch_interval_min, fetch_interval_max)
			fetching_timer.start(wait_time)
			# #print("Worker %d fetching timer started (%s sec)." % [worker_id, wait_time]) # Debug
# <<< YENİ SONU >>>

# YENİ Timer için timeout fonksiyonu
func _on_wait_at_source_timer_timeout():
	# Sadece WAITING_AT_SOURCE durumundaysa çalışmalı
	if current_state != State.WAITING_AT_SOURCE:
		return
		
	#print("Worker %d finished waiting at source, returning to building." % worker_id)
	current_state = State.RETURNING_FROM_FETCH
	visible = true # Tekrar görünür yap
	if is_instance_valid(assigned_building_node):
		move_target_x = assigned_building_node.global_position.x
	else:
		# Bina yoksa? Güvenli bir yere git?
		#printerr("Worker %d: Building node invalid while returning from fetch!" % worker_id)
		move_target_x = global_position.x
# <<< YENİ SONU >>>

# <<< YENİ: Stil Adı Çıkarma Fonksiyonu (Düzeltilmiş) >>>
func get_style_from_texture_path(path: String) -> String:
	if path.is_empty(): return "default"

	var filename = path.get_file()
	var base_name = filename.get_basename()

	var parts = base_name.split("_")
	if parts.is_empty(): return "default"

	# Clothing için özel kontrol (örn: shirt_walk_gray)
	if parts[0] == "shirt" or parts[0] == "shirtless":
		return parts[0] # Stil adı ilk parça
	# Mouth ve Eyes için özel kontrol (örn: mouth1, eyes2)
	elif parts[0].begins_with("mouth"):
		var style_num = parts[0].trim_prefix("mouth")
		if style_num.is_valid_int(): return style_num
	elif parts[0].begins_with("eyes"):
		var style_num = parts[0].trim_prefix("eyes")
		if style_num.is_valid_int(): return style_num
	# Diğer parçalar için stil anahtar kelimelerini kontrol et (örn: pants_basic, hair_style1)
	else:
		var style_keywords = ["basic", "short", "style1", "style2"] # Giyim stilleri yukarıda ele alındı
		for i in range(1, parts.size()):
			if parts[i] in style_keywords:
				return parts[i]

	# Hiçbir stil bulunamazsa (örn. body)
	return "default"
# <<< YENİ SONU >>>

# <<< YENİ: Animasyon Oynatma Fonksiyonu (Genişletilmiş) >>>
func play_animation(anim_name: String):
	if !is_instance_valid(animation_player):
		#printerr("Worker %d: AnimationPlayer bulunamadı!" % worker_id)
		return

	# <<< REMOVING CHECK AGAIN >>>
	# if _current_animation_name == anim_name:
	#	return 

	#print("Worker %d - Calling play_animation('%s') (Internal state was '%s')" % [worker_id, anim_name, _current_animation_name])
	_current_animation_name = anim_name # Update tracked state *immediately*

	# 1. Animasyonu Oynat
	animation_player.play(anim_name)
	# Seek to 0 for default animations
	if anim_name == "idle" or anim_name == "walk":
		if animation_player.has_animation(anim_name): # Check if animation exists
			animation_player.seek(0.0, true) # Seek to beginning, update immediately

	# 2. Texture ve Normal Map'leri Ayarla
	var texture_set_to_use = null
	var hide_held_item = true

	# <<< CHANGE: Explicitly map idle/walk/walk_carry to walk_work_textures >>>
	match anim_name:
		"idle", "walk":
			# <<< DÜZELTME: "walk" için doğru texture seti kullanılıyor >>>
			# TODO: "walk_textures" adında bir sözlüğün var olduğunu ve 
			# aletsiz yürüme texture'larını içerdiğini varsayıyoruz.
			# Eğer bu sözlük yoksa veya adı farklıysa, burayı güncellemeniz gerekir.
			texture_set_to_use = walk_textures 
			# <<< YENİ DEBUG >>>
			#print("Worker %d - play_animation('%s'): Assigning texture set: walk_textures" % [worker_id, anim_name])
			# hide_held_item remains true
		"walk_tool":
			texture_set_to_use = walk_work_textures
			# <<< YENİ DEBUG >>>
			#print("Worker %d - play_animation('%s'): Assigning texture set: walk_work_textures" % [worker_id, anim_name])
			hide_held_item = false
		"sit":
			texture_set_to_use = idle_sit_textures
		"lie":
			texture_set_to_use = idle_lie_textures
		"drink":
			texture_set_to_use = idle_drink_textures
		"walk_carry": # Assuming walk_carry uses the same base textures as walk/work
			texture_set_to_use = walk_work_textures # Needs verification
			hide_held_item = true # Currently no visual item for walk_carry
		_:
			#printerr("Worker %d: Unknown animation name '%s' in play_animation. Using default visuals." % [worker_id, anim_name])
			texture_set_to_use = walk_work_textures # Fallback

	# <<< REMOVED the old else block >>>
	# The following logic now applies to ALL animations handled here.
	if texture_set_to_use != null:
		# --- Texture Seti Kullan --- 
		var parts_to_update = {
			"body": body_sprite, "pants": pants_sprite, "clothing": clothing_sprite,
			"mouth": mouth_sprite, "eyes": eyes_sprite, "beard": beard_sprite, "hair": hair_sprite
		}
		# <<< MOVED: Frame reset check >>>
		var reset_frame = (anim_name == "idle" or anim_name == "walk")

		for part_name in parts_to_update:
			var sprite: Sprite2D = parts_to_update[part_name]
			var original_canvas_texture: CanvasTexture = null
			if is_instance_valid(sprite) and appearance:
				match part_name:
					"body": original_canvas_texture = appearance.body_texture
					"pants": original_canvas_texture = appearance.pants_texture
					"clothing": original_canvas_texture = appearance.clothing_texture
					"mouth": original_canvas_texture = appearance.mouth_texture
					"eyes": original_canvas_texture = appearance.eyes_texture
					"beard": original_canvas_texture = appearance.beard_texture
					"hair": original_canvas_texture = appearance.hair_texture

			if not is_instance_valid(sprite):
				# Don't hide if original_canvas_texture is invalid but sprite is fine
				continue
			if not is_instance_valid(original_canvas_texture):
				# If appearance resource is missing texture, hide the sprite part
				sprite.hide()
				continue

			var original_diffuse_path = original_canvas_texture.diffuse_texture.resource_path if is_instance_valid(original_canvas_texture.diffuse_texture) else ""
			var style = get_style_from_texture_path(original_diffuse_path)

			if texture_set_to_use.has(part_name) and texture_set_to_use[part_name].has(style):
				var textures = texture_set_to_use[part_name][style]
				var new_canvas_texture = CanvasTexture.new()

				if textures.has("diffuse") and textures["diffuse"] != null:
					new_canvas_texture.diffuse_texture = textures["diffuse"]
				else:
					# If specific animation diffuse texture is missing, hide the part
					# #print("Hiding %s because diffuse is missing for %s style %s" % [part_name, anim_name, style]) # Debug
					sprite.hide()
					continue

				if textures.has("normal") and textures["normal"] != null:
					new_canvas_texture.normal_texture = textures["normal"]

				sprite.texture = new_canvas_texture

				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"beard": sprite.modulate = appearance.hair_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE

				sprite.show()
				# <<< MOVED: Reset frame here >>>
				if reset_frame:
					sprite.frame = 0
			else:
				# Fallback: Use original texture from appearance if specific style/part not found in target set
				# #print("Using original texture for %s in %s because style %s not found in set" % [part_name, anim_name, style]) # Debug
				sprite.texture = original_canvas_texture
				match part_name:
					"body": sprite.modulate = appearance.body_tint
					"pants": sprite.modulate = appearance.pants_tint
					"clothing": sprite.modulate = appearance.clothing_tint
					"beard": sprite.modulate = appearance.hair_tint
					"hair": sprite.modulate = appearance.hair_tint
					_: sprite.modulate = Color.WHITE
				sprite.show()
				# <<< MOVED: Reset frame here >>>
				if reset_frame:
					sprite.frame = 0

		# --- Alet/Held Item Ayarı ---
		if anim_name == "walk_tool":
			if is_instance_valid(held_item_sprite):
				# <<< YENİ DEBUG: walk_tool içinde >>>
				#print("Worker %d - play_animation('walk_tool'): Checking job type: '%s'" % [worker_id, assigned_job_type])
				# <<< YENİ DEBUG SONU >>>
				if assigned_job_type in tool_textures and assigned_job_type in tool_normal_textures:
					var tool_diffuse_tex = tool_textures[assigned_job_type]
					var tool_normal_tex = tool_normal_textures[assigned_job_type]

					var tool_canvas_texture = CanvasTexture.new()
					tool_canvas_texture.diffuse_texture = tool_diffuse_tex
					tool_canvas_texture.normal_texture = tool_normal_tex
					held_item_sprite.texture = tool_canvas_texture
					held_item_sprite.modulate = Color.WHITE
					held_item_sprite.show()
					hide_held_item = false
				else:
					# <<< YENİ DEBUG: Alet bulunamadı >>>
					#print("Worker %d - play_animation('walk_tool'): Job type '%s' not in tool_textures/tool_normal_textures. Hiding item." % [worker_id, assigned_job_type])
					# <<< YENİ DEBUG SONU >>>
					held_item_sprite.hide()
					hide_held_item = true
		# elif anim_name == "drink": # Add logic for other items if needed

		# --- Gizle (Eğer hide_held_item true ise) ---
		if hide_held_item and is_instance_valid(held_item_sprite):
			# <<< YENİ DEBUG >>>
			#print("Worker %d - play_animation('%s'): Hiding held item (hide_held_item=%s, sprite valid=%s)" % [worker_id, anim_name, hide_held_item, is_instance_valid(held_item_sprite)])
			held_item_sprite.hide()
			# <<< YENİ DEBUG >>>
			#print("Worker %d - play_animation('%s'): Held item hidden status: %s" % [worker_id, anim_name, not held_item_sprite.visible])
		#else:
			# <<< YENİ DEBUG >>>
			#print("Worker %d - play_animation('%s'): NOT hiding held item (hide_held_item=%s, sprite valid=%s)" % [worker_id, anim_name, hide_held_item, is_instance_valid(held_item_sprite)])
	#else:
		# Uyarı yazdır - bu bloğa hiç ulaşılmamalı normalde
		#printerr("Worker %d: Texture set was null for animation '%s'. Check play_animation logic." % [worker_id, anim_name])

	# 3. Frame Sayılarını Ayarla (Yeni yaklaşım - problematik else bloğundan kaçınır)
	var default_hf = 12
	var default_vf = 1
	var hf = default_hf
	var vf = default_vf

	# Eğer özel frame sayısı varsa kullan
	if animation_frame_counts.has(anim_name):
		var frames = animation_frame_counts[anim_name]
		hf = frames["hframes"]
		vf = frames["vframes"]
	#else:
		# Özel ayar yoksa varsayılanları kullan ve uyarı ver
		#printerr("Worker %d: Frame count not found for animation '%s'. Using defaults." % [worker_id, anim_name])

	# Tüm sprite'lar için frame sayılarını ayarla
	var sprites_to_set_frames = [
		body_sprite, pants_sprite, clothing_sprite, mouth_sprite,
		eyes_sprite, beard_sprite, hair_sprite, held_item_sprite
	]
	for sprite in sprites_to_set_frames:
		if is_instance_valid(sprite):
			sprite.hframes = hf
			sprite.vframes = vf

# <<< play_animation fonksiyonu burada biter >>>

# <<< YENİ: Eksik Fonksiyonların İşlevsel Tanımları >>>

# Appearance resource'una göre sprite'ları günceller
func update_visuals():
	if not appearance:
		#printerr("Worker %d: Appearance resource atanmamış, görseller güncellenemiyor." % worker_id)
		return
	
	# Görselleri güncellemek için mevcut duruma uygun animasyonu tekrar oynatmak
	# yeterli olmalı, çünkü play_animation appearance'ı kullanıyor.
	# Ancak _physics_process zaten her karede doğru animasyonu ayarlamaya çalışıyor.
	# Belki burada sadece başlangıç durumunu ele almak yeterli?
	# Şimdilik sadece bir uyarı yazdıralım, eğer sorun devam ederse burayı geliştirebiliriz.
	#print("Worker %d: update_visuals() çağrıldı." % worker_id)
	# Gerekirse: _determine_and_play_current_animation() gibi bir yardımcı fonksiyon çağırılabilir.
	pass # play_animation zaten appearance kullanıyor, _physics_process tetikleyecek.

# Boş zaman aktivite zamanlayıcısı dolduğunda çağrılır
func _on_idle_activity_timer_timeout():
	# #print("Worker %d: Idle activity timer timeout." % worker_id) # Debug
	# Aktivite bitti, bir sonraki adıma geç
	_start_next_idle_step()

# Bir sonraki boş zaman/sosyalleşme adımını başlatır
func _start_next_idle_step():
	# #print("Worker %d: Starting next idle step..." % worker_id) # Debug
	if not (current_state == State.AWAKE_IDLE or current_state == State.SOCIALIZING):
		# #print("Worker %d: Not in idle/socializing state, aborting _start_next_idle_step." % worker_id) # Debug
		return # Sadece bu durumlarda çalışmalı

	idle_activity_timer.stop() # Önceki zamanlayıcıyı durdur
	_is_briefly_idling = false # Kısa bekleme durumunu sıfırla
	
	# <<< YENİ: Fonksiyonun varlığını kontrol et >>>
	if not has_method("_choose_next_idle_activity"):
		#printerr("Worker %d: _choose_next_idle_activity fonksiyonu bulunamadı!" % worker_id)
		_current_idle_activity = "wandering" # Varsayılana dön
	else:
		# Bir sonraki aktiviteyi seç
		_current_idle_activity = _choose_next_idle_activity()
	# <<< YENİ SONU >>>

	# #print("Worker %d: Chose idle activity: %s" % [worker_id, _current_idle_activity]) # Debug

	if _current_idle_activity == "wandering":
		# Yeni bir gezinme hedefi belirle
		# <<< DÜZENLEME: Gezinme Mesafesi Artırıldı >>>
		var wander_range = 300.0 # Ne kadar uzağa gidebilir - Önceki: 150.0
		# Hedef X: Mevcut X +/- wander_range
		move_target_x = global_position.x + randf_range(-wander_range, wander_range)
		# Hedef Y: 0 ile VERTICAL_RANGE_MAX arasında rastgele
		_target_global_y = randf_range(0.0, VERTICAL_RANGE_MAX)
		# #print("Worker %d: New wander target: (%.1f, %.1f)" % [worker_id, move_target_x, _target_global_y]) # Debug
		# physics_process yürüme animasyonunu (walk) başlatacak
	else:
		# Diğer aktiviteler (sit, lie, drink) için animasyonu oynat ve zamanlayıcıyı başlat
		# <<< DÜZELTME: _current_idle_activity artık doğru ismi içeriyor >>>
		play_animation(_current_idle_activity) # Animasyonu hemen başlat
		var duration = randf_range(idle_activity_duration_min, idle_activity_duration_max)
		idle_activity_timer.start(duration)
		# #print("Worker %d: Starting activity '%s' for %.1f seconds." % [worker_id, _current_idle_activity, duration]) # Debug

# <<< YENİ: _choose_next_idle_activity (Eğer yoksa eklenecek - önceki koddan alınabilir) >>>
# Bu fonksiyonun var olduğunu varsayıyoruz, eğer yoksa eklenmesi gerekir.
# func _choose_next_idle_activity():
# 	 var activity_weights = { ... }
# 	 ... (Fonksiyonun geri kalan içeriği)
# 	 return chosen_activity
# <<< YENİ SONU >>>

# <<< EKLENDİ: _choose_next_idle_activity Fonksiyonu >>>
func _choose_next_idle_activity():
	# Bu durumlar için aktivite seçimi yapma (güvenlik önlemi)
	if current_state != State.AWAKE_IDLE and current_state != State.SOCIALIZING:
		return "wandering" # Hata durumunda varsayılan

	# Aktivite Olasılıkları (Ayarlanabilir)
	# <<< DÜZELTME: Animasyon isimleriyle eşleşen anahtarlar kullanıldı >>>
	var activity_weights = {
		"wandering": 0.5, # %50 gezinme
		"sit": 0.2,   # %20 oturma
		"lie": 0.15,  # %15 uzanma
		"drink": 0.15 # %15 içme
	}
	
	# Toplam ağırlığı hesapla (normallik kontrolü için, isteğe bağlı)
	var total_weight = 0.0
	for key in activity_weights:
		total_weight += activity_weights[key]
	# if total_weight != 1.0: #printerr("Worker %d: Idle activity weights do not sum to 1.0!" % worker_id)
		
	# Rastgele bir değer seç (0 ile toplam ağırlık arasında)
	var rand_val = randf() * total_weight 
	# Debug: #print("Worker %d - Rand Val: %.2f / Total Weight: %.2f" % [worker_id, rand_val, total_weight])
	
	# Kümülatif ağırlığa göre aktivite seçimi
	var chosen_activity = "wandering" # Varsayılan (eğer bir hata olursa)
	var cumulative_weight = 0.0
	for key in activity_weights:
		cumulative_weight += activity_weights[key]
		if rand_val <= cumulative_weight:
			chosen_activity = key
			break # Aktivite seçildi, döngüden çık
			
	# Seçilen aktiviteyi döndür
	# Debug: #print("Worker %d - Chosen Activity: %s" % [worker_id, chosen_activity])
	return chosen_activity
# <<< YENİ SONU >>>
