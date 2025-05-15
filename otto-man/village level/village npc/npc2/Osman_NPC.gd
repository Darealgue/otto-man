extends CharacterBody2D

# Keep UI/Animation refs if needed
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var action_label = $ActionLabel # Keep if you want to display Mood, etc.

# Autoload reference
var llama_service = null

var NPC_Info = {
	"Info": {
			"Name": "Osman",
			"Occupation": "Farmer",
			"Mood": "Angry",
			"Gender": "Male",
			"Age": "45",
			"Health": "Weak eyesight"
		},
		"History": [
			"Lost his land due to unfair taxes",
			"Got into a brutal fight with a noble's guards",
			"His only son ran away to become a mercenary"
		],
		# Add the DialogueHistory field, initialized or with example data
		"DialogueHistory": {
			"Dialogue with Tax Collector": {
				"speaker": "The law is the law, Osman. Pay what you owe, or suffer the consequences.",
				"self": "*slams fist on the table* You leeches drain us dry while we starve. One day, someone will stand up to you."
			}
			# Add more significant past dialogues here if desired
		}
}

# Variables to hold state during async LLM call
var _is_waiting_for_llm = false
var _original_info_state = {}
var _original_history_state = []
var _original_dialogue_history_state = {} # Store original dialogue history
var _current_player_input = ""
var _conversation_turn_count = 0 # Add conversation turn counter


# --- Godot Lifecycle Functions ---
func _ready():
	# Wait one frame potentially for C# autoloads
	await get_tree().process_frame

	# Connect to LlamaService (using Autoload access)
	if not LlamaService.is_connected("GenerationComplete", Callable(self, "_on_llama_generation_complete")):
		var error_code = LlamaService.connect("GenerationComplete", Callable(self, "_on_llama_generation_complete"))
		if error_code != OK:
			printerr("Osman_NPC: Failed to connect GenerationComplete signal: Error ", error_code)
	elif not LlamaService.IsInitialized():
		printerr("Osman_NPC: Warning - LlamaService found but reports not initialized in _ready.")


	# Initial state setup
	animated_sprite_2d.play("idle")
	update_action_label()


func update_action_label():
	# Modify this to show relevant info, e.g., current Mood
	if NPC_Info.has("Info") and NPC_Info["Info"].has("Mood"):
		action_label.text = "Mood: %s" % NPC_Info["Info"]["Mood"]
	else:
		action_label.text = "Mood: Unknown"
	if _is_waiting_for_llm:
		action_label.text += "\n(Thinking...)" # Using \n for newline consistency


# --- Dialogue Processing (Entry point from UI/Interaction Manager) ---
func process_player_dialogue(player_input: String):
	# Use direct Autoload access
	if not LlamaService.IsInitialized():
		push_error("Osman_NPC: LlamaService not available or not initialized.")
		show_npc_speech(NPC_Info["Info"]["Name"], "...")
		return

	if _is_waiting_for_llm:
		push_warning("Osman_NPC: Already waiting for LLM response.")
		return

	_current_player_input = player_input
	print("GDScript (Osman): Player said: ", _current_player_input)

	# 1. Increment turn count BEFORE constructing prompt
	_conversation_turn_count += 1

	# 2. Store original state for comparison (duplicate needed!)
	# We store state *before* the LLM potentially modifies it based on the current input
	_original_info_state = NPC_Info["Info"].duplicate(true) # Deep duplicate
	_original_history_state = NPC_Info["History"].duplicate(true) # Deep duplicate
	_original_dialogue_history_state = NPC_Info["DialogueHistory"].duplicate(true) # Store original dialogue history

	# 3. Construct the prompt string (now context-aware: full or hybrid)
	var prompt_to_send = _construct_full_prompt(NPC_Info, _current_player_input)
	if prompt_to_send.is_empty():
		push_error("Osman_NPC: Failed to construct prompt.")
		_conversation_turn_count = 0 # Reset count on error
		return

	# 4. Call LlamaService asynchronously
	_is_waiting_for_llm = true
	update_action_label() # Show "Thinking..."
	LlamaService.GenerateResponseAsync(prompt_to_send, 350) # Increased max tokens
	print("GDScript (Osman): Called GenerateResponseAsync. Waiting for signal...")


