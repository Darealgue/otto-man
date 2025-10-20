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
var darkness_controller: DarknessController

func _init() -> void:
	pass

func _ready() -> void:
	collision_visibility_mode = TileMap.VISIBILITY_MODE_DEFAULT
	modulate = Color(1, 1, 1, 1)
	visible = true
	
	# Player spawn olduktan sonra darkness controller'ı initialize et
	call_deferred("initialize_darkness_controller")

func initialize_darkness_controller() -> void:
	# Darkness controller'ı oluştur ve ekle
	darkness_controller = DarknessController.new()
	add_child(darkness_controller)
	
	# Shader'ı bu TileMap'e uygula
	darkness_controller.apply_to_tilemap(self)
	
	print("[UnifiedTerrain] Darkness controller initialized and applied to TileMap")

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

func process_tilemap_layer(tilemap_layer: TileMapLayer, chunk: Node2D) -> void:
	if not tile_set and tilemap_layer.tile_set:
		tile_set = tilemap_layer.tile_set
	
	print("\n=== Position Analysis for Chunk: ", chunk.name, " ===")
	print("Chunk Global Position: ", chunk.global_position)
	print("TileMapLayer Position: ", tilemap_layer.position)
	print("TileMapLayer Global Position: ", tilemap_layer.global_position)
	
	# Get all cells in the tilemap layer
	var cells = tilemap_layer.get_used_cells()
	print("Processing ", cells.size(), " cells")
	
	# Sort cells by Y coordinate to ensure consistent processing
	cells.sort_custom(func(a, b): return a.y < b.y)
	
	# Track the bounds of this chunk's tiles
	var min_pos = Vector2.INF
	var max_pos = -Vector2.INF
	
	for cell in cells:
		# Get cell data using Vector2i cell position
		var source_id = tilemap_layer.get_cell_source_id(cell)
		if source_id == -1:
			continue
			
		var atlas_coords = tilemap_layer.get_cell_atlas_coords(cell)
		var alternative_tile = tilemap_layer.get_cell_alternative_tile(cell)
		
		# Calculate local position in tilemap space
		var local_pos = tilemap_layer.map_to_local(cell)
		
		# Calculate world position
		var world_pos = local_pos + chunk.position
		
		# Convert to unified tilemap coordinates
		var unified_cell = local_to_map(world_pos)
		
		# Update bounds
		min_pos = Vector2(min(min_pos.x, world_pos.x), min(min_pos.y, world_pos.y))
		max_pos = Vector2(max(max_pos.x, world_pos.x), max(max_pos.y, world_pos.y))
		
		# Set the cell in our tilemap
		set_cell(0, unified_cell, source_id, atlas_coords, alternative_tile)
	
	print("\nChunk Bounds Analysis:")
	print("- Min Position: ", min_pos)
	print("- Max Position: ", max_pos)
	print("- Chunk Size: ", max_pos - min_pos)
	
	# After processing the layer, disable both visibility and collision
	tilemap_layer.visible = false
	tilemap_layer.process_mode = Node.PROCESS_MODE_DISABLED  # Disable processing
	
	# Clear all cells from the original tilemap to remove collision
	for cell in cells:
		tilemap_layer.set_cell(cell, -1)  # -1 removes the cell
	
	# Make sure our layer is visible and has collision
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

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
	var source_id = get_cell_source_id(0, cell)
	if source_id == -1:
		return -1
		
	# Get tile data to check terrain type
	var tile_data = get_cell_tile_data(0, cell)
	if not tile_data:
		return -1
	
	# Check if this is a dark tile (should not be treated as platform)
	var atlas_coords = get_cell_atlas_coords(0, cell)
	if is_dark_tile(atlas_coords):
		print("DEBUG: get_cell_terrain_type(", cell, ") - Dark tile detected, returning 0")
		return 0  # Dark tiles are terrain=0 but not platforms
	
	if tile_data.has_method("get_terrain"):
		var terrain = tile_data.get_terrain()
		print("DEBUG: get_cell_terrain_type(", cell, ") - Terrain from tile_data: ", terrain)
		return terrain  # Get terrain type from tile data
	else:
		# Fallback: check if it's a one-way platform by looking at collision properties
		var collision_polygon = tile_data.get_collision_polygon_points(0, 0)
		if collision_polygon.size() > 0:
			# Check if it has one-way collision
			var is_one_way = tile_data.get_collision_polygon_one_way(0, 0)
			if is_one_way:
				print("DEBUG: get_cell_terrain_type(", cell, ") - One-way platform detected, returning 1")
				return 1  # One-way platform
		print("DEBUG: get_cell_terrain_type(", cell, ") - Regular wall, returning 0")
		return 0  # Regular wall

