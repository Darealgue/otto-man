# Köy Eventleri ve Görev Sistemi (v0.25)

## Event havuzları
- **Süreli felaket/nimet** (`VillageManager._pick_and_create_event`): günde %2, tür başına 30 gün bekleme, 3-14 gün.
  Havuz: famine (oyuncuya "Kötü Hasat"), pest, disease, wolf_attack, severe_storm, weather_blessing, worker_strike, bandit_activity.
  `drought` havuzdan çıkarıldı (eski kayıtlarda aktifse etkisi sürer). `raid` WorldManager takviminden gelir.
- **Doğrudan köy eventleri** (`_check_and_trigger_village_event`): trade_caravan, resource_discovery, windfall,
  village_festival, traveler, minor_accident, immigration_wave.
- **Dünya eventleri** (WorldManager.active_events): trade_boom, famine, plague, war_declaration, rebellion.

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
