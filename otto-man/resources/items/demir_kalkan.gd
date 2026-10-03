# demir_kalkan.gd
# COMMON item - +1 stamina hücresi (blok / parry için fazladan bir hak).
# Not: eski hali "blok hasar azaltma %50 → %90" idi. Standart blok artık hasarı her zaman
# tamamen durdurduğu için (block_state.gd DEFAULT_BLOCK_DAMAGE_REDUCTION = 1.0) bu efekt
# işe yaramaz hale geldi; yerine hücre bonusu geldi.

extends ItemEffect

const EXTRA_CHARGES := 1.0

var _applied := false

func _init():
	item_id = "demir_kalkan"
	item_name = tr("item.demir_kalkan.name")
	description = tr("item.demir_kalkan.description")
	flavor_text = "Güçlü savunma"
	rarity = ItemRarity.COMMON
	category = ItemCategory.BLOCK
	affected_stats = ["block_charges"]

func activate(player: CharacterBody2D):
	super.activate(player)
	if player_stats and not _applied:
		player_stats.add_stat_bonus("block_charges", EXTRA_CHARGES)
		_applied = true
		print("[Demir Kalkan] ✅ +1 stamina hücresi")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	if player_stats and _applied:
		player_stats.add_stat_bonus("block_charges", -EXTRA_CHARGES)
		_applied = false
		print("[Demir Kalkan] ❌ Stamina hücresi geri alındı")
