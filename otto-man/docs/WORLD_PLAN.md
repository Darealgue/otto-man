# Dünya Planı: Görünür, Canlı ve Gezilebilir Dünya

> Taslak, onay bekliyor. Oluşturulma: 2026-10-16 (v0.37.18). Güncel durum: `docs/DURUM.md`.
> Bu plan `docs/LIVING_WORLD_PLAN.md` üzerine kurulur, onun yerine geçmez.

## 1. Hedef

1. Dünyada ne olup bittiği **haritada görülsün**: kim kime saldırdı, savaş nerede, kervan nereden
   nereye gidiyor.
2. Köylerin **kendi ekonomisi, ordusu ve birbirleriyle özgün ilişkisi** olsun (RimWorld hissi),
   ittifaklar köyler arasında da kurulsun.
3. Oyuncu başka bir köye **gidip gezebilsin**. Nüfusu ve ordusu büyük bir köye gece girip stealth
   ile bir şeyler çalabilsin.

## 2. Teşhis: sistem zengin ama görünmez

Koddan okuduğum haliyle (`WorldManager.gd`, `WorldMapScene.gd`):

| Konu | Şu an | Sonuç |
|---|---|---|
| Köy verisi | nüfus, erzak, güvenlik, istikrar, `economy_profile` (üretir / kıt) | Ordu ve altın yok, köyler birbirinden "sayı" olarak ayrışıyor |
| Kervanlar | `_resolve_trade_convoy`: gün tikinde tek zar atışı, anında sonuç, haber metni | Haritada hiç görünmez, yolu yok, süresi yok, yağmalanamaz |
| Köy savaşları | Diplomasi durum makinesi (`peace`, `tension`, `cold_war`, `open_war`, `ceasefire`) | Bir etiket. Ordu, cephe, kayıp, savaş yeri yok |
| Köy ittifakı | Yalnız oyuncu↔köy ittifakı var | Köyler arası ittifak yok |
| Harita işaretleri | olay ikonları, POI, haydut kampı, oyuncu birimleri | Savaş, kervan, ittifak, ilişki işareti yok |
| Haberler | Var, iyi | Hepsi metin; olayın yerine gitmek, geçmişe bakmak zor |
| Köy ziyareti | Yok. `chunks/city/` altında zengin/orta/fakir ev şablonları duruyor ama bağlı bir üretici yok | Oyuncu komşu köyü yalnızca harita menüsünden görüyor |

Yani "ne olup bittiğini göremiyorum" hissi bir cila eksiği değil, yapısal: olayların çoğu
**varlık (entity) olarak yaşamıyor**, yalnızca bir gün tikinde hesaplanıp haber olarak yazılıyor.

## 3. Kural: önce görünür yap, sonra zenginleştir, en son gezdir

Üç aşama, sırayla. Her aşamanın sonunda oyun tek başına oynanabilir kalır.

---

## AŞAMA A: Dünyayı görünür yap (en ucuz, en büyük etki)

Amaç: mevcut simülasyona dokunmadan, olayları harita üstünde yaşayan nesnelere çevirmek.

