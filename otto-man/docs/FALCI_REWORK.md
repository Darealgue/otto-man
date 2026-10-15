# Falcı yeniden tasarımı (taslak, 2026-10-15)

Durum: TASARIM. Kod yazılmadı. Sayılar öneridir, oyuncu kararı bekleyenler en altta.

## Karar verilenler (kullanıcı)

- Ekran tam ekran, Hearthstone koleksiyonu gibi kart ızgarası. Üstüne gelince altta aksiyon yazısı çıkar.
- Sıralama: kronolojik (en son açılan sol üstte), element, kategori. Rarity yok.
- **Rarity oyuncuya hiç gösterilmez.** Kart rengi ait olduğu elemente göre.
- **Güçlendir:** kalıcı. Güçlendirilen kart çekimde 3 kat ağırlıkla gelir. Slot sayısı falcı seviyesine bağlı:
  ilk yükseltmede 1 slot, sonra sırayla artar (3-5 aralığı).
- **Arşivle** (eski "çıkar"): kart desteden çıkar ama silinmez, **geri alınabilir**.
- **Takas:** aynı elementten başka kart. Kolay farm yolu olmamalı, çok pahalı olmalı, 3 karta karşılık 1 kart olabilir.
- **Satış:** her falcı ziyaretinde 3 item, **kapalı (koleksiyonda olmayan) havuzdan, tema fark etmez**.
  Biri alınınca diğer ikisi kaybolur. Ziyaret başına 1 hak.
- **Falcı Kadın item'ı kalkar.** Yerini güçlendirme sistemi alır.
- Fiyatlar pahalı: oyuncuya altın kazanma motivasyonu.

## Sistem

### Deste
Deste = açık item'lar - arşivdekiler. Kart çekimi yalnızca desteden yapılır (`get_offer_candidate_ids`).

### Güçlendirme
- Güçlendirilmiş kartın ağırlığı 3, diğerleri 1.
- **Pay tavanı:** güçlendirilmişlerin toplam ağırlık payı çekimde en fazla ~%40. Aşılırsa çarpan otomatik düşer.
  Neden: küçük havuzda (15 kart, 5 güçlendirme) tek başına x3 çekimi neredeyse deterministik yapıyor
  (3 kartın ortalama 1,8'i güçlendirilmiş). Tavan bunu önler.
- Yerleştirme ücretli, kaldırma bedava ama iade yok.
- Güçlendirme elde olan kartı etkilemez (zaten çekimden çıkıyor).

### Havuz tabanı
Deste hiçbir zaman `max(24, açık item sayısının %60'ı)` altına inemez. Arşivleme ve takas bunu kontrol eder.
Taban açık item sayısıyla büyür, sabit kalmaz.

### Arşiv
- Arşivleme ücreti artar: 120 + 40 x (şu an arşivde olan sayı).
- Geri alma sabit ücret (öneri 100). Geri alınca ücret sayacı düşer.
- **Takas için feda edilen kartlar arşive girmez, yok olur.** Yoksa "3 çöp kart feda et, geri al, tekrar feda et" döngüsü
  kolay farm olur. Arşivdeki kart takasa verilemez.

### Takas
- 3 kart feda edilir (aynı element olmak zorunda değil, kullanıcı karar versin), + altın.
- Karşılığında **kapalı havuzdan, feda edilen kartların elementinden** rastgele 1 kart açılır.
- Ön koşul zinciri ebeveyni olanlar feda edilemez (mevcut kural).
- Öneri ücret: 250 altın.
- Net etki desteyi 3 azaltıp 1 arttırır, yani taban kuralıyla doğal olarak sınırlanır.

### Satış
- Her ziyarette 3 item, kapalı havuzdan. Ziyaret sayacı `falci_arrives_day` ile aynı pencere.
- Düz fiyat (rarity olmadığı için): öneri 300 altın. Biri alınınca diğer ikisi gider.
- Alınan item koleksiyona açılır (desteye girer), o run'da otomatik elde olmaz.

### Falcı seviyesi
- Seviye 0: güçlendirme yok (arşiv/takas/satış mevcut).
- Seviye 1..5: güçlendirme slotu = seviye.
- Yükseltme ücreti (öneri): 300, 600, 1000, 1500, 2200.

## Arayüz

- Tam ekran, kenarlarda boşluk yok. Üstte tema sekmeleri (Ateş, Buz, Zehir, Fırtına, Barut, Gölge, Tümü, Arşiv).
- Sıralama seçici: Kronolojik, Element, Kategori.
- Izgara: sağdan sola, yukarıdan aşağı. Kaydırma + gamepad gezinme.
- Kart üstüne gelince alt çubukta aksiyonlar ve fiyat: Güçlendir, Arşivle, Takas.
- Bulunmamış kartlar siluet (koleksiyon tamamlama hissi). Ön koşul ebeveyni olanlar soluk ve neden yazar.
- Üst bar: destedeki kart / taban, kullanılan güçlendirme / slot, altın.
- Satış, falcı seviyesi ve takas ayrı sekme/panel olarak ekranın altında ya da yan şeritte.

## Teknik not (mevcut kod)

- `autoload/item_manager.gd`: `banish_item_permanently`, `swap_unlocked_item`, `oracle_category`,
  `permanently_banished_ids`, `get_random_items`, `get_offer_candidate_ids` yeniden yazılacak/uyarlanacak.
- `ui/FalciPopupUI.gd`: sıfırdan yeniden (popup yerine tam ekran).
- Rarity: ~190 item dosyasında `rarity = ...` satırı var. Önce yalnızca gösterimden kaldırılır
  (`item_button.gd`, `card_visual_util.gd`, `FalciPopupUI.gd`), alan şimdilik kalır.
  `swap_unlocked_item` rarity'ye bakıyor, bu yeni takasla değişir.
  `DungeonEventInteractable.gd` ve `dev_console.gd` rarity kullanımı ayrıca kontrol edilecek.
- Element rengi: `DUNGEON_THEME_POOLS` (kesif + boss) ve `CHILD_HOME_BY_PARENT` (çocuk item ebeveynin temasında) üzerinden.
  Teması olmayan başlangıç item'ları için nötr renk gerekli.
- `falci_kadin` item'ı `EXCLUDED_ITEM_IDS`'e ve açılmışlardan temizlenir (kayıt geçişi).
- Kayıt: arşiv listesi, güçlendirme listesi, falcı seviyesi ve ziyaret başına satış stoğu/hakkı kayda eklenecek.
  `SaveManager.SAVE_VERSION` değişmeyecek, yeni alanlar eksikse varsayılanla yüklenir.

## Aşamalar

1. Veri katmanı: arşiv, güçlendirme ağırlığı + pay tavanı, taban, takas, satış stoğu, falcı seviyesi, kayıt.
2. Rarity'yi gösterimden kaldır, element rengi.
3. Tam ekran arayüz.
4. `falci_kadin` kaldırma + geçiş.
5. Denge/ayar ve item smoke test.

## Açık sorular

1. Falcıyı yükseltmek neyle? (altın, köy kaynağı, ziyaret sayısı)
2. Teması olmayan başlangıç item'larının rengi/etiketi.
3. Takasta feda edilen 3 kartın aynı elementten olması şart mı?
4. Satışta item'ın kapalı havuzdan seçimi bütün temalardan eşit mi, yoksa henüz hiç açılmamış temaya hafif öncelik mi?
5. Güçlendirme yerleştirme ücreti sabit mi, slot sayısına göre artsın mı?
