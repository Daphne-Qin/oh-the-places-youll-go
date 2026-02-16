extends Control

## Horton Chat Interface
## A calming, gentle chat interface for talking with anxious Horton

@onready var portrait: TextureRect = $TextureRect
@onready var chat_container: VBoxContainer = $ChatPanel/VBox/ChatContainer/ScrollContainer/MessagesContainer
@onready var input_field: LineEdit = $ChatPanel/VBox/InputPanel/InputField
@onready var send_button: Button = $ChatPanel/VBox/InputPanel/SendButton
@onready var close_button: Button = $ChatPanel/VBox/Header/CloseButton
@onready var horton_avatar: TextureRect = $ChatPanel/VBox/Header/HortonAvatar
@onready var typing_indicator: Label = $ChatPanel/VBox/ChatContainer/TypingIndicator

@export var portrait_assets := {
	"neutral": "res://assets/sprites/horton/anxiousHorton.png",  # Use anxious as neutral for now
	"anxious": "res://assets/sprites/horton/anxiousHorton.png",
	"happy": "res://assets/sprites/horton/happyCHAT.png",
	"sad": "res://assets/sprites/horton/anxiousHorton.png",  # Use anxious for sad too
	"panicked": "res://assets/sprites/horton/anxiousHorton.png"  # Use anxious for panicked
}

var is_open: bool = false

# Game state tracking for Listening Challenge system
var game_state := {
	"messages_decoded": 0,  # 0-5 messages successfully decoded
	"total_failures": 0,  # 0-10 failures across all messages, 10 = game over
	"current_message_attempts": 0,  # Attempts on current message (resets per message)
	"current_phase": "introduction"  # "introduction", "decoding", "resolved", "ran_away"
}

# Conversation history for context
var conversation_history: Array = []

# Signals for game outcomes
signal message_decoded  # Successfully decoded a message
signal interpretation_failed  # Failed to decode a message correctly
signal horton_trusts_player  # Successfully completed all challenges
signal horton_ran_away  # Too many failures, Horton gives up

func _ready() -> void:
	"""Initialize the chat interface."""
	print("[HORTON_CHAT] Initializing chat interface...")

	await get_tree().process_frame

	if not chat_container:
		print("[HORTON_CHAT] WARNING: chat_container not found via path, searching...")
		chat_container = _find_messages_container()
		if not chat_container:
			print("[HORTON_CHAT] ERROR: Could not find MessagesContainer!")
			return
	if not send_button:
		print("[HORTON_CHAT] ERROR: send_button not found!")
		return
	if not close_button:
		print("[HORTON_CHAT] ERROR: close_button not found!")
		return
	if not input_field:
		print("[HORTON_CHAT] ERROR: input_field not found!")
		return

	print("[HORTON_CHAT] All nodes found.")

	# Connect signals
	send_button.pressed.connect(_on_send_pressed)
	close_button.pressed.connect(_on_close_pressed)
	input_field.text_submitted.connect(_on_input_submitted)

	# Connect to API manager signals
	if APIManager:
		APIManager.horton_message_received.connect(on_horton_message_received)
		APIManager.horton_message_failed.connect(on_horton_message_failed)
		print("[HORTON_CHAT] Connected to APIManager signals")
	else:
		print("[HORTON_CHAT] ERROR: APIManager not found!")

	visible = false
	is_open = false

	print("[HORTON_CHAT] Chat interface initialized successfully")

func _input(event: InputEvent) -> void:
	"""Handle input for opening/closing chat."""
	if event.is_action_pressed("ui_cancel") and is_open:
		close_chat()

func open_chat(force_reset: bool = false) -> void:
	"""Open the chat interface."""
	print("[HORTON_CHAT] open_chat() called")
	if is_open:
		print("[HORTON_CHAT] Chat already open, returning")
		return

	if force_reset or game_state.current_phase == "ran_away":
		reset_conversation()

	is_open = true
	visible = true
	modulate.a = 1.0

	# Animate in with a gentler animation (Horton is soft)
	var tween = create_tween()
	tween.set_parallel(true)
	modulate.a = 0.0
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	scale = Vector2(0.9, 0.9)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Wait for animation to complete
	await get_tree().create_timer(0.3).timeout

	if not chat_container:
		print("[HORTON_CHAT] ERROR: chat_container is null when opening chat!")
		return

	if chat_container.get_child_count() == 0:
		print("[HORTON_CHAT] Chat is empty, adding welcome message...")
		await get_tree().process_frame
		_add_welcome_message()

	# Focus input field
	input_field.grab_focus()

	GameState.disable_movement()

func close_chat() -> void:
	"""Close the chat interface."""
	if not is_open:
		return

	is_open = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.2)

	await tween.finished
	visible = false

	GameState.enable_movement()