### A1. Kervanlar gerçek varlık olur (YAPILDI, v0.38.0, 2026-10-16; headless test geçti, oyunda gözle görülmedi)
Uygulama: `WorldManager.world_trade_convoys` / `world_convoy_wrecks` (kayıtta `trade_convoys`,
`convoy_wrecks`), günde 3 hex, en çok 8 aktif, yağma izi 3 gün. Çizim `WorldMapScene._draw_trade_convoys`
(araba simgesi + soluk rota, yalnız keşfedilmiş hex'ler), bilgi balonu mevcut hex tooltip'ine eklendi,
yeni tuş/panel yok. Çıkarken yağma zarı atılır (`fate_step`), yağma yolun ortasında olur.
**Bulunan hata:** eski ticaret sistemi hiç çalışmıyordu: tüm köyler ova karosuna kurulduğu için hepsi
"yiyecek üretir, taş ister" profili alıyordu ve hiç ticaret çifti çıkmıyordu. Profil artık köyün
çevresindeki (2 hex) araziden okunuyor (`economy_profile.v = 2`, eski kayıtlar yenilenir), ova köyleri
odun da istiyor. Mesafe cezası 0.025 → 0.011 hex başına (yağma ~%25).
**Kervan yağması (v0.40.0, 2026-10-16):** oyuncu kendisi yağmalayamaz, yalnız Komutan cariye
(`KIND_CONVOY`, seçenek `commander_raid_convoy`, efekt `convoy_raid`). Cariye göreve yollanırken
haritada kervanın hex'i seçilir. **v0.40.1 (kullanıcı kararı): başarı sessiz, başarısızlık ağır.**
Başarıda yük + 20 altın, kervan kalkar, iz kalır, haberde yalnız "yolda kayboldu"; çıkış köyüyle ilişki
-2, misilleme %8. Başarısızlıkta kervan yoluna devam eder ama herkes kimin yaptığını bilir: çıkış
köyüyle -12, varış köyüyle -6, haber çıkar, misilleme %70 (`world_retaliations`, 1-3 gün sonra mevcut
düşman köy baskını). Sabitler `CONVOY_RAID_*`. Kervan cariye varmadan menzile ulaşırsa ödül de ceza da yok. Oyuncunun kendisinin
yağması için sahne fikri ileride; çözülmesi gereken sorun: dövüşü sömürüp bol ganimet toplamak
(düşman seviyesi artırılarak zorlaştırılabilir).
Orijinal tasarım:
- Kervan artık anında çözülmez. `{id, sender, receiver, resource, route(hex listesi), start_day,
  eta_day, escort/güvenlik, durum}` olarak `world_trade_convoys` listesinde yaşar.
- Rota: oyuncunun yürüyüşünde kullanılan hex yol bulma mantığı (WorldMapScene'deki rota çizimi
  `_draw_path_preview` / `_draw_unit_route` ile aynı kaynaktan). Doğrulanacak: yol bulma
  `WorldManager` tarafında mı, sahnede mi.
- Gün tikinde konum ilerler. Varınca eski başarı/başarısızlık mantığı (`_apply_trade_convoy_*`)
  çalışır, ama zar artık **yolda** atılır (en riskli hex'te).
- Haritada küçük hareketli işaret + soluk rota çizgisi. Üstüne gelince: kimden kime, ne taşıyor,
  tahmini varış.
- **Oyuncu kervana saldırabilir** (baskın hedefi). Komutan cariyenin mevcut yağma mekaniği ve
  `launch_offensive_raid` ile bağlanır. Sonuç: ganimet, iki köyle ilişki düşer.
- Kayıt: `get_world_map_state` içine `world_trade_convoys` eklenir (eski kayıtta boş liste).

### A2. Savaşlar görünür olur (YAPILDI, v0.39.0, 2026-10-16; headless test geçti, oyunda gözle görülmedi)
Uygulama: `WorldMapScene._draw_war_fronts` (iki keşfedilmiş köy arasında renkli kesik çizgi, savaş/soğuk
savaşta ortada cephe işareti, baskın zincirindeki köyde alev), `WorldManager.get_visible_war_fronts`
ve `get_visible_raided_settlements`, cephe bilgi balonu mevcut hex tooltip'inde; yeni tuş/panel yok.
**Bulunan boşluk:** köyler arası ilişki kendiliğinden hiç düşmüyordu, savaş yalnız oyuncu müdahalesiyle
çıkabiliyordu. `_drift_settlement_relations` eklendi (sınır çatışması, açlık kızgınlığı, gergin çiftte
tırmanma, savaşan çiftte yıpranma). Sabitler `VILLAGE_FRICTION_*`, denge simülasyonla ayarlandı
(300 günde 1-7 savaş, ortalama 0.4-0.7 eşzamanlı), oynanmadı.
Bilinen: `raid_chain` baskını yapan köye uygulanıyor ("attacker" aslında baskına uğrayan), köy→köy
saldırı oku henüz yok, savaşın ordusu/kaybı yok (Aşama B).
Orijinal tasarım:
- `open_war` durumundaki her köy çifti arasında haritada renkli çatışma çizgisi (kırmızı
  `open_war`, turuncu `cold_war`, sarı `tension`, mavi kesikli `ceasefire`).
- Savaşın "olduğu yer": iki köyün arasında bir cephe hex'i seçilir, orada çatışma ikonu belirir,
  `war_intensity` ile büyür. Oyuncu o hex'e yaklaşınca yol riski artar (mevcut yol riski
  mantığına bağlanır).
- Saldırı olayları (köy → köy baskını) kısa süreli ok animasyonu + kalıcı "son saldırı" izi.

### A3. Olay günlüğü paneli (İPTAL, 2026-10-16)
Yapıldı ama geri alındı: Mentor'un haber ekranı (`ui/MentorBriefPopupUI.gd`, Haberler / Görevler /
Diplomasi / Savaş sekmeleri) zaten dünya haberlerini gösteriyor, ayrı bir liste ve yeni tuş
çoğaltmaydı. Ders: bu plan yazılırken o ekran hesaba katılmamıştı. Asıl eksik "listede okumak"
değil, **olayı haritada görmek**; bu yüzden A1, A2 ve A4 (haritada çizilen kervan, savaş, ilişki)
öncelikli, A3 yerine ancak istenirse Mentor haber sekmesine "haritada göster" eklenir.
Eski tasarım (artık uygulanmayacak):
- Haritada tek tuşla açılan, tarih sıralı **dünya olayları listesi**: savaş başladı, kervan
  yağmalandı, ittifak kuruldu, göç, kıtlık. Her satırda "haritada göster" (kamerayı oraya götürür).
