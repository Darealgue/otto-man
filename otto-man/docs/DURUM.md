# Rogue Harem: Güncel Durum

> Tek doğru kaynak. Oluşturulma: 2026-10-16 (v0.37.18). Eski yol haritaları (SHIP_PLAN,
> BETA_YOL_HARITASI, project_status, BATTLE_STORY_TODO, STEALTH_SYSTEM_ROADMAP) tarihî kayıttır,
> güncel durum için burası geçerlidir. Bir şey bitince ya da kapanınca burayı güncelle.

## Çalışan çekirdek

Köy, orman, zindan, dünya haritası, kamp, challenge kapıları, kurtarma odaları, cariye harita
görevleri, köy olayları, köy savunması (oynanabilir segment), item sistemi (189 item, set
sinerjileri, gölge mekaniği), stealth, save/load, TR/EN yerelleştirme, tutorial (zindan + köy).

## Bilerek kapalı olanlar (bayraklar)

| Bayrak | Dosya | Durum | Not |
|---|---|---|---|
| `ROGUELITE_CARDS_ENABLED` | `autoload/VillageCardManager.gd` | `false` | Köy kart sistemi. Tasarım hazır: `docs/VILLAGE_ROGUELITE_CARDS.md`. Karar bekliyor, bkz. aşağı. |
| `DUNGEON_BOSS_ARENAS_ENABLED` | `scenes/level_generator.gd` | `false` | Bilerek kapalı: mini-boss (Shield Captain) iyi bir düşman ama çok hatası var. Düzeltilince açılacak. |
| `BOSS_FIGHTS_ENABLED` | `scenes/boss_room_registry.gd` | `true` | Yalnız Orb Scatter (Witch) kayıtlı. Tepegöz yorum satırında. |
| `_PREVIEW_OFFER_IN_EDITOR`, `TEST_MODE` | `AiVillagers.gd`, `AiModelDownloader.gd` | `false` | Export öncesi false kalmalı (CLAUDE.md). |

## Açık işler

### Güncel öncelik (2026-10-16): dünya haritası, dünya olayları, görselleştirme
Hedef: köylerin kendi ekonomisi, ordusu ve birbirleriyle özgün ilişkisi olsun (RimWorld gibi),
ne olup bittiği haritada görülsün, oyuncu başka köyleri ziyaret edip gezebilsin (gece stealth
soygun dahil). Plan: `docs/WORLD_PLAN.md`. A3 (ayrı olay günlüğü) denendi ve iptal edildi: Mentor haber ekranı zaten
var. A1 (kervanlar harita üstünde yürüyen varlıklar) yapıldı, v0.38.0, oyunda gözle denenmedi. Bu
sırada köy ekonomisi hatası bulundu ve düzeltildi (eskiden hiç ticaret olmuyordu). Sıradaki: A2
(savaş çizgileri), kervana saldırma.
Aşama A tamam (A1 kervan, A2 savaş çizgileri, A4 ilişki/ittifak bağları, kervan yağması v0.40.1) ve Aşama B
yapıldı (v0.42.0: köy kişiliği, lider, ordu, hazine, savaş kaybı, gerekçeli haber). Sıradaki: Aşama C (köy ziyareti),
plan `docs/VILLAGE_VISIT_PLAN.md`. C0 (köy sahnesi iskeleti: gir, gez, çık) yapıldı, v0.43.0, pencereli testte doğrulandı.
C2 yapıldı (v0.44.0): nöbetçiler + görüş konileri (VisitGuard/VisitPerception), çatı hazine kapağı, depo, zindan, alarm, ganimet çıkışta (WorldManager.resolve_village_heist), savaş esirleri. Oynanmadı, denge ve his kullanıcı testine bağlı.
v0.45.0: dost köyde gündüz köylüyle konuşma (NpcAmbientBubble balonu, köy durumuna göre söz havuzu; düşman köyde ve gece yok). Ticaret ve bilgi satın alma yapılmadı (kullanıcı seçmedi).
v0.45.1: ziyaret sırasında otomatik kayıt kapalı (SaveManager._can_autosave_now) ve duraklatma menüsünde Kaydet pasif; son kayıt haritaya girişteki kalır.
v0.46.0: müttefik savaş desteği (WorldManager._apply_war_ally_support, SETTLEMENT_ALLY_*): yardım (4 altın, 3 erzak), saldırgana kin -6/gün, soğuk savaş eşiğinde savaşa katılma; ordu birleşmez. Doğal sim'de ittifak ile savaş seyrek kesişiyor, birim testiyle doğrulandı (~13 günde katılım).
Sonra yapılacaklar (kullanıcı kararıyla ertelendi, 2026-10-16): oyuncunun kervan saldırısı (ganimet sömürüsü endişesi, kurallar önce netleşmeli), köy fethi, dost köyde ticaret ve soygun ipucu satın alma. Önce görseller.
v0.46.1: green_ground2 (kıyı olmayan köy zemini) ve bush_frontground (en ön çalılar: ölçeksiz, alt kenarı ekranın altına yapışık, kamerayla FOREGROUND_SPEED hızında kayar) entegre. Kullanıcı çizimleri kendi boyutunda kullanır, ölçekle oynama.
Kullanıcı çizimleri: kalan arka plan varyasyonları ve zindan. (Ziyarette kayıt güvenliği v0.45.1 ile yapıldı.)
A2 (köyler arası savaş çizgileri, cephe işareti, baskın alevi) da yapıldı, v0.39.0, gözle denenmedi.
Köyler arası sürtüşme eklendi, çünkü savaş kendiliğinden hiç çıkmıyordu. Sıradaki: A4 (ilişki katmanı,
köy ittifakı bağları) ya da kervana saldırma.

