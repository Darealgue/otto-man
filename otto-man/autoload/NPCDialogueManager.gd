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
	var new_dialogue_history = parsed_result.get("DialogueHistory", {}) as Dictionary
	var generated_dialogue = ""
	if parsed_result.has("Generated Dialogue"):
		generated_dialogue = parsed_result.get("Generated Dialogue", "")
	elif parsed_result.has("GeneratedDialogue"):
		generated_dialogue = parsed_result.get("GeneratedDialogue", "")
	generated_dialogue = str(generated_dialogue)
	if generated_dialogue.strip_edges() == "":
		generated_dialogue = "..."
	
	var tentative_new_state = {"Info": new_info, "History": new_history, "DialogueHistory": new_dialogue_history}
	var was_significant = _did_state_change(
		_current_original_state.get("Info", {}),
		_current_original_state.get("History", []),
		_current_original_state.get("DialogueHistory", {}),
		new_info, new_history, new_dialogue_history
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
	var dialogue_history_json = JSON.stringify(state.get("DialogueHistory", {}))
	
	var sanitized_input = str(player_input).replace("\"", "\\\"")
	
	var full_prompt = """
Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "%s"

Instructions:
1. Evaluate the Player Dialogue in the context of the NPC's current Input State (Info, History, DialogueHistory).
2. Determine if the dialogue is "Significant" or "Insignificant" based on the "Significance Criteria" and "Insignificant Dialogue" definitions below.
3. If Significant: Update "Info" and/or append a new event to "History" in the output JSON, and add exactly one new entry to "DialogueHistory".
4. If Insignificant: The "Info", "History", and "DialogueHistory" fields in the output JSON MUST be *exactly identical* to those in the Input State. Do not invent, remove, rename, or reformat entries.
5. ALWAYS include the "Generated Dialogue" field with the NPC's spoken response.
6. Provide ONLY the complete JSON output as specified by the GBNF grammar.

Significance Decision (CRITICAL):
- A dialogue is Significant ONLY if your OUTPUT "Info" or "History" differs from the INPUT.
- Changes to "DialogueHistory" ALONE are NEVER sufficient to be Significant. If not Significant, copy "DialogueHistory" exactly from the INPUT with no changes.

Key naming (CRITICAL - use EXACT keys):
- Use these exact keys in the top-level JSON: "Info", "History", "DialogueHistory", "Generated Dialogue" (with a space).
- Do NOT use placeholders like <AGE> or template markers. If a value is unknown, keep the original value as-is from the Input State.
- Do NOT add new keys to "Info". If a title is bestowed and there is no Title key, append it to the "Name" string (e.g., "Name": "NPC the Brave").

Examples (GUIDANCE):
- Insignificant (greeting / identity query when Name exists):
  Input Info.Name = "Cora"; Player Dialogue: "what's your name?" -> OUTPUT Info, History, DialogueHistory are IDENTICAL to INPUT; "Generated Dialogue": "I'm Cora."
- Significant (title bestowed):
  Input Info.Name = "Kamil"; Player Dialogue: "I grant you the title Ironfist" -> OUTPUT Info.Name = "Kamil the Ironfist"; History APPEND: "Got a new title: the Ironfist"; DialogueHistory ADD ONE: {"Dialogue with Player": {"speaker": "I grant you the title Ironfist", "self": "Thank you..."}}; "Generated Dialogue" first-person.
- Significant (contradiction):
  Input History includes "Mother died"; Player Dialogue: "I saw your mother; she is alive" -> OUTPUT History REMOVES the superseded entry and APPENDS: "Correction: Previously believed mother died; now learned mother is alive."; DialogueHistory ADD ONE: {"Dialogue with Player": {"speaker": "I saw your mother; she is alive", "self": "..."}}.

Generated Dialogue formatting (STRICT):
- Output MUST be the NPC's first-person line (I, me, my), with no name prefix.
- Do NOT include narration, descriptions, or stage directions; only the line the NPC says.
- Do NOT include the NPC's name anywhere in the Generated Dialogue.

DialogueHistory entry formatting (STRICT):
- Only add a DialogueHistory entry when the dialogue is Significant.
- You MUST NOT modify existing DialogueHistory entries; keep them BYTE-IDENTICAL to the Input State.
- Add exactly one new entry whose key is a short title (e.g., "Dialogue with Player").
- The new entry MUST be exactly: {"speaker": "<exact Player Dialogue>", "self": "<NPC first-person line>"}.

History mutation policy (STRICT):
- History represents the NPC's current believed facts and landmark personal events.
- When new information contradicts a prior entry, REMOVE the superseded entry and APPEND a single concise correction entry that explicitly references the prior belief and the new belief (e.g., "Correction: Previously believed mother died; now learned mother is alive.").
- Otherwise, when Significant, APPEND a new concise event describing what changed (e.g., "Got a new title: the Ironfist").
- Do not reorder unrelated entries; keep chronological order of changes.

Rules for Significance & State Update:
- Significance Criteria: Dialogue is significant if it bestows titles, reveals major plot points, causes strong emotional reactions in the NPC, involves important actions/items/decisions relevant to the NPC, or makes the NPC reveal something deep about their unique history/personality.
- Insignificant Dialogue: Simple greetings ("hello", "hi", "hey", "how are you?", etc.), basic identity queries (e.g., "what is your name?", "who are you?") when the Info already contains a Name, casual questions unrelated to core concerns, generic statements, or chit-chat that doesn't impact the NPC's state or understanding.
- IF SIGNIFICANT:
	- Update "Info" using only existing keys; append/update "History" per policy; and add exactly one new DialogueHistory entry per the strict format above.
- IF INSIGNIFICANT:
	- The "Info", "History", AND "DialogueHistory" fields MUST be ABSOLUTELY IDENTICAL (byte-for-byte) to the Input State provided.
- The "Generated Dialogue" field MUST always be present and contain the NPC's direct response.

NOW, PROCESS THE FOLLOWING INPUT AND PROVIDE ONLY THE JSON OUTPUT:

Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "%s"
""" % [info_json, history_json, dialogue_history_json, sanitized_input, info_json, history_json, dialogue_history_json, sanitized_input]
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
	
	# Compare DialogueHistory (order matters)
	var old_dialogue_history_str = JSON.stringify(old_dialogue_history, "\t", false)
	var new_dialogue_history_str = JSON.stringify(new_dialogue_history, "\t", false)
	if old_dialogue_history_str != new_dialogue_history_str:
		print("NPCDialogueManager: DialogueHistory changed")
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
	var empty_state = {"Info": {}, "History": [], "DialogueHistory": {}}
	dialogue_processed.emit(npc_name, empty_state, error_dialogue, false) 

# Ensure state has correct shapes
func _normalize_state(state: Dictionary) -> Dictionary:
	var info = state.get("Info", {})
	if typeof(info) != TYPE_DICTIONARY:
		info = {}
	var history = state.get("History", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	var dialogue_history = state.get("DialogueHistory", {})
	if typeof(dialogue_history) != TYPE_DICTIONARY:
		dialogue_history = {}
	return {"Info": info, "History": history, "DialogueHistory": dialogue_history} 

# Merge/sanitize significant updates: keep Info key set identical, preserve DialogueHistory entries, and avoid history deletions
func _sanitize_significant_state(old_state: Dictionary, new_state: Dictionary) -> Dictionary:
	var old_info: Dictionary = old_state.get("Info", {})
	var old_history: Array = old_state.get("History", [])
	var old_dh: Dictionary = old_state.get("DialogueHistory", {})
	
	var in_info = new_state.get("Info", {})
	var in_history = new_state.get("History", [])
	var in_dh = new_state.get("DialogueHistory", {})
	
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
	
	# 3) DialogueHistory: preserve all original entries; only add exactly one new entry if Info or History changed and it matches the strict format
	var sanitized_dh: Dictionary = {}
	for key in old_dh.keys():
		sanitized_dh[key] = old_dh[key]
	if (info_changed or history_changed) and typeof(in_dh) == TYPE_DICTIONARY:
		for key in in_dh.keys():
			if not sanitized_dh.has(key):
				var entry = in_dh[key]
				var is_valid_entry = (
					typeof(entry) == TYPE_DICTIONARY and
					entry.has("speaker") and entry.has("self") and
					str(entry["speaker"]) == _current_player_input and
					str(entry["self"]) != _current_player_input
				)
				if is_valid_entry:
					sanitized_dh[key] = entry
					break
	
	return {"Info": sanitized_info, "History": sanitized_history, "DialogueHistory": sanitized_dh} 
