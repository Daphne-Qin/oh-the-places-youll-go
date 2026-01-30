extends Control

## Lorax Chat Interface
## Beautiful, Seussian-styled chat interface for talking with the Lorax

@onready var portrait: TextureRect = $TextureRect
@onready var chat_container: VBoxContainer = $ChatPanel/VBox/ChatContainer/ScrollContainer/MessagesContainer
@onready var input_field: LineEdit = $ChatPanel/VBox/InputPanel/InputField
@onready var send_button: Button = $ChatPanel/VBox/InputPanel/SendButton
@onready var close_button: Button = $ChatPanel/VBox/Header/CloseButton
@onready var lorax_avatar: TextureRect = $ChatPanel/VBox/Header/LoraxAvatar
@onready var typing_indicator: Label = $ChatPanel/VBox/ChatContainer/TypingIndicator

@export var portrait_assets := {
	"neutral": null,
	"angry": "res://assets/sprites/lorax/angry.png",
	"grateful": "res://assets/sprites/lorax/grateful.png"
}

var is_open: bool = false

# Game state tracking for riddle system
var game_state := {
	"failures": 0,
	"riddles_passed": 0,
	"intentions_passed": false,
	"current_phase": "intentions"  # "intentions", "riddles", "complete", "kicked_out"
}

# Conversation history for context
var conversation_history: Array = []

# Signals for game outcomes
signal tree_fall
signal player_granted_access
signal player_kicked_out

func _ready() -> void:
	"""Initialize the chat interface."""
	print("[CHAT] Initializing chat interface...")
	
	# Wait a frame to ensure all @onready variables are set
	await get_tree().process_frame
	
	# Verify nodes exist - try to find container if path failed
	if not chat_container:
		print("[CHAT] WARNING: chat_container not found via path, searching...")
		chat_container = _find_messages_container()
		if not chat_container:
			print("[CHAT] ERROR: Could not find MessagesContainer!")
			return
	if not send_button:
		print("[CHAT] ERROR: send_button not found!")
		return
	if not close_button:
		print("[CHAT] ERROR: close_button not found!")
		return
	if not input_field:
		print("[CHAT] ERROR: input_field not found!")
		return
	
	print("[CHAT] All nodes found. Chat container: ", chat_container.name)
	
	# Connect signals
	send_button.pressed.connect(_on_send_pressed)
	close_button.pressed.connect(_on_close_pressed)
	input_field.text_submitted.connect(_on_input_submitted)
	
	# Connect to API manager signals
	if APIManager:
		APIManager.lorax_message_received.connect(on_lorax_message_received)
		APIManager.lorax_message_failed.connect(on_lorax_message_failed)
		print("[CHAT] Connected to APIManager signals")
	else:
		print("[CHAT] ERROR: APIManager not found!")
	
	# Start hidden
	visible = false
	is_open = false
	
	print("[CHAT] Chat interface initialized successfully")

func _input(event: InputEvent) -> void:
	"""Handle input for opening/closing chat."""
	if event.is_action_pressed("ui_cancel") and is_open:
		close_chat()

func open_chat(force_reset: bool = false) -> void:
	"""Open the chat interface."""
	print("[CHAT] open_chat() called")
	if is_open:
		print("[CHAT] Chat already open, returning")
		return

	# Reset if player was kicked out or forced reset
	if force_reset or game_state.current_phase == "kicked_out":
		reset_conversation()

	is_open = true
	visible = true
	modulate.a = 1.0  # Make sure it's fully visible

	print("[CHAT] Chat opened. Visible: ", visible, " Modulate alpha: ", modulate.a)

	# Animate in
	var tween = create_tween()
	tween.set_parallel(true)
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	scale = Vector2(0.9, 0.9)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wait for animation to complete
	await get_tree().create_timer(0.3).timeout

	# Verify chat container is ready
	if not chat_container:
		print("[CHAT] ERROR: chat_container is null when opening chat!")
		return

	# Add welcome message when chat opens (only if chat is empty)
	if chat_container.get_child_count() == 0:
		print("[CHAT] Chat is empty, adding welcome message...")
		await get_tree().process_frame  # Wait one more frame
		_add_welcome_message()

	# Focus input field
	input_field.grab_focus()

	# Disable player movement
	GameState.disable_movement()

