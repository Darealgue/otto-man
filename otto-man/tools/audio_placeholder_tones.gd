extends RefCounted
class_name AudioPlaceholderTones
## SFX dosya kök adı → sentez tanımı. Gerçek asset: aynı isimle `assets/audio/sfx/` altına koy.

const SFX_STEMS: Dictionary = {
	"ui_click": {"hz": 920.0, "duration": 0.05, "volume": 0.22, "slide_hz": 0.0, "wave": "sine"},
	"ui_confirm": {"hz": 660.0, "duration": 0.07, "volume": 0.24, "slide_hz": 120.0, "wave": "sine"},
	"ui_cancel": {"hz": 340.0, "duration": 0.08, "volume": 0.2, "slide_hz": -80.0, "wave": "triangle"},
	"player_hurt": {"hz": 220.0, "duration": 0.11, "volume": 0.38, "slide_hz": -140.0, "wave": "triangle"},
	"player_death": {"hz": 130.0, "duration": 0.55, "volume": 0.42, "slide_hz": -90.0, "wave": "sine"},
	"door_open": {"hz": 280.0, "duration": 0.22, "volume": 0.32, "slide_hz": 420.0, "wave": "square"},
	"door_locked": {"hz": 160.0, "duration": 0.08, "volume": 0.28, "slide_hz": -60.0, "wave": "square"},
	"combat_swipe": {"hz": 540.0, "duration": 0.09, "volume": 0.3, "slide_hz": -220.0, "wave": "triangle"},
	"combat_hit_light": {"hz": 400.0, "duration": 0.06, "volume": 0.3, "slide_hz": -200.0, "wave": "square"},
	"combat_hit_heavy": {"hz": 210.0, "duration": 0.1, "volume": 0.38, "slide_hz": -80.0, "wave": "square"},
	"combat_whiff": {"hz": 310.0, "duration": 0.05, "volume": 0.14, "slide_hz": -90.0, "wave": "sine"},
	"combat_block": {"hz": 180.0, "duration": 0.09, "volume": 0.35, "slide_hz": 0.0, "wave": "triangle"},
	"combat_parry": {"hz": 720.0, "duration": 0.08, "volume": 0.3, "slide_hz": 160.0, "wave": "sine"},
	"player_dash": {"hz": 640.0, "duration": 0.12, "volume": 0.24, "slide_hz": -280.0, "wave": "triangle"},
	"player_dodge": {"hz": 480.0, "duration": 0.14, "volume": 0.2, "slide_hz": -180.0, "wave": "triangle"},
	"player_slide": {"hz": 220.0, "duration": 0.12, "volume": 0.22, "slide_hz": -30.0, "wave": "triangle"},
	"pickup": {"hz": 780.0, "duration": 0.09, "volume": 0.26, "slide_hz": 200.0, "wave": "sine"},
	"build_complete": {"hz": 520.0, "duration": 0.18, "volume": 0.3, "slide_hz": 180.0, "wave": "sine"},
	"footstep_player": {"hz": 95.0, "duration": 0.04, "volume": 0.18, "slide_hz": -40.0, "wave": "triangle"},
	"footstep_player_dirt": {"hz": 88.0, "duration": 0.045, "volume": 0.16, "slide_hz": -35.0, "wave": "triangle"},
	"player_jump": {"hz": 420.0, "duration": 0.07, "volume": 0.22, "slide_hz": 180.0, "wave": "sine"},
	"player_land": {"hz": 120.0, "duration": 0.05, "volume": 0.2, "slide_hz": -30.0, "wave": "triangle"},
	"player_land_dirt": {"hz": 110.0, "duration": 0.055, "volume": 0.19, "slide_hz": -28.0, "wave": "triangle"},
	"player_land_heavy": {"hz": 85.0, "duration": 0.09, "volume": 0.28, "slide_hz": -20.0, "wave": "square"},
	"enemy_hurt": {"hz": 280.0, "duration": 0.07, "volume": 0.26, "slide_hz": -120.0, "wave": "square"},
	"enemy_death": {"hz": 150.0, "duration": 0.35, "volume": 0.32, "slide_hz": -60.0, "wave": "sine"},
	"enemy_alert": {"hz": 520.0, "duration": 0.14, "volume": 0.22, "slide_hz": 80.0, "wave": "triangle"},
	"enemy_attack_swing": {"hz": 380.0, "duration": 0.08, "volume": 0.22, "slide_hz": -150.0, "wave": "triangle"},
	"projectile_fire": {"hz": 720.0, "duration": 0.06, "volume": 0.2, "slide_hz": -200.0, "wave": "sine"},
	"projectile_hit": {"hz": 350.0, "duration": 0.05, "volume": 0.24, "slide_hz": -100.0, "wave": "square"},
}

const MUSIC_STEMS: Dictionary = {
	"menu_ambient": {"hz": 110.0, "duration": 2.4, "volume": 0.08, "slide_hz": 8.0, "wave": "sine"},
	"village_ambient_day": {"hz": 165.0, "duration": 3.0, "volume": 0.07, "slide_hz": -12.0, "wave": "triangle"},
	"village_ambient_night": {"hz": 90.0, "duration": 3.0, "volume": 0.08, "slide_hz": 5.0, "wave": "sine"},
	"forest_ambient_day": {"hz": 140.0, "duration": 3.0, "volume": 0.07, "slide_hz": -8.0, "wave": "triangle"},
	"forest_ambient_night": {"hz": 75.0, "duration": 3.2, "volume": 0.09, "slide_hz": 4.0, "wave": "sine"},
	"dungeon_ambient": {"hz": 90.0, "duration": 3.2, "volume": 0.09, "slide_hz": 5.0, "wave": "sine"},
	"river_ambient": {"hz": 200.0, "duration": 3.0, "volume": 0.06, "slide_hz": -6.0, "wave": "sine"},
}
