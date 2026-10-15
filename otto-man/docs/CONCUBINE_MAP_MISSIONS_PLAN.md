# Cariye Haritadan Görevlendirme — Plan

Durum: PLAN (kod yazılmadı). Tarih: 2026-10-13.

## 1. Kararlar (kullanıcı onaylı)

1. Keşfedilmemiş / kapalı (sisli) hex'lere **yalnız Ajan** gönderilebilir.
2. Eski görev panosu sistemi **bırakılır**; yerine oyuncu-yönlendirmeli sistem gelir. Eski görev içerikleri yeniden ele alınır.
3. Yeni **haydut kampı** POI'si eklenecek (Komutan "savaşa gitme" hedefi).
4. Tüccar/diplomat etkilerinin süreli mi kalıcı mı olacağı: **açık**, Faz 3'te karar.
5. Görevlerin büyük çoğunluğu **yalnız cariyeler** tarafından yapılır (bkz. §5).
6. Esir düşme + kurtarma görevi **onaylı** (§6.3).
7. Aynı anda görevde olabilecek cariye/asker sayısında **sınır yok**; mevcut ne kadarsa gönderilebilir.
8. Mouse **yok ve olmayacak**; harita imleç/gamepad ile kalır.
9. **Sadelik ilkesi**: Yeni sistem eklenmez. Mevcut sistemlere (yaralanma, moral, esir/kurtarma, rol) bağlanan basit fikirler tercih edilir. §7'deki karmaşık öneriler iptal, yerine §7'nin yeni hali geçerli.
10. Özellikler: görevden birikmez; **cariye doğarken sabit** 1 artı + 1 eksi özellikle gelir (§7).

## 2. Akış

1. Cariye sohbeti: "Görevler" yerine/yanına **"Göreve Yolla"**.
2. Harita overlay olarak açılır, **seçim modu** (`select_mission_target` payload). Seçilebilir hex'ler vurgulanır, hover'da özet (ETA, risk).
3. Hex'e onay -> o hex + cariye rolüne göre **görev seçenekleri menüsü**.
4. **Hazırlık paneli**: asker stepper, kaynak/hediye paketi, ETA, başarı %, risk uyarısı, "Önerilen paketle gönder".
5. Onay -> `MissionManager.create_player_directed_mission(...)` -> cariye haritada rota boyunca ilerler.

Teknik kancalar (keşif raporundan):
- Seçim modu: `WorldMapScene._confirm_move_to_cursor`, `_is_blocking_world_map_ui_open`, `_draw()` vurgusu.
- Harita açma: `SceneManager.change_to_world_map` + payload.
- Hedef hex: `Mission.world_hex_key`; yeni çözümleme `_resolve_mission_target_on_world_map`.
- Asker: `ConcubineMissionPopupUI._get_available_soldiers`, `MissionManager.assign_mission_to_concubine(soldier_count)`.
- Kaynak: `VillageManager.can_afford_resources / spend_resources`.
- Not: `MissionManager.missions` karışık Mission/Dictionary içerir; yeni kodda `is Dictionary` dalı gözetilmeli.

## 3. Rol × hedef matrisi (taslak)

| Rol | Köy | Zindan | Doğa (orman/dağ/nehir) | Challenge / landmark | Haydut kampı |
|---|---|---|---|---|---|
| Ajan | İstihbarat | Sızma (stealth bonusu, garantili kurtarma şansı) | Keşif, sis açma | Ön keşif | Gözetleme (kamp zayıflığı) |
| Diplomat | Hediye, anlaşma, arabuluculuk | - | - | Mülteci/kervan müzakeresi | Pazarlık (fidye/ateşkes) |
| Tüccar | Ticaret anlaşması (kervan sıklığı) | - | Kaynak rotası | Kervan landmark | - |
| Komutan | Asker desteği/raid | Ön temizlik (zorluk düşer) | Bölge temizliği | Oyuncu görevlerini devralır (§5) | Saldırı |
| ~~Alım~~ | ROL KALDIRILDI (v0.31.5); satın alma seçeneği Tüccar'a geçti | | | | |
| Tıbbiyeci | Salgın/yardım | - | Şifalı bitki | Mülteci yardımı | - |
| Rolsüz | Basit keşif / taşıma | - | Yakın keşif | - | - |

## 4. Rota göstergeleri