func close_chat() -> void:
	"""Close the chat interface."""
	if not is_open:
		return
	
	is_open = false
	
	# Animate out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)
	
	await tween.finished
	visible = false
	
	# Re-enable player movement
	GameState.enable_movement()

func _add_welcome_message() -> void:
	"""Add a welcome message from the Lorax."""
	print("[CHAT] Adding welcome message...")
	var welcome_text = "I am the Lorax! I speak for the trees! You wish to enter my forest, I see... But first you must answer to ME! Tell me, small one - WHY do you seek the Truffula trees? What brings you here, if you please?"
	_add_message(welcome_text, false)  # false = from Lorax
	# Add to history
	conversation_history.append({"text": welcome_text, "is_user": false})

func _on_send_pressed() -> void:
	"""Handle send button press."""
	_send_message()

func _on_close_pressed() -> void:
	"""Handle close button press."""
	close_chat()

func _on_input_submitted(text: String) -> void:
	"""Handle Enter key in input field."""
	_send_message()

func _send_message() -> void:
	"""Send the user's message."""
	var message = input_field.text.strip_edges()
	if message == "":
		return

	# Don't allow messages if game is over
	if game_state.current_phase == "complete" or game_state.current_phase == "kicked_out":
		return

	print("[CHAT] Sending message to API: ", message)

	# Add user message to chat and history
	_add_message(message, true)  # true = from user
	conversation_history.append({"text": message, "is_user": true})

	# Clear input
	input_field.text = ""

	# Show typing indicator
	_show_typing_indicator()

	# Send to API with conversation history and game state
	print("[CHAT] Calling APIManager.send_message_to_lorax()...")
	APIManager.send_message_to_lorax(message, conversation_history, game_state)
	print("[CHAT] Message sent to API manager")

func _add_message(text: String, is_user: bool) -> void:
	"""Add a message bubble to the chat."""
	print("[CHAT] Adding message: ", text, " (user: ", is_user, ")")
	
	# Verify chat container exists
	if not chat_container:
		print("[CHAT] ERROR: chat_container is null!")
		return
	
	# Create message bubble
	var bubble = _create_message_bubble(text, is_user)
	chat_container.add_child(bubble)
	
	print("[CHAT] Message bubble added. Container now has ", chat_container.get_child_count(), " children")
	
	# Make sure bubble is visible
	bubble.visible = true
	bubble.modulate.a = 1.0
	
	# Scroll to bottom
	await get_tree().process_frame
	_scroll_to_bottom()
	
	# Animate message appearance
	var tween = create_tween()
	bubble.modulate.a = 0.0
	bubble.scale = Vector2(0.8, 0.8)
	tween.set_parallel(true)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.2)
	tween.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func _create_message_bubble(text: String, is_user: bool) -> Control:
	"""Create a styled message bubble."""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)
	
	# User messages align right, Lorax messages align left
	if is_user:
		container.add_child(Control.new())  # Spacer
		container.set_alignment(BoxContainer.ALIGNMENT_END)
	
	# Create bubble
	var bubble = PanelContainer.new()
	var style = StyleBoxFlat.new()
	
	if is_user:
		style.bg_color = Color(0.2, 0.6, 0.9, 1)  # Blue for user
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 5
	else:
		style.bg_color = Color(0.9, 0.6, 0.2, 1)  # Orange for Lorax
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 15
	
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.1, 0.1, 0.1, 1)
	
	bubble.add_theme_stylebox_override("panel", style)
	
	# Add text label
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_constant_override("line_spacing", 4)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(label)
	
	bubble.add_child(margin)
	
	# Set size
	bubble.custom_minimum_size = Vector2(200, 0)
	if is_user:
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	else:
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	container.add_child(bubble)
	
	if not is_user:
		container.add_child(Control.new())  # Spacer
	
	# Ensure container is visible and has proper sizing
	container.visible = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	return container

