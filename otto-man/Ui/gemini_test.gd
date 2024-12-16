extends Node

#var NPC_Info = {"Name":"","Occupation":"","Mood":"","Gender":"","Age":"","Health":""}
var Current_NPC_Info = null
var All_NPC_Infos = []
var All_NPCs = []
var Current_Daily_Actions = null
var Current_NPC = null
var Prompt_Action = "" # "\"Dialogue\"" or "\"DailyActions\""
var NPC_Setup_Prompt = "Imagine you're a video game NPC.
You will be asked to fill in dialogue, actions, action durations, mood and next goal according to some fields provided below.
All the dialogue and actions should be 1 to 3 sentences long at most.

The field named \"Info\" has the information about this specific NPC.
The field named \"History\" is the chronological list of events that happened in this NPC's life.
The field named \"Dialogue History\" is the the list of dialogue this NPC had with players or other NPCs in the form of {\"name of dialogue\":{\"name of other NPC or Player\" : \"what other NPC or player said last\",\"This NPC\":\"what this NPC said last\"}}
The field named \"Main Actions\" is what this NPC can do as main actions in the game.
The field named \"Invoked Action\" is what this prompt wants as an answer.
The field named \"Invoked Dialogue\" is what has been said or asked to this NPC in the case of Invoked Action = \"Dialogue\".