- Oyuncunun `_draw_dotted_path` / `_draw_path_dot` parametreleştirilir (renk, aralık, kalınlık).
- Cariye başına **rol rengi** (oyuncununkinden ayrı). Giden: dolu nokta; dönen: soluk; yürünen kısım dolu, kalan soluk.
- Birim ikonu rol simgeli, hedef hex'te çerçeve + kalan süre.
- Seçim sırasında hover hex'e kesik çizgili **önizleme rotası** (`_refresh_path_preview` kalıbı).
- Eski `_draw_active_unit_markers` çizgi/daire/ok gösterimi kaldırılır.

## 5. Görev sahipliği: kim yapabilir?

Her görev şablonunda `executor` alanı:

| Executor | Anlamı | Örnekler |
|---|---|---|
| `CARIYE_ONLY` (çoğunluk) | Oyuncu haritada yapamaz | ajan sızma/istihbarat, diplomat hediye/anlaşma, tıbbiyeci yardım, tüccar anlaşma, alım |
| `PLAYER_OR_KOMUTAN` | Oyuncu kendisi gidebilir **veya** Komutan gönderilebilir | köylü kurtarma, dalga arenası, challenge odaları, küçük temizlik görevleri |
| `PLAYER_ONLY` | Yalnız oyuncu | zindan run'ı, boss |

Uygulama: `allow_player_map_completion` / `player_map_strategies` yalnız `PLAYER_OR_KOMUTAN` için açık kalır; `try_complete_player_missions_at_hex_with_report` rol-kilitli görevleri yok sayar. Haritada rol-kilitli hex'e oyuncu varınca "Bu iş bir cariye gerektirir (Ajan)" bilgisi.

## 6. Ödül / ceza / başarısızlık sistemi (öneri)

### 6.1 Sonuç kademeleri (tek zar yerine)
| Kademe | Koşul (zar vs. şans) | Etki |
|---|---|---|
| Büyük başarı | çok düşük zar | tam ödül + bonus (nadir eşya, +ilişki, +XP x2) |
| Başarı | şans içinde | tam ödül |
| Kıl payı | şansın biraz üstü | yarım ödül, **hafif yaralanma** veya moral -5 |
| Başarısızlık | şans üstü | ödül yok, ceza uygulanır (6.2) |
| Felaket | çok yüksek zar (düşük şansta ihtimal artar) | ağır ceza + **esir düşme** (6.3) |

### 6.2 Başarısızlık sonuçları (görev türüne göre)
- **Cariye**: `YARALI` durumu (süre = ağırlığa göre 1-3 gün, iyileşene dek görev alamaz; tıbbiyeci ile hızlanır), **moral düşüşü** (-10..-25), düşük morale "isteksiz" -> başarı şansı cezası, çok düşükte görevi reddeder.
- **Asker**: kayıp (komutan görevinde %20-60), yaralı askerler iyileşene dek kışlada devre dışı.
- **Kaynak/hediye**: kaybolur, hediye reddedilirse ilişki -.
- **Dünya**: diplomatik gaf (ilişki -), ajan yakalanırsa komşu köy güveni -, haydut kampı karşılık verir (kervan/köy olayı riski).
- **Deneyim**: başarısızlık yine de küçük XP verir ("tecrübe"), böylece zorlama yoktur.

### 6.3 Esir düşme (felaket)
Cariye haritadaki hedefte **esir** olur -> kurtarma görevi açılır (mevcut `rescue_leverage` / DUNGEON_RESCUE sistemine bağlanır). Süresi dolarsa kalıcı kayıp yerine "fidye" seçeneği (altın). Gerilim yaratır, ama ölüm yok.

### 6.4 Risk seçimi (hazırlık panelinde)
3 duruş: **Temkinli** (süre uzun, şans yüksek, ödül düşük) / **Dengeli** / **Gözü kara** (süre kısa, şans düşük, ödül yüksek, felaket ihtimali yüksek). Oyuncuya karar verdirir.

## 7. Eğlence: sade fikirler (GEÇERLİ)

Kural: yeni sistem yok, mevcut sistemlere bağlanan küçük dokunuşlar.

