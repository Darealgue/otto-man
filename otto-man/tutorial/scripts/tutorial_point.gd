class_name TutorialPoint
extends Marker2D
## Tutorial sahnesinde numaralı NPC / balon konumu. Sıra genelde 1,2,3… — TutorialBeatStep.npc_point_index ile eşleşir.
## Yaygın pratik: sahneye birkaç Marker koy, her satırda hangi numarada konuşacağını seç.

const GROUP_NAME := "tutorial_point"

@export_range(1, 64) var point_index: int = 1
## Editörde hatırlatma (oyunda kullanılmaz).
@export_multiline var designer_note: String = ""


func _enter_tree() -> void:
	if not is_in_group(GROUP_NAME):
		add_to_group(GROUP_NAME)
