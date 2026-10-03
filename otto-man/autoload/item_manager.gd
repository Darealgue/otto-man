# ItemManager.gd
# Central manager for all items in the game.
# Replaces/works alongside PowerupManager for the new item system.

extends Node

signal item_activated(item: ItemEffect)
signal item_deactivated(item: ItemEffect)
signal item_set_activated(set_id: String)
signal item_set_deactivated(set_id: String)
signal xp_orbs_collected_changed(count: int)

var player: CharacterBody2D
var active_items: Array[ItemEffect] = []
var active_item_sets: Array[String] = []
var _set_bonus_cache: Dictionary = {}
var enemy_kill_count: int = 0
var xp_orbs_collected: int = 0  # Xp orb'u oyuncuya ulaştığında artar (bar + kart seçimi buna göre tetiklenir)
const KILLS_PER_ITEM: int = 10  # Her 10 kill'de item seçimi

# Item selection UI
const ItemSelection = preload("res://ui/item_selection.tscn")
var _item_selection_open: bool = false

# Pilot items (will expand later)
const ITEM_SCENES: Dictionary = {
	"baklava": preload("res://resources/items/baklava.tscn"),
	"simit": preload("res://resources/items/simit.tscn"),
	"ayran": preload("res://resources/items/ayran.tscn"),
	"hizli_el": preload("res://resources/items/hizli_el.tscn"),
	"combo_ustasi": preload("res://resources/items/combo_ustasi.tscn"),
	"zeytinyagi": preload("res://resources/items/zeytinyagi.tscn"),
	"demir_kalkan": preload("res://resources/items/demir_kalkan.tscn"),
	"ruzgar_hanceri": preload("res://resources/items/ruzgar_hanceri.tscn"),
	"yansitici_kalkan": preload("res://resources/items/yansitici_kalkan.tscn"),
	"kalkan_ustasi": preload("res://resources/items/kalkan_ustasi.tscn"),
	"parry_ustasi": preload("res://resources/items/parry_ustasi.tscn"),
	"guc_kayasi": preload("res://resources/items/guc_kayasi.tscn"),
	"gokten_dusus": preload("res://resources/items/gokten_dusus.tscn"),
	"ters_darbe": preload("res://resources/items/ters_darbe.tscn"),
	"cift_vurus": preload("res://resources/items/cift_vurus.tscn"),
	"hizli_charge": preload("res://resources/items/hizli_charge.tscn"),
	"genis_dusus": preload("res://resources/items/genis_dusus.tscn"),
	"kus_kanadi": preload("res://resources/items/kus_kanadi.tscn"),
	"zehirli_tirnak": preload("res://resources/items/zehirli_tirnak.tscn"),
	"parry_ruhu": preload("res://resources/items/parry_ruhu.tscn"),
	"tunel_ustasi": preload("res://resources/items/tunel_ustasi.tscn"),
	"yildirim_adimi": preload("res://resources/items/yildirim_adimi.tscn"),
	"dodge_bombasi": preload("res://resources/items/dodge_bombasi.tscn"),
	"dikenli_kalkan": preload("res://resources/items/dikenli_kalkan.tscn"),
	"atesli_yumruk": preload("res://resources/items/atesli_yumruk.tscn"),
	"buzlu_kilic": preload("res://resources/items/buzlu_kilic.tscn"),
	"kaygan_yag": preload("res://resources/items/kaygan_yag.tscn"),
	"zehirli_dusus": preload("res://resources/items/zehirli_dusus.tscn"),
	"simsek_kalkani": preload("res://resources/items/simsek_kalkani.tscn"),
	"zaman_durdurucu": preload("res://resources/items/zaman_durdurucu.tscn"),
	"kum_saati": preload("res://resources/items/kum_saati.tscn"),
	"zehirli_dev": preload("res://resources/items/zehirli_dev.tscn"),
	"yildirim_dususu": preload("res://resources/items/yildirim_dususu.tscn"),
	"patlama_zinciri": preload("res://resources/items/patlama_zinciri.tscn"),
	"simsek_parmagi": preload("res://resources/items/simsek_parmagi.tscn"),
	"gok_gurultusu": preload("res://resources/items/gok_gurultusu.tscn"),
	"lav_cekici": preload("res://resources/items/lav_cekici.tscn"),
	"donma_cekici": preload("res://resources/items/donma_cekici.tscn"),
	"ates_topu_dususu": preload("res://resources/items/ates_topu_dususu.tscn"),
	"buzlu_kayma": preload("res://resources/items/buzlu_kayma.tscn"),
	"atesli_kayma": preload("res://resources/items/atesli_kayma.tscn"),
	"uzun_menzil": preload("res://resources/items/uzun_menzil.tscn"),
	"ucuncu_vurus": preload("res://resources/items/ucuncu_vurus.tscn"),
	"genis_darbe": preload("res://resources/items/genis_darbe.tscn"),
	"hizlanan_yumruk": preload("res://resources/items/hizlanan_yumruk.tscn"),
	"patlama_topuzu": preload("res://resources/items/patlama_topuzu.tscn"),
	"ruh_avcisi": preload("res://resources/items/ruh_avcisi.tscn"),
	"buz_cagi": preload("res://resources/items/buz_cagi.tscn"),
	"ikinci_nefes": preload("res://resources/items/ikinci_nefes.tscn"),
	"cift_ziplama": preload("res://resources/items/cift_ziplama.tscn"),
	"havada_kal": preload("res://resources/items/havada_kal.tscn"),
	"ortaoyunu": preload("res://resources/items/ortaoyunu.tscn"),
	"gorunmezlik_pelerini": preload("res://resources/items/gorunmezlik_pelerini.tscn"),
	"berserker_ruhu": preload("res://resources/items/berserker_ruhu.tscn"),
	"nazar_boncugu": preload("res://resources/items/nazar_boncugu.tscn"),
	"kan_tadi": preload("res://resources/items/kan_tadi.tscn"),
	"tas_yurek": preload("res://resources/items/tas_yurek.tscn"),
	"olumcul_sukut": preload("res://resources/items/olumcul_sukut.tscn"),
	"kalkan_kuresi": preload("res://resources/items/kalkan_kuresi.tscn"),
	"parry_zirhi": preload("res://resources/items/parry_zirhi.tscn"),
	"keskin_refleks": preload("res://resources/items/keskin_refleks.tscn"),
	"geri_tepme": preload("res://resources/items/geri_tepme.tscn"),
	"karsi_atilim": preload("res://resources/items/karsi_atilim.tscn"),
	"altin_pencere": preload("res://resources/items/altin_pencere.tscn"),
	"hasar_donusumu": preload("res://resources/items/hasar_donusumu.tscn"),
	"yankilanan_parry": preload("res://resources/items/yankilanan_parry.tscn"),
	"nobetci": preload("res://resources/items/nobetci.tscn"),
	"savunma_ofkesi": preload("res://resources/items/savunma_ofkesi.tscn"),
	"topuk_kirici": preload("res://resources/items/topuk_kirici.tscn"),
	"karagoz_laneti": preload("res://resources/items/karagoz_laneti.tscn"),
	"hacivat_golgesi": preload("res://resources/items/hacivat_golgesi.tscn"),
	"flank_avantaji": preload("res://resources/items/flank_avantaji.tscn"),
	"sessiz_ayakkabi": preload("res://resources/items/sessiz_ayakkabi.tscn"),
	"golge_pelerini": preload("res://resources/items/golge_pelerini.tscn"),
	"elemental_odak": preload("res://resources/items/elemental_odak.tscn"),
	# --- Dalga 1: yeni itemler (docs/ZINDAN_ITEM_FIKIRLERI.md) ---
	"ok_yagmuru": preload("res://resources/items/ok_yagmuru.tscn"),
	"pala_kilici": preload("res://resources/items/pala_kilici.tscn"),
	"cenk_meydani": preload("res://resources/items/cenk_meydani.tscn"),
	"keskin_nazar": preload("res://resources/items/keskin_nazar.tscn"),
	"taskin_guc": preload("res://resources/items/taskin_guc.tscn"),
	"ruh_akisi": preload("res://resources/items/ruh_akisi.tscn"),
	"sansli_nal": preload("res://resources/items/sansli_nal.tscn"),
	"sadik_golge": preload("res://resources/items/sadik_golge.tscn"),
	# --- Dalga 2: menzilli vuruş yükseltmeleri ---
	"yansiyan_ok": preload("res://resources/items/yansiyan_ok.tscn"),
	"ruzgarin_nisani": preload("res://resources/items/ruzgarin_nisani.tscn"),
	"yanki_oku": preload("res://resources/items/yanki_oku.tscn"),
	"kartal_bakisi": preload("res://resources/items/kartal_bakisi.tscn"),
	"gerilmis_yay": preload("res://resources/items/gerilmis_yay.tscn"),
	"golge_nisanci": preload("res://resources/items/golge_nisanci.tscn"),
	"suru_oku": preload("res://resources/items/suru_oku.tscn"),
	"pesine_dusen": preload("res://resources/items/pesine_dusen.tscn"),
	"agir_mermi": preload("res://resources/items/agir_mermi.tscn"),
	"ruh_mermisi": preload("res://resources/items/ruh_mermisi.tscn"),
	# --- Dalga 3: tuzak / patlama / bağışıklık / meta ---
	"tuzak_fisildayan": preload("res://resources/items/tuzak_fisildayan.tscn"),
	"barut_zirhi": preload("res://resources/items/barut_zirhi.tscn"),
	"kara_barut": preload("res://resources/items/kara_barut.tscn"),
	"panzehir_derisi": preload("res://resources/items/panzehir_derisi.tscn"),
	"falci_kadin": preload("res://resources/items/falci_kadin.tscn"),
	# --- Dalga 4: parry & mobilite ---
	"golge_adimi": preload("res://resources/items/golge_adimi.tscn"),
	"firlatma_parry": preload("res://resources/items/firlatma_parry.tscn"),
	"hayalet_adim": preload("res://resources/items/hayalet_adim.tscn"),
	"sekme_tabanligi": preload("res://resources/items/sekme_tabanligi.tscn"),
	"duvar_ustasi": preload("res://resources/items/duvar_ustasi.tscn"),
	"son_kale": preload("res://resources/items/son_kale.tscn"),
	# --- Dalga 5: ceset ekonomisi ---
	"les_gazi": preload("res://resources/items/les_gazi.tscn"),
	"ceset_tekmesi": preload("res://resources/items/ceset_tekmesi.tscn"),
	# --- Dalga 6: element ustalığı II + stamina büyüsü ---
	"element_izi": preload("res://resources/items/element_izi.tscn"),
	"cuppe_degil_zirh": preload("res://resources/items/cuppe_degil_zirh.tscn"),
	"element_degisimi": preload("res://resources/items/element_degisimi.tscn"),
	"cevher_dili": preload("res://resources/items/cevher_dili.tscn"),
	"yikim_muhru": preload("res://resources/items/yikim_muhru.tscn"),
	"kan_bedeli": preload("res://resources/items/kan_bedeli.tscn"),
	# --- Dalga 7: unlock sistemi Faz 2 (docs/ITEM_UNLOCK_SISTEMI.md 5.7-5.9) ---
	# Ateş zindanı: yanmaya payoff + eksik savunma verb'ü
	"koz_tutan": preload("res://resources/items/koz_tutan.tscn"),
	"koruk": preload("res://resources/items/koruk.tscn"),
	"tavlanmis_celik": preload("res://resources/items/tavlanmis_celik.tscn"),
	"ocak": preload("res://resources/items/ocak.tscn"),
	# Barut zindanı: giriş + mobilite
	"falya": preload("res://resources/items/falya.tscn"),
	"lagimci": preload("res://resources/items/lagimci.tscn"),
	"tepme": preload("res://resources/items/tepme.tscn"),
	# Zehir zindanı: zehrin eksik olan RARE tavanı
	"sabir_tasi": preload("res://resources/items/sabir_tasi.tscn"),
	"yankesici": preload("res://resources/items/yankesici.tscn"),
	"serbetci": preload("res://resources/items/serbetci.tscn"),
	# "Fiil değiştiren" item'lar (stamina ekonomisini yeniden yazar)
	"yansiyan_irade": preload("res://resources/items/yansiyan_irade.tscn"),
	"zehirli_sekme": preload("res://resources/items/zehirli_sekme.tscn"),
	"kesintisiz_akis": preload("res://resources/items/kesintisiz_akis.tscn"),
	# Havaya Fırlatma boru hattı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.4)
	"ziplatan_yumruk": preload("res://resources/items/ziplatan_yumruk.tscn"),
	"toplu_kaldirma": preload("res://resources/items/toplu_kaldirma.tscn"),
	"agirliksiz": preload("res://resources/items/agirliksiz.tscn"),
	"kader_ani": preload("res://resources/items/kader_ani.tscn"),
	# Kaçınma boru hattı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.2)
	"refleks": preload("res://resources/items/refleks.tscn"),
	"kavis_adimi": preload("res://resources/items/kavis_adimi.tscn"),
	"soguk_temas": preload("res://resources/items/soguk_temas.tscn"),
	"iz_birakan": preload("res://resources/items/iz_birakan.tscn"),
	# Temas Saldırısı boru hattı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.1)
	"artan_guc": preload("res://resources/items/artan_guc.tscn"),
	"kesintisiz_zincir": preload("res://resources/items/kesintisiz_zincir.tscn"),
	"daire_darbesi": preload("res://resources/items/daire_darbesi.tscn"),
	"sirt_darbesi": preload("res://resources/items/sirt_darbesi.tscn"),
	"kesme_yayi": preload("res://resources/items/kesme_yayi.tscn"),
	"guc_devri": preload("res://resources/items/guc_devri.tscn"),
	"zincirleme_vurus": preload("res://resources/items/zincirleme_vurus.tscn"),
	"sarsici_darbe": preload("res://resources/items/sarsici_darbe.tscn"),
	# Savunma boru hattı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.3)
	"alan_parrysi": preload("res://resources/items/alan_parrysi.tscn"),
	"emici_kalkan": preload("res://resources/items/emici_kalkan.tscn"),
	"karsi_mermi": preload("res://resources/items/karsi_mermi.tscn"),
	"cellat_nefesi": preload("res://resources/items/cellat_nefesi.tscn"),
	# Hareket/Parkur boru hattı (bkz. docs/ITEM_PIPELINE_DESIGN.md §2.5)
	"duvar_kirici": preload("res://resources/items/duvar_kirici.tscn"),
	"ruzgar_toplama": preload("res://resources/items/ruzgar_toplama.tscn"),
	"kesintisiz_akrobasi": preload("res://resources/items/kesintisiz_akrobasi.tscn"),
	# Wildcard/Joker (bkz. docs/ITEM_PIPELINE_DESIGN.md §7)
	"usta_isci": preload("res://resources/items/usta_isci.tscn"),
	"tek_sanat": preload("res://resources/items/tek_sanat.tscn"),
	# 2026-09-30 kullanıcı geri bildirimiyle eklenen ek item'lar (firtina/golge
	# havuzlarını güçlendirme + Havaya Fırlatma derinliği + kamp ekonomisi)
	"yildirim_zinciri": preload("res://resources/items/yildirim_zinciri.tscn"),
	"firtina_gozu": preload("res://resources/items/firtina_gozu.tscn"),
	"yere_cakis": preload("res://resources/items/yere_cakis.tscn"),
	"agir_yumruk": preload("res://resources/items/agir_yumruk.tscn"),
	"sessiz_adim": preload("res://resources/items/sessiz_adim.tscn"),
	"golgeye_karisma": preload("res://resources/items/golgeye_karisma.tscn"),
	"kalkan_kirigi": preload("res://resources/items/kalkan_kirigi.tscn"),
	"tasan_kaynak": preload("res://resources/items/tasan_kaynak.tscn"),
	# Mermi türü: heavy mermisini Top'tan zıplayan bombaya çevirir (ITEM_REQUIREMENTS_ANY: ok_yagmuru)
	"ates_bombasi": preload("res://resources/items/ates_bombasi.tscn"),
}

