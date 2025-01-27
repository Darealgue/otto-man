extends TileMap
class_name UnifiedTerrain

# Constants for terrain types
const TERRAIN_GROUND = 0
const TERRAIN_WALL = 1

# Tile size for coordinate conversion
const TILE_SIZE = 32

var terrain_tileset: TileSet
var source_chunk_map: TileMap
var processed_positions = {}

func _init() -> void:
	pass

func _ready() -> void:
	collision_visibility_mode = TileMap.VISIBILITY_MODE_DEFAULT
	modulate = Color(1, 1, 1, 1)
	visible = true

func unify_chunks(chunks: Array) -> void:
	print("\n=== Starting Terrain Unification ===")
	print("Number of chunks to process: ", chunks.size())
	
	if chunks.is_empty():
		push_error("No chunks provided for unification!")
		return
	
	# Reset processed positions for new unification
	processed_positions.clear()
	
	# Process each chunk
	for chunk in chunks:
		if not chunk:
			print("Warning: Null chunk found in array")
			continue
			
		print("\nProcessing chunk: ", chunk.name)
		
		# Look for TileMapLayer directly
		var tilemap_layer = chunk.get_node_or_null("TileMapLayer")
		if tilemap_layer:
			print("Found TileMapLayer in chunk ", chunk.name)
			# Hide the original TileMapLayer
			tilemap_layer.visible = false
			process_tilemap_layer(tilemap_layer, chunk)
		else:
			print("No TileMapLayer found in chunk ", chunk.name)
	
	# After copying all tiles, fix the terrain connections
	fix_terrain_connections()
	print("\n=== Terrain Unification Complete ===")
	
	# Make sure the unified terrain is visible
	visible = true

func process_tilemap_layer(tilemap_layer: Node, chunk: Node) -> void:
	if not tile_set and tilemap_layer.tile_set:
		tile_set = tilemap_layer.tile_set
		collision_visibility_mode = TileMap.VISIBILITY_MODE_DEFAULT
		y_sort_enabled = tilemap_layer.y_sort_enabled if tilemap_layer.has_method("is_y_sort_enabled") else false
	
	var cells = tilemap_layer.get_used_cells()
	print("\n=== Position Analysis for Chunk: ", chunk.name, " ===")
	print("Chunk Global Position: ", chunk.global_position)
	print("TileMapLayer Position: ", tilemap_layer.position)
	print("TileMapLayer Global Position: ", tilemap_layer.global_position)
	print("Processing ", cells.size(), " cells")
	
	# Sort cells by Y coordinate to ensure consistent processing
	cells.sort_custom(func(a, b): return a.y < b.y)
	
	# Track the bounds of this chunk's tiles
	var min_pos = Vector2.INF
	var max_pos = -Vector2.INF
	
	# Get the chunk's base Y position (rounded to nearest tile)
	var chunk_base_y = int(chunk.position.y / TILE_SIZE) * TILE_SIZE
	
	for cell in cells:
		var source_id = tilemap_layer.get_cell_source_id(cell)
		var atlas_coords = tilemap_layer.get_cell_atlas_coords(cell)
		var alternative_tile = tilemap_layer.get_cell_alternative_tile(cell)
		
		if source_id != -1:
			# Calculate local position in tilemap space
			var local_pos = tilemap_layer.map_to_local(cell)
			
			# Calculate world position with corrected Y coordinate
			var world_pos = Vector2(
				local_pos.x + chunk.position.x,
				local_pos.y + chunk_base_y
			)
			
			# Convert to unified tilemap coordinates
			var unified_cell = local_to_map(world_pos)
			
			# Update bounds
			min_pos = Vector2(min(min_pos.x, world_pos.x), min(min_pos.y, world_pos.y))
			max_pos = Vector2(max(max_pos.x, world_pos.x), max(max_pos.y, world_pos.y))
			
			var pos_key = str(unified_cell)
			
			# Check if this position has already been processed
			if not processed_positions.has(pos_key):
				set_cell(0, unified_cell, source_id, atlas_coords, alternative_tile)
				processed_positions[pos_key] = {
					"chunk": chunk.name,
					"source_id": source_id,
					"atlas_coords": atlas_coords,
					"alternative_tile": alternative_tile,
					"original_pos": world_pos,
					"final_pos": map_to_local(unified_cell),
					"has_collision": tilemap_layer.get_cell_tile_data(cell) != null and tilemap_layer.get_cell_tile_data(cell).get_collision_polygons_count(0) > 0
				}
			else:
				var existing = processed_positions[pos_key]
				var new_data = tilemap_layer.get_cell_tile_data(cell)
				var has_new_collision = new_data != null and new_data.get_collision_polygons_count(0) > 0
				
				# Only update if the new tile has collision and the existing one doesn't
				if has_new_collision and not existing.has_collision:
					set_cell(0, unified_cell, source_id, atlas_coords, alternative_tile)
					existing.source_id = source_id
					existing.atlas_coords = atlas_coords
					existing.alternative_tile = alternative_tile
					existing.has_collision = true
	
	print("\nChunk Bounds Analysis:")
	print("- Min Position: ", min_pos)
	print("- Max Position: ", max_pos)
	print("- Chunk Size: ", max_pos - min_pos)

