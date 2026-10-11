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
| Hava tonu | `village/scripts/VillageEventMood.gd` | `EVENT_TINTS`; köylü tepki balonları (`EVENT_BUBBLE_KEYS`) |
| Aktif event şeridi | `village/scripts/VillageEventStrip.gd` | `EVENT_ICONS` emojileri PLACEHOLDER; ❗ = yarın başlayacak, ❓ = karar bekliyor |
| Haber öncesi uyarı | `VillageManager.FORECAST_EVENT_TYPES` | fırtına, kurt, grev bir gün önceden haber verir |
| Köylü sohbetleri | `village/narrative/VillageNpcAmbientCatalog.gd` | `event_*` etiketleri, aktifken %70 öncelik |
| Karar kartı | `VillageEventDecisionUI.gd` + `VillageEventDecisions.gd` | seçenekler `OPTIONS` tablosunda |
| Çözüm görevi | `MissionManager.EVENT_RELIEF_TEMPLATES` | başarıyla biterse olay sona erer |

## Etkiyi azaltanlar
- `_event_mitigation_factor`: kurt için her asker -%5 (en çok -%40); kıtlıkta depoda >=25 yiyecek -%25.
- Karar kartı seçimi `ev["decision_mult"]` yazar; `_accumulate_gather_trip_mods_from_event` okur.
- Salgın (`plague`) artık `production_penalty` ile tüm temel seferleri etkiler.

## Görev süreleri (fırsat görevleri)
- `MissionManager.OPPORTUNITY_ID_PREFIXES` önekli, zincir/olay köprüsü/rol dışındaki MEVCUT görevler ilk görüldüğünde
  süre damgalanır (7 gün, seyyah 5, çözüm görevleri olay bitiş günü) ve süre dolunca sessizce silinir.
- Listede `⏳N` rozeti (<=2 gün `⚠⏳`), detayda "Fırsat: N gün sonra kaçar".

## Test
Dev konsol: `trigger_world_event <tür>` ile event başlat. Kart, şerit ve çözüm görevi aynı anda belirir.