# Ön koşul: bu item_id sadece listelenen item'lar aktifken seçenekte çıkar (örn. Kum Saati → Zaman Durdurucu)
const ITEM_REQUIREMENTS: Dictionary = {
	"kum_saati": ["zaman_durdurucu"],
	"karagoz_laneti": ["ortaoyunu"],
	"hacivat_golgesi": ["ortaoyunu"],
	"kesintisiz_zincir": ["artan_guc"],
	"kesintisiz_akis": ["zehirli_sekme"],
}

# Ön koşul (VEYA): listedeki item'lardan EN AZ BİRİ aktifse seçenekte çıkar
const ITEM_REQUIREMENTS_ANY: Dictionary = {
	"yansiyan_ok": ["uzun_menzil", "ok_yagmuru"],
	"ruzgarin_nisani": ["uzun_menzil", "ok_yagmuru"],
	"yanki_oku": ["uzun_menzil", "ok_yagmuru"],
	"kartal_bakisi": ["uzun_menzil", "ok_yagmuru"],
	"gerilmis_yay": ["uzun_menzil", "ok_yagmuru"],
	"golge_nisanci": ["uzun_menzil", "ok_yagmuru"],
	"suru_oku": ["uzun_menzil", "ok_yagmuru"],
	"pesine_dusen": ["uzun_menzil", "ok_yagmuru"],
	"agir_mermi": ["uzun_menzil", "ok_yagmuru"],
	"ruh_mermisi": ["uzun_menzil", "ok_yagmuru"],
	"ates_bombasi": ["ok_yagmuru"],
	"kan_bedeli": ["cevher_dili", "yikim_muhru"],
}

## 2 parça = set bonusu (geri bildirim build — 4 set)
const ITEM_SET_DEFINITIONS: Dictionary = {
	"poison_mastery": {
		"name_key": "item.set.poison.name",
		"items": ["zehirli_tirnak", "zehirli_dev", "zehirli_dusus"],
		"pieces_for_bonus": 2,
		"bonuses": {"poison_damage_mult": 1.4, "poison_max_stacks_bonus": 2},
	},
	"iron_guard": {
		"name_key": "item.set.guard.name",
		"items": ["yansitici_kalkan", "simsek_kalkani", "ters_darbe", "parry_ustasi", "dikenli_kalkan", "demir_kalkan"],
		"pieces_for_bonus": 2,
		"bonuses": {"block_reflect_mult": 1.35},
	},
	"sky_strike": {
		"name_key": "item.set.aerial.name",
		"items": ["yildirim_dususu", "ates_topu_dususu", "buz_cagi", "zehirli_dusus", "gokten_dusus", "genis_dusus"],
		"pieces_for_bonus": 2,
		"bonuses": {"fall_damage_mult": 1.3, "fall_effect_damage_mult": 1.35, "fall_effect_radius_mult": 1.2},
	},
	# "items" yerine "tag_prefix" kullanıyor (bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 3).
	# Eskiden ["atesli_yumruk", "buzlu_kilic", "simsek_parmagi"] elle listeliyordu; bu üç
	# item'ın ağır/düşüş eşdeğerlerini (lav_cekici, donma_cekici, gok_gurultusu, vb.) ve
	# zehiri hiç saymıyordu. Artık "elemental_" ile başlayan herhangi bir tag'i taşıyan
	# aktif item'lar otomatik sayılıyor — yeni bir elemental item eklendiğinde bu listeye
	# elle eklenmesi gerekmez. Havuz 3 item'dan 12'ye çıktığı için eşik de 2'den 3'e çekildi.
	"tri_element": {
		"name_key": "item.set.elemental.name",
		"tag_prefix": "elemental_",
		"pieces_for_bonus": 3,
		"bonuses": {"elemental_damage_mult": 1.25},
	},
	# "category_family" kullanıyor — bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4.
	# Her item zaten TEK bir ItemCategory taşıyor (item_effect.gd); burada yeni bir tag
	# eklemeye gerek yok, sadece hangi kategorilerin "hareket" sayıldığını gruplayıp
	# eşik koyuyoruz. Sayısal bonus yok — bu setin AKTİF OLMASI kendi başına bir
	# davranış kapısı: apply_movement_contact_tick() bunu okuyup dodge/dash'i temas
	# hasarı verir hale getiriyor (bkz. o fonksiyon ve dodge_state.gd/dash_state.gd).
	"restless_body": {
		"name_key": "item.set.movement.name",
		"category_family": [ItemEffect.ItemCategory.DODGE, ItemEffect.ItemCategory.SLIDE, ItemEffect.ItemCategory.WALL_SLIDE, ItemEffect.ItemCategory.JUMP, ItemEffect.ItemCategory.CROUCH],
		"pieces_for_bonus": 3,
		"bonuses": {},
	},
	# Aynı desen, dövüş kategorileri için. Aktifken _on_global_attack_landed_brawl_family
	# her isabetli vuruşa (light/heavy/fall, tip fark etmez) aktif element(ler)i uygular —
	# oyuncu bunun için ayrıca element item'ının "doğru" saldırı tipini bulmasına gerek kalmaz.
	"brawler_instinct": {
		"name_key": "item.set.brawl.name",
		"category_family": [ItemEffect.ItemCategory.LIGHT_ATTACK, ItemEffect.ItemCategory.HEAVY_ATTACK, ItemEffect.ItemCategory.FALL_ATTACK],
		"pieces_for_bonus": 4,
		"bonuses": {},
	},
}

## ============================================================================
## UNLOCK SİSTEMİ (docs/ITEM_UNLOCK_SISTEMI.md)
## Oyuncu dar bir başlangıç havuzuyla başlar; zindan tamamladıkça yeni item'lar
## kalıcı olarak koleksiyona girer. get_random_items() sadece açılmışları teklif eder.
## ============================================================================

signal item_unlocked(item_id: String)
signal unlock_offer_resolved()

## Oyunun başında açık olan item'lar. Element yok — başlangıç havuzu fiilleri öğretir.
## Zayıf item kuralı: zayıf item ödül olamaz, başlangıçta olur (baklava, topuk_kirici).
## 2026-09-30: ayran/zeytinyagi/gokten_dusus/guc_kayasi/hizli_charge/tunel_ustasi
## çıkarıldı — hepsi zaten itemsiz de var olan bir fiile (%X) düz bonus ekliyordu,
## oyuncunun ilk izlenimi tamamen "stat sopası" oluyordu (kullanıcı geri bildirimi:
## "hep eski itemler geldi... yüzde elli daha hızlı stamina doldurma... bunları
## istemiyorum"). Yerlerine gerçekten fiil/davranış değiştiren, önkoşulsuz COMMON/
## UNCOMMON boru hattı item'ları kondu (bkz. docs/ITEM_PIPELINE_DESIGN.md).
const STARTER_ITEM_IDS: Array[String] = [
	"baklava", "simit",
	"hizli_el", "combo_ustasi", "cift_vurus", "ucuncu_vurus",
	"demir_kalkan", "kalkan_ustasi", "parry_ruhu",
	"cift_ziplama", "kus_kanadi", "ruzgar_hanceri",
	"topuk_kirici",
	"duvar_kirici", "soguk_temas", "sarsici_darbe", "kesme_yayi", "artan_guc", "emici_kalkan",
	# Mermi açıcıları: burada olmaları TÜM Mermi yükseltme item'larını (yansiyan_ok,
	# ruzgarin_nisani, yanki_oku, kartal_bakisi, gerilmis_yay, golge_nisanci, suru_oku,
	# pesine_dusen, agir_mermi, ruh_mermisi — ITEM_REQUIREMENTS_ANY ile bunlara bağlı)
	# oyunun başından itibaren fırtına keşif havuzunda aday yapar (CHILD_HOME_BY_PARENT);
	# artık bedava açılmaz, zindan sonunda kart olarak seçilir.
	"uzun_menzil", "ok_yagmuru",
]

## Havuza hiç girmeyen item'lar (dosyaları duruyor ama teklif edilmiyor).
## Not: miknatis (altın çekme) buraya değil, tamamen silindi — akrobat hırsız ilkesine
## aykırıydı: altın toplamak bir beceri ifadesi, otomatikleştirilmemeli.
## bkz. docs/ITEM_UNLOCK_SISTEMI.md bölüm 3
## 2026-09-30: aşağıdaki 14 item, docs/ITEM_PIPELINE_DESIGN.md §8.3'te "Atılır" olarak
## işaretlenmişti (düz stat sopası, hiçbir boru hattının bir "adımı" değil) ama havuzlardan
## hiç çıkarılmamıştı — kullanıcı geri bildirimi ("hep eski itemler geldi, bunları
## istemiyorum") üzerine artık gerçekten teklif edilmiyorlar. sadik_golge, ebeveyni
## ruh_avcisi burada olduğu için zaten cascade ile de açılamaz; açıklık için ayrıca eklendi.
const EXCLUDED_ITEM_IDS: Array[String] = [
	"hizlanan_yumruk", "ruh_avcisi", "ikinci_nefes", "berserker_ruhu", "kan_tadi",
	"tas_yurek", "sessiz_ayakkabi", "golge_pelerini", "sadik_golge", "barut_zirhi",
	"kara_barut", "panzehir_derisi", "kaygan_yag", "keskin_nazar",
]

const UNLOCK_TIER_KESIF: String = "kesif"
const UNLOCK_TIER_BOSS: String = "boss"

## Zindan teması -> {kesif: [...], boss: [...]}
## kesif = keşif run 1-3 ödülü (giriş item'ları), boss = boss clear ödülü (derinlik).
## Ön koşullu item'lar burada YOK: ebeveyni açıldığında ebeveynin temasının havuzuna
## otomatik aday olurlar (bkz. _child_ids_for / CHILD_HOME_BY_PARENT).
const DUNGEON_THEME_POOLS: Dictionary = {
	"ates": {
		# Ateş = VUR: yanma + ham tek hedef hasarı, ağır vuruş
		"kesif": ["atesli_yumruk", "ates_topu_dususu", "taskin_guc", "koz_tutan", "koruk", "gokten_dusus", "guc_kayasi", "hizli_charge", "sansli_nal"],
		"boss": ["atesli_kayma", "ocak", "sirt_darbesi", "guc_devri"],
	},
	"buz": {
		# Buz = DAYAN: blok, parry, kalkan, yavaşlatma
		"kesif": ["buzlu_kilic", "donma_cekici", "buz_cagi", "yansitici_kalkan", "dikenli_kalkan", "ters_darbe", "parry_ustasi", "olumcul_sukut", "kalkan_kirigi", "parry_zirhi", "savunma_ofkesi", "keskin_refleks", "geri_tepme", "nobetci", "karsi_atilim", "tavlanmis_celik", "firlatma_parry"],
		"boss": ["buzlu_kayma", "nazar_boncugu", "son_kale", "cuppe_degil_zirh", "zaman_durdurucu", "yansiyan_irade", "alan_parrysi", "tasan_kaynak", "kalkan_kuresi", "altin_pencere", "hasar_donusumu", "yankilanan_parry", "karsi_mermi", "simsek_kalkani", "refleks"],
	},
	"zehir": {
		# Zehir = SİNSİCE ÖLDÜR: zamanla hasar, yayılma, gizlilik, hırsızlık
		"kesif": ["zehirli_tirnak", "zehirli_dev", "zehirli_dusus", "ceset_tekmesi", "les_gazi", "sessiz_adim", "golgeye_karisma"],
		"boss": ["gorunmezlik_pelerini", "hayalet_adim", "flank_avantaji", "sabir_tasi", "yankesici", "serbetci"],
	},
	"firtina": {
		# Fırtına = HAREKET ET: şimşek, hava, dash/dodge, parkur
		"kesif": ["gok_gurultusu", "yildirim_dususu", "yildirim_adimi", "havada_kal", "sekme_tabanligi", "firtina_gozu", "zeytinyagi", "ruzgar_toplama", "tunel_ustasi"],
		"boss": ["simsek_parmagi", "duvar_ustasi", "yildirim_zinciri", "ziplatan_yumruk", "agirliksiz", "agir_yumruk", "toplu_kaldirma", "zehirli_sekme", "kavis_adimi", "iz_birakan", "kesintisiz_akrobasi"],
	},
	"barut": {
		# Barut = PATLAT: alan hasarı, patlama, zincir, çoklu hedef
		"kesif": ["patlama_zinciri", "dodge_bombasi", "lav_cekici", "falya", "lagimci", "tepme", "zincirleme_vurus", "pala_kilici", "genis_dusus"],
		"boss": ["patlama_topuzu", "tuzak_fisildayan", "cenk_meydani", "yikim_muhru", "cevher_dili", "daire_darbesi", "yere_cakis", "genis_darbe"],
	},
	"golge": {
		# Gölge = BİRLEŞTİR: sinerji, element dönüşümü, kaynak (stamina)
		"kesif": ["element_izi", "ruh_akisi", "ayran", "cellat_nefesi"],
		"boss": ["ortaoyunu", "golge_adimi", "element_degisimi", "elemental_odak", "falci_kadin", "kader_ani", "usta_isci", "tek_sanat"],
	},
}

