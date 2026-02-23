extends Control

## Three-Way Chat: Horton the Elephant ↔ Player ↔ Baron Von Bitey
##
## Story logic:
##   - Horton reveals a 4-stage Whoville crisis progressively
##   - Baron Von Bitey circles and grows more obsessed over time
##   - WIN:  Whoville celebration (crisis_stage 4 + enough engagement) defeats Baron
##   - FAIL1: Baron's patience runs out → he takes the clover
##   - FAIL2: Player ignores Horton long enough → Whos are lost
##
## All UI is built programmatically in _build_ui() so the .tscn is minimal.

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal horton_trusts_player   # WIN — Whoville saved, Baron defeated
signal baron_wins             # FAIL 1 — Baron took the clover
signal whos_lost              # FAIL 2 — Whos lost without player help

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------
const HORTON_BG   := Color(0.50, 0.33, 0.12, 1.0)   # warm dark brown/tan header
const HORTON_MSG  := Color(0.65, 0.45, 0.20, 1.0)   # warm orange-tan bubble
const BARON_BG    := Color(0.25, 0.08, 0.40, 1.0)   # deep purple header
const BARON_MSG   := Color(0.38, 0.12, 0.55, 1.0)   # deep purple bubble
const PLAYER_MSG  := Color(0.25, 0.42, 0.65, 1.0)   # soft blue bubble
const INTERJ_ALPHA := 0.70                            # alpha for interjection bubbles
const PANEL_W     := 1100.0
const PANEL_H     := 580.0

# ---------------------------------------------------------------------------
# UI nodes (built in _build_ui)
# ---------------------------------------------------------------------------
var _background_overlay: ColorRect
var _chat_panel: PanelContainer
var _messages_container: VBoxContainer
var _scroll_container: ScrollContainer
var _typing_indicator: Label
var _input_field: LineEdit
var _send_button: Button
var _horton_portrait: TextureRect
var _horton_status: Label
var _baron_status: Label

# ---------------------------------------------------------------------------
# Story / game state
# ---------------------------------------------------------------------------
var is_open: bool = false
var game_phase: String = "intro"   # intro | active | win | fail_baron | fail_whos
var outcome_triggered: bool = false
var intro_shown: bool = false

# Horton crisis tracking
var crisis_stage: int = 0       # 0-4
var horton_engagement: int = 0  # meaningful turns with Horton

# Baron escalation tracking
var baron_stage: int = 0
var baron_patience: float = 100.0
const PATIENCE_DECAY   := 8.0    # per timer tick
const PATIENCE_RESTORE := 8.0   # per player message sent
const PATIENCE_TICK_SEC := 20.0  # how often patience decays

# Conversation history (shared between all three)
# Each entry: { "label": "Player"|"Horton"|"Baron"|"Horton (to Baron)"|"Baron (to Horton)", "text": "..." }
var shared_history: Array = []

# Request chaining
var waiting_for_horton: bool = false
var waiting_for_baron: bool = false
var pending_baron_after_horton: bool = false
var interjection_pending: bool = false    # Baron interjection queued
var baron_interjection_text: String = ""  # saved so Horton can react to it
var _is_interjection_react: bool = false  # true when Horton reacts to Baron interjection (don't count as engagement)

# Sprites node reference (set by horton_level.gd)
var sprites_node: Node = null

# Timers
var _patience_timer: Timer
var _interjection_timer: Timer

# ---------------------------------------------------------------------------
# _ready — build UI + wire signals
# ---------------------------------------------------------------------------
func _ready() -> void:
	print("[HORTON_CHAT] Initializing three-way chat...")
	_build_ui()

	# API signals
	if APIManager:
		APIManager.horton_message_received.connect(_on_horton_response)
		APIManager.horton_message_failed.connect(_on_horton_failed)
		APIManager.baron_message_received.connect(_on_baron_response)
		APIManager.baron_message_failed.connect(_on_baron_failed)

	# Baron patience timer
	_patience_timer = Timer.new()
	_patience_timer.wait_time = PATIENCE_TICK_SEC
	_patience_timer.autostart = false
	_patience_timer.timeout.connect(_on_patience_tick)
	add_child(_patience_timer)

	# Character-to-character interjection timer (fires every 35-50 seconds)
	_interjection_timer = Timer.new()
	_interjection_timer.wait_time = 40.0
	_interjection_timer.autostart = false
	_interjection_timer.one_shot = true
	_interjection_timer.timeout.connect(_on_interjection_timer_timeout)
	add_child(_interjection_timer)

	visible = false
	print("[HORTON_CHAT] Ready.")

