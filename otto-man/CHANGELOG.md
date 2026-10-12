# Changelog

Her sürüm için oyuncuya dönük kısa notlar. Biçim `tools/push_itch.ps1` tarafından okunur:

- Sürüm başlığı `## <sürüm> - <tarih>` olmalı ve `project.godot` içindeki `config/version` ile aynı yazılmalı.
- Altında `### TR` ve `### EN` bölümleri, her biri madde işaretli liste.
- Oyuncu metinlerinde tire işaretli cümle kurma, sade yaz.
- En yeni sürüm en üstte.

Bu dosya 0.26.5 ile başladı, öncesi kayıt altında değil.

## 0.26.8 - 2026-10-12

### TR
- Düşen odun, taş ve meyve parçaları büyütüldü, artık kolay fark ediliyor.
- Kaynak toplayınca oyuncunun başında kaynağın ikonuyla "+N" çıkıyor. Kısa sürede toplananlar tek bir sayıda birikiyor.
- Hasar alınca düşen kaynakları ve altını geri toplarken de aynı yazı görünüyor.

### EN
- Dropped wood, stone and berry pieces are larger and easier to spot.
- Collecting a resource shows the resource icon and a "+N" above the player. Pickups made in quick succession add up into one number.
- The same popup shows when you pick your resources and gold back up after taking damage.

## 0.26.7 - 2026-10-12

### TR
- Her ağaç, çalı ve kaya iki parça verip bitiyor: ağaç devriliyor ve rengi soluyor, çalı meyvesiz görünüme geçiyor, kaya kırılıyor.
- Çalılar artık ağaçların odununu bitirmiyor, her kaynak kendi payını veriyor.
- Düşen parçalar minigame'lerdeki gerçek parça çizimlerini kullanıyor, meyveler artık dev gibi görünmüyor.

### EN
- Each tree, bush and rock gives two pieces and then finishes: trees fall over and fade, bushes switch to their berry-less look, rocks break.
- Bushes no longer use up the wood of trees, every resource gives its own share.
- Dropped pieces use the real piece art from the minigames, berries no longer look gigantic.

## 0.26.6 - 2026-10-12

### TR
- Ağaç, meyve çalısı ve taşlar artık minigame yerine vurarak sökülüyor. Hafif, ağır ve düşme saldırısı hepsi işe yarıyor.
- Her 3 ila 4 vuruşta yere bir parça düşüyor ve toplayana kadar kaybolmuyor.

### EN
- Trees, berry bushes and rocks are now harvested by hitting them instead of a minigame. Light, heavy and fall attacks all work.
- Every 3 to 4 hits a piece drops to the ground and stays there until you pick it up.

## 0.26.5 - 2026-10-12

### TR
- Orman, dağ ve akarsu bölgeleri artık sonsuz değil: girişten sağa doğru sınırlı bir yol var ve sonunda ikinci bir çıkış portalı bulunuyor.
- Bölgenin iki ucunda harita kenarı koyulaşarak bitiyor, kamera kenarı göstermiyor ve kenardaki duvarlara tutunulamıyor.
- Her bölgenin hammaddesi sınırlı. Biten stok yaklaşık 3 oyun günü içinde yavaş yavaş yeniden doluyor. Dünya haritasında bölgenin üstüne gelince stok durumu görünüyor.

### EN
- Forest, mountain and river regions are no longer endless: there is a limited path from the entrance to the right, with a second exit portal at the end.
- The edge of the map fades to dark at both ends, the camera never shows the border and the boundary walls cannot be climbed.
- Each region has a limited amount of resources. Depleted stock slowly refills over about 3 game days. Hover a region on the world map to see its stock.
