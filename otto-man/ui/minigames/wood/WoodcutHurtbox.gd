extends EnemyHurtbox

var _minigame: Node = null

func _ready() -> void:
	super._ready()
	add_to_group("hurtbox", true)
	monitoring = true
	monitorable = true
	debug_enabled = false

func bind_minigame(minigame: Node) -> void:
	_release_connection()
	_minigame = minigame
	if _minigame and not hurt.is_connected(Callable(self, "_forward_hurt")):
		hurt.connect(Callable(self, "_forward_hurt"))

func release_minigame(minigame: Node) -> void:
	if _minigame == minigame:
		_release_connection()
		_minigame = null

func _forward_hurt(hitbox: Area2D) -> void:
	if _minigame and _minigame.is_inside_tree() and _minigame.has_method("_on_woodcut_hurtbox_hit"):
		_minigame._on_woodcut_hurtbox_hit(hitbox)

func _release_connection() -> void:
	if hurt.is_connected(Callable(self, "_forward_hurt")):
		hurt.disconnect(Callable(self, "_forward_hurt"))

