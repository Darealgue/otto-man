extends Control


# Reference to the HTTPRequest node
@onready var http_request: HTTPRequest = $HTTPRequest

# Function to send a request to the Google Gemini API
func send_request():
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyCh5tEYI_BcXFGJp7t8sLu47zhLf44mDX8"
	var headers = ["Content-Type: application/json"]
	var body = {
  "contents": [{"parts":[{"text": $LineEdit.text}]}]}
	# Convert body to JSON string
	var json_body = JSON.stringify(body)
	# Send the HTTP POST request
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

# Callback when the HTTPRequest completes
func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Request completed. Response code: ", response_code)
	# Convert body (PackedByteArray) to string
	var response_body = body.get_string_from_utf8()
	var response_dict = JSON.parse_string(response_body)
	print(response_dict)
	var response_text = response_dict["candidates"][0]["content"]["parts"][0]["text"]
	$Panel/Label.text = response_text


func _on_button_pressed() -> void:
	send_request()