func get_chunk_children(node: Node) -> String:
	var children = []
	for child in node.get_children():
		var desc = child.name + " (" + child.get_class() + ")"
		if child is TileMap:
			desc += " [TileSet: " + str(child.tile_set != null) + "]"
		elif child.get_class() == "TileMapLayer":
			desc += " [TileSet: " + str(child.get("tile_set") != null) + ", Data: " + str(child.get("tile_map_data") != null) + "]"
		children.append(desc)
	return ", ".join(children)

func integrate_chunk(chunk: Node2D) -> int:
	if not chunk:
		print("Warning: Null chunk passed to integrate_chunk")
		return 0
		
	print("Integrating chunk: ", chunk.name)
	
	# Try to find TileMap in different possible locations
	var chunk_map = chunk.get_node_or_null("TileMap")
	if not chunk_map:
		# Try TileMapLayer
		var tilemap_layer = chunk.get_node_or_null("TileMapLayer")
		if tilemap_layer:
			# Try to find converted TileMap
			chunk_map = chunk.get_node_or_null("ConvertedTileMap")
			if not chunk_map:
				# Create a new TileMap from the TileMapLayer data
				var new_tilemap = TileMap.new()
				new_tilemap.tile_set = tilemap_layer.get("tile_set")
				new_tilemap.name = "ConvertedTileMap"
				
				# Copy all visible properties
				new_tilemap.visible = tilemap_layer.visible
				new_tilemap.modulate = tilemap_layer.modulate
				new_tilemap.position = tilemap_layer.position
				new_tilemap.scale = tilemap_layer.scale
				new_tilemap.y_sort_enabled = tilemap_layer.y_sort_enabled
				
				# Try to directly set the tile data
				var tile_map_data = tilemap_layer.get("tile_map_data")
				if tile_map_data:
					print("Found tile data of type: ", typeof(tile_map_data))
					print("First few bytes: ", tile_map_data.slice(0, 20) if tile_map_data is PackedByteArray else "N/A")
					new_tilemap.set("layer_0/tile_data", tile_map_data)
				
				# Add to scene before forcing update
				chunk.add_child(new_tilemap)
				
				# Force update and verify
				new_tilemap.force_update(0)
				var cells = new_tilemap.get_used_cells(0)
				print("After setup - cells found: ", cells.size())
				
				chunk_map = new_tilemap
	
		# If still not found, try Terrain node
		if not chunk_map:
			var terrain = chunk.get_node_or_null("Terrain")
			if terrain:
				chunk_map = terrain.get_node_or_null("TileMap")
	
	if not chunk_map or not chunk_map is TileMap:
		print("Warning: No valid TileMap in chunk ", chunk.name)
		return 0
	
	if not chunk_map.tile_set:
		print("Warning: No tileset in chunk ", chunk.name)
		return 0
		
	var used_cells = chunk_map.get_used_cells(0)
	print("Found ", used_cells.size(), " cells in chunk")
	
	if used_cells.is_empty():
		print("Warning: No cells found in chunk ", chunk.name)
		return 0
	
	var cells_transferred = 0
	var failed_transfers = 0
	
	print("Starting cell transfer for chunk ", chunk.name)
	for cell in used_cells:
		var source_id = chunk_map.get_cell_source_id(0, cell)
		var atlas_coords = chunk_map.get_cell_atlas_coords(0, cell)
		var alternative = chunk_map.get_cell_alternative_tile(0, cell)
		
		# Convert position
		var world_pos = chunk_map.map_to_local(cell) + chunk_map.position + chunk.position
		var unified_cell = local_to_map(world_pos)
		
		# Place tile
		set_cell(0, unified_cell, source_id, atlas_coords, alternative)
		
		# Verify placement
		var placed_data = get_cell_tile_data(0, unified_cell)
		if placed_data == null:
			failed_transfers += 1
			if failed_transfers <= 5:  # Only print first 5 failures to avoid spam
				print("Failed to place tile at ", unified_cell, " from source cell ", cell)
		else:
			cells_transferred += 1
			if cells_transferred <= 5:  # Only print first 5 successes to avoid spam
				print("Successfully placed tile at ", unified_cell, " from source cell ", cell)
	
	print("Transfer results for chunk ", chunk.name, ":")
	print("- Successful: ", cells_transferred)
	print("- Failed: ", failed_transfers)
	
	return cells_transferred