const DEFAULT_DUNGEON_THEME: String = "ates"

## Kalıcı koleksiyon. Sadece buradakiler run içinde kart olarak teklif edilir.
var unlocked_item_ids: Array[String] = []
## Bekleyen unlock teklifleri: [{theme: String, tier: String, picks: int}]
## Sahne geçişi teklifi yutmasın diye kuyruğa alınır ve kayda yazılır.
var _pending_unlock_offers: Array[Dictionary] = []
var _unlock_selection_open: bool = false


func _ready() -> void:
	var container = Node.new()
	container.name = "ActiveItems"
	add_child(container)
	set_process(true)
	if unlocked_item_ids.is_empty():
		_reset_unlocks_to_starter()
	if OS.is_debug_build():
		_validate_unlock_pools()
	var tm: Node = get_node_or_null("/root/TimeManager")
	if is_instance_valid(tm) and tm.has_signal("day_changed"):
		if not tm.is_connected("day_changed", _on_day_changed):
			tm.connect("day_changed", _on_day_changed)
	refresh_falci_schedule()


func _on_day_changed(_new_day: int) -> void:
	refresh_falci_schedule()


## --- Sorgular ---

func is_unlocked(item_id: String) -> bool:
	return item_id in unlocked_item_ids


func get_unlocked_item_ids() -> Array[String]:
	return unlocked_item_ids.duplicate()


## Bir temanın toplam item sayısı ve kaçının açıldığı — dünya haritası göstergesi için.
func get_theme_unlock_progress(theme: String) -> Dictionary:
	var pool: Array[String] = _theme_pool(theme, "")
	pool.append_array(_child_ids_for(theme, ""))
	var owned: int = 0
	for id in pool:
		if is_unlocked(id):
			owned += 1
	return {"unlocked": owned, "total": pool.size()}


## --- Unlock ---

func unlock_item(item_id: String) -> bool:
	if item_id.is_empty() or item_id in EXCLUDED_ITEM_IDS:
		return false
	if not ITEM_SCENES.has(item_id):
		push_warning("[ItemManager] Bilinmeyen item unlock denemesi: %s" % item_id)
		return false
	if is_unlocked(item_id) or is_permanently_banished(item_id):
		return false
	unlocked_item_ids.append(item_id)
	item_unlocked.emit(item_id)
	print("[ItemManager] Item açıldı: %s" % item_id)
	return true


## Ön koşullu (çocuk) item'lar ebeveyniyle BEDAVA açılmaz. Ebeveyn açıldıysa çocuk, ebeveynin
## zindan temasının/kademesinin unlock havuzuna girer (bkz. _child_ids_for) ve bir sonraki
## zindan sonunda kart olarak çıkabilir. Başlangıç item'ı olan ebeveynlerin çocukları
## için ev tema burada elle verilir.
const CHILD_HOME_BY_PARENT: Dictionary = {
	"artan_guc": ["ates", "kesif"],
	"uzun_menzil": ["firtina", "kesif"],
	"ok_yagmuru": ["firtina", "kesif"],
}
## Ebeveyninin temasından farklı bir zindanda çıkması gereken çocuklar.
const CHILD_HOME_OVERRIDE: Dictionary = {
	"ates_bombasi": ["barut", "kesif"],
}


## Çocuğun unlock havuzundaki yeri: [tema, kademe]; belirlenemezse boş.
func _child_home(child_id: String) -> Array:
	if CHILD_HOME_OVERRIDE.has(child_id):
		return CHILD_HOME_OVERRIDE[child_id]
	var parents: Array = []
	parents.append_array(ITEM_REQUIREMENTS.get(child_id, []))
	parents.append_array(ITEM_REQUIREMENTS_ANY.get(child_id, []))
	for parent_id in parents:
		var pid: String = String(parent_id)
		for theme in DUNGEON_THEME_POOLS:
			for tier in [UNLOCK_TIER_KESIF, UNLOCK_TIER_BOSS]:
				if pid in DUNGEON_THEME_POOLS[theme].get(tier, []):
					return [String(theme), String(tier)]
		if CHILD_HOME_BY_PARENT.has(pid):
			return CHILD_HOME_BY_PARENT[pid]
	return []


## Verilen tema/kademede havuzlanan tüm çocuk item'lar (açık olup olmadıklarına bakmaz).
func _child_ids_for(theme: String, tier: String) -> Array[String]:
	var out: Array[String] = []
	for child_id in _dependent_item_ids():
		if child_id in EXCLUDED_ITEM_IDS:
			continue
		var home: Array = _child_home(child_id)
		if home.size() == 2 and String(home[0]) == theme and (tier.is_empty() or String(home[1]) == tier):
			out.append(child_id)
	return out


func _requirements_met_by_unlocks(item_id: String) -> bool:
	if item_id in ITEM_REQUIREMENTS:
		for req_id in ITEM_REQUIREMENTS[item_id]:
			if not is_unlocked(String(req_id)):
				return false
	if item_id in ITEM_REQUIREMENTS_ANY:
		var any_met: bool = false
		for req_id in ITEM_REQUIREMENTS_ANY[item_id]:
			if is_unlocked(String(req_id)):
				any_met = true
				break
		if not any_met:
			return false
	return true


func _dependent_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in ITEM_REQUIREMENTS:
		ids.append(String(key))
	for key in ITEM_REQUIREMENTS_ANY:
		var k: String = String(key)
		if k not in ids:
			ids.append(k)
	return ids


func _theme_pool(theme: String, tier: String) -> Array[String]:
	var themed: Dictionary = DUNGEON_THEME_POOLS.get(theme, {})
	if themed.is_empty():
		return []
	var out: Array[String] = []
	var tiers: Array = [tier] if not tier.is_empty() else [UNLOCK_TIER_KESIF, UNLOCK_TIER_BOSS]
	for t in tiers:
		for id in themed.get(t, []):
			out.append(String(id))
	return out


## Teklif edilebilecek adaylar: temada, doğru kademede, henüz açılmamış.
func get_unlock_candidates(theme: String, tier: String) -> Array[String]:
	var out: Array[String] = []
	for id in _theme_pool(theme, tier):
		if is_unlocked(id) or id in EXCLUDED_ITEM_IDS:
			continue
		if is_permanently_banished(id):
			continue  # Falcı kalıcı olarak eledi
		out.append(id)
	# Ebeveyni açılmış çocuk item'lar da aynı temanın havuzunda aday olur
	for id in _child_ids_for(theme, tier):
		if is_unlocked(id) or is_permanently_banished(id):
			continue
		if not _requirements_met_by_unlocks(id):
			continue
		out.append(id)
	return out


## Bu temada bu kademede açılacak bir şey kaldı mı? (tükenmiş zindan kontrolü)
func has_unlock_candidates(theme: String, tier: String) -> bool:
	return not get_unlock_candidates(theme, tier).is_empty()


## --- Teklif kuyruğu ---

func queue_unlock_offer(theme: String, tier: String, picks: int = 1) -> void:
	var key: String = theme if DUNGEON_THEME_POOLS.has(theme) else DEFAULT_DUNGEON_THEME
	if not has_unlock_candidates(key, tier):
		print("[ItemManager] Unlock teklifi atlandı — %s/%s havuzu tükendi" % [key, tier])
		return
	_pending_unlock_offers.append({"theme": key, "tier": tier, "picks": maxi(1, picks)})
	print("[ItemManager] Unlock teklifi kuyruğa alındı: %s/%s x%d" % [key, tier, maxi(1, picks)])


func has_pending_unlock_offers() -> bool:
	return not _pending_unlock_offers.is_empty()


## Bekleyen tüm teklifleri sırayla gösterir. Çağıran await edebilir:
##   await ItemManager.resolve_pending_unlock_offers()
func resolve_pending_unlock_offers() -> void:
	while not _pending_unlock_offers.is_empty():
		if not is_instance_valid(player):
			return  # Oyuncu yok — teklifler kuyrukta kalır, kayda yazılır
		var offer: Dictionary = _pending_unlock_offers[0]
		var picks: int = maxi(1, int(offer.get("picks", 1)))
		var theme: String = String(offer.get("theme", DEFAULT_DUNGEON_THEME))
		var tier: String = String(offer.get("tier", UNLOCK_TIER_KESIF))
		var shown_any: bool = false
		for _i in range(picks):
			if not has_unlock_candidates(theme, tier):
				break
			var ok: bool = await _show_unlock_selection(theme, tier)
			if not ok:
				break
			shown_any = true
		_pending_unlock_offers.pop_front()
		if not shown_any:
			continue
	unlock_offer_resolved.emit()


func _show_unlock_selection(theme: String, tier: String) -> bool:
	if _unlock_selection_open or _item_selection_open:
		return false
	var candidates: Array[String] = get_unlock_candidates(theme, tier)
	if candidates.is_empty():
		return false
	candidates.shuffle()
	var picked_ids: Array[String] = candidates.slice(0, mini(3, candidates.size()))

	# Kehanet: falcıya para verdiysen bir slot istediğin kategoriye yönlendirilir
	var focus: int = consume_oracle_category()
	if focus != -1 and not picked_ids.is_empty():
		for candidate_id in candidates:
			if candidate_id in picked_ids:
				continue
			if _get_item_category(candidate_id) == focus:
				picked_ids[picked_ids.size() - 1] = candidate_id
				print("[ItemManager] 🔮 Kehanet tuttu: %s" % candidate_id)
				break
	var scenes: Array[PackedScene] = []
	for id in picked_ids:
		scenes.append(ITEM_SCENES[id])

	_unlock_selection_open = true
	var selection_ui = ItemSelection.instantiate()
	get_tree().root.add_child(selection_ui)
	selection_ui.setup_unlock(scenes, picked_ids, theme, tier)
	get_tree().paused = true
	await selection_ui.tree_exited
	_unlock_selection_open = false
	return true


## --- Kayıt / sıfırlama ---

func _reset_unlocks_to_starter() -> void:
	unlocked_item_ids.clear()
	for id in STARTER_ITEM_IDS:
		if ITEM_SCENES.has(id) and id not in EXCLUDED_ITEM_IDS:
			unlocked_item_ids.append(id)


func reset_for_new_game() -> void:
	_pending_unlock_offers.clear()
	permanently_banished_ids.clear()
	oracle_category = -1
	falci_arrives_day = -1
	falci_leaves_day = -1
	_falci_present_cache = false
	_reset_unlocks_to_starter()
	refresh_falci_schedule()


func get_save_data() -> Dictionary:
	return {
		"unlocked_items": unlocked_item_ids.duplicate(),
		"pending_unlock_offers": _pending_unlock_offers.duplicate(true),
		"permanently_banished": permanently_banished_ids.duplicate(),
		"oracle_category": oracle_category,
		"falci_arrives_day": falci_arrives_day,
		"falci_leaves_day": falci_leaves_day,
	}


func load_save_data(data: Variant) -> void:
	_pending_unlock_offers.clear()
	permanently_banished_ids.clear()
	oracle_category = -1
	if not data is Dictionary:
		_reset_unlocks_to_starter()
		return
	var d: Dictionary = data as Dictionary
	var banished: Variant = d.get("permanently_banished", null)
	if banished is Array:
		for bid in (banished as Array):
			var b: String = String(bid).strip_edges()
			if ITEM_SCENES.has(b) and b not in permanently_banished_ids:
				permanently_banished_ids.append(b)
	oracle_category = int(d.get("oracle_category", -1))
	falci_arrives_day = int(d.get("falci_arrives_day", -1))
	falci_leaves_day = int(d.get("falci_leaves_day", -1))
	_falci_present_cache = is_falci_in_village()
	var raw: Variant = d.get("unlocked_items", null)
	if not (raw is Array) or (raw as Array).is_empty():
		# Unlock verisi olmayan eski kayıt: başlangıç havuzuyla başlat.
		_reset_unlocks_to_starter()
	else:
		unlocked_item_ids.clear()
		for rid in (raw as Array):
			var id: String = String(rid).strip_edges()
			if id.is_empty() or id in EXCLUDED_ITEM_IDS:
				continue
			if ITEM_SCENES.has(id) and id not in unlocked_item_ids:
				unlocked_item_ids.append(id)
	var pending: Variant = d.get("pending_unlock_offers", null)
	if pending is Array:
		for entry in (pending as Array):
			if entry is Dictionary:
				_pending_unlock_offers.append((entry as Dictionary).duplicate(true))