# ---------------------------------------------------------------------------
# _build_ui — construct entire UI programmatically
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	# Background overlay
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color(0, 0, 0, 0.55)
	_background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_overlay)

	# Main panel
	_chat_panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.06, 0.10, 0.97)
	panel_style.border_color = Color(0.55, 0.35, 0.75, 1.0)
	panel_style.border_width_left   = 3
	panel_style.border_width_top    = 3
	panel_style.border_width_right  = 3
	panel_style.border_width_bottom = 3
	panel_style.corner_radius_top_left     = 16
	panel_style.corner_radius_top_right    = 16
	panel_style.corner_radius_bottom_right = 16
	panel_style.corner_radius_bottom_left  = 16
	_chat_panel.add_theme_stylebox_override("panel", panel_style)
	_chat_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chat_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_chat_panel.offset_left   = -PANEL_W / 2.0
	_chat_panel.offset_right  =  PANEL_W / 2.0
	_chat_panel.offset_top    = -PANEL_H / 2.0
	_chat_panel.offset_bottom =  PANEL_H / 2.0
	add_child(_chat_panel)

	# Main VBox inside panel
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_chat_panel.add_child(main_vbox)

	# ---- Header row (Horton | Close | Baron) ----
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 90)
	header.add_theme_constant_override("separation", 0)
	main_vbox.add_child(header)

	# Horton section (left half of header)
	var horton_section = PanelContainer.new()
	var hs_style = StyleBoxFlat.new()
	hs_style.bg_color = HORTON_BG
	hs_style.corner_radius_top_left = 13
	hs_style.corner_radius_bottom_left = 0
	hs_style.corner_radius_top_right = 0
	hs_style.corner_radius_bottom_right = 0
	horton_section.add_theme_stylebox_override("panel", hs_style)
	horton_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(horton_section)

	var horton_inner = HBoxContainer.new()
	horton_inner.add_theme_constant_override("separation", 10)
	horton_section.add_child(horton_inner)

	# Horton portrait
	_horton_portrait = TextureRect.new()
	_horton_portrait.custom_minimum_size = Vector2(64, 64)
	_horton_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_horton_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_horton_portrait.texture = load("res://assets/sprites/horton/anxiousHorton.png")
	var hport_margin = MarginContainer.new()
	hport_margin.add_theme_constant_override("margin_left", 10)
	hport_margin.add_theme_constant_override("margin_top", 8)
	hport_margin.add_theme_constant_override("margin_bottom", 8)
	hport_margin.add_child(_horton_portrait)
	horton_inner.add_child(hport_margin)

	var horton_labels = VBoxContainer.new()
	horton_labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	horton_inner.add_child(horton_labels)

	var horton_name = Label.new()
	horton_name.text = "HORTON"
	horton_name.add_theme_font_size_override("font_size", 20)
	horton_name.add_theme_color_override("font_color", Color(1.0, 0.88, 0.65, 1))
	horton_labels.add_child(horton_name)

	_horton_status = Label.new()
	_horton_status.text = "Holding the clover..."
	_horton_status.add_theme_font_size_override("font_size", 12)
	_horton_status.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6, 0.8))
	horton_labels.add_child(_horton_status)

	# Close button (center of header)
	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(_on_close_pressed)
	var close_margin = MarginContainer.new()
	close_margin.add_theme_constant_override("margin_left", 8)
	close_margin.add_theme_constant_override("margin_right", 8)
	close_margin.add_child(close_btn)
	header.add_child(close_margin)

	# Baron section (right half of header)
	var baron_section = PanelContainer.new()
	var bs_style = StyleBoxFlat.new()
	bs_style.bg_color = BARON_BG
	bs_style.corner_radius_top_right = 13
	bs_style.corner_radius_bottom_right = 0
	bs_style.corner_radius_top_left = 0
	bs_style.corner_radius_bottom_left = 0
	baron_section.add_theme_stylebox_override("panel", bs_style)
	baron_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(baron_section)

	var baron_inner = HBoxContainer.new()
	baron_inner.add_theme_constant_override("separation", 10)
	baron_inner.alignment = BoxContainer.ALIGNMENT_END
	baron_section.add_child(baron_inner)

	var baron_labels = VBoxContainer.new()
	baron_labels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baron_inner.add_child(baron_labels)

	var baron_name = Label.new()
	baron_name.text = "BARON VON BITEY"
	baron_name.add_theme_font_size_override("font_size", 18)
	baron_name.add_theme_color_override("font_color", Color(0.85, 0.70, 1.0, 1))
	baron_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	baron_labels.add_child(baron_name)

	_baron_status = Label.new()
	_baron_status.text = "Circling nearby..."
	_baron_status.add_theme_font_size_override("font_size", 12)
	_baron_status.add_theme_color_override("font_color", Color(0.75, 0.60, 0.90, 0.8))
	_baron_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	baron_labels.add_child(_baron_status)

	# Baron icon (colored rectangle placeholder with monocle emoji)
	var baron_icon_margin = MarginContainer.new()
	baron_icon_margin.add_theme_constant_override("margin_right", 12)
	baron_icon_margin.add_theme_constant_override("margin_top", 8)
	baron_icon_margin.add_theme_constant_override("margin_bottom", 8)
	var baron_icon = Label.new()
	baron_icon.text = "🎩"
	baron_icon.add_theme_font_size_override("font_size", 36)
	baron_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baron_icon_margin.add_child(baron_icon)
	baron_inner.add_child(baron_icon_margin)

	# ---- Thin separator line ----
	var sep_line = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.55, 0.35, 0.75, 0.6)
	sep_line.add_theme_stylebox_override("separator", sep_style)
	main_vbox.add_child(sep_line)

	# ---- Chat scroll area ----
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(_scroll_container)

	_messages_container = VBoxContainer.new()
	_messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_messages_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_messages_container.add_theme_constant_override("separation", 8)
	var msg_margin = MarginContainer.new()
	msg_margin.add_theme_constant_override("margin_left", 12)
	msg_margin.add_theme_constant_override("margin_right", 12)
	msg_margin.add_theme_constant_override("margin_top", 8)
	msg_margin.add_theme_constant_override("margin_bottom", 4)
	msg_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(msg_margin)
	msg_margin.add_child(_messages_container)

	# ---- Typing indicator ----
	_typing_indicator = Label.new()
	_typing_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_typing_indicator.add_theme_font_size_override("font_size", 13)
	_typing_indicator.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1))
	_typing_indicator.text = ""
	_typing_indicator.visible = false
	_typing_indicator.custom_minimum_size = Vector2(0, 22)
	main_vbox.add_child(_typing_indicator)

	# ---- Input row ----
	var input_separator = HSeparator.new()
	var is_style = StyleBoxFlat.new()
	is_style.bg_color = Color(0.4, 0.25, 0.55, 0.5)
	input_separator.add_theme_stylebox_override("separator", is_style)
	main_vbox.add_child(input_separator)

	var input_panel = HBoxContainer.new()
	input_panel.add_theme_constant_override("separation", 8)
	input_panel.custom_minimum_size = Vector2(0, 52)
	var ip_margin = MarginContainer.new()
	ip_margin.add_theme_constant_override("margin_left", 10)
	ip_margin.add_theme_constant_override("margin_right", 10)
	ip_margin.add_theme_constant_override("margin_top", 6)
	ip_margin.add_theme_constant_override("margin_bottom", 8)
	ip_margin.add_child(input_panel)
	main_vbox.add_child(ip_margin)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Talk to Horton or the Baron..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 16)
	_input_field.text_submitted.connect(_on_input_submitted)
	input_panel.add_child(_input_field)

	_send_button = Button.new()
	_send_button.text = "Send ▶"
	_send_button.custom_minimum_size = Vector2(90, 0)
	_send_button.add_theme_font_size_override("font_size", 15)
	var send_style = StyleBoxFlat.new()
	send_style.bg_color = Color(0.45, 0.25, 0.65, 1)
	send_style.corner_radius_top_left     = 8
	send_style.corner_radius_top_right    = 8
	send_style.corner_radius_bottom_right = 8
	send_style.corner_radius_bottom_left  = 8
	_send_button.add_theme_stylebox_override("normal", send_style)
	_send_button.pressed.connect(_on_send_pressed)
	input_panel.add_child(_send_button)

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func set_sprites_node(node: Node) -> void:
	sprites_node = node

