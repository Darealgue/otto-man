class_name VillageCardDatabase
extends RefCounted
## Köy roguelite kart sistemi — SSOT: docs/VILLAGE_ROGUELITE_CARDS.md
## Bu dosya sadece VERİ taşır (kart tanımları). Draft/seçim mantığı VillageCardManager'da.
## NOT: Kartların çoğu henüz sadece "alındı" olarak kaydediliyor — gerçek oynanış
## etkileri (mekanik kancalar) ayrı bir implementasyon turunda eklenecek.

enum Path { ESKIYA, PASA, KOYLU }

const PATH_KEYS := {
	Path.ESKIYA: "eskiya",
	Path.PASA: "pasa",
	Path.KOYLU: "koylu",
}

const PATH_NAMES := {
	"eskiya": "Eşkıya",
	"pasa": "Paşa",
	"koylu": "Köylü",
}

## Her kart: {id, path, name, desc, is_dilemma, dilemma_group, dilemma_side}
## dilemma_side sadece is_dilemma=true kartlarda anlamlı: "a" / "b"
const CARDS: Array[Dictionary] = [
	# ============ EŞKIYA — tekli kartlar ============
	{"id": "eskiya_maskeli_soyguncular", "path": "eskiya", "name": "Maskeli Soyguncular", "desc": "Yağma sonrası %50 ihtimalle ilişki düşmez.", "is_dilemma": false},
	{"id": "eskiya_golge_agi", "path": "eskiya", "name": "Gölge Ağı", "desc": "Ajan cariyenin işaretlediği hedefte garanti yüksek yağma başarısı (odaklanma cezası: sadece işaretli hedefe).", "is_dilemma": false},
	{"id": "eskiya_baraka_duzeni", "path": "eskiya", "name": "Baraka Düzeni", "desc": "Ev 4 kişi barındırır (2 yerine).", "is_dilemma": false},
	{"id": "eskiya_savasci_ruhu", "path": "eskiya", "name": "Savaşçı Ruhu", "desc": "Kayıp savaş/yağma moral düşürmez; ama 3 gün üst üste saldırı/yağma yapılmazsa moral düşer.", "is_dilemma": false},
	{"id": "eskiya_deli_cesaret", "path": "eskiya", "name": "Deli Cesaret", "desc": "Düşmandan sayıca azsan savaş gücü 2×; eşit/fazlaysan bonus yok.", "is_dilemma": false},
	{"id": "eskiya_kesik_kulak", "path": "eskiya", "name": "Kesik Kulak", "desc": "Kazanılan savaşta düşman askerinden bir kısmı kendi ordun olur; bu askerler moral cezasına daha duyarlı (büyük yenilgide ilk kaçanlar).", "is_dilemma": false},
	{"id": "eskiya_kan_borcu", "path": "eskiya", "name": "Kan Borcu", "desc": "Yağma ganimeti 2×; yağmalanan köy rastgele bir gün misilleme baskını gönderebilir.", "is_dilemma": false},
	{"id": "eskiya_talan_izni", "path": "eskiya", "name": "Talan İzni", "desc": "Askerler yağmadan otomatik kişisel pay alır → kalıcı moral bonusu, ama köy deposuna giren ganimet azalır.", "is_dilemma": false},
	{"id": "eskiya_zafer_ruzgari", "path": "eskiya", "name": "Zafer Rüzgarı", "desc": "Başarılı bir yağma sonrası belirli bir süre ordunun saldırı gücüne buff.", "is_dilemma": false},
	{"id": "eskiya_kanun_kacagi_cenneti", "path": "eskiya", "name": "Kanun Kaçağı Cenneti", "desc": "Diğer köylerden kaçak/mahkûm köylüler sığınır (bedava nüfus); ama her yeni gelen köyün genel moralini düşürür.", "is_dilemma": false},
	{"id": "eskiya_kolelik_duzeni", "path": "eskiya", "name": "Kölelik Düzeni", "desc": "Savaşta esir alınan düşmanlar ücretsiz işçi olur; moral çok düşükse kaçarlar ve giderken kaynak çalarlar.", "is_dilemma": false},
	{"id": "eskiya_silah_kacakciligi", "path": "eskiya", "name": "Silah Kaçakçılığı", "desc": "Savaş kazanınca otomatik silah ganimeti gelir; silah üretim binasına ihtiyaç azalır.", "is_dilemma": false},
	{"id": "eskiya_kurt_kardesligi", "path": "eskiya", "name": "Kurt Kardeşliği", "desc": "Yaralanan askerler ölmez, \"emekli\" olup köyde üretici işçiye döner — asker kaybı hiç tam kayıp olmaz.", "is_dilemma": false},
	{"id": "eskiya_safak_vakti_kacisi", "path": "eskiya", "name": "Şafak Vakti Kaçışı", "desc": "Kaybedilen savaşta ölüm oranı çok düşer (çoğu kaçıp kurtulur), ama moral büyük düşer (utanç).", "is_dilemma": false},
	{"id": "eskiya_ates_ve_kul", "path": "eskiya", "name": "Ateş ve Kül", "desc": "Yağmada hedefi yakma seçeneği: ganimet azalır ama o köy uzun süre çok zayıf kalır.", "is_dilemma": false},
	{"id": "eskiya_gece_baskini", "path": "eskiya", "name": "Gece Baskını", "desc": "Yağmalar sadece gece yapılabilir, başarı şansı çok yüksek; ama kendi köyünün gece savunması da aynı oranda zayıflar.", "is_dilemma": false},
	{"id": "eskiya_capulcu_sohreti", "path": "eskiya", "name": "Çapulcu Şöhreti", "desc": "Şöhret arttıkça gönüllü eşkıyalar orduna katılır; ama şöhret düşman ittifaklarını da tetikler.", "is_dilemma": false},
	{"id": "eskiya_golgede_saklanma", "path": "eskiya", "name": "Gölgede Saklanma", "desc": "Yağmada misilleme riski düşer (temkinli baskın); ama ganimet biraz azalır.", "is_dilemma": false},

	# ============ EŞKIYA — ikilemler ============
	{"id": "eskiya_dilemma_tek_vurus", "path": "eskiya", "name": "Tek Vuruş", "desc": "Aynı gün biter, sadece küçük hedefler, ganimet küçük.", "is_dilemma": true, "dilemma_group": "eskiya_baskin_tarzi", "dilemma_side": "a"},
	{"id": "eskiya_dilemma_uzun_kusatma", "path": "eskiya", "name": "Uzun Kuşatma", "desc": "Günler sürer (asker o süre meşgul), büyük hedeflere de yapılabilir, ganimet çok büyük.", "is_dilemma": true, "dilemma_group": "eskiya_baskin_tarzi", "dilemma_side": "b"},
	{"id": "eskiya_dilemma_midas_eli", "path": "eskiya", "name": "Midas'ın Eli", "desc": "Yağma direkt altın verir, hızlı likit ekonomi.", "is_dilemma": true, "dilemma_group": "eskiya_yagma_getirisi", "dilemma_side": "a"},
	{"id": "eskiya_dilemma_karaborsa", "path": "eskiya", "name": "Karaborsa", "desc": "Yağma ham/lüks eşya verir (zanaata girdi olur); satarsan aracısız pazar cezasıyla daha az altın; yavaş ama zanaat zincirini besler.", "is_dilemma": true, "dilemma_group": "eskiya_yagma_getirisi", "dilemma_side": "b"},
	{"id": "eskiya_dilemma_sadik_cete", "path": "eskiya", "name": "Sadık Çete", "desc": "Asker kaynağı sadece kendi köylülerin; kayıplarda ceza yok; yavaş büyüyen öz ordu.", "is_dilemma": true, "dilemma_group": "eskiya_asker_kaynagi", "dilemma_side": "a"},
	{"id": "eskiya_dilemma_parali_kiliclar", "path": "eskiya", "name": "Paralı Kılıçlar", "desc": "Altınla anında asker satın alınır (barınak/nüfus şartı yok); haftalık maaş ödenmezse asker sayısı azalır; hızlı ama altına bağımlı ordu.", "is_dilemma": true, "dilemma_group": "eskiya_asker_kaynagi", "dilemma_side": "b"},

	# ============ PAŞA — tekli kartlar ============
	{"id": "pasa_altin_kalkani", "path": "pasa", "name": "Altın Kalkanı", "desc": "Saldırı geldiğinde rüşvet vererek baskını iptal etme seçeneği (maliyet: raid gücüne göre altın).", "is_dilemma": false},
	{"id": "pasa_pazar_yeri", "path": "pasa", "name": "Pazar Yeri", "desc": "Oyuncu kendi pazarını kurar; tüccar ziyaretini beklemeden alım-satım yapılabilir.", "is_dilemma": false},
	{"id": "pasa_harem_siyaseti", "path": "pasa", "name": "Harem Siyaseti", "desc": "Cariye sayısı arttıkça köy morali ve görev başarı şansı kalıcı artar.", "is_dilemma": false},
	{"id": "pasa_elcilik", "path": "pasa", "name": "Elçilik", "desc": "Diplomat cariye görevleri hiç başarısız olmaz; maliyeti 2× lüks kaynak.", "is_dilemma": false},
	{"id": "pasa_altinla_gecis", "path": "pasa", "name": "Altınla Geçiş", "desc": "Haftada 1 cariye görev maliyeti, kaynak yerine altınla ödenebilir.", "is_dilemma": false},
	{"id": "pasa_sasaa_gosterisi", "path": "pasa", "name": "Şaşaa Gösterisi", "desc": "Saldırı sıklığı azalır; ama gerçek saldırı gelirse hazırlıksız yakalanma cezası.", "is_dilemma": false},
	{"id": "pasa_vergi_muafiyeti", "path": "pasa", "name": "Vergi Muafiyeti", "desc": "Seçilen 1 bina bedava kurulur.", "is_dilemma": false},
	{"id": "pasa_sadakat_yemini", "path": "pasa", "name": "Sadakat Yemini", "desc": "İşçi/asker verimi morale bağımsız sabit yüksek kalır (altınla moral sistemini bypass).", "is_dilemma": false},
	{"id": "pasa_rehin_diplomasi", "path": "pasa", "name": "Rehin Diplomasi", "desc": "Bir cariyeni komşuya gönder → o yönle sonsuza dek barış; cariye geri gelmez (kalıcı kayıp).", "is_dilemma": false},
	{"id": "pasa_sahte_skandal", "path": "pasa", "name": "Sahte Skandal", "desc": "Rakip köyün ittifakını zayıflat; başarısız olursa kendi ilişkin daha çok düşer.", "is_dilemma": false},
	{"id": "pasa_nufuz_agi", "path": "pasa", "name": "Nüfuz Ağı", "desc": "Her ittifak köy sana otomatik istihbarat sağlar (yaklaşan saldırılar önceden görünür).", "is_dilemma": false},
	{"id": "pasa_hazine_odasi", "path": "pasa", "name": "Hazine Odası", "desc": "Altın stoku saldırıda hiç yağmalanamaz; diğer kaynaklar daha savunmasız hâle gelir.", "is_dilemma": false},
	{"id": "pasa_toren_alayi", "path": "pasa", "name": "Tören Alayı", "desc": "Düzenli gösteri: moral yükselir, göçmen akışı hızlanır; her tören altın harcar.", "is_dilemma": false},
	{"id": "pasa_rusvet_agi", "path": "pasa", "name": "Rüşvet Ağı", "desc": "Rüşvet maliyeti kalıcı düşer; ama her rüşvette küçük ihtimalle \"yolsuzluk skandalı\" (moral cezası).", "is_dilemma": false},
	{"id": "pasa_tefeci_defteri", "path": "pasa", "name": "Tefeci Defteri", "desc": "Altın borç verdiğin köyler \"defterine\" yazılır; toplam alacak belli eşiği geçince tek seferlik dev geri ödeme tetiklenir.", "is_dilemma": false},
	{"id": "pasa_loncalar_vergisi", "path": "pasa", "name": "Loncalar Vergisi", "desc": "Zanaat/lüks binalarının ürettiği her birim için küçük otomatik altın (üretim vergisi) — pasif gelir.", "is_dilemma": false},
	{"id": "pasa_sahte_zenginlik", "path": "pasa", "name": "Sahte Zenginlik", "desc": "Köyün gerçek altın stoku haritada olduğundan az görünür; rakip seni zayıf sanıp daha küçük saldırı gönderir.", "is_dilemma": false},
	{"id": "pasa_suikast_parasi", "path": "pasa", "name": "Suikast Parası", "desc": "Pahalı, tek seferlik: bir düşman komutanına suikast — başarılıysa o köyün sıradaki saldırısı çok zayıflar, başarısızsa savaş ilanı.", "is_dilemma": false},
	{"id": "pasa_comert_efendi", "path": "pasa", "name": "Cömert Efendi", "desc": "Köylülere/askerlere düzenli hediye dağıt — moral kalıcı yüksek kalır, ama altın sürekli dışarı akar.", "is_dilemma": false},
	{"id": "pasa_vergi_reformu", "path": "pasa", "name": "Vergi Reformu", "desc": "Tüm bina yükseltme maliyetleri sadece altına çevrilir (kaynak istemez), ama altın ihtiyacı katlanır.", "is_dilemma": false},
	{"id": "pasa_debbag_vergisi", "path": "pasa", "name": "Debbağ Vergisi", "desc": "Köye gelen her tüccardan geçiş vergisi alınır — sadece ticaret ağın zaten aktifse anlamlı pasif gelir.", "is_dilemma": false},
	{"id": "pasa_casus_yuvasi", "path": "pasa", "name": "Casus Yuvası", "desc": "Ajan cariye görevleri daha ucuz ve daha hızlı biter (kendi \"casus okulun\").", "is_dilemma": false},
	{"id": "pasa_yabanci_misafir", "path": "pasa", "name": "Yabancı Misafir", "desc": "Düzenli aralıklarla gelen yabancı zanaatkâr, geçici olarak bir binanın üretimini 2 katına çıkarır, sonra gider.", "is_dilemma": false},
	{"id": "pasa_sirca_kosk", "path": "pasa", "name": "Sırça Köşk", "desc": "Gösterişli, üretim vermeyen bina — kalıcı moral/itibar bonusu, ama inşa maliyeti çok yüksek.", "is_dilemma": false},

	# ============ PAŞA — ikilem ============
	{"id": "pasa_dilemma_saray_fermani", "path": "pasa", "name": "Saray Fermanı", "desc": "Savunma otomatik, haftalık vergiyle; altın akışına tam bağımlı; vergi ödenmezse saray ağır ceza baskını düzenler.", "is_dilemma": true, "dilemma_group": "pasa_savunma_modeli", "dilemma_side": "a"},
	{"id": "pasa_dilemma_kendi_ordun", "path": "pasa", "name": "Kendi Ordun", "desc": "Savunma yok — kendi kışlanı kurarsın; bağımsız, ama ekonomi payı asker giderine gider; klasik savaş riski.", "is_dilemma": true, "dilemma_group": "pasa_savunma_modeli", "dilemma_side": "b"},

	# ============ KÖYLÜ — tekli kartlar ============
	{"id": "koylu_kis_ambari", "path": "koylu", "name": "Kış Ambarı", "desc": "Depo kapasitesi +%50.", "is_dilemma": false},
	{"id": "koylu_genis_tarla", "path": "koylu", "name": "Geniş Tarla", "desc": "+1 avcı kulübesi slotu veya mevcut kulübeye +2 max işçi.", "is_dilemma": false},
	{"id": "koylu_nadas_bilgisi", "path": "koylu", "name": "Nadas Bilgisi", "desc": "Toplama binaları altınsız, haftada otomatik +1 kapasite kazanır (yavaş, bedava büyüme).", "is_dilemma": false},
	{"id": "koylu_ortak_ekin", "path": "koylu", "name": "Ortak Ekin", "desc": "Bir kaynak biterse diğerinden küçük oranda otomatik \"takas\" (kıtlık tamponu).", "is_dilemma": false},
	{"id": "koylu_gocmen_kapisi", "path": "koylu", "name": "Göçmen Kapısı", "desc": "Düzenli aralıklarla yeni köylü gelir; her gelen ilk gün \"aç\" gelir (küçük yemek şoku).", "is_dilemma": false},
	{"id": "koylu_bereket_duasi", "path": "koylu", "name": "Bereket Duası", "desc": "Her gün küçük şansla bedava 1 ekstra rastgele ham kaynak.", "is_dilemma": false},
	{"id": "koylu_saray_emrinde", "path": "koylu", "name": "Saray Emrinde", "desc": "Cariyeler üretim binasına atanabilir; atanan bina +1 üretim kazanır, ama o cariye o süre görev alamaz.", "is_dilemma": false},
	{"id": "koylu_solen_gelenegi", "path": "koylu", "name": "Şölen Geleneği", "desc": "Haftada 1 şölen günü: üretim durur, tüm köy morali maksimuma çıkar ve birkaç gün yüksek kalır.", "is_dilemma": false},
	{"id": "koylu_herkes_icin_bir_sey", "path": "koylu", "name": "Herkes İçin Bir Şey", "desc": "Moral belli eşiğin üstündeyken tüm üretim binaları +1 verim.", "is_dilemma": false},
	{"id": "koylu_tas_siper", "path": "koylu", "name": "Taş Siper", "desc": "1 duvar segmenti + savunmada hafif bonus.", "is_dilemma": false},
	{"id": "koylu_ortak_kader", "path": "koylu", "name": "Ortak Kader", "desc": "Nüfus arttıkça tüm üretim otomatik hafif artar; kıtlık/şortaj cezası tek bina değil tüm köye yayılır.", "is_dilemma": false},
	{"id": "koylu_siki_disiplin", "path": "koylu", "name": "Sıkı Disiplin", "desc": "Üretim sabit bonus alır; moral tavanı düşer (asla çok yüksek coşku, ama asla çok dip de yok).", "is_dilemma": false},
	{"id": "koylu_saglam_temeller", "path": "koylu", "name": "Sağlam Temeller", "desc": "Yeni bina inşa/yükseltme maliyeti %50 ucuzlar; inşa süresi %100 uzar.", "is_dilemma": false},
	{"id": "koylu_ortaklasa_insaat", "path": "koylu", "name": "Ortaklaşa İnşaat", "desc": "Bina inşası sırasında tüm boşta köylüler yardıma koşar, inşa süresi çok kısalır.", "is_dilemma": false},
	{"id": "koylu_nesil_bilgisi", "path": "koylu", "name": "Nesil Bilgisi", "desc": "Bir bina 10+ gün kesintisiz çalışırsa \"gelenek\" oluşur, üretimi kalıcı artar — ama işçi değişince bu bonus sıfırlanır.", "is_dilemma": false},
	{"id": "koylu_emegin_karsiligi", "path": "koylu", "name": "Emeğin Karşılığı", "desc": "Köylülere düzenli pay/ücret verilir: moral kalıcı yüksek kalır, ama sürekli küçük altın gideri oluşur.", "is_dilemma": false},

	# ============ KÖYLÜ — ikilem ============
	{"id": "koylu_dilemma_kutsal_toprak", "path": "koylu", "name": "Kutsal Toprak", "desc": "Seçilen 1 ham kaynağı asla satamaz/dışarıdan alamazsın; o kaynağın üretimi kalıcı yüksek.", "is_dilemma": true, "dilemma_group": "koylu_kaynak_politikasi", "dilemma_side": "a"},
	{"id": "koylu_dilemma_acik_pazar", "path": "koylu", "name": "Açık Pazar", "desc": "Kısıt yok, esnek; nötr bonus.", "is_dilemma": true, "dilemma_group": "koylu_kaynak_politikasi", "dilemma_side": "b"},
]


static func get_card_by_id(card_id: String) -> Dictionary:
	for card in CARDS:
		if String(card.get("id", "")) == card_id:
			return card
	return {}


static func get_cards_for_path(path_key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for card in CARDS:
		if String(card.get("path", "")) == path_key:
			out.append(card)
	return out


static func get_dilemma_partner(card_id: String) -> Dictionary:
	var card: Dictionary = get_card_by_id(card_id)
	if card.is_empty() or not bool(card.get("is_dilemma", false)):
		return {}
	var group: String = String(card.get("dilemma_group", ""))
	var side: String = String(card.get("dilemma_side", ""))
	for other in CARDS:
		if String(other.get("dilemma_group", "")) == group and String(other.get("dilemma_side", "")) != side and not group.is_empty():
			return other
	return {}


static func get_path_display_name(path_key: String) -> String:
	return String(PATH_NAMES.get(path_key, path_key.capitalize()))
