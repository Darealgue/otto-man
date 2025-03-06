extends Node

# Constants for API
const API_URL = "http://127.0.0.1:1234/v1/chat/completions"  # Updated endpoint
const HEADERS = ["Content-Type: application/json"]

var invokedDialogue :String

# Signal for when response is received
signal response_received(response_data)

# Update the system prompt to be more explicit about JSON structure
const SYSTEM_PROMPT = """You are Kamil, a depressed logger who witnessed his mother's murder. RESPOND IN CHARACTER.

COPY THIS FORMAT EXACTLY, ONLY CHANGING THE GeneratedDialogue:

{
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
	},
	"GeneratedDialogue": "Kamil: *stares at the ground, voice trembling* H-hello..."
}

RESPONSE RULES:
1. KEEP ALL FIELDS EXACTLY AS SHOWN
2. ONLY CHANGE GeneratedDialogue
3. GeneratedDialogue MUST:
   - Start with "Kamil: "
   - Include an *emotional action*
   - Be in character (depressed, traumatized)
4. NO EXTRA TEXT OR FIELDS
5. RESPOND AS KAMIL, NOT AS THE PLAYER"""

# Add validation function
func validate_dialogue_state(state: Dictionary) -> bool:
	# Load and parse our dialogue schema
	var schema_file = FileAccess.open("res://AI/config/dialogue_schema.json", FileAccess.READ)
	var dialogue_schema = JSON.parse_string(schema_file.get_as_text())
	schema_file.close()
	
	# TODO: Implement JSON schema validation
	# For now, just check required fields
	if not state.has_all(["Info", "History", "DialogueHistory"]):
		print("Missing required fields in dialogue state")
		return false
		
	return true

# Make request to LLM server
func request_completion(prompt: String, preset: String) -> void:
	print("Sending request to server...")
	
	# First validate our request format
	var request = {
		"messages": [
			{
				"role": "system",
				"content": SYSTEM_PROMPT
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"temperature": 0.3,  # Balanced between consistency (0.1) and creativity (0.7)
		"max_tokens": 1000,
		"stream": false
	}
	
	# Load and validate against server schema
	var schema_file = FileAccess.open("res://AI/config/server_schema.json", FileAccess.READ)
	var server_schema = JSON.parse_string(schema_file.get_as_text())
	schema_file.close()
	
	# TODO: Implement JSON schema validation
	# For now, just check required fields
	if not request.has("messages"):
		print("Invalid request format")
		return
		
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	var body = JSON.stringify(request)
	print("Request body: ", body)
	
	var error = http_request.request(API_URL, HEADERS, HTTPClient.METHOD_POST, body)
	if error != OK:
		print("An error occurred in the HTTP request: ", error)
	else:
		print("Request sent successfully")

# Handle response from server
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Response received!")
	print("Result: ", result)
	print("Response code: ", response_code)
	
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error with the request: ", result)
		return
		
	var raw_response = body.get_string_from_utf8()
	print("Raw response: ", raw_response)
		
	var json = JSON.parse_string(raw_response)
	if json == null:
		print("Failed to parse initial JSON")
		return
	
	# Extract the AI's message content
	var response_content = json.get("choices", [{}])[0].get("message", {}).get("content", "")
	print("Response content before cleaning: ", response_content)
	
	# Clean the response to get only the JSON object
	response_content = clean_json_response(response_content)
	print("Cleaned response content: ", response_content)
	
	# Parse the cleaned response
	var response_data = JSON.parse_string(response_content)
	if response_data:
		if validate_response(response_data):
			var dialogue = response_data["GeneratedDialogue"]
			var label = get_node_or_null("Label")
			if label:
				label.text = dialogue
			emit_signal("response_received", response_data)
		else:
			print("Invalid response structure")
	else:
		print("Failed to parse response data")

# Example usage
func SendDialogue():
	var character_state = {
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
		},
		"NewDialogue": "Player: " + invokedDialogue
	}
	
	# Validate the dialogue state before sending
	if not validate_dialogue_state(character_state):
		print("Invalid dialogue state")
		return

	# Send the state directly as JSON
	request_completion(JSON.stringify(character_state), "dialogue")


func _on_button_pressed() -> void:
	invokedDialogue = $LineEdit.text
	SendDialogue()


func _on_ai_launch_pressed() -> void:
	ServerManager.Launch_AI_Server()

func validate_response(response: Dictionary) -> bool:
	# Check for duplicate fields
	if response.has("History") and response.get("Info", {}).has("History"):
		print("Error: Duplicate History field found")
		return false
		
	# Check for required structure
	if not response.has("Info") or not response.has("History") or not response.has("DialogueHistory"):
		print("Error: Missing required top-level fields")
		return false
		
	# Check for GeneratedDialogue format
	if not response.has("GeneratedDialogue"):
		print("Error: Missing GeneratedDialogue")
		return false
		
	var dialogue = response["GeneratedDialogue"]
	if not dialogue.begins_with(response["Info"]["Name"] + ":"):
		print("Error: GeneratedDialogue should start with NPC name")
		return false
		
	return true

func clean_json_response(content: String) -> String:
	# Find the first '{' and last '}'
	var start = content.find("{")
	var end = content.rfind("}")
	
	if start == -1 or end == -1:
		print("No valid JSON object found in response")
		return ""
		
	# Extract only the JSON object
	return content.substr(start, end - start + 1)