func process_chunk_boundaries(chunks: Array) -> int:
	print("\nProcessing chunk boundaries...")
	
	# Get all cells that are at chunk boundaries
	var boundary_cells = []
	var all_cells = get_used_cells(0)
	print("Total cells in unified map: ", all_cells.size())
	
	for cell in all_cells:
		if is_boundary_cell(cell):
			boundary_cells.append(cell)
			print("Found boundary cell at: ", cell)
	
	print("Found ", boundary_cells.size(), " boundary cells")
	
	# Process boundary cells
	var processed_count = 0
	for cell in boundary_cells:
		if update_boundary_cell(cell):
			processed_count += 1
	
	return processed_count

func is_boundary_cell(cell: Vector2i) -> bool:
	# Check if any neighboring cell has a different terrain type
	var current_terrain = get_cell_terrain_type(cell)
	if current_terrain == -1:
		return false
	
	var is_boundary = false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			
			var neighbor = cell + Vector2i(dx, dy)
			var neighbor_terrain = get_cell_terrain_type(neighbor)
			
			if neighbor_terrain != -1 and neighbor_terrain != current_terrain:
				print("Cell ", cell, " is boundary: different terrain at offset ", Vector2i(dx, dy))
				is_boundary = true
				break
	
	return is_boundary

func get_cell_terrain_type(cell: Vector2i) -> int:
	var data = get_cell_tile_data(0, cell)
	if data == null:
		return -1
	
	# Only consider cells that have a valid tile
	var source_id = get_cell_source_id(0, cell)
	if source_id == -1:
		return -1
		
	return data.terrain if data.has_method("get_terrain") else 0

func update_boundary_cell(cell: Vector2i) -> bool:
	var source_id = get_cell_source_id(0, cell)
	if source_id == -1:
		return false
		
	var atlas_coords = get_cell_atlas_coords(0, cell)
	var alternative = get_cell_alternative_tile(0, cell)
	
	# Get current terrain type
	var data = get_cell_tile_data(0, cell)
	if not data:
		return false
	var terrain = data.terrain if data.has_method("get_terrain") else 0
	
	# Get surrounding terrain information
	var surroundings = get_surrounding_terrain(cell)
	
	# Debug connection pattern
	var pattern = ""
	pattern += "T" if surroundings["top"] == terrain else "_"
	pattern += "R" if surroundings["right"] == terrain else "_"
	pattern += "B" if surroundings["bottom"] == terrain else "_"
	pattern += "L" if surroundings["left"] == terrain else "_"
	
	# Select appropriate tile based on surroundings and terrain type
	var new_coords = select_appropriate_tile(surroundings, terrain)
	if new_coords != atlas_coords:
		print("Cell ", cell, " Pattern: ", pattern, " Old coords: ", atlas_coords, " New coords: ", new_coords)
		set_cell(0, cell, source_id, new_coords, alternative)
		return true
	return false

func get_surrounding_terrain(cell: Vector2i) -> Dictionary:
	var current_terrain = get_cell_terrain_type(cell)
	if current_terrain == -1:
		return {
			"top": -1, "right": -1, "bottom": -1, "left": -1,
			"top_right": -1, "bottom_right": -1, "bottom_left": -1, "top_left": -1
		}
	
	var surroundings = {
		"top": get_cell_terrain_type(cell + Vector2i(0, -1)),
		"right": get_cell_terrain_type(cell + Vector2i(1, 0)),
		"bottom": get_cell_terrain_type(cell + Vector2i(0, 1)),
		"left": get_cell_terrain_type(cell + Vector2i(-1, 0)),
		"top_right": get_cell_terrain_type(cell + Vector2i(1, -1)),
		"bottom_right": get_cell_terrain_type(cell + Vector2i(1, 1)),
		"bottom_left": get_cell_terrain_type(cell + Vector2i(-1, 1)),
		"top_left": get_cell_terrain_type(cell + Vector2i(-1, -1))
	}
	
	# Only consider a direction connected if it has a valid tile and matching terrain
	for direction in surroundings:
		if surroundings[direction] != current_terrain:
			surroundings[direction] = -1
	
	return surroundings

