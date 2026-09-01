extends Control

@onready var _landscape: Control = $Landscape
@onready var _menu_dimmer: ColorRect = $MenuDimmer
@onready var _intro_fade: ColorRect = $IntroFade
@onready var _press_prompt: Label = $PressPrompt
@onready var _menu_root: CenterContainer = $CenterContainer
@onready var _continue_button: Button = $CenterContainer/Menu/Buttons/ContinueButton
@onready var _change_profile_button: Button = $CenterContainer/Menu/Buttons/ChangeProfileButton
@onready var _new_game_button: Button = $CenterContainer/Menu/Buttons/NewGameButton
@onready var _load_game_button: Button = $CenterContainer/Menu/Buttons/LoadGameButton
@onready var _settings_button: Button = $CenterContainer/Menu/Buttons/SettingsButton
@onready var _discord_button: Button = $CenterContainer/Menu/Buttons/DiscordButton
@onready var _quit_button: Button = $CenterContainer/Menu/Buttons/QuitButton
@onready var _load_game_menu: Control = $LoadGameMenu
var _settings_menu: Control = null
var _profile_menu: Control = null
var _tutorial_prompt: Control = null
## Hangi akıştan profil menüsü açıldı (geri dönüşte odak için)
## Açılıştaki profil kapısı ve menüdeki "Profil değiştir" için: seçim yapıldıktan sonra
## yeni oyun / yükleme ekranı AÇILMAMALI, sadece profil değişip menüye dönülmeli.
var _in_profile_gate_phase: bool = false
var _profile_gate_done: bool = false
var _intro_dismissed: bool = false
var _intro_tween: Tween = null
var _cold_start_fading: bool = false
var _cold_start_tween: Tween = null
var _disclaimer_panel: PanelContainer = null
var _disclaimer_title_label: Label = null
var _disclaimer_body_label: Label = null
var _disclaimer_hint_label: Label = null
## Saf siyah ekranda uyarı metni gösterilirken true — bu sırada henüz ne "herhangi bir tuşa
## bas" ekranı ne de menü animasyonu başlamış olur (bkz. _play_disclaimer_phase).
var _in_disclaimer_phase: bool = false
var _disclaimer_skip_requested: bool = false

## Aşama 1.5: yapay zeka köylüleri teklifi. Sadece dışa aktarılmış sürümde, model diskte yokken ve
## oyuncu daha önce hiç cevap vermemişken görünür (bkz. AiVillagers.should_show_offer). Editörde
## ASLA görünmez — geliştirme akışı bundan hiç etkilenmez.
var _ai_offer_panel: PanelContainer = null
var _in_ai_offer_phase: bool = false
## -1 = henüz seçilmedi, 0 = şimdilik atla, 1 = indir ve etkinleştir.
var _ai_offer_choice: int = -1
## İlk açılış dil seçimi (bkz. _play_language_gate_phase) — henüz hiç locale kaydedilmemişse
## erken erişim uyarısından ÖNCE gösterilir, böylece uyarı zaten doğru dilde çıkar.
var _language_gate_panel: PanelContainer = null
var _in_language_gate_phase: bool = false
var _language_gate_choice: String = ""

const INTRO_REVEAL_DURATION: float = 0.55
const COLD_START_FADE_DURATION: float = 4.8
const DISCLAIMER_FADE_OUT_DURATION: float = 0.35

## TODO: sunucu kurulunca gerçek davet linkiyle doldur (bkz. DISCORD_KURULUM.md).
## Boş bırakılırsa buton tıklandığında sessizce hiçbir şey yapmaz (uyarı log'lanır).
const DISCORD_INVITE_URL: String = "https://discord.gg/KcTGKkPej2"
## Discord ikonu için beklenen yol — piksel art sembolü buraya bu adla eklemen yeterli,
## kod tarafında başka bir şey değiştirmene gerek yok.
const DISCORD_ICON_PATH: String = "res://assets/Icons/discord_icon.png"

func _ready() -> void:
	if not _validate_nodes():
		return

	# Menü müziği karşılama müziği: dil seçimi / erken erişim uyarısı / AI teklifi /
	# profil kapısı boyunca çalmaz. Kilit burada, SoundManager sahneyi görüp müziği
	# başlatmadan önce kurulur; parallax açılırken _unlock_menu_music() ile açılır.
	_lock_menu_music()

	# Açılış sahnesi artık StudioSplash olduğu için SoundManager'ın kendi bootstrap'i
	# menü profilini yakalayamaz (o an sahne menü değil). Menü müziğini burada kendimiz
	# isteriz: kilit hemen yukarıda kurulduğu için çalmaz, bekleyen parça olarak durur ve
	# karşılama anında _unlock_menu_music() ile başlar.
	var sound_manager := get_node_or_null("/root/SoundManager")
	if sound_manager and sound_manager.has_method("play_ambient_for_scene"):
		sound_manager.play_ambient_for_scene(scene_file_path)

	# Ensure game is not paused (use GameState if available)
	if is_instance_valid(GameState) and GameState.has_method("resume"):
		GameState.resume()
	else:
		get_tree().paused = false
	
	print("[MainMenu] ready, intro landscape active")
	_connect_signals()
	_setup_load_game_menu()
	_setup_settings_menu()
	_setup_profile_select_menu()
	_setup_new_game_tutorial_prompt()
	_setup_intro_state()
	# Mouse imleci tamamen kapalı — menü klavye/gamepad ile kullanılıyor.
	if LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_refresh_locale)
	_refresh_locale()
	_refresh_continue_button()
	_register_ui_font_scale()
	_apply_startup_audio_settings()
	await _play_startup_fade_if_needed()
	# Profil kapısı aktif profili değiştirmiş olabilir; "Devam et" ona göre yeniden değerlendirilir.
	_refresh_continue_button()


