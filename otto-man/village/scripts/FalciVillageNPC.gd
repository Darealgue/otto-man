# FalciVillageNPC.gd
# Gezgin falcı. Yürüyüş/oturma/uyuma davranışının tamamı tüccarla aynı olduğu için
# TraderVillageNPC'den türetiliyor; farklı olan üç şey burada:
#   1) Otururken de konuşulabilir (tüccar oturunca etkileşimi kapatıyor)
#   2) Poz değişince ok ikonu yeniden değerlendiriliyor
#   3) Tepesinde isim şeridi var
#
# GEÇİCİ SANAT: sprite'lar şimdilik tüccarınkiler (assets/NPC/trader/*), mor tonlamayla
# ayırt ediliyor. Falcının kendi sheet'leri gelince FalciVillageNPC.tscn içindeki dört
# texture yolunu değiştirmek ve _apply_placeholder_tint() çağrısını silmek yeterli.
extends "res://village/scripts/TraderVillageNPC.gd"

const PLACEHOLDER_TINT := Color(0.72, 0.58, 1.0)

## Tepe arayüzü Worker'ı taklit ediyor. Sayıları elle sabitlemek YANLIŞ sonuç veriyor çünkü
## InteractBand leke yüksekliğini host kontrolünün ÇALIŞMA ANINDAKİ yüksekliğinden alıyor
## (bkz. InteractBand._refit) ve bu, sahne dosyasında yazan ölçüden farklı çıkabiliyor:
##   Worker'ın oku bir Button, sahnede 23x25 -> leke 25 yüksek, ince yatay şerit
##   Falcının oku bir TextureRect, boyutu texture'ın doğal ölçüsünden geliyordu (31x32)
##   -> leke 63x32, yani neredeyse kare: ekranda yatay şerit değil yuvarlak leke görünüyordu
## Çözüm iki parçalı: oku Worker'ın butonuyla aynı dikdörtgene oturt, dikey hizayı da
## çalışma anındaki gerçek leke yüksekliklerinden hesapla (_align_overhead_ui).
const NAMEPLATE_SIZE := Vector2(120.0, 30.0)
## Worker.gd ile BİREBİR aynı iki ofset. Türetmeye çalışmak yanlış sonuç verdi:
## leke örtüşmesini Worker'a eşitlemek yazıyı okun üstüne bindiriyor, çünkü lekeler
## yazıdan çok daha yüksek ve iki NPC'de yükseklikleri farklı (48 / 60). Ekranda
## görülen mesafe lekelerin değil, OK ile YAZININ merkezleri arasındaki 27.5 px.
const NAMEPLATE_CENTER_Y := -85.0
const HINT_ICON_CENTER_Y := -112.5
## Worker'ın ok butonunun sahnedeki dikdörtgeni. Lekenin yüksekliği host'un çalışma
## anındaki yüksekliğinden geldiği için (InteractBand._refit) bu şart: TextureRect
## kendi texture'ının doğal ölçüsüne (31x32) büyüyünce leke kareleşip yuvarlak görünüyordu.
const HINT_ICON_RECT := Vector2(23.0, 25.0)

var _player_near: bool = false
var _hint_shown: bool = false
var _nameplate: PanelContainer = null


func _ready() -> void:
	super._ready()
	_apply_placeholder_tint()
	_build_nameplate()
	_raise_hint_icon_above_nameplate()


## Oku Worker'ın butonuyla aynı dikdörtgene oturt. TextureRect varsayılan olarak texture'ın
## doğal ölçüsünü minimum kabul ediyor; IGNORE_SIZE olmadan verdiğimiz boyut yok sayılıyor
## ve leke kareye yakın (yuvarlak görünen) bir şekil alıyordu.
func _raise_hint_icon_above_nameplate() -> void:
	if not is_instance_valid(_interact_hint_icon):
		return
	_interact_hint_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_interact_hint_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_interact_hint_icon.custom_minimum_size = HINT_ICON_RECT
	_interact_hint_icon.size = HINT_ICON_RECT
	if is_instance_valid(_interact_hold_ring) and _interact_hold_ring.has_method("sync_to_control"):
		_interact_hold_ring.sync_to_control(_interact_hint_icon)
	var tracker := get_node_or_null("OverheadUiTracker_" + _interact_hint_icon.name)
	if tracker and tracker.has_method("set_world_center_offset"):
		tracker.call("set_world_center_offset", Vector2(INTERACT_HINT_X_SHIFT, HINT_ICON_CENTER_Y))


## Geçici sanat işareti — falcının kendi sprite'ları gelince sil.
func _apply_placeholder_tint() -> void:
	for spr in [idle_sprite, walk_sprite, sit_sprite, sleep_sprite]:
		if is_instance_valid(spr):
			spr.modulate = PLACEHOLDER_TINT


func _build_nameplate() -> void:
	_nameplate = PanelContainer.new()
	_nameplate.name = "FalciNamePlate"
	# Sabit ölçü şart: teğetlik şeridin yüksekliğinden hesaplanıyor. İçeriğe göre büyüyen
	# bir kapsayıcı bırakılsaydı isim uzunluğuna göre hizalama kayardı.
	_nameplate.custom_minimum_size = NAMEPLATE_SIZE
	_nameplate.size = NAMEPLATE_SIZE
	var label := Label.new()
	label.name = "NamePlate"
	label.text = tr(_title_key())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nameplate.add_child(label)
	add_child(_nameplate)
	NpcOverheadUi.apply_frameless_nameplate(_nameplate)
	NpcOverheadUi.apply_nameplate_text_style(label)
	# Diğer köylülerle aynı: isim sürekli asılı durmaz, sadece konuşulabilecekken çıkar.
	_nameplate.visible = false
	OverheadUiTracker.attach(_nameplate, self, Vector2(INTERACT_HINT_X_SHIFT, NAMEPLATE_CENTER_Y))
	_bind_hint_band_width_to(label)


## Köylülerdeki bitişik sütunun sırrı: InteractBand genişliği METNİ ÖLÇEREK buluyor.
## Worker ok butonuna ismi "genişlik kaynağı" olarak veriyor (apply_frameless_interact_button
## -> InteractBand.attach(button, name_reference)), böylece iki leke aynı genişlikte çıkıp
## tek bir sütun oluşturuyor. Tüccardan gelen ok ikonuna kaynak verilmemişti: kendi boş
## metnini ölçüp minik yuvarlak bir leke çiziyordu. Mevcut lekenin kaynağını isme bağla.
func _bind_hint_band_width_to(name_label: Label) -> void:
	if not is_instance_valid(_interact_hint_icon):
		return
	var band := _interact_hint_icon.get_node_or_null("InteractBand")
	if band:
		band.set("_width_source", name_label)


## Falcı OTURURKEN de konuşulabilir — falcının doğal pozu zaten oturmak.
## (Tüccarın tersine: onda oturmak etkileşimi kapatıyor.)
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