# Signal handler called by LlamaService when generation finishes
func _on_llama_generation_complete(result_string: String):
	# Only process if this specific NPC was waiting for a response
	if not _is_waiting_for_llm:
		return # Exit if this NPC wasn't the one waiting
	
	print("GDScript (Osman): Received generation_complete signal.") # Log kept for consistency, check helps
	# Trim whitespace from the raw response
	var trimmed_result_string = result_string.strip_edges()
	# print("\n--- Full LLM Response (Osman) ---\n" + trimmed_result_string + "\n---------------------------------") # Print trimmed string <<< COMMENT OUT
	_is_waiting_for_llm = false
	update_action_label() # Remove "Thinking..."
	
	# Check trimmed string before parsing
	if trimmed_result_string == null or trimmed_result_string.is_empty():
		push_error("GDScript (Osman): LLM failed to generate a response (trimmed result_string is empty).")
		show_npc_speech(NPC_Info["Info"]["Name"], "I... don't know what to say.") # Placeholder error reply
		return
	
	# Attempt to parse using Godot's built-in JSON parser
	var parsed_result = null
	var json_parser_helper = JSON.new()
	var error_code = json_parser_helper.parse(trimmed_result_string)

	if error_code != OK:
		var error_line = json_parser_helper.get_error_line()
		var error_msg = json_parser_helper.get_error_message()
		push_error("GDScript (Osman): Godot JSON.parse failed. Error '%s' at line %d.\nRaw LLM Response:\n%s" % [error_msg, error_line, trimmed_result_string])
		parsed_result = null
	else:
		parsed_result = json_parser_helper.get_data()

	# Check if parsing succeeded and the result is a Dictionary
	if typeof(parsed_result) != TYPE_DICTIONARY:
		# Error messages are now more specific from the block above
		# var error_string = json_string_to_parse if not json_string_to_parse.is_empty() else trimmed_result_string
		# push_error("GDScript (Osman): LLM response was not valid JSON.\nAttempted to parse: %s" % error_string)
		show_npc_speech(NPC_Info["Info"]["Name"], "My thoughts are scrambled...") # Placeholder error reply
		return
	var response_data = parsed_result as Dictionary

	# 6. Extract data
	# Use .get() with default values for safety
	var new_info = response_data.get("Info", {}) as Dictionary
	var new_history = response_data.get("History", []) as Array
	var generated_dialogue = response_data.get("Generated Dialogue", "...") as String # Default to "..."
	var new_dialogue_history = response_data.get("Dialogue History", {}) as Dictionary # Extract Dialogue History

	# Check specifically if Generated Dialogue is missing, as that was the last error
	if not response_data.has("Generated Dialogue"):
		push_error("GDScript (Osman): LLM output was valid JSON but missing the 'Generated Dialogue' field.")
		# Keep generated_dialogue as "..." (already defaulted)
		# Potentially add logic here to handle this specific error case if needed
	elif generated_dialogue.is_empty(): # Log if it's present but empty
		push_warning("GDScript (Osman): LLM response parsed okay, but 'Generated Dialogue' was empty.")
		generated_dialogue = "..." # Fallback dialogue

	# 7. Determine Significance by comparing (primarily Dialogue History now for logging)
	var was_significant = _did_state_change(
		_original_info_state, new_info,
		_original_history_state, new_history,
		_original_dialogue_history_state, new_dialogue_history
	)
	print("GDScript (Osman): Dialogue was significant (based on state change)? ", was_significant)

	# 8. Update NPC internal state (LLM output IS the new state)
	NPC_Info["Info"] = new_info
	NPC_Info["History"] = new_history
	NPC_Info["DialogueHistory"] = new_dialogue_history # Update internal Dialogue History
	update_action_label() # Update mood display

	# 9. Display generated dialogue
	show_npc_speech(NPC_Info["Info"]["Name"], generated_dialogue)

	# 10. Log to diary (including significance flag)
	# log_to_diary(NPC_Info["Info"]["Name"], _current_player_input, generated_dialogue, was_significant)


# --- Helper function implementations (STUBS - NEED TO BE IMPLEMENTED) ---