- Filtre: sadece bildiklerim / sadece savaş / sadece ticaret.
- Mevcut haber sistemi (`_post_world_news`) kaynak olur; yeni veri modeli gerekmez, her habere
  `hex` ve `type` alanı eklenir.

### A4. İlişki ve ittifak bağları (YAPILDI, v0.41.0, 2026-10-16; headless test geçti, oyunda gözle görülmedi)
Düğme yerine her zaman görünen küçük işaretler: köyün üstünde oyuncuyla ilişki bayrağı (müttefik altın,
dostane yeşil, gergin turuncu, düşman kırmızı, nötr yok), müttefikleri bağlayan düz çizgi + kalkan
(`_draw_alliance_bonds`), köy balonunda "Müttefikleri / Savaşta" satırı. **Bulunan boşluk:** köyler arası
ittifak hiç yoktu ve ilişki pozitife gitmiyordu. Eklendi: `world_settlement_alliances` (ilişki 40'ta
kurulur, 20'nin altında bozulur, haber çıkar), dostluk sürücüsü (kervanla ısınma, ortak düşman,
tohumdan türeyen "yakın" çiftler: `VILLAGE_KINDRED_*`), simülasyonda 300 günde 1-4 ittifak.
**Henüz yok (Aşama B3):** müttefikler savaşa birlikte girmez, ittifakın ticaret/göç etkisi yok.
Orijinal tasarım (düğmeli katman fikri, uygulanmadı):
- Tek tuşla köylerin üstüne ilişki rengi (dost, nötr, düşman) ve ittifak bağları çizilir.
- Keşfedilmemiş köyler ve bilgisi olmayan olaylar **gösterilmez** (mevcut "duyum" mantığı korunur,
  ajan cariyenin değeri artar).

**A'nın bitiş ölçütü:** 10 oyun günü oyna, haritaya bakarak "son günlerde ne oldu" sorusuna
günlük paneline bakmadan cevap verebil.

**Risk:** `WorldMapScene.gd` ve `WorldManager.gd` çok büyük dosyalar (6000 satır civarı). Yeni
çizim kodunu ayrı dosyalara (`WorldMapOverlayLayer.gd`, `WorldConvoyManager.gd`) koymak şart.

---

## AŞAMA B: Köylere öz ver (ekonomi, ordu, kişilik, köyler arası ittifak)