func is_dark_tile(atlas_coords: Vector2i) -> bool:
	# Dark tile koordinatları - gerçek atlas koordinatları
	var dark_coordinates = [
		Vector2i(9, 12),  # Dark tile - debug çıktısından görülen koordinat
		# Diğer dark tile koordinatları buraya eklenebilir
	]
	
	# DEBUG: Dark tile kontrolü
	var is_dark = atlas_coords in dark_coordinates
	if is_dark:
		print("DEBUG: is_dark_tile(", atlas_coords, ") = TRUE")
	else:
		print("DEBUG: is_dark_tile(", atlas_coords, ") = FALSE")
	
	return is_dark

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
	pattern += "L" if surroundings["left"] else "_"
	
	# Select appropriate tile based on surroundings and terrain type
	var new_coords = select_appropriate_tile(surroundings)
	if new_coords != atlas_coords:
		set_cell(0, cell, source_id, new_coords, alternative)
		return true
	return false

func get_surrounding_terrain(cell: Vector2i) -> Dictionary:
	var current_terrain = get_cell_terrain_type(cell)
	if current_terrain == -1:
		return {
			"top": false, "right": false, "bottom": false, "left": false,
			"top_right": false, "bottom_right": false, "bottom_left": false, "top_left": false
		}
	
	var surroundings = {
		"top": false, "right": false, "bottom": false, "left": false,
		"top_right": false, "bottom_right": false, "bottom_left": false, "top_left": false
	}
	
	# Check each direction and compare terrain types
	var top_terrain = get_cell_terrain_type(cell + Vector2i(0, -1))
	var right_terrain = get_cell_terrain_type(cell + Vector2i(1, 0))
	var bottom_terrain = get_cell_terrain_type(cell + Vector2i(0, 1))
	var left_terrain = get_cell_terrain_type(cell + Vector2i(-1, 0))
	var top_right_terrain = get_cell_terrain_type(cell + Vector2i(1, -1))
	var bottom_right_terrain = get_cell_terrain_type(cell + Vector2i(1, 1))
	var bottom_left_terrain = get_cell_terrain_type(cell + Vector2i(-1, 1))
	var top_left_terrain = get_cell_terrain_type(cell + Vector2i(-1, -1))
	
	# Set boolean values based on terrain matching
	surroundings["top"] = (top_terrain != -1 and top_terrain == current_terrain)
	surroundings["right"] = (right_terrain != -1 and right_terrain == current_terrain)
	surroundings["bottom"] = (bottom_terrain != -1 and bottom_terrain == current_terrain)
	surroundings["left"] = (left_terrain != -1 and left_terrain == current_terrain)
	surroundings["top_right"] = (top_right_terrain != -1 and top_right_terrain == current_terrain)
	surroundings["bottom_right"] = (bottom_right_terrain != -1 and bottom_right_terrain == current_terrain)
	surroundings["bottom_left"] = (bottom_left_terrain != -1 and bottom_left_terrain == current_terrain)
	surroundings["top_left"] = (top_left_terrain != -1 and top_left_terrain == current_terrain)
	
	return surroundings