func open_chat(force_reset: bool = false) -> void:
	if is_open:
		return
	if force_reset:
		_reset_conversation()

	is_open = true
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	await tween.finished

	if not intro_shown:
		intro_shown = true
		_show_intro()
		game_phase = "active"

	_input_field.grab_focus()
	GameState.disable_movement()

	# Start timers when first opened
	if not _patience_timer.is_stopped():
		pass  # already running
	else:
		_patience_timer.start()
		_interjection_timer.start()

func close_chat() -> void:
	if not is_open:
		return
	is_open = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.2)
	await tween.finished
	visible = false
	GameState.enable_movement()

# ---------------------------------------------------------------------------
# Intro (shown once, no API call — immediate)
# ---------------------------------------------------------------------------
func _show_intro() -> void:
	_add_message(
		"*clutches the clover tightly and looks up with relief* Oh! Oh, thank goodness you're here! The Whos... something feels a little off today. And that Baron keeps circling. I'm... I'm so glad you came. Please — stay close.",
		"horton"
	)
	shared_history.append({"label": "Horton", "text": "*clutches the clover tightly and looks up with relief* Oh! Oh, thank goodness you're here! The Whos... something feels a little off today. And that Baron keeps circling. I'm... I'm so glad you came. Please — stay close."})

	await get_tree().create_timer(1.2).timeout

	_add_message(
		"*cape swirls as he turns to regard you* Ah. A small visitor. Baron Von Bitey acknowledges you, briefly. *eyes drift unmistakably to the clover* That is a remarkably... compelling piece of vegetation over there. Architecturally intriguing. Nothing more.",
		"baron"
	)
	shared_history.append({"label": "Baron", "text": "*cape swirls as he turns to regard you* Ah. A small visitor. Baron Von Bitey acknowledges you, briefly. *eyes drift unmistakably to the clover* That is a remarkably... compelling piece of vegetation over there. Architecturally intriguing. Nothing more."})

