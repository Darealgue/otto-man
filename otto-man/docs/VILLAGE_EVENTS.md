# Köy Eventleri ve Görev Sistemi (v0.25)

## Event havuzları
- **Süreli felaket/nimet** (`VillageManager._pick_and_create_event`): günde %2, tür başına 30 gün bekleme, 3-14 gün.
  Havuz: famine (oyuncuya "Kötü Hasat"), pest, disease, wolf_attack, severe_storm, weather_blessing, worker_strike, bandit_activity.
  `drought` havuzdan çıkarıldı (eski kayıtlarda aktifse etkisi sürer). `raid` WorldManager takviminden gelir.
- **Doğrudan köy eventleri** (`_check_and_trigger_village_event`): trade_caravan, resource_discovery, windfall,
  village_festival, traveler, minor_accident, immigration_wave.
- **Dünya eventleri** (WorldManager.active_events): trade_boom, famine, plague, war_declaration, rebellion.

## Köy özeti satırları / "posta kutusu" (v0.27.1-0.27.2)
- `autoload/VillageDigest.gd`: kısa, BBCode'lu, tonlu (INFO/GOOD/WARN/BAD) satırları biriktirir (en çok 40).
  Kaynaklar: (1) **her haber**: `MissionManager.news_posted` (başlık renkli + içerik, sayılar +yeşil/-kırmızı/düz sarı; içerik 150 karaktere kesilir);
  `flags.digest_skip` / haber `digest_skip` true ise atlanır (savunma haberleri, çünkü aşağıdaki yapılandırılmış satır var);
  (2) `WorldManager.defense_outcome_report` (baskın: başlık + kayıp satırı); (3) `MissionManager.mission_completed` (ticaret görevleri hariç, haber var);
  (4) `VillageManager.time_skip_completed` (yokluk üretimi); (5) `construction_completed`; (6) olay bitişi (`_digest_report_event`; çözüm görevi ile
  bitenlerde haber geldiği için bastırılır). Olay başlangıcı haber olarak gelir (haber gövdesine etkilenen kaynak eklenir).
- `ui/VillageDigestTicker.gd`: köy sahnesi `_ready` içinde eklenir; ÜST ORTADA (olay şeridinin altı, y=58) dizilir. Kuyruktaki her şey aynı anda
  (14 satıra kadar) düşer; önem sırasıyla (kırmızı, sarı, yeşil, bilgi). Satır 5 sn + fazladan her satır için 0.4 sn (en çok 12 sn) kalır.
- `VillageScene.USE_DIGEST_TICKER` true iken eski ortadaki özet kutusu ve inşaat toast'ı kapalıdır.
- Yeni kaynak eklemek: `VillageDigest.report(bbcode, VillageDigest.Tone.X, "ikon")`; sayılar için `good()/bad()/warn()/delta()`.
- Bekleyen kuyruk kaydedilmez (en çok 14 satır, en önemsiz/eski atılır); dedupe aynı metni tekrar eklemez.

## Toplama alanı engelleri (v0.27)
`gather_bandits` (haydutlar) ve `gather_birds` (kuş sürüsü) süreli köy olaylarıdır; havuzda diğerleriyle birlikte seçilir
ve yalnız o kaynakta en az bir toplayıcı çalışıyorsa doğar (`VillageManager._setup_gather_blockade_event`).
- **Etki:** olay kaydındaki `blocked_resource` (wood/stone/food) için toplama seferleri %100 eli boş döner
  (`_is_gather_blockaded`, `_get_gather_trip_modifiers` içinde üst sınırdan sonra uygulanır).
- **Üç çözüm yolu:** (1) görev merkezinden cariye/asker: `MissionManager.EVENT_RELIEF_TEMPLATES["gather_bandits"|"gather_birds"]`,
  başarıyla biterse olay kapanır; (2) haritada toplama alanına konan challenge'ı kendin yap: haydutlar `dalga`, kuşlar `kovalamaca`;
  (3) olayın süresi dolar (sessizce biter).
- **Harita:** `WorldManager.place_gather_blockade_poi` köye en yakın boş orman (odun/yiyecek) ya da dağ (taş) karosuna
  `poi_type = "challenge"` + `challenge_blockade*` alanlarını yazar. Normal etkinlik gibi tek kullanımlık DEĞİL: karo giriş
  sırasında silinmez, yalnız olay bitince kalkar; `purge_expired_challenges` ve `CHALLENGE_MAX_ACTIVE` sayımı bunu atlar.
- **Challenge odası:** payload `blockade_event` / `blockade_resource` taşır; zaferde `VillageManager.clear_event(tür)`
  çağrılır (görev + karo birlikte kalkar), ödül item yerine `15 + 10*zorluk` altındır. Başarısızlık = ölüm kuralı aynıdır, engel yerinde kalır.
- Dev: `trigger_world_event gather_bandits|gather_birds` toplayıcı şartı aramaz (hemen görülsün).

## Oyuncuya yansıma
| Parça | Dosya | Not |
|---|---|---|
| Aktif event şeridi | `village/scripts/VillageEventStrip.gd` | `EVENT_ICONS` emojileri PLACEHOLDER; ❗ = yarın başlayacak |
| Köylü tepki balonları | `village/scripts/VillageEventMood.gd` | `EVENT_BUBBLE_KEYS`; ekrana renk filtresi YOK (denendi, kaldırıldı) |
| Haber öncesi uyarı | `VillageManager.FORECAST_EVENT_TYPES` | fırtına, kurt, grev bir gün önceden haber verir |
| Köylü sohbetleri | `village/narrative/VillageNpcAmbientCatalog.gd` | `event_*` etiketleri, aktifken %70 öncelik |
| Çözüm görevi (cariye) | `MissionManager.EVENT_RELIEF_TEMPLATES` | köyde cariye varsa çıkar; başarıyla biterse olay sona erer |

Karar kartı (seçim menüsü) denendi ve KALDIRILDI: oyuncu çözümü cariye görevleriyle yapar. Fırtına ve hava bereketi
için çözüm görevi yoktur (durdurulamaz).

## Etkiyi azaltanlar
- `_event_mitigation_factor`: kurt için her asker -%5 (en çok -%40); kıtlıkta depoda >=25 yiyecek -%25.
- Salgın (`plague`) artık `production_penalty` ile tüm temel seferleri etkiler.

## Görev süreleri (fırsat görevleri)
- `MissionManager.OPPORTUNITY_ID_PREFIXES` önekli, zincir/olay köprüsü/rol dışındaki MEVCUT görevler ilk görüldüğünde
  süre damgalanır (7 gün, seyyah 5, çözüm görevleri olay bitiş günü) ve süre dolunca sessizce silinir.
- Listede `⏳N` rozeti (<=2 gün `⚠⏳`), detayda "Fırsat: N gün sonra kaçar".

## Test
Dev konsol: `trigger_world_event <tür>` ile event başlat; şerit ve çözüm görevi aynı anda belirir (cariye varsa).