func select_appropriate_tile(surroundings: Dictionary) -> Vector2i:
	# Debug print to see what patterns we're getting
	var pattern = ""
	pattern += "T" if surroundings.top else "_"
	pattern += "R" if surroundings.right else "_"
	pattern += "B" if surroundings.bottom else "_"
	pattern += "L" if surroundings.left else "_"
	
	# Check for inner corners first
	# Top-right inner corner (when connecting up and right)
	if surroundings.top and surroundings.right and not surroundings.top_right:
		return Vector2i(6, 1)
	
	# Top-left inner corner (when connecting up and left)
	if surroundings.top and surroundings.left and not surroundings.top_left:
		return Vector2i(7, 1)
	
	# Bottom-right inner corner (when connecting bottom and right)
	if surroundings.bottom and surroundings.right and not surroundings.bottom_right:
		return Vector2i(6, 0)
	
	# Bottom-left inner corner (when connecting bottom and left)
	if surroundings.bottom and surroundings.left and not surroundings.bottom_left:
		return Vector2i(7, 0)
	
	# Regular tile selection
	if surroundings.top and surroundings.right and surroundings.bottom and surroundings.left:
		return Vector2i(1, 1)  # Full cross piece - middle tile
	elif surroundings.top and surroundings.bottom and not surroundings.left and not surroundings.right:
		return Vector2i(3, 1)  # Vertical corridor
	elif surroundings.left and surroundings.right and not surroundings.top and not surroundings.bottom:
		return Vector2i(1, 1)  # Horizontal corridor - using middle piece
	elif surroundings.right and surroundings.bottom and not surroundings.top and not surroundings.left:
		return Vector2i(0, 0)  # Top-left corner
	elif surroundings.left and surroundings.bottom and not surroundings.top and not surroundings.right:
		return Vector2i(2, 0)  # Top-right corner
	elif surroundings.top and surroundings.right and not surroundings.bottom and not surroundings.left:
		return Vector2i(0, 2)  # Bottom-left corner
	elif surroundings.top and surroundings.left and not surroundings.bottom and not surroundings.right:
		return Vector2i(2, 2)  # Bottom-right corner
	elif surroundings.top and not surroundings.right and not surroundings.bottom and not surroundings.left:
		return Vector2i(1, 2)  # Bottom cap
	elif not surroundings.top and surroundings.right and not surroundings.bottom and not surroundings.left:
		return Vector2i(0, 1)  # Left cap
	elif not surroundings.top and not surroundings.right and surroundings.bottom and not surroundings.left:
		return Vector2i(1, 0)  # Top cap
	elif not surroundings.top and not surroundings.right and not surroundings.bottom and surroundings.left:
		return Vector2i(2, 1)  # Right cap
	elif surroundings.top and surroundings.right and surroundings.bottom and not surroundings.left:
		return Vector2i(0, 1)  # Left T-junction
	elif surroundings.top and not surroundings.right and surroundings.bottom and surroundings.left:
		return Vector2i(2, 1)  # Right T-junction
	elif not surroundings.top and surroundings.right and surroundings.bottom and surroundings.left:
		return Vector2i(1, 0)  # Top T-junction
	elif surroundings.top and surroundings.right and not surroundings.bottom and surroundings.left:
		return Vector2i(1, 2)  # Bottom T-junction
	
	return Vector2i(1, 1)  # Default to middle piece instead of blank


func fix_terrain_connections() -> void:
	print("Fixing terrain connections...")
	var cells = get_used_cells(0)
	var updated_count = 0
	
	for cell in cells:
		var source_id = get_cell_source_id(0, cell)
		if source_id == -1:
			continue
			
		var atlas_coords = get_cell_atlas_coords(0, cell)
		var alternative = get_cell_alternative_tile(0, cell)
		
		# Dark tile'ları koru - onları değiştirme
		if is_dark_tile(atlas_coords):
			print("DEBUG: Found dark tile at ", cell, " with coords ", atlas_coords)
			print("DEBUG: This tile should NOT be changed!")
			continue
		
		# Dark tile'ların komşularını da koru - onları değiştirme
		# Ama sadece dark tile'ların hemen yanındaki tile'ları koru
		if is_dark_tile_immediate_neighbor(cell):
			print("DEBUG: Found dark tile immediate neighbor at ", cell, " with coords ", atlas_coords)
			print("DEBUG: This tile should NOT be changed!")
			continue
		
		# Terrain type'ı belirle
		var terrain_type = get_cell_terrain_type(cell)
		
		# Platform tile'ları için connection logic uygula
		if terrain_type == 1:
			var surroundings = get_surrounding_terrain_info(cell)
			var new_coords = select_platform_tile(surroundings)
			
			if new_coords != atlas_coords:
				set_cell(0, cell, source_id, new_coords, alternative)
				updated_count += 1
				print("DEBUG: Updated platform tile at ", cell, " from ", atlas_coords, " to ", new_coords)
		
		# Wall tile'ları için de connection logic uygula (chunk birleşmeleri için)
		elif terrain_type == 0:
			var surroundings = get_surrounding_terrain_info(cell)
			
			# Chunk sınırlarındaki köşe tile'ları için özel kontrol
			if is_chunk_boundary_corner(cell):
				var new_coords = select_chunk_boundary_tile(cell, surroundings)
				if new_coords != atlas_coords:
					set_cell(0, cell, source_id, new_coords, alternative)
					updated_count += 1
					print("DEBUG: Updated chunk boundary corner at ", cell, " from ", atlas_coords, " to ", new_coords)
			else:
				var new_coords = select_appropriate_tile(surroundings)
				
				if new_coords != atlas_coords:
					set_cell(0, cell, source_id, new_coords, alternative)
					updated_count += 1
					print("DEBUG: Updated wall tile at ", cell, " from ", atlas_coords, " to ", new_coords)
	
	print("Terrain connection fixes complete. Updated ", updated_count, " tiles.")

