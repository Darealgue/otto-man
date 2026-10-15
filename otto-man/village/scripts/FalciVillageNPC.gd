# FalciVillageNPC.gd
# Gezgin falcı. Yürüyüş/oturma/uyuma davranışının ve isim plakasının tamamı tüccarla aynı olduğu için
# TraderVillageNPC'den türetiliyor; farklı olan şeyler burada:
#   1) Otururken de konuşulabilir (taban sınıf da artık böyle, ama falcı kendi hint döngüsünü koruyor)
#   2) Poz değişince ok ikonu yeniden değerlendiriliyor
#   3) Plaka metni tüccar adı değil "Falcı"
#
# GEÇİCİ SANAT: sprite'lar şimdilik tüccarınkiler (assets/NPC/trader/*), mor tonlamayla
# ayırt ediliyor. Falcının kendi sheet'leri gelince FalciVillageNPC.tscn içindeki dört
# texture yolunu değiştirmek ve _apply_placeholder_tint() çağrısını silmek yeterli.
extends "res://village/scripts/TraderVillageNPC.gd"

const PLACEHOLDER_TINT := Color(0.72, 0.58, 1.0)

var _player_near: bool = false
var _hint_shown: bool = false


func _ready() -> void:
	super._ready()
	_apply_placeholder_tint()


## Geçici sanat işareti — falcının kendi sprite'ları gelince sil.
func _apply_placeholder_tint() -> void:
	for spr in [idle_sprite, walk_sprite, sit_sprite, sleep_sprite]:
		if is_instance_valid(spr):
			spr.modulate = PLACEHOLDER_TINT


## Plaka metni (taban sınıf bunu isim plakasına yazar).
func _nameplate_text() -> String:
	return tr(_title_key())


## Falcı OTURURKEN de konuşulabilir — falcının doğal pozu zaten oturmak.
func can_interact() -> bool:
	if current_state != State.IDLE:
		return false
	if _is_sleeping:
		return false
	return true


## Taban sınıf otururken HideInteractButton() çağırıyor ve oyuncu menzildeyken poz
## değişince ikonu kimse geri getirmiyordu. Her karede istenen durumla eşitle.
func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var want: bool = _player_near and can_interact()
	if want == _hint_shown:
		return
	_hint_shown = want
	if is_instance_valid(_nameplate):
		_nameplate.visible = want
	if want:
		super.ShowInteractButton()
	else:
		super.HideInteractButton()


func _on_interact_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"):
		_player_near = true


func _on_interact_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.is_in_group("Player"):
		_player_near = false


func interact() -> void:
	if not can_interact():
		return
	var host := VillageWorldPopups.get_host()
	if host:
		_open_popup(host)


## Türetilen gezgin NPC'ler (ozan) başlık anahtarını ve açtığı pencereyi buradan değiştirir.
func _title_key() -> String:
	return "falci.title"


func _open_popup(host: VillageWorldPopups) -> void:
	if host.has_method("open_falci"):
		host.open_falci()
