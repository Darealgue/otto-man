extends CharacterBody2D

# Keep UI/Animation refs if needed
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var action_label = $ActionLabel # Keep if you want to display Mood, etc.

# Autoload reference
var llama_service = null

# NPC State (Mirroring Osman's structure)
var NPC_Info = {
	"Info": {
		"Name": "Kamil",
		"Occupation": "Logger",
		"Mood": "Depressed",
		"Gender": "Male",
		"Age": "25",
		"Health": "Injured"
	},
	"History": [
		"Witnessed the murder of his own mother",
		"Fell in love with a girl in the same village",
		"Sprained own ankle"
	],
	"DialogueHistory": {
		"Dialogue with Bandits": {
			"speaker": "If you want to take revenge some day, I'll be waiting for you, and I'll be ready.",
			"self": "*cries in agony*"
		}
	}
}

# Variables to hold state during async LLM call
var _is_waiting_for_llm = false # Use underscore prefix matching Osman's var
var _original_info_state = {}
var _original_history_state = []
var _original_dialogue_history_state = {} # Store original dialogue history
var _current_player_input = ""
var _conversation_turn_count = 0 # Add conversation turn counter

# Remove incorrect interaction state variables
# var player_in_area = false
# var dialogue_mode = false

# Keep UI node refs if needed (but interaction flow is via manager)
var dialogue_label: Label = null # Keep if used by show_npc_speech
var dialogue_options_ui: Control = null # Keep if used by show_npc_speech

# Movement related (2D)
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var movement_speed = 50.0 # Adjust speed for 2D pixels/sec
var nav_agent: NavigationAgent2D = null
var current_target_position: Vector2 = Vector2.ZERO


# --- Godot Lifecycle Functions ---
func _ready():
	# Wait one frame potentially for C# autoloads
	await get_tree().process_frame

	dialogue_label = get_node_or_null("DialogueLabel") # Adjust path if needed
	dialogue_options_ui = get_node_or_null("DialogueOptionsUI") # Adjust path if needed
	nav_agent = get_node_or_null("NavigationAgent2D") # Get 2D agent

	if not nav_agent:
		printerr("NavigationAgent2D node not found on %s! Movement disabled." % NPC_Info["Info"]["Name"])

	if dialogue_label: dialogue_label.hide()
	if dialogue_options_ui: dialogue_options_ui.hide()

	# Connect to LlamaService (using Autoload access)
	# No need to store llama_service variable if accessing directly
	if not LlamaService.is_connected("GenerationComplete", Callable(self, "_on_llama_generation_complete")):
		var error_code = LlamaService.connect("GenerationComplete", Callable(self, "_on_llama_generation_complete"))
		if error_code != OK:
			printerr("Kamil_NPC: Failed to connect GenerationComplete signal: Error ", error_code)
	# Check initialization status (Optional - manager should handle init)
	elif not LlamaService.IsInitialized():
		printerr("Kamil_NPC: Warning - LlamaService found but reports not initialized in _ready.")


	animated_sprite_2d.play("idle")
	update_action_label() # Update label initially


func update_action_label():
	# Modify this to show relevant info, e.g., current Mood
	if NPC_Info.has("Info") and NPC_Info["Info"].has("Mood"):
		action_label.text = "Mood: %s" % NPC_Info["Info"]["Mood"]
	else:
		action_label.text = "Mood: Unknown"
	if _is_waiting_for_llm:
		action_label.text += "\n(Thinking...)"


# --- Dialogue Processing ---

# This function should be called by your UI (e.g., NpcInteractionManager)
# when the player submits their dialogue input.
func process_player_dialogue(player_input: String):
	# Use direct Autoload access
	if not LlamaService.IsInitialized():
		push_error("Kamil_NPC: LlamaService not available or not initialized.")
		show_npc_speech(NPC_Info["Info"]["Name"], "...")
		return

	if _is_waiting_for_llm:
		push_warning("Kamil_NPC: Already waiting for LLM response.")
		return

	_current_player_input = player_input
	print("GDScript (Kamil): Player said: ", _current_player_input)

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
		push_error("Kamil_NPC: Failed to construct prompt.")
		_conversation_turn_count = 0 # Reset count on error
		return

	# 4. Call LlamaService asynchronously
	_is_waiting_for_llm = true
	update_action_label() # Show "Thinking..."
	LlamaService.GenerateResponseAsync(prompt_to_send, 256)
	print("GDScript (Kamil): Called GenerateResponseAsync. Waiting for signal...")