func is_dark_tile_immediate_neighbor(cell: Vector2i) -> bool:
	# Dark tile'ların sadece 4 ana yöndeki komşularını kontrol et (diagonal değil)
	var directions = [
		Vector2i(0, -1),   # top
		Vector2i(1, 0),    # right
		Vector2i(0, 1),    # bottom
		Vector2i(-1, 0),   # left
	]
	
	for direction in directions:
		var check_pos = cell + direction
		var neighbor_source_id = get_cell_source_id(0, check_pos)
		if neighbor_source_id != -1:
			var neighbor_atlas_coords = get_cell_atlas_coords(0, check_pos)
			if is_dark_tile(neighbor_atlas_coords):
				return true
	
	return false

func get_surrounding_terrain_info(cell: Vector2i) -> Dictionary:
	# Önce bu tile'ın terrain türünü öğren
	var current_tile_data = get_cell_tile_data(0, cell)
	if not current_tile_data:
		return {"top": false, "right": false, "bottom": false, "left": false, "top_right": false, "bottom_right": false, "bottom_left": false, "top_left": false}
	
	var current_terrain = current_tile_data.get_terrain() if current_tile_data.has_method("get_terrain") else 0
	
	var surroundings = {
		"top": false, "right": false, "bottom": false, "left": false,
		"top_right": false, "bottom_right": false, "bottom_left": false, "top_left": false
	}
	
	# Komşu tile'ları kontrol et (8 yön)
	var neighbors = [
		{"dir": "top", "pos": cell + Vector2i(0, -1)},
		{"dir": "right", "pos": cell + Vector2i(1, 0)},
		{"dir": "bottom", "pos": cell + Vector2i(0, 1)},
		{"dir": "left", "pos": cell + Vector2i(-1, 0)},
		{"dir": "top_right", "pos": cell + Vector2i(1, -1)},
		{"dir": "bottom_right", "pos": cell + Vector2i(1, 1)},
		{"dir": "bottom_left", "pos": cell + Vector2i(-1, 1)},
		{"dir": "top_left", "pos": cell + Vector2i(-1, -1)}
	]
	
	for neighbor in neighbors:
		var neighbor_source_id = get_cell_source_id(0, neighbor.pos)
		if neighbor_source_id != -1:
			var neighbor_data = get_cell_tile_data(0, neighbor.pos)
			if neighbor_data and neighbor_data.has_method("get_terrain"):
				var neighbor_terrain = neighbor_data.get_terrain()
				# Sadece aynı terrain türündeki komşuları kabul et
				surroundings[neighbor.dir] = (neighbor_terrain == current_terrain)
			else:
				# Tile data yoksa ama tile varsa, terrain type'ı manuel olarak belirle
				var neighbor_terrain = get_cell_terrain_type(neighbor.pos)
				if neighbor_terrain != -1:
					surroundings[neighbor.dir] = (neighbor_terrain == current_terrain)
	
	return surroundings

func select_appropriate_tile_for_terrain(surroundings: Dictionary, terrain_type: int) -> Vector2i:
	if terrain_type == 1:  # Platform tile
		# Platform için komşularına göre farklı tile'lar seç
		return select_platform_tile(surroundings)
	else:  # Wall tile
		# Wall için orijinal bağlantı mantığı
		return select_appropriate_tile(surroundings)

