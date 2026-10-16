# Köy Ziyareti Planı (Aşama C)

> Taslak, onay bekliyor. Oluşturulma: 2026-10-16 (v0.42.0). Üst plan: `docs/WORLD_PLAN.md` Aşama C.
> Dünya verisi (kişilik, lider, ordu, hazine, ilişki, ittifak, savaş) Aşama B ile hazır; bu plan onu
> oynanabilir bir sahneye çevirir.

## 1. Kullanıcı kararları (2026-10-16)

- **Erişim:** keşfedilmiş her komşu köy. Haritada köy hex'inde köy menüsünden "Köye gir".
- **Kapsam:** gündüz gezme VE gece soygunu ikisi de olacak (ilk teslimde ikisi birden istendi; aşağıda
  dilimlere bölünmüştür, her dilim kendi başına oynanır).
- **Ganimet:** hazine altını, erzak deposu, esir kurtarma. Hepsi gerçek köy verisinden düşer.
- **Yakalanma:** "kaç ya da yakalan": alarm → nöbetçiler kovalar; kaçıp çıkarsan yara + ilişki kaybı,
  yakalanırsan ganimeti ve biraz altını kaybedip köy dışına atılırsın. Köy düşman olur, misilleme gelebilir.
- Yeni tuş ya da panel yok; mevcut etkileşim (yukarı tuşu), köy menüsü ve haber/balon sistemi kullanılır.

## 1.a Netleşen kurallar (2026-10-16)

- **Alarm:** o ana kadar toplanan ganimetin **hepsi** gider, prestij kaybedilir, kervan yağması başarısızlığındaki gibi köyle
  ilişki ağır bozulur, haber çıkar, misilleme olabilir; oyuncu haritaya döner. Kovalamaca yok.
- **Ganimet ne zaman senin:** hedefi alınca değil, **köyün çıkışından çıkınca**. Yükle geri dönmek de risk.
- **Gündüz / gece:** saatten (20:00-05:00 gece). **Dost (nötr ve üstü) köy:** gündüz serbest gezme, yalnız gece gizlilik.
  **Düşman (ilişki <= -15) köy:** gündüz de gece de gizlilik; gündüz nöbetçi görüş konisi geceye göre 2.4 kat geniş (çok riskli).
- **Esir:** her köyde olabilir ama her zaman değil; savaştan sonra köyler savaş esiri tutar (`prisoners` verisi henüz yok, C2).
- **Nöbetçi:** köy askeri sprite'ı + köye göre ufak renk farkı.

## 1.c Durum

- **DÜZELTME (v0.43.1, 2026-10-16): ziyaret köyü GERÇEK köy binalarıyla kurulur**, `chunks/city` prefab'larıyla değil (o benim hatamdı: kullanılmayan
  eski dosyalardı). `VillageVisitBuildings.gd` bina sahnesini (`res://village/buildings/*.tscn`) örnekler, ekonomiye bağlı kök betiği
  ağaca girmeden kaldırır, `WorkBuildings`/`Housing` gruplarından çıkarır (VillageManager kendi köyünden saymasın); evler HouseFloorGround/Upper
  katlarıyla (kat başına 4 kişi, en çok 4 kat), kaynak binalarında seviyeye göre sprite ve çatı çarpışması, dükkân üstüne ev katı
  (ResidentialHousingExtension kalıbı). Parseller oyuncu köyündeki 22 konum (400 px arayla). Bina seçimi nüfus, zenginlik, kişilikten.
  `VisitVillager.gd`: oyuncu köyündeki gerçek Worker sahnesi "tutsak" kipinde (CampRescuedNpc kalıbı), saat düzeni ev, iş, meydan;
  binalara girer çıkar, evde biri varken pencere ışığı.
