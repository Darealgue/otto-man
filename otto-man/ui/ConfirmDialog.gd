extends Control

## ConfirmDialog - Oyun içi onay dialogu
## OS.alert yerine kullanılır

signal confirmed()
signal cancelled()

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var confirm_button: Button = $Panel/VBoxContainer/ButtonsContainer/ConfirmButton
@onready var cancel_button: Button = $Panel/VBoxContainer/ButtonsContainer/CancelButton

var _result: bool = false
var _waiting_for_result: bool = false

func _ready() -> void:
	_ensure_nodes()
	_connect_signals()
	visible = false
	set_as_top_level(true)
	global_position = Vector2.ZERO
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Ensure dialog is on top of everything
	z_index = 1000  # Very high z-index to be on top
	mouse_filter = Control.MOUSE_FILTER_STOP  # Ensure it can receive mouse input

func _ensure_nodes() -> void:
	if not title_label:
		push_error("[ConfirmDialog] TitleLabel not found!")
	if not message_label:
		push_error("[ConfirmDialog] MessageLabel not found!")
	if not confirm_button:
		push_error("[ConfirmDialog] ConfirmButton not found!")
	if not cancel_button:
		push_error("[ConfirmDialog] CancelButton not found!")

func _connect_signals() -> void:
	if confirm_button:
		if not confirm_button.pressed.is_connected(_on_confirm_pressed):
			confirm_button.pressed.connect(_on_confirm_pressed)
			print("[ConfirmDialog] ✅ Connected confirm_button.pressed signal")
		else:
			print("[ConfirmDialog] ⚠️ confirm_button.pressed already connected")
	else:
		push_error("[ConfirmDialog] confirm_button is null!")
	
	if cancel_button:
		if not cancel_button.pressed.is_connected(_on_cancel_pressed):
			cancel_button.pressed.connect(_on_cancel_pressed)
			print("[ConfirmDialog] ✅ Connected cancel_button.pressed signal")
		else:
			print("[ConfirmDialog] ⚠️ cancel_button.pressed already connected")
	else:
		push_error("[ConfirmDialog] cancel_button is null!")

func show_dialog(title: String, message: String, show_cancel: bool = true) -> void:
	print("[ConfirmDialog] show_dialog called: title='%s', message='%s', show_cancel=%s" % [title, message, show_cancel])
	if not title_label or not message_label:
		push_error("[ConfirmDialog] Nodes not ready!")
		return
	
	title_label.text = title
	message_label.text = message
	cancel_button.visible = show_cancel
	
	# Ensure confirm button is always visible and enabled
	if confirm_button:
		confirm_button.visible = true
		confirm_button.disabled = false
		confirm_button.process_mode = Node.PROCESS_MODE_ALWAYS
		confirm_button.focus_mode = Control.FOCUS_ALL  # Ensure focus is enabled
		print("[ConfirmDialog] Confirm button: visible=%s, disabled=%s, process_mode=%s, focus_mode=%s" % [confirm_button.visible, confirm_button.disabled, confirm_button.process_mode, confirm_button.focus_mode])
	
	if cancel_button:
		cancel_button.process_mode = Node.PROCESS_MODE_ALWAYS
		cancel_button.focus_mode = Control.FOCUS_ALL  # Ensure focus is enabled
		print("[ConfirmDialog] Cancel button: visible=%s, disabled=%s, process_mode=%s, focus_mode=%s" % [cancel_button.visible, cancel_button.disabled, cancel_button.process_mode, cancel_button.focus_mode])
	
	_result = false
	_waiting_for_result = true
	
	# Ensure process mode is ALWAYS so it works even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 1000  # Ensure it's on top
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Make sure dialog is visible and on top
	visible = true
	show()  # Force show
	
	# Ensure it's in the viewport and on top
	var viewport = get_viewport()
	if viewport:
		# If we're a child of another node, we might need to reparent to viewport
		# But set_as_top_level should handle this
		# Just ensure we're visible and on top
		z_index = 1000
		# Make sure we cover the entire screen
		if get_parent() != viewport:
			# Reparent to viewport if needed (but set_as_top_level should handle this)
			pass
	
	# Ensure size covers the viewport
	if viewport:
		size = viewport.get_visible_rect().size
		global_position = Vector2.ZERO
	
	print("[ConfirmDialog] Dialog visible set to true, process_mode: %s, z_index: %d" % [process_mode, z_index])
	print("[ConfirmDialog] Dialog size: %s, position: %s" % [size, global_position])
	print("[ConfirmDialog] Dialog parent: %s" % get_parent())
	print("[ConfirmDialog] Dialog is_visible_in_tree: %s" % is_visible_in_tree())
	
	# Focus management - Always focus confirm button first, then cancel if shown
	# This ensures confirm button is accessible
	# Use call_deferred twice to ensure UI is ready and all focus changes are complete
	if confirm_button:
		call_deferred("call_deferred", "_set_dialog_focus")
		print("[ConfirmDialog] Focus will be set to confirm button (double deferred)")

func _set_dialog_focus() -> void:
	# Set focus to confirm button when dialog is ready
	# Force focus even if something else has it
	if confirm_button and confirm_button.visible and confirm_button.focus_mode != Control.FOCUS_NONE:
		# Release focus from any other control first
		var current_focus = get_viewport().gui_get_focus_owner()
		if current_focus:
			current_focus.release_focus()
		# Now grab focus
		confirm_button.grab_focus()
		print("[ConfirmDialog] ✅ Focus set to confirm button (previous focus: %s)" % (current_focus.name if current_focus else "none"))

func _on_confirm_pressed() -> void:
	print("[ConfirmDialog] 🔵 CONFIRM BUTTON PRESSED!")
	_result = true
	_waiting_for_result = false
	visible = false
	print("[ConfirmDialog] Emitting confirmed signal...")
	confirmed.emit()
	print("[ConfirmDialog] ✅ Confirmed signal emitted")

func _on_cancel_pressed() -> void:
	print("[ConfirmDialog] 🔴 CANCEL BUTTON PRESSED!")
	_result = false
	_waiting_for_result = false
	visible = false
	print("[ConfirmDialog] Emitting cancelled signal...")
	cancelled.emit()
	print("[ConfirmDialog] ✅ Cancelled signal emitted")

func hide_dialog() -> void:
	visible = false
	_waiting_for_result = false

func _input(event: InputEvent) -> void:
	# ESC ile iptal et
	if visible and _waiting_for_result and event.is_action_pressed("ui_cancel"):
		_on_cancel_pressed()
		get_viewport().set_input_as_handled()