# ---------------------------------------------------------------------------
# Input handling
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and is_open:
		close_chat()

func _on_send_pressed() -> void:
	_send_player_message()

func _on_input_submitted(_text: String) -> void:
	_send_player_message()

func _send_player_message() -> void:
	if game_phase in ["win", "fail_baron", "fail_whos", "baron_attacking"]:
		return
	if waiting_for_horton or waiting_for_baron:
		return

	var text = _input_field.text.strip_edges()
	if text == "":
		return

	_input_field.text = ""

	# Show player message
	_add_message(text, "player")
	shared_history.append({"label": "Player", "text": text})

	# Restore some baron patience (player is engaged)
	baron_patience = min(100.0, baron_patience + PATIENCE_RESTORE)
	_update_baron_stage()

	# Send to Horton first, then baron responds after
	waiting_for_horton = true
	pending_baron_after_horton = true
	_show_typing("Horton is thinking...")
	APIManager.send_message_to_horton(text, shared_history, _build_horton_state())

func _on_close_pressed() -> void:
	close_chat()

# ---------------------------------------------------------------------------
# Horton response handling
# ---------------------------------------------------------------------------
func _on_horton_response(message: String) -> void:
	if game_phase in ["fail_baron", "fail_whos"]:
		return

	waiting_for_horton = false
	_hide_typing()

	var display = _strip_markers(message)
	_add_message(display, "horton")
	shared_history.append({"label": "Horton", "text": display})

	# Only count engagement for real player-driven turns, not interjection reactions
	if not _is_interjection_react:
		horton_engagement += 1
		_update_crisis_stage()
	_is_interjection_react = false
	_update_horton_portrait(message)
	_update_horton_status()

	# Check outcome markers
	if "[HORTON_WIN]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_horton_win()
		return
	if "[WHOS_LOST]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_whos_lost()
		return

	# Queue Baron's response
	if pending_baron_after_horton and game_phase == "active":
		pending_baron_after_horton = false
		await get_tree().create_timer(0.6).timeout
		if game_phase == "active":
			waiting_for_baron = true
			_show_typing("Baron Von Bitey is composing a response...")
			var baron_context = "The player said: \"" + shared_history[-2].get("text", "") + "\" — Horton just responded. Weigh in briefly in your theatrical style."
			APIManager.send_message_to_baron(baron_context, shared_history, _build_baron_state())

