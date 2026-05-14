class_name TutorialBeatStep
extends Resource
## Bir balon satırı: hangi numaralı TutorialPoint’te NPC gösterilecek, metin, kapanma mesafesi, isteğe bağlı tetik alanı.

## İlk satır gibi sahne açılır açılmaz başlasın; trigger_area yok sayılır.
@export var begin_immediately: bool = false
## Oyuncu bu Area2D içine girince beat başlar (begin_immediately false ise zorunlu).
@export var trigger_area: NodePath = NodePath("")
## Sahnedeki TutorialPoint.point_index ile eşleşir (1, 2, 3…).
@export_range(1, 64) var npc_point_index: int = 1
@export_multiline var speech_bbcode: String = ""
## true ise speech_bbcode yerine sıralı dövüş görevleri gösterilir (Beat6 vb.). Tutma/yürüme ile kapanmaz.
@export var use_combat_objectives: bool = false
## Balon bu Area2D içindeyken açık kalır; oyuncu alandan çıkınca kapanır.
## Boşsa ve beat’in trigger_area’sı varsa: kapanış için trigger_area kullanılır.
## Hem tetik hem tutma ayrı olsun istersen burayı doldur.
@export var hold_until_exit_area: NodePath = NodePath("")
## hold_until_exit_area ve trigger_area yoksa (ör. begin_immediately): balon bu kadar yürüyüşle kapanır.
@export var close_after_travel_pixels: float = 220.0
