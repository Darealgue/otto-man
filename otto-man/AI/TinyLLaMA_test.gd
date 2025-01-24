extends Node

# Constants for API
const API_URL = "http://127.0.0.1:1234/v1/chat/completions"  # Updated endpoint
const HEADERS = ["Content-Type: application/json"]

var invokedDialogue :String

# Signal for when response is received
signal response_received(response_data)

# Make request to LLM server
func request_completion(prompt: String, preset: String) -> void:
	print("Sending request to server...")
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)
	
	var system_prompt = """You are an AI that manages NPC dialogue. For each interaction:
1. Read the provided NPC data (Info, History, DialogueHistory)
2. Read the NewDialogue field to see what was said to the NPC
3. Generate the NPC's response as GeneratedDialogue using actual values from Info (not placeholders)
4. Update the NPC's state if needed
5. Return a JSON object with GeneratedDialogue (your response), Info, History, and DialogueHistory

Example:
If Info contains "Name": "Kamil" and NewDialogue is "Villager: Hello what's your name?"
Your response should be:
{
	"GeneratedDialogue": "My name is Kamil",
	"Info": { ... current state ... },
	"History": [ ... current events ... ],
	"DialogueHistory": { ... current conversations ... }
}"""
	
	var body = JSON.stringify({
		"messages": [
			{
				"role": "system",
				"content": system_prompt
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"preset": preset,
		"temperature": 0.7,
		"max_tokens": 800,
		"stream": false
	})
	
	print("Request body: ", body)  # Let's see what we're sending
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
	
	print("Initial JSON parse: ", json)
	
	# Extract the AI's message content
	var response_content = json.get("choices", [{}])[0].get("message", {}).get("content", "")
	print("Response content: ", response_content)
	
	# Parse the response content as JSON
	var response_data = JSON.parse_string(response_content)
	print("Parsed response data: ", response_data)
	
	if response_data and response_data.has("GeneratedDialogue"):
		var dialogue = response_data["GeneratedDialogue"]
		# Replace any remaining [placeholders] with actual values
		if response_data.has("Info"):
			for key in response_data["Info"]:
				dialogue = dialogue.replace("[" + key + "]", response_data["Info"][key])
		print("AI Response: ", dialogue)
		$Label.text = dialogue
		emit_signal("response_received", response_data)
	else:
		print("Invalid response format - missing GeneratedDialogue")

# Example usage
func SendDialogue():
	# Create the character state data
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
				"Bandit Leader": "If you want to take revenge some day, I'll be waiting for you, and I'll be ready.",
				"self": "*cries in agony*"
			}
		},
		"NewDialogue": "Villager: " + invokedDialogue
	}

	# Send the structured data to the AI
	request_completion(JSON.stringify(character_state), "dialogue")


func _on_button_pressed() -> void:
	invokedDialogue = $LineEdit.text
	SendDialogue()


func _on_ai_launch_pressed() -> void:
	ServerManager.Launch_AI_Server()