func _on_horton_failed(error: String) -> void:
	waiting_for_horton = false
	pending_baron_after_horton = false
	_hide_typing()
	_add_message("*Horton is too anxious to speak right now* ...Give me a moment... " + error, "horton")

# ---------------------------------------------------------------------------
# Baron response handling
# ---------------------------------------------------------------------------
func _on_baron_response(message: String) -> void:
	if game_phase in ["fail_whos", "fail_baron"]:
		return

	waiting_for_baron = false
	_hide_typing()

	# Handle interjection round-trip (Horton now reacts to Baron)
	if interjection_pending:
		interjection_pending = false
		var display = _strip_markers(message)
		_add_message(display, "baron", true)
		shared_history.append({"label": "Baron (to Horton)", "text": display})
		baron_interjection_text = display
		# Horton reacts — mark as interjection so engagement counter is not incremented
		await get_tree().create_timer(0.7).timeout
		if game_phase == "active":
			_is_interjection_react = true
			waiting_for_horton = true
			_show_typing("Horton is reacting...")
			var react_msg = "[Baron Von Bitey just said to you: '" + baron_interjection_text + "'. React briefly and anxiously. Address Baron, not the player. 1-2 sentences only.]"
			APIManager.send_message_to_horton(react_msg, shared_history, _build_horton_state(true))
		return

	var display = _strip_markers(message)
	_add_message(display, "baron")
	shared_history.append({"label": "Baron", "text": display})
	_update_baron_status()

	# Check outcome markers
	if "[BARON_TAKES_CLOVER]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_baron_wins()
		return
	if "[BARON_RETREATS]" in message:
		_finalize_win_aftermath()
		return

func _on_baron_failed(error: String) -> void:
	waiting_for_baron = false
	interjection_pending = false
	_hide_typing()
	_add_message("*adjusts monocle in silence* ...Baron Von Bitey has nothing to say to that. (" + error + ")", "baron")

# ---------------------------------------------------------------------------
# Story state updates
# ---------------------------------------------------------------------------
func _update_crisis_stage() -> void:
	# Advance one stage every 2 meaningful Horton exchanges
	var new_stage = min(4, horton_engagement / 2)
	if new_stage > crisis_stage:
		crisis_stage = new_stage
		print("[HORTON_CHAT] Crisis stage advanced to: ", crisis_stage)

func _update_baron_stage() -> void:
	if baron_patience > 75.0:
		baron_stage = 0
	elif baron_patience > 50.0:
		baron_stage = 1
	elif baron_patience > 25.0:
		baron_stage = 2
	elif baron_patience > 10.0:
		baron_stage = 3
	else:
		baron_stage = 4

