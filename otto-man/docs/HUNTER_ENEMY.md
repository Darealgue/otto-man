# Avcı (Hunter) düşmanı

Oyuncuyu gören, tile ve one-way platformları tanıyıp zıplayarak / atlayarak / platformdan inerek peşinden giden, yeterince hızlı kaçılırsa izini kaybeden takipçi.

| Dosya | Görev |
|---|---|
| `enemy/hunter/hunter_enemy.gd` | Algı, davranış durumları, rotayı yürütme, atılma saldırısı |
| `enemy/hunter/hunter_nav.gd` | `HunterNav`: çalışma zamanı gezinme grafiği + A* |
| `enemy/hunter/hunter_enemy_stats.tres` | Hız / algı / hasar |

## Gezinme (HunterNav)

- **Tile'lar önceden işaretlenmez.** Çevre fizik sorgularıyla taranır: her 16 px'de aşağı ışın, basılabilir (düz, tepesi boş) her yüzey bir düğüm. One-way platformlar da yüzey sayılır; altından geçilebilirliği `test_move` ile ölçülüp `one_way` işaretlenir.
- Yan yana düğümler "yürü" kenarıyla bağlanır (aynı koşu = union-find).
- **Zıplama / kenardan düşme / platformdan inme kenarları tembel üretilir** (A* düğümü açarken). Analitik yay hesaplanır, sonra gerçek gövdeyle `test_move` ile simüle edilip nereye indiği doğrulanır. Yani kenar listesindeki her hamle bu gövdeyle gerçekten yapılabilir.
- A* zaman bütçelidir (kare başına ~1.5 ms), ulaşılamayan hedefte en yakın düğüme kısmi rota verir. Kenarlar önbellekte kalır, ikinci arama hızlıdır.
- Hareket sabitleri (`GRAV`, `JUMP_SPEED`, `AIR_MAX`) `hunter_enemy.gd` ve nav'da aynıdır; simüle edilen yay yürütülenle birebir olmalı. Birini değiştirirsen hepsi aynı kalır (nav, avcıdan alır).
- Havada hedef düğüme doğru yatay düzeltme yapılır; beklenmedik yere inerse rota sıfırlanıp yeniden aranır. Takılırsa (0.5 sn'de 8 px'den az) yeniden planlar ve küçük bir zıplama dener.
- **Bilinen sınır:** grafik statik geometri varsayar. Hareketli asansörde avcı çıkmaz (`plan_wave` `allow_hunter`).

## Davranış

`idle → patrol → chase → (windup → lunge → recover) → search → patrol`

- **Fark etme:** `detection_range` içinde ve görüş hattı açıksa (ya da 150 px yakındaysa). Vurulursa, menzil dışında bile vuranı fark eder. Meta `always_aggro` olan (challenge) avcı hiç kaybetmez.
- **Takip:** hedefin ayağının bastığı yüzeye rota çizer; oyuncu koşuyorsa biraz ilerisine nişan alır (yolunu kesmeye çalışır).
- **İz kaybı:** menzil x1.6'nın ötesindeyse sayaç hızlı, görüş hattı yoksa normal ilerler; 4.5 sn dolunca `search` (son görülen yere gider, 2.6 sn bekler, devriyeye döner). Uyku mesafesi (1700 px) ötesinde zaten uyur.
- **Saldırı (atılma):** 170 px yatay / 90 px dikey içinde, görüş hattı varsa 0.3 sn çömelir, sonra hedefin biraz ötesine iner şekilde atılır. Hasar `attack_damage x 1.1`, 1.6 sn bekleme. Vuruş teması `EnemyHitbox` + çakışma yedeği.
- **Dövüş taktikleri (yakın mesafede):**
  - **Blok (`guard`):** oyuncunun Attack durumuna geçtiğini görünce (%55) 0.65 sn kalkan kaldırır. Önden gelen hafif vuruş sıfır hasar (mavi parlama, hafif geri itilir), sonra karşı atılma; ağır vuruş korumayı kırar (%60 hasar), arkadan vuruş geçer. Bekleme 2.2 sn.
  - **Geri adım (`backstep`):** oyuncuya bakarak geri sıçrar, %60 ihtimalle hemen atılır. Arkası boş olmalı (zemin var, duvar yok).
  - **Geri koşup atılma (`retreat`):** ~0.8 sn geri koşar, döner, uzun sıçrayışla (+%20 hasar) atılır.
  - Taktikler arası bekleme ~3 sn (`tactic_cd`); hepsi `_combat_tactics` içinde.
- **Animasyonlar:** idle / patrol / chase / jump / fall. `death` ve `hurt` yok; kodda `fall` karesinden üretilir (base `die()` çağırdığı için), ölünce dönüp solar.

## Test

Headless bir test sahnesi (zemin + boşluk + one-way + katı blok) ile doğrulandı: boşluk atlama, iki kademe one-way tırmanma, yukarıdan inme, iz kaybı. Gerçek challenge arenasında (dalga, koruma) hasar verdiği de görüldü.
