Mentor sprite'larını buraya koy.

Önerilen dosya adları:
  mentor_idle.png          — yatay sprite sheet (idle kareleri)
  mentor_smoke_bomb.png    — atış animasyonu sheet
  mentor_smoke_fx.png      — bombadan çıkan duman efekti sheet

Godot'ta MentorCharacter.tscn → Body → Sprite Frames:
  - animasyon "idle"       → mentor_idle.png
  - animasyon "smoke_bomb" → mentor_smoke_bomb.png

SmokeFx → Sprite Frames:
  - animasyon "default"    → bomba patlama + duman (giriş ve çıkışta; loop kapalı)

Giriş: default FX ortasında Body idle görünür (entrance_body_reveal_frame, -1 = yarı).
Çıkış: Body smoke_bomb → departure_smoke_fx_at_throw_frame karesinde (varsayılan 5 = 6. kare) default FX.

Import: Filter = Nearest, Mipmaps = kapalı (piksel sanat).