func _add_welcome_message() -> void:
	"""Add a welcome message from Horton."""
	print("[HORTON_CHAT] Adding welcome message...")
	var welcome_text = "Oh! Oh thank goodness someone's here! *holds clover to ear excitedly* I can HEAR the Whos, but... but their voices are so tiny and garbled! My ears are big but sometimes I only catch bits and pieces. I need your help to understand what they're saying! Will you help me translate their messages? A person's a person, no matter how small!"
	_add_message(welcome_text, false)
	conversation_history.append({"text": welcome_text, "is_user": false})
	_set_portrait("anxious")

func _on_send_pressed() -> void:
	_send_message()

func _on_close_pressed() -> void:
	close_chat()

func _on_input_submitted(_text: String) -> void:
	_send_message()

func _send_message() -> void:
	"""Send the user's message."""
	var message = input_field.text.strip_edges()
	if message == "":
		return

	if game_state.current_phase == "resolved" or game_state.current_phase == "ran_away":
		return

	print("[HORTON_CHAT] Sending message to API: ", message)

	_add_message(message, true)
	conversation_history.append({"text": message, "is_user": true})

	input_field.text = ""
	_show_typing_indicator()

	print("[HORTON_CHAT] Calling APIManager.send_message_to_horton()...")
	APIManager.send_message_to_horton(message, conversation_history, game_state)

func _add_message(text: String, is_user: bool) -> void:
	"""Add a message bubble to the chat."""
	print("[HORTON_CHAT] Adding message: ", text.substr(0, 50), "...")

	if not chat_container:
		print("[HORTON_CHAT] ERROR: chat_container is null!")
		return

	var bubble = _create_message_bubble(text, is_user)
	chat_container.add_child(bubble)

	bubble.visible = true
	bubble.modulate.a = 1.0

	await get_tree().process_frame
	_scroll_to_bottom()

	var tween = create_tween()
	bubble.modulate.a = 0.0
	bubble.scale = Vector2(0.8, 0.8)
	tween.set_parallel(true)
	tween.tween_property(bubble, "modulate:a", 1.0, 0.2)
	tween.tween_property(bubble, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

func _create_message_bubble(text: String, is_user: bool) -> Control:
	"""Create a styled message bubble - softer colors for Horton."""
	var container = HBoxContainer.new()
	container.add_theme_constant_override("separation", 10)

	if is_user:
		container.add_child(Control.new())
		container.set_alignment(BoxContainer.ALIGNMENT_END)

	var bubble = PanelContainer.new()
	var style = StyleBoxFlat.new()

	if is_user:
		style.bg_color = Color(0.4, 0.6, 0.8, 1)  # Soft blue for user
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 5
	else:
		style.bg_color = Color(0.6, 0.7, 0.6, 1)  # Soft gray-green for Horton (elephant color)
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 5
		style.corner_radius_bottom_right = 15

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.2, 0.2, 0.5)

	bubble.add_theme_stylebox_override("panel", style)

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

	bubble.custom_minimum_size = Vector2(200, 0)
	if is_user:
		bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	else:
		bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	container.add_child(bubble)

	if not is_user:
		container.add_child(Control.new())

	container.visible = true
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	return container

func _show_typing_indicator() -> void:
	"""Show typing indicator."""
	typing_indicator.visible = true
	typing_indicator.text = "Horton is thinking... (and probably worrying)"

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

func on_horton_message_received(message: String) -> void:
	"""Handle Horton message received from API."""
	print("[HORTON_CHAT] Horton message received: ", message)
	_hide_typing_indicator()

	var filtered_message = _filter_leaked_state(message)
	_process_horton_response(filtered_message)

func _filter_leaked_state(message: String) -> String:
	"""Remove any accidentally leaked game state from the response."""
	var filtered = message

	var leak_patterns = [
		"messages_decoded", "total_failures", "current_message_attempts", "current_phase",
		"game state", "game_state", "GAME_STATE",
		"is now TRUE", "is now FALSE", "= true", "= false",
		"= 0", "= 1", "= 2", "= 3", "= 4", "= 5", "= 10"
	]

	var contains_leak = false
	for pattern in leak_patterns:
		if pattern.to_lower() in filtered.to_lower():
			contains_leak = true
			break

	if contains_leak and filtered.length() < 100:
		print("[HORTON_CHAT] WARNING: Filtered leaked state info")
		return "I... I'm sorry, what was I saying? My mind wanders when I'm anxious..."

	if contains_leak:
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
			filtered = "...sorry, I lost my train of thought. The Whos were distracting me."

	return filtered

func _process_horton_response(message: String) -> void:
	"""Process the filtered Horton response."""
	var display_message = message
	var player_trusted = false
	var horton_left = false

	# Check for outcome markers
	if "[HORTON_TRUSTS_YOU]" in message:
		player_trusted = true
		display_message = message.replace("[HORTON_TRUSTS_YOU]", "").strip_edges()
		game_state.current_phase = "resolved"

	if "[HORTON_RUNS_AWAY]" in message:
		horton_left = true
		display_message = message.replace("[HORTON_RUNS_AWAY]", "").strip_edges()
		game_state.current_phase = "ran_away"

	# Detect emotion from response
	var detected_emotion = _detect_emotion(message)

	# Update portrait
	if horton_left:
		_set_portrait("panicked")
		interpretation_failed.emit()
	elif player_trusted:
		_set_portrait("happy")
		message_decoded.emit()
	elif detected_emotion == "anxious":
		_set_portrait("anxious")
	elif detected_emotion == "sad":
		_set_portrait("sad")
		interpretation_failed.emit()
	elif detected_emotion == "happy":
		_set_portrait("happy")
		message_decoded.emit()
	else:
		_set_portrait("neutral")

	_add_message(display_message, false)
	conversation_history.append({"text": display_message, "is_user": false})

	# Handle outcomes
	if player_trusted:
		#await get_tree().create_timer(2.0).timeout
		_handle_trust_success()
	elif horton_left:
		#await get_tree().create_timer(2.0).timeout
		_handle_horton_ran_away()

func _detect_emotion(message: String) -> String:
	"""Detect Horton's emotion from response."""
	var msg_lower = message.to_lower()

	# PANICKED/ANXIOUS
	var anxious_keywords = [
		"oh no", "oh dear", "please", "i'm sorry", "don't", "can't",
		"worried", "scared", "help", "ah!", "aah", "*clutches*",
		"*winces*", "they'll die", "what if"
	]
	for keyword in anxious_keywords:
		if keyword in msg_lower:
			return "anxious"

	# SAD
	var sad_keywords = [
		"*ears droop*", "nobody believes", "alone", "crazy",
		"just like the others", "*trails off*", "leave", "left"
	]
	for keyword in sad_keywords:
		if keyword in msg_lower:
			return "sad"

	# HAPPY
	var happy_keywords = [
		"you believe", "thank you", "really?", "*happy*", "*perks up*",
		"wonderful", "you'd help", "not alone", "*small smile*"
	]
	for keyword in happy_keywords:
		if keyword in msg_lower:
			return "happy"

	return "neutral"

func _handle_trust_success() -> void:
	"""Handle Horton trusting the player."""
	print("[HORTON_CHAT] Horton trusts the player!")
	horton_trusts_player.emit()
	_add_message("*Horton carefully shows you the clover with the Whos* ...thank you for believing.", false)
	input_field.editable = false
	send_button.disabled = true
	# Complete the level
	GameState.complete_level("horton")

func _handle_horton_ran_away() -> void:
	"""Handle Horton running away."""
	print("[HORTON_CHAT] Horton ran away!")
	horton_ran_away.emit()
	_add_message("*Horton has fled with the clover, trumpeting anxiously in the distance*", false)
	input_field.editable = false
	send_button.disabled = true
	#await get_tree().create_timer(3.0).timeout
	close_chat()

func on_horton_message_failed(error_message: String) -> void:
	"""Handle Horton message failure."""
	print("[HORTON_CHAT] Horton message failed: ", error_message)
	_hide_typing_indicator()
	var error_text = "*Horton is too anxious to speak right now* ...I need a moment... " + error_message
	_add_message(error_text, false)

func _find_messages_container() -> VBoxContainer:
	"""Fallback method to find MessagesContainer."""
	var found = _search_for_node(self, "MessagesContainer")
	if found and found is VBoxContainer:
		return found as VBoxContainer
	return null

func _search_for_node(node: Node, target_name: String) -> Node:
	"""Recursively search for a node by name."""
	if node.name == target_name:
		return node
	for child in node.get_children():
		var result = _search_for_node(child, target_name)
		if result:
			return result
	return null

func _set_portrait(emotion: String) -> void:
	"""Set Horton's portrait based on emotion."""
	print("[HORTON_CHAT] Setting portrait to: ", emotion)
	if portrait and portrait_assets.has(emotion):
		var asset_path = portrait_assets[emotion]
		if asset_path != null and asset_path != "":
			var texture = load(asset_path)
			if texture:
				portrait.texture = texture

func reset_conversation() -> void:
	"""Reset the conversation state."""
	print("[HORTON_CHAT] Resetting conversation...")
	game_state = {
		"messages_decoded": 0,
		"total_failures": 0,
		"current_message_attempts": 0,
		"current_phase": "introduction"
	}
	conversation_history.clear()
	if chat_container:
		for child in chat_container.get_children():
			child.queue_free()
	if input_field:
		input_field.editable = true
	if send_button:
		send_button.disabled = false
	_set_portrait("anxious")