## Debug: her item tam bir kez atanmış mı? Liste elle tutulduğu için sapma yakalar.
func _validate_unlock_pools() -> void:
	var seen: Dictionary = {}
	var dupes: Array[String] = []
	for id in STARTER_ITEM_IDS:
		if seen.has(id):
			dupes.append(id)
		seen[id] = true
	for theme in DUNGEON_THEME_POOLS:
		for tier in [UNLOCK_TIER_KESIF, UNLOCK_TIER_BOSS]:
			for id in DUNGEON_THEME_POOLS[theme].get(tier, []):
				var sid: String = String(id)
				if seen.has(sid):
					dupes.append(sid)
				seen[sid] = true
				if not ITEM_SCENES.has(sid):
					push_warning("[ItemManager] Havuzda olup ITEM_SCENES'te olmayan item: %s (%s/%s)" % [sid, theme, tier])
	for id in _dependent_item_ids():
		seen[id] = true
	for id in EXCLUDED_ITEM_IDS:
		seen[id] = true
	var unassigned: Array[String] = []
	for id in ITEM_SCENES:
		if not seen.has(String(id)):
			unassigned.append(String(id))
	if not dupes.is_empty():
		push_warning("[ItemManager] Birden fazla havuzda geçen item: %s" % ", ".join(dupes))
	if not unassigned.is_empty():
		push_warning("[ItemManager] Hiçbir havuza atanmamış item: %s" % ", ".join(unassigned))

func _process(delta: float) -> void:
	# Scene transition sirasinda player veya item instance'i freed olabilir.
	# Typed item.process(player: CharacterBody2D, ...) cagrisi oncesi mutlaka validasyon yap.
	if not is_instance_valid(player):
		player = null
		return
	var invalid_items: Array[ItemEffect] = []
	for item in active_items:
		if not is_instance_valid(item):
			invalid_items.append(item)
			continue
		if item.has_method("process"):
			item.process(player, delta)
	for invalid_item in invalid_items:
		active_items.erase(invalid_item)

func _on_decoy_fall_attack_impacted(position: Vector2) -> void:
	# Gölge konumunda fall-attack efektini tüm ilgili itemlere uygula (hitbox aynası gibi tek noktadan)
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("apply_fall_attack_effect_at"):
			item.apply_fall_attack_effect_at(position, true)

func register_player(p: CharacterBody2D) -> void:
	# Gölge fall-attack: önceki oyuncudan disconnect (sahne değişince eski oyuncu freed olabilir)
	var old_player = player
	if is_instance_valid(old_player) and old_player.has_signal("decoy_fall_attack_impacted"):
		if old_player.is_connected("decoy_fall_attack_impacted", _on_decoy_fall_attack_impacted):
			old_player.decoy_fall_attack_impacted.disconnect(_on_decoy_fall_attack_impacted)
	if is_instance_valid(old_player) and old_player.has_signal("player_attack_landed"):
		if old_player.is_connected("player_attack_landed", _on_global_attack_landed_brawl_family):
			old_player.player_attack_landed.disconnect(_on_global_attack_landed_brawl_family)
	player = p
	if player and player.has_signal("decoy_fall_attack_impacted"):
		if not player.is_connected("decoy_fall_attack_impacted", _on_decoy_fall_attack_impacted):
			player.decoy_fall_attack_impacted.connect(_on_decoy_fall_attack_impacted)
	# Brawl ailesi sinerjisi (bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4): tek bir merkezi
	# dinleyici, item-özel değil — her item'ın kendi _on_player_attack_landed'ını yazmasına
	# gerek yok, eşik sağlandığında otomatik devreye girer.
	if player and player.has_signal("player_attack_landed"):
		if not player.is_connected("player_attack_landed", _on_global_attack_landed_brawl_family):
			player.player_attack_landed.connect(_on_global_attack_landed_brawl_family)
	# Reactivate any existing items for the new player
	for item in active_items:
		if not is_instance_valid(item):
			continue
		# Otomatik bağlanan sinyaller (_on_player_light_attack_performed, _on_perfect_parry...)
		# yalnızca _initialize_item'da, item ilk alındığında ESKİ oyuncuya bağlanıyordu. Yeni
		# sahnede yeni bir Player gelince bunlar ölü oyuncuda kalıyor, item "aktif" görünüp
		# hiçbir şey yapmıyordu (Uzun Menzil: melee hitbox kapalı + mermi hiç çıkmıyor).
		if is_instance_valid(old_player) and old_player != player:
			_rewire_item_auto_signals(item, old_player, false)
		_rewire_item_auto_signals(item, player, true)
		if item.has_method("activate"):
			item.activate(player)

## _initialize_item/deactivate_item'daki otomatik sinyal bağlantılarının tablo hâli;
## register_player (sahne değişimi) bunu kullanır. Burada değişiklik yaparsanız iki fonksiyonu da
## güncelleyin — tools/item_smoke_test.gd yeniden kayıt sonrası bağlantıları doğrular.
const AUTO_SIGNAL_HOOKS: Array = [
	["_on_player_dodged", "player_dodged"],
	["_on_player_slid", "player_slid"],
	["_on_player_blocked", "player_blocked"],
	["_on_player_attack_landed", "player_attack_landed"],
	["_on_player_light_attack_performed", "player_light_attack_performed"],
	["_on_perfect_parry", "perfect_parry"],
	["_on_player_took_damage", "player_took_damage"],
	["_on_fall_attack_impacted", "fall_attack_impacted"],
	["_on_heavy_attack_performed", "heavy_attack_performed"],
	["_on_heavy_attack_hit", "heavy_attack_hit"],
	["_on_heavy_attack_impact", "heavy_attack_impact"],
]

func _rewire_item_auto_signals(item: Node, target: Node, connect_it: bool) -> void:
	if not is_instance_valid(item) or not is_instance_valid(target):
		return
	for hook in AUTO_SIGNAL_HOOKS:
		var method: String = hook[0]
		var sig: String = hook[1]
		if not item.has_method(method) or not target.has_signal(sig):
			continue
		# Zehirli Dev heavy_attack_impact'i kendi activate() içinde bağlıyor
		if sig == "heavy_attack_impact" and item.get("item_id") == "zehirli_dev":
			continue
		var callable := Callable(item, method)
		if connect_it:
			if not target.is_connected(sig, callable):
				target.connect(sig, callable)
		elif target.is_connected(sig, callable):
			target.disconnect(sig, callable)

func activate_item(item_scene: PackedScene) -> void:
	if !player:
		push_error("[ItemManager] No player registered!")
		return
		
	var item = item_scene.instantiate() as ItemEffect
	if !item:
		push_error("[ItemManager] Failed to instantiate item")
		return
	
	# Initialize item
	_initialize_item(item)
	
	# Add to scene tree and activate
	$ActiveItems.add_child(item)
	active_items.append(item)
	item.activate(player)
	item_activated.emit(item)
	_recalculate_item_sets()
	
	print("[ItemManager] ✅ Activated: ", item.item_name)

func _initialize_item(item: ItemEffect) -> void:
	# Ensure item has access to singletons
	if !item.player_stats:
		item.player_stats = get_node("/root/PlayerStats")
	
	# Connect signals if needed
	if item.has_method("_on_player_dodged") and player.has_signal("player_dodged"):
		if !player.is_connected("player_dodged", item._on_player_dodged):
			player.connect("player_dodged", item._on_player_dodged)
	
	if item.has_method("_on_player_slid") and player.has_signal("player_slid"):
		if !player.is_connected("player_slid", item._on_player_slid):
			player.connect("player_slid", item._on_player_slid)
	
	if item.has_method("_on_player_blocked") and player.has_signal("player_blocked"):
		if !player.is_connected("player_blocked", item._on_player_blocked):
			player.connect("player_blocked", item._on_player_blocked)
	
	if item.has_method("_on_player_attack_landed") and player.has_signal("player_attack_landed"):
		if !player.is_connected("player_attack_landed", item._on_player_attack_landed):
			player.connect("player_attack_landed", item._on_player_attack_landed)
	if item.has_method("_on_player_light_attack_performed") and player.has_signal("player_light_attack_performed"):
		if !player.is_connected("player_light_attack_performed", item._on_player_light_attack_performed):
			player.connect("player_light_attack_performed", item._on_player_light_attack_performed)
	
	if item.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		if !player.is_connected("perfect_parry", item._on_perfect_parry):
			player.connect("perfect_parry", item._on_perfect_parry)
	
	if item.has_method("_on_player_took_damage") and player.has_signal("player_took_damage"):
		if !player.is_connected("player_took_damage", item._on_player_took_damage):
			player.connect("player_took_damage", item._on_player_took_damage)
	
	if item.has_method("_on_fall_attack_impacted") and player.has_signal("fall_attack_impacted"):
		if !player.is_connected("fall_attack_impacted", item._on_fall_attack_impacted):
			player.connect("fall_attack_impacted", item._on_fall_attack_impacted)
	
	if item.has_method("_on_heavy_attack_performed") and player.has_signal("heavy_attack_performed"):
		if !player.is_connected("heavy_attack_performed", item._on_heavy_attack_performed):
			player.connect("heavy_attack_performed", item._on_heavy_attack_performed)
	if item.has_method("_on_heavy_attack_hit") and player.has_signal("heavy_attack_hit"):
		if !player.is_connected("heavy_attack_hit", item._on_heavy_attack_hit):
			player.connect("heavy_attack_hit", item._on_heavy_attack_hit)
	# Zehirli Dev kendi activate() içinde heavy_attack_impact bağlıyor (register_player uyumu için)
	if item.has_method("_on_heavy_attack_impact") and player.has_signal("heavy_attack_impact") and item.get("item_id") != "zehirli_dev":
		if !player.is_connected("heavy_attack_impact", item._on_heavy_attack_impact):
			player.connect("heavy_attack_impact", item._on_heavy_attack_impact)

func deactivate_item(item: ItemEffect) -> void:
	if !player or !item:
		return
		
	# Disconnect signals
	if item.has_method("_on_player_dodged") and player.has_signal("player_dodged"):
		if player.is_connected("player_dodged", item._on_player_dodged):
			player.disconnect("player_dodged", item._on_player_dodged)
	
	if item.has_method("_on_player_slid") and player.has_signal("player_slid"):
		if player.is_connected("player_slid", item._on_player_slid):
			player.disconnect("player_slid", item._on_player_slid)
	
	if item.has_method("_on_player_blocked") and player.has_signal("player_blocked"):
		if player.is_connected("player_blocked", item._on_player_blocked):
			player.disconnect("player_blocked", item._on_player_blocked)
	
	if item.has_method("_on_player_attack_landed") and player.has_signal("player_attack_landed"):
		if player.is_connected("player_attack_landed", item._on_player_attack_landed):
			player.disconnect("player_attack_landed", item._on_player_attack_landed)
	if item.has_method("_on_player_light_attack_performed") and player.has_signal("player_light_attack_performed"):
		if player.is_connected("player_light_attack_performed", item._on_player_light_attack_performed):
			player.disconnect("player_light_attack_performed", item._on_player_light_attack_performed)
	
	if item.has_method("_on_perfect_parry") and player.has_signal("perfect_parry"):
		if player.is_connected("perfect_parry", item._on_perfect_parry):
			player.disconnect("perfect_parry", item._on_perfect_parry)
	
	if item.has_method("_on_player_took_damage") and player.has_signal("player_took_damage"):
		if player.is_connected("player_took_damage", item._on_player_took_damage):
			player.disconnect("player_took_damage", item._on_player_took_damage)
	
	if item.has_method("_on_fall_attack_impacted") and player.has_signal("fall_attack_impacted"):
		if player.is_connected("fall_attack_impacted", item._on_fall_attack_impacted):
			player.disconnect("fall_attack_impacted", item._on_fall_attack_impacted)
	
	if item.has_method("_on_heavy_attack_performed") and player.has_signal("heavy_attack_performed"):
		if player.is_connected("heavy_attack_performed", item._on_heavy_attack_performed):
			player.disconnect("heavy_attack_performed", item._on_heavy_attack_performed)
	if item.has_method("_on_heavy_attack_hit") and player.has_signal("heavy_attack_hit"):
		if player.is_connected("heavy_attack_hit", item._on_heavy_attack_hit):
			player.disconnect("heavy_attack_hit", item._on_heavy_attack_hit)
	if item.has_method("_on_heavy_attack_impact") and player.has_signal("heavy_attack_impact") and item.get("item_id") != "zehirli_dev":
		if player.is_connected("heavy_attack_impact", item._on_heavy_attack_impact):
			player.disconnect("heavy_attack_impact", item._on_heavy_attack_impact)
	
	item.deactivate(player)
	active_items.erase(item)
	item.queue_free()
	item_deactivated.emit(item)
	_recalculate_item_sets()
	
	print("[ItemManager] ❌ Deactivated: ", item.item_name)

func get_active_items() -> Array[ItemEffect]:
	return active_items

func has_active_item(item_id: String) -> bool:
	for item in active_items:
		if item and item.get("item_id") == item_id:
			return true
	return false

func clear_all_items() -> void:
	_dev_pending_selections = 0
	var current_player_valid: bool = is_instance_valid(player)
	for item in active_items.duplicate():
		if not is_instance_valid(item):
			active_items.erase(item)
			continue
		if current_player_valid:
			deactivate_item(item)
		else:
			# Player yoksa minimum guvenli temizlik: item'i dogrudan serbest birak.
			active_items.erase(item)
			item.queue_free()
	active_items.clear()
	active_item_sets.clear()
	_set_bonus_cache.clear()
	enemy_kill_count = 0  # Sonraki zindan run için sıfırla
	xp_orbs_collected = 0
	_run_banished_ids.clear()  # Tüccarın elemesi run'a özgü
	xp_orbs_collected_changed.emit(xp_orbs_collected)
	print("[ItemManager] 🗑️ All items cleared")

## Zindan/orman/test_level: ölen düşmandan bazen fiziksel altın (seviye çarpanı ile).
const ENEMY_GOLD_DROP_CHANCE_NORMAL := 0.25
const ENEMY_GOLD_DROP_CHANCE_PREMIUM := 0.50

