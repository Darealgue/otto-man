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

---

## Müzik (`assets/audio/music/`)

Ambient'ten **ayrı** çalar: kendi `AudioStreamPlayer`'ı var ve **Music bus**'ına bağlı.
Ambient/BGS ise **SFX bus**'ında — böylece oyuncu ayarlardan müzik ile ortam sesini
ayrı ayrı kısabiliyor.

| Oyun ID | Dosya adı (uzantısız) | Nerede çalar |
|---------|------------------------|--------------|
| `menu` | `menu_theme` | Ana menü (`menu` profili, ortam sesi yok) |
| `dungeon_1` | `dungeon_theme` | `dungeon` çalma listesi |
| `dungeon_2` | `dungeon_theme_2` | `dungeon` çalma listesi |

### Çalma listeleri — run başına tek parça

`MUSIC_PLAYLISTS` profil → parça listesi eşlemesi. Oyuncu zindana **her girdiğinde**
listeden rastgele bir parça seçilir ve **o run boyunca değişmez** (zindan → kamp →
zindan → boss hep aynı parça). Köye/dünya haritasına dönünce seçim sıfırlanır,
sonraki girişte yeniden seçilir. Üst üste aynı parça gelmez.

Yeni parça eklemek: dosyayı koy → `MUSIC_FILES`'a id ver → id'yi `MUSIC_PLAYLISTS`
içindeki listeye ekle. Başka hiçbir yere dokunma.

### Uzun parça eklerken

1. **`.ogg` (Vorbis, 128-160 kbps)** olarak dışa aktar. `.wav` KULLANMA — Godot WAV'ı
   `AudioStreamWAV` yapıp tamamen RAM'e açar; 6 dakikalık stereo WAV ≈ 63 MB.
   OGG diskten stream edilir.
2. Dosyayı `assets/audio/music/` altına koy.
3. Godot'ta dosyaya çift tıkla → **Import** sekmesi → **Loop** işaretle → **Reimport**.
   İşaretlemezsen kod `finished` sinyaliyle yeniden başlatır ve her turda duyulur bir
   boşluk kalır.
4. **Kuyruk kontrolü — atlama.** DAW export'ları parçanın sonuna reverb kuyruğu ve
   dijital sessizlik ekler. Motorun kendi loop'u dosyanın **en sonuna** kadar çalar,
   yani o sessizlik her turda boşluk olarak duyulur. Mevcut iki parçada ölçülen:
   `dungeon_theme` 5.0 sn, `dungeon_theme_2` 2.5 sn kuyruk.
   Çözüm: `SoundCatalog.MUSIC_LOOP_POINTS` içine parçanın `end` süresini yaz —
   kod oraya gelince `start`a sarar. Değerler müziğin gerçekten bittiği ana göre
   ölçülmeli (kuyruğun ilk ~0.2 sn'sini bırak, kesme sert duyulmasın).
   **Parçayı yeniden export edersen bu değerleri de güncelle.**
5. Mixaj hedefi: **-16 … -14 LUFS integrated, true peak -1 dBTP**. Oyun içi ek kısma
   `SoundManager.MUSIC_VOLUME_LINEAR` ile ayarlanır.
6. Parçanın sonu başına temiz bağlanmalı; reverb kuyruğu sonda kesilirse dikiş duyulur.

Profil geçişlerinde 1.2 sn müzik / 0.6 sn ambient fade uygulanır. Aynı profil içinde
(zindan → kamp → zindan → boss) parça **baştan başlamaz**, kaldığı yerden devam eder.