# Signal handler called by LlamaService when generation finishes
func _on_llama_generation_complete(result_string: String):
	# Only process if this specific NPC was waiting for a response
	if not _is_waiting_for_llm:
		return # Exit if this NPC wasn't the one waiting
		
	print("GDScript (Kamil): Received GenerationComplete signal.") # Log kept for consistency, check helps
	# Trim whitespace from the raw response
	var trimmed_result_string = result_string.strip_edges()
	# print("\n--- Full LLM Response (Kamil) ---\n" + trimmed_result_string + "\n---------------------------------") # Print trimmed string <<< COMMENT OUT
	_is_waiting_for_llm = false
	update_action_label() # Remove "Thinking..."
	
	# Check trimmed string before parsing
	if trimmed_result_string == null or trimmed_result_string.is_empty():
		push_error("GDScript (Kamil): LLM failed to generate a response (trimmed result_string is empty).")
		show_npc_speech(NPC_Info["Info"]["Name"], "I... don't know what to say.") # Placeholder error reply
		return
	
	# Attempt to parse using Godot's built-in JSON parser
	var parsed_result = null
	var json_parser_helper = JSON.new()
	var error_code = json_parser_helper.parse(trimmed_result_string)

	if error_code != OK:
		var error_line = json_parser_helper.get_error_line()
		var error_msg = json_parser_helper.get_error_message()
		push_error("GDScript (Kamil): Godot JSON.parse failed. Error '%s' at line %d.\nRaw LLM Response:\n%s" % [error_msg, error_line, trimmed_result_string])
		parsed_result = null
	else:
		parsed_result = json_parser_helper.get_data()

	# Check if parsing succeeded and the result is a Dictionary
	if typeof(parsed_result) != TYPE_DICTIONARY:
		# Error messages are now more specific from the block above
		# var error_string = json_string_to_parse if not json_string_to_parse.is_empty() else trimmed_result_string
		# push_error("GDScript (Kamil): LLM response was not valid JSON.\nAttempted to parse: %s" % error_string)
		show_npc_speech(NPC_Info["Info"]["Name"], "My thoughts are scrambled...") # Placeholder error reply
		return
	var response_data = parsed_result as Dictionary

	# 6. Extract data
	# Use .get() with default values for safety
	var new_info = response_data.get("Info", {}) as Dictionary
	var new_history = response_data.get("History", []) as Array
	var generated_dialogue = response_data.get("Generated Dialogue", "") as String
	var new_dialogue_history = response_data.get("Dialogue History", {}) as Dictionary # Extract Dialogue History

	# Check specifically if Generated Dialogue is missing
	if not response_data.has("Generated Dialogue"):
		push_error("GDScript (Kamil): LLM output was valid JSON but missing the 'Generated Dialogue' field.")
		# Keep generated_dialogue as "..." (already defaulted)
	elif generated_dialogue.is_empty(): # Log if it's present but empty
		push_warning("GDScript (Kamil): LLM response parsed okay, but 'Generated Dialogue' was empty.")
		generated_dialogue = "..." # Fallback dialogue

	# 7. Determine Significance by comparing (primarily Dialogue History now for logging)
	var was_significant = _did_state_change(
		_original_info_state, new_info,
		_original_history_state, new_history,
		_original_dialogue_history_state, new_dialogue_history # Pass dialogue history to checker
	)
	print("GDScript (Kamil): Dialogue was significant (based on state change)? ", was_significant)

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

Instructions: Determine significance based on initial instructions (reveals major plots, causes strong emotions, involves key actions/items, bestows titles). If significant, update Info, History, and/or DialogueHistory fields in the output JSON. If insignificant, Info, History, and DialogueHistory MUST be identical to the Input State. Provide ONLY the JSON output. The 'Generated Dialogue' field MUST always be included.

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
  "Info": {"Name":"Kamil", "Occupation":"Logger", "Mood":"Depressed", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"If you want to take revenge some day...", "self":"*cries in agony*"}
  }
}

Player Dialogue: "Player":"Hello how are you?"

Output JSON:
{
  "Info": {"Name":"Kamil", "Occupation":"Logger", "Mood":"Depressed", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"If you want to take revenge some day...", "self":"*cries in agony*"}
  },
  "Generated Dialogue": "Not great... been struggling lately."
}

