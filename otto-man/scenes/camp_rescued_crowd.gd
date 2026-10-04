class_name CampRescuedCrowd
extends Node2D

## Kamp sahnesinde, o ana kadar kurtarılıp henüz kampa taşınan köylü ve cariyeleri çeşmenin çevresinde gösterir.
## Salt görseldir; DungeonRunState'in bekleyen listelerini okur, değiştirmez.

const MAX_VISIBLE := 14
const WANDER_RANGE := 200.0


## center: dünya uzayında çeşmenin zemindeki konumu; base_z: oyuncunun hemen arkasında kalacak z.
func populate(center: Vector2, base_z: int) -> int:
	for c in get_children():
		c.queue_free()
	var drs: Node = get_node_or_null("/root/DungeonRunState")
	if drs == null:
		return 0
	var entries: Array = []
	for v in drs.get("pending_rescued_villagers"):
		entries.append({"kind": "villager", "data": v if v is Dictionary else {}})
	for c in drs.get("pending_rescued_cariyes"):
		entries.append({"kind": "cariye", "data": c if c is Dictionary else {}})
	entries = entries.slice(0, MAX_VISIBLE)
	var count: int = entries.size()
	for i in count:
		var npc := CampRescuedNpc.new()
		add_child(npc)
		# Başlangıç konumları çeşmenin çevresine yayılır
		var slot: float = (float(i) - float(count - 1) * 0.5) * (WANDER_RANGE * 1.6 / maxf(float(count), 1.0))
		npc.global_position = Vector2(center.x + 50.0 + slot, center.y)
		npc.setup(String(entries[i]["kind"]), entries[i]["data"], center.x + 50.0, WANDER_RANGE, base_z)
	return count
