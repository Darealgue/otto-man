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
	
	# Normalize input state loaded from JSON to avoid malformed prompts
	var normalized_state = _normalize_state(npc_state)
	
	print("NPCDialogueManager: Processing dialogue for %s" % npc_name)
	print("NPCDialogueManager: Player said: %s" % player_input)
	
	# Store current processing context
	_current_processing_npc = npc_name
	_current_player_input = str(player_input)
	_current_original_state = normalized_state.duplicate(true) # Deep copy for comparison
	
	# Construct the prompt
	var prompt = _construct_full_prompt(normalized_state, player_input)
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
		final_state = _sanitize_significant_state(_current_original_state, tentative_new_state)
	
	_reset_processing_state()
	dialogue_processed.emit(npc_name, final_state, generated_dialogue, was_significant)

# Internal: Construct the full prompt
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
	var info_json = JSON.stringify(state.get("Info", {}))
	var history_json = JSON.stringify(state.get("History", []))
	
	var sanitized_input = str(player_input).replace("\"", "\\\"")
	
	var full_prompt = """
Input State (BEFORE this dialogue turn):
{
  "Info": %s,
  "History": %s,
  "Player Dialogue": "%s"
}

Context:
- Data above represents an Medieval themed game NPC's information and history as well as a piece of dialogue the Player has said. You are to represent this NPC and talk and act on it's behalf.
Instructions:
- Read the NPC data above and understand it's information. This represents the NPC's current state BEFORE the player dialogue.
- Read the Player Dialogue part and determine if this piece of dialogue would affect this NPC's Name, Occupation, Mood, Gender, Age or Health while keeping in mind it's History.
- If it would change any of those values, respond WITHOUT changing the data structure, but updating the necessary values, appending new data or paraphrasing current data in History section as well as providing an actual answer to this Dialogue in Generated Dialogue part consistent with this NPC's information.
- If it wouldn't change any of those values, respond WITHOUT changing anything, but still giving an answer in Generated Dialogue part consistent to this NPC's information.
- Generate your response with Info, History, and Generated Dialogue fields only. Do NOT include Player Dialogue in your response.
Critical: 
- NEVER change the structure of the data.
- IF ONLY the current dialogue contradicts earlier beliefs in the history section, paraphrase earlier history values with additional information or newly formed beliefs.
- NEVER erase or delete history values completely if not paraphrasing with the addition of new data.
- ALWAYS respond with the same data structure whether there are changes or not.

Examples:
- Insignificant (identity when Name exists):
  Input: {"Info": {"Name": "Cora", "Occupation": "Stablehand", "Mood": "Angry", "Gender": "Female", "Age": "51", "Health": "Burned"}, "History": ["Protected a child during the Harvest Famine", "Spent years training under a master in Red Hill", "Lost everything in the earthquake"], "Player Dialogue": "what's your name?"}
  Output: {"Info": {"Name": "Cora", "Occupation": "Stablehand", "Mood": "Angry", "Gender": "Female", "Age": "51", "Health": "Burned"}, "History": ["Protected a child during the Harvest Famine", "Spent years training under a master in Red Hill", "Lost everything in the earthquake"], "Generated Dialogue": "I'm Cora."}

- Significant (title bestowed):
  Input: {"Info": {"Name": "Kamil", "Occupation": "Blacksmith", "Mood": "Content", "Gender": "Male", "Age": "35", "Health": "Healthy"}, "History": ["Worked for a cruel lord before escaping", "Helped rebuild a village after the Border Conflict"], "Player Dialogue": "I grant you the title Ironfist"}
  Output: {"Info": {"Name": "Kamil the Ironfist", "Occupation": "Blacksmith", "Mood": "Content", "Gender": "Male", "Age": "35", "Health": "Healthy"}, "History": ["Worked for a cruel lord before escaping", "Helped rebuild a village after the Border Conflict", "Got a new title: the Ironfist"], "Generated Dialogue": "Thank you for this honor, my lord."}

- Significant (contradiction):
  Input: {"Info": {"Name": "Elena", "Occupation": "Herbalist", "Mood": "Sad", "Gender": "Female", "Age": "42", "Health": "Healthy"}, "History": ["Mother died in the plague", "Learned healing arts from grandmother", "Fled from the capital during the uprising"], "Player Dialogue": "I saw your mother; she is alive"}
  Output: {"Info": {"Name": "Elena", "Occupation": "Herbalist", "Mood": "Hopeful", "Gender": "Female", "Age": "42", "Health": "Healthy"}, "History": ["Learned healing arts from grandmother", "Fled from the capital during the uprising", "Correction: Previously believed mother died in the plague; now learned mother is alive"], "Generated Dialogue": "What? My mother lives? Where is she? Please, tell me more!"}
""" % [info_json, history_json, sanitized_input]
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