## Autoload'a çıplak isimle değil node yoluyla erişiyoruz (bkz. CLAUDE.md): dosya
## --check-only ile tek başına doğrulanabilsin.
func _lock_menu_music() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("lock_music"):
		sm.lock_music()


func _unlock_menu_music() -> void:
	var sm := get_node_or_null("/root/SoundManager")
	if sm and sm.has_method("unlock_music"):
		sm.unlock_music()


func _setup_intro_state() -> void:
	_intro_dismissed = false
	if _menu_root:
		_menu_root.modulate.a = 0.0
		_menu_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _menu_dimmer:
		_menu_dimmer.modulate.a = 0.0
	if _press_prompt:
		_press_prompt.show()
		if _should_play_cold_start_fade():
			_press_prompt.modulate.a = 0.0
	_disable_main_menu_focus()


func _should_play_cold_start_fade() -> bool:
	if not is_instance_valid(SceneManager):
		return true
	return SceneManager.previous_scene_path.is_empty()


func _play_startup_fade_if_needed() -> void:
	if not _should_play_cold_start_fade():
		# Oyundan menüye dönüş: giriş akışı yok, müzik hemen başlasın.
		_clear_intro_fade()
		_unlock_menu_music()
		return
	if not is_instance_valid(_intro_fade):
		_unlock_menu_music()
		return

	_intro_fade.show()
	_intro_fade.color = Color(0, 0, 0, 1)
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_STOP

	# Aşama 0: dil seçimi SADECE ilk açılışta sorulur. Oyuncu bir kez seçtikten sonra tercih
	# user://settings.cfg içinde saklanır (LocaleManager.persist_locale) ve bir daha sorulmaz.
	# Sonradan değiştirmek isteyen Ayarlar menüsündeki dil satırını kullanır.
	if not LocaleManager.has_persisted_locale():
		await _play_language_gate_phase()

	# Aşama 1: saf siyah ekran + erken erişim uyarısı — menü/animasyon henüz yok.
	await _play_disclaimer_phase()

	# Aşama 1.5: yapay zeka köylüleri teklifi. Kendi içinde koşullu — editörde, model zaten
	# diskteyken veya oyuncu daha önce cevap vermişken hiçbir şey yapmadan anında döner.
	await _play_ai_offer_phase()

	# Aşama 1.75: profil seçimi. Dil kapısıyla aynı mantık — sadece hiç profil seçilmemişken
	# sorulur, sonrasında active_profile.json'dan hatırlanır. Menü açılmadan önce olması
	# şart: "Devam et" butonu ve otomatik kayıt hangi profille çalışacağını bilmek zorunda.
	if not (is_instance_valid(SaveManager) and SaveManager.has_persisted_profile()):
		await _play_profile_gate_phase()

	# Aşama 2: uyarı tamamen söndükten SONRA asıl açılış animasyonu (siyah ekran açılır,
	# "herhangi bir tuşa bas" belirir) başlar — ikisi artık üst üste binmiyor.
	# Müzik tam burada başlar: siyah ekran açılıp parallax manzara ve "herhangi bir
	# tuşa bas" belirirken müzik de kendi fade'iyle yükselir, ikisi birlikte gelir.
	_unlock_menu_music()
	_cold_start_fading = true
	_cold_start_tween = create_tween()
	_cold_start_tween.set_ease(Tween.EASE_IN)
	_cold_start_tween.set_trans(Tween.TRANS_SINE)
	_cold_start_tween.tween_property(_intro_fade, "color:a", 0.0, COLD_START_FADE_DURATION)
	if _press_prompt:
		_cold_start_tween.parallel().tween_property(_press_prompt, "modulate:a", 1.0, COLD_START_FADE_DURATION)
	await _cold_start_tween.finished

	_clear_intro_fade()
	_cold_start_fading = false
	_cold_start_tween = null


## Aşama 0: hiç locale kaydedilmemiş ilk açılışta iki dil butonu gösterir; oyuncu birini
## seçene kadar bekler (herhangi bir tuşla atlanamaz — bilinçli bir seçim gerekir), locale'i
## kaydeder, sonra paneli söndürüp döner. Butonların kendi metni KASITLI OLARAK tr() KULLANMAZ:
## henüz hangi dilde gösterileceğimizi bilmiyoruz, bu yüzden her iki dil de kendi adıyla yazılı.
func _play_language_gate_phase() -> void:
	_show_language_gate()
	if not is_instance_valid(_language_gate_panel):
		return
	_language_gate_panel.modulate.a = 1.0
	_language_gate_panel.show()
	_in_language_gate_phase = true
	_language_gate_choice = ""

	while _language_gate_choice.is_empty():
		await get_tree().process_frame
		if not is_instance_valid(self):
			return

	LocaleManager.set_locale(_language_gate_choice)
	LocaleManager.persist_locale(_language_gate_choice)

	_in_language_gate_phase = false
	var fade_tween := create_tween()
	fade_tween.tween_property(_language_gate_panel, "modulate:a", 0.0, DISCLAIMER_FADE_OUT_DURATION)
	await fade_tween.finished
	_language_gate_panel.hide()
	_language_gate_panel.queue_free()
	_language_gate_panel = null


