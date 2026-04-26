extends Node2D

@export var NPC_Info : Dictionary 
var NPCWindow = preload("res://ui/npc_window.tscn")
# <<< YENİ: Appearance Resource >>>
const VillagerAppearance = preload("res://village/scripts/VillagerAppearance.gd")
@export var appearance: VillagerAppearance:
	set(value):
		appearance = value
		if is_node_ready(): # Eğer sahne hazırsa görselleri hemen güncelle
			update_visuals()

var worker_id: int = -1 # VillageManager tarafından atanacak
var is_dungeon_prisoner: bool = false # Zindan kurtarma odasında sadece görsel; AI yok
# Zindan mahkûmu: yerçekimi + basit platformer hareketi
var dungeon_floor_y: float = -1.0   # -1 = henüz ayarlanmadı (sadece fallback)
var dungeon_spawn_x: float = 0.0   # Yatay hareket merkezi
const DUNGEON_PRISONER_WANDER_RANGE: float = 80.0
const DUNGEON_PRISONER_GRAVITY: float = 450.0
const DUNGEON_PRISONER_MOVE_SPEED: float = 42.0
var dungeon_ground_ray: RayCast2D = null
var dungeon_wall_ray: RayCast2D = null
var dungeon_ledge_ray: RayCast2D = null
var dungeon_move_dir: int = 1
var dungeon_idle_timer: float = 0.0
var dungeon_idle_duration: float = 0.0
var dungeon_is_idling: bool = false
var dungeon_walk_timer: float = 0.0
var dungeon_walk_duration: float = 0.0

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
# <<< YENİ: Uyku Denemesi Başarısız Flag >>>
var _sleep_attempt_failed: bool = false # Kapasite dolu olduğunda tekrar denemeyi engelle
var _sleep_retry_timer: Timer # Uyku denemesi başarısız olduğunda bekleme zamanlayıcısı
var _sleep_retry_delay: float = 30.0 # 30 saniye bekle, sonra tekrar dene
# <<< YENİ SONU >>>

# <<< YENİ: Dikey Hareket İçin >>>
var _target_global_y: float = 0.0 # Hedef global Y konumu
const VERTICAL_RANGE_MIN: float = 5.0 # Yürünebilir bandın üst sınırı (aşağı kaydırıldı)
const VERTICAL_RANGE_MAX: float = 30.0 # Y ekseninde hareket aralığı (MIN ile bu değer arası)
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
	RETURNING_FROM_FETCH, # Kaynaktan binaya dönüyor (görsel)
	SICK,              # Hasta (evde yatıyor, görünmez)
	GOING_HOME_SICK    # Hasta olunca evine gidiyor
} 
var current_state = State.AWAKE_IDLE # Başlangıç durumu (Tip otomatik çıkarılacak)

# Atama Bilgileri
var assigned_job_type: String = "" # "wood", "stone", etc. or "" for idle
var assigned_building_node: Node2D = null # Atandığı binanın node'u
var housing_node: Node2D = null # Kaldığı yer (CampFire veya House)
var is_deployed: bool = false # Askerler için: savaş için deploy edildi mi?
var is_sick: bool = false # Hasta mı? (evden çıkmaz, çalışamaz)
var sick_since_day: int = -1 # Hangi günden beri hasta (iyileşme kontrolü için)
var previous_job_type: String = "" # Hastalanmadan önceki iş (iyileşince dönmek için)
var previous_building_node: Node2D = null # Hastalanmadan önceki bina (iyileşince dönmek için)

# Rutin Zamanlaması için Rastgele Farklar
var wake_up_minute_offset: int = randi_range(0, 20) # 0-20 dakika arası rastgelelik (daha doğal görünsün)
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
	if is_dungeon_prisoner:
		_ready_dungeon_prisoner()
		return
	add_to_group("Villagers") # Register for global updates like news
	randomize()
	
	# Debug: Print initialization state
	if NPC_Info.is_empty():
		print("Worker %d _ready: NPC_Info is EMPTY" % worker_id)
	else:
		print("Worker %d _ready: NPC_Info has %d keys. Info present: %s" % [
			worker_id, 
			NPC_Info.size(), 
			NPC_Info.has("Info")
		])
		if NPC_Info.has("Info"):
			print("Worker %d _ready: Info keys: %s" % [worker_id, NPC_Info["Info"].keys()])
	
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
	
	# <<< YENİ: Uyku Denemesi Başarısız Zamanlayıcısı >>>
	_sleep_retry_timer = Timer.new()
	_sleep_retry_timer.one_shot = true
	_sleep_retry_timer.wait_time = _sleep_retry_delay
	_sleep_retry_timer.timeout.connect(_on_sleep_retry_timer_timeout)
	add_child(_sleep_retry_timer)
	# <<< YENİ SONU >>>

	# <<< DEBUG: HeldItemSprite kontrolü >>>
	#print("Worker %d - HeldItemSprite Node in _ready: " % worker_id, held_item_sprite)
	# <<< DEBUG SONU >>>

	# Başlangıçta görünür yapalım
	visible = true
	# <<< YENİ: Başlangıç Y Konumunu ve Hedefini Ayarla >>>
	global_position.y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
	_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
	
	# Z-Index'i ayak pozisyonuna göre ayarla (Y düşük = önde)
	# Su yansımasında görünmesi için z_index'i su sprite'ının z_index'inden (20) düşük tutmalıyız
	var foot_y = get_foot_y_position()
	z_index = _calculate_z_index_from_foot_y(foot_y)
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
	
	if $InteractButton:
		var key_name = InputManager.get_interact_key_name()
		$InteractButton.text = _format_key_name(key_name)
	
	# NamePlate'i varsayılan olarak görünmez yap (sadece en yakın NPC'nin ismi görünecek)
	if $NamePlateContainer:
		$NamePlateContainer.visible = false
	###TODO: Village Manager önce saveli villagerları loadlayıp sonra başlatmalı, initalize new villager sadece yeni villager doğduğunda çağırılmalı

func _ready_dungeon_prisoner() -> void:
	visible = true
	if appearance:
		update_visuals()
	if NPC_Info.has("Info") and NPC_Info["Info"].has("Name"):
		Update_Villager_Name()
	if $NamePlateContainer:
		$NamePlateContainer.visible = true
		# Görsel olarak biraz daha aşağı dursun (fizik pozisyonu bozmadan)
		$BodySprite.position.y += 3
		$PantsSprite.position.y += 3
		$ClothingSprite.position.y += 3
		if is_instance_valid($MouthSprite):
			$MouthSprite.position.y += 3
		if is_instance_valid($EyesSprite):
			$EyesSprite.position.y += 3
		if is_instance_valid($BeardSprite):
			$BeardSprite.position.y += 3
		if is_instance_valid($HairSprite):
			$HairSprite.position.y += 3
	# Zindanda konuşma/etkileşim yok: etkileşim butonunu gizle ve devre dışı bırak
	if $InteractButton:
		$InteractButton.hide()
		$InteractButton.set_process_unhandled_input(false)
	move_target_x = position.x  # İlk hedef kendi konumu
	dungeon_spawn_x = global_position.x  # Yatay hareket merkezi başlangıç pozisyonu olsun
	dungeon_move_dir = 1 if randf() < 0.5 else -1
	dungeon_is_idling = true
	dungeon_idle_timer = 0.0
	dungeon_idle_duration = randf_range(30.0, 45.0) # Uzun oturma süresi
	dungeon_walk_timer = 0.0
	dungeon_walk_duration = randf_range(2.0, 3.0) # Kısa yürüyüşler
	# Zemin / duvar / uçurum için raycast'leri oluştur
	if dungeon_ground_ray == null:
		dungeon_ground_ray = RayCast2D.new()
		dungeon_ground_ray.target_position = Vector2(0, 96) # 1–2 tile aşağı bak
		dungeon_ground_ray.collision_mask = 1
		dungeon_ground_ray.enabled = true
		add_child(dungeon_ground_ray)
	if dungeon_wall_ray == null:
		dungeon_wall_ray = RayCast2D.new()
		dungeon_wall_ray.target_position = Vector2(24, -8) # Öne doğru, hafif yukarı
		dungeon_wall_ray.collision_mask = 1
		dungeon_wall_ray.enabled = true
		add_child(dungeon_wall_ray)
	if dungeon_ledge_ray == null:
		dungeon_ledge_ray = RayCast2D.new()
		dungeon_ledge_ray.target_position = Vector2(24, 64) # Öne ve aşağı, uçurum kontrolü
		dungeon_ledge_ray.collision_mask = 1
		dungeon_ledge_ray.enabled = true
		add_child(dungeon_ledge_ray)
	# Z-index'i düşmanlarla aynı seviyeye sabitle (ENEMY_Z_INDEX = 4, player ~5)
	z_index = 4
	if has_method("play_animation"):
		play_animation("idle")
 
