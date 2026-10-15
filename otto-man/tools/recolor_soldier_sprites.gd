extends SceneTree
## Basic düşman sprite sayfalarından asker varyantı üretir: kavuk beyaz, kuşak kırmızı, diğer kıyafet kahverengi.
## Kavuk ile kuşak aynı açık gri renkleri paylaşıyor; bağlı bileşenlere ayrılıp karenin en üstündeki açık gri
## bölge (kavuk) ve ona yakın parçalar beyaz, aşağıdaki açık gri parçalar (kuşak) kırmızı yapılır.

const SRC_DIR := "res://enemy/basic/sprite/"
const OUT_DIR := "res://assets/NPC/soldier/"
const FRAME_W := 150
const FRAME_H := 120
const BLADE_MIN_W := 24     # bu kadar geniş ya da yüksek açık gri parça kılıç namlusudur (kuşak ~15x6)
const BLADE_MIN_H := 20
const OUT_BLADE := Color8(205, 210, 220)
const HAT_REACH := 18   # kavuk üstünden bu kadar piksel aşağıya kadar olan açık gri parçalar kavuktur

const HAT_LIGHT := Color8(203, 198, 193)
const HAT_SHADE := Color8(166, 158, 154)
const VEST := Color8(52, 48, 55)
const PANTS := Color8(86, 79, 91)
const SASH_TAIL := Color8(133, 95, 57)

const OUT_HAT_LIGHT := Color8(255, 255, 255)
const OUT_HAT_SHADE := Color8(222, 220, 216)
const OUT_BELT_LIGHT := Color8(196, 38, 45)
const OUT_BELT_SHADE := Color8(142, 27, 34)
const OUT_VEST := Color8(66, 42, 24)
const OUT_PANTS := Color8(112, 78, 46)
const OUT_TAIL := Color8(133, 95, 57)   # kın/kılıç sapı kahverengi kalır

const SHEETS := [
	"basic_attack_border", "basic_chase_border", "basic_death_border", "basic_fall_border",
	"basic_get_up_border", "basic_hurt_fall_border", "basic_hurt_ground_border", "basic_hurt_rise_border",
	"basic_idle_border", "basic_jump_border", "basic_sit1_border", "basic_sit2_border", "basic_sit3_border",
	"basic_walk_border",
]


func _same(a: Color, b: Color) -> bool:
	return absi(int(round(a.r * 255.0)) - int(round(b.r * 255.0))) <= 1 \
		and absi(int(round(a.g * 255.0)) - int(round(b.g * 255.0))) <= 1 \
		and absi(int(round(a.b * 255.0)) - int(round(b.b * 255.0))) <= 1


func _is_light(c: Color) -> bool:
	return c.a > 0.0 and (_same(c, HAT_LIGHT) or _same(c, HAT_SHADE))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for sheet in SHEETS:
		var img := Image.load_from_file(ProjectSettings.globalize_path(SRC_DIR + sheet + ".png"))
		if img == null:
			print("MISSING ", sheet)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var frames: int = img.get_width() / FRAME_W
		var belt_px := 0
		var hat_px := 0
		for f in range(frames):
			var ox: int = f * FRAME_W
			# açık gri pikseller
			var hat_top: int = 9999
			for y in range(FRAME_H):
				for x in range(FRAME_W):
					if _is_light(img.get_pixel(ox + x, y)):
						hat_top = mini(hat_top, y)
			var label := {}      # Vector2i -> bileşen no
			var comp_min_y: Array[int] = []
			var comp_min_x: Array[int] = []
			var comp_max_x: Array[int] = []
			var comp_max_y: Array[int] = []
			var comp_vest: Array[bool] = []
			var comp_pants: Array[bool] = []
			for y in range(FRAME_H):
				for x in range(FRAME_W):
					var p := Vector2i(x, y)
					if label.has(p) or not _is_light(img.get_pixel(ox + x, y)):
						continue
					var id: int = comp_min_y.size()
					comp_min_y.append(y)
					comp_min_x.append(x)
					comp_max_x.append(x)
					comp_max_y.append(y)
					comp_vest.append(false)
					comp_pants.append(false)
					var stack: Array[Vector2i] = [p]
					label[p] = id
					while not stack.is_empty():
						var cur: Vector2i = stack.pop_back()
						comp_min_y[id] = mini(comp_min_y[id], cur.y)
						comp_max_y[id] = maxi(comp_max_y[id], cur.y)
						comp_min_x[id] = mini(comp_min_x[id], cur.x)
						comp_max_x[id] = maxi(comp_max_x[id], cur.x)
						for dy in range(-1, 2):
							for dx in range(-1, 2):
								var n := Vector2i(cur.x + dx, cur.y + dy)
								if n.x < 0 or n.y < 0 or n.x >= FRAME_W or n.y >= FRAME_H or label.has(n):
									continue
								var nc: Color = img.get_pixel(ox + n.x, n.y)
								if nc.a > 0.0 and _same(nc, VEST):
									comp_vest[id] = true
								if nc.a > 0.0 and _same(nc, PANTS):
									comp_pants[id] = true
								if _is_light(nc):
									label[n] = id
									stack.append(n)
			for y in range(FRAME_H):
				for x in range(FRAME_W):
					var c: Color = img.get_pixel(ox + x, y)
					if c.a <= 0.0:
						continue
					var out: Color = c
					if _is_light(c):
						var id2: int = int(label[Vector2i(x, y)])
						var is_hat: bool = comp_min_y[id2] < hat_top + HAT_REACH
						var shade: bool = _same(c, HAT_SHADE)
						var bw: int = comp_max_x[id2] - comp_min_x[id2] + 1
						var bh: int = comp_max_y[id2] - comp_min_y[id2] + 1
						if not is_hat and not (comp_vest[id2] and comp_pants[id2]):
							out = OUT_BLADE
						elif is_hat:
							out = OUT_HAT_SHADE if shade else OUT_HAT_LIGHT
							hat_px += 1
						else:
							out = OUT_BELT_SHADE if shade else OUT_BELT_LIGHT
							belt_px += 1
					elif _same(c, VEST):
						out = OUT_VEST
					elif _same(c, PANTS):
						out = OUT_PANTS
					elif _same(c, SASH_TAIL):
						out = OUT_TAIL
					out.a = c.a
					img.set_pixel(ox + x, y, out)
		img.save_png(ProjectSettings.globalize_path(OUT_DIR + "soldier_" + sheet.trim_prefix("basic_") + ".png"))
		print("OK ", sheet, " frames=", frames, " hat_px=", hat_px, " belt_px=", belt_px)
	quit()




