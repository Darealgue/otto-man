# Zindan Köylü/Cariye Kurtarma Sistemi – Yol Planı

Bu doküman, zindandaki köylü ve cariye kurtarma odalarına **görsel mahkûm** eklenmesi ve kurtarmanın **zindandan sağ çıkınca** köye eklenmesi için adım adım planı içerir.

---

## 1. Mevcut Durum Özeti

- **Kurtarma chunk’ları:** `villager_dead_end_left.tscn`, `villager_dead_end_right.tscn` (köylü), `vip_dead_end_left.tscn`, `vip_dead_end_right.tscn` (cariye).
- **Etkileşim:** Bu chunk’larda `DoorInteraction.gd` ile kapı/minigame tetikleniyor; `minigame_kind` = `"villager"` veya `"vip"`.
- **Şu anki akış:** Minigame başarılı olunca **hemen** `VillageManager.add_villager()` veya `VillageManager.add_cariye(cariye_data)` çağrılıyor.
- **Eksik:** Odada hapsedilmiş bir köylü/cariye **görseli** yok; kurtarma da zindandan çıkışla ilişkili değil.

---

## 2. Hedef Davranış

1. Oyuncu kurtarma odasına girdiğinde **hapsedilmiş bir köylü veya cariye** (idle, hareketsiz) görsün.
2. Bu NPC, mevcut **köylü/cariye görünüm sistemini** (Worker/Concubine asset’leri, AppearanceDB) kullansın.
3. Minigame **başarılı** olunca köye **hemen** eklenmesin; “kurtarıldı” olarak işaretlensin.
4. Oyuncu **zindandan sağ salim çıkınca** (finish/portal ile köye dönünce) kurtarılan tüm köylüler ve cariyeler köye eklensin.
5. Oyuncu zindanda **ölürse** kurtarılanlar köye **eklenmesin** (roguelike).

---

## 3. Mimari Kararlar

### 3.1 Görsel mahkûm (dungeon prisoner)

- **Worker/Concubine sahnelerini doğrudan kullanmak** köy bağımlılıkları (VillageManager, WorkersContainer, barınak) yüzünden zor.
- **Öneri:** Zindan için hafif “sadece görsel” NPC sahneleri:
  - **DungeonPrisonerVillager:** Görünüm için `AppearanceDB.generate_random_appearance()` + Worker benzeri sprite/animasyon (veya tek sprite idle).
  - **DungeonPrisonerConcubine:** Görünüm için `AppearanceDB.generate_random_concubine_appearance()` + Concubine benzeri görsel.
- Bu sahneler sadece **görsel** olacak; VillageManager’a kayıt, barınak, AI yok. İsterseniz ileride Worker/Concubine’dan türeyen “dungeon modu” da düşünülebilir.

### 3.2 “Kurtarıldı” listesi (pending rescued)

- Zindan run’ı boyunca kurtarılanları tutmak için **tek bir kaynak** kullanılmalı.
- **Öneri:** Yeni bir autoload: **`DungeonRunState`** (veya mevcut bir autoload’a ek alan).
  - `pending_rescued_villagers: int` (kaç köylü kurtarıldı)
  - `pending_rescued_cariyes: Array[Dictionary]` (cariye verisi: isim, leverage, appearance vb.)
- Minigame başarılı → bu listeye ekle.  
- Zindandan **köye dönüş** (portal/finish) → VillageManager’a ekle, listeyi temizle.  
- **Ölüm** → listeyi temizle, köye ekleme.

### 3.3 Cariye verisi tutarlılığı

- Köye eklerken `VillageManager.add_cariye(cariye_data)` kullanılıyor; `cariye_data` içinde en azından `isim`, `leverage` (minigame’den) ve istenirse `appearance` olmalı.
- Chunk’ta spawn edilen **DungeonPrisonerConcubine** için minigame açılmadan önce rastgele isim + görünüm atanır; minigame başarılı olunca bu **aynı** veri (isim + appearance + minigame’den gelen leverage) `pending_rescued_cariyes`’e eklenir. Böylece köye geçerken aynı isim ve görünüm korunur.

---

## 4. Uygulama Adımları

### Adım 1: DungeonRunState (veya mevcut autoload) – Pending rescued

