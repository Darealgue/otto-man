# NPCDialogueManager.gd
# Central manager for all NPC-LLM interactions
# NPCs just call process_dialogue() with their state data

extends Node

# Signal that NPCs can connect to for responses
signal dialogue_processed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool)

# Track which NPC is currently being processed
var _current_processing_npc: String = ""
var _current_original_state: Dictionary = {}
var _current_player_input: String = ""
func _ready():
	# Connect to LlamaService
	if not LlamaService.is_connected("GenerationComplete", Callable(self, "_on_llama_generation_complete")):
		var error_code = LlamaService.connect("GenerationComplete", Callable(self, "_on_llama_generation_complete"))
		if error_code != OK:
			printerr("NPCDialogueManager: Failed to connect to LlamaService: Error ", error_code)

# Main function that NPCs call
# npc_state: The complete NPC_Info dictionary
# player_input: What the player said
# npc_name: Name of the calling NPC (for response routing)

func process_dialogue(npc_state: Dictionary, player_input: String, npc_name: String):
	if not LlamaService.IsInitialized():
		push_error("NPCDialogueManager: LlamaService not available or not initialized.")
		_emit_error_response(npc_name, "I... don't know what to say.")
		return
	
	if not _current_processing_npc.is_empty():
		push_warning("NPCDialogueManager: Already processing dialogue for %s. Queuing not implemented yet." % _current_processing_npc)
		_emit_error_response(npc_name, "Please wait a moment...")
		return
	
	print("NPCDialogueManager: Processing dialogue for %s" % npc_name)
	print("NPCDialogueManager: Player said: %s" % player_input)
	
	# Store current processing context
	_current_processing_npc = npc_name
	_current_player_input = str(player_input)
	_current_original_state = npc_state.duplicate(true) # Deep copy for comparison
	
	# Construct the prompt
	var prompt = _construct_full_prompt(npc_state, player_input)
	if prompt.is_empty():
		push_error("NPCDialogueManager: Failed to construct prompt for %s" % npc_name)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...")
		return
	
	# Send to LLM
	LlamaService.GenerateResponseAsync(prompt, 350)
	print("NPCDialogueManager: Sent prompt to LlamaService for %s" % npc_name)

# Internal: Handle LLM response
func _on_llama_generation_complete(result_string: String):
	if _current_processing_npc.is_empty():
		return # Not processing anyone
	
	var npc_name = _current_processing_npc
	print("NPCDialogueManager: Received response for %s" % npc_name)
	
	var trimmed_result = result_string.strip_edges()
	if trimmed_result.is_empty():
		push_error("NPCDialogueManager: Empty response for %s" % npc_name)
		_reset_processing_state()
		_emit_error_response(npc_name, "I... don't know what to say.")
		return
	
	var parsed_result = _parse_json_response(trimmed_result)
	if parsed_result == null:
		push_error("NPCDialogueManager: Failed to parse JSON response for %s" % npc_name)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...")
		return
	
	var new_info = parsed_result.get("Info", {}) as Dictionary
	var new_history = parsed_result.get("History", []) as Array
	var generated_dialogue = ""
	if parsed_result.has("Generated Dialogue"):
		generated_dialogue = parsed_result.get("Generated Dialogue", "")
	elif parsed_result.has("GeneratedDialogue"):
		generated_dialogue = parsed_result.get("GeneratedDialogue", "")
	generated_dialogue = str(generated_dialogue)
	if generated_dialogue.strip_edges() == "":
		generated_dialogue = "..."
	
	var tentative_new_state = {"Info": new_info, "History": new_history}
	var was_significant = _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		new_info, new_history
	)
	print("NPCDialogueManager: Dialogue for %s was significant: %s" % [npc_name, was_significant])
	
	var final_state: Dictionary
	if not was_significant:
		final_state = _current_original_state.duplicate(true)
	else:
		final_state = tentative_new_state
	
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated_dialogue, was_significant)

# Internal: Construct the full prompt
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
	var info_json = JSON.stringify(state.get("Info", {}))
	var history_json = JSON.stringify(state.get("History", []))
	var pd = str(player_input).replace('"', '\\"')
	var full_prompt = """
Input State:
{
  \"Info\": %s,
  \"History\": %s
}

Player Dialogue: \"Player\":\"%s\"

Instructions:
1. Evaluate the Player Dialogue in the context of the NPC's current Input State (Info, History).
2. Determine if the dialogue is \"Significant\" or \"Insignificant\" based on the criteria below.
3. If Significant: Update \"Info\" (use only existing keys; do not add new keys) and append a short description to \"History\" reflecting the change. Include the \"Generated Dialogue\" as the NPC's reply.
4. If Insignificant: The \"Info\" and \"History\" fields in the output JSON MUST be exactly identical to those in the Input State. Only \"Generated Dialogue\" may differ.
5. Provide ONLY the complete JSON output as specified by the grammar.

Rules for Significance & State Update:
- Significance Criteria: Dialogue is significant if it bestows titles, reveals important new facts, corrects prior beliefs, causes strong emotional reactions, or involves important actions/items relevant to the NPC.
- Insignificant Dialogue: Simple greetings, casual questions unrelated to the NPC's concerns, or small talk that doesn't impact the NPC's state.
- IF SIGNIFICANT:
	- Output Info MUST contain exactly the same set of keys as the input Info (no additions or removals). Preserve any unchanged values byte-for-byte.
	- If bestowing a title and there is no dedicated Title key, APPEND \" the <Title>\" to the existing Name value (e.g., \"Kamil the Iron Fist\").
	- If the dialogue provides new or superseding information directly impacting the NPC's attributes (the existing keys in the \"Info\" object like Name, Age, Gender, Mood, Occupation, Health), update the values appropriately. Do NOT add new keys.
	- ALWAYS append a short description of the significant event or new memory to the \"History\" array in the output JSON.
- IF INSIGNIFICANT:
	- The \"Info\" and \"History\" fields in the output JSON MUST be ABSOLUTELY IDENTICAL to the Input State provided.
	- Make NO CHANGES WHATSOEVER to these two fields if the dialogue is insignificant.

Generated Dialogue Requirements:
- A single first-person NPC line.
- Do NOT prefix with the NPC's name (no \"Name: ...\").
- No narration or stage directions.

NOW, PROCESS THE FOLLOWING INPUT AND PROVIDE ONLY THE JSON OUTPUT:

Input State:
{
  \"Info\": %s,
  \"History\": %s
}

Player Dialogue: \"Player\":\"%s\"
""" % [info_json, history_json, pd, info_json, history_json, pd]
	print("FULL PROMPT : ", full_prompt)
	return full_prompt

