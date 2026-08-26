main_font.ttf  = Grenze              (govde, HUD, menu)
title_font.ttf = Grenze Gotisch      (baslik icin, henuz hicbir yere baglanmadi)

Ikisi de Omnibus-Type, SIL Open Font License 1.1, Reserved Font Name yok.
Tam telif metni ve lisans: THIRD_PARTY_LICENSES.txt bolum 10.

Kaynak:
  https://github.com/google/fonts/tree/main/ofl/grenze
  https://github.com/google/fonts/tree/main/ofl/grenzegotisch

Font degistirilirse main_font.ttf.import icindeki su ayarlar gozden gecirilmeli:
  serif  icin -> antialiasing=1 (Gray), hinting=2 (Normal), subpixel_positioning=1 (Auto)
  piksel icin -> antialiasing=0,        hinting=0,          subpixel_positioning=0
Yanlis sinifin ayariyla font okunmaz hale gelir.

Fontu tema atiyor: resources/medieval_theme.tres -> default_font.
Tek tek kontrole font atamaya gerek yok.