1. **Esir düşme + kurtarma görevi** (§6.3). Ana dramatik an. Kurtarma görevi mevcut kurtarma sistemini kullanır, esir yerinin hex'i haritada işaretlenir.
2. **Doğuştan özellikler**: Her cariye 1 artı + 1 eksi özellikle gelir, **sabit**, sonradan birikmez/değişmez. Rol (ajan/diplomat...) zaten ayrı; özellik küçük bir kişilik rötuşu. Toplam özellik havuzu ~12 (6 artı, 6 eksi), her biri tek cümleyle anlatılır ve tek bir sayıyı etkiler.
   - **İlke: özellik rolü tanımlamaz, görevin SEYRİNİ etkiler** (yolculuk, yaralanma, esirlik, moral, asker kaybı, kaynak, XP). Hangi role verilirse verilsin işe yarar; rol zaten beceri puanıyla ayrı belirlenir.
   - Artı: **Fırtına Ayaklı** (yolculuk süresi -%20), **Demir İrade** (yaralanma süresi yarı, moral az düşer), **Kurnaz** (esir düşünce %40 kendi kaçar, kurtarma görevi gerekmez), **Sevilen Komutan** (götürdüğü asker kaybı -%40), **Tutumlu** (götürdüğü kaynağın %25'i her halükarda geri döner), **Şanslı Yıldız** (Büyük başarı şansı artar), **Çabuk Öğrenir** (XP +%30).
   - Eksi: **Ürkek** (moral hızlı düşer, felaket ihtimali artar), **Kırılgan** (başarısızlıkta yaralanma ağırlaşır, süre x1.5), **Savurgan** (götürdüğü kaynak %20 fazla harcanır), **Dikbaşlı** (dönüşte moral düşükse görevi reddedebilir), **Tembel** (yolculuk süresi +%20), **Kibirli** (asker kaybı +%30), **Dert Küpü** (her başarısızlıkta köy genel morali biraz düşer).
   - Zindan kurtarmayla gelen cariyelerde de aynı: kurtarma anında özellikler rastgele atanır.
3. **Hızlı karar paketi**: Hazırlık panelinde "Önerilen paketle gönder" tek tuş (asker + hediye otomatik).
4. **Dönüş satırı**: Başarı/başarısızlık sonucu `VillageDigest` kayan satırında tek cümle ("Ayşe haydut kampından yaralı döndü"). Ayrı rapor ekranı YOK.
5. **Yara izi (küçük, kozmetik)**: Esirlikten kurtarılan cariyenin ismine küçük bir işaret/ikon eklenir, mekanik etkisi yok; hikâye hissi için.
6. ~~Risk duruşu (§6.4)~~ **İPTAL** (kullanıcı kararı: gereksiz karıştırıyor). Hazırlık paneli yalnız asker + kaynak/hediye.

Özellikler uzun oyunda sorun çıkarmaz çünkü sabit ve en fazla 2 tane; oyuncu cariyeyi seçerken "iyi/kötü kombinasyon" okur, takip edilecek bir şey birikmez.

## 7.b Eski öneriler (İPTAL, arşiv)

1. **Cariye kişiliği/özellik**: görevden doğan özellikler ("Gazi", "Kurnaz", "Ürkek"). Başarısızlıkta yara izi, başarıda unvan. Özellikler şansı/ödülü etkiler.
2. **Rol imza görevleri**: seviye atlayınca açılır, hikâye zinciri (ajan -> komşu köyde sahte kimlik, diplomat -> ittifak töreni). (FEEDBACK_BUILD_ROADMAP.md:37-38 yapılmamış maddeler.)
3. **Eşleşme/ekip**: iki cariye birlikte gönder (Komutan + Ajan = dengeli saldırı), kombinasyon bonusu.
4. **Yol olayı**: yolda %X ihtimalle seçimli küçük olay ("Haydut pususu: geç/öde/savaş"), sonucu cariyenin rolü etkiler.
5. **Rapor ekranı**: dönüşte kısa hikâyeli rapor (kimin ne yaptığı), `VillageDigest` kayan satırlarına entegre.
6. **Bölge bilgisi**: Ajanın açtığı hex'ler kalıcı keşfedilir, zindan ipuçları/tuzak bilgisi hex tooltip'ine yazılır.
7. **Köy tepkisi**: Başarı/başarısızlık köy halkı morali/itibarını etkiler (tek kaynak olmasın).
8. **Dinlenme/bakım**: Dönen cariye `DİNLENİYOR`, dinlendirilmezse yorgunluk birikir -> başarı şansı düşer. Haremde bakım seçeneği.
9. **Zorluk ölçeği**: Hex mesafesi + bölge düşmanlığı + gün sayısı ödülü ve riski büyütür; "yakın = güvenli, uzak = kazançlı".
10. **Rakip olaylar**: Aynı hedefe birden fazla köy/olay tetiklenirse süre baskısı ("fırsat 3 günde kapanır").

## 8. Fazlar

**Faz 1 — Çekirdek (KOD YAZILDI, v0.28.0, oyun içi elle doğrulanmadı)**
Dosyalar: `village/missions/DirectedMissionCatalog.gd` (rol×hedef şablonları), `worldmap/scripts/DirectedMissionController.gd`
(seçim modu + paneller), `MissionManager.get_directed_mission_options / create_player_directed_mission`,
`Mission.executor` + `player_can_complete_on_map()`, `ConcubineMissionPopupUI` "Göreve Yolla" düğmesi,
`WorldMapScene` kancaları (`_directed_mission_ctrl`). Rastgele pano `LEGACY_DAILY_BOARD_ENABLED=false`.
Bilinen eksikler: haydut kampı POI'si yok (Faz 2), özellik etkileri/esir düşme/yaralanma kademeleri yok (Faz 3),
rota renkleri eski çizim (Faz 2), zindan/kervan/challenge etkileri yalnız meta olarak işaretli (Faz 3).
- "Göreve Yolla" butonu + `ConcubineMissionPopupUI` temizliği
- Harita seçim modu + payload
- Rol→seçenek şablonları (`RoleMissionCatalog` genişler), `executor` alanı
- Hazırlık paneli (asker + kaynak/hediye + risk duruşu)
- `create_player_directed_mission`, eski rastgele üretim (`_maybe_spawn_daily_dynamic_mission`) kapatılır
- Oyuncu harita tamamlamasının rol kilidi

**Faz 2 — Rota & görsel (KOD YAZILDI, v0.29.0, oyun içi elle doğrulanmadı)**
Yapıldı: rol renkli noktalı rota (`WorldMapScene._draw_unit_route`), marker'lara `path`/`role`, seçim modunda renkli önizleme,
haydut kampı POI (`WorldManager._place_bandit_camps_on_map`, `clear_bandit_camp_at`, effect `camp_clear`, yedek kırmızı çarpı simgesi).
Eksik: kamp sprite'ı yok (geçici işaretçi), kampın haritada başka bir etkisi (tehdit/olay) yok.
- Renkli noktalı rota, önizleme, dönüş ayağı, ikonlar
- Haydut kampı POI'si (WorldManager yerleşim + tooltip + doku)

**Faz 3 — Etkiler & sonuçlar (KOD YAZILDI, v0.30.0, oyun içi elle doğrulanmadı)**
Yapıldı: 5 kademe (`MissionManager._directed_roll_tier/_directed_finish`), yaralanma + günlük toparlanma, esirlik (`Concubine.Status.ESIR`)
ve `rescue_captive_<id>` kurtarma görevi (baskın/fidye/Komutan), doğuştan özellikler (`Concubine.get_trait_pos/neg`, kimlikten türetilir),
süreli etkiler 10 gün: tüccar kervan x2 (`directed_state`, VillageManager), ajan sızması garanti kurtarma, komutan temizliği -2 düşman
(`WorldManager.set_dungeon_directed_effect`, `DungeonRunState.start_run_from_village`), kayıt: `mm_directed_state`, `Concubine.to_dict`.
Eksik: challenge_clear etkisi, esirin fidye UI'ı yok (oyuncu haritada hex'e gidip strateji seçer), özellik dengesi ayarsız.
- Kademeli sonuç sistemi (§6.1), yaralanma/moral/esir
- Ajan->zindan (`DungeonRunState.start_run_from_village`, `stealth_clear`, `guaranteed_rescue_next`)
- Diplomat->`DiplomacyManager`, Tüccar->kervan sıklığı (`VillageManager.gd:6755`), Komutan->zorluk düşürme
- Etki süresi kararı (süreli/kalıcı)

**Faz 4 — Derinlik**
- Özellikler, imza görev zincirleri, yol olayları, ekip görevleri, geri çağırma, rapor ekranı

## 9. Proje kuralları (CLAUDE.md)
- Her değişiklikte CHANGELOG.md + versiyon (project.godot + export_presets).
- Yeni metinler `strings.csv` TR+EN, sonra `--import`.
- Bilgi balonlarında "nasıl oynanır" yazılmaz.
- `get_node_or_null("/root/X")` tercih edilir.
- Emoji/placeholder görseller kabul, final sanat sonra.

## 10. Açık sorular
- Etki süreleri (süreli buff vs kalıcı kademe).
- Esir düşme + fidye dengesi.
- Mouse ile hex seçimi gerekli mi (harita şu an imleç/gamepad tabanlı).
- Aynı anda en fazla kaç cariye görevde olabilir.