---

EXAMPLE 2 (Significant Dialogue - Title):

Input State:
{
  "Info": {"Name":"Kamil", "Occupation":"Logger", "Mood":"Depressed", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"...", "self":"..."}
  }
}

Player Dialogue: "Player":"Now I am giving you the title of Eagle!"

Output JSON:
{
  "Info": {"Name":"Kamil the Eagle", "Occupation":"Logger", "Mood":"Proud/Honored", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle", "Was given the title 'Eagle' by the player"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"...", "self":"..."},
	"Given Title Eagle": {"Player":"Now I am giving you the title of Eagle!", "Kamil": "That is an honor, I wish my mother could see this day..." }
  },
  "Generated Dialogue": "That is an honor, I wish my mother could see this day..."
}

---

EXAMPLE 3 (Significant Dialogue - Item/Plot):

Input State:
{
  "Info": {"Name":"Kamil", "Occupation":"Logger", "Mood":"Depressed", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"...", "self":"..."}
  }
}

Player Dialogue: "Player":"Kamil, I found this Sunpetal herb. It's said to mend injuries quickly. Take it for your ankle."

Output JSON:
{
  "Info": {"Name":"Kamil", "Occupation":"Logger", "Mood":"Grateful/Hopeful", "Gender":"Male", "Age":"25", "Health":"Injured"},
  "History": ["Witnessed the murder of his own mother", "Fell in love with a girl in the same village", "Sprained own ankle", "Received Sunpetal herb from player for ankle"],
  "DialogueHistory": {
	"Dialogue with Bandits": {"speaker":"...", "self":"..."},
	"Received Sunpetal Herb": {"Player":"Kamil, I found this Sunpetal herb... Take it...", "Kamil": "Thank you! Maybe this will finally help..."}
  },
  "Generated Dialogue": "Thank you! Maybe this will finally help..."
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
""" % [info_json, history_json, dialogue_history_json, player_input.replace('"', '\"'), info_json, history_json, dialogue_history_json, player_input.replace('"', '\"')] # Provide args twice

	# print("Constructed Prompt:\n", full_prompt) # Debug print - Re-enable if needed
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
	print("Kamil says: ", text)
	# TODO: Implement your actual UI update logic here
	# e.g., get_node("SpeechBubble").show_text(text)
	pass


# Logs the conversation turn to the diary system
func log_to_diary(npc_name: String, player_text: String, npc_text: String, significant: bool):
	print("Diary Log (%s): Player: '%s' / NPC: '%s' (Significant: %s)" % [npc_name, player_text, npc_text, significant])
	# TODO: Get your DiaryManager node/autoload and call its logging function
	# e.g., DiaryManager.add_entry(npc_name, player_text, npc_text, significant)
	pass


# --- Interaction Area / Button Signals (Mirroring Osman's structure) ---

func _on_interaction_area_area_entered(_area: Area2D) -> void:
	# Assumes this signal is connected from an Area2D child node named "InteractionArea"
	# Mirror Osman's logic: Show OptionsPanel?
	# IMPORTANT: Adjust the node path to match Kamil's scene structure
	var options_panel = $InteractionArea.get_node_or_null("OptionsPanel")
	if options_panel:
		options_panel.show()
	print("Player entered Kamil interaction area")


func _on_interaction_area_area_exited(_area: Area2D) -> void:
	# Assumes this signal is connected from an Area2D child node named "InteractionArea"
	# Mirror Osman's logic: Hide OptionsPanel? Close Dialogue Window?
	# IMPORTANT: Adjust the node path to match Kamil's scene structure
	var options_panel = $InteractionArea.get_node_or_null("OptionsPanel")
	if options_panel:
		options_panel.hide()
	# Assume NpcInteractionManager handles closing the main dialogue UI
	NpcInteractionManager.CloseDialogueWindow()
	_conversation_turn_count = 0 # Reset turn counter when player leaves
	print("GDScript (Kamil): Player exited area, conversation turn count reset.")
	print("Player exited Kamil interaction area")


func _on_dialogue_button_pressed() -> void:
	NpcInteractionManager.SelectedNPC = NPC_Info["Info"]["Name"]
	NpcInteractionManager.OpenDialogueWindow() # This manager method should eventually lead to process_player_dialogue
	print("Kamil dialogue button pressed")
