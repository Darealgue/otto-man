# NPCDialogueManager.gd
# Central manager for all NPC-LLM interactions
# NPCs just call process_dialogue() with their state data

extends Node

# Signal that NPCs can connect to for responses
signal dialogue_processed(npc_name: String, new_state: Dictionary, generated_dialogue: String, was_significant: bool)

# Track which NPC is currently being processed
var _current_processing_npc: String = ""
var _current_original_state: Dictionary = {}

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
	
	# Trim response
	var trimmed_result = result_string.strip_edges()
	
	if trimmed_result.is_empty():
		push_error("NPCDialogueManager: Empty response for %s" % npc_name)
		_reset_processing_state()
		_emit_error_response(npc_name, "I... don't know what to say.")
		return
	
	# Parse JSON
	var parsed_result = _parse_json_response(trimmed_result)
	if parsed_result == null:
		push_error("NPCDialogueManager: Failed to parse JSON response for %s" % npc_name)
		_reset_processing_state()
		_emit_error_response(npc_name, "My thoughts are scrambled...")
		return
	
	# Extract data safely
	var new_info = parsed_result.get("Info", {}) as Dictionary
	var new_history = parsed_result.get("History", []) as Array
	var new_dialogue_history = parsed_result.get("DialogueHistory", {}) as Dictionary
	var generated_dialogue = parsed_result.get("Generated Dialogue", "...") as String
	
	# Check for missing dialogue
	if not parsed_result.has("Generated Dialogue") or generated_dialogue.is_empty():
		push_warning("NPCDialogueManager: Missing or empty 'Generated Dialogue' for %s" % npc_name)
		generated_dialogue = "..."
	
	# Create new state
	var new_state = {
		"Info": new_info,
		"History": new_history,
		"DialogueHistory": new_dialogue_history
	}
	
	# Determine significance
	var was_significant = _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		_current_original_state.get("DialogueHistory", {}),
		new_info, new_history, new_dialogue_history
	)
	
	print("NPCDialogueManager: Dialogue for %s was significant: %s" % [npc_name, was_significant])
	
	# Reset processing state
	_reset_processing_state()
	
	# Emit response to the NPC
	dialogue_processed.emit(npc_name, new_state, generated_dialogue, was_significant)
	
# Internal: Construct the full prompt
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
	var npc_name = state.get("Info", {}).get("Name", "NPC")
	var info_json = JSON.stringify(state.get("Info", {}))
	var history_json = JSON.stringify(state.get("History", []))
	var dialogue_history_json = JSON.stringify(state.get("DialogueHistory", {}))
	
	var full_prompt = """
Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "Player":"%s"

Instructions:
1. Evaluate the Player Dialogue in the context of the NPC's current Input State (Info, History, DialogueHistory).
2. Determine if the dialogue is "Significant" or "Insignificant" based on the "Significance Criteria" and "Insignificant Dialogue" definitions below.
3. If Significant: Update "Info", "History" (e.g., append a new memory), and add a new entry to "DialogueHistory" in the output JSON, reflecting the changes. The new "DialogueHistory" entry should summarize the key parts of the interaction.
4. If Insignificant: The "Info", "History", and "DialogueHistory" fields in the output JSON MUST be *exactly identical* to those in the Input State. Crucially, do NOT add any new entries to "DialogueHistory" and make no alterations to it if the dialogue is insignificant.
5. ALWAYS include the "Generated Dialogue" field with the NPC's spoken response.
6. Provide ONLY the complete JSON output as specified by the GBNF grammar.

Rules for Significance & State Update:
- Significance Criteria: Dialogue is significant if it bestows titles, reveals major plot points, causes strong emotional reactions in the NPC, involves important actions/items/decisions relevant to the NPC, or makes the NPC reveal something deep about their unique history/personality.
- Insignificant Dialogue: Simple greetings ("hello", "how are you?"), casual questions unrelated to the NPC's core concerns, generic statements, or chit-chat that doesn't impact the NPC's state or understanding.
- IF SIGNIFICANT:
	- If the dialogue provides new or superseding information directly impacting the NPC's *attributes* (those represented by the existing keys in the "Info" field like name, age, gender, mood, occupation, etc.), update the "Info" field in the output JSON. **CRITICAL RULE: You MUST only use the exact same set of keys for "Info" that were provided in the Input State's "Info" object. YOU ARE NOT ALLOWED TO ADD NEW KEYS to the "Info" object.** Change the values of the existing keys as appropriate. For example, if a title is bestowed and the Input State's "Info" object does NOT contain a 'Title' key, you MUST append the title to the existing "Name" value (e.g., Input "Name": "NPC" becomes Output "Name": "NPC the Brave"). If an existing key can logically store the new information (like "Mood", "Age", "Occupation"), update its value.
	- ALWAYS append a short description of the significant event or new memory to the "History" array in the output JSON.
	- ALWAYS add a new entry to "DialogueHistory" in the output JSON, summarizing this significant interaction. **CRITICAL: You MUST preserve ALL existing entries in "DialogueHistory" from the Input State and add the new entry alongside them. NEVER delete or omit existing DialogueHistory entries.** The key for this new entry should be a short, descriptive title for the dialogue turn. The value should be an object containing player and NPC lines (e.g., {"speaker": "...", "self": "..."}).
- IF INSIGNIFICANT:
	- The "Info", "History", AND "DialogueHistory" fields in the output JSON MUST be ABSOLUTELY IDENTICAL to the Input State provided.
	- DO NOT add any new entries to "DialogueHistory".
	- Make NO CHANGES WHATSOEVER to these three fields if the dialogue is insignificant.
- The "Generated Dialogue" field MUST always be present and contain the NPC's direct response.

NOW, PROCESS THE FOLLOWING INPUT AND PROVIDE ONLY THE JSON OUTPUT:

Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "Player":"%s"
""" % [info_json, history_json, dialogue_history_json, player_input.replace('"', '\"'), npc_name, info_json, history_json, dialogue_history_json, player_input.replace('"', '\"')]
	
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
func _did_state_change(old_info: Dictionary, old_history: Array, old_dialogue_history: Dictionary,
					   new_info: Dictionary, new_history: Array, new_dialogue_history: Dictionary) -> bool:
	
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
	
	# Compare DialogueHistory (complex comparison)
	if _compare_dialogue_histories(old_dialogue_history, new_dialogue_history):
		print("NPCDialogueManager: DialogueHistory changed")
		return true
	
	return false

# Internal: Reset processing state
func _reset_processing_state():
	_current_processing_npc = ""
	_current_original_state = {}

# Internal: Emit error response
func _emit_error_response(npc_name: String, error_dialogue: String):
	var empty_state = {"Info": {}, "History": [], "DialogueHistory": {}}
	dialogue_processed.emit(npc_name, empty_state, error_dialogue, false) 