func _show_typing_indicator() -> void:
	"""Show typing indicator."""
	typing_indicator.visible = true
	typing_indicator.text = "The Lorax is thinking..."
	
	# Animate typing dots
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(typing_indicator, "modulate:a", 0.5, 0.5)
	tween.tween_property(typing_indicator, "modulate:a", 1.0, 0.5)

func _hide_typing_indicator() -> void:
	"""Hide typing indicator."""
	var tween = create_tween()
	tween.tween_property(typing_indicator, "modulate:a", 0.0, 0.2)
	await tween.finished
	typing_indicator.visible = false
	typing_indicator.modulate.a = 1.0

func _scroll_to_bottom() -> void:
	"""Scroll chat to bottom."""
	var scroll_container = chat_container.get_parent()
	if scroll_container is ScrollContainer:
		var scroll = scroll_container as ScrollContainer
		await get_tree().process_frame
		var v_scroll = scroll.get_v_scroll_bar()
		if v_scroll:
			scroll.scroll_vertical = v_scroll.max_value

func on_lorax_message_received(message: String) -> void:
	"""Handle Lorax message received from API."""
	print("[CHAT] Lorax message received: ", message)
	_hide_typing_indicator()

	# Filter out any leaked state/meta information (LLM prompt leakage protection)
	var filtered_message = _filter_leaked_state(message)

	# Process the filtered response
	_process_lorax_response(filtered_message)

func _filter_leaked_state(message: String) -> String:
	"""Remove any accidentally leaked game state or meta-commentary from the response."""
	var filtered = message

	# List of patterns that indicate leaked state info
	var leak_patterns = [
		"riddles_passed", "intentions_passed", "failures", "current_phase",
		"game state", "game_state", "GAME_STATE", "state update",
		"is now TRUE", "is now FALSE", "is now true", "is now false",
		"= true", "= false", "= 0", "= 1", "= 2", "= 3",
		"moving to phase", "updating state", "phase 1", "phase 2", "phase 3"
	]

	# Check if message contains leaked info
	var contains_leak = false
	for pattern in leak_patterns:
		if pattern.to_lower() in filtered.to_lower():
			contains_leak = true
			break

	# If the entire message seems to be state info, replace with fallback
	if contains_leak and filtered.length() < 100:
		print("[CHAT] WARNING: Filtered leaked state info from response")
		return "Hmm... the trees whisper something I cannot quite hear. Speak again, small one!"

	# For longer messages, try to extract just the dialogue part
	if contains_leak:
		# Try to find actual dialogue after the leak
		var lines = filtered.split("\n")
		var clean_lines = []
		for line in lines:
			var is_leak = false
			for pattern in leak_patterns:
				if pattern.to_lower() in line.to_lower():
					is_leak = true
					break
			if not is_leak and line.strip_edges() != "":
				clean_lines.append(line)

		if clean_lines.size() > 0:
			filtered = "\n".join(clean_lines)
		else:
			filtered = "The forest awaits your answer... speak clearly!"
		print("[CHAT] WARNING: Partially filtered leaked state info")

	return filtered