func select_appropriate_tile(surroundings: Dictionary, terrain: int) -> Vector2i:
	var has_top = surroundings["top"] == terrain
	var has_right = surroundings["right"] == terrain
	var has_bottom = surroundings["bottom"] == terrain
	var has_left = surroundings["left"] == terrain
	
	# Count connections
	var connection_count = 0
	if has_top: connection_count += 1
	if has_right: connection_count += 1
	if has_bottom: connection_count += 1
	if has_left: connection_count += 1
	
	# Single connection - end pieces
	if connection_count == 1:
		if has_top: return Vector2i(1, 0)    # End piece pointing up
		if has_right: return Vector2i(2, 1)   # End piece pointing right
		if has_bottom: return Vector2i(1, 2)  # End piece pointing down
		if has_left: return Vector2i(0, 1)    # End piece pointing left
	
	# Two connections - corners or straight pieces
	if connection_count == 2:
		# Prioritize vertical connections
		if has_top and has_bottom: return Vector2i(1, 1)   # Vertical
		if has_left and has_right: return Vector2i(1, 1)   # Horizontal
		
		# Corners
		if has_bottom and has_right: return Vector2i(0, 0)  # Top-left corner
		if has_bottom and has_left: return Vector2i(2, 0)   # Top-right corner
		if has_top and has_right: return Vector2i(0, 2)     # Bottom-left corner
		if has_top and has_left: return Vector2i(2, 2)      # Bottom-right corner
	
	# Three connections - T-junctions
	if connection_count == 3:
		if !has_top: return Vector2i(1, 0)     # T-junction open top
		if !has_right: return Vector2i(2, 1)   # T-junction open right
		if !has_bottom: return Vector2i(1, 2)  # T-junction open bottom
		if !has_left: return Vector2i(0, 1)    # T-junction open left
	
	# Four connections or default - center piece
	return Vector2i(1, 1)

func fix_terrain_connections() -> void:
	print("\nFixing terrain connections...")
	var cells = get_used_cells(0)
	print("Processing ", cells.size(), " cells for terrain connections")
	
	# Sort cells by Y coordinate to ensure consistent processing
	cells.sort_custom(func(a, b): return a.y < b.y)
	
	var processed_cells = {}
	var updated_count = 0
	
	# First pass: Store all existing tiles and their terrain types
	for cell in cells:
		var data = get_cell_tile_data(0, cell)
		if data and data.has_method("get_terrain"):
			processed_cells[cell] = {
				"terrain": data.get_terrain(),
				"source_id": get_cell_source_id(0, cell),
				"atlas_coords": get_cell_atlas_coords(0, cell),
				"alternative": get_cell_alternative_tile(0, cell)
			}
	
	# Second pass: Update tiles based on their surroundings
	for cell in cells:
		if not processed_cells.has(cell):
			continue
			
		var cell_info = processed_cells[cell]
		var terrain = cell_info.terrain
		
		# Get surrounding terrain information
		var surroundings = {
			"top": -1, "right": -1, "bottom": -1, "left": -1
		}
		
		var neighbors = {
			"top": cell + Vector2i(0, -1),
			"right": cell + Vector2i(1, 0),
			"bottom": cell + Vector2i(0, 1),
			"left": cell + Vector2i(-1, 0)
		}
		
		# Check each neighbor
		for direction in neighbors:
			var neighbor = neighbors[direction]
			if processed_cells.has(neighbor):
				var neighbor_terrain = processed_cells[neighbor].terrain
				if neighbor_terrain == terrain:
					surroundings[direction] = terrain
		
		# Create debug pattern
		var pattern = ""
		pattern += "T" if surroundings.top == terrain else "_"
		pattern += "R" if surroundings.right == terrain else "_"
		pattern += "B" if surroundings.bottom == terrain else "_"
		pattern += "L" if surroundings.left == terrain else "_"
		
		# Determine the appropriate tile based on connections
		var new_coords = select_appropriate_tile(surroundings, terrain)
		
		# Only update if the tile needs to change
		if new_coords != cell_info.atlas_coords:
			var should_update = true
			
			# Check if this would create a duplicate connection
			var would_create_duplicate = false
			for direction in neighbors:
				var neighbor = neighbors[direction]
				if processed_cells.has(neighbor) and processed_cells[neighbor].atlas_coords == new_coords:
					# Allow duplicates if they maintain vertical connections
					if surroundings.top == terrain or surroundings.bottom == terrain:
						would_create_duplicate = false
						break
					would_create_duplicate = true
					break
			
			if would_create_duplicate:
				print("SKIPPED Update at ", cell, " - Would create duplicate tile. Pattern: ", pattern)
			else:
				set_cell(0, cell, cell_info.source_id, new_coords, cell_info.alternative)
				processed_cells[cell].atlas_coords = new_coords
				updated_count += 1
				print("UPDATED tile at ", cell, " Pattern: ", pattern, " New coords: ", new_coords)
	
	print("\nTerrain Connection Summary:")
	print("- Total cells processed: ", cells.size())
	print("- Updates applied: ", updated_count)