func _build_horton_state(is_interjection_react: bool = false) -> Dictionary:
	var state = {
		"crisis_stage": crisis_stage,
		"horton_engagement": horton_engagement,
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"resolve_now": false,
		"whos_lost_now": false,
		"baron_took_clover": (game_phase == "fail_baron")
	}
	# Trigger win if fully ready
	if crisis_stage >= 4 and horton_engagement >= 5 and game_phase == "active" and not outcome_triggered:
		state["resolve_now"] = true
	# Trigger Whos lost if player has ignored Horton
	if horton_engagement < 2 and shared_history.size() > 14 and game_phase == "active" and not outcome_triggered:
		state["whos_lost_now"] = true
	return state

func _build_baron_state(take_clover: bool = false, celebrate: bool = false) -> Dictionary:
	return {
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"crisis_stage": crisis_stage,
		"take_clover_now": take_clover,
		"celebration_victory": celebrate,
		"is_interjection": false
	}

func _build_baron_interjection_state() -> Dictionary:
	return {
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"crisis_stage": crisis_stage,
		"take_clover_now": false,
		"celebration_victory": false,
		"is_interjection": true
	}

# ---------------------------------------------------------------------------
# Timers
# ---------------------------------------------------------------------------
func _on_patience_tick() -> void:
	if game_phase != "active" or outcome_triggered:
		return
	baron_patience = max(0.0, baron_patience - PATIENCE_DECAY)
	_update_baron_stage()
	_update_baron_status()
	print("[HORTON_CHAT] Baron patience: %.0f, stage: %d" % [baron_patience, baron_stage])

	# Trigger baron's move if patience is exhausted
	if baron_patience <= 0 and not outcome_triggered:
		outcome_triggered = true
		_trigger_baron_move()

func _on_interjection_timer_timeout() -> void:
	if game_phase != "active" or outcome_triggered:
		_schedule_next_interjection()
		return
	if waiting_for_horton or waiting_for_baron:
		# Defer slightly if already waiting
		await get_tree().create_timer(5.0).timeout
		_on_interjection_timer_timeout()
		return

	# Baron addresses Horton directly
	interjection_pending = true
	waiting_for_baron = true
	_show_typing("Baron Von Bitey clears his throat...")
	var interjection_prompt = "[DIRECT EXCHANGE WITH HORTON — the player is watching but you are speaking TO Horton. Say something theatrically taunting or philosophical about the clover, or about Horton's dedication. Keep it to 1-2 sentences. Be brilliantly menacing or funny.]"
	APIManager.send_message_to_baron(interjection_prompt, shared_history, _build_baron_interjection_state())
	# Horton's reaction is triggered inside _on_baron_response when interjection_pending is true
	_schedule_next_interjection()

func _schedule_next_interjection() -> void:
	# Random interval 35-55 seconds
	_interjection_timer.wait_time = 35.0 + randf() * 20.0
	_interjection_timer.one_shot = true
	_interjection_timer.start()

# ---------------------------------------------------------------------------
# Baron's patience runs out — he makes his move
# ---------------------------------------------------------------------------
func _trigger_baron_move() -> void:
	game_phase = "baron_attacking"
	_add_message("*The Baron's patience has finally snapped. He begins moving toward the clover with unmistakable purpose...*", "baron", true)
	await get_tree().create_timer(1.5).timeout

	# Tell baron to take clover
	waiting_for_baron = true
	_show_typing("Baron Von Bitey is making his move!")
	APIManager.send_message_to_baron(
		"[The time for waiting is over. Move toward the clover. Include [BARON_TAKES_CLOVER].]",
		shared_history,
		_build_baron_state(true, false)
	)

# ---------------------------------------------------------------------------
# Win condition
# ---------------------------------------------------------------------------
func _handle_horton_win() -> void:
	game_phase = "win"
	_patience_timer.stop()
	_interjection_timer.stop()
	_update_horton_portrait_direct("happy")

	# Now send celebration signal to Baron to trigger his defeat
	await get_tree().create_timer(2.0).timeout
	waiting_for_baron = true
	_show_typing("Something is happening to the Baron...")
	APIManager.send_message_to_baron(
		"[WHOVILLE CELEBRATION: A massive wave of joyful noise just hit you from the direction of the clover. You are physically staggered and fall into a mud puddle. Retreat in magnificent denial. Include [BARON_RETREATS].]",
		shared_history,
		_build_baron_state(false, true)
	)