**Durum (2026-10-16, v0.42.0): B1, B2, B4 yapıldı; B3 kısmen (ittifak var, ittifaklı savaş yok).**
Kullanıcı kararları: kişilik = 5 etiket + lider adı; ordu = savaş ve baskın gücü (müttefik ordusu birleşmez);
altın = vergi + ticaret, ordu maaşı gider; görünürlük = kaba kademe, ajan istihbaratı olan köyde gerçek sayı.
Uygulama (`WorldManager`): `_ensure_settlement_identity` (tohumdan kararlı kişilik/lider/ordu/hazine, eski kayıt
doldurulur), `PERSONALITY_TRAITS` (aggression/trade/alliance çarpanları), `_simulate_settlement_economy`
(vergi 0.10/nüfus, maaş 0.3/asker, 250 üstü harcama, 120 altında asker alımı, ödeme güçsüzlüğünde kaçak),
`_simulate_settlement_wars` (günlük %7 kayıp, savaş masrafı, ordu 3'ün altına inince ilişki +5),
`world_settlement_grudges` + `_war_reason_text` (haber gerekçesi), baskın gücü `_get_attacker_force_for_defense`
(ordunun %55'i, 3-30 arası) ve baskın kaybı ordudan düşer. Balon: `WorldMapScene` komşu köy satırları.
Simülasyon (300 gün, 4 tohum): medyan ordu 13-18, medyan hazine 160-300, birkaç köy ara sıra iflas eder; oynanmadı.
Açık: ittifak savaşa katılmıyor, köy altını harita üzerinde başka bir şeye bağlı değil (köy ziyareti/soygun C'de),
lider adları Türkçe sabit havuz (EN'de de aynı).

Amaç: köyler birbirinden gerçekten farklı olsun ve davranışlarının gerekçesi okunabilsin.

### B1. Köy verisine üç alan
`world_settlement_states` içine:
- `gold`: köy hazinesi (kervan, vergi, yağma buna işler).
- `soldiers`: ordu büyüklüğü (nüfusun bir oranı; savaş, baskın ve savunma gücünü belirler).
- `personality`: tek bir kişilik etiketi. Taslak liste: `savaşçı`, `tüccar`, `ihtiyatlı`,
  `hırslı`, `dindar`. Her kişilik 2-3 sayısal eğilim değiştirir (saldırganlık, ticaret isteği,
  ittifak isteği). Karmaşıklaştırmamak için başlangıç **5 etiket, 3 eğilim**.
- Mevcut `economy_profile` (üretir / kıt) korunur, kişilikle birlikte okunur.

### B2. Savaş ve baskın gerçek sayıya bağlanır
- Köy-köy savaşı: iki ordunun gücü karşılaştırılır, her gün/aşamada kayıp, erzak harcaması, altın
  kaybı olur. Ordusu çöken köy teslim olur ya da ateşkes ister (durum makinesine bağlanır).
- Oyuncunun köyüne baskın gücü de saldıran köyün `soldiers` değerinden gelir (şu an soyut
  `base_strength`, bkz. `WorldManager` savunma hesapları).
- Kayıplar köyün nüfusunu ve istikrarını etkiler (mevcut göç sistemi besleyici olur).

### B3. Köyler arası ittifak
- Oyuncu↔köy ittifakının köy↔köy karşılığı: `world_settlement_alliances` ("idA|idB").
- Kurulum: kişilik + ilişki + ortak düşman. Bozulma: ihanet, savaşta yardım etmeme.
- Etki: müttefik savaşa girer (cephe sayısı artar), ticaret ve göç müttefikler arasında artar.
- Oyuncunun ittifak hostility yayılımı (mevcut) köy ittifak bloklarıyla uyumlu çalışır.

### B4. Haberlerde gerekçe
- Her büyük olayın haberine "neden" satırı: "Tembel Köy ordusu zayıfladığı için ateşkes istedi."
  Bu, B'nin asıl amacı: oyuncu olayın nedenini görsün.

**B'nin bitiş ölçütü:** Aynı başlangıç tohumunda iki farklı oyun, birbirinden gözle ayırt
edilir dünya durumları (kim güçlü, kim kimle müttefik) üretir.

**Denge notu:** hazine ve ordu eklemek simülasyonu hassaslaştırır. Önce sayılar sade tutulur,
oyun içi 30 günlük hızlı simülasyon test aracı yazılır (dev console komutu: dünya X gün ilerlet,
özet dök). Böylece elle oynamadan dengesiz sonuçlar yakalanır.

---

## AŞAMA C: Başka köyü ziyaret et (en büyük parça)

Amaç: haritada bir komşu köye girince yan kaydırmalı bir köy sahnesi yüklensin; oyuncu gezsin,
konuşsun, ticaret yapsın ya da gece gizlice soygun yapsın.

### C1. Sahne üretimi: köyün sayılarından üretilir
Köyün verisi sahnenin gerçek içeriğini belirler:
- `population` → köyün uzunluğu, ev sayısı, sokaktaki NPC sayısı.
- `gold` / zenginlik → ev katmanı (mevcut `chunks/city/neighborhoods/` fakir, orta, zengin
  şablonları tam olarak buna uygun).
- `soldiers` → nöbetçi sayısı, devriye yoğunluğu.
- `personality` → görsel ton ve NPC davranışı (savaşçıda daha çok nöbetçi, tüccarda pazar).
- Köy adı + tohum → her seferinde aynı köy (sabit üretim).
Kaynak: zindan seviye üreticisinin (`level_generator.gd`) chunk birleştirme mantığı ve mevcut
`chunks/city/*` şablonları. Not: `chunks/city/` şablonları durur ama bağlı bir "şehir üreticisi"
şu an yok, yazılacak.

### C2. İki mod
1. **Barışçıl ziyaret** (ilişki iyi/nötr): yürü, NPC'lerle konuş (mevcut diyalog / LLM altyapısı),
   tüccardan al/sat, görev panosu, haber duy. Nöbetçiler tehdit değil.
2. **Gizli giriş** (gece, ya da düşman köy): `StealthManager` + `stealth_perception` (zindan için
   yazıldı, düşman tiplerine bağlı) bu sahneye uyarlanır. Nöbetçiler görüş konisi ve alarm kullanır.

### C3. Soygun hedefleri (ilk dilim)
- **Hazine odası:** altın çal (köyün `gold` değeri gerçekten düşer).
- **Erzak deposu:** erzak çal (köyün `food_stock` düşer).
- **Esir kurtar:** zindandaki kurtarma sistemini yeniden kullanır (köylü/cariye).
- (Sonraya) suikast, sabotaj, belge/haber çalma.

### C4. Sonuçlar dünyaya geri yazılır
- Fark edilmeden çıkarsan: hiçbir şey olmaz, belki ileride "gizemli hırsızlık" haberi.
- Yakalanırsan / alarm verirsen: ilişki düşer, köy `security` artar, hostile eşiği aşılırsa oyuncu
  köyüne **misilleme baskını** gelir (mevcut `_check_hostile_settlement_attacks` zinciri).
- Ordusu ve nüfusu büyük köy daha zor (daha çok nöbetçi) ama ganimeti daha yüksek: risk/ödül
  doğrudan B'deki sayılardan çıkar.

### C5. Önce dikey dilim
İlk teslim: **tek köy tipi, tek hedef** (hazine soygunu), tek giriş (gece), 4-5 chunk, 3-4 nöbetçi.
Önce bu oynanır, hissi doğrulanır, sonra çeşitlenir. C, A ve B olmadan başlamaz: ziyaret edilen
köyün üretileceği veri (`gold`, `soldiers`, `personality`) B'de oluşuyor.

**Riskler:**
- Kapsam: NPC yapay zekası, nöbet davranışı, sahne üretimi, kayıt/yükleme (köyde yarıda çıkış).
- Performans: kalabalık NPC sayısı. Sahne uzunluğu sınırlı tutulacak.
- Sanat: ev şablonları var, nöbetçi/NPC görünümü için mevcut `AppearanceDB` ve asker sprite'ları
  yeniden kullanılabilir. Yeni çizim ihtiyacı (köy giriş kapısı, hazine odası) minimumda tutulacak.
- LLM kapalıyken ziyaret edilen köy NPC'leri el yapımı diyalogla çalışmalı.

---

## 4. Önerilen sıra ve büyüklük

| Sıra | Parça | Büyüklük | Not |
|---|---|---|---|
| 1 | A1 kervanlar varlık olur | orta | A'nın çekirdeği, yağma hedefi de buradan |
| 2 | A2 savaş çizgileri / cephe | orta | |
| (iptal) | A3 olay günlüğü | | Mentor haber ekranı zaten var, bkz. A3 |
| 4 | A4 ilişki katmanı | küçük | |
| 5 | B1 + B2 köy verisi ve savaşlar | büyük | Denge test aracı ile birlikte |
| 6 | B3 + B4 köy ittifakları, gerekçeli haber | orta | |
| 7 | C dikey dilim | çok büyük | A ve B oturduktan sonra |

Her adım ayrı sürüm (MINOR: yeni sistem). Kayıt uyumluluğu: her yeni alan eski kayıtta varsayılanla
yüklenir, `SaveManager.SAVE_VERSION` değişmez.

## 5. Kapsam dışı (şimdilik bilerek)

- Köy roguelite kartları (dünya oturunca dönülecek).
- Köyler için ayrı bina/ekonomi simülasyonu (sadece `gold`, `soldiers`, `personality`).
- Oyuncunun başka köyü fethetmesi / ele geçirmesi.
- Çok oyunculu, gerçek zamanlı savaş.

## 6. Onay için sorular

1. **Fetih / köy ele geçirme** hiç olmayacak mı, yoksa ileride mi? (Plan: ileride, şimdilik yok.)
2. **Köy kişilikleri**: 5 etiketle başlamak yeterli mi, yoksa isim/lider gibi daha kişisel bir
   katman mı istiyorsun (ör. her köyün bir lideri, "muhtar" adı ve huyu)?
3. **Ziyaret erişimi**: her komşu köyü ziyaret edebilmeli mi, yoksa yalnızca ilişkisi belirli
   eşiğin üstündeki / keşfedilmiş köyler mi?
4. **Gece soygunu dışında** gündüz barışçıl ziyaret ilk dilimde de olsun mu, yoksa ilk teslim
   yalnızca gizli giriş mi?
5. **Kervan yağması**: oyuncu kervana kendisi mi saldırsın (haritada hex'e gidip), yoksa cariye
   görevi olarak mı (mevcut yağma sistemi)? İkisi de olabilir; öncelik hangisi?
6. **Başlangıç**: sıra önerisi (A3 ile başla) uygun mu?