func _show_language_gate() -> void:
	if is_instance_valid(_language_gate_panel):
		return
	if not is_instance_valid(_intro_fade):
		return

	_language_gate_panel = PanelContainer.new()
	_language_gate_panel.anchor_left = 0.5
	_language_gate_panel.anchor_right = 0.5
	_language_gate_panel.anchor_top = 0.5
	_language_gate_panel.anchor_bottom = 0.5
	_language_gate_panel.offset_left = -240
	_language_gate_panel.offset_right = 240
	_language_gate_panel.offset_top = -90
	_language_gate_panel.offset_bottom = 90
	_language_gate_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ParchmentTextures.apply_large_panel_style(_language_gate_panel, 20)
	_intro_fade.add_child(_language_gate_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_language_gate_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)

	var title := Label.new()
	title.text = "Language / Dil"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	col.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)

	var en_btn := Button.new()
	en_btn.text = "English"
	en_btn.custom_minimum_size = Vector2(140, 46)
	en_btn.add_theme_font_size_override("font_size", 18)
	en_btn.pressed.connect(_on_language_gate_choice.bind("en"))
	row.add_child(en_btn)

	var tr_btn := Button.new()
	tr_btn.text = "Türkçe"
	tr_btn.custom_minimum_size = Vector2(140, 46)
	tr_btn.add_theme_font_size_override("font_size", 18)
	tr_btn.pressed.connect(_on_language_gate_choice.bind("tr"))
	row.add_child(tr_btn)

	_link_horizontal_focus(en_btn, tr_btn)
	_register_ui_font_scale()
	en_btn.grab_focus()


## Yan yana duran iki butonu DÖRT ok yönüyle de birbirine bağlar. Godot'un otomatik komşu
## bulması yalnızca sol/sağ için çalışırdı; oyuncular yukarı/aşağıya da basıyor (ilk playtest,
## 2026-08-31) ve o zaman odak hiç kımıldamıyordu.
func _link_horizontal_focus(left: Control, right: Control) -> void:
	var left_path := left.get_path()
	var right_path := right.get_path()
	for neighbor in ["focus_neighbor_left", "focus_neighbor_right", "focus_neighbor_top", "focus_neighbor_bottom", "focus_next", "focus_previous"]:
		left.set(neighbor, right_path)
		right.set(neighbor, left_path)


func _on_language_gate_choice(locale: String) -> void:
	if not _language_gate_choice.is_empty():
		return
	_play_click()
	_language_gate_choice = locale


## Aşama 1.5: yapay zeka köylüleri teklifi.
##
## Koşulları tamamen AiVillagers.should_show_offer() belirler: editörde ASLA, model zaten diskteyken
## ASLA (7.5 GB'lık dosyayı elle koymuş birine ne olduğunu anlatmaya gerek yok) ve oyuncu daha önce
## bir kez cevap verdiyse ASLA. Cevap kayıt dosyasına değil user://settings.cfg içine yazılır: model
## profil başına değil makine başına tek bir dosyadır, ayrıca kayıtlar silinse bile indirilmiş model
## diskte kalır — dolayısıyla seçim de kalmalı.
##
## Dil kapısından SONRA çalışır, yani tr() burada zaten doğru dilde metin döndürür.
func _play_ai_offer_phase() -> void:
	var ai_node := get_node_or_null("/root/AiVillagers")
	if ai_node == null or not ai_node.has_method("should_show_offer"):
		return
	if not bool(ai_node.call("should_show_offer")):
		return

	_show_ai_offer()
	if not is_instance_valid(_ai_offer_panel):
		return
	_ai_offer_panel.modulate.a = 1.0
	_ai_offer_panel.show()
	_in_ai_offer_phase = true
	_ai_offer_choice = -1

	while _ai_offer_choice < 0:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return

	var enabled := _ai_offer_choice == 1
	if ai_node.has_method("set_player_choice"):
		ai_node.call("set_player_choice", enabled)
	# İndirici henüz yoksa (has_method koruması) bu satır sessizce hiçbir şey yapmaz; indirici
	# eklendiğinde teklif ekranı otomatik olarak onu tetiklemeye başlar.
	if enabled and ai_node.has_method("request_download"):
		ai_node.call("request_download")

	_in_ai_offer_phase = false
	var fade_tween := create_tween()
	fade_tween.tween_property(_ai_offer_panel, "modulate:a", 0.0, DISCLAIMER_FADE_OUT_DURATION)
	await fade_tween.finished
	if is_instance_valid(_ai_offer_panel):
		_ai_offer_panel.hide()
		_ai_offer_panel.queue_free()
	_ai_offer_panel = null