# Internal: Parse JSON response safely
func _parse_json_response(json_string: String):
	var json_parser = JSON.new()
	var error_code = json_parser.parse(json_string)
	
	if error_code != OK:
		var error_line = json_parser.get_error_line()
		var error_msg = json_parser.get_error_message()
		push_error("NPCDialogueManager: JSON parse failed. Error '%s' at line %d.\nResponse:\n%s" % [error_msg, error_line, json_string])
		return null
	
	var parsed_data = json_parser.get_data()
	if typeof(parsed_data) != TYPE_DICTIONARY:
		push_error("NPCDialogueManager: Parsed JSON is not a dictionary")
		return null
	
	return parsed_data

# Internal: Compare dialogue histories for changes
func _compare_dialogue_histories(dh1: Dictionary, dh2: Dictionary) -> bool:
	if dh1.size() != dh2.size():
		return true # Changed (different number of entries)

	for title in dh1:
		if not dh2.has(title):
			return true # Changed (title removed or renamed)
		
		var entry1 = dh1[title]
		var entry2 = dh2[title]

		if typeof(entry1) != TYPE_DICTIONARY or typeof(entry2) != TYPE_DICTIONARY:
			if entry1 != entry2: 
				return true # Fallback comparison
			continue

		# Compare inner dictionaries with sorted keys
		var entry1_str = JSON.stringify(entry1, "\t", true)
		var entry2_str = JSON.stringify(entry2, "\t", true)
		
		if entry1_str != entry2_str:
			return true # Changed content
			
	return false # No changes detected

# Internal: Check if state changed (significance detection)
func _did_state_change(old_info: Dictionary, old_history: Array,
				   new_info: Dictionary, new_history: Array) -> bool:
	# Compare Info (with sorted keys)
	var old_info_str = JSON.stringify(old_info, "\t", true)
	var new_info_str = JSON.stringify(new_info, "\t", true)
	if old_info_str != new_info_str:
		print("NPCDialogueManager: Info changed")
		return true
	
	# Compare History (order matters)
	var old_history_str = JSON.stringify(old_history, "\t", false)
	var new_history_str = JSON.stringify(new_history, "\t", false)
	if old_history_str != new_history_str:
		print("NPCDialogueManager: History changed")
		return true
	
	
	# No significant changes detected
	return false

# Internal: Reset processing state
func _reset_processing_state():
	_current_processing_npc = ""
	_current_original_state = {}
	_current_player_input = ""

# Internal: Emit error response
func _emit_error_response(npc_name: String, error_dialogue: String):
	var empty_state = {"Info": {}, "History": []}
	dialogue_processed.emit(npc_name, empty_state, error_dialogue, false) 

# Ensure state has correct shapes
func _normalize_state(state: Dictionary) -> Dictionary:
	var info = state.get("Info", {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var history = state.get("History", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	return {"Info": info, "History": history} 

# Merge/sanitize significant updates: keep Info key set identical and avoid history deletions
func _sanitize_significant_state(old_state: Dictionary, new_state: Dictionary) -> Dictionary:
	var old_info: Dictionary = old_state.get("Info", {})
	var old_history: Array = old_state.get("History", [])
	
	var in_info = new_state.get("Info", {})
	var in_history = new_state.get("History", [])
	
	# 1) Info: restrict to original keys only, fill missing with old values
	var sanitized_info: Dictionary = {}
	for k in old_info.keys():
		if in_info.has(k):
			sanitized_info[k] = in_info[k]
		else:
			sanitized_info[k] = old_info[k]
	
	# 2) History: accept model-provided authoritative history when it's an array
	var sanitized_history: Array = old_history.duplicate()
	var history_changed := false
	if typeof(in_history) == TYPE_ARRAY:
		var old_history_str = JSON.stringify(old_history, "\t", false)
		var new_history_str = JSON.stringify(in_history, "\t", false)
		history_changed = (old_history_str != new_history_str)
		sanitized_history = in_history
	
	# Detect info change
	var info_changed := JSON.stringify(old_info, "\t", true) != JSON.stringify(sanitized_info, "\t", true)
	
	return {"Info": sanitized_info, "History": sanitized_history} 
