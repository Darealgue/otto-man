# AI Narrative Brief (SSOT)

Görev ve olay metinleri oyun mantığından ayrılır. Oyun **brief** üretir; LLM anlatı yazar; pipeline yayınlar.

## Akış

```
Tetikleyici (incident, görev spawn, olay haberi, …)
  → simülasyon anında işler (kaynak, incident, world_events, …)
  → NarrativeSpawnPipeline.enqueue() veya request_settlement_incident_package()
  → narrative_brief_ready sinyali
  → apply_ai_narrative() veya 15 sn timeout → mechanical_fallback
  → publish: post_news + missions aynı anda (paket varsa)
```

## Görünürlük

- LLM hazır olana kadar haber ve görev **gizli**.
- Timeout veya LLM kapalı: **mechanical-only**.
- LLM kapalıysa bekleme yok; anında mechanical publish.

## MissionManager API (oyun tarafı)

| Fonksiyon | Kullanım |
|-----------|----------|
| `try_enqueue_mission_spawn(mission, source, news_cfg)` | Mission resource görev + opsiyonel haber |
| `try_enqueue_dict_mission_spawn(dict, source, news_cfg)` | Dictionary görev (raid/defense) |
| `try_enqueue_news(source, facts, news_override)` | Sadece haber |
| `publish_narrative_mission(mech, brief, title, body, mode)` | Pipeline publish (Mission) |
| `publish_narrative_dict_mission(dict, brief, title, body, mode)` | Pipeline publish (Dictionary) |

`news_cfg`: `post_news`, `news_override`, `brief_extra`, `post_publish_actions`

## source etiketleri

| source | Tetikleyici |
|--------|-------------|
| `settlement_incident` | WM incident (görevsiz haber) |
| `incident_relief` | WM incident + relief görevi |
| `alliance_aid` | Muttefik yardım çağrısı |
| `dynamic_mission` | Günlük/rotasyon dinamik görev |
| `procedural` | `generate_new_mission` |
| `conflict_defend` | Yerleşim çatışması savunma |
| `conflict_raid` | Yerleşim çatışması yağma |
| `conflict_start` / `conflict_result` | Çatışma haberleri |
| `world_event` | MM kuraklık / göçmen / kurt |
| `worldmap_trade` / `worldmap_diplomacy` / `worldmap_raid` | Harita eylemi |
| `defense_dict` | WM savunma görevi (dict) |
| `bandit_clear` | Haydut temizliği (+ bandit haber) |
| `plague_aid` | Salgın yardım |
| `escort` | Kervan koruma |
| `special_elite` / `special_emergency` | Özel görevler |
| `village_event_{type}` | VM süreli köy olayı (drought, raid, worker_strike, …) |
| `village_surface_resource_discovery` | Kaynak keşfi |
| `village_surface_windfall` | Bolluk |
| `village_surface_traveler` | Seyyah ziyareti |
| `village_surface_minor_accident` | Küçük kaza |
| `village_surface_immigration` | Göç dalgası (başarılı) |
| `village_surface_immigration_failed` | Göç dalgası (barınak yok) |
| `village_surface_trade_caravan_miss` | Tüccar gelmedi |
| `village_surface_cariye_shortage` | Cariye haftalık ihtiyaç eksikliği |
| `village_macro` | Makro olay bildirimi (kıtlık, salgın, …) |
| `village_news` | Genel köy haberi (erzak, hastalık baskısı, …) |

## LLM entegrasyon kontratı

**Dinle:** `NarrativeSpawnPipeline.narrative_brief_ready(request_id, brief, target_locale)`

**Yanıtla:**
```gdscript
NarrativeSpawnPipeline.apply_ai_narrative(
    request_id, locale,
    mission_title, mission_body,  # görev yoksa ""
    news_title, news_body
)
```

**Prompt:** `AiNarrativeBrief.to_prompt_string(brief)` — canonical EN keywords.

**Test:** `NarrativeSpawnPipeline.debug_print_brief(request_id)`