func _show_ai_offer() -> void:
	if is_instance_valid(_ai_offer_panel):
		return
	if not is_instance_valid(_intro_fade):
		return

	_ai_offer_panel = PanelContainer.new()
	# Oyun gamepad/klavye ile oynanıyor; panelin kaydırılması gerekmemeli. Bu yüzden yükseklik
	# ekrana bağlı (üstten/alttan 40px boşluk) — 1080p'de ~1000px yer açar ve metnin tamamı tek
	# ekranda sığar. Genişlik kasıtlı olarak sabit: tam ekran genişliğinde satırlar okunamayacak
	# kadar uzun oluyor.
	_ai_offer_panel.anchor_left = 0.5
	_ai_offer_panel.anchor_right = 0.5
	_ai_offer_panel.anchor_top = 0.0
	_ai_offer_panel.anchor_bottom = 1.0
	_ai_offer_panel.offset_left = -520
	_ai_offer_panel.offset_right = 520
	_ai_offer_panel.offset_top = 40
	_ai_offer_panel.offset_bottom = -40
	_ai_offer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	ParchmentTextures.apply_large_panel_style(_ai_offer_panel, 20)
	_intro_fade.add_child(_ai_offer_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_ai_offer_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = tr("ai.offer.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	col.add_child(title)

	# Metin uzun; kaydırma çubuğu şart. Yatay kaydırma kapalı olduğu için içerideki etiketler
	# panel genişliğine göre sarılır (aksi halde autowrap devreye girmez ve metin yana taşar).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var body_col := VBoxContainer.new()
	body_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_col.add_theme_constant_override("separation", 10)
	scroll.add_child(body_col)

	_add_ai_offer_section(body_col, "ai.offer.experience.header", "ai.offer.experience.body")
	_add_ai_offer_section(body_col, "ai.offer.privacy.header", "ai.offer.privacy.body")
	_add_ai_offer_section(body_col, "ai.offer.download.header", "ai.offer.download.body")
	# İlk playtest (2026-08-31): oyuncu indirmeyi bir yükleme ekranı sanıp bitmesini bekledi.
	# İndirmenin arka planda sürdüğünü teklif ekranında açıkça söylüyoruz; ekranın sağ alt
	# köşesindeki ilerleme kutusu da aynı cümleyi tekrar ediyor (AiVillagersChip).
	_add_ai_offer_highlight_label(body_col, tr("ai.offer.download.background"))
	_add_ai_offer_subheader(body_col, "ai.offer.requirement.header")
	_add_ai_offer_body_label(body_col, tr("ai.offer.requirement.body"))
	_add_ai_offer_section(body_col, "ai.offer.without.header", "ai.offer.without.body")

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	col.add_child(row)

	var enable_btn := Button.new()
	enable_btn.text = tr("ai.offer.button.enable")
	enable_btn.custom_minimum_size = Vector2(210, 44)
	enable_btn.add_theme_font_size_override("font_size", 16)
	enable_btn.pressed.connect(_on_ai_offer_choice.bind(1))
	row.add_child(enable_btn)

	var skip_btn := Button.new()
	skip_btn.text = tr("ai.offer.button.skip")
	skip_btn.custom_minimum_size = Vector2(210, 44)
	skip_btn.add_theme_font_size_override("font_size", 16)
	skip_btn.pressed.connect(_on_ai_offer_choice.bind(0))
	row.add_child(skip_btn)

	_link_horizontal_focus(enable_btn, skip_btn)
	_register_ui_font_scale()
	enable_btn.grab_focus()


func _add_ai_offer_section(parent: VBoxContainer, header_key: String, body_key: String) -> void:
	var header := Label.new()
	header.text = tr(header_key)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	parent.add_child(header)
	_add_ai_offer_body_label(parent, tr(body_key))


## Alt başlık — ana bölüm başlıklarıyla aynı renk ailesinde ama bir tık soluk ve küçük, böylece
## "İNDİRME VE PERFORMANS"ın altına ait olduğu görülür, ayrı bir bölüm gibi durmaz.
func _add_ai_offer_subheader(parent: VBoxContainer, header_key: String) -> void:
	var header := Label.new()
	header.text = tr(header_key)
	header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", Color(0.88, 0.74, 0.44, 1.0))
	parent.add_child(header)


## Gövde metniyle aynı boyutta ama yeşilimsi ve kalın: okumayı atlayan oyuncunun bile gözüne
## çarpması gereken tek cümle bu (indirme sırasında oynanabilir).
func _add_ai_offer_highlight_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.72, 0.90, 0.66, 1.0))
	parent.add_child(label)


func _add_ai_offer_body_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76, 1.0))
	parent.add_child(label)


func _on_ai_offer_choice(choice: int) -> void:
	if _ai_offer_choice >= 0:
		return
	_play_click()
	_ai_offer_choice = choice


## Aşama 1: saf siyah ekranda erken erişim uyarısını gösterir; oyuncu bilinçli olarak bir
## tuşa/gamepad butonuna basana kadar (otomatik zaman aşımı YOK) bekler, sonra yazıyı
## söndürüp döner.
func _play_disclaimer_phase() -> void:
	_show_early_access_disclaimer()
	if not is_instance_valid(_disclaimer_panel):
		return
	_disclaimer_panel.modulate.a = 1.0
	_disclaimer_panel.show()
	_in_disclaimer_phase = true
	_disclaimer_skip_requested = false

	while not _disclaimer_skip_requested:
		await get_tree().process_frame
		if not is_instance_valid(self):
			return

	_in_disclaimer_phase = false
	var fade_tween := create_tween()
	fade_tween.tween_property(_disclaimer_panel, "modulate:a", 0.0, DISCLAIMER_FADE_OUT_DURATION)
	await fade_tween.finished
	_disclaimer_panel.hide()


## Soğuk açılışta (gerçek oyun başlangıcı, menüye oyun içinden dönüşte DEĞİL) siyah ekranın
## üzerinde bir kerelik "erken erişim/test sürümü" uyarısı gösterir — parşömen çerçeveli,
## başlık + gövde + "devam" ipucu satırından oluşan süslü bir panel.
func _show_early_access_disclaimer() -> void:
	if is_instance_valid(_disclaimer_panel):
		return
	if not is_instance_valid(_intro_fade):
		return

	_disclaimer_panel = PanelContainer.new()
	_disclaimer_panel.anchor_left = 0.5
	_disclaimer_panel.anchor_right = 0.5
	_disclaimer_panel.anchor_top = 0.5
	_disclaimer_panel.anchor_bottom = 0.5
	# Panel, büyütülen puntolara göre genişletildi (ilk playtest, 2026-08-31: "geliştirme
	# aşaması yazısı küçük, alttaki 'bir tuşa bas' satırı hiç okunmuyor"). Metin sarmalandığı
	# için yükseklik cömert tutuldu; dar bir kutu satır sayısı arttığında taşardı.
	_disclaimer_panel.offset_left = -430
	_disclaimer_panel.offset_right = 430
	_disclaimer_panel.offset_top = -230
	_disclaimer_panel.offset_bottom = 230
	_disclaimer_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ParchmentTextures.apply_large_panel_style(_disclaimer_panel, 20)
	_intro_fade.add_child(_disclaimer_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_disclaimer_panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(col)

	_disclaimer_title_label = Label.new()
	_disclaimer_title_label.text = tr("menu.early_access_title")
	_disclaimer_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disclaimer_title_label.add_theme_font_size_override("font_size", 36)
	_disclaimer_title_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.45, 1.0))
	col.add_child(_disclaimer_title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 2)
	divider.color = Color(0.78, 0.64, 0.32, 0.85)
	col.add_child(divider)

	_disclaimer_body_label = Label.new()
	_disclaimer_body_label.text = tr("menu.early_access_disclaimer")
	_disclaimer_body_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disclaimer_body_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_disclaimer_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_disclaimer_body_label.add_theme_font_size_override("font_size", 23)
	_disclaimer_body_label.add_theme_color_override("font_color", Color(0.9, 0.86, 0.76, 1.0))
	col.add_child(_disclaimer_body_label)

	# İpucu satırı gövde metnine yapışınca paragrafın devamı gibi okunuyordu; araya boşluk.
	var hint_spacer := Control.new()
	hint_spacer.custom_minimum_size = Vector2(0, 10)
	hint_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(hint_spacer)

	_disclaimer_hint_label = Label.new()
	_disclaimer_hint_label.text = tr("menu.early_access_continue_hint")
	_disclaimer_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_disclaimer_hint_label.add_theme_font_size_override("font_size", 22)
	# 12 punto + %55 saydamlık okunmuyordu; hem büyütüldü hem neredeyse tam opak yapıldı.
	_disclaimer_hint_label.modulate = Color(1, 1, 1, 0.92)
	col.add_child(_disclaimer_hint_label)

	_register_ui_font_scale()
	# "Arayüz Boyutu" ayarı büyükse yazılarla birlikte kutu da büyüsün, yoksa metin taşar.
	# Panel açılışta bir kez kurulduğu için tek seferlik uygulamak yeterli.
	var scaler := get_node_or_null("/root/UiFontScale")
	if scaler != null and scaler.has_method("scale_panel"):
		scaler.call("scale_panel", _disclaimer_panel)