- **C0 YAPILDI (v0.43.0, 2026-10-16):** `village/visit/VillageVisitScene.tscn/.gd` + `VillageVisitLayout.gd`. Haritada köy menüsüne
  "Köyü ziyaret et", `SceneManager.change_to_village_visit`, `WorldManager.get_village_visit_info`. Düz zemin, paralaks arka plan,
  gün/gece (DayNightController), kıyı köyünde su, nüfusa göre 5-14 bina (yer tutucu: şehir prefab'ları hedef yüksekliğe küçültülüp
  zemine oturtulur), çalı/çimen/çam serpiştirme, rastgele hazine/depo (ve esir varsa zindan) binası (editörde etiketli), giriş başlığı,
  iki uçta çıkış. Oynanabilir akış (harita → köy → harita) pencereli testte doğrulandı, ekran görüntüsü alındı.
- **C2 (v0.44.0) yapıldı:** nöbetçi (VisitGuard, asker sprite + köy rengi, VisitPerception konisi, dost köyde gündüz kapalı), hedefler (çatı hazine kapağı `VillageVisitBuildings.roof_point`, depo kapısı, zindan), alarm (ganimet gider, prestij, ilişki -12, %70 misilleme), çıkışta ganimet (`WorldManager.resolve_village_heist`), savaş esiri verisi (`prisoners`). Yeni tuş/panel yok: ok ipucu, ganimet satırı ve ekran başlığı.
- **Henüz yok:** gündüz NPC etkileşimleri (konuşma, ticaret), esir/zemin çizimleri, ziyaret sırasında kayıt güvenliği.
- **Kullanıcının çizeceği:** tam çimen zemin (kıyı olmayan köy; şimdilik kıyı olmayanda zemin altı koyu yer tutucu), arka plan ve zemin
  varyasyonları (`BACKGROUND_SETS`, `GROUND_TEXTURES`), zindan, nöbetçi renk farkı.

## 1.b Kullanıcının vizyonu (2026-10-16, bu bölüm üstteki teknik taslağın yerine geçer)

Ziyaret edilen köy, oyuncunun kendi köy sahnesinin (`VillageScene`) bir varyasyonu olacak: aynı yapı (düz zemin,
kamera sınırları, gün/gece, güneş-ay, paralaks arka plan), ama:
- Deniz kenarındaki köyde ekranın altında su efekti var; deniz kenarında olmayan köy için kullanıcı tam çimen zemin
  çizimi yapacak. Arka plandaki dağlar, ağaçlar köyün çevresine göre değişecek.
- Köyün nüfusuna uygun sayıda ev ve dükkân olacak. Her şey rastgele (köy kimliğinden türeyen sabit tohumla) şekillenecek;
  kullanıcı farklı arka plan ve zemin varyasyonları çizecek, üretici çalı ve ağaç serpiştirecek (kurallar sonra konuşulacak).
- Esirler için zindan benzeri bir yapı kullanıcı tarafından çizilecek.
- Hazine odası: oyun rastgele bir binayı hazine odası seçer. Oyuncu stealth ile çatılara zıplayarak o binayı bulur,
  rehineleri kaçırır ya da depoyu soyar.
- **Alarm çalarsa görev iptal olur, oyuncu prestij kaybeder ve haritaya döner.** (Kovalamaca / yakalanma yok; yukarıdaki
  "kaç ya da yakalan" kararının yerine geçer.)
- Gece-gündüz günün saatine göre. Köyde her zaman esir olabilir ama her zaman değil: savaştan sonra köyler savaş esiri tutar.
- Nöbetçi: köy askeri sprite'ı, köye göre ufak renk değişikliği.

Teknik sonuç: orman gibi chunk üreticisi gerekmiyor; `VillageScene` yapısını kopyalayıp komut dosyasıyla dolduran bir
`VillageVisitScene` yeterli. Oyuncu köyündeki binalar (`village/buildings/*`) ekonomiye bağlı çalışan sahneler olduğu için
ziyaret köyünde kullanılamaz (kendi köyünün üretimini bozar). Onun yerine betiksiz, tek yönlü platformlu `chunks/city/neighborhoods/*`
ev prefab'ları kullanılacak (zengin, orta, fakir).