func _process_lorax_response(message: String) -> void:
	"""Process the filtered Lorax response."""
	var display_message = message
	var granted_access = false
	var kicked_out = false

	if "[FOREST_ACCESS_GRANTED]" in message:
		granted_access = true
		display_message = message.replace("[FOREST_ACCESS_GRANTED]", "").strip_edges()
		game_state.current_phase = "complete"

	if "[KICKED_OUT]" in message:
		kicked_out = true
		display_message = message.replace("[KICKED_OUT]", "").strip_edges()
		game_state.current_phase = "kicked_out"

	# Detect anger/failure indicators in the response
	var anger_keywords = ["wrong", "falls", "weeps", "angry", "disappointed", "no!", "incorrect", "fail"]
	var is_angry_response = false
	for keyword in anger_keywords:
		if keyword in message.to_lower():
			is_angry_response = true
			break

	# Detect success indicators
	var success_keywords = ["correct", "yes!", "right", "well done", "approval", "pleased", "passed"]
	var is_success_response = false
	for keyword in success_keywords:
		if keyword in message.to_lower():
			is_success_response = true
			break

	# Update portrait based on response
	if kicked_out or is_angry_response:
		tree_fall.emit()
		_set_portrait("angry")
	elif granted_access or is_success_response:
		_set_portrait("grateful")
	else:
		_set_portrait("neutral")

	# Add to chat and history
	_add_message(display_message, false)
	conversation_history.append({"text": display_message, "is_user": false})

	# Handle outcomes with delay for dramatic effect
	if granted_access:
		await get_tree().create_timer(2.0).timeout
		_handle_forest_access()
	elif kicked_out:
		await get_tree().create_timer(2.0).timeout
		_handle_kicked_out()

func _handle_forest_access() -> void:
	"""Handle player being granted access to the forest."""
	print("[CHAT] Player granted access to Truffula Forest!")
	player_granted_access.emit()
	# Add a final celebratory message
	_add_message("🌳 The path to the Truffula Forest opens before you... 🌳", false)
	# Disable input
	input_field.editable = false
	send_button.disabled = true

func _handle_kicked_out() -> void:
	"""Handle player being kicked out."""
	print("[CHAT] Player kicked out!")
	player_kicked_out.emit()
	# Add a dismissal message
	_add_message("🚫 The forest closes its paths to you. Come back when you've learned respect! 🚫", false)
	# Disable input
	input_field.editable = false
	send_button.disabled = true
	# Close chat after delay
	await get_tree().create_timer(3.0).timeout
	close_chat()

func on_lorax_message_failed(error_message: String) -> void:
	"""Handle Lorax message failure."""
	print("[CHAT] Lorax message failed: ", error_message)
	_hide_typing_indicator()
	var error_text = "The trees rustle in anger! I'm left speechless. " + error_message
	_add_message(error_text, false)

func _find_messages_container() -> VBoxContainer:
	"""Fallback method to find MessagesContainer by searching."""
	var found = _search_for_node(self, "MessagesContainer")
	if found and found is VBoxContainer:
		return found as VBoxContainer
	return null

func _search_for_node(node: Node, name: String) -> Node:
	"""Recursively search for a node by name."""
	if node.name == name:
		return node
	for child in node.get_children():
		var result = _search_for_node(child, name)
		if result:
			return result
	return null

func _set_portrait(emotion: String) -> void:
	"""Set the Lorax portrait based on emotion."""
	print("[CHAT] Setting portrait to: ", emotion)
	if portrait and portrait_assets.has(emotion):
		var asset_path = portrait_assets[emotion]
		if asset_path != null and asset_path != "":
			var texture = load(asset_path)
			if texture:
				portrait.texture = texture
				print("[CHAT] Portrait loaded: ", asset_path)

func reset_conversation() -> void:
	"""Reset the conversation state for a new attempt."""
	print("[CHAT] Resetting conversation...")
	game_state = {
		"failures": 0,
		"riddles_passed": 0,
		"intentions_passed": false,
		"current_phase": "intentions"
	}
	conversation_history.clear()
	# Clear existing messages
	if chat_container:
		for child in chat_container.get_children():
			child.queue_free()
	# Re-enable inputs
	if input_field:
		input_field.editable = true
	if send_button:
		send_button.disabled = false
	# Reset portrait
	_set_portrait("neutral")