func _finalize_win_aftermath() -> void:
	game_phase = "win"
	_baron_status.text = "Retreating in defeat..."
	_update_horton_status()

	if sprites_node and sprites_node.has_method("baron_defeat_retreat"):
		sprites_node.baron_defeat_retreat()

	await get_tree().create_timer(1.5).timeout
	_add_message("*holds the clover up to the light, tears streaming down his enormous cheeks* They're okay... they're all okay. I meant what I said, and I said what I meant. An elephant's faithful... one hundred percent.", "horton")

	_input_field.editable = false
	_send_button.disabled = true
	await get_tree().create_timer(2.0).timeout
	horton_trusts_player.emit()
	GameState.complete_level("horton")

# ---------------------------------------------------------------------------
# Fail condition 1 — Baron wins
# ---------------------------------------------------------------------------
func _handle_baron_wins() -> void:
	game_phase = "fail_baron"
	_patience_timer.stop()
	_interjection_timer.stop()

	if sprites_node and sprites_node.has_method("baron_make_move_for_clover"):
		sprites_node.baron_make_move_for_clover()

	_baron_status.text = "Has taken the clover!"
	_update_horton_portrait_direct("anxious")

	await get_tree().create_timer(2.0).timeout
	_add_message("*staggers backward, trunk reaching out desperately* No... no, no, NO! The clover... the WHOS... *trumpets in anguish* They're just trying to live! How could you— how could anyone—", "horton")
	_input_field.editable = false
	_send_button.disabled = true
	await get_tree().create_timer(3.0).timeout
	baron_wins.emit()

# ---------------------------------------------------------------------------
# Fail condition 2 — Whos are lost
# ---------------------------------------------------------------------------
func _handle_whos_lost() -> void:
	game_phase = "fail_whos"
	_patience_timer.stop()
	_interjection_timer.stop()

	_update_horton_portrait_direct("anxious")
	_horton_status.text = "The Whos are lost..."

	_input_field.editable = false
	_send_button.disabled = true
	await get_tree().create_timer(3.0).timeout
	whos_lost.emit()

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _add_message(text: String, speaker: String, is_interjection: bool = false) -> void:
	if not is_instance_valid(_messages_container):
		return

	var row = _create_bubble(text, speaker, is_interjection)
	_messages_container.add_child(row)

	row.modulate.a = 0.0
	row.scale = Vector2(0.95, 0.95)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(row, "modulate:a", 1.0, 0.2)
	tween.tween_property(row, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

	await get_tree().process_frame
	_scroll_to_bottom()

func _create_bubble(text: String, speaker: String, is_interjection: bool = false) -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)

	# Spacer for right-aligned speakers
	if speaker in ["baron", "player", "baron_to_horton"]:
		var sp = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_stretch_ratio = 0.35
		row.add_child(sp)

	# Message column: speaker name + bubble
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	row.add_child(col)

	# Speaker name label
	var name_lbl = Label.new()
	name_lbl.text = _get_speaker_label(speaker, is_interjection)
	name_lbl.add_theme_font_size_override("font_size", 12)
	var name_color = _get_speaker_color(speaker).lightened(0.4)
	name_color.a = 0.9
	name_lbl.add_theme_color_override("font_color", name_color)
	if speaker in ["baron", "player"]:
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(name_lbl)

	# Bubble panel
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	var bg_color = _get_speaker_color(speaker)
	if is_interjection:
		bg_color.a = INTERJ_ALPHA
	style.bg_color = bg_color
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10 if speaker in ["baron", "player"] else 3
	style.corner_radius_bottom_right = 3 if speaker in ["baron", "player"] else 10
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16 if not is_interjection else 14)
	var text_color = Color(1, 1, 1, 0.92 if not is_interjection else 0.75)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_constant_override("line_spacing", 3)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(label)
	panel.add_child(margin)
	col.add_child(panel)

	# Spacer for left-aligned speakers
	if speaker in ["horton", "horton_to_baron"]:
		var sp = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_stretch_ratio = 0.35
		row.add_child(sp)

	return row