### Ertelenenler
- **Köy roguelite kartları:** istenen bir özellik ama köy/dünya etkileşimleri oturmadan eklemek
  karışıklık yaratır. Dünya işi bitince dönülecek.
- **Boss içeriği:** fikir ve çizim bekleniyor, bilerek ertelendi.
- **Yayın hazırlığı:** hobi tempo, şimdilik salındı.

### Yarım ya da doğrulanmamış
- **Cariye görevleri Faz 3-4:** elle doğrulanmadı. Özellik dengesi ayarsız, esir fidye arayüzü yok,
  `challenge_clear` etkisi yok. Faz 4 (imza zincirleri, yol olayları, ekip görevleri, rapor ekranı)
  başlamadı. Bkz. `docs/CONCUBINE_MAP_MISSIONS_PLAN.md`.
- **Ses:** 2 müzik parçası oyunda (besteleyen kullanıcı). Combat hook, footstep, düşman sesi
  eksik olabilir, `docs/AUDIO_MANIFEST.md` eski, doğrulanmadı.
- **Dünya haritası:** bazı karo sprite'ları çizilmedi (kodla çizilen yedek simge var), challenge'ın
  kendi simgesi yok. Yol olayları rafta.
- **Mevsim / kış döngüsü:** başlamadı.
- **NPC'lerin köy haber tahtasını okuması:** başlamadı.
- **Köy savaş simülasyonu (`village_battlesim`):** çalışıyor ama en kaba kalan parça.
- **Eski TODO'lar:** `VillageManager.gd` içinde görev ödül/ceza etkileri (yaklaşık 5540-5590) hâlâ TODO
  notlu. Eski görev sistemine ait olabilir, kullanılıyor mu doğrulanmadı.
- **Elit düşman varyantları:** ertelendi.
- **Item dengesi:** 189 item, ateş/zehir/barut genişlemesi kodlandı, denge oynanmadı. Bkz.
  `docs/ITEM_AUTHORING_GUIDE.md`.

### Yayın hazırlığı
Hobi tempo, son tarih yok. Sıra ve ayrıntı: `docs/ROAD_TO_PUBLISHED_GAME.md`. Başlanmadı: Steamworks
hesabı, mağaza görselleri, trailer, EULA, gizlilik metni, Discord. Sıradaki Next Fest Şubat 2027,
yetişmek zorunda değil.

## Dokümanlar

| Doküman | Durum |
|---|---|
| `CHANGELOG.md` | Güncel |
| `CLAUDE.md` | Güncel, release kuralları |
| `docs/ITEM_AUTHORING_GUIDE.md` | Güncel |
| `docs/CONCUBINE_MAP_MISSIONS_PLAN.md` | Güncel, Faz 4 açık |
| `docs/VILLAGE_ROGUELITE_CARDS.md` | Tasarım güncel, kod kapalı |
| `docs/SHIP_PLAN.md` | Kısmen eski, bu dosya geçerli |
| `docs/FEEDBACK_BUILD_ROADMAP.md` | Eski (2026-06) |
| `BETA_YOL_HARITASI.md`, `project_status.md`, `BATTLE_STORY_TODO.md`, `docs/STEALTH_SYSTEM_ROADMAP.md` | Eski, tarihî |
