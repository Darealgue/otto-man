# golgeye_karisma.gd
# UNCOMMON - Dodge/dash BİTİŞİNDE (Görünmezlik Pelerini gibi başında değil)
# 0.4sn'lik kısa bir görünmezlik flaşı: düşmanlar aggro bırakır, hurtbox
# geçici kapanır. Görünmezlik Pelerini'nin küçük/ucuz kardeşi — saldırı
# bonusu yok, sadece kaçış anı. player_dodged sinyali dodge/dash'in
# BİTİŞİNDE ateşleniyor (bkz. player/states/dodge_state.gd emit noktası).
#
# HATA DÜZELTMESİ (0.26.2): eskiden başlangıçta hurtbox.monitoring değeri kaydedilip bitişte geri yükleniyordu.
# player_dodged, dodge_state hurtbox'ı yeniden açmadan ÖNCE ateşlendiği için kaydedilen değer hep `false`'tu;
# flaş bitince hurtbox kalıcı olarak kapanıyor, basic/uçan/ateş büyücüsü oyuncuya hiç hasar veremiyordu.
# Artık kayıt yok: bitişte (ölü ya da hâlâ Dodge değilse) her zaman açılır.

extends ItemEffect

const FLASH_DURATION := 0.4
const FLASH_ALPHA := 0.5

var _player: CharacterBody2D = null
var _flash_timer := 0.0
var _saved_modulate: Color = Color(1, 1, 1, 1)
var _is_invisible := false

func _init():
	item_id = "golgeye_karisma"
	item_name = tr("item.golgeye_karisma.name")
	description = tr("item.golgeye_karisma.description")
	flavor_text = "Gölge biter, sen kaybolursun"
	rarity = ItemRarity.UNCOMMON
	category = ItemCategory.DODGE
	affected_stats = ["dodge_end_invis"]

func activate(player: CharacterBody2D):
	super.activate(player)
	_player = player
	if player.has_signal("player_dodged"):
		if not player.is_connected("player_dodged", _on_player_dodged):
			player.connect("player_dodged", _on_player_dodged)
	print("[Gölgeye Karışma] ✅ Dodge/dash bitişinde kısa görünmezlik")

func deactivate(player: CharacterBody2D):
	super.deactivate(player)
	_end_flash()
	if _player and _player.has_signal("player_dodged"):
		if _player.is_connected("player_dodged", _on_player_dodged):
			_player.disconnect("player_dodged", _on_player_dodged)
	_player = null
	print("[Gölgeye Karışma] ❌ Kaldırıldı")

func _on_player_dodged(_direction, _start_pos, _end_pos) -> void:
	_start_flash()

func _start_flash() -> void:
	if not _player or not is_instance_valid(_player):
		return
	if not _is_invisible:
		_saved_modulate = _player.modulate
		var c := _saved_modulate
		_player.modulate = Color(c.r, c.g, c.b, c.a * FLASH_ALPHA)
		_player.remove_from_group("player")
		var hb := _player.get_node_or_null("Hurtbox")
		if hb:
			hb.monitoring = false
		_is_invisible = true
	_flash_timer = FLASH_DURATION

func _end_flash() -> void:
	if not _player or not is_instance_valid(_player):
		_is_invisible = false
		return
	if not _is_invisible:
		return
	_player.modulate = _saved_modulate
	if not _player.is_in_group("player"):
		_player.add_to_group("player")
	_reopen_hurtbox()
	_is_invisible = false
	_flash_timer = 0.0

## Hurtbox'ı yeniden aç. Ölüyse dokunma (ölüm akışı kapatmıştır); Dodge içindeyse dodge çıkışı açar.
func _reopen_hurtbox() -> void:
	if not _player or not is_instance_valid(_player):
		return
	if _player.get("is_dead") == true or _player.get("pending_death") == true:
		return
	var sm = _player.get("state_machine")
	if sm != null and sm.get("current_state") != null and String(sm.current_state.name) == "Dodge":
		return
	var hb := _player.get_node_or_null("Hurtbox")
	if hb:
		hb.monitoring = true

func process(_player_ref: CharacterBody2D, delta: float) -> void:
	if _flash_timer <= 0.0:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_end_flash()