func _get_speaker_label(speaker: String, is_interjection: bool) -> String:
	if is_interjection:
		match speaker:
			"horton": return "Horton → Baron"
			"baron":  return "Baron → Horton"
	match speaker:
		"horton":         return "Horton"
		"baron":          return "Baron Von Bitey"
		"player":         return "You"
		"horton_to_baron": return "Horton → Baron"
		"baron_to_horton": return "Baron → Horton"
	return speaker

func _get_speaker_color(speaker: String) -> Color:
	match speaker:
		"horton", "horton_to_baron": return HORTON_MSG
		"baron", "baron_to_horton":  return BARON_MSG
		"player": return PLAYER_MSG
	return Color(0.3, 0.3, 0.3)

func _show_typing(who: String) -> void:
	_typing_indicator.text = who
	_typing_indicator.visible = true

func _hide_typing() -> void:
	_typing_indicator.visible = false
	_typing_indicator.text = ""

func _scroll_to_bottom() -> void:
	if not is_instance_valid(_scroll_container):
		return
	await get_tree().process_frame
	var v_bar = _scroll_container.get_v_scroll_bar()
	if v_bar:
		_scroll_container.scroll_vertical = int(v_bar.max_value)

func _strip_markers(message: String) -> String:
	var result = message
	for marker in ["[HORTON_WIN]", "[WHOS_LOST]", "[BARON_TAKES_CLOVER]", "[BARON_RETREATS]"]:
		result = result.replace(marker, "")
	return result.strip_edges()

func _update_horton_portrait(message: String) -> void:
	var msg_lower = message.to_lower()
	if "thank" in msg_lower or "wonderful" in msg_lower or "we did it" in msg_lower or "[horton_win]" in msg_lower:
		_update_horton_portrait_direct("happy")
	elif "oh no" in msg_lower or "please" in msg_lower or "afraid" in msg_lower or "scared" in msg_lower:
		_update_horton_portrait_direct("anxious")

func _update_horton_portrait_direct(emotion: String) -> void:
	if not is_instance_valid(_horton_portrait):
		return
	var path = "res://assets/sprites/horton/anxiousHorton.png"
	if emotion == "happy":
		path = "res://assets/sprites/horton/happyCHAT.png"
	var tex = load(path)
	if tex:
		_horton_portrait.texture = tex

func _update_horton_status() -> void:
	if not is_instance_valid(_horton_status):
		return
	match crisis_stage:
		0: _horton_status.text = "Holding the clover..."
		1: _horton_status.text = "The Mayor is missing!"
		2: _horton_status.text = "The Whos are scared..."
		3: _horton_status.text = "The fountain cracked!"
		4: _horton_status.text = "JoJo has a plan!"

func _update_baron_status() -> void:
	if not is_instance_valid(_baron_status):
		return
	match baron_stage:
		0: _baron_status.text = "Circling nearby..."
		1: _baron_status.text = "Eyeing the clover..."
		2: _baron_status.text = "Obsessed with Clementine..."
		3: _baron_status.text = "Moving closer..."
		4: _baron_status.text = "Making his move!"

func _reset_conversation() -> void:
	print("[HORTON_CHAT] Resetting conversation...")
	game_phase = "intro"
	outcome_triggered = false
	intro_shown = false
	crisis_stage = 0
	horton_engagement = 0
	baron_stage = 0
	baron_patience = 100.0
	shared_history.clear()
	waiting_for_horton = false
	waiting_for_baron = false
	pending_baron_after_horton = false
	interjection_pending = false
	_is_interjection_react = false

	if is_instance_valid(_messages_container):
		for child in _messages_container.get_children():
			child.queue_free()
	if is_instance_valid(_input_field):
		_input_field.editable = true
	if is_instance_valid(_send_button):
		_send_button.disabled = false
	_update_horton_portrait_direct("anxious")
	_update_horton_status()
	_update_baron_status()