func _physics_process_dungeon_prisoner(delta: float) -> void:
	# Yer çekimi + zemine oturtma
	if dungeon_ground_ray:
		dungeon_ground_ray.global_position = global_position
		dungeon_ground_ray.force_raycast_update()
		if dungeon_ground_ray.is_colliding():
			var hit_pos: Vector2 = dungeon_ground_ray.get_collision_point()
			# Çarpışma noktasının biraz üzerinde dur (tile'ın içine girmesin)
			global_position.y = hit_pos.y - 4.0
		else:
			global_position.y += DUNGEON_PRISONER_GRAVITY * delta
	# Duvar ve uçurum ray'lerini yönüne göre hizala
	if dungeon_wall_ray:
		dungeon_wall_ray.global_position = global_position
		dungeon_wall_ray.target_position.x = 24 * dungeon_move_dir
		dungeon_wall_ray.force_raycast_update()
	if dungeon_ledge_ray:
		dungeon_ledge_ray.global_position = global_position
		dungeon_ledge_ray.target_position.x = 24 * dungeon_move_dir
		dungeon_ledge_ray.force_raycast_update()
	# Basit AI: çoğunlukla idle, arada kısa yürüyüş
	if dungeon_is_idling:
		dungeon_idle_timer += delta
		if _current_animation_name != "sit":
			play_animation("sit")
		if dungeon_idle_timer >= dungeon_idle_duration:
			# Idle bitti, kısa bir yürüyüşe geç
			dungeon_is_idling = false
			dungeon_idle_timer = 0.0
			dungeon_walk_timer = 0.0
			dungeon_walk_duration = randf_range(2.0, 3.0)
	else:
		var hit_wall := dungeon_wall_ray and dungeon_wall_ray.is_colliding()
		var no_ground_ahead := dungeon_ledge_ray and not dungeon_ledge_ray.is_colliding()
		if hit_wall or no_ground_ahead:
			# Duvar veya uçurum: yön değiştir
			dungeon_move_dir *= -1
			# Duvara çarpınca bazen yürüyüşü hemen kesip idle'e geri dön
			if randf() < 0.5:
				dungeon_is_idling = true
				dungeon_idle_timer = 0.0
				dungeon_idle_duration = randf_range(30.0, 45.0)
				if _current_animation_name != "sit":
					play_animation("sit")
		else:
			# Yatay hareket
			global_position.x += float(dungeon_move_dir) * DUNGEON_PRISONER_MOVE_SPEED * delta
			scale.x = dungeon_move_dir
			if $NamePlateContainer:
				$NamePlateContainer.scale.x = -1.0 if scale.x < 0 else 1.0
			if _current_animation_name != "walk":
				play_animation("walk")
		# Yürüme süresi dolunca tekrar idle'e dön
		dungeon_walk_timer += delta
		if dungeon_walk_timer >= dungeon_walk_duration:
			dungeon_is_idling = true
			dungeon_idle_timer = 0.0
			dungeon_idle_duration = randf_range(30.0, 45.0)
			if _current_animation_name != "sit":
				play_animation("sit")
	# Wander aralığının dışına çok çıkmasın, duvar ray'ı kaçırsa bile geri dönsün
	var dx_center = global_position.x - dungeon_spawn_x
	if abs(dx_center) > DUNGEON_PRISONER_WANDER_RANGE:
		var edge_dir = sign(dx_center)
		global_position.x = dungeon_spawn_x + DUNGEON_PRISONER_WANDER_RANGE * edge_dir
		dungeon_move_dir = -edge_dir
	# Zindanda sabit z_index (player'dan geride)
	z_index = 4

func update_news(news_string: String) -> void:
	if NPC_Info.is_empty():
		return
	if not NPC_Info.has("Latest_news") or typeof(NPC_Info["Latest_news"]) != TYPE_ARRAY:
		NPC_Info["Latest_news"] = []
	
	NPC_Info["Latest_news"].push_front(news_string)
	if NPC_Info["Latest_news"].size() > 15:
		NPC_Info["Latest_news"] = NPC_Info["Latest_news"].slice(0, 15)
	# print("Worker %d received news: %s" % [worker_id, news_string])

func Save_Villager_Info():
	VillagerAiInitializer.Saved_Villagers.append(NPC_Info)
	
#func Load_Villager_Info(VillagerInfo:Dictionary):
	#NPC_Info = VillagerInfo
func Update_Villager_Name():
	if NPC_Info.has("Info") and NPC_Info["Info"].has("Name"):
		var name_label = $NamePlateContainer.get_node_or_null("NamePlate")
		if name_label:
			name_label.text = NPC_Info["Info"]["Name"]
	else:
		print("[Worker] ⚠️ Cannot update name: NPC_Info missing 'Info' or 'Name' key. Info keys: ", NPC_Info.keys())
	
	# NamePlate'i varsayılan olarak görünmez yap (zindan mahkûmunda görünür bırak)
	if $NamePlateContainer and not is_dungeon_prisoner:
		$NamePlateContainer.visible = false
	
func Initialize_Existing_Villager(NPCInfo):
		print("Worker %d Initialize_Existing_Villager called with data size: %d" % [worker_id, NPCInfo.size()])
		if NPCInfo.is_empty() == true:
			print("Worker %d: Initialize_Existing_Villager received EMPTY data. Falling back to new villager." % worker_id)
			Initialize_New_Villager()
		else:
			NPC_Info=NPCInfo
			if not NPC_Info.has("Latest_news"):
				NPC_Info["Latest_news"] = []
			elif typeof(NPC_Info["Latest_news"]) == TYPE_STRING:
				NPC_Info["Latest_news"] = [NPC_Info["Latest_news"]] if NPC_Info["Latest_news"] != "" else []
			
			Update_Villager_Name() # Safe update
			$NpcWindow.InitializeWindow(NPC_Info)
			
func Initialize_New_Villager():
	print("Worker %d Initialize_New_Villager called" % worker_id)
	NPC_Info = VillagerAiInitializer.get_villager_info()
	if NPC_Info.is_empty():
		printerr("Worker %d: VillagerAiInitializer returned EMPTY info!" % worker_id)
		return
		
	# Verify structure
	if not NPC_Info.has("Info"):
		printerr("Worker %d: New NPC_Info missing 'Info' key!" % worker_id)
		
	Update_Villager_Name() # Use the safe update function
	$NpcWindow.InitializeWindow(NPC_Info)

