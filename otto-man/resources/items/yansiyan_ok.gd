# RARE - Mermiler ilk hedeften sekip yakındaki 2. bir düşmana da çarpar
# Önkoşul (VEYA): uzun_menzil veya ok_yagmuru (ITEM_REQUIREMENTS_ANY)
extends ItemEffect

const BOUNCE_COUNT := 1

func _init():
	item_id = "yansiyan_ok"
	item_name = tr("item.yansiyan_ok.name")
	description = tr("item.yansiyan_ok.description")
	flavor_text = "Bir taş, iki kuş"
	category = ItemCategory.LIGHT_ATTACK
	affected_stats = ["projectile_bounce"]

# Etki, mermiyi fırlatan itemin (uzun_menzil/ok_yagmuru) her setup() sonrası
# projectile.bounce_remaining alanını kontrol etmesiyle uygulanır (bkz. light_attack_projectile.gd).
# Bu item pasif bir "işaret" olarak çalışır: has_active_item ile diğer itemler kontrol eder.

func activate(player: CharacterBody2D):
	super.activate(player)

func deactivate(player: CharacterBody2D):
	super.deactivate(player)

static func get_bounce_count() -> int:
	return BOUNCE_COUNT