## 2. Mevcut altyapı (okunan, kullanılabilir)

| Parça | Nerede | Durum |
|---|---|---|
| Sınırlı bölge sahnesi örneği | `scenes/forest.tscn` + `levels/forest_level_generator.gd` (chunk, duvar, çıkış portalı, kamera sınırı, payload ile hex) | Kalıp olarak birebir |
| Sahne geçişi | `SceneManager.change_to_forest(payload)`, `change_to_world_map` | Yeni `change_to_village_visit` aynı kalıp |
| Stealth | `StealthManager` (segment alarmı, `alarm_raised`), `StealthPerception` (görüş konisi, şüphe), `StealthTreasureChest` | Zindan segmentine bağlı ama sahne bağımsız kullanılabilir |
| Esir kurtarma | `DoorInteraction` kurtarma odası, `MissionManager` kurtarma akışı | Köylü/cariye esir mantığı hazır |
| Asker/nöbetçi sprite | `enemy/basic` (köy askeri sprite'ıyla, v0.37.12) | Nöbetçi için aday |
| Ev sprite'ları | `assets/buildings/zengin|orta|fakir`, `chunks/city/neighborhoods/*` | **Hazır chunk değil:** tek tek bina prefab'ı (StaticBody2D, tek yönlü platformlar). Zemin, duvar, sokak yok |
| Şehir üreticisi | yok (`city_level_generator` silinmiş) | Yazılacak |
| Dünya verisi | `WorldManager.get_settlement_profile`, `world_settlement_states` | Hazır |

## 3. Teknik tasarım

**Yeni sahne** `scenes/village_visit.tscn` + `levels/village_visit_generator.gd` (forest üreticisinin sadeleşmiş kopyası):
- Sabit uzunlukta, tek sıra "sokak": sol ve sağ uçta çıkış portalı (haritaya döner), görünmez duvarlar.
- Uzunluk ve içerik köy verisinden: nüfus → bina sayısı / sokak uzunluğu, hazine → ev sınıfı (fakir, orta, zengin),
  ordu → nöbetçi sayısı, kişilik → görünüm tonu ve nöbetçi yoğunluğu (savaşçı yoğun, tüccar pazar), sabit tohum
  (köy kimliği + dünya tohumu) ile her ziyarette aynı köy.
- Bina yerleşimi: `chunks/city/neighborhoods/*` prefab'ları zemine dizilir; zemin için basit düz karo/StaticBody2D.
  Yeni sanat gerekmez; ilk teslimde yer tutucu zemin ve duvar.
- Özel yapılar: **hazine odası** (altın sandığı), **ambar** (erzak), **zindan/hücre** (esir), **meydan** (NPC'ler, pazar).

**Oyuncu girişi/çıkışı:** `WorldMapScene` köy menüsüne "Köye gir" satırı (mevcut menü); `SceneManager.change_to_village_visit`
payload: `{settlement_id, q, r, mode}`. Çıkışta `change_to_world_map` aynı hex'e, süre maliyeti (yarım gün).
Giriş modu: saat 20:00 - 05:00 arası gece, diğer saatler gündüz; mod haritadan seçilmez, saate göre belirlenir.

**Gündüz (barışçıl):**
- İlişki ≥ -14 (nötr ve üstü): nöbetçiler yürüyüş yapar, saldırmaz; sivil NPC'ler dolaşır; NPC ile konuşma
  mevcut diyalog sistemini (LLM kapalıysa el yapımı şablon) kullanır; pazar tezgâhı (mevcut tüccar arayüzü).
- İlişki düşmanca (≤ -15) ya da savaşta: nöbetçiler görünce alarm verir (gündüz gizlenemezsin), kaç ya da savaş.
- Ödül: söylenti / haber (köyün durumu, komşu savaşları), ilişki artışı (küçük hediye), ticaret.

**Gece (soygun):**
- `StealthManager` segment mantığı: `reset_for_segment()` ile alarm sıfırlanır, nöbetçiler `StealthPerception` ile görüş
  konisi ve şüphe kullanır, `raise_alarm()` bütün köyü uyarır.
- Hedefler: hazine odasından altın (köyün `gold` değerinden düşer, en çok %30'u), ambardan erzak (`food_stock`),
  hücreden esir (köylü ya da cariye, mevcut kurtarma akışı).
- Nöbetçi sayısı = `soldiers` / 4 (en az 2, en çok 12), devriye yoğunluğu kişilikten.
- Sonuç: sessiz çıkış → "gizemli hırsızlık" (ilişki -2 gibi ufak şüphe, kervan yağmasındaki ilke); alarmla çıkış →
  ilişki ağır düşer, haber çıkar, misilleme; yakalanma → ganimet kaybı + köy dışı.

**Dünyaya geri yazma:** tüm kayıplar köy durumundan düşer (altın, erzak, esir); `WorldManager.visit_loot_*` API'leri,
`CONVOY_RAID_*` benzeri sabitler; haber ve misilleme mevcut `world_retaliations` zincirine bağlanır.

## 4. Dilimler (sırayla, her biri oynanabilir)

| Dilim | İçerik | Doğrulama |
|---|---|---|
| C0 İskelet | Sahne + üretici + gir/çık, düz sokak, yer tutucu bina, köy verisinden uzunluk/bina sayısı, portal çıkışı | Haritadan gir, yürü, çık; headless sahne testi |
| C1 Gündüz | Sivil NPC'ler, nöbetçi yürüyüşü, söylenti/konuşma, ilişkiye göre düşmanlık | Dost köyde serbest, düşman köyde alarm |
| C2 Gece soygunu | Stealth nöbetçi, hazine/ambar/hücre hedefleri, alarm, kaç/yakalan sonucu | Hazineden altın düşer, alarm ilişkiyi bozar |
| C3 Cila | Kayıt güvenliği (ziyaretteyken kayıt/çıkış), ölüm akışı, çeviriler, denge | Tam akış testi |

C0 + C1 ilk büyük teslimat, C2 ikinci. Her biri ayrı sürüm.

## 5. Riskler ve açık noktalar

- **Sahne üretimi en büyük iş.** Forest üreticisi 1800+ satır, ondan yalnız sınırlı bölge kısmı alınacak.
- **Sanat:** ev sprite'ları var; zemin, çıkış kapısı, hücre, hazine odası yer tutucu olacak. Çizim ihtiyacı sonra listelenir.
- **Nöbetçi AI:** `basic_enemy` zindan chunk'larına ve `SpawnManager`'a bağlı olabilir; köy sahnesinde bağımsız çalıştırmak
  için küçük bir sarmalayıcı gerekebilir (C1'de ilk iş doğrulanacak).
- **Performans / NPC sayısı:** sokak kısa tutulur, NPC sayısı sınırlı (en çok ~12).
- **LLM kapalıyken** köy NPC'leri el yapımı satırlarla konuşmalı.
- **Oyuncu ölümü / çıkışı sırasında kayıt:** mevcut ölüm akışı yeniden kullanılır, kayıtta `scene` köy ziyareti ise haritaya dönülür.

## 6. Onay için sorular

1. **Gündüz-gece ayrımı** saat bazlı otomatik uygun mu, yoksa "bekle ve geceyi bekle" seçeneği mi istersin? (Plan: saat bazlı, bekleme kamp ateşiyle zaten var.)
2. **Hücredeki esir** her köyde olsun mu, yoksa yalnız savaşta ya da düşman köyde mi? (Plan: ordusu güçlü ve düşman köylerde olasılıkla.)
3. **Nöbetçi görünümü:** köy askeri sprite'ı yeterli mi (kavuk beyaz, kuşak kırmızı), yoksa köy kişiliğine göre renk mi?
4. İlk dilim (C0) için **yer tutucu sanatla** başlayıp sonra çizim listesi mi çıkarayım?