- **Dosya:** Yeni autoload `DungeonRunState.gd` veya `LevelGenerator` / başka uygun autoload’a alan ekleme.
- **İçerik:**
  - `pending_rescued_villagers: int = 0`
  - `pending_rescued_cariyes: Array = []` (Dictionary listesi: `{ isim, leverage, appearance? }`)
  - `clear_pending_rescued()` (zindan girişinde veya ölümde çağrılacak)
  - `add_pending_villager()` → sayacı artır
  - `add_pending_cariye(data: Dictionary)` → listeye ekle
  - `get_and_clear_pending_rescued() -> Dictionary` → `{ villagers: int, cariyes: Array }` döndür, sonra listeyi sıfırla (köye dönüşte tek seferde kullanılacak).

### Adım 2: Dungeon prisoner sahneleri (görsel)

- **DungeonPrisonerVillager:**  
  - Node2D + Sprite (veya basit AnimatedSprite).  
  - Script: `_ready()`’de `AppearanceDB.generate_random_appearance()` ile görseli uygula (mevcut Worker görsel sistemine benzer).  
  - Sadece idle dur; hareket/AI yok.  
  - İsteğe bağlı: “hapsedilmiş” efekti (zincir sprite’ı, koyu renk vb.).

- **DungeonPrisonerConcubine:**  
  - Aynı mantık; `AppearanceDB.generate_random_concubine_appearance()`.  
  - Script’te `cariye_display_name: String` ve `appearance` tutulur; minigame başarılı olunca bu veri `DungeonRunState.add_pending_cariye()` ile kullanılır.

- Bu sahneleri `res://chunks/dungeon/prisoners/` veya `res://village/scenes/dungeon_prisoners/` gibi bir yerde toplayabilirsiniz.

### Adım 3: Chunk’larda mahkûm spawn noktası

- Her kurtarma chunk’ında (villager_dead_end_*, vip_dead_end_*) bir **Marker2D** veya sabit bir **Node2D** ekleyin (örn. `PrisonerSpawn`). Mahkûm bu konumda spawn edilecek.

### Adım 4: DoorInteraction’ı genişletmek

- **Spawn sorumluluğu:** `DoorInteraction` _ready’de:
  - Parent chunk’ta `PrisonerSpawn` (veya benzeri) node’unu bulur.
  - `minigame_kind == "villager"` ise `DungeonPrisonerVillager` sahnesini instantiate edip spawn noktasına ekler.
  - `minigame_kind == "vip"` ise `DungeonPrisonerConcubine` sahnesini instantiate edip ekler; script’e rastgele isim + appearance atanır (ve script bunu saklar).
- **Minigame sonucu:** `_on_minigame_result` içinde:
  - **Başarılı:**  
    - `vm.add_villager()` / `vm.add_cariye()` **çağrılmasın**.  
    - Villager ise: `DungeonRunState.add_pending_villager()`.  
    - VIP ise: Spawn ettiğiniz `DungeonPrisonerConcubine` node’undan isim + appearance (+ minigame payload’ından leverage) alıp `DungeonRunState.add_pending_cariye(...)` çağrısı yapın.  
    - Görsel olarak mahkûmu “kurtarılmış” gösterebilirsiniz (sprite’ı kaldırma, basit animasyon vb.).
  - **Başarısız:** Mevcut `_apply_failure_penalty()` aynen kalabilir.

### Adım 5: Zindan girişinde pending’i temizleme

- Zindana **girerken** (SceneManager.change_to_dungeon veya dungeon sahnesi yüklenirken) `DungeonRunState.clear_pending_rescued()` çağrılmalı. Böylece her yeni zindan run’ında liste sıfırdan başlar.

### Adım 6: Zindandan köye dönüşte kurtarılanları ekleme

- **Ölüm:** `Player` veya ölüm işleyen kod (örn. `_apply_roguelike_mechanics(is_dead)`) ölümde `DungeonRunState.clear_pending_rescued()` çağırsın; böylece kurtarılanlar köye eklenmez.

- **Başarılı çıkış (portal/finish):**  
  - Şu an köye dönüş `PortalArea` → `SceneManager.change_to_village(payload)` ile oluyor.  
  - **Seçenek A:** PortalArea’da, `change_to_village(payload)` çağrılmadan önce `DungeonRunState.get_and_clear_pending_rescued()` ile veriyi al; `payload["rescued_villagers"]` ve `payload["rescued_cariyes"]` olarak ekle.  
  - **Seçenek B:** Köy sahnesi yüklendikten sonra (VillageScene._ready veya VillageManager) `SceneManager.get_current_payload()` ile `source == "dungeon"` ve `rescued_villagers` / `rescued_cariyes` varsa VillageManager’a ekle.

