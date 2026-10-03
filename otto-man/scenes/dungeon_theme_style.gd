extends RefCounted
class_name DungeonThemeStyle

## Zindan teması başına görsel palet + tuzak kimliği (docs/ITEM_UNLOCK_SISTEMI.md bölüm 5).
## Tek doğru kaynak burası; level_generator ve TrapConfigV2 buradan okur.
## Teması listede olmayan zindan (veya run dışı açılan sahne) hiçbir değişiklik görmez.
##
## Anahtarlar:
##   tint_fg / tint_bg : çarpışmalı (zemin/duvar) ve çarpışmasız (arka plan) karoların rengi
##                       (UnifiedTerrain.apply_theme_palette). Beyaz = değişiklik yok.
##   trap_weight   : TrapType -> ağırlık çarpanı (tür seçiminde)
##   trap_group    : TrapType -> Vector2i(min, max) yan yana grup boyu; seviye tablosunu ezer
##   flame_scale   : FireTrapV2 alev boyutu çarpanı (görsel + hasar alanı)
##   burn_ticks_bonus : FireTrapV2 yanma tick sayısına eklenen değer

const STYLES: Dictionary = {
	# Ateş = VUR: kızıl-turuncu palet, uzun alevli ve 2-3'lü gruplar halinde ateş tuzakları.
	"ates": {
		"tint_fg": Color(1.0, 0.84, 0.72),   # üstünde koştuğumuz (çarpışmalı) karolar
		"tint_bg": Color(0.78, 0.60, 0.54),  # arka plan duvarı (chunk "bg" katmanı + çarpışmasız karolar); fg'ye yakın tutuldu, yumuşak geçiş
		"trap_weight": {
			"fire_trap": 3.5,
		},
		"trap_group": {
			"fire_trap": Vector2i(2, 3),
		},
		"flame_scale": 1.7,
		"burn_ticks_bonus": 2,
	},
	# Zehir = SİNSİCE ÖLDÜR: yeşil palet; damla yere çarpınca sağa sola sıçrayan zehir toplarına
	# bölünür. Hasar/süre/sıklık bilerek normal bırakıldı (haksızlık hissi yaratmıştı).
	"zehir": {
		"tint_fg": Color(0.84, 1.0, 0.78),
		"tint_bg": Color(0.58, 0.74, 0.56),
		"trap_params": {
			"poison_drip": {
				"splash_balls": 2,
			},
		},
	},
}


static func get_style(theme: String) -> Dictionary:
	return STYLES.get(theme, {})


static func get_tint_fg(theme: String) -> Color:
	return get_style(theme).get("tint_fg", Color.WHITE)


static func get_tint_bg(theme: String) -> Color:
	return get_style(theme).get("tint_bg", Color.WHITE)


## trap_name: TrapConfigV2.TrapType anahtarının küçük harfi ("fire_trap", "spike", ...).
## (Enum'a doğrudan bağlanmıyoruz: TrapConfigV2 de bu sınıfı okuyor, döngüsel referans olurdu.)
static func get_trap_weight_mult(theme: String, trap_name: String) -> float:
	var weights: Dictionary = get_style(theme).get("trap_weight", {})
	return float(weights.get(trap_name, 1.0))


## (0, 0) = bu tür için tema override'ı yok, seviye tablosu geçerli.
static func get_trap_group_override(theme: String, trap_name: String) -> Vector2i:
	var groups: Dictionary = get_style(theme).get("trap_group", {})
	return groups.get(trap_name, Vector2i.ZERO)


## Tuzağın export/değişken adı -> değer. TileTrapSpawner tuzak sahneye girmeden önce uygular.
static func get_trap_params(theme: String, trap_name: String) -> Dictionary:
	var all: Dictionary = get_style(theme).get("trap_params", {})
	return all.get(trap_name, {})


static func get_flame_scale(theme: String) -> float:
	return float(get_style(theme).get("flame_scale", 1.0))


static func get_burn_ticks_bonus(theme: String) -> int:
	return int(get_style(theme).get("burn_ticks_bonus", 0))