# Constructs the prompt string based on our established format
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
	var npc_name = state.get("Info", {}).get("Name", "NPC") # Get NPC name for prompt
	var info_json = JSON.stringify(state.get("Info", {}))
	var history_json = JSON.stringify(state.get("History", []))
	var dialogue_history_json = JSON.stringify(state.get("DialogueHistory", {})) # Stringify Dialogue History

	# Always use the detailed prompt format
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
	- If the dialogue provides new or superseding information directly impacting the NPC's *attributes* (those represented by the existing keys in the "Info" field like name, age, gender, mood, occupation, etc.), update the "Info" field in the output JSON. **CRITICAL RULE: You MUST only use the exact same set of keys for "Info" that were provided in the Input State's "Info" object. YOU ARE NOT ALLOWED TO ADD NEW KEYS to the "Info" object.** Change the values of the existing keys as appropriate. For example, if a title is bestowed and the Input State's "Info" object does NOT contain a 'Title' key, you MUST append the title to the existing "Name" value (e.g., Input "Name": "Osman" becomes Output "Name": "Osman the Resolute"). If an existing key can logically store the new information (like "Mood", "Age", "Occupation"), update its value.
	- ALWAYS append a short description of the significant event or new memory to the "History" array in the output JSON.
	- ALWAYS add a new entry to "DialogueHistory" in the output JSON, summarizing this significant interaction. The key for this new entry should be a short, descriptive title for the dialogue turn (e.g., "News About Son", "Threat from Player"). The value should be an object containing player and NPC lines (e.g., {"Player": "...", "%s": "..."}).
- IF INSIGNIFICANT:
	- The "Info", "History", AND "DialogueHistory" fields in the output JSON MUST be ABSOLUTELY IDENTICAL to the Input State provided.
	- DO NOT add any new entries to "DialogueHistory".
	- Make NO CHANGES WHATSOEVER to these three fields if the dialogue is insignificant.
- The "Generated Dialogue" field MUST always be present and contain the NPC's direct response.

---

EXAMPLE 1 (Insignificant Dialogue):

Input State:
{
  "Info": {"Name":"Osman", "Occupation":"Farmer", "Mood":"Angry", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "The law is the law, Osman. Pay what you owe...", "self": "*slams fist... One day, someone will stand up to you."}
  }
}

Player Dialogue: "Player":"Hello how are you?"

Output JSON:
{
  "Info": {"Name":"Osman", "Occupation":"Farmer", "Mood":"Angry", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "The law is the law, Osman. Pay what you owe...", "self": "*slams fist... One day, someone will stand up to you."}
  },
  "Generated Dialogue": "Hmph. What do you want?"
}

---

EXAMPLE 2 (Significant Dialogue - Plot):

Input State:
{
  "Info": {"Name":"Osman", "Occupation":"Farmer", "Mood":"Angry", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "...", "self": "..."}
  }
}

Player Dialogue: "Player":"Osman, I saw your son near the northern border. He looked well, leading a band of sellswords."

Output JSON:
{
  "Info": {"Name":"Osman", "Occupation":"Farmer", "Mood":"Worried/Relieved", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary", "Learned from the player his son is alive near the northern border"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "...", "self": "..."},
	"News About Son": {"Player":"Osman, I saw your son near the northern border...", "Osman": "My boy... alive? ... Thank you for telling me."}
  },
  "Generated Dialogue": "My boy... alive? Leading mercenaries? Gods, I hope he stays safe out there. Thank you for telling me."
}

---

EXAMPLE 3 (Significant Dialogue - Title Bestowed):

Input State:
{
  "Info": {"Name":"Osman", "Occupation":"Farmer", "Mood":"Angry", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "The law is the law, Osman. Pay what you owe...", "self": "*slams fist... One day, someone will stand up to you."}
  }
}

Player Dialogue: "Player":"Osman, from now on you shall be known as Osman the Resolute!"

Output JSON:
{
  "Info": {"Name":"Osman the Resolute", "Occupation":"Farmer", "Mood":"Surprised", "Gender":"Male", "Age":"45", "Health":"Weak eyesight"},
  "History": ["Lost his land due to unfair taxes", "Got into a brutal fight with a noble's guards", "His only son ran away to become a mercenary", "Bestowed the title 'the Resolute' by the player"],
  "DialogueHistory": {
	"Dialogue with Tax Collector": {"speaker": "The law is the law, Osman. Pay what you owe...", "self": "*slams fist... One day, someone will stand up to you."},
	"Title Bestowed": {"Player":"Osman, from now on you shall be known as Osman the Resolute!", "Osman": "The Resolute? I... I will try to live up to it."}
  },
  "Generated Dialogue": "The Resolute? I... I will try to live up to it."
}

---