- **Öneri:** Seçenek A daha net: PortalArea’da payload’a ekleyip, **VillageScene._ready** içinde (mevcut `_check_and_transfer_forest_resources` benzeri) `source == "dungeon"` ise:
  - `payload["rescued_villagers"]` kadar `VillageManager.add_villager()` çağır.
  - `payload["rescued_cariyes"]` dizisindeki her eleman için `VillageManager.add_cariye(cariye_data)` çağır.
  - Sonra payload’tan bu anahtarları silebilir veya bir kez işlendiklerini işaretleyebilirsiniz.

### Adım 7: Cariye appearance’ın köye taşınması

- `add_cariye` şu an Dictionary alıyor; VillageManager’daki cariye verisi `appearance` tutuyorsa (Concubine sınıfına bakın), `pending_rescued_cariyes` içindeki her cariye için `appearance`’ı da dictionary’ye koyun.
- Concubine sahnesi köyde spawn edilirken `concubine_data.appearance` kullanılıyor; zindandan gelen cariye verisinde de aynı alanın olması yeterli.

### Adım 8: Test ve senaryolar

- Köylü odası: Gir → mahkûm görünür → minigame başarılı → başka odaya git → finish’e git → köye dön → köyde +1 köylü.
- Cariye odası: Aynı akış; köyde +1 cariye, doğru isim/görünüm.
- Ölüm: Minigame başarılı → sonra öl → köye dön → kurtarılanlar eklenmesin.
- Minigame başarısız: Köylü/cariye odada kalsın, pending’e eklenmesin.

---

## 5. Dosya Değişiklikleri Özeti

| Ne | Dosya / Yer |
|----|-----------------------------|
| Pending state | Yeni `DungeonRunState.gd` (autoload) veya mevcut autoload |
| Görsel mahkûm | Yeni `DungeonPrisonerVillager.tscn` + script |
| Görsel mahkûm | Yeni `DungeonPrisonerConcubine.tscn` + script |
| Spawn + minigame sonucu | `chunks/common/DoorInteraction.gd` |
| Chunk’lara spawn noktası | `villager_dead_end_*.tscn`, `vip_dead_end_*.tscn` |
| Zindan girişi temizlik | SceneManager veya dungeon sahne _ready |
| Ölüm temizlik | Player veya PortalArea _apply_roguelike_mechanics |
| Köye ekleme + payload | `PortalArea.gd` (payload doldurma), `VillageScene.gd` (payload’dan okuyup add_villager / add_cariye) |

---

## 6. Uygulama Özeti (Yapılanlar)

- DungeonRunState autoload, VillageManager can_add_villager/can_add_cariye + record_village_capacity + add_cariye_with_id, MissionManager add_concubine_from_rescue, DoorInteraction kapasite + Köy dolu mesajı + pending, PortalArea payload + ölümde clear, VillageScene _apply_dungeon_rescued, SceneManager clear + record.

## 7. Belirsiz / Senin Kararın Gereken Noktalar

1. **Görsel detay:** Mahkûm için ayrı “zincir” veya “kafes” sprite’ı kullanılacak mı, yoksa sadece mevcut Worker/Concubine görünümü yeterli mi?
2. **Concubine ID / MissionManager:** Cariyeler köyde MissionManager ile senkron mu? `add_cariye` sonrası MissionManager’a da kayıt gerekiyorsa, mevcut köy cariye akışına bir kez daha bakıp aynı yolu kullanmak gerekir.
3. **Aynı run’da aynı odaya tekrar girme:** Chunk tekrar yüklenirse aynı odada ikinci bir mahkûm spawn edilmemeli; `_consumed` zaten minigame’i kilitlemiş oluyor, spawn’ı da sadece `!_consumed` iken yaparak çözülebilir.
4. **Kapasite (uygulandı):** Köy doluysa minigame başlamıyor; "Köy dolu! Yeni köylü/cariye alacak barınak/yer yok." mesajı. Cariye senkron: MissionManager.add_concubine_from_rescue + VillageManager.add_cariye_with_id.

Bu plan uygulandığında: oyuncu kurtarma odasında hapsedilmiş köylü/cariyeyi görecek, minigame’i kazanacak ve zindandan sağ çıkınca kurtardıklarını köye götürmüş olacak.
