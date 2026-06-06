# Olay veri sözleşmesi (SSOT)

Bu dosya harita, köy ve görev katmanlarının **kim nerede güncellenir** kurallarını sabitler.

## Sahiplik

| Katman | Kaynak | Persist (kayit) | Haber |
|--------|--------|-----------------|-------|
| Yerleşim krizi (kurt, kıtlık, göç, …) | `WorldManager.world_settlement_incidents` | `get_world_map_state` icinde `settlement_incidents` | `_present_settlement_incident_to_player` → `NarrativeSpawnPipeline` → `post_news` (+ relief görevi) |
| Hex yol olayı (travel) | `WorldManager` payload `type: travel_incident` | Yok (anlik); istege bagli `linked_incident_id` referansi | Oyuncu etkisi `apply_world_map_travel_event_resolution_*` |
| Zamanlanmis baskin (fraksiyon / dusman koy / raid) | `WorldManager.pending_attacks` | `get_world_map_state` → `pending_attacks` | Uyari haberi; tetik: `_check_pending_attacks` |
| MissionManager “dünya olayı” (kuraklık vb.) | `MissionManager.world_events` | Bellek; haber ile duyurulur | `post_news` |
| Köy günlük yüzey olayı | `VillageManager` | Köy kaynakları / MM tüccar | `MissionManager.post_news` (köy kategorisi); dünya sıçraması `WorldManager.on_village_surface_event` → `_post_world_news` |
| Köy `trade_caravan` kökeni | `VillageManager` + `MissionManager.settlements` (id = harita `settlement_id`) | — | Tüccar yalnız `WorldManager.is_settlement_hostile_to_player` false köylerden; ilişki `get_relation` ile senkron; uygun köy yoksa karavan yok haberi `post_news` |
| Dinamik görev (`relief_*`, `ally_relief_*`, `worldmap_*`, …) | `MissionManager.missions` | `SaveManager` → `persisted_mission_snapshots` (`Mission.to_save_dict`) | Liste haberi `post_news`; tamamlanınca WM incident veya (ittifak) `apply_alliance_aid_mission_success` |

**Kural:** Aynı kriz için **tek yazım**: incident kaydı WM’de; köy olayından dünyaya sıçrama `WorldManager.on_village_surface_event` ile kontrollü.

**Haber tek kapı:** Oyunda görünen kuyruklar `MissionManager.news_queue_village` / `news_queue_world` (`post_news`). UI yansıması MissionCenter’da çift kuyruk tutulmaz; `news_posted` yalnızca canlı kart güncellemesi için kullanılır.

## Ortak alanlar (genişleme)

- `linked_incident_id` / `linked_settlement_id`: travel payload’da WM incident’ına köprü.
- `completes_incident_id` (`Mission`): görev başarılı bitince `WorldManager.resolve_settlement_incident_by_id`.
- `completes_alliance_aid_settlement_id` (`Mission`): muttefik `aid_call` kapanır; `WorldManager.apply_alliance_aid_mission_success` (öncelik: bu alan doluysa incident çözümü atlanır).
- `MissionManager.settlements[].relation`: haritada yer alan `id` için `WorldManager.get_relation("Köy", görünen_ad)` ile güncellenir (`sync_settlement_relations_from_world_map`, WM `set_relation` sonrası); `-100..100` → `0..100` gösterim eşlemesi `50 + wm/2`. Aynı adımda `trade_routes` öğelerinde `relation` / `risk` / `active` tazelenir (`refresh_trade_route_stats_from_settlements`).

## Zaman

- `world_events`: mümkünse `start_game_minutes` + `duration_game_minutes` (oyun dakikası); yoksa geri dönüş gerçek zaman.
- Gün simülasyonu: `WorldManager` günlük tick (incident üretimi) — `TimeManager` günü.

## Cariye rolleri (dünya sim)

- Kaynak: `MissionManager` concubine `role` (`Concubine.Role`); gün tick’te `WorldManager._get_living_world_role_modifiers()` en iyi yetenekli cariyeyi rol başına alır.
- Okuma: `get_living_world_role_modifiers()` (harita UI `_build_role_buffs_status_line`), incident üretimi / çözümü aynı sözlüğü kullanır.
- Yeni anahtarlar: `harvest_failure_severity_mult`, `plague_scare_severity_mult`, `plague_population_loss_mult` (Alim / Tibbiyeci; `docs/LIVING_WORLD_PLAN.md` etki tablosu).

## AI anlatı (NarrativeSpawnPipeline)

- Simülasyon (incident kaydı, stok düşüşü) **anında**; oyuncuya haber/görev **pipeline publish** ile gelir.
- Relief: `relief_*` görevleri `MissionManager.publish_narrative_mission` ile eklenir; `ai_brief` + `ai_narratives` `Mission.to_save_dict` içinde.
- LLM entegrasyonu: `narrative_brief_ready` → `apply_ai_narrative`. Detay: `docs/AI_NARRATIVE_BRIEF.md`.