Info ="+str(Current_NPC_Info)+"
History = [\"Witnessed the murder of his own mother\",
	   \"Fell in love with a girl in the same village\"
	   \"Sprained own ankle\"]

Dialogue History = {Dialogue with Bandits{\"Bandit Leader\":\"If you want to take revenge some day, I'll be waiting for you, and I'll be ready.\",\"self\":\"*cries in agony*\"}

Main Actions = [\"Cut down trees\",\"Go in the house\",\"Sleep\",\"Fetch water\",\"Visit another villager\"]

Invoked Action = "+Prompt_Action+"

Invoked Dialogue = \"\"

Based on the fields above, You're to perform 1 of 2 things: 

If the Invoked Action field says \"Dialogue\" , you'll come up with a dialogue based on what's been said or asked in \"Invoked Dialogue\" field to this NPC.
In the answer of this prompt, you're to copy and fill in the After Dialogue section. Please fill the \"Generated Dialogue\" part with what this NPC will say,change the Dialogue history accordingly, and change the Info and History only if necessary ( example: After a heated arguement with an other NPC, \"argued with X NPC\" could be added to history. ) 

If the Invoked Action field says \"Daily actions\", you'll come up with a list of daily actions that consits of \"Main Actions\" and you'll come up with some filler \"Custom Actions\" which are going to be between \"Main Actions\". 
Examples of Custom actions could be minor things like \"Watching the clouds, whistling, sitting down\" etc...
All actions should sum up to 24 hours in game (which is 1 hour in real life)
An example of this list and how it should be formatted is down below. Please give the answer to this prompt with only the list and what's in it.

Most Important of all:
Make sure you're not confusing the Dialogue and Daily actions.Look at the Invoked action and make sure you give the right answer.
If the Invoked Action part says \"Daily Actions\", response of this prompt should only include a list of daily actions like below and NOTHING ELSE.

After Dialogue =
Generated Dialogue = \"\"
Info = {\"Name\":\"Kamil\", \"Occupation\":\"Logger\", \"Mood\":\"Depressed\", 
\"Gender\":\"Male\", \"Age\":\"25\", \"Health\":\"Injured\"}
History = [\"Witnessed the murder of his own mother\",
	   \"Fell in love with a girl in the same village\"
	   \"Sprained own ankle\"]
Dialogue History = {Dialogue with Bandits{\"Bandit Leader\":\"If you want to take revenge some day, I'll be waiting for you, and I'll be ready.\",\"self\":\"*cries in agony*\"}


Daily Actions = [\"Main action: Visiting the girl's house but staying at a distance/ Duration: 20 minutes\",
\"Custom action: Watching the girl from afar, building courage to approach / Duration: 1 hour\",
\"Main action: Cutting down trees / Duration: 3 hours\",
\"Custom action: Resting under a tree, humming softly and carving a small wooden heart / Duration: 1 hour\",
\"Main action: Taking a bucket of water from the well / Duration: 5 minutes\",
\"Custom action: Drinking water and resting on the well's edge / Duration: 30 minutes\",
\"Main action: Enter the house / Duration: 10 minutes\",
\"Custom action: Sitting by the window, writing a note or poem for the girl / Duration: 1 hour\",
\"Main action: Get out of the house / Duration: 10 minutes\",
\"Custom action: Walking toward the girl's house but stopping halfway / Duration: 1 hour\",
\"Main action: Visiting the girl's house / Duration: 15 minutes\",
\"Custom action: Talking briefly if she is outside, or leaving a carved wooden heart nearby if she's not / Duration: 20 minutes\",
\"Main action: Cutting down trees / Duration: 1.5 hours\",
\"Custom action: Collecting wood and stacking it neatly near the house, hoping she will notice / Duration: 1 hour\",
\"Main action: Enter the house / Duration: 10 minutes\",
\"Custom action: Sitting on the floor, looking at the wooden heart he carved earlier / Duration: 30 minutes\",
\"Main action: Going to sleep / Duration: 5 hours\"]

"

func _ready() -> void:
	Gather_Daily_NPC_Infos()
# Reference to the HTTPRequest node
@onready var http_request: HTTPRequest = $HTTPRequest

# Function to send a request to the Google Gemini API
func send_request():
	print("sendingrequest")
	var url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=AIzaSyCh5tEYI_BcXFGJp7t8sLu47zhLf44mDX8"
	var headers = ["Content-Type: application/json"]
	var body = {
  "contents": [{"parts":[{"text": NPC_Setup_Prompt}]}]}
	# Convert body to JSON string
	var json_body = JSON.stringify(body)
	# Send the HTTP POST request
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)

func _on_http_request_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	print("Request completed. Response code: ", response_code)
	# Convert body (PackedByteArray) to string
	var response_body = body.get_string_from_utf8()
	var response_dict = JSON.parse_string(response_body)
	var response_text = response_dict["candidates"][0]["content"]["parts"][0]["text"]
	print(response_text)
	Convert_Daily_Actions_To_Array(response_text)
	
func Gather_Daily_NPC_Infos():
	for NPC in get_tree().get_nodes_in_group("NPC"):
		All_NPC_Infos.append(NPC.NPC_Info)
		All_NPCs.append(NPC)
	Request_New_NPC_Actions()
	
func Request_New_NPC_Actions():
	Prompt_Action = "\"Daily Actions\""
	if All_NPC_Infos.size() > 0:
		Current_NPC = All_NPCs[0]
		Current_NPC_Info = All_NPC_Infos[0]
		send_request()
		await _on_http_request_request_completed
		All_NPC_Infos.remove_at(0)
		
func Convert_Daily_Actions_To_Array(raw_string:String):
	# Extract the part inside the brackets
	var start_index = raw_string.find('[') + 1
	var end_index = raw_string.rfind(']')
	var actions_string = raw_string.substr(start_index, end_index - start_index)
	
	# Split into individual lines using "\n"
	var actions = actions_string.split("\n")
	
	# Clean up and remove extra quotes/commas
	var result_array = []
	for action in actions:
		action = action.strip_edges()  # Remove leading/trailing whitespace
		action = action.trim_prefix('"')  # Remove leading quote
		action = action.trim_suffix('",')  # Remove trailing quote and comma
		action = action.trim_suffix('"')  # Extra check for trailing quote
		if action != "":
			result_array.append(action)
	Current_Daily_Actions = result_array
	print(Current_Daily_Actions)
	print(typeof(Current_Daily_Actions))
	Current_NPC.parse_daily_schedule(Current_Daily_Actions)
	Current_NPC = null
	All_NPCs.erase(Current_NPC)
	Request_New_NPC_Actions()
