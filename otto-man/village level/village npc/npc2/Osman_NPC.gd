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
		# Removed DialogueHistory_Context as it's replaced by the actual DialogueHistory
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
	LlamaService.GenerateResponseAsync(prompt_to_send, 256)
	print("GDScript (Osman): Called GenerateResponseAsync. Waiting for signal...")


# Signal handler called by LlamaService when generation finishes
func _on_llama_generation_complete(result_string: String):
	# Only process if this specific NPC was waiting for a response
	if not _is_waiting_for_llm:
		return # Exit if this NPC wasn't the one waiting
	
	print("GDScript (Osman): Received generation_complete signal.") # Log kept for consistency, check helps
	# Trim whitespace from the raw response
	var trimmed_result_string = result_string.strip_edges()
	print("\n--- Full LLM Response (Osman) ---\n" + trimmed_result_string + "\n---------------------------------") # Print trimmed string
	_is_waiting_for_llm = false
	update_action_label() # Remove "Thinking..."
	
	# Check trimmed string before parsing
	if trimmed_result_string == null or trimmed_result_string.is_empty():
		push_error("GDScript (Osman): LLM failed to generate a response (trimmed result_string is empty).")
		show_npc_speech(NPC_Info["Info"]["Name"], "I... don't know what to say.") # Placeholder error reply
		return
	
	# Attempt to extract JSON block robustly by finding the first '{' and its matching '}'
	var extracted_json_block = ""
	var parsed_result = null
	
	var json_start = trimmed_result_string.find("{")
	if json_start != -1:
		var brace_count = 0
		var json_end = -1
		for i in range(json_start, trimmed_result_string.length()):
			var char = trimmed_result_string[i]
			if char == '{':
				brace_count += 1
			elif char == '}':
				brace_count -= 1
				if brace_count == 0: # Found the matching closing brace for the first opening brace
					json_end = i
					break
				elif brace_count < 0:
					# This shouldn't normally happen if starting search from the first '{'
					push_warning("GDScript (Osman): Found closing brace before matching opening brace during JSON extraction.")
					break 

		if json_end != -1:
			# Extract the substring from the first '{' to the matched '}'
			extracted_json_block = trimmed_result_string.substr(json_start, json_end - json_start + 1)
			
			# Now attempt to parse ONLY the extracted block
			var json_parser = JSON.new()
			var error_code = json_parser.parse(extracted_json_block)

			if error_code != OK:
				var error_line = json_parser.get_error_line()
				var error_msg = json_parser.get_error_message()
				# Log the block we TRIED to parse
				push_error("GDScript (Osman): JSON parsing failed. Error '%s' at line %d:\n%s" % [error_msg, error_line, extracted_json_block])
				parsed_result = null
			else:
				# Success! Get the actual result
				parsed_result = json_parser.get_data()
		else:
			# Could not find matching closing brace for the first opening brace
			push_error("GDScript (Osman): Could not find matching '}' for the initial '{' in LLM response: %s" % [trimmed_result_string])
			parsed_result = null
	else:
		# Could not find opening '{' at all
		push_error("GDScript (Osman): Could not find starting '{' in LLM response: %s" % [trimmed_result_string])
		parsed_result = null 

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
	var generated_dialogue = response_data.get("Generated Dialogue", "") as String
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
		_original_dialogue_history_state, new_dialogue_history # Pass dialogue history to checker
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
	log_to_diary(NPC_Info["Info"]["Name"], _current_player_input, generated_dialogue, was_significant)


# --- Helper function implementations (STUBS - NEED TO BE IMPLEMENTED) ---

# Constructs the prompt string based on our established format
func _construct_full_prompt(state: Dictionary, player_input: String) -> String:
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

Instructions: Respond strictly in the JSON format below. Determine significance based on initial instructions (reveals major plots, causes strong emotions, involves key actions/items, bestows titles). If significant, update Info, History, and/or DialogueHistory fields in the output JSON. If insignificant, Info, History, and DialogueHistory MUST be identical to the Input State. Provide ONLY the JSON output. The 'Generated Dialogue' field MUST always be included.

Output JSON:
{
  "Info": { ... current or updated info ... },
  "History": [ ... current or updated history ... ],
  "DialogueHistory": { ... current or updated dialogue history ... },
  "Generated Dialogue": "NPC's response here"
}

Rules for Significance & State Update:
- Significance Criteria: Dialogue is significant if it bestows titles, reveals major plot points, causes strong emotional reactions, involves important actions/items/decisions, or refers specifically to the NPC's unique history/personality.
- Insignificant Dialogue: Simple greetings, casual questions, generic statements.
- IF SIGNIFICANT: Update the "Info", "History" (append short description), and/or "DialogueHistory" (add a new entry summarizing the interaction) fields in the output JSON as appropriate. The new "DialogueHistory" entry key should be a short descriptive title.
- IF NOT SIGNIFICANT: The "Info", "History", AND "DialogueHistory" fields in the output JSON MUST be ABSOLUTELY IDENTICAL to the Input State provided below. Make NO CHANGES WHATSOEVER to these three fields if the dialogue is insignificant.
- The "Generated Dialogue" field MUST always be present in the output JSON.

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

NOW, PROCESS THE FOLLOWING INPUT AND PROVIDE ONLY THE JSON OUTPUT:

Input State:
{
  "Info": %s,
  "History": %s,
  "DialogueHistory": %s
}

Player Dialogue: "Player":"%s"

Output JSON:
""" % [info_json, history_json, dialogue_history_json, player_input.replace('"', '\\"'), info_json, history_json, dialogue_history_json, player_input.replace('"', '\\"')] # Provide args twice

	# print("Constructed Prompt:\\n", full_prompt) # Debug print - Re-enable if needed
	return full_prompt


# Compares old and new state dictionaries/arrays to see if changes occurred
func _did_state_change(old_info: Dictionary, new_info: Dictionary,
					   old_history: Array, new_history: Array,
					   old_dialogue_history: Dictionary, new_dialogue_history: Dictionary) -> bool: # Added dialogue history params

	# Convert states to comparable strings (handles order differences, basic types)
	var old_info_str = JSON.stringify(old_info, "\t", false) # Use stringify for consistent comparison
	var new_info_str = JSON.stringify(new_info, "\t", false)
	var old_history_str = JSON.stringify(old_history, "\t", false)
	var new_history_str = JSON.stringify(new_history, "\t", false)
	var old_dialogue_history_str = JSON.stringify(old_dialogue_history, "\t", false)
	var new_dialogue_history_str = JSON.stringify(new_dialogue_history, "\t", false)

	# Check if any state component has changed
	if old_info_str != new_info_str:
		print("_did_state_change: Info changed")
		return true
	if old_history_str != new_history_str:
		print("_did_state_change: History changed")
		return true
	if old_dialogue_history_str != new_dialogue_history_str:
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
func log_to_diary(npc_name: String, player_text: String, npc_text: String, significant: bool):
	print("Diary Log (%s): Player: '%s' / NPC: '%s' (Significant: %s)" % [npc_name, player_text, npc_text, significant])
	# TODO: Get your DiaryManager node/autoload and call its logging function
	# e.g., DiaryManager.add_entry(npc_name, player_text, npc_text, significant)
	pass


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
