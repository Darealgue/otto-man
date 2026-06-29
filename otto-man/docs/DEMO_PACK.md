# Demo paketi — export rehberi

## Hızlı aç/kapa

1. Godot → **Project → Project Settings → Autoload** → `DemoPackConfig`
2. `demo_mode_enabled` → **true** (Inspector veya `autoload/DemoPackConfig.gd` içinde `@export`)
3. `max_game_days` → varsayılan **21** (isteğe göre 14–30)

Demo modu açıkken gün sayısı sınırına ulaşıldığında:
- Görev Merkezi haber bandı (`demo.teaser.*`)
- Mentor inbox kapanış mesajı

Oyun kilitlemez; geri bildirim build'i için loop denenmiş sayılır.

## Export adımları

1. **Ana menü** → Ayarlar → Dil TR/EN test
2. Yeni oyun (tutorial'lı veya atlanmış) → köy → orman/zindan → dönüş
3. `demo_mode_enabled = true` ile 21+ gün simüle et veya zaman atla
4. **Project → Export** → Windows Desktop (veya hedef platform)
5. Zip adı önerisi: `otto-man-demo-YYYYMMDD-win64.zip`

## Demo kapsamı (önerilen anlatım)

| Dahil | Hariç / teaser |
|-------|----------------|
| Köy inşa + işçi | Mevsim/kış döngüsü |
| Orman + zindan + harita seyahati | Tam fraksiyon diplomasi derinliği |
| Cariye kurtarma + rol görevleri | Resmi çoklu dil genişlemesi (tr/en mevcut) |
| Köy festivali + savunma savaşı | LLM NPC diyalog (opsiyonel) |
| NPC–NPC ambient sohbet | |

## Test checklist

- [ ] Demo kapalı: gün sınırı mesajı gelmez
- [ ] Demo açık: 21. günde haber + mentor mesajı
- [ ] Köyde iki köylü yakınken ambient balon (20–40 sn)
- [ ] Ayarlar → English → ambient metinler İngilizce
