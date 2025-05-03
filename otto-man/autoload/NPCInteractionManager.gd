extends Node

var isDialogueOpen : bool = false
var SelectedNPC = ""

# Model filename constant
const LLAMA_MODEL_FILENAME = "Phi-3-mini-4k-instruct-q4.gguf"


func _ready():
	# Connect signals
	get_tree().root.connect("ready", Callable(self, "_initialize_llama_service"), CONNECT_ONE_SHOT)
	get_tree().connect("process_frame", Callable(self, "_check_close_request"), CONNECT_ONE_SHOT)


func _initialize_llama_service():
	await get_tree().process_frame

	# Initialize LlamaService if it exists and isn't already initialized
	# Use direct access for Autoload
	if not LlamaService.IsInitialized():
		print("NPCInteractionManager: Initializing LlamaService...")
		var success = LlamaService.Initialize(LLAMA_MODEL_FILENAME)
		if not success:
			printerr("NPCInteractionManager: FATAL - Failed to initialize LlamaService!")
		else:
			print("NPCInteractionManager: LlamaService initialized successfully.")
	else:
		print("NPCInteractionManager: LlamaService was already initialized.")


func _check_close_request():
	# Connect the main window's close request signal
	# Ensure root window exists before connecting
	if get_tree().root:
		get_tree().root.connect("close_requested", Callable(self, "_on_window_close_request"))
	else:
		printerr("NPCInteractionManager: Root window not found in _check_close_request")


func _on_window_close_request():
	print("Window close requested. Quitting.")
	get_tree().quit()


func _notification(what):
	if what == NOTIFICATION_EXIT_TREE:
		print("NPCInteractionManager: Tree exiting. Cleaning up LlamaService...")
		# Use direct access for Autoload
		LlamaService.Dispose()
		print("NPCInteractionManager: LlamaService Dispose called.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("Mouse1"):
		get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").release_focus()
		
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Enter"):
		print("ENTERPRESSED")
		if get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").text.length() != 0:
			print("DIALOGUE > 0 - Sending to NPC")
			var player_text = get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").text
			# Call the correct function on the NPC script
			get_tree().get_nodes_in_group(SelectedNPC)[0].process_player_dialogue(player_text)
			# Update the UI immediately with player's text
			UpdateDialogueWindow("Player : " + player_text)

func IsSayFocused()->bool:
	var IsSayFocused = get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").has_focus()
	return IsSayFocused


func OpenDialogueWindow():
	if isDialogueOpen == false:
		get_tree().get_nodes_in_group("Dialogue")[0].show()
		get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").grab_focus()
		isDialogueOpen = true


func CloseDialogueWindow():
	if isDialogueOpen == true:
		get_tree().get_nodes_in_group("Dialogue")[0].hide()
		get_tree().get_nodes_in_group("Dialogue")[0].get_node("CurrentDialogue").text = ""
		get_tree().get_nodes_in_group("Dialogue")[0].get_node("Say").text = ""
		isDialogueOpen = false


func UpdateDialogueWindow(NewText : String):
	var CurrentConversationLength : int = get_tree().get_nodes_in_group("Dialogue")[0].get_node("CurrentDialogue").text.length() 
	get_tree().get_nodes_in_group("Dialogue")[0].get_node("CurrentDialogue").text.insert(CurrentConversationLength,"/n"+ NewText)
