# cift_vurus.gd
# UNCOMMON item - Her light attack iki seri vuruş olur, her vuruş %60 hasar verir.
# İkinci vuruş artık hasarı sonradan tekrar yazmak değil, GERÇEK bir ikinci savuruş:
# attack_state.gd animasyonu hızlandırıp aynı saldırıyı bir kez daha oynatır (hitbox, mermi,
# element, on-hit itemleri ikinci savuruşta da kendiliğinden çalışır).

extends ItemEffect

const DAMAGE_MULTIPLIER = 0.6  # %60 hasar
## attack_state.gd'nin okuduğu hız çarpanı (her iki savuruş da bu kadar hızlı)
const SWING_SPEED_MULT := 1.6
## İlk vuruş penceresi kapanınca animasyon, pencere başlangıcının bu kadar (oran) öncesine sarılır
const BURST_REWIND := 0.15

func _init():
	item_id = "cift_vurus"
	item_name = tr("item.cift_vurus.name")
	description = tr("item.cift_vurus.description")
	flavor_text = "İkili vuruş"
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["light_attack_double"]

var _player: CharacterBody2D = null
var _multiplier_applied_to: Object = null

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	# Çarpımsal: light_attack_damage_multiplier'ı başka item'larla (Combo Ustası) paylaşıyoruz,
	# atama yapmak sonradan alınanın ilkinin etkisini siliyordu. register_player aynı oyuncuya
	# activate'i tekrar çağırabildiği için aynı oyuncuya iki kez uygulanmıyor.
	if _multiplier_applied_to != player:
		player.light_attack_damage_multiplier *= DAMAGE_MULTIPLIER
		_multiplier_applied_to = player

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if _player and _multiplier_applied_to == _player:
		_player.light_attack_damage_multiplier /= DAMAGE_MULTIPLIER
	_multiplier_applied_to = null
	_player = null