NOW, PROCESS THE FOLLOWING INPUT AND PROVIDE ONLY THE JSON OUTPUT:

Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "Player":"%s"
""" % [info_json, history_json, dialogue_history_json, player_input.replace('"', '\"'), npc_name, info_json, history_json, dialogue_history_json, player_input.replace('"', '\"')] # Provide args

	# print("Constructed Prompt:\n", full_prompt) # Debug print - Re-enable if needed
	return full_prompt


func _compare_dialogue_histories(dh1: Dictionary, dh2: Dictionary) -> bool:
	if dh1.size() != dh2.size():
		# print("_compare_dialogue_histories: Size mismatch")
		return true # Changed (different number of entries)

	for title in dh1:
		if not dh2.has(title):
			# print("_compare_dialogue_histories: Title '%s' missing in new history" % title)
			return true # Changed (title removed or renamed)
		
		var entry1 = dh1[title]
		var entry2 = dh2[title]

		# Ensure both entries are dictionaries as expected
		if typeof(entry1) != TYPE_DICTIONARY or typeof(entry2) != TYPE_DICTIONARY:
			# print("_compare_dialogue_histories: Type mismatch for entry '%s'" % title)
			if entry1 != entry2: return true # Fallback to direct comparison if not dicts
			continue # Or treat as unchanged if types are same but not dicts (should not happen with GBNF)

		# Compare the inner dictionaries (e.g., {"speaker": "...", "self": "..."})
		# by stringifying THEM with sorted keys.
		var entry1_str = JSON.stringify(entry1, "\t", true) # sort_keys=true for inner dict
		var entry2_str = JSON.stringify(entry2, "\t", true) # sort_keys=true for inner dict
		
		if entry1_str != entry2_str:
			# print("_compare_dialogue_histories: Content mismatch for entry '%s'" % title)
			# print("Entry1: ", entry1_str)
			# print("Entry2: ", entry2_str)
			return true # Changed (content of an entry differs)
			
	return false # No changes detected


# Compares old and new state dictionaries/arrays to see if changes occurred
func _did_state_change(old_info: Dictionary, new_info: Dictionary,
					   old_history: Array, new_history: Array,
					   old_dialogue_history: Dictionary, new_dialogue_history: Dictionary) -> bool: 

	# Convert states to comparable strings (handles order differences, basic types)
	var old_info_str = JSON.stringify(old_info, "\t", true) # Use stringify for consistent comparison, sort_keys=true
	var new_info_str = JSON.stringify(new_info, "\t", true) # sort_keys=true
	var old_history_str = JSON.stringify(old_history, "\t", false) # History is an array, order matters, sort_keys not applicable directly
	var new_history_str = JSON.stringify(new_history, "\t", false) # History is an array, order matters
	# Removed direct stringification of entire dialogue history

	# Check if any state component has changed
	if old_info_str != new_info_str:
		print("_did_state_change: Info changed")
		return true
	if old_history_str != new_history_str:
		print("_did_state_change: History changed")
		return true
	
	if _compare_dialogue_histories(old_dialogue_history, new_dialogue_history):
		print("_did_state_change: DialogueHistory changed")
		return true

	# If none of the stringified states differ, assume insignificant
	return false


# Displays the NPC's dialogue in the game UI
func show_npc_speech(_npc_name: String, text: String):
	print("Osman says: ", text)
	# TODO: Implement your actual UI update logic here
	# e.g., get_node("SpeechBubble").show_text(text)
	pass


# Logs the conversation turn to the diary system
#func log_to_diary(npc_name: String, player_text: String, npc_text: String, significant: bool):
#	print("Diary Log (%s): Player: '%s' / NPC: '%s' (Significant: %s)" % [npc_name, player_text, npc_text, significant])
#	# TODO: Get your DiaryManager node/autoload and call its logging function
#	# e.g., DiaryManager.add_entry(npc_name, player_text, npc_text, significant)
#	pass


# --- Interaction Area Functions (Keep or adapt as needed) ---

func _on_interaction_area_area_entered(_area: Area2D) -> void:
	# Assumes you have an OptionsPanel node as child of InteractionArea
	var options_panel = $InteractionArea.get_node_or_null("OptionsPanel")
	if options_panel:
		options_panel.show()


func _on_interaction_area_area_exited(_area: Area2D) -> void:
	# Assumes you have an OptionsPanel node as child of InteractionArea
	var options_panel = $InteractionArea.get_node_or_null("OptionsPanel")
	if options_panel:
		options_panel.hide()
	# Assumes NpcInteractionManager is an Autoload or globally accessible
	NpcInteractionManager.CloseDialogueWindow()
	_conversation_turn_count = 0 # Reset turn counter when player leaves
	print("GDScript (Osman): Player exited area, conversation turn count reset.")


func _on_dialogue_button_pressed() -> void:
	NpcInteractionManager.SelectedNPC = NPC_Info["Info"]["Name"]
	NpcInteractionManager.OpenDialogueWindow() # This should eventually lead to process_player_dialogue being called
