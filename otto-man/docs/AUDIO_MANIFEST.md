# Ses manifesti — otto-man

> **Amaç:** Hangi sesin nerede çalacağını, dosya adını ve önceliğini tek yerde tutmak.  
> **Kural:** Kod `SoundManager.play_sfx("id")` / `play_ui("id")` kullanır; sen `assets/audio/sfx/<file_stem>.ogg` koyarsın.

## Neden şu an az ses duyuyorsun?

| Durum | Açıklama |
|-------|----------|
| Hook | Sadece ~6 olay bağlı: UI click, hasar, ölüm, kapı aç/kilit |
| Dosya | `assets/audio/sfx/*.wav` placeholder var; gerçek asset yoksa sentez tonu (çok kısa) |
| Ayar | `Ayarlar → SFX` %0 ise hiç duymazsın |
| Müzik | `play_music` hazır ama henüz sahnelerde çağrılmıyor |

---

## Dosya yapısı

```
assets/audio/
  sfx/          ← kısa efektler (ogg önerilir)
  music/        ← loop ambient
```

**Öncelik uzantı:** `.ogg` > `.wav` > `.mp3`  
**Değiştirme:** Aynı `file_stem` ile üzerine yaz — kod değişmez.

---

## İsimlendirme

`{kategori}_{eylem}_{varyant}`

Örnek: `footstep_player_stone_01.ogg`, `combat_hit_flesh_heavy.ogg`

---

## Faz 0 — Çekirdek (şu an / hemen sonra)

| ID | Dosya (`sfx/`) | Tetikleyici | Hook durumu |
|----|----------------|-------------|-------------|
| `click` | `ui_click` | Menü butonları | ✅ |
| `confirm` | `ui_confirm` | Onay / kaydet | ⬜ |
| `cancel` | `ui_cancel` | İptal / geri | ⬜ |
| `hurt` | `player_hurt` | Oyuncu hasar | ✅ |
| `death` | `player_death` | Oyuncu ölüm | ✅ |
| `door_open` | `door_open` | Zindan kapısı | ✅ |
| `door_locked` | `door_locked` | Kilitli kapı | ✅ |
| `hit_light` | `combat_hit_light` | Düşmana isabet (hafif) | ⬜ |
| `hit_heavy` | `combat_hit_heavy` | Ağır vuruş / boss | ⬜ |
| `hit_whiff` | `combat_hit_whiff` | Hava vuruşu (hedef yok) | ⬜ |
| `block` | `combat_block` | Kalkan / parry | ⬜ |
| `pickup` | `pickup` | Altın / item toplama | ⬜ |

**Hedef:** 30 dk oynanışta dövüş + UI hissedilir olsun.

---

## Faz 1 — Oyuncu locomotion

| ID | Dosya | Tetikleyici | Not |
|----|-------|-------------|-----|
| `footstep_player_grass` | `footstep_player_grass` | Yürüme (orman/zindan zemin) | 2–3 varyant `_01` `_02` |
| `footstep_player_stone` | `footstep_player_stone` | Taş / zindan | |
| `footstep_player_wood` | `footstep_player_wood` | Köy ahşap | |
| `footstep_player_dirt` | `footstep_player_dirt` | Toprak | |
| `jump` | `player_jump` | Zıplama başlangıcı | |
| `land` | `player_land` | Yere iniş (hız eşiği) | |
| `dash` | `player_dash` | Dash / dodge | |
| `roll` | `player_roll` | Varsa roll anim | |

**Teknik:** `PlayerFootstepEmitter` — `is_on_floor()` + hız eşiği + zemin tipi (başta tek `footstep_player` yeter).

---

## Faz 2 — Düşman

| ID | Dosya | Tetikleyici |
|----|-------|-------------|
| `enemy_footstep` | `footstep_enemy_generic` | Yürüyen düşman (basic, spearman…) |
| `enemy_hurt` | `enemy_hurt` | `base_enemy.take_damage` |
| `enemy_death` | `enemy_death` | Ölüm |
| `enemy_alert` | `enemy_alert` | Stealth → tespit |
| `enemy_attack_swing` | `enemy_attack_swing` | Saldırı wind-up |
| `projectile_fire` | `projectile_fire` | Ok / top / büyü |
| `projectile_hit` | `projectile_hit` | Mermi isabet |

**Not:** Uçan düşmanlarda footstep yok; `enemy_flap` / `enemy_swoop` ayrı ID.

---

## Faz 3 — Köy & UI derinliği

| ID | Dosya | Tetikleyici |
|----|-------|-------------|
| `build_complete` | `build_complete` | İnşaat bitti | ✅ katalogda |
| `build_place` | `build_place` | Bina yerleştirme |
| `resource_deposit` | `resource_deposit` | Orman → köy aktarım |
| `mission_complete` | `mission_complete` | Görev başarı |
| `mission_fail` | `mission_fail` | Görev başarısız |
| `news_pop` | `news_pop` | Haber bandı |
| `trader_arrive` | `trader_arrive` | Tüccar geldi |
| `morale_up` | `morale_up` | Moral artışı (festival) |

---

## Faz 4 — Müzik & ambient

| ID | Dosya (`music/`) | Sahne |
|----|------------------|-------|
| `menu` | `menu_ambient` | Ana menü |
| `village` | `village_ambient` | Köy (düşük vol loop) |
| `dungeon` | `dungeon_ambient` | Zindan |
| `world_map` | `world_map_ambient` | Harita |
| `combat_stinger` | `combat_stinger` | Savaş başladı (one-shot) |
| `boss` | `boss_theme` | Boss odası |

---

## Önerilen çalışma sırası (sen + agent)

1. **Manifest onayı** — bu listeden faz 0–1 ID’leri kesinleştir  
2. **Hook turu** — agent: `AttackManager` / `player` / `base_enemy` / footstep emitter  
3. **Placeholder üret** — `tools/generate_audio_placeholders.gd` veya freesound’dan geçici wav  
4. **Asset değiştir** — her ID için gerçek ogg’yi aynı isimle koy  
5. **Varyant** — aynı ID için `footstep_player_stone_01..03` → SoundManager random pick (sonra)

---

## Asset kaynak önerileri (ücretsiz)

- [Kenney](https://kenney.nl/assets?q=audio) — UI, impact paketleri  
- [OpenGameArt](https://opengameart.org/) — footstep, RPG SFX  
- [Freesound](https://freesound.org/) — arama: `footstep stone`, `sword hit flesh`  
- **Lisans:** CC0 / CC-BY kaydet; `assets/audio/CREDITS.txt` tut

---

## Kod referansı

- Katalog: `autoload/SoundCatalog.gd` — yeni ID buraya eklenir  
- Çalma: `SoundManager.play_sfx("id", global_position)`  
- UI: `SoundManager.play_ui("id")`  
- Kısa rehber: `assets/audio/PLACEHOLDER.md`

---

## Durum özeti (2026-06-29)

- [x] SoundManager + dosya/sentez fallback  
- [x] 11 SFX placeholder wav  
- [x] 6 oyun hook’u  
- [ ] Faz 0 combat (hit/whiff/block) hook  
- [ ] Faz 1 footstep emitter  
- [ ] Faz 2 enemy hook  
- [ ] Müzik sahnelerde `play_music`
