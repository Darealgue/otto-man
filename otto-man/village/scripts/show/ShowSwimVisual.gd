extends Node2D

## Yüzen köylünün görseli: her yüzücünün kendi su çizgisi vardır; çizginin altı kırpılır, böylece köylü suda yukarı aşağı
## gezerken boyu değişmez, hep baş ve göğsü görünür ("batıp çıkma" yerine "suda gezme").
##  - Su çizgisi hiçbir zaman su yüzeyinin (y 98) üstüne çıkmaz: sığ yerde su yüzeyi, derinde ayak - VISIBLE_HEIGHT.
##  - Asıl gövde (z < 20) kırpılmış hâlde kalır; su sprite'ının yansıma shader'ı onu da yansıtır (derine indikçe silikleşir).
##  - Su çizgisi 98'in altına inince asıl gövdeyi su sprite'ı örter; bu yüzden gövdenin kırpılmış bir kopyası su sprite'ının
##    ÜSTÜNDE (z 22) çizilir. Dalga halkası kopyanın arkasında (z 21, üst yarı) ve önünde (z 23, alt yarı) durur (ShowWaterRipple).
##  - Yüzücüye ait kendi yansıması da çizilir (z 21): su çizgisine göre ters çevrilmiş, aşağı doğru solan, dalgalanan kopya.
##    Böylece yansıma derinlikten bağımsız her zaman görünür.
## Karada (ayak y <= 98) hiçbir kırpma yoktur.

const CLIP_SHADER_PATH: String = "res://shaders/swim_clip.gdshader"
const WATER_SURFACE_Y: float = 98.0
const VISIBLE_HEIGHT: float = 28.0     # tam yüzerken görünen kısım (baş, omuz, göğüs)
const NO_CLIP: float = 100000.0
const CLONE_Z: int = 22
const REFLECTION_Z: int = 21
const REFLECTION_ALPHA: float = 0.55

var swimmer: Node2D = null
var body: Node2D = null
var clip_y: float = NO_CLIP            # güncel su çizgisi (ripple bunu okur)

var _body_mat: ShaderMaterial = null
var _clone_mat: ShaderMaterial = null
var _ref_mat: ShaderMaterial = null
var _clone_root: Node2D = null
var _ref_root: Node2D = null
var _pairs: Array = []                 # [{src: CanvasItem, clone: CanvasItem, ref: CanvasItem}]
var _changed: Array = []               # use_parent_material'i bizim açtığımız düğümler


func setup(p_swimmer: Node2D, p_body: Node2D) -> void:
	swimmer = p_swimmer
	body = p_body
	var shader := load(CLIP_SHADER_PATH) as Shader
	if shader == null or body == null:
		return
	_body_mat = _make_mat(shader, false)
	_clone_mat = _make_mat(shader, false)
	_ref_mat = _make_mat(shader, true)
	_ref_mat.set_shader_parameter("alpha_mul", REFLECTION_ALPHA)
	body.material = _body_mat
	_clone_root = _make_root("SwimClone", CLONE_Z, _clone_mat)
	_ref_root = _make_root("SwimReflection", REFLECTION_Z, _ref_mat)
	for c in body.get_children():
		if c is Sprite2D or c is AnimatedSprite2D:
			(c as CanvasItem).use_parent_material = true
			_changed.append(c)
			var clone: CanvasItem = _make_clone(c)
			clone.use_parent_material = true
			_clone_root.add_child(clone)
			var ref: CanvasItem = _make_clone(c)
			ref.use_parent_material = true
			_ref_root.add_child(ref)
			_pairs.append({"src": c, "clone": clone, "ref": ref})


func _make_mat(shader: Shader, mirrored: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("mirrored", mirrored)
	return m


func _make_root(node_name: String, z: int, mat: ShaderMaterial) -> Node2D:
	var r := Node2D.new()
	r.name = node_name
	r.z_as_relative = false
	r.z_index = z
	r.material = mat
	add_child(r)
	return r


func _make_clone(src: CanvasItem) -> CanvasItem:
	if src is AnimatedSprite2D:
		var a := AnimatedSprite2D.new()
		a.sprite_frames = (src as AnimatedSprite2D).sprite_frames
		return a
	return Sprite2D.new()


## Su çizgisi: karada yok; suda su yüzeyinin üstüne çıkmaz (sığda su yüzeyi, derinde ayak - VISIBLE_HEIGHT).
func _waterline(feet_y: float) -> float:
	if feet_y <= WATER_SURFACE_Y:
		return NO_CLIP
	return maxf(WATER_SURFACE_Y, feet_y - VISIBLE_HEIGHT)


func _process(_delta: float) -> void:
	if swimmer == null or not is_instance_valid(swimmer) or body == null or not is_instance_valid(body):
		queue_free()
		return
	var feet_y: float = swimmer.global_position.y
	clip_y = _waterline(feet_y)
	_body_mat.set_shader_parameter("clip_y", clip_y)
	_clone_mat.set_shader_parameter("clip_y", clip_y)
	_ref_mat.set_shader_parameter("clip_y", clip_y)
	var sx: float = signf(body.scale.x) if body.scale.x != 0.0 else 1.0
	_clone_root.global_position = body.global_position
	_clone_root.scale = Vector2(sx, 1.0)
	# Yansıma: gövde su çizgisine göre dikeyde aynalanır (kök y = 2*çizgi - ayak y, ölçek y = -1).
	var has_line: bool = clip_y < NO_CLIP * 0.5
	_ref_root.visible = has_line
	if has_line:
		_ref_root.global_position = Vector2(body.global_position.x, 2.0 * clip_y - feet_y)
		_ref_root.scale = Vector2(sx, -1.0)
	for p in _pairs:
		_sync(p["src"], p["clone"])
		_sync(p["src"], p["ref"])


func _sync(src: CanvasItem, clone: CanvasItem) -> void:
	if not is_instance_valid(src) or not is_instance_valid(clone):
		return
	clone.visible = src.visible
	clone.position = src.position
	clone.modulate = src.modulate
	if src is Sprite2D:
		var s: Sprite2D = src
		var c: Sprite2D = clone
		c.texture = s.texture
		c.hframes = s.hframes
		c.vframes = s.vframes
		c.frame = s.frame
		c.flip_h = s.flip_h
		c.flip_v = s.flip_v
		c.centered = s.centered
		c.offset = s.offset
		c.scale = s.scale
	elif src is AnimatedSprite2D:
		var sa: AnimatedSprite2D = src
		var ca: AnimatedSprite2D = clone
		ca.sprite_frames = sa.sprite_frames
		ca.animation = sa.animation
		ca.frame = sa.frame
		ca.flip_h = sa.flip_h
		ca.centered = sa.centered
		ca.offset = sa.offset
		ca.scale = sa.scale


## Köylüyü eski haline döndürür (materyal ve parent-material bayrakları).
func restore() -> void:
	_release_body()
	queue_free()


func _release_body() -> void:
	if is_instance_valid(body) and body.material == _body_mat:
		body.material = null
	for n in _changed:
		if is_instance_valid(n):
			(n as CanvasItem).use_parent_material = false
	_changed.clear()


func _exit_tree() -> void:
	# Düğüm başka bir yolla silinirse köylü kırpılmış kalmasın.
	_release_body()