func _clear_intro_fade() -> void:
	if not is_instance_valid(_intro_fade):
		return
	_intro_fade.color = Color(0, 0, 0, 0)
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_fade.hide()


func _process(_delta: float) -> void:
	if _cold_start_fading or _in_disclaimer_phase or _intro_dismissed or not is_instance_valid(_press_prompt) or not _press_prompt.visible:
		return
	# Eski aralık 0.10 - 1.00 idi: yazı nabzın dip noktasında pratikte görünmez oluyordu ve
	# 22 puntoyla birleşince "hiç okunmuyor" şikayetine yol açtı (ilk playtest, 2026-08-31).
	# Nefes alma hissi korunuyor, taban çok daha yukarıda.
	var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() * 0.004)
	_press_prompt.modulate.a = pulse


func _unhandled_input(event: InputEvent) -> void:
	if not _is_intro_dismiss_input(event):
		return
	# Dil seçimi ekranı sadece butonlara tıklanarak/onaylanarak geçilir — "herhangi bir tuşla"
	# atlanamaz, bu yüzden burada input'u yutup hiçbir şey yapmıyoruz.
	if _in_language_gate_phase:
		get_viewport().set_input_as_handled()
		return
	# Yapay zeka teklifi de dil seçimi gibi bilinçli bir karar gerektirir — "herhangi bir tuşla"
	# geçilemez, aksi halde oyuncu farkında olmadan varsayılan bir seçime kilitlenirdi.
	if _in_ai_offer_phase:
		get_viewport().set_input_as_handled()
		return
	# Diğer menülerdeki (ör. DungeonRunReport) "tuşa bas = oynayan animasyonu atla" davranışıyla
	# tutarlı: ne uyarı ekranı ne de soğuk açılış fade'i artık sonuna kadar beklemeyi zorlamıyor.
	if _in_disclaimer_phase:
		get_viewport().set_input_as_handled()
		_disclaimer_skip_requested = true
		return
	if _cold_start_fading:
		get_viewport().set_input_as_handled()
		_skip_cold_start_fade()
		return
	if _intro_dismissed:
		return
	get_viewport().set_input_as_handled()
	_dismiss_intro()


## `Tween.custom_step` ile devam eden fade'i anında hedef değerlerine sıçratır — kill()'in
## aksine bu, "finished" sinyalini de tetikler, böylece _play_startup_fade_if_needed()
## içindeki `await tween.finished` normal şekilde devam eder.
func _skip_cold_start_fade() -> void:
	if not _cold_start_fading or not is_instance_valid(_cold_start_tween) or not _cold_start_tween.is_valid():
		return
	_cold_start_tween.custom_step(COLD_START_FADE_DURATION + 1.0)


func _is_intro_dismiss_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


func _dismiss_intro() -> void:
	if _intro_dismissed:
		return
	_intro_dismissed = true
	if _press_prompt:
		_press_prompt.hide()
	if _intro_tween and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	_intro_tween.set_ease(Tween.EASE_OUT)
	_intro_tween.set_trans(Tween.TRANS_CUBIC)
	if _menu_dimmer:
		_intro_tween.tween_property(_menu_dimmer, "modulate:a", 1.0, INTRO_REVEAL_DURATION)
	if _menu_root:
		_intro_tween.tween_property(_menu_root, "modulate:a", 1.0, INTRO_REVEAL_DURATION)
	_intro_tween.finished.connect(_on_intro_reveal_finished)


func _on_intro_reveal_finished() -> void:
	if _menu_root:
		_menu_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_continue_button()
	_enable_main_menu_focus()
	_focus_first_menu_button()

func _validate_nodes() -> bool:
	if not is_instance_valid(_new_game_button):
		push_error("MainMenu: NewGameButton bulunamadı; node path kontrol et")
		return false
	if not is_instance_valid(_load_game_button):
		push_error("MainMenu: LoadGameButton bulunamadı")
		return false
	if not is_instance_valid(_settings_button):
		push_error("MainMenu: SettingsButton bulunamadı")
		return false
	if not is_instance_valid(_discord_button):
		push_error("MainMenu: DiscordButton bulunamadı; node path kontrol et")
		return false
	if not is_instance_valid(_quit_button):
		push_error("MainMenu: QuitButton bulunamadı")
		return false
	return true