func _physics_process(delta: float) -> void:
	if is_dungeon_prisoner:
		_physics_process_dungeon_prisoner(delta)
		return
	# Stop worker processing when dialogue window is open
	if $NpcWindow and $NpcWindow.visible:
		return
	
	# Köylüler birbirine çok girmesin (cariye/worker/trader arası mesafe)
	if visible:
		_apply_villager_separation()
	
	# AI kamili workerların sağa sola dönmesini spriteları döndürmek yerine
	# tüm node'un X scale'ını değiştirerek yaptığı için böyle isim plakasını tersine çevirmemiz gerekti
	if scale.x < 0:
		$NamePlateContainer.scale.x = -1
		$InteractButton.scale.x = -1
		$NpcWindow.scale.x = -1
	else:
		$NamePlateContainer.scale.x = 1
		$InteractButton.scale.x = 1
		$NpcWindow.scale.x = 1
	# <<< YENİ: Mevcut Duruma Göre Animasyon Belirleme >>>
	var target_anim = "idle" # Varsayılan animasyon
	var target_pos = Vector2(move_target_x, _target_global_y)
	# Hareket durumu hesaplama
	var distance = global_position.distance_to(target_pos)
	var moving = distance > 1.0 # <<< DÜZELTME: Eşiği 1.0 yaptık >>>
	
	# <<< YENİ: DEPLOY EDİLMİŞ ASKERLER İÇİN ÖZEL DAVRANIŞ >>>
	if is_deployed and assigned_job_type == "soldier":
		# Deploy edilmiş askerler ekran dışına yürümeli
		if current_state != State.WORKING_OFFSCREEN and current_state != State.WAITING_OFFSCREEN:
			current_state = State.WORKING_OFFSCREEN
			# Hedef zaten raid/görev tarafından set edildiyse (sola/sağa 4800) üzerine yazma
			if abs(move_target_x) < 3000.0:
				if global_position.x <= 1920.0:
					move_target_x = global_position.x + 1500.0
				else:
					move_target_x = 4500.0
			_target_global_y = global_position.y
		# Hareket ederken görünür kalmalı, ekran dışına çıkınca gizlenecek
		if current_state == State.WORKING_OFFSCREEN:
			visible = true  # Hareket ederken görünür
		moving = distance > 1.0  # Deploy edilmiş askerler hareket edebilir
	# Eğer idle/socializing durumunda ve aktivite gezinme değilse, hareket etme
	# <<< DEĞİŞİKLİK: Check _is_briefly_idling as well >>>
	elif (current_state == State.AWAKE_IDLE or current_state == State.SOCIALIZING) and (_current_idle_activity != "wandering" or _is_briefly_idling):
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
				
				# AWAKE_IDLE ve SOCIALIZING state'lerinde her zaman görünür ol
				visible = true
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
	# HASTA KONTROLÜ: Hasta işçiler için özel hız (GOING_HOME_SICK state'inde)
	if moving: # Sadece moving true ise hareket et
		var actual_move_speed = move_speed
		if current_state == State.GOING_HOME_SICK:
			# Hasta işçiler normal hızın %75'i ile yürür
			actual_move_speed = move_speed * 0.75
		global_position = global_position.move_toward(target_pos, actual_move_speed * delta)
	# <<< YENİ SONU >>>
	
	match current_state:
		State.GOING_HOME_SICK:
			# Hasta işçi evine gidiyor (barakaya/kamp ateşine GİRMEZ, sadece pozisyonunu alır)
			if not is_instance_valid(housing_node):
				# Ev yoksa direkt SICK state'ine geç
				current_state = State.SICK
				visible = false
				return
			
			# Evine vardı mı kontrol et (housing_node'un pozisyonuna yakın olmalı)
			var distance_to_home = global_position.distance_to(housing_node.global_position)
			# Eve vardı: yürünebilir banttaysa mesafe ile, değilse (kamp ateşi) yatay mesafe ile
			var housing_y = housing_node.global_position.y
			var housing_outside_walkable_home = housing_y < VERTICAL_RANGE_MIN or housing_y > VERTICAL_RANGE_MAX
			var horizontal_dist_home = abs(global_position.x - housing_node.global_position.x)
			var at_home = (distance_to_home < 10.0) if not housing_outside_walkable_home else (horizontal_dist_home < 40.0)
			if at_home:
				current_state = State.SICK
				visible = false
				global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
				return
			else:
				# Eve doğru hareket et; barınak yürünebilir bantta değilse hedef Y yürünebilir bantta
				move_target_x = housing_node.global_position.x
				if housing_outside_walkable_home:
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
				else:
					_target_global_y = housing_y + randf_range(-8.0, 8.0)
				target_pos = Vector2(move_target_x, _target_global_y)
				if not moving:
					moving = true
			return
		
		State.SICK:
			# Hasta işçiler evde kalır, hiçbir şey yapmaz
			# İyileşme kontrolü VillageManager tarafından günlük yapılır
			visible = false
			if is_instance_valid(housing_node):
				global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
			return
		
		State.SLEEPING:
			# Uyanma zamanı geldi mi kontrol et
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			# WAKE_UP_HOUR sabitine ve işçiye özel offset'e göre kontrol
			# Sadece gündüz saatlerinde (WAKE_UP_HOUR ile SLEEP_HOUR arası) uyan
			# Gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uyanma
			var should_wake = false
			# Gündüz saatleri: 6-22 arası
			if current_hour >= wake_hour and current_hour < sleep_hour:
				# WAKE_UP_HOUR'dan sonra veya tam WAKE_UP_HOUR'da offset geçmişse uyan
				if current_hour > wake_hour:
					should_wake = true
				elif current_hour == wake_hour and current_minute >= wake_up_minute_offset:
					should_wake = true
			
			if should_wake:
				# Barınaktan çıkar — SADECE CampFire için slot serbest bırakılır.
				# ResidentialHousing (ev) köylüyü kalıcı kiracı olarak tutar;
				# remove_occupant çağrısı yapılmaz, aksi hâlde gündüz sayaç 0'a düşer.
				if is_instance_valid(housing_node) and housing_node.has_method("remove_occupant"):
					if not (housing_node is ResidentialHousing):
						housing_node.remove_occupant(self)
				
				# Uyandır!
				current_state = State.AWAKE_IDLE # Şimdilik direkt idle yapalım
				visible = true
				if is_instance_valid(housing_node): # Güvenlik kontrolü
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
				else:
					#printerr("Worker %d: Housing node geçerli değil, başlangıç konumu ayarlanamadı!" % worker_id)
					move_target_x = global_position.x # Hedefi kendi konumu yap
					_target_global_y = global_position.y # Hedef Y'yi mevcut Y yap
					
				_current_idle_activity = "" # Reset activity state on wake up
				_is_briefly_idling = false # Reset flag
				_start_next_idle_step() # Decide initial action
				#print("Worker %d uyandı!" % worker_id) # Debug
			else:
				# Hala uyku zamanı, SLEEPING state'inde kal
				pass

		State.AWAKE_IDLE:
			# HASTALIK KONTROLÜ: Hasta işçiler evden çıkmaz, çalışamaz
			if is_sick:
				# Eğer evine gitmediyse git
				if is_instance_valid(housing_node):
					var distance_to_home = global_position.distance_to(housing_node.global_position)
					if distance_to_home > 10.0:
						current_state = State.GOING_HOME_SICK
						visible = true
						return
				# Evdeyse SICK state'ine geç
				current_state = State.SICK
				visible = false
				if is_instance_valid(housing_node):
					global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
				return
			
			# DEPLOY EDİLMİŞ ASKER İSTİSNASI: Deploy edilmiş askerler normal rutinlerine devam etmemeli
			if is_deployed and assigned_job_type == "soldier":
				current_state = State.WORKING_OFFSCREEN
				visible = false
				if global_position.x <= 1920.0:
					move_target_x = global_position.x + 1500.0
				else:
					move_target_x = 3500.0
				_target_global_y = global_position.y
				return
			
			# DEBUG: AWAKE_IDLE state'inde her frame kontrol
			#if _debug_frame_counter % 60 == 0: # Her 60 frame'de bir
				#print("🔍 Worker %d AWAKE_IDLE state'inde - Visible: %s, Pos: %s, Activity: %s" % [
				#	worker_id, visible, global_position, _current_idle_activity
			#	])
			
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			
			# 1. Uyku Zamanı Kontrolü
			# HASTA KONTROLÜ: Hasta işçiler uykuya gitmez, GOING_HOME_SICK olmalı
			if not is_sick:
				# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
				# Gündüz saatlerinde (WAKE_UP_HOUR ile SLEEP_HOUR arası) uyku kontrolü yapma
				var wake_hour = TimeManager.WAKE_UP_HOUR
				var sleep_hour = TimeManager.SLEEP_HOUR
				var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
				# Sadece gece saatlerinde (22-6 arası) ve henüz uyumamışsa uykuya git
				if not is_daytime and current_hour >= sleep_hour and current_minute >= sleep_minute_offset:
					# Worker zaten uyuyorsa veya uyumaya gidiyorsa tekrar kontrol etme
					if current_state != State.SLEEPING and current_state != State.GOING_TO_SLEEP:
						if is_instance_valid(housing_node):
							#print("Worker %d (Idle) uyumaya gidiyor." % worker_id)
							current_state = State.GOING_TO_SLEEP
							move_target_x = housing_node.global_position.x
							_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
							idle_activity_timer.stop() # Aktiviteyi durdur
							_is_briefly_idling = false # <<< Reset flag >>>
							_current_idle_activity = "" # <<< Reset activity >>>
							return

			# 2. İşe Gitme Zamanı Kontrolü (ASKER İSTİSNASI: askerler gündüz köyde kalır)
			# HASTALIK KONTROLÜ: Hasta işçiler çalışamaz
			elif assigned_job_type != "" and assigned_job_type != "soldier" and is_instance_valid(assigned_building_node) and not is_sick:
				# Çalışma saatleri içindeyse işe git (WORK_START_HOUR ile WORK_END_HOUR arası)
				var is_work_time = current_hour >= TimeManager.WORK_START_HOUR and current_hour < TimeManager.WORK_END_HOUR
				var is_work_start_hour = current_hour == TimeManager.WORK_START_HOUR
				var passed_offset = current_minute >= work_start_minute_offset
				
				# Çalışma saatleri içindeyse ve (ilk çalışma saatinde değilse VEYA dakika offset'i geçmişse) işe git
				if is_work_time and (not is_work_start_hour or passed_offset):
					#print("Worker %d işe gidiyor (%s)!" % [worker_id, assigned_job_type])
					current_state = State.GOING_TO_BUILDING_FIRST
					move_target_x = assigned_building_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
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
			# DEPLOY EDİLMİŞ ASKER İSTİSNASI: Deploy edilmiş askerler binaya gitmemeli
			if is_deployed and assigned_job_type == "soldier":
				current_state = State.WORKING_OFFSCREEN
				visible = false
				if global_position.x <= 1920.0:
					move_target_x = global_position.x + 1500.0
				else:
					move_target_x = 3500.0
				_target_global_y = global_position.y
				return
			
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var current_hour_building = TimeManager.get_hour()
			var current_minute_building = TimeManager.get_minute()
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = current_hour_building >= wake_hour and current_hour_building < sleep_hour
			if not is_daytime and current_hour_building >= sleep_hour and current_minute_building >= sleep_minute_offset:
				# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
				if is_sick:
					current_state = State.GOING_HOME_SICK
					visible = true
				elif is_instance_valid(housing_node):
					#print("Worker %d going to sleep while going to building." % worker_id)
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					return
			
			# Binaya doğru hareket et (hareket _physics_process başında yapılıyor)
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Binaya vardıysa
				# Binaya vardı, bina türüne ve seviyesine göre karar ver
				if is_instance_valid(assigned_building_node) and assigned_building_node.has_method("get_script"):
					var building_node = assigned_building_node # Kısa isim
					var go_inside = false # Varsayılan: dışarı çık
					# ASKER İSTİSNASI: Askerler iş saatinde bina içine girmez, köyde kalır
					if assigned_job_type == "soldier":
						current_state = State.SOCIALIZING
						_start_next_idle_step()
						# Idle/socializing'e geçtiğimiz için daha fazla işlem yapma
						return

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
						# Kamp ateşini merkez alarak sağa ve sola 4800 piksel mesafe
						var campfire_x = 960.0  # Varsayılan ekran merkezi, kamp ateşi bulunursa güncellenir
						var campfire_node = get_tree().get_first_node_in_group("Housing")
						if is_instance_valid(campfire_node):
							campfire_x = campfire_node.global_position.x
						
						if global_position.x < campfire_x:
							move_target_x = campfire_x - 4800.0
							_target_global_y = global_position.y # Hedef Y'yi mevcut Y yapalım ki sadece X ekseninde gitsin
						else:
							move_target_x = campfire_x + 4800.0
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
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var current_hour_offscreen = TimeManager.get_hour()
			var current_minute_offscreen = TimeManager.get_minute()
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = current_hour_offscreen >= wake_hour and current_hour_offscreen < sleep_hour
			if not is_daytime and current_hour_offscreen >= sleep_hour and current_minute_offscreen >= sleep_minute_offset:
				# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
				if is_sick:
					current_state = State.GOING_HOME_SICK
					visible = true
				elif is_instance_valid(housing_node):
					#print("Worker %d going to sleep while working offscreen." % worker_id)
					current_state = State.GOING_TO_SLEEP
					visible = true
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					return
			
			# Ekran dışına doğru hareket et
			# <<< DEĞİŞTİ: Hedefe varma kontrolü distance_to ile >>>
			if not moving: # Ekran dışı hedefine vardıysa
				# Ekran dışına ulaştı
				#print("Worker %d ekran dışına çıktı, çalışıyor (beklemede)." % worker_id)
				_offscreen_exit_x = global_position.x
				if is_instance_valid(held_item_sprite): held_item_sprite.hide()
				# DEPLOY EDİLMİŞ ASKER İSTİSNASI: Deploy edilmiş askerler ekran dışında beklesin
				if assigned_job_type == "soldier" and is_deployed:
					# Deploy edilmiş askerler ekran dışında beklesin (görünmez olacaklar)
					current_state = State.WAITING_OFFSCREEN
					visible = false
				# ASKER İSTİSNASI: Normal askerler ekran dışında beklemesin, köyde sosyalleşsin
				elif assigned_job_type == "soldier":
					current_state = State.SOCIALIZING
					visible = true
					_start_next_idle_step()
				else:
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
					global_position = Vector2(assigned_building_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
				else:
					pass 

				# Sadece gece saatlerinde uykuya git
				var wake_hour = TimeManager.WAKE_UP_HOUR
				var sleep_hour = TimeManager.SLEEP_HOUR
				var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
				if not is_daytime and current_hour >= sleep_hour:
					# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
					if is_sick:
						current_state = State.GOING_HOME_SICK
						visible = true
						if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					elif is_instance_valid(housing_node):
						#print("Worker %d going to sleep from inside building." % worker_id)
						current_state = State.GOING_TO_SLEEP
						move_target_x = housing_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
						if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					else:
						#print("Worker %d finished work, no housing, socializing." % worker_id)
						current_state = State.SOCIALIZING
						_is_briefly_idling = false # <<< Reset flag >>>
						_current_idle_activity = "" # <<< Reset activity >>>
						_start_next_idle_step() # Start socializing behavior
						# var wander_range = 150.0 # Handled by _start_next_idle_step
						# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
						# _target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
						if is_instance_valid(held_item_sprite): held_item_sprite.hide()
				else:
					#print("Worker %d finished work, socializing." % worker_id)
					current_state = State.SOCIALIZING
					_is_briefly_idling = false # <<< Reset flag >>>
					_current_idle_activity = "" # <<< Reset activity >>>
					_start_next_idle_step() # Start socializing behavior
					# var wander_range = 150.0 # Handled by _start_next_idle_step
					# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					# _target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()

		State.WAITING_OFFSCREEN:
			# DEPLOY EDİLMİŞ ASKER İSTİSNASI: Deploy edilmiş askerler geri dönmemeli
			if is_deployed and assigned_job_type == "soldier":
				visible = false
				return  # Deploy edilmiş askerler ekran dışında beklesin
			
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
			if not is_daytime and current_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
				if is_sick:
					current_state = State.GOING_HOME_SICK
					visible = true
				elif is_instance_valid(housing_node):
					#print("Worker %d going to sleep while waiting offscreen." % worker_id)
					current_state = State.GOING_TO_SLEEP
					visible = true
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					return
			
			if current_hour >= TimeManager.WORK_END_HOUR:
				if current_hour > TimeManager.WORK_END_HOUR or current_minute >= work_end_minute_offset:
					#print("Worker %d işten dönüyor." % worker_id)
					current_state = State.RETURNING_FROM_WORK
					visible = true
					
					# Eğer _offscreen_exit_x kaydedilmemişse, kamp ateşine göre hesapla
					if _offscreen_exit_x == 0.0:
						# Kamp ateşini merkez alarak sağa veya sola 4800 piksel mesafe
						var campfire_x = 960.0  # Varsayılan ekran merkezi
						var campfire_node = get_tree().get_first_node_in_group("Housing")
						if is_instance_valid(campfire_node):
							campfire_x = campfire_node.global_position.x
						
						# Binanın konumuna göre hangi taraftan çıktığını tahmin et
						if is_instance_valid(assigned_building_node):
							if assigned_building_node.global_position.x < campfire_x:
								_offscreen_exit_x = campfire_x - 4800.0
							else:
								_offscreen_exit_x = campfire_x + 4800.0
						else:
							# Bina yoksa rastgele bir taraf seç
							_offscreen_exit_x = campfire_x - 4800.0 if randf() < 0.5 else campfire_x + 4800.0
					
					# Ekranın dışından başla (100 piksel margin ile)
					var start_margin = 100.0
					var start_x = 0.0
					if _offscreen_exit_x < 0:
						# Soldan çıkmıştı, soldan gir (ekranın dışından)
						start_x = _offscreen_exit_x - start_margin
					else:
						# Sağdan çıkmıştı, sağdan gir (ekranın dışından)
						start_x = _offscreen_exit_x + start_margin
					
					# <<< DEĞİŞTİ: Y konumunu rastgele yap >>>
					global_position = Vector2(start_x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					
					if is_instance_valid(assigned_building_node):
						move_target_x = assigned_building_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
					else:
						#printerr("Worker %d: Returning from work but building is invalid! Socializing." % worker_id)
						current_state = State.SOCIALIZING
						_is_briefly_idling = false # <<< Reset flag >>>
						_current_idle_activity = "" # <<< Reset activity >>>
						_start_next_idle_step() # Start socializing behavior
						# var wander_range = 150.0 # Handled by _start_next_idle_step
						# move_target_x = global_position.x + randf_range(-wander_range, wander_range)
						# _target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)

		State.RETURNING_FROM_WORK:
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var current_hour = TimeManager.get_hour()
			var current_minute = TimeManager.get_minute()
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
			if not is_daytime and current_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
				if is_sick:
					current_state = State.GOING_HOME_SICK
					visible = true
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()
				elif is_instance_valid(housing_node):
					#print("Worker %d going to sleep while returning from work." % worker_id)
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()
					return
			
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
				# _target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)

		State.SOCIALIZING:
			# DEPLOY EDİLMİŞ ASKER İSTİSNASI: Deploy edilmiş askerler SOCIALIZING'e geçmemeli
			if is_deployed and assigned_job_type == "soldier":
				current_state = State.WORKING_OFFSCREEN
				visible = true
				if global_position.x <= 1920.0:
					move_target_x = global_position.x + 1500.0
				else:
					move_target_x = 3500.0
				_target_global_y = global_position.y
				return
			
			var current_hour = TimeManager.get_hour()
			var current_minute_social = TimeManager.get_minute()
			# Uyku Zamanı Kontrolü
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			# Gündüz saatlerinde (WAKE_UP_HOUR ile SLEEP_HOUR arası) uyku kontrolü yapma
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
			# <<< YENİ: Başarısız deneme flag'ini kontrol et >>>
			# Sadece gece saatlerinde (22-6 arası) ve henüz uyumamışsa uykuya git
			if not is_daytime and current_hour >= sleep_hour and current_minute_social >= sleep_minute_offset and not _sleep_attempt_failed:
				# Worker zaten uyuyorsa veya uyumaya gidiyorsa tekrar kontrol etme
				if current_state != State.SLEEPING and current_state != State.GOING_TO_SLEEP and current_state != State.GOING_HOME_SICK:
					# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
					if is_sick:
						current_state = State.GOING_HOME_SICK
						visible = true
						idle_activity_timer.stop()
						_is_briefly_idling = false
						_current_idle_activity = ""
						return
					elif is_instance_valid(housing_node):
						# Debug: State transition (commented out)
						# print("[Worker DEBUG] Worker %d: SOCIALIZING'den GOING_TO_SLEEP'e geçiyor, saat: %d:%d" % [worker_id, current_hour, current_minute_social])
						current_state = State.GOING_TO_SLEEP
						move_target_x = housing_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX) #<<< YENİ: Hedef Y
						idle_activity_timer.stop() # Aktiviteyi durdur
						_is_briefly_idling = false # <<< Reset flag >>>
						_current_idle_activity = "" # <<< Reset activity >>>
						return
				# else:
				# 	print("[Worker DEBUG] Worker %d: SOCIALIZING'de ama zaten SLEEPING veya GOING_TO_SLEEP state'inde (state: %d)" % [worker_id, current_state])
			elif _sleep_attempt_failed:
				# Debug: Sleep attempt failed (commented out)
				# print("[Worker DEBUG] Worker %d: SOCIALIZING'de ama _sleep_attempt_failed=true, uykuya gitmiyor" % worker_id)
				pass
				#else:
					#printerr("Worker %d: Uyuyacak yer (housing_node) yok!" % worker_id)

			# Sosyalleşme/Boşta Aktivite Mantığı (Refactored)
			# Check if reached wander destination AND ensure not already processing brief idle
			if not _is_briefly_idling and distance <= 10.0 and _current_idle_activity == "wandering":
				_start_next_idle_step() # Decide and initiate the next step

		State.GOING_TO_SLEEP:
			# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP state'ine geçmemeli, GOING_HOME_SICK olmalı
			if is_sick:
				current_state = State.GOING_HOME_SICK
				return
			
			# NOT: GOING_TO_SLEEP state'inde sabah kontrolü YAPILMAMALI
			# Çünkü worker henüz eve varmamış, bu yüzden uyandırılmamalı
			# Sabah kontrolü sadece SLEEPING state'inde yapılmalı
			
			# Hedef: barınak yürünebilir bantta değilse (örn. kamp ateşi y=-26) hedef Y'yi yürünebilir bantta tut (MIN..MAX)
			if is_instance_valid(housing_node):
				move_target_x = housing_node.global_position.x
				var housing_y = housing_node.global_position.y
				if housing_y < VERTICAL_RANGE_MIN or housing_y > VERTICAL_RANGE_MAX:
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
				else:
					_target_global_y = housing_y + randf_range(-8.0, 8.0)
			
			var distance_to_housing = 9999.0
			var horizontal_dist_to_housing = 9999.0
			if is_instance_valid(housing_node):
				distance_to_housing = global_position.distance_to(housing_node.global_position)
				horizontal_dist_to_housing = abs(global_position.x - housing_node.global_position.x)
			
			# Barınak yürünebilir bantta değilse (kamp ateşi gibi) "vardı" = yatay mesafe yeterince küçük (worker yürünebilir Y'de kalır)
			var housing_outside_walkable = is_instance_valid(housing_node) and (housing_node.global_position.y < VERTICAL_RANGE_MIN or housing_node.global_position.y > VERTICAL_RANGE_MAX)
			var arrived = false
			if housing_outside_walkable:
				arrived = horizontal_dist_to_housing < 40.0
			else:
				arrived = distance_to_housing < 25.0
			
			if arrived:
				# Uyku saati kontrolü: Eğer hala uyku saati içindeyse SLEEPING state'ine geç
				var current_hour_sleep = TimeManager.get_hour()
				var wake_hour = TimeManager.WAKE_UP_HOUR
				var sleep_hour = TimeManager.SLEEP_HOUR
				var is_sleep_time = current_hour_sleep >= sleep_hour or current_hour_sleep < wake_hour
				
				if is_sleep_time:
					var can_sleep = true
					if is_instance_valid(housing_node) and housing_node.has_method("add_occupant"):
						var add_result = housing_node.add_occupant(self)
						if not add_result:
							can_sleep = false
							_sleep_attempt_failed = true
							_sleep_retry_timer.start()
							current_state = State.SOCIALIZING
							visible = true
							_is_briefly_idling = false
							_current_idle_activity = ""
							_start_next_idle_step()
							return
					
					if can_sleep:
						current_state = State.SLEEPING
						_sleep_attempt_failed = false
						_sleep_retry_timer.stop()
					visible = false
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(housing_node):
						global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
				else:
					current_state = State.AWAKE_IDLE
					visible = true
					if is_instance_valid(housing_node):
						global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
						var wander_range = 150.0
						move_target_x = global_position.x + randf_range(-wander_range, wander_range)
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					_current_idle_activity = ""
					_is_briefly_idling = false
					_start_next_idle_step()

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
					global_position = Vector2(assigned_building_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					if assigned_building_node.has_method("finished_fetching"):
						assigned_building_node.finished_fetching()
					#else:
						#printerr("Worker %d: Building %s has no finished_fetching method!" % [worker_id, assigned_building_node.name])
					if is_instance_valid(held_item_sprite): held_item_sprite.hide()

		_:
			pass # Bilinmeyen veya henüz işlenmeyen durumlar
	
	# Koylu yurunebilir bant sinirlarini her karede zorla.
	_enforce_walkable_vertical_band()

	# Z-Index'i ayak pozisyonuna göre güncelle (Y düşük = önde)
	# Sprite'lar position = Vector2(0, -48) offset'ine sahip, bu yüzden ayaklar daha aşağıda
	# Su yansımasında görünmesi için z_index'i su sprite'ının z_index'inden (20) düşük tutmalıyız
	var foot_y = get_foot_y_position()
	var new_z_index = _calculate_z_index_from_foot_y(foot_y)
	if z_index != new_z_index:
		z_index = new_z_index


func _enforce_walkable_vertical_band() -> void:
	global_position.y = clampf(global_position.y, VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
	_target_global_y = clampf(_target_global_y, VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)

# Ayak pozisyonunu hesapla (sprite offset'i ve yüksekliğini hesaba katarak)
func get_foot_y_position() -> float:
	# Sprite'lar position = Vector2(0, -48) offset'ine sahip
	# Sprite merkezi global_position'dan 48 piksel yukarıda → merkez_y = global_position.y - 48
	# Ayaklar = sprite merkezi + sprite_height/2 → foot_y = global_position.y - 48 + (sprite_height / 2)
	var sprite_offset_y = 48.0  # Sprite offset'i (negatif = yukarı)
	
	# Body sprite'ın texture yüksekliğini al
	var sprite_height = 96.0  # Varsayılan yükseklik
	if is_instance_valid(body_sprite) and body_sprite.texture:
		var texture = body_sprite.texture
		if texture is CanvasTexture:
			var canvas_texture = texture as CanvasTexture
			if is_instance_valid(canvas_texture.diffuse_texture):
				sprite_height = canvas_texture.diffuse_texture.get_height()
		elif texture is Texture2D:
			sprite_height = texture.get_height()
	
	# Ayak pozisyonu = global_position.y - offset + sprite'ın alt yarısı
	return global_position.y - sprite_offset_y + (sprite_height / 2.0)

# Z-index'i ayak pozisyonuna göre normalize et (su yansımasında görünmesi için 0-19 aralığında)
func _calculate_z_index_from_foot_y(foot_y: float) -> int:
	# foot_y'yi normalize et: VERTICAL_RANGE_MAX + sprite_offset + sprite_height/2 maksimum değer olabilir
	# Yaklaşık maksimum foot_y: 25 + 48 + 96 = 169, minimum: 0 + 48 + 48 = 96
	# NPC'lerin z_index'lerini 6-19 aralığına normalize et (kamp ateşinden yüksek, su sprite'ından düşük)
	# Oyuncuyla aynı aralıkta olmalı ki pozisyona göre doğru sorting yapılsın
	const CAMPFIRE_Z_INDEX: int = 5  # Kamp ateşinin z_index'i
	const WATER_Z_INDEX: int = 20  # Su sprite'ının z_index'i
	const MIN_Z_INDEX: int = CAMPFIRE_Z_INDEX + 1  # Kamp ateşinden yüksek (6)
	const MAX_Z_INDEX: int = WATER_Z_INDEX - 1  # Su sprite'ından düşük (19)
	
	var sprite_offset_y = 48.0
	var sprite_height = 96.0  # Varsayılan yükseklik
	if is_instance_valid(body_sprite) and body_sprite.texture:
		var texture = body_sprite.texture
		if texture is CanvasTexture:
			var canvas_texture = texture as CanvasTexture
			if is_instance_valid(canvas_texture.diffuse_texture):
				sprite_height = canvas_texture.diffuse_texture.get_height()
		elif texture is Texture2D:
			sprite_height = texture.get_height()
	
	# foot_y = global_position.y - 48 + height/2 → yaklaşık y=MIN ile y=MAX arası
	var max_foot_y = VERTICAL_RANGE_MAX - sprite_offset_y + (sprite_height / 2.0)
	var min_foot_y = VERTICAL_RANGE_MIN - sprite_offset_y + (sprite_height / 2.0)
	var range_foot_y = max_foot_y - min_foot_y
	
	# Division by zero kontrolü
	if range_foot_y <= 0.0:
		return (MIN_Z_INDEX + MAX_Z_INDEX) / 2  # Varsayılan orta değer (12-13)
	
	var normalized_foot_y = (foot_y - min_foot_y) / range_foot_y
	normalized_foot_y = clamp(normalized_foot_y, 0.0, 1.0)  # 0-1 aralığına sınırla
	# 6-19 aralığına normalize et (kamp ateşinden yüksek, su sprite'ından düşük)
	var z_index_range = MAX_Z_INDEX - MIN_Z_INDEX
	return MIN_Z_INDEX + int(normalized_foot_y * z_index_range)

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
	# Worker instance'ın ve scene tree'in geçerli olduğundan emin ol
	if not is_inside_tree():
		return
	if not is_instance_valid(self):
		return
	
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
	# Worker instance'ın ve scene tree'in geçerli olduğundan emin ol
	if not is_inside_tree():
		return
	if not is_instance_valid(self):
		return
	
	if current_state == State.WORKING_INSIDE:
		# #print("Worker %d switching from INSIDE to WORKING_OFFSCREEN." % worker_id) #<<< KALDIRILDI
		current_state = State.WORKING_OFFSCREEN
		visible = true # Görünür yap
		# Kamp ateşini merkez alarak sağa ve sola 4800 piksel mesafe
		var campfire_x = 960.0  # Varsayılan ekran merkezi, kamp ateşi bulunursa güncellenir
		var campfire_node = get_tree().get_first_node_in_group("Housing")
		if is_instance_valid(campfire_node):
			campfire_x = campfire_node.global_position.x
		
		# Binanın konumuna göre ekran dışı hedefini belirle
		if is_instance_valid(assigned_building_node):
			if assigned_building_node.global_position.x < campfire_x:
				move_target_x = campfire_x - 4800.0
			else:
				move_target_x = campfire_x + 4800.0
			# Pozisyonu bina konumu yap ki oradan yürümeye başlasın
			global_position = assigned_building_node.global_position
		else:
			# Bina geçerli değilse, bulunduğu yerden rastgele bir yöne gitsin? Güvenli varsayım:
			#printerr("Worker %d switching to OFFSCREEN but building node is invalid. Using current pos." % worker_id)
			if global_position.x < campfire_x: 
				move_target_x = campfire_x - 4800.0
			else:
				move_target_x = campfire_x + 4800.0
		
		# AnimatedSprite2D node'unun geçerli olduğundan emin ol
		var animated_sprite = get_node_or_null("AnimatedSprite2D")
		if is_instance_valid(animated_sprite):
			animated_sprite.play("walk") # Yürüme animasyonunu başlat
		else:
			# Alternatif olarak play_animation metodunu kullan (eğer varsa)
			if has_method("play_animation"):
				play_animation("walk")
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
		
		# Uyku vakti mi? Sadece gece saatlerinde
		var wake_hour = TimeManager.WAKE_UP_HOUR
		var sleep_hour = TimeManager.SLEEP_HOUR
		var is_daytime = current_hour >= wake_hour and current_hour < sleep_hour
		if not is_daytime and current_hour >= sleep_hour:
			# HASTA KONTROLÜ: Hasta işçiler GOING_TO_SLEEP yerine GOING_HOME_SICK olmalı
			if is_sick:
				current_state = State.GOING_HOME_SICK
				visible = true
				if is_instance_valid(held_item_sprite): held_item_sprite.hide()
			elif is_instance_valid(housing_node):
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

# Köy NPC'leri arası çok hafif mesafe (neredeyse üst üste gelince hafifçe it, alan dışına çıkmasın)
func _apply_villager_separation() -> void:
	const MIN_SPACING: float = 10.0
	const STRENGTH: float = 0.06
	var villagers = get_tree().get_nodes_in_group("Villagers")
	var separation = Vector2.ZERO
	for other in villagers:
		if other == self or not is_instance_valid(other):
			continue
		if not other is Node2D:
			continue
		var other_pos = (other as Node2D).global_position
		var dist = global_position.distance_to(other_pos)
		if dist < MIN_SPACING and dist > 0.01:
			var away = (global_position - other_pos).normalized()
			separation += away * (MIN_SPACING - dist)
	if separation.length_squared() > 0.0:
		global_position += separation * STRENGTH

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

# Uyku denemesi başarısız olduktan sonra timer dolduğunda çağrılır
func _on_sleep_retry_timer_timeout():
	# <<< YENİ: Timer doldu, tekrar denemeyi serbest bırak >>>
	_sleep_attempt_failed = false

# Saat değişiminde state transition kontrolü (VillageManager'dan çağrılır)
func check_hour_transition(new_hour: int) -> void:
	if not is_instance_valid(TimeManager):
		return
	var current_minute: int = TimeManager.get_minute() if TimeManager.has_method("get_minute") else 0
	
	match current_state:
		State.SLEEPING:
			# Uyanma kontrolü: Sadece sabah 6'da (WAKE_UP_HOUR) uyan
			# Gündüz saatlerinde (WAKE_UP_HOUR ile SLEEP_HOUR arası) tekrar uyanma kontrolü yapma
			var should_wake = false
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			# Sadece tam WAKE_UP_HOUR'da uyan (gündüz saatlerinde tekrar uyanma kontrolü yapma)
			if new_hour == wake_hour and current_minute >= wake_up_minute_offset:
				should_wake = true
			# Eğer saat WAKE_UP_HOUR'dan sonra ama SLEEP_HOUR'dan önceyse, zaten uyanmış olmalı
			# Bu durumda tekrar uyanma kontrolü yapma
			
			if should_wake:
				# Barınaktan çıkar (CampFire veya House)
				if is_instance_valid(housing_node) and housing_node.has_method("remove_occupant"):
					housing_node.remove_occupant(self)
				
				current_state = State.AWAKE_IDLE
				visible = true
				if is_instance_valid(housing_node):
					global_position = Vector2(housing_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					var wander_range = 150.0
					move_target_x = global_position.x + randf_range(-wander_range, wander_range)
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
				_current_idle_activity = ""
				_is_briefly_idling = false
				_start_next_idle_step()
		
		State.WAITING_OFFSCREEN:
			if is_deployed and assigned_job_type == "soldier":
				return
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					current_state = State.GOING_TO_SLEEP
					visible = true
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					return
			if new_hour >= TimeManager.WORK_END_HOUR:
				var should_return = false
				if new_hour > TimeManager.WORK_END_HOUR:
					should_return = true
				elif current_minute >= work_end_minute_offset:
					should_return = true
				if should_return:
					current_state = State.RETURNING_FROM_WORK
					visible = true
					var start_margin = 5.0
					var start_x = _offscreen_exit_x - start_margin if _offscreen_exit_x < 0 else _offscreen_exit_x + start_margin
					global_position = Vector2(start_x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					if is_instance_valid(assigned_building_node):
						move_target_x = assigned_building_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					else:
						current_state = State.SOCIALIZING
						_is_briefly_idling = false
						_current_idle_activity = ""
						_start_next_idle_step()
		
		State.RETURNING_FROM_WORK:
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					current_state = State.GOING_TO_SLEEP
					visible = true
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite):
						held_item_sprite.hide()
		
		State.WORKING_OFFSCREEN:
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					current_state = State.GOING_TO_SLEEP
					visible = true
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite):
						held_item_sprite.hide()
		
		State.WORKING_INSIDE:
			if new_hour >= TimeManager.WORK_END_HOUR:
				var should_finish = false
				if new_hour > TimeManager.WORK_END_HOUR:
					should_finish = true
				elif current_minute >= work_end_minute_offset:
					should_finish = true
				if should_finish:
					visible = true
					if is_instance_valid(assigned_building_node):
						global_position = Vector2(assigned_building_node.global_position.x, randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX))
					if fetching_timer and not fetching_timer.is_stopped():
						fetching_timer.stop()
					# Sadece gece saatlerinde uykuya git
					var wake_hour = TimeManager.WAKE_UP_HOUR
					var sleep_hour = TimeManager.SLEEP_HOUR
					var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
					if not is_daytime and new_hour >= sleep_hour:
						if is_instance_valid(housing_node):
							current_state = State.GOING_TO_SLEEP
							move_target_x = housing_node.global_position.x
							_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
							if is_instance_valid(held_item_sprite):
								held_item_sprite.hide()
						else:
							current_state = State.SOCIALIZING
							_is_briefly_idling = false
							_current_idle_activity = ""
							_start_next_idle_step()
							if is_instance_valid(held_item_sprite):
								held_item_sprite.hide()
					else:
						current_state = State.SOCIALIZING
						_is_briefly_idling = false
						_current_idle_activity = ""
						_start_next_idle_step()
						if is_instance_valid(held_item_sprite):
							held_item_sprite.hide()
		
		State.GOING_TO_BUILDING_FIRST:
			# Uyku zamanı kontrolü (öncelikli)
			# Sadece gece saatlerinde (SLEEP_HOUR ile WAKE_UP_HOUR arası) uykuya git
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				if is_instance_valid(housing_node):
					current_state = State.GOING_TO_SLEEP
					move_target_x = housing_node.global_position.x
					_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
					idle_activity_timer.stop()
					_is_briefly_idling = false
					_current_idle_activity = ""
					if is_instance_valid(held_item_sprite):
						held_item_sprite.hide()
		
		State.GOING_TO_SLEEP:
			# GOING_TO_SLEEP state'inde hiçbir şey yapma, worker zaten eve gidiyor
			# Sadece sabah olduysa uyan (yukarıda zaten kontrol ediliyor)
			pass
		
		State.AWAKE_IDLE, State.SOCIALIZING:
			# Uyku kontrolü: Sadece uyku saati içindeyse ve henüz uyumamışsa
			# SLEEPING veya GOING_TO_SLEEP state'indeki worker'lar bu kontrole takılmamalı
			# <<< YENİ: Sabah saatlerinde (WAKE_UP_HOUR ile SLEEP_HOUR arası) uyku kontrolü yapma >>>
			var wake_hour = TimeManager.WAKE_UP_HOUR
			var sleep_hour = TimeManager.SLEEP_HOUR
			var is_daytime = new_hour >= wake_hour and new_hour < sleep_hour
			# Sadece gece saatlerinde (22-6 arası) uyku kontrolü yap
			if not is_daytime and new_hour >= sleep_hour and current_minute >= sleep_minute_offset:
				# Worker zaten uyuyorsa veya uyumaya gidiyorsa tekrar GOING_TO_SLEEP'e geçirme
				if current_state != State.SLEEPING and current_state != State.GOING_TO_SLEEP:
					if is_instance_valid(housing_node) and not _sleep_attempt_failed:
						current_state = State.GOING_TO_SLEEP
						move_target_x = housing_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
						idle_activity_timer.stop()
						_is_briefly_idling = false
						_current_idle_activity = ""
			# Çalışma saatleri kontrolü: WORK_START_HOUR ile WORK_END_HOUR arası
			elif new_hour >= TimeManager.WORK_START_HOUR and new_hour < TimeManager.WORK_END_HOUR:
				if assigned_job_type != "" and assigned_job_type != "soldier" and is_instance_valid(assigned_building_node):
					# İlk çalışma saatinde ise dakika kontrolü de yap (offset'e göre)
					var is_work_start_hour = new_hour == TimeManager.WORK_START_HOUR
					var passed_offset = current_minute >= work_start_minute_offset
					# Çalışma saatleri içindeyse ve (ilk çalışma saatinde değilse VEYA dakika offset'i geçmişse) işe git
					if not is_work_start_hour or passed_offset:
						current_state = State.GOING_TO_BUILDING_FIRST
						move_target_x = assigned_building_node.global_position.x
						_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
						idle_activity_timer.stop()
						_is_briefly_idling = false
						_current_idle_activity = ""

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
		# Hedef Y: VERTICAL_RANGE_MIN ile VERTICAL_RANGE_MAX arasında rastgele
		_target_global_y = randf_range(VERTICAL_RANGE_MIN, VERTICAL_RANGE_MAX)
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

func _format_key_name(key_name: String) -> String:
	# Convert numpad keys (KP 8, KP8, KP_8, etc.) to Num8 format
	if key_name.begins_with("KP"):
		var num_part = key_name.trim_prefix("KP")
		# Remove spaces, underscores, and other separators
		num_part = num_part.replace(" ", "").replace("_", "").strip_edges()
		if num_part.is_valid_int():
			return "Num" + num_part
		# If it's not a valid int, try to extract just the number
		var extracted_num = ""
		for char in num_part:
			if char.is_valid_int():
				extracted_num += char
		if extracted_num != "":
			return "Num" + extracted_num
		return "Num" + num_part
	
	# Convert arrow symbols to text
	match key_name:
		"↑": return "Up"
		"↓": return "Down"
		"←": return "Left"
		"→": return "Right"
		_: return key_name

func ShowInteractButton():
	if is_dungeon_prisoner:
		return
	if $InteractButton:
		var key_name = InputManager.get_interact_key_name()
		$InteractButton.text = _format_key_name(key_name)
		$InteractButton.show()

func HideInteractButton():
	if $InteractButton:
		$InteractButton.hide()

func _on_interact_button_pressed() -> void:
	if is_dungeon_prisoner:
		return
	OpenNpcWindow()

func OpenNpcWindow():
	if is_dungeon_prisoner:
		return
	var nw = $NpcWindow if has_node("NpcWindow") else null
	if not is_instance_valid(nw):
		return
	var vm = get_node_or_null("/root/VillageManager")
	if not vm or not vm.get("Village_Player"):
		return
	if not NPC_Info is Dictionary or NPC_Info.is_empty():
		return
	var npc_info_ref = nw.get("NpcInfo") if nw else null
	if npc_info_ref == null or (npc_info_ref is Dictionary and npc_info_ref.is_empty()):
		if nw.has_method("InitializeWindow"):
			nw.InitializeWindow(NPC_Info)
	nw.show()
	if NpcDialogueManager.dialogue_processed.is_connected(NpcAnswered):
		NpcDialogueManager.dialogue_processed.disconnect(NpcAnswered)
	NpcDialogueManager.dialogue_processed.connect(NpcAnswered)
	vm.Village_Player.set_ui_locked(true)

func NpcAnswered(npc_name, new_state, generated_dialogue, was_significant):
	$NpcWindow.NPCDialogueProcessed(npc_name, new_state, generated_dialogue, was_significant)
	
func CloseNpcWindow():
	if is_dungeon_prisoner:
		return
	if has_node("NpcWindow"):
		$NpcWindow.hide()
	if NpcDialogueManager.dialogue_processed.is_connected(NpcAnswered):
		NpcDialogueManager.dialogue_processed.disconnect(NpcAnswered)
	var vm = get_node_or_null("/root/VillageManager")
	if vm and vm.get("Village_Player"):
		vm.Village_Player.set_ui_locked(false)
