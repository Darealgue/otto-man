# kaygan_yag.gd
# UNCOMMON - Slide mesafesi +100% (zeytinyağı ile stack eder)

extends ItemEffect

const SLIDE_DISTANCE_MULTIPLIER = 2.0  # +100%

var _player: CharacterBody2D = null
var _slide_state: Node = null

func _init():
	item_id = "kaygan_yag"
	item_name = "Kaygan Yağ"
	description = "Slide mesafesi +%100"
	flavor_text = "Süper kaygan"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.SLIDE
	affected_stats = ["slide_distance"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	_slide_state = player.get_node_or_null("StateMachine/Slide")
	if not _slide_state:
		push_warning("[Kaygan Yağ] StateMachine/Slide bulunamadı, slide bonusu uygulanamıyor.")
	if _slide_state:
		_slide_state.set_meta("kaygan_yag_prev_duration", _slide_state.SLIDE_DURATION)
		_slide_state.set_meta("kaygan_yag_prev_friction", _slide_state.SLIDE_FRICTION)
		_slide_state.SLIDE_DURATION *= SLIDE_DISTANCE_MULTIPLIER
		_slide_state.SLIDE_FRICTION *= 0.5
		print("[Kaygan Yağ] ✅ Slide mesafesi +%100")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _slide_state and _slide_state.has_meta("kaygan_yag_prev_duration"):
		_slide_state.SLIDE_DURATION = _slide_state.get_meta("kaygan_yag_prev_duration")
		_slide_state.SLIDE_FRICTION = _slide_state.get_meta("kaygan_yag_prev_friction")
		_slide_state.remove_meta("kaygan_yag_prev_duration")
		_slide_state.remove_meta("kaygan_yag_prev_friction")
	_slide_state = null
	_player = null
	print("[Kaygan Yağ] ❌ Kaldırıldı")