## Daha zor türler: %50 şans, daha yüksek taban altın (çarpan aynı).
## (PackedStringArray() const ifadesi değil; düz dizi sabit kullan.)
const PREMIUM_ENEMY_PATH_MARKERS: Array[String] = [
	"heavy/",
	"summoner/",
	"canonman/",
	"firemage/",
	"hunter/",
]


func _enemy_loot_script_path(enemy: Node2D) -> String:
	var sc: Variant = enemy.get_script()
	if sc is Script:
		var rp: String = (sc as Script).resource_path
		if rp.is_empty():
			return ""
		return rp.to_lower()
	if enemy.scene_file_path:
		return str(enemy.scene_file_path).to_lower()
	return ""


func _is_turtle_enemy_for_loot(enemy: Node2D) -> bool:
	return _enemy_loot_script_path(enemy).find("turtle") != -1


func _is_summoner_spawned_flying_for_loot(enemy: Node2D) -> bool:
	# Typed class referansi (FlyingEnemy) her sahnede scope'da olmayabilir.
	# Summoner spawn kuslari zaten meta ile isaretleniyor; parser-safe kontrol.
	return bool(enemy.get_meta("summoner_summoned_bird", false))


## Ölen düşmandan oyuncuya uçan beyaz "xp" partikülü (toplanan xp'nin görsel karşılığı).
const XpOrbScene = preload("res://effects/xp_orb.tscn")

