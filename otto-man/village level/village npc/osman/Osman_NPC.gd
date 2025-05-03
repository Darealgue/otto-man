extends CharacterBody2D

# Movement/State Variables
var player_in_area = false
var dialogue_mode = false
var dialogue_label: Label = null
var dialogue_options_ui: Control = null
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var movement_speed = 40.0 # Osman might be slower
var nav_agent: NavigationAgent2D = null
var current_target_position: Vector2 = Vector2.ZERO

# LLM Integration Variables
var llama_service = null
var dialogue_history = []
var is_waiting_for_llm = false
var npc_name = "Osman"


func _ready():
	dialogue_label = get_node_or_null("DialogueLabel")
	dialogue_options_ui = get_node_or_null("DialogueOptionsUI")
	nav_agent = get_node_or_null("NavigationAgent2D")

	if not nav_agent:
		printerr("NavigationAgent2D node not found on %s! Movement disabled." % npc_name)

	if dialogue_label: dialogue_label.hide()
	if dialogue_options_ui: dialogue_options_ui.hide()

	llama_service = get_node_or_null("/root/LlamaService")
	if llama_service:
		if not llama_service.is_connected("GenerationComplete", Callable(self, "_on_LlamaService_GenerationComplete")):
			var error_code = llama_service.connect("GenerationComplete", Callable(self, "_on_LlamaService_GenerationComplete"))
			if error_code != OK:
				printerr("Failed to connect GenerationComplete signal: Error ", error_code)
		if not llama_service.IsInitialized():
			printerr("LlamaService not initialized when %s was ready!" % npc_name)
	else:
		printerr("LlamaService singleton not found! NPC %s cannot function." % npc_name)


func _physics_process(delta):
	var target_reached = false
	if nav_agent and not nav_agent.is_navigation_finished():
		target_reached = move_towards_target(delta)
	else:
		velocity.y += gravity * delta

	if target_reached or not nav_agent or nav_agent.is_navigation_finished():
		velocity.x = move_toward(velocity.x, 0, movement_speed)
		velocity.y += gravity * delta
	else:
		velocity.y += gravity * delta

	move_and_slide()

func move_towards_target(delta) -> bool:
	if not nav_agent or nav_agent.is_target_reached():
		velocity = Vector2.ZERO
		return true
	var current_pos = global_position
	var next_pos = nav_agent.get_next_path_position()
	var direction = current_pos.direction_to(next_pos)
	velocity = direction * movement_speed
	# Optional: Face direction
	# if direction.x != 0:
	#	$Sprite2D.flip_h = direction.x < 0
	return false


func interact_with_player(player_line: String):
	if is_waiting_for_llm:
		print("%s is already thinking..." % npc_name)
		show_dialogue("One moment, please.")
		return
	if not llama_service or not llama_service.IsInitialized():
		printerr("Cannot interact: LlamaService not ready for %s." % npc_name)
		show_dialogue("My apologies, my mind wanders.")
		return
	print("Player said to %s: %s" % [npc_name, player_line])
	dialogue_history.append({"player": player_line})
	if dialogue_history.size() > 15:
		dialogue_history.pop_front()
		dialogue_history.pop_front()
	dialogue_mode = true
	velocity = Vector2.ZERO
	show_dialogue("...")
	request_npc_response()

# --- LLM Functions (build_prompt, request_npc_response, _on_LlamaService_GenerationComplete, process_llm_response) --- 
func build_prompt() -> String:
	var prompt = "You are %s, a wise elder in a historical Ottoman village (2D pixel art game). Respond concisely in JSON format like this: {\"mood\": \"your_current_mood\", \"dialogue\": \"your_response_line\"}. Offer thoughtful but brief replies.
Current Conversation:
" % npc_name
	for entry in dialogue_history:
		if entry.has("player"): prompt += "Player: " + entry["player"] + "\n"
		elif entry.has("npc"): prompt += npc_name + ": " + entry["npc"] + "\n"
	prompt += "%s's Response (JSON):" % npc_name
	# print("Built Prompt for %s: %s" % [npc_name, prompt])
	return prompt

func request_npc_response():
	var prompt_string = build_prompt()
	if llama_service and llama_service.IsInitialized():
		is_waiting_for_llm = true
		print("Requesting response from LlamaService for %s..." % npc_name)
		llama_service.GenerateResponseAsync(prompt_string, 100)
	else:
		printerr("Cannot request response: LlamaService not available for %s." % npc_name)
		process_llm_response('{"mood": "contemplative", "dialogue": "Patience, these things take time."}')

func _on_LlamaService_GenerationComplete(response_text: String):
	print("%s received response from LlamaService: %s" % [npc_name, response_text])
	is_waiting_for_llm = false
	if response_text == null or response_text.strip_edges().empty():
		printerr("%s received null or empty response." % npc_name)
		process_llm_response('{"mood": "weary", "dialogue": "The words escape me."}')
	else:
		process_llm_response(response_text)

func process_llm_response(raw_response: String):
	print("Processing LLM Response for %s: %s" % [npc_name, raw_response])
	var parsed = JSON.parse_string(raw_response)
	var mood = "neutral"
	var dialogue_line = "..."
	if parsed == null:
		printerr("Failed to parse JSON response for %s: %s" % [npc_name, raw_response])
		if raw_response.strip_edges().length() > 0: dialogue_line = raw_response
		else: dialogue_line = "Perhaps another time."
		mood = "reserved"
	else:
		mood = parsed.get("mood", "neutral")
		dialogue_line = parsed.get("dialogue", "...")
		if dialogue_line.strip_edges().empty(): dialogue_line = "..."
	print("%s Mood: %s" % [npc_name, mood])
	print("%s Dialogue: %s" % [npc_name, dialogue_line])
	dialogue_history.append({"npc": dialogue_line})
	show_dialogue(dialogue_line)
# --- End LLM Functions ---

func show_dialogue(text: String):
	if dialogue_label:
		dialogue_label.text = text
		dialogue_label.show()
	else:
		print("NPC %s Dialogue: %s" % [npc_name, text])

func hide_dialogue():
	if dialogue_label: dialogue_label.hide()
	if dialogue_options_ui: dialogue_options_ui.hide()
	dialogue_mode = false

func set_target_position(new_target: Vector2): # Use Vector2
	current_target_position = new_target
	if nav_agent:
		nav_agent.target_position = current_target_position

func _on_interaction_area_body_entered(body):
	if body.is_in_group("player"):
		player_in_area = true
		print("Player entered %s's area" % npc_name)

func _on_interaction_area_body_exited(body):
	if body.is_in_group("player"):
		player_in_area = false
		print("Player exited %s's area" % npc_name)
		hide_dialogue()

func _input(event):
	if player_in_area and event.is_action_pressed("interact") and not dialogue_mode:
		interact_with_player("Peace be upon you, %s." % npc_name) 