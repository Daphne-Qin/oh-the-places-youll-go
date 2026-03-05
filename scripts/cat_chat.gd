extends Control

## Cat in the Hat Chat UI
## Player chats with the Cat — win by showing adventurous spirit (cat_engagement reaches 4)
## WIN: [CAT_ADVENTURE_BEGINS] → emit cat_adventure_begins signal

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal cat_adventure_begins   # WIN — Cat recruits player for the adventure

# ---------------------------------------------------------------------------
# Visual constants — Cat-in-the-Hat red/white theme
# ---------------------------------------------------------------------------
const CAT_BG      := Color(0.45, 0.06, 0.06, 1.0)   # Deep red header/bubble bg
const CAT_MSG     := Color(0.60, 0.10, 0.10, 1.0)   # Lighter red for Cat messages
const PLAYER_MSG  := Color(0.22, 0.38, 0.60, 1.0)   # Blue for player messages
const NARRATOR_MSG := Color(0.15, 0.30, 0.15, 1.0)  # Green for system messages
const PANEL_W     := 900.0
const PANEL_H     := 560.0

# ---------------------------------------------------------------------------
# UI nodes (all built in _build_ui)
# ---------------------------------------------------------------------------
var _background_overlay: ColorRect
var _chat_panel: PanelContainer
var _messages_container: VBoxContainer
var _scroll_container: ScrollContainer
var _typing_indicator: Label
var _input_field: LineEdit
var _send_button: Button
var _cat_status: Label
var _engagement_progress: Label

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var is_open: bool = false
var outcome_triggered: bool = false
var intro_shown: bool = false
var cat_engagement: int = 0     # 0-4; when 4 is reached, adventure_begins_now = true
var cat_ready_to_go: bool = false
var conversation_history: Array = []
var waiting_for_cat: bool = false

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	print("[CAT_CHAT] Initializing...")
	_build_ui()

	if APIManager:
		APIManager.cat_message_received.connect(_on_cat_response)
		APIManager.cat_message_failed.connect(_on_cat_failed)

	visible = false
	print("[CAT_CHAT] Ready.")

# ---------------------------------------------------------------------------
# _build_ui — full UI constructed in code
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Semi-transparent overlay
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color(0, 0, 0, 0.55)
	_background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_overlay)

	# Centered panel
	_chat_panel = PanelContainer.new()
	_chat_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chat_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_chat_panel.offset_left   = -PANEL_W / 2.0
	_chat_panel.offset_right  =  PANEL_W / 2.0
	_chat_panel.offset_top    = -PANEL_H / 2.0
	_chat_panel.offset_bottom =  PANEL_H / 2.0
	add_child(_chat_panel)

	var root_vbox = VBoxContainer.new()
	root_vbox.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	_chat_panel.add_child(root_vbox)

	# --- Header ---
	var header = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = CAT_BG
	header_style.corner_radius_top_left  = 8
	header_style.corner_radius_top_right = 8
	header_style.content_margin_left   = 12
	header_style.content_margin_right  = 12
	header_style.content_margin_top    = 8
	header_style.content_margin_bottom = 8
	header.add_theme_stylebox_override("panel", header_style)
	root_vbox.add_child(header)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 16)
	header.add_child(header_hbox)

	var title_label = Label.new()
	title_label.text = "The Cat in the Hat"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title_label)

	_engagement_progress = Label.new()
	_engagement_progress.text = "○○○○"
	_engagement_progress.add_theme_font_size_override("font_size", 18)
	_engagement_progress.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	header_hbox.add_child(_engagement_progress)

	_cat_status = Label.new()
	_cat_status.text = "Sizing you up..."
	_cat_status.add_theme_font_size_override("font_size", 13)
	_cat_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75, 1.0))
	header_hbox.add_child(_cat_status)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.pressed.connect(close_chat)
	header_hbox.add_child(close_btn)

	# --- Scroll area for messages ---
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.custom_minimum_size.y = 380
	root_vbox.add_child(_scroll_container)

	_messages_container = VBoxContainer.new()
	_messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_container.add_theme_constant_override("separation", 8)
	_scroll_container.add_child(_messages_container)

	# --- Typing indicator ---
	_typing_indicator = Label.new()
	_typing_indicator.text = "*hat tilts thoughtfully* The Cat is composing a response..."
	_typing_indicator.add_theme_font_size_override("font_size", 13)
	_typing_indicator.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	_typing_indicator.visible = false
	root_vbox.add_child(_typing_indicator)

	# --- Input row ---
	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	var input_margin = MarginContainer.new()
	input_margin.add_theme_constant_override("margin_left",   8)
	input_margin.add_theme_constant_override("margin_right",  8)
	input_margin.add_theme_constant_override("margin_bottom", 8)
	root_vbox.add_child(input_margin)
	input_margin.add_child(input_row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Say something to the Cat..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.text_submitted.connect(_on_input_submitted)
	input_row.add_child(_input_field)

	_send_button = Button.new()
	_send_button.text = "Send"
	_send_button.pressed.connect(_send_player_message)
	input_row.add_child(_send_button)

# ---------------------------------------------------------------------------
# open_chat / close_chat
# ---------------------------------------------------------------------------
func open_chat() -> void:
	show()
	is_open = true
	GameState.disable_movement()
	_input_field.grab_focus()

	if not intro_shown:
		intro_shown = true
		_add_narrator_message("The Cat in the Hat has appeared — hat first, naturally.")
		_request_cat_response("[INTRO] The player has walked up to you. Greet them with maximum theatrical flair and hint at the extraordinary adventure you are currently planning.")

func close_chat() -> void:
	hide()
	is_open = false
	GameState.enable_movement()

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _on_input_submitted(_text: String) -> void:
	_send_player_message()

func _send_player_message() -> void:
	var text = _input_field.text.strip_edges()
	if text.is_empty() or waiting_for_cat or outcome_triggered:
		return

	_input_field.text = ""
	_add_message(text, "You", PLAYER_MSG)
	conversation_history.append({"label": "Player", "text": text})
	_request_cat_response(text)

# ---------------------------------------------------------------------------
# API request
# ---------------------------------------------------------------------------
func _request_cat_response(user_message: String) -> void:
	waiting_for_cat = true
	_input_field.editable = false
	_send_button.disabled = true
	_typing_indicator.visible = true

	var game_state = {
		"cat_engagement": cat_engagement,
		"cat_ready_to_go": cat_ready_to_go,
		"adventure_begins_now": cat_engagement >= 4 and not outcome_triggered
	}
	APIManager.send_message_to_cat(user_message, conversation_history, game_state)

# ---------------------------------------------------------------------------
# Response handlers
# ---------------------------------------------------------------------------
func _on_cat_response(message: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	_typing_indicator.visible = false

	var adventure_triggered = false
	var clean_message = message

	if "[CAT_ADVENTURE_BEGINS]" in message:
		clean_message = message.replace("[CAT_ADVENTURE_BEGINS]", "").strip_edges()
		adventure_triggered = true

	_add_message(clean_message, "Cat", CAT_MSG)
	conversation_history.append({"label": "Cat", "text": clean_message})

	# Increment engagement after every successful Cat response (max 4)
	cat_engagement = min(cat_engagement + 1, 4)
	_update_engagement_display()

	if adventure_triggered and not outcome_triggered:
		outcome_triggered = true
		cat_ready_to_go = true
		_add_narrator_message("The Cat has chosen you as his companion! The adventure begins!")
		await get_tree().create_timer(2.5).timeout
		cat_adventure_begins.emit()

func _on_cat_failed(error: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	_typing_indicator.visible = false
	print("[CAT_CHAT] API error: ", error)
	_add_narrator_message("(The Cat appears momentarily distracted by something off-screen. Try again!)")

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _add_message(text: String, sender: String, bg_color: Color) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(6)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	panel.add_child(vbox)

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_font_size_override("font_size", 11)
	sender_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	vbox.add_child(sender_label)

	var msg_label = Label.new()
	msg_label.text = text
	msg_label.add_theme_font_size_override("font_size", 15)
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_label.custom_minimum_size.x = PANEL_W - 80
	vbox.add_child(msg_label)

	_messages_container.add_child(panel)

	await get_tree().process_frame
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)

func _add_narrator_message(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_container.add_child(label)

func _update_engagement_display() -> void:
	var filled = "●".repeat(cat_engagement)
	var empty  = "○".repeat(max(0, 4 - cat_engagement))
	_engagement_progress.text = filled + empty
	match cat_engagement:
		1: _cat_status.text = "Intrigued"
		2: _cat_status.text = "Impressed"
		3: _cat_status.text = "Delighted!"
		4: _cat_status.text = "READY!"
		_: _cat_status.text = "Sizing you up..."