func _connect_signals() -> void:
	if is_instance_valid(_continue_button):
		_continue_button.pressed.connect(_on_continue_pressed)
	if is_instance_valid(_change_profile_button):
		_change_profile_button.pressed.connect(_on_change_profile_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_load_game_button.pressed.connect(_on_load_game_pressed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_discord_button.pressed.connect(_on_discord_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_setup_discord_icon()


## Piksel art ikon henüz yoksa (dosya diskte yoksa) sessizce metinle devam eder — ikon
## eklendiğinde başka bir şey değiştirmeden otomatik görünür.
func _setup_discord_icon() -> void:
	if not is_instance_valid(_discord_button):
		return
	if not ResourceLoader.exists(DISCORD_ICON_PATH):
		return
	var icon_tex: Texture2D = load(DISCORD_ICON_PATH) as Texture2D
	if icon_tex:
		_discord_button.icon = icon_tex


func _refresh_locale(_locale: String = "") -> void:
	if _press_prompt:
		_press_prompt.text = tr("menu.press_any_button")
	if is_instance_valid(_disclaimer_title_label):
		_disclaimer_title_label.text = tr("menu.early_access_title")
	if is_instance_valid(_disclaimer_body_label):
		_disclaimer_body_label.text = tr("menu.early_access_disclaimer")
	if is_instance_valid(_disclaimer_hint_label):
		_disclaimer_hint_label.text = tr("menu.early_access_continue_hint")
	if _continue_button:
		_continue_button.text = tr("menu.continue")
	if _change_profile_button:
		_change_profile_button.text = tr("menu.change_profile")
	if _new_game_button:
		_new_game_button.text = tr("menu.new_game")
	if _load_game_button:
		_load_game_button.text = tr("menu.load_game")
	if _settings_button:
		_settings_button.text = tr("menu.settings")
	if _discord_button:
		_discord_button.text = tr("menu.discord")
	if _quit_button:
		_quit_button.text = tr("menu.quit")
	var footer := get_node_or_null("CenterContainer/Menu/Footer") as Label
	if footer:
		footer.text = tr("menu.beta_footer")

## Profil artık menü açılmadan önce seçilmiş oluyor, bu yüzden Yeni Oyun ve Oyunu Yükle
## araya profil ekranı sokmadan doğrudan kendi işlerine gidiyor.
func _on_new_game_pressed() -> void:
	_play_click()
	_show_new_game_tutorial_choice()

func _on_load_game_pressed() -> void:
	_play_click()
	if _load_game_menu and _load_game_menu.has_method("show_menu"):
		_disable_main_menu_focus()
		_load_game_menu.show_menu()
		if _load_game_menu.has_method("set_process_mode"):
			_load_game_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)

## Devam et: aktif profildeki en yeni kaydı (otomatik kayıt veya manuel slot, hangisi
## daha yeniyse) doğrudan yükler. Buton zaten kayıt yokken gizleniyor, yine de
## savunmacı davranıyoruz.
func _on_continue_pressed() -> void:
	_play_click()
	if not is_instance_valid(SaveManager):
		return
	if not SaveManager.continue_latest():
		push_warning("[MainMenu] Devam et: yüklenecek kayıt bulunamadı")
		_refresh_continue_button()

func _on_change_profile_pressed() -> void:
	_play_click()
	_in_profile_gate_phase = true
	_profile_gate_done = false
	_open_profile_menu(ProfileSelectMenu.MenuIntent.SELECT)

func _on_settings_pressed() -> void:
	_play_click()
	if _settings_menu and _settings_menu.has_method("show_menu"):
		# Disable focus on main menu buttons while settings is open
		_disable_main_menu_focus()
		_settings_menu.show_menu()
		if _settings_menu.has_method("set_process_mode"):
			_settings_menu.set_process_mode(Node.PROCESS_MODE_ALWAYS)
	else:
		push_warning("SettingsMenu not available")

func _on_discord_pressed() -> void:
	_play_click()
	if DISCORD_INVITE_URL.is_empty():
		push_warning("[MainMenu] DISCORD_INVITE_URL henüz ayarlanmadı — MainMenu.gd içindeki sabiti doldur")
		return
	OS.shell_open(DISCORD_INVITE_URL)

func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit()

func _setup_load_game_menu() -> void:
	if not _load_game_menu:
		push_warning("[MainMenu] LoadGameMenu node not found, creating instance...")
		var load_menu_scene = load("res://ui/LoadGameMenu.tscn")
		if load_menu_scene:
			_load_game_menu = load_menu_scene.instantiate()
			_load_game_menu.name = "LoadGameMenu"
			add_child(_load_game_menu)
		else:
			push_error("[MainMenu] Failed to load LoadGameMenu scene!")
			return
	
	if _load_game_menu.has_signal("slot_selected"):
		_load_game_menu.slot_selected.connect(_on_load_game_slot_selected)
	if _load_game_menu.has_signal("back_requested"):
		_load_game_menu.back_requested.connect(_on_load_game_back)
	
	if _load_game_menu.has_method("hide_menu"):
		_load_game_menu.hide_menu()

func _setup_new_game_tutorial_prompt() -> void:
	if _tutorial_prompt:
		return
	var sc: PackedScene = load("res://tutorial/ui/NewGameTutorialPrompt.tscn") as PackedScene
	if not sc:
		push_error("[MainMenu] NewGameTutorialPrompt.tscn yüklenemedi")
		return
	_tutorial_prompt = sc.instantiate()
	_tutorial_prompt.name = "NewGameTutorialPrompt"
	add_child(_tutorial_prompt)
	if _tutorial_prompt.has_signal("tutorial_chosen"):
		_tutorial_prompt.tutorial_chosen.connect(_on_new_game_tutorial_play)
	if _tutorial_prompt.has_signal("skip_tutorial_chosen"):
		_tutorial_prompt.skip_tutorial_chosen.connect(_on_new_game_tutorial_skip)
	if _tutorial_prompt.has_signal("back_requested"):
		_tutorial_prompt.back_requested.connect(_on_new_game_tutorial_back)


func _show_new_game_tutorial_choice() -> void:
	if _tutorial_prompt and _tutorial_prompt.has_method("show_prompt"):
		# Eskiden buraya profil ekranı üzerinden geliniyordu ve odağı o kapatıyordu.
		# Artık Yeni Oyun doğrudan buraya geldiği için odağı burada kapatmak gerekiyor.
		_disable_main_menu_focus()
		move_child(_tutorial_prompt, maxi(0, get_child_count() - 1))
		_tutorial_prompt.show_prompt()
	elif is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(false)


func _on_new_game_tutorial_play() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	if is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(true)


func _on_new_game_tutorial_skip() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	if is_instance_valid(SceneManager) and SceneManager.has_method("start_new_game"):
		SceneManager.start_new_game(false)


## Tutorial seçiminden geri: profil zaten seçili olduğu için artık profil ekranına değil,
## doğrudan ana menüye dönülüyor.
func _on_new_game_tutorial_back() -> void:
	_play_click()
	if _tutorial_prompt and _tutorial_prompt.has_method("hide_prompt"):
		_tutorial_prompt.hide_prompt()
	_enable_main_menu_focus()
	if _new_game_button:
		_new_game_button.grab_focus()


func _setup_profile_select_menu() -> void:
	if _profile_menu:
		return
	var sc: PackedScene = load("res://ui/ProfileSelectMenu.tscn") as PackedScene
	if not sc:
		push_error("[MainMenu] ProfileSelectMenu.tscn yüklenemedi")
		return
	_profile_menu = sc.instantiate()
	_profile_menu.name = "ProfileSelectMenu"
	add_child(_profile_menu)
	if _profile_menu.has_signal("profile_chosen"):
		_profile_menu.profile_chosen.connect(_on_profile_chosen)
	if _profile_menu.has_signal("back_requested"):
		_profile_menu.back_requested.connect(_on_profile_menu_back)
	if _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()


func _open_profile_menu(intent: ProfileSelectMenu.MenuIntent, allow_back: bool = true) -> void:
	if _profile_menu and _profile_menu.has_method("show_menu"):
		_disable_main_menu_focus()
		move_child(_profile_menu, maxi(0, get_child_count() - 1))
		_profile_menu.show_menu(intent, allow_back)
	else:
		push_warning("[MainMenu] Profil menüsü yok — doğrudan devam")
		if intent == ProfileSelectMenu.MenuIntent.NEW_GAME and is_instance_valid(SceneManager):
			_show_new_game_tutorial_choice()
		elif intent == ProfileSelectMenu.MenuIntent.LOAD and _load_game_menu and _load_game_menu.has_method("show_menu"):
			_load_game_menu.show_menu()
		else:
			# Profil kapısı: menü yoksa kilitlenmeyelim, kayıtlı/varsayılan profille devam et.
			_profile_gate_done = true


## Aşama 1.75: ilk açılışta profil seçtirir. Oyuncu bir profil seçene kadar bekler —
## geri butonu gizli, çünkü menü henüz yok, dönülecek bir yer de yok.
func _play_profile_gate_phase() -> void:
	if _profile_menu == null or not _profile_menu.has_method("show_menu"):
		return
	_in_profile_gate_phase = true
	_profile_gate_done = false
	_open_profile_menu(ProfileSelectMenu.MenuIntent.SELECT, false)
	while not _profile_gate_done:
		await get_tree().process_frame
	_in_profile_gate_phase = false


func _on_profile_chosen(profile_id: int) -> void:
	if is_instance_valid(SaveManager) and SaveManager.has_method("set_active_profile"):
		SaveManager.set_active_profile(profile_id)
	if _profile_menu and _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()

	# Profil ekranı artık yalnızca açılış kapısı ve "Profil değiştir" için açılıyor:
	# her iki durumda da sadece profil değişir ve menüye dönülür.
	_profile_gate_done = true
	_refresh_continue_button()
	_enable_main_menu_focus()
	_focus_first_menu_button()


## Geri: profil değişmedi, menüye dön. Açılış kapısında bu buton gizli olduğu için
## buraya yalnızca "Profil değiştir" akışından gelinir.
func _on_profile_menu_back() -> void:
	if _profile_menu and _profile_menu.has_method("hide_menu"):
		_profile_menu.hide_menu()
	_in_profile_gate_phase = false
	_profile_gate_done = true
	_enable_main_menu_focus()
	_focus_first_menu_button()


## Devam et butonu sadece aktif profilde yüklenecek bir kayıt varken görünür.
func _refresh_continue_button() -> void:
	if not is_instance_valid(_continue_button):
		return
	var has_save: bool = false
	if is_instance_valid(SaveManager) and SaveManager.has_method("get_latest_save_entry"):
		has_save = not SaveManager.get_latest_save_entry().is_empty()
	_continue_button.visible = has_save
	_continue_button.focus_mode = Control.FOCUS_ALL if has_save else Control.FOCUS_NONE


## Menüde odaklanılacak ilk buton: kayıt varsa Devam et, yoksa Yeni Oyun.
func _focus_first_menu_button() -> void:
	if is_instance_valid(_continue_button) and _continue_button.visible:
		_continue_button.grab_focus()
	elif is_instance_valid(_new_game_button):
		_new_game_button.grab_focus()


func _setup_settings_menu() -> void:
	if not _settings_menu:
		push_warning("[MainMenu] SettingsMenu node not found, creating instance...")
		var settings_menu_scene = load("res://ui/SettingsMenu.tscn")
		if settings_menu_scene:
			_settings_menu = settings_menu_scene.instantiate()
			_settings_menu.name = "SettingsMenu"
			add_child(_settings_menu)
		else:
			push_error("[MainMenu] Failed to load SettingsMenu scene!")
			return
	
	if _settings_menu.has_signal("back_requested"):
		_settings_menu.back_requested.connect(_on_settings_back)
	if _settings_menu.has_signal("settings_applied"):
		_settings_menu.settings_applied.connect(_on_settings_applied)
	
	if _settings_menu.has_method("hide_menu"):
		_settings_menu.hide_menu()

func _on_settings_back() -> void:
	if _settings_menu and _settings_menu.has_method("hide_menu"):
		_settings_menu.hide_menu()
	_enable_main_menu_focus()
	_focus_first_menu_button()


func _on_settings_applied(_settings: Dictionary) -> void:
	_refresh_locale()

func _disable_main_menu_focus() -> void:
	# Disable focus on all buttons so they can't be navigated to while settings is open
	if _continue_button:
		_continue_button.focus_mode = Control.FOCUS_NONE
	if _change_profile_button:
		_change_profile_button.focus_mode = Control.FOCUS_NONE
	if _new_game_button:
		_new_game_button.focus_mode = Control.FOCUS_NONE
	if _load_game_button:
		_load_game_button.focus_mode = Control.FOCUS_NONE
	if _settings_button:
		_settings_button.focus_mode = Control.FOCUS_NONE
	if _discord_button:
		_discord_button.focus_mode = Control.FOCUS_NONE
	if _quit_button:
		_quit_button.focus_mode = Control.FOCUS_NONE

func _enable_main_menu_focus() -> void:
	# Re-enable focus on all buttons
	# Devam et butonu kayıt yoksa gizli kalır; gizliyken odak alması istenmez.
	if _continue_button:
		_continue_button.focus_mode = Control.FOCUS_ALL if _continue_button.visible else Control.FOCUS_NONE
	if _change_profile_button:
		_change_profile_button.focus_mode = Control.FOCUS_ALL
	if _new_game_button:
		_new_game_button.focus_mode = Control.FOCUS_ALL
	if _load_game_button:
		_load_game_button.focus_mode = Control.FOCUS_ALL
	if _settings_button:
		_settings_button.focus_mode = Control.FOCUS_ALL
	if _discord_button:
		_discord_button.focus_mode = Control.FOCUS_ALL
	if _quit_button:
		_quit_button.focus_mode = Control.FOCUS_ALL

func _on_load_game_slot_selected(slot_id: int) -> void:
	print("[MainMenu] Loading game from slot %d..." % slot_id)
	if is_instance_valid(SaveManager):
		# Connect to error signals if not already connected
		if SaveManager.has_signal("error_occurred"):
			if not SaveManager.error_occurred.is_connected(_on_save_manager_error):
				SaveManager.error_occurred.connect(_on_save_manager_error)
		if SaveManager.has_signal("load_completed"):
			if not SaveManager.load_completed.is_connected(_on_load_completed):
				SaveManager.load_completed.connect(_on_load_completed)
		
		var loaded_ok: bool = false
		if slot_id == SaveManager.AUTOSAVE_UI_SLOT_ID:
			loaded_ok = SaveManager.load_autosave()
		else:
			loaded_ok = SaveManager.load_game(slot_id)
		if loaded_ok:
			print("[MainMenu] ✅ Game loaded successfully")
		else:
			push_error("[MainMenu] Failed to load game from slot %d" % slot_id)
			_show_error(tr("error.load_failed_title"), tr("error.load_failed_message"))
	else:
		push_error("[MainMenu] SaveManager not available!")
		_show_error(tr("error.title"), tr("error.save_manager_missing"))

func _on_load_completed(slot_id: int, success: bool) -> void:
	if not success:
		_show_error(tr("error.load_failed_title"), tr("error.load_failed_corrupt"))


func _on_save_manager_error(error_message: String, error_type: String) -> void:
	if error_type == "load" or error_type == "validation":
		_show_error(tr("error.load_error_title"), error_message)

func _show_error(title: String, message: String) -> void:
	"""Show error dialog"""
	var error_dialog_scene = load("res://ui/ErrorDialog.tscn")
	if error_dialog_scene:
		var error_dialog = error_dialog_scene.instantiate()
		get_tree().root.add_child(error_dialog)
		if error_dialog.has_method("show_error"):
			error_dialog.show_error(title, message)

func _on_load_game_back() -> void:
	if _load_game_menu and _load_game_menu.has_method("hide_menu"):
		_load_game_menu.hide_menu()
	_enable_main_menu_focus()
	if _new_game_button:
		_new_game_button.grab_focus()

func _play_click() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("play_ui"):
		SoundManager.play_ui("click")


func _apply_startup_audio_settings() -> void:
	if is_instance_valid(SoundManager) and SoundManager.has_method("_apply_saved_volume_from_settings"):
		SoundManager._apply_saved_volume_from_settings()


## Menü yazı boyutu ayarı (Ayarlar > Görüntü > Arayüz Boyutu). register() bu kökü kapsama alır:
## şimdi bir kez uygular, sonra ölçek her değiştiğinde yeniden uygular. Autoload'a node yoluyla
## erişiyoruz ki dosya --check-only ile tek başına doğrulanabilsin (bkz. CLAUDE.md).
func _register_ui_font_scale() -> void:
	var scaler := get_node_or_null("/root/UiFontScale")
	if scaler != null and scaler.has_method("register"):
		scaler.call("register", self)
