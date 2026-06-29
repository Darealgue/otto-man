# Ses placeholder'ları

Oyunda kullanılan her ses bir **ID** ile çağrılır. Gerçek dosyayı aynı isimle koyman yeterli — kod değişmez.

## Klasörler

| Klasör | İçerik |
|--------|--------|
| `assets/audio/sfx/` | Kısa efektler (.ogg önerilir, .wav/.mp3 de olur) |
| `assets/audio/music/` | Loop müzik (henüz hook yok; dosyalar hazır bekleyebilir) |

## SFX — dosya adları

| Oyun ID | Dosya adı (uzantısız) | Şu an kullanılıyor |
|---------|------------------------|-------------------|
| `click` | `ui_click` | Ana menü, ayarlar |
| `confirm` | `ui_confirm` | (ileride) |
| `cancel` | `ui_cancel` | (ileride) |
| `hurt` | `player_hurt` | Oyuncu hasar |
| `death` | `player_death` | Oyuncu ölüm |
| `door_open` | `door_open` | Zindan kapısı |
| `door_locked` | `door_locked` | Kilitli kapı |
| `hit_light` | `combat_hit_light` | (ileride) |
| `block` | `combat_block` | (ileride) |
| `pickup` | `pickup` | (ileride) |
| `build_complete` | `build_complete` | (ileride) |

## Asset değiştirme

1. Örneğin `player_hurt.ogg` indir veya üret.
2. `assets/audio/sfx/player_hurt.ogg` olarak kaydet (`.wav` da olur).
3. Godot projeyi yeniden tarar; oyunu başlat — dosya varsa otomatik o çalar.
4. Dosya yoksa sentez placeholder devreye girer.

Öncelik: `.ogg` > `.wav` > `.mp3`

## Placeholder üretme (ilk kurulum)

Godot Editor → **File → Run** → `tools/generate_audio_placeholders.gd`

Bu script yalnızca **eksik** `.wav` dosyalarını yazar; mevcut dosyalarına dokunmaz.

## Kodda çağırma

```gdscript
SoundManager.play_ui("click")
SoundManager.play_sfx("hurt", global_position)
SoundManager.play_sfx("door_open", global_position)
```

Yeni ses eklemek için `autoload/SoundCatalog.gd` içindeki `SFX_FILES` sözlüğüne bir satır ekle.
