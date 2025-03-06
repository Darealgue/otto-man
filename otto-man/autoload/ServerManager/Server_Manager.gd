extends Node

const SERVER_PATH = "llama-server.exe"
const MODEL_PATH = "models/tinyllama-1.1b-chat-v1.0.Q4_0.gguf"

var _server_process: int = -1
var output: Array = []
signal server_ready

func Launch_AI_Server():
	print("Server manager starting...")
	
	var base_path = OS.get_executable_path().get_base_dir().replace("/", "\\")
	var ai_path = base_path + "\\AI"
	var full_server_path = ai_path + "\\" + SERVER_PATH
	var full_model_path = ai_path + "\\" + MODEL_PATH
	
	print("Base path: ", base_path)
	print("AI path: ", ai_path)
	print("Full server path: ", full_server_path)
	print("Full model path: ", full_model_path)
	
	# Simplified server launch with minimal required parameters
	_server_process = OS.create_process(
		full_server_path,
		[
			"-m", full_model_path,  # Model path with -m instead of --model
			"-c", "2048",           # Context size with -c instead of --ctx-size
			"-ngl", "0",            # GPU layers with -ngl instead of --n-gpu-layers
			"--host", "127.0.0.1",  # Keep these the same
			"--port", "1234"        # Keep these the same
		],
		ai_path
	)
	
	if _server_process <= 0:
		print("Failed to start server process!")
		return
		
	print("Process ID: ", _server_process)
	
	# Start checking if server is ready
	await get_tree().create_timer(5.0).timeout
	_check_server_status()

func _check_server_status():
	var http = HTTPClient.new()
	var err = http.connect_to_host("127.0.0.1", 1234)
	if err != OK:
		print("Failed to start connection, error: ", err)
		await get_tree().create_timer(2.0).timeout
		_check_server_status()
		return
		
	# Wait for connection with less frequent prints
	var connection_attempts = 0
	var max_attempts = 30  # Add maximum attempts
	while http.get_status() == HTTPClient.STATUS_CONNECTING or http.get_status() == HTTPClient.STATUS_RESOLVING:
		http.poll()
		connection_attempts += 1
		if connection_attempts % 60 == 0:
			print("Still trying to connect... Attempt: ", connection_attempts / 60)
		if connection_attempts >= max_attempts * 60:  # Give up after max_attempts
			print("Connection attempts exceeded, giving up!")
			return
		await get_tree().process_frame
	
	if http.get_status() != HTTPClient.STATUS_CONNECTED:
		print("Server not ready yet (status: ", http.get_status(), "), retrying in 2 seconds...")
		await get_tree().create_timer(2.0).timeout
		_check_server_status()
		return
	
	print("Server is ready!")
	emit_signal("server_ready")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _server_process != -1:
			# Kill the server process
			OS.kill(_server_process)
		get_tree().quit()