func select_platform_tile(surroundings: Dictionary) -> Vector2i:
	# Platform tile'ları için komşularına göre uygun tile seç
	
	# Yatay platformlar (sadece sol-sağ komşular)
	if surroundings.left and surroundings.right and not surroundings.top and not surroundings.bottom:
		# Sol ve sağda komşu var - orta parça
		return Vector2i(1, 4)  # Orta yatay platform
	elif surroundings.left and not surroundings.right and not surroundings.top and not surroundings.bottom:
		# Sadece solda komşu var - sağ uç
		return Vector2i(2, 4)  # Sağ uç yatay platform
	elif surroundings.right and not surroundings.left and not surroundings.top and not surroundings.bottom:
		# Sadece sağda komşu var - sol uç
		return Vector2i(0, 4)  # Sol uç yatay platform
	
	# Dikey platformlar (sadece üst-alt komşular)
	elif surroundings.top and surroundings.bottom and not surroundings.left and not surroundings.right:
		# Üst ve altta komşu var - orta parça
		return Vector2i(4, 1)  # Orta dikey platform
	elif surroundings.top and not surroundings.bottom and not surroundings.left and not surroundings.right:
		# Sadece üstte komşu var - alt uç
		return Vector2i(4, 2)  # Alt uç dikey platform
	elif surroundings.bottom and not surroundings.top and not surroundings.left and not surroundings.right:
		# Sadece altta komşu var - üst uç
		return Vector2i(4, 0)  # Üst uç dikey platform
	
	# Tek başına platform
	else:
		return Vector2i(4, 4)  # Tek başına platform tile

func has_terrain_at(pos: Vector2i) -> bool:
	return get_cell_source_id(0, pos) != -1

func is_chunk_boundary_corner(cell: Vector2i) -> bool:
	# Chunk sınırlarındaki köşe tile'larını tespit et
	# Bu tile'lar chunk birleşmelerinde özel durumlar oluşturur
	
	# 4 ana yöndeki komşuları kontrol et
	var top_neighbor = get_cell_source_id(0, cell + Vector2i(0, -1)) != -1
	var right_neighbor = get_cell_source_id(0, cell + Vector2i(1, 0)) != -1
	var bottom_neighbor = get_cell_source_id(0, cell + Vector2i(0, 1)) != -1
	var left_neighbor = get_cell_source_id(0, cell + Vector2i(-1, 0)) != -1
	
	# Köşe durumları: sadece 2 komşu var ve bunlar dik açı oluşturuyor
	var neighbor_count = 0
	if top_neighbor: neighbor_count += 1
	if right_neighbor: neighbor_count += 1
	if bottom_neighbor: neighbor_count += 1
	if left_neighbor: neighbor_count += 1
	
	# Köşe tile'ı: tam 2 komşu var ve bunlar dik açı oluşturuyor
	if neighbor_count == 2:
		# Dik açı kontrolü: üst-sağ, sağ-alt, alt-sol, sol-üst
		return (top_neighbor and right_neighbor) or \
			   (right_neighbor and bottom_neighbor) or \
			   (bottom_neighbor and left_neighbor) or \
			   (left_neighbor and top_neighbor)
	
	return false

func select_chunk_boundary_tile(cell: Vector2i, surroundings: Dictionary) -> Vector2i:
	# Chunk sınırlarındaki köşe tile'ları için özel tile seçimi
	# Bu tile'lar chunk birleşmelerinde daha yumuşak geçişler sağlar
	
	# Köşe durumlarına göre özel tile'lar seç
	if surroundings.top and surroundings.right:
		return Vector2i(0, 2)  # Sol-alt köşe (üst-sağ komşu var)
	elif surroundings.right and surroundings.bottom:
		return Vector2i(0, 0)  # Sol-üst köşe (sağ-alt komşu var)
	elif surroundings.bottom and surroundings.left:
		return Vector2i(2, 0)  # Sağ-üst köşe (alt-sol komşu var)
	elif surroundings.left and surroundings.top:
		return Vector2i(2, 2)  # Sağ-alt köşe (sol-üst komşu var)
	
	# Fallback: normal tile seçimi
	return select_appropriate_tile(surroundings)