func _spawn_xp_orb(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not is_instance_valid(player):
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var orb = XpOrbScene.instantiate()
	tree.current_scene.add_child(orb)
	orb.launch(enemy.global_position, player)


const EliteCorpseScene = preload("res://effects/elite_corpse.tscn")

## Leş Gazı / Ceset Tekmesi: elit düşman öldüğünde kalıcı, etkileşilebilir ceset bırakır.
func _try_spawn_elite_corpse(enemy: Node2D) -> void:
	if not is_instance_valid(enemy):
		return
	if not (has_active_item("les_gazi") or has_active_item("ceset_tekmesi")):
		return
	if not _is_premium_enemy_for_loot(enemy):
		return
	var tree := get_tree()
	if not tree or not tree.current_scene:
		return
	var corpse = EliteCorpseScene.instantiate()
	tree.current_scene.add_child(corpse)
	corpse.global_position = enemy.global_position


func _is_premium_enemy_for_loot(enemy: Node2D) -> bool:
	var p: String = _enemy_loot_script_path(enemy)
	if p.is_empty():
		return false
	for m in PREMIUM_ENEMY_PATH_MARKERS:
		if m in p:
			return true
	return false


func _is_dungeon_like_for_loot() -> bool:
	var sm := get_node_or_null("/root/SceneManager")
	if sm:
		var cur = sm.get("current_scene_path")
		if cur:
			var cur_s := str(cur)
			var ds = sm.get("DUNGEON_SCENE")
			var fs = sm.get("FOREST_SCENE")
			if cur_s == ds or cur_s == fs:
				return true
	var scene := get_tree().current_scene
	if scene and scene.scene_file_path:
		var fp: String = scene.scene_file_path
		if "test_level" in fp or "forest" in fp:
			return true
	return false


func _find_decoration_spawner_for_loot() -> DecorationSpawner:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("decoration_spawner"):
		if n is DecorationSpawner and (n as Node).is_inside_tree():
			return n as DecorationSpawner
	return null


func _try_spawn_enemy_dungeon_gold(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not _is_dungeon_like_for_loot():
		return
	if _is_turtle_enemy_for_loot(enemy):
		return
	if _is_summoner_spawned_flying_for_loot(enemy):
		return
	var premium: bool = _is_premium_enemy_for_loot(enemy)
	var chance: float = ENEMY_GOLD_DROP_CHANCE_PREMIUM if premium else ENEMY_GOLD_DROP_CHANCE_NORMAL
	if randf() > chance:
		return
	var sp := _find_decoration_spawner_for_loot()
	if sp == null:
		return
	var base: int
	if premium:
		base = randi_range(5, 10)
	else:
		base = randi_range(1, 3)
	var total: int = sp.get_scaled_dungeon_gold(base)
	var pos: Vector2 = enemy.global_position
	sp.call_deferred("spawn_enemy_gold_burst", pos, total, premium)


# Called when an enemy is killed
func on_enemy_killed(enemy: Node2D = null) -> void:
	enemy_kill_count += 1
	_spawn_xp_orb(enemy)
	_try_spawn_enemy_dungeon_gold(enemy)
	_try_drop_expedition_loot_on_kill(enemy)
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if is_instance_valid(drs) and drs.has_method("handle_enemy_defeated") and enemy != null:
		drs.call("handle_enemy_defeated", enemy)

	# Notify items that listen to enemy kills
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("on_enemy_killed"):
			item.on_enemy_killed(enemy)

	_try_spawn_elite_corpse(enemy)


## Xp orb oyuncuya ulaştığında çağrılır (bkz. effects/xp_orb.gd). Bar ve kart seçimi
## öldürme anında değil, partikül gerçekten toplandığında güncellenir/tetiklenir.
func _on_xp_orb_collected() -> void:
	xp_orbs_collected += 1
	xp_orbs_collected_changed.emit(xp_orbs_collected)
	# Eşiğe ulaşıldı mı? Sayaç kart seçimi kapanınca sıfırlandığı için modulo yerine >= .
	if xp_orbs_collected >= KILLS_PER_ITEM and not _item_selection_open:
		await get_tree().create_timer(0.15).timeout
		show_item_selection()


const _DungeonLootDropSpawner = preload("res://interactables/dungeon/DungeonLootDropSpawner.gd")
const ENEMY_LOOT_DROP_CHANCE := 0.05
const ENEMY_LOOT_DROP_CHANCE_PREMIUM := 0.09
const MAX_EXPEDITION_LOOT_DROPS_PER_SEGMENT := 3

var _segment_expedition_loot_drops: int = 0


func reset_segment_expedition_loot_drops() -> void:
	_segment_expedition_loot_drops = 0


func _try_drop_expedition_loot_on_kill(enemy: Node2D) -> void:
	if enemy == null or not is_instance_valid(enemy):
		return
	if not _is_dungeon_like_for_loot():
		return
	if _segment_expedition_loot_drops >= MAX_EXPEDITION_LOOT_DROPS_PER_SEGMENT:
		return
	if _is_turtle_enemy_for_loot(enemy):
		return
	if _is_summoner_spawned_flying_for_loot(enemy):
		return
	var premium: bool = _is_premium_enemy_for_loot(enemy)
	var chance: float = ENEMY_LOOT_DROP_CHANCE_PREMIUM if premium else ENEMY_LOOT_DROP_CHANCE
	if randf() > chance:
		return
	var loot_type: String = _DungeonLootDropSpawner.pick_random_enemy_loot_type()
	_DungeonLootDropSpawner.spawn_expedition_loot(enemy.global_position, loot_type, 1)
	_segment_expedition_loot_drops += 1


func show_item_selection() -> void:
	if !player:
		return
	if _item_selection_open:
		return
	_item_selection_open = true
	var selection_ui = ItemSelection.instantiate()
	selection_ui.tree_exiting.connect(_on_item_selection_closed)
	get_tree().root.add_child(selection_ui)
	
	# Get random 3 items from available pool
	var available_items = get_random_items(3)
	selection_ui.setup_items(available_items)
	get_tree().paused = true

## Dev console 'levelup [n]': n kez ardışık draft ekranı. Her seçim kapanınca sıradaki açılır.
var _dev_pending_selections: int = 0

func dev_queue_item_selections(count: int) -> void:
	_dev_pending_selections = maxi(count - 1, 0)
	show_item_selection()

func _on_item_selection_closed() -> void:
	_item_selection_open = false
	if _dev_pending_selections > 0:
		_dev_pending_selections -= 1
		call_deferred("show_item_selection")
	# Ödül alındı, sayaç sıfırdan başlasın. Eskiden sayaç toplam olarak artmaya devam ettiği
	# için bar 10'da dolu kalıyor ve ancak 11. orb geldiğinde 1'e düşüyordu ("bir geriden").
	xp_orbs_collected = 0
	xp_orbs_collected_changed.emit(xp_orbs_collected)

## Bu run boyunca teklif havuzundan elenen item'lar (zindan tüccarının hizmeti).
## Run bitince clear_all_items() ile sıfırlanır — kalıcı silme falcının işi (aşağıda).
var _run_banished_ids: Array[String] = []

## FALCI (kalıcı, kayda yazılır)
## Kalıcı olarak teklif havuzundan çıkarılan item'lar. Meta-progression'ın en güçlü
## kaldıracı: gelecekteki BÜTÜN run'ların kart kalitesini yükseltir.
var permanently_banished_ids: Array[String] = []
## Kehanet: bir sonraki unlock teklifinde bir slot bu kategoriye yönlendirilir (-1 = yok).
var oracle_category: int = -1


## Falcının köy ziyaret takvimi. Kervanla gelir gibi düşünülüyor ama tüccar sistemine
## bağlanmadı: tüccar listesi kaynak/ürün satışı üzerine kurulu, falcının satacak ürünü yok
## ve ticaret arayüzünde ürünsüz bir satıcı olarak görünürdü. Takvim burada duruyor çünkü
## verdiği hizmetlerin tamamı zaten bu sınıfın state'i (kayıt da buraya bağlı).
signal falci_presence_changed(present: bool)

const FALCI_VISIT_INTERVAL_MIN: int = 6
const FALCI_VISIT_INTERVAL_MAX: int = 9
const FALCI_STAY_DAYS: int = 2

var falci_arrives_day: int = -1
var falci_leaves_day: int = -1
var _falci_present_cache: bool = false


func is_falci_in_village() -> bool:
	if falci_arrives_day < 0:
		return false
	var day: int = _current_day()
	return day >= falci_arrives_day and day < falci_leaves_day


## Gün değişiminde çağrılır: ziyaret bittiyse bir sonrakini planlar.
func refresh_falci_schedule() -> void:
	var day: int = _current_day()
	if falci_arrives_day < 0:
		_schedule_next_falci_visit(day)
	elif day >= falci_leaves_day:
		_schedule_next_falci_visit(day)
	var present: bool = is_falci_in_village()
	if present != _falci_present_cache:
		_falci_present_cache = present
		falci_presence_changed.emit(present)


func _schedule_next_falci_visit(from_day: int) -> void:
	var gap: int = randi_range(FALCI_VISIT_INTERVAL_MIN, FALCI_VISIT_INTERVAL_MAX)
	falci_arrives_day = from_day + gap
	falci_leaves_day = falci_arrives_day + FALCI_STAY_DAYS
	print("[ItemManager] 🔮 Falcı %d. günde gelecek, %d. günde gidecek" % [falci_arrives_day, falci_leaves_day])


func _current_day() -> int:
	var tm: Node = get_node_or_null("/root/TimeManager")
	if is_instance_valid(tm) and tm.has_method("get_day"):
		return int(tm.call("get_day"))
	return 0


## Dev/test: falcıyı hemen köye getirir.
func force_falci_visit_now() -> void:
	var day: int = _current_day()
	falci_arrives_day = day
	falci_leaves_day = day + FALCI_STAY_DAYS
	_falci_present_cache = true
	falci_presence_changed.emit(true)


func banish_item_permanently(item_id: String) -> bool:
	if item_id.is_empty() or not ITEM_SCENES.has(item_id):
		return false
	if item_id in permanently_banished_ids:
		return false
	permanently_banished_ids.append(item_id)
	print("[ItemManager] 🔮 Kalıcı olarak elendi: %s" % item_id)
	return true


func is_permanently_banished(item_id: String) -> bool:
	return item_id in permanently_banished_ids


## Takas edilebilir mi? Ön koşul zincirinin ebeveyni olan item takas edilemez —
## çıkarılırsa çocukları koleksiyonda ölü ağırlık olarak kalır.
func can_swap_unlocked_item(item_id: String) -> bool:
	if not is_unlocked(item_id) or item_id in STARTER_ITEM_IDS:
		return false
	for child_id in _dependent_item_ids():
		if not is_unlocked(child_id):
			continue
		if item_id in ITEM_REQUIREMENTS.get(child_id, []):
			return false
		if item_id in ITEM_REQUIREMENTS_ANY.get(child_id, []):
			# VEYA koşulu: başka bir ebeveyn hâlâ açıksa çıkarmak güvenli
			var other_parent_open: bool = false
			for parent_id in ITEM_REQUIREMENTS_ANY[child_id]:
				if String(parent_id) != item_id and is_unlocked(String(parent_id)):
					other_parent_open = true
					break
			if not other_parent_open:
				return false
	return true


## Takas: verilen item koleksiyondan çıkar, yerine aynı rarity'den rastgele kapalı bir item
## açılır. Yeni item'ın id'sini döner; takas mümkün değilse boş string.
func swap_unlocked_item(item_id: String) -> String:
	if not can_swap_unlocked_item(item_id):
		return ""
	var meta: Dictionary = get_item_meta(item_id)
	if meta.is_empty():
		return ""
	var target_rarity: int = int(meta.get("rarity", 0))
	var candidates: Array[String] = []
	for other_id in ITEM_SCENES:
		var oid: String = String(other_id)
		if is_unlocked(oid) or oid == item_id:
			continue
		if is_permanently_banished(oid) or oid in EXCLUDED_ITEM_IDS:
			continue
		if oid in _dependent_item_ids():
			continue  # Ön koşullu item'lar ebeveyniyle gelir, takasla değil
		if int(get_item_meta(oid).get("rarity", -1)) == target_rarity:
			candidates.append(oid)
	if candidates.is_empty():
		return ""
	unlocked_item_ids.erase(item_id)
	var replacement: String = candidates[randi() % candidates.size()]
	unlocked_item_ids.append(replacement)
	item_unlocked.emit(replacement)
	print("[ItemManager] 🔮 Takas: %s -> %s" % [item_id, replacement])
	return replacement


## Kehanet: sonraki unlock teklifinde bir slotu bu kategoriye yönlendirir.
func set_oracle_category(category: int) -> void:
	oracle_category = category


func consume_oracle_category() -> int:
	var c: int = oracle_category
	oracle_category = -1
	return c


func banish_item_for_run(item_id: String) -> bool:
	if item_id.is_empty() or item_id in _run_banished_ids:
		return false
	if not ITEM_SCENES.has(item_id):
		return false
	_run_banished_ids.append(item_id)
	print("[ItemManager] 🚫 Bu run boyunca teklif edilmeyecek: %s" % item_id)
	return true


func is_banished_for_run(item_id: String) -> bool:
	return item_id in _run_banished_ids


## Şu anda kart olarak teklif edilebilecek item id'leri (açık, aktif değil, ön koşulu tam,
## bu run'da elenmemiş). Hem draft hem tüccar stoğu buradan beslenir.
func get_offer_candidate_ids() -> Array[String]:
	var available_ids: Array[String] = []
	for item_id in ITEM_SCENES:
		# Koleksiyonda olmayan item run içinde teklif edilmez (bkz. UNLOCK SİSTEMİ)
		if not is_unlocked(item_id):
			continue
		# Zaten seçilmiş item tekrar çıkmasın
		if has_active_item(item_id):
			continue
		# Tüccara "bunu bir daha gösterme" dedik (bu run) / falcı kalıcı olarak eledi
		if is_banished_for_run(item_id) or is_permanently_banished(item_id):
			continue
		# Ön koşullu item: gerekli item(lar) yoksa seçenekte gösterme
		if item_id in ITEM_REQUIREMENTS:
			var reqs: Array = ITEM_REQUIREMENTS[item_id]
			var all_met := true
			for req_id in reqs:
				if not has_active_item(req_id):
					all_met = false
					break
			if not all_met:
				continue
		# VEYA ön koşulu: listedekilerden en az biri aktif olmalı
		if item_id in ITEM_REQUIREMENTS_ANY:
			var any_reqs: Array = ITEM_REQUIREMENTS_ANY[item_id]
			var any_met := false
			for req_id in any_reqs:
				if has_active_item(req_id):
					any_met = true
					break
			if not any_met:
				continue
		available_ids.append(item_id)
	return available_ids


func get_random_items(count: int = 3) -> Array[PackedScene]:
	var available_ids: Array[String] = get_offer_candidate_ids()
	available_ids.shuffle()
	var picked_ids: Array[String] = available_ids.slice(0, min(count, available_ids.size()))

	# Falcı Kadın: build'inde 2+ aynı kategoriden item varsa, %60 ihtimalle bir slotu o kategoriye yönlendir
	if has_active_item("falci_kadin") and not picked_ids.is_empty():
		var favored := _get_favored_category()
		if favored != -1 and randf() < 0.6:
			for candidate_id in available_ids:
				if candidate_id in picked_ids:
					continue
				if _get_item_category(candidate_id) == favored:
					picked_ids[0] = candidate_id
					break

	var result: Array[PackedScene] = []
	for id in picked_ids:
		result.append(ITEM_SCENES[id])
	return result

## Falcı Kadın: aktif item'lar arasında 2+ ile temsil edilen en yaygın kategoriyi döner (yoksa -1)
func _get_favored_category() -> int:
	var counts: Dictionary = {}
	for item in active_items:
		if not is_instance_valid(item):
			continue
		counts[item.category] = int(counts.get(item.category, 0)) + 1
	var best_cat := -1
	var best_count := 1
	for cat in counts:
		if int(counts[cat]) > best_count:
			best_count = int(counts[cat])
			best_cat = cat
	return best_cat

## Bir item'ın gösterim bilgisi (ad, açıklama, rarity, kategori). Sahneyi instantiate eder,
## o yüzden sadece birkaç kart için çağır — kart çekiminde değil, tüccar vitrininde.
## Ad tr() ile üretildiği için önbelleğe alınmıyor: dil değişince güncel kalsın.
func get_item_meta(item_id: String) -> Dictionary:
	if not ITEM_SCENES.has(item_id):
		return {}
	var temp = ITEM_SCENES[item_id].instantiate()
	if temp == null:
		return {}
	var meta: Dictionary = {
		"id": item_id,
		"name": String(temp.item_name),
		"description": String(temp.description),
		"rarity": int(temp.rarity),
		"category": int(temp.category),
	}
	temp.queue_free()
	return meta


## Tüccar vitrini: build'e ağırlıklı kart stoğu.
## Aktif item'larda baskın bir kategori varsa kartların bir kısmı ona yönlendirilir —
## Falcı Kadın'ın kart çekimindeki mantığının aynısı, vitrine uygulanmış hâli.
func pick_merchant_stock(count: int = 3) -> Array[String]:
	var candidates: Array[String] = get_offer_candidate_ids()
	if candidates.is_empty():
		return []
	candidates.shuffle()
	var picked: Array[String] = []
	var favored: int = _get_favored_category()
	if favored != -1:
		for id in candidates:
			if picked.size() >= maxi(1, count / 2):
				break
			if _get_item_category(id) == favored:
				picked.append(id)
	for id in candidates:
		if picked.size() >= count:
			break
		if id not in picked:
			picked.append(id)
	return picked


func _get_item_category(item_id: String) -> int:
	if not ITEM_SCENES.has(item_id):
		return -1
	var temp = ITEM_SCENES[item_id].instantiate()
	var cat: int = -1
	if temp:
		cat = temp.category
		temp.queue_free()
	return cat

func has_item(item_id: String) -> bool:
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.item_id == item_id:
			return true
	return false

# İkinci Nefes: ölüm anında çağrılır; true dönerse oyuncu 1 canla dirilir (PlayerStats canı 1 yapar)
func try_revive_player() -> bool:
	if not player:
		return false
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if item.has_method("try_revive_player") and item.try_revive_player():
			return true
	return false


func get_set_bonus(bonus_key: String, default_value: float = 1.0) -> float:
	return float(_set_bonus_cache.get(bonus_key, default_value))


func get_set_bonus_int(bonus_key: String, default_value: int = 0) -> int:
	return int(_set_bonus_cache.get(bonus_key, default_value))


## ============================================================================
## TAG SİSTEMİ — bkz. docs/ITEM_SYNERGY_DESIGN.md §10.
## Element üreten item'lar (zehirli_tirnak, atesli_yumruk, buzlu_kilic,
## simsek_parmagi ve ağır/düşüş eşdeğerleri) "elemental_poison/fire/ice/lightning"
## tag'lerini taşır. Element TÜKETEN yeni mekanikler (zehirli_sekme, element_degisimi)
## artık kendi elementini hardcode etmek yerine bu iki fonksiyonu kullanır.
## ============================================================================

## Aktif item'ların "elemental_*" tag'lerinden türetilen benzersiz element listesi.
func get_active_elements() -> Array[String]:
	var out: Array[String] = []
	for item in active_items:
		if not is_instance_valid(item):
			continue
		for t in item.tags:
			if String(t).begins_with("elemental_"):
				var el: String = String(t).trim_prefix("elemental_")
				if not out.has(el):
					out.append(el)
	return out


## Tek merkezi element uygulama noktası. "poison"/"fire"/"ice" düşmanın kendi
## add_X_stack metoduna (varsa) yönlendirilir; poison_mastery set bonusu burada
## da geçerli olsun diye zehirli_tirnak.gd ile aynı get_set_bonus okumaları
## kullanılıyor. "lightning" düşmanda kalıcı bir stack sistemine sahip değil
## (bkz. simsek_parmagi.gd — anlık zincir hasarı), bu yüzden burada da tek
## seferlik doğrudan hasar olarak uygulanıyor.
const _ELEMENT_LIGHTNING_TOUCH_DAMAGE := 5.0
const _ElementHitFlashScript = preload("res://effects/element_hit_flash.gd")
const _LightningBoltLineScript = preload("res://effects/lightning_bolt_line.gd")
const _LIGHTNING_STRIKE_HEIGHT := 260.0

func apply_element_to_enemy(enemy: Node2D, element: String) -> void:
	if not is_instance_valid(enemy):
		return
	spawn_element_hit_flash(enemy, element)
	match element:
		"poison":
			if enemy.has_method("add_poison_stack"):
				var max_stacks := 5 + get_set_bonus_int("poison_max_stacks_bonus", 0)
				var dmg_per_stack := 1.0 * get_set_bonus("poison_damage_mult", 1.0)
				enemy.add_poison_stack(max_stacks, dmg_per_stack, 2.0)
		"fire":
			if enemy.has_method("add_burn_stack"):
				enemy.add_burn_stack()
		"ice":
			if enemy.has_method("add_frost_stack"):
				enemy.add_frost_stack(1)
		"lightning":
			if enemy.has_method("take_damage"):
				enemy.take_damage(_ELEMENT_LIGHTNING_TOUCH_DAMAGE, 0.0, 0.0, true)
			_apply_lightning_reactions(enemy)
			# Şok: 1 sn stun (zehir/ateş/buz gibi şimşeğin durum etkisi)
			if is_instance_valid(enemy) and enemy.has_method("apply_shock"):
				enemy.apply_shock()
			_spawn_lightning_strike_from_above(enemy)
			# Yıldırım Zinciri: şimşeğin poison_stacks/frost_stacks gibi kalıcı bir
			# stack'i yok, bu yüzden "bu düşman şimşekle vuruldu mu" bilgisini
			# geçici bir meta işaretle tutuyoruz — enemy öldüğünde yildirim_zinciri.gd
			# bunu okuyup zincirlemeyi tetikliyor.
			if is_instance_valid(enemy):
				enemy.set_meta("was_lightning_hit", true)


## Basit placeholder görsel: element uygulanan düşmanın üstünde kısa bir
## renkli halka (bkz. effects/element_hit_flash.gd). Kalıcı sanat gelene
## kadar "element gerçekten isabet etti" bilgisini ekrana taşıyor. Public:
## zehirli_tirnak/atesli_yumruk/buzlu_kilic gibi element KAYNAĞI item'lar
## apply_element_to_enemy()'yi çağırmadan doğrudan add_X_stack() kullanıyor
## (kendi set-bonus/çift-vuruş mantıkları var), bu yüzden görseli kendileri
## ayrıca tetikliyor.
func spawn_element_hit_flash(enemy: Node2D, element: String) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null or not is_instance_valid(enemy):
		return
	var flash = Node2D.new()
	flash.set_script(_ElementHitFlashScript)
	tree.current_scene.add_child(flash)
	flash.setup(enemy.global_position, element)


## Basit placeholder görsel: şimşek isabetinde düşmanın tepesinden aşağı inen
## çentikli bir bolt çizgisi (bkz. effects/lightning_bolt_line.gd). Yıldırım
## Zinciri'nin sekmesi de aynı script'i iki düşman arasında kullanıyor.
func _spawn_lightning_strike_from_above(enemy: Node2D) -> void:
	var tree := get_tree()
	if tree == null or tree.current_scene == null or not is_instance_valid(enemy):
		return
	var bolt = Node2D.new()
	bolt.set_script(_LightningBoltLineScript)
	tree.current_scene.add_child(bolt)
	bolt.setup(enemy.global_position + Vector2(0.0, -_LIGHTNING_STRIKE_HEIGHT), enemy.global_position)


## Element Reaksiyon Matrisi (bkz. docs/ITEM_PIPELINE_DESIGN.md §3): şimşeğin
## `enemy/base_enemy.gd`'deki poison_stacks/burn_remaining_ticks/frost_stacks
## gibi kalıcı bir stack'i yok (anlık hasar) — bu yüzden buz/zehir/ateşle olan
## reaksiyonları, şimşeğin uygulandığı BU anda kontrol ediyoruz. Zehir+Ateş ve
## Ateş+Buz ve Zehir+Buz reaksiyonları bunun yerine base_enemy.gd'nin kendi
## add_burn_stack()/add_frost_stack() fonksiyonlarında (kalıcı stack'ler
## arasında, sıraya bakılmaksızın kontrol edilebildiği için) yaşıyor.
func _apply_lightning_reactions(enemy: Node2D) -> void:
	if not enemy.has_method("take_damage"):
		return
	var frost: int = int(enemy.get("frost_stacks")) if enemy.get("frost_stacks") != null else 0
	if frost > 0:
		# Buz + Şimşek = Kırılma: donmuş düşman büyük bonus hasar alır, don tüketilir
		var shatter_damage := float(frost) * 2.0
		enemy.set("frost_stacks", 0)
		enemy.take_damage(shatter_damage, 0.0, 0.0, true)
	var poison: int = int(enemy.get("poison_stacks")) if enemy.get("poison_stacks") != null else 0
	if poison > 0:
		# Zehir + Şimşek = Uçucu Zehir: biriken zehir anında patlar, stack'ler tüketilir
		var dmg_per_stack: float = float(enemy.get("poison_damage_per_stack")) if enemy.get("poison_damage_per_stack") != null else 1.0
		var burst_damage := float(poison) * dmg_per_stack * 2.0
		enemy.set("poison_stacks", 0)
		enemy.take_damage(burst_damage, 0.0, 0.0, true)
	var burn: int = int(enemy.get("burn_remaining_ticks")) if enemy.get("burn_remaining_ticks") != null else 0
	if burn > 0:
		# Ateş + Şimşek = Aşırı Yükleme: yanan düşman ekstra şok hasarı alır (en hafif ikili)
		enemy.take_damage(float(burn) * 0.5, 0.0, 0.0, true)


## ============================================================================
## HAREKET AİLESİ SİNERJİSİ — bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4.
## zehirli_sekme'nin özel davranışı (dodge/dash temas hasarı + aktif element)
## artık tek bir item'a bağlı değil: "restless_body" ailesi (3+ hareket kategorili
## item) eşiği sağlandığında da otomatik açılır. dodge_state.gd ve dash_state.gd
## bu tek fonksiyonu çağırır, mantığı kendi içlerinde tekrar etmezler.
## ============================================================================

func movement_contact_damage_enabled() -> bool:
	return has_active_item("zehirli_sekme") or active_item_sets.has("restless_body")


## Soğuk Temas (Kaçınma pipeline, bkz. docs/ITEM_PIPELINE_DESIGN.md §2.2) bu
## turdaki temas döngüsünü Zehirli Sekme/restless_body olmadan da çalıştırır.
func movement_contact_tick_enabled() -> bool:
	return movement_contact_damage_enabled() or has_active_item("soguk_temas")


## Kavis Adımı (Kaçınma pipeline): temas yarıçapını genişletir.
func get_movement_contact_radius(base_radius: float) -> float:
	if has_active_item("kavis_adimi"):
		return base_radius * 1.6
	return base_radius


## hit_ids: çağıran state'in (dodge/dash) kendi "bu hareket başına bir kez vur"
## dizisi — paylaşılmaz, her state kendi Array'ini tutar.
func apply_movement_contact_tick(hit_ids: Array, radius: float, base_damage: float) -> void:
	if not movement_contact_tick_enabled() or not is_instance_valid(player):
		return
	var tree := get_tree()
	if tree == null:
		return
	var effective_radius := get_movement_contact_radius(radius)
	var elements := get_active_elements()
	var deal_contact_damage := movement_contact_damage_enabled()
	var apply_frost := has_active_item("soguk_temas")
	var specialist_mult := get_specialist_multiplier("kacinma")
	# Fırtına Gözü (Kaçınma → Havaya Fırlatma köprüsü): temas hasarı artık
	# gerçek bir fırlatma da veriyor (60 -> 220 up_force).
	var launch_active := has_active_item("firtina_gozu")
	var contact_up_force: float = 220.0 if launch_active else 60.0
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if hit_ids.has(node.get_instance_id()):
			continue
		if player.global_position.distance_to(node.global_position) > effective_radius:
			continue
		hit_ids.append(node.get_instance_id())
		if deal_contact_damage:
			if node.has_method("take_damage"):
				node.take_damage(base_damage * specialist_mult, 80.0, contact_up_force, true)
			for element in elements:
				apply_element_to_enemy(node, element)
		if apply_frost and node.has_method("add_frost_stack"):
			node.add_frost_stack(1)


## İz Bırakan (Kaçınma pipeline, bkz. docs/ITEM_PIPELINE_DESIGN.md §2.2): dodge/dash
## yolunun tamamına küçük bir hasar taraması yapar — kalıcı bir tuzak sahnesi
## eklemek yerine, yol boyunca birkaç örnek noktada anlık bir "kılıç darbesi"
## gibi davranır. hit_ids ile aynı dodge/dash içinde bir düşmana tekrar vurmaz.
func apply_movement_trail_if_active(hit_ids: Array, start_pos: Vector2, end_pos: Vector2) -> void:
	if not has_active_item("iz_birakan"):
		return
	var tree := get_tree()
	if tree == null:
		return
	const TRAIL_SAMPLES := 4
	const TRAIL_RADIUS := 40.0
	const TRAIL_DAMAGE := 3.0
	var specialist_mult := get_specialist_multiplier("kacinma")
	for i in range(1, TRAIL_SAMPLES + 1):
		var t: float = float(i) / float(TRAIL_SAMPLES)
		var sample_pos: Vector2 = start_pos.lerp(end_pos, t)
		for node in tree.get_nodes_in_group("enemies"):
			if not is_instance_valid(node) or node.get("current_behavior") == "dead":
				continue
			if hit_ids.has(node.get_instance_id()):
				continue
			if sample_pos.distance_to(node.global_position) > TRAIL_RADIUS:
				continue
			hit_ids.append(node.get_instance_id())
			if node.has_method("take_damage"):
				node.take_damage(TRAIL_DAMAGE * specialist_mult, 0.0, 0.0, true)


## ============================================================================
## ELEMENT İZİ — bkz. docs/ITEM_PIPELINE_DESIGN.md §8.2 madde 1.
## Eskiden element_izi/dodge_zehiri/ziplama_zehiri/slide_simsegi dört ayrı item
## olarak, dört ayrı hareket fiiline (dodge/dodge/zıplama/slide) bağlı, çoğu tek
## elemente sabit olarak yazılmıştı. Tek bir "element_izi" item'ında birleştirildi;
## dodge_state.gd, dash_state.gd, jump_state.gd, slide_state.gd bu TEK fonksiyonu
## çağırır. element_izi.gd artık pasif bir işarettir, gerçek mantık burada.
## ============================================================================

const _ELEMENT_TRAIL_LIGHTNING_RADIUS := 70.0
const _ELEMENT_TRAIL_LIGHTNING_DAMAGE := 4.0
const _FirePatchScene := preload("res://effects/ground_fire_patch.tscn")
const _IcePatchScene := preload("res://effects/ground_ice_patch.tscn")
const _PoisonCloudScript := preload("res://effects/poison_cloud.gd")
const _LightningFlashScript := preload("res://effects/lightning_flash.gd")

func spawn_element_trail_if_active(pos: Vector2) -> void:
	if not has_active_item("element_izi"):
		return
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return
	for element in get_active_elements():
		match element:
			"poison":
				var cloud = Node2D.new()
				cloud.set_script(_PoisonCloudScript)
				tree.current_scene.add_child(cloud)
				cloud.global_position = pos
			"fire":
				var fire_patch = _FirePatchScene.instantiate()
				tree.current_scene.add_child(fire_patch)
				fire_patch.global_position = pos
			"ice":
				var ice_patch = _IcePatchScene.instantiate()
				tree.current_scene.add_child(ice_patch)
				ice_patch.global_position = pos
			"lightning":
				# Şimşeğin kalıcı bir zemin sahnesi yok (bkz. apply_element_to_enemy) —
				# burada da aynı "anlık, kalıcı değil" karaktere sadık kalınıyor.
				var flash = Node2D.new()
				flash.set_script(_LightningFlashScript)
				tree.current_scene.add_child(flash)
				flash.global_position = pos
				for node in tree.get_nodes_in_group("enemies"):
					if not is_instance_valid(node) or node.get("current_behavior") == "dead":
						continue
					if pos.distance_to(node.global_position) <= _ELEMENT_TRAIL_LIGHTNING_RADIUS and node.has_method("take_damage"):
						node.take_damage(_ELEMENT_TRAIL_LIGHTNING_DAMAGE, 0.0, 0.0, true)


## ============================================================================
## HAREKET/PARKUR BORU HATTI — bkz. docs/ITEM_PIPELINE_DESIGN.md §2.5.
## Duvar Kırıcı ve Rüzgâr Toplama pasif işaretlerdir; gerçek mantık burada,
## wall_slide_state.gd/ledge_grab_state.gd/slide_state.gd/jump_state.gd'nin
## dört ayrı parkur eylemi noktasından çağrılır (Kesintisiz Akrobasi bu
## merkezi fonksiyonlara ihtiyaç duymuyor — ledge_grab_state.gd doğrudan
## has_active_item ile player.enable_double_jump() çağırıyor).
## ============================================================================

const _WALL_JUMP_BURST_RADIUS := 90.0
const _WALL_JUMP_BURST_DAMAGE := 6.0

func apply_wall_jump_burst(pos: Vector2) -> void:
	if not has_active_item("duvar_kirici"):
		return
	var tree := get_tree()
	if tree == null:
		return
	var specialist_mult := get_specialist_multiplier("hareket")
	for node in tree.get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node.get("current_behavior") == "dead":
			continue
		if pos.distance_to(node.global_position) > _WALL_JUMP_BURST_RADIUS:
			continue
		if node.has_method("take_damage"):
			node.take_damage(_WALL_JUMP_BURST_DAMAGE * specialist_mult, 100.0, 60.0, true)


## Rüzgâr Toplama: her ayrı parkur eylemi (duvar zıplama/kenar tutunma/slide/
## çift zıplama) küçük bir kesirli stamina şarjı iade eder — "hiç durmadan
## hareket eden" bir build'i stamina ekonomisiyle ödüllendirir.
const _PARKOUR_MOMENTUM_RESTORE := 0.1

func apply_parkour_momentum_tick() -> void:
	if not has_active_item("ruzgar_toplama"):
		return
	var tree := get_tree()
	if tree == null:
		return
	var bar = tree.get_first_node_in_group("stamina_bar")
	if bar and bar.has_method("restore_partial_charge"):
		bar.restore_partial_charge(_PARKOUR_MOMENTUM_RESTORE * get_specialist_multiplier("hareket"))


## ============================================================================
## MERMİ ALT-DALI — bkz. docs/ITEM_PIPELINE_DESIGN.md §2.1 "Mermi alt-dalı".
## uzun_menzil/ok_yagmuru/golge_nisanci (Tetik katmanı, açıcılar) buradaki TEK
## fonksiyonu çağırır; Sürü Oku/Yansıyan Ok/Rüzgârın Nişanı/Yankı Oku/Kartal
## Bakışı/Ağır Mermi/Peşine Düşen/Ruh Mermisi (Hedef/Yük/Son-etki) hepsi pasif
## işaret, gerçek uygulama burada. Önceden uzun_menzil.gd ve ok_yagmuru.gd'de
## birbirinin aynısı iki kopya olarak duran _apply_projectile_upgrades()
## buraya taşındı — Sürü Oku'nun yelpaze-spawn'ı üçüncü bir kopya (Gölge
## Nişancı) gerektirdiği için merkezileştirmek daha az riskli hale geldi.
## ============================================================================

const _MermiProjectileScript = preload("res://effects/light_attack_projectile.gd")
const _SURU_OKU_SPREAD_DEG := 15.0
const _SURU_OKU_DAMAGE_RATIO := 0.4
const _CannonProjectileScript = preload("res://effects/cannon_projectile.gd")
const _FireBombProjectileScript = preload("res://effects/player_fire_bomb_projectile.gd")
## Mermi türleri: "ok" (light, hızlı/hafif), "top" (heavy varsayılanı, yavaş + alan hasarı + knockback),
## "bomb" (Ateş Bombası: yerçekimli, zıplar, düşmana değince patlar). Türe göre ana hasar çarpanı:
const _PROJECTILE_KIND_DAMAGE_MULT := {"ok": 1.0, "top": 1.6, "bomb": 1.3}

## scene_root: proj'un ekleneceği sahne kökü (çağıranın tree.current_scene'i).
## max_distance_override: -1.0 ise projectile'ın kendi varsayılanı korunur.
## kind: mermi türü (yukarıya bakın). double_strike: Çift Vuruş bu atış için iki volley atsın mı —
## Çift Vuruş bir HAFİF saldırı item'ı, bu yüzden sadece Uzun Menzil true geçer (ağır/fall mermileri
## eskiden yanlışlıkla iki katına çıkıyordu).
func spawn_upgraded_projectile(scene_root: Node, origin: Vector2, direction: Vector2, damage: float, max_distance_override: float = -1.0, kind: String = "ok", double_strike: bool = false) -> void:
	if not scene_root:
		return
	var directions: Array[Vector2] = [direction]
	var damage_ratio := 1.0
	if has_active_item("suru_oku"):
		directions = [
			direction.rotated(deg_to_rad(-_SURU_OKU_SPREAD_DEG)),
			direction,
			direction.rotated(deg_to_rad(_SURU_OKU_SPREAD_DEG)),
		]
		damage_ratio = _SURU_OKU_DAMAGE_RATIO
	# Not: Tek Sanat'ın "temas" çarpanı burada UYGULANMIYOR. Gelen `damage` her çağıranda
	# (uzun_menzil/ok_yagmuru/golge_nisanci) player_hitbox.enable_combo()'dan geçmiş
	# hitbox.damage'den türüyor ve çarpan orada zaten uygulanıyor; burada tekrar çarpmak
	# mermide 1.5 x 1.5 = 2.25x yapıyordu.
	# Çift Vuruş: melee'de olduğu gibi aynı saldırı 2 kez vurur. Gelen `damage`
	# zaten light_attack_damage_multiplier üzerinden Çift Vuruş'un kendi %X
	# indirimini içeriyor (attack_state.gd'nin hesapladığı değer buraya kadar
	# taşınıyor) — bu yüzden ikinci vuruşa AYRICA bir indirim uygulanmıyor,
	# tıpkı melee'nin iki vuruşunun da aynı indirimli değerde olması gibi.
	# Kullanıcı geri bildirimi (2026-09-30): "çift vuruş itemi ranged saldırıyı
	# da ikiye bölsün" — Sürü Oku'yla da çarpımsal olarak yığılabiliyor.
	var volleys := 2 if (double_strike and has_active_item("cift_vurus")) else 1
	var script: Script = _MermiProjectileScript
	match kind:
		"top":
			script = _CannonProjectileScript
		"bomb":
			script = _FireBombProjectileScript
	var kind_mult: float = _PROJECTILE_KIND_DAMAGE_MULT.get(kind, 1.0)
	for _volley in range(volleys):
		for dir in directions:
			var proj = Node2D.new()
			proj.set_script(script)
			scene_root.add_child(proj)
			proj.setup(origin, dir, damage * damage_ratio * kind_mult)
			if max_distance_override > 0.0:
				proj.max_distance = max_distance_override
			_apply_projectile_item_upgrades(proj)


func _apply_projectile_item_upgrades(proj: Node) -> void:
	if has_active_item("yansiyan_ok"):
		proj.bounce_remaining = 1
	if has_active_item("ruzgarin_nisani"):
		var RuzgarinNisani = load("res://resources/items/ruzgarin_nisani.gd")
		proj.element = RuzgarinNisani.detect_active_element(self)
	if has_active_item("yanki_oku"):
		proj.echo = true
	if has_active_item("kartal_bakisi"):
		proj.unlimited_range = true
	if has_active_item("agir_mermi"):
		proj.knockback_force = 140.0
		proj.knockback_up_force = 80.0
	if has_active_item("pesine_dusen"):
		proj.homing_strength = 2.5
	if has_active_item("ruh_mermisi"):
		proj.soul_chain = true


## ============================================================================
## WILDCARD/JOKER — bkz. docs/ITEM_PIPELINE_DESIGN.md §7.
## "Kaç FARKLI boru hattına item ekledin" (Usta İşçi) / "hangi TEK hatta
## uzmanlaştın" (Tek Sanat) sorusu, her item'ın zaten taşıdığı `category`
## alanından türetilir — item dosyalarına yeni bir alan eklemek gerekmedi.
## Kategori → hat eşlemesi çoğu item için otomatik doğru sonuç verir; 3
## istisna (toplu_kaldirma/agirliksiz/kader_ani, hepsi HEAVY_ATTACK ama
## gerçekte Havaya Fırlatma'ya ait) _PIPELINE_OVERRIDES ile düzeltiliyor.
## Mermi alt-dalı ayrı sayılmaz — doküman "Mermi ayrı bir hat değil, Temas
## Saldırısı'nın alt dalı" diyor ve zaten LIGHT_ATTACK/HEAVY_ATTACK/
## FALL_ATTACK kategorili, otomatik "temas"a düşüyor. STAMINA/SPECIAL/
## SYNERGY kategorili item'lar (düz stat item'ları, wildcard'ların kendisi)
## hiçbir hatta sayılmaz — "hangi FİİLİ değiştirdin" sorusunun cevabı yok.
## ============================================================================

const _CATEGORY_PIPELINE_MAP := {
	ItemEffect.ItemCategory.LIGHT_ATTACK: "temas",
	ItemEffect.ItemCategory.HEAVY_ATTACK: "temas",
	ItemEffect.ItemCategory.FALL_ATTACK: "temas",
	ItemEffect.ItemCategory.DODGE: "kacinma",
	ItemEffect.ItemCategory.BLOCK: "savunma",
	ItemEffect.ItemCategory.PARRY: "savunma",
	ItemEffect.ItemCategory.WALL_SLIDE: "hareket",
	ItemEffect.ItemCategory.SLIDE: "hareket",
	ItemEffect.ItemCategory.CROUCH: "hareket",
	ItemEffect.ItemCategory.JUMP: "hareket",
}
const _PIPELINE_OVERRIDES := {
	"toplu_kaldirma": "havaya",
	"agirliksiz": "havaya",
	"kader_ani": "havaya",
}

func _get_item_pipeline(item: ItemEffect) -> String:
	if _PIPELINE_OVERRIDES.has(item.item_id):
		return _PIPELINE_OVERRIDES[item.item_id]
	return _CATEGORY_PIPELINE_MAP.get(item.category, "")


## pipeline_id -> o hatta ait aktif item sayısı. Usta İşçi ve Tek Sanat'ın
## ortak veri kaynağı.
func get_pipeline_item_counts() -> Dictionary:
	var counts := {}
	for item in active_items:
		if not is_instance_valid(item):
			continue
		var pipeline := _get_item_pipeline(item)
		if pipeline == "":
			continue
		counts[pipeline] = counts.get(pipeline, 0) + 1
	return counts


func count_active_pipelines() -> int:
	return get_pipeline_item_counts().size()


## Tek Sanat: oyuncunun item'ları SADECE bir hatta toplanmışsa (başka hiçbir
## hatta item yok) ve o hatta 5+ item varsa, o hattın numeric çıktısı (hasar/
## iade miktarı) 1.5x güçlenir. Aksi halde 1.0 (no-op) — çağıran yerler bunu
## koşulsuz çarpabilir.
const TEK_SANAT_MIN_ITEMS := 5
const TEK_SANAT_MULTIPLIER := 1.5

func get_specialist_multiplier(pipeline: String) -> float:
	if not has_active_item("tek_sanat"):
		return 1.0
	var counts := get_pipeline_item_counts()
	if counts.size() != 1:
		return 1.0
	if not counts.has(pipeline) or counts[pipeline] < TEK_SANAT_MIN_ITEMS:
		return 1.0
	return TEK_SANAT_MULTIPLIER


## ============================================================================
## DÖVÜŞ AİLESİ SİNERJİSİ — bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4.
## "brawler_instinct" ailesi (4+ light/heavy/fall kategorili item) eşiği sağlandığında,
## HER isabetli vuruş (saldırı tipi fark etmeden) aktif element(ler)i uygular — oyuncunun
## "doğru" saldırı-tipi item'ını bulmasına gerek kalmaz. register_player() içinde TEK
## seferlik bağlanır, item-özel bir sinyal dinleyicisi değildir.
## ============================================================================

func _resolve_attack_target_enemy(target: Node) -> Node:
	if not is_instance_valid(target):
		return null
	if target.has_method("take_damage"):
		return target
	var p = target.get_parent()
	if p and p.has_method("take_damage"):
		return p
	if p and p.get_parent() and p.get_parent().has_method("take_damage"):
		return p.get_parent()
	return null


func _on_global_attack_landed_brawl_family(_attack_type: String, _damage: float, targets: Array, _position: Vector2, effect_filter: String = "all") -> void:
	if effect_filter == "physical_only":
		return
	if not active_item_sets.has("brawler_instinct"):
		return
	var elements := get_active_elements()
	if elements.is_empty():
		return
	for t in targets:
		var enemy := _resolve_attack_target_enemy(t)
		if enemy and is_instance_valid(enemy) and enemy.get("current_behavior") != "dead":
			for element in elements:
				apply_element_to_enemy(enemy, element)


func get_active_item_sets() -> Array[String]:
	return active_item_sets.duplicate()


func get_set_hint_if_selected(item_id: String) -> String:
	var best := ""
	for set_id in ITEM_SET_DEFINITIONS.keys():
		var def: Dictionary = ITEM_SET_DEFINITIONS[set_id]
		var members: Array = def.get("items", [])
		if not item_id in members:
			continue
		var owned := _count_owned_set_pieces(members)
		if not has_active_item(item_id):
			owned += 1
		var needed := int(def.get("pieces_for_bonus", 2))
		var set_name := tr(String(def.get("name_key", set_id)))
		if set_id in active_item_sets:
			best = "⚡ " + set_name + " — " + tr("item.set.active_short")
		elif owned >= needed:
			best = "🔗 " + set_name + " — " + tr("item.set.will_activate")
		elif owned == needed - 1:
			best = "🔗 " + set_name + " — " + tr("item.set.one_more")
	return best


## Kart üzerinde gösterilen sinerji ipuçları: [item_a, item_b, çeviri_anahtarı]. Çift yönlüdür —
## oyuncu b'ye sahipken a teklif edilirse (ya da tersi) kartta "🔗 <b'nin adı>: <etki>" satırı çıkar.
## Sadece mekanik olarak gerçekten var olan etkileşimler yazılır (docs/ITEM_PIPELINE_DESIGN.md).
## tools/item_smoke_test.gd id'lerin ve çevirilerin varlığını doğrular.
const ITEM_SYNERGY_PAIRS: Array = [
	# Çift Vuruş mermiyi de ikiye böler (spawn_upgraded_projectile volley)
	["cift_vurus", "uzun_menzil", "synergy.double_ranged"],
	["cift_vurus", "suru_oku", "synergy.double_swarm"],
	# Ateş Bombası (heavy mermi türü)
	["ates_bombasi", "suru_oku", "synergy.bomb_swarm"],
	["ates_bombasi", "ruh_mermisi", "synergy.bomb_chain"],
	["ates_bombasi", "yansiyan_ok", "synergy.bomb_chain"],
	["ates_bombasi", "ruzgarin_nisani", "synergy.bomb_element"],
	["ates_bombasi", "zehirli_tirnak", "synergy.bomb_element"],
	["ates_bombasi", "buzlu_kilic", "synergy.bomb_element"],
	["ates_bombasi", "simsek_parmagi", "synergy.bomb_element"],
	# Mermi isabeti "player_attack_landed" yayınlar: isabete bağlı item'lar mermide de çalışır
	["sarsici_darbe", "uzun_menzil", "synergy.ranged_onhit"],
	["ucuncu_vurus", "uzun_menzil", "synergy.ranged_onhit"],
	["koruk", "uzun_menzil", "synergy.ranged_onhit"],
	["zehirli_tirnak", "uzun_menzil", "synergy.ranged_element"],
	["atesli_yumruk", "uzun_menzil", "synergy.ranged_element"],
	["buzlu_kilic", "uzun_menzil", "synergy.ranged_element"],
	["simsek_parmagi", "uzun_menzil", "synergy.ranged_element"],
	["flank_avantaji", "uzun_menzil", "synergy.flank_ranged"],
	# Kaçınma -> Havaya Fırlatma
	["zehirli_sekme", "firtina_gozu", "synergy.contact_launch"],
	["zehirli_sekme", "kavis_adimi", "synergy.contact_radius"],
	["soguk_temas", "kavis_adimi", "synergy.contact_radius"],
	["firtina_gozu", "toplu_kaldirma", "synergy.contact_group"],
	# Havaya Fırlatma
	["ziplatan_yumruk", "toplu_kaldirma", "synergy.group_launch"],
	["ziplatan_yumruk", "agir_yumruk", "synergy.juggle_damage"],
	["toplu_kaldirma", "agir_yumruk", "synergy.juggle_damage"],
	["ziplatan_yumruk", "agirliksiz", "synergy.juggle_hang"],
	["ziplatan_yumruk", "yere_cakis", "synergy.launch_slam"],
	["toplu_kaldirma", "yere_cakis", "synergy.launch_slam"],
	["kader_ani", "zehirli_tirnak", "synergy.air_element"],
	["kader_ani", "atesli_yumruk", "synergy.air_element"],
	["kader_ani", "buzlu_kilic", "synergy.air_element"],
	["kader_ani", "simsek_parmagi", "synergy.air_element"],
	# Şimşek zinciri, Savunma, Hareket
	["yildirim_zinciri", "simsek_parmagi", "synergy.lightning_chain"],
	["alan_parrysi", "parry_ustasi", "synergy.parry_window"],
	["ruzgar_toplama", "kus_kanadi", "synergy.jump_stamina"],
	["ruzgar_toplama", "cift_ziplama", "synergy.jump_stamina"],
	# Element reaksiyon matrisi (6/6)
	["zehirli_tirnak", "atesli_yumruk", "synergy.react_poison_fire"],
	["atesli_yumruk", "buzlu_kilic", "synergy.react_fire_ice"],
	["zehirli_tirnak", "buzlu_kilic", "synergy.react_poison_ice"],
	["buzlu_kilic", "simsek_parmagi", "synergy.react_ice_lightning"],
	["zehirli_tirnak", "simsek_parmagi", "synergy.react_poison_lightning"],
	["atesli_yumruk", "simsek_parmagi", "synergy.react_fire_lightning"],
]


## Teklif edilen item, elindeki bir item'la birleşiyorsa tek satırlık ipucu ("" = yok).
func get_synergy_hint(item_id: String) -> String:
	for pair in ITEM_SYNERGY_PAIRS:
		var other := ""
		if pair[0] == item_id:
			other = String(pair[1])
		elif pair[1] == item_id:
			other = String(pair[0])
		else:
			continue
		if has_active_item(other):
			return "🔗 %s: %s" % [tr("item.%s.name" % other), tr(String(pair[2]))]
	return ""


func _count_owned_set_pieces(member_ids: Array) -> int:
	var n := 0
	for mid in member_ids:
		if has_active_item(String(mid)):
			n += 1
	return n


## Belirli bir tag ön ekiyle başlayan (ör. "elemental_") herhangi bir tag'i taşıyan
## aktif item sayısı. ID listesi tutmaya gerek yok — yeni bir item o tag'i taşıdığı
## an otomatik sayılır. Bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 3.
func _count_active_items_with_tag_prefix(prefix: String) -> int:
	var n := 0
	for item in active_items:
		if not is_instance_valid(item):
			continue
		for t in item.tags:
			if String(t).begins_with(prefix):
				n += 1
				break  # bir item aynı ön ekten birden fazla tag taşısa bile 1 kez sayılır
	return n


## Belirli ItemCategory değerlerinden birini taşıyan aktif item sayısı. Her item
## zaten tek bir `category`'ye sahip (item_effect.gd) — burada yeni bir alan
## eklemeye gerek yok, sadece kategoriler bir "aile" olarak gruplanıyor.
## Bkz. docs/ITEM_SYNERGY_DESIGN.md §10 Faz 4.
func _count_active_items_with_category_family(categories: Array) -> int:
	var n := 0
	for item in active_items:
		if not is_instance_valid(item):
			continue
		if categories.has(item.category):
			n += 1
	return n


func _recalculate_item_sets() -> void:
	var previous := active_item_sets.duplicate()
	active_item_sets.clear()
	_set_bonus_cache.clear()
	for set_id in ITEM_SET_DEFINITIONS.keys():
		var def: Dictionary = ITEM_SET_DEFINITIONS[set_id]
		var owned := 0
		if def.has("tag_prefix"):
			owned = _count_active_items_with_tag_prefix(String(def["tag_prefix"]))
		elif def.has("category_family"):
			owned = _count_active_items_with_category_family(def["category_family"])
		else:
			owned = _count_owned_set_pieces(def.get("items", []))
		if owned >= int(def.get("pieces_for_bonus", 2)):
			active_item_sets.append(set_id)
			var bonuses: Dictionary = def.get("bonuses", {})
			for key in bonuses.keys():
				_set_bonus_cache[key] = bonuses[key]
	for set_id in active_item_sets:
		if set_id not in previous:
			item_set_activated.emit(set_id)
			print("[ItemManager] ✨ Set aktif: ", tr(String(ITEM_SET_DEFINITIONS[set_id].get("name_key", set_id))))
	for set_id in previous:
		if set_id not in active_item_sets:
			item_set_deactivated.emit(set_id)
