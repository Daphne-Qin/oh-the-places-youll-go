extends Control

## Three-Way Chat: Horton the Elephant ↔ Player ↔ Baron Von Bitey
##
## Core mechanic: Decipher 5 garbled Who messages to find the missing Mayor.
## Baron periodically chases Horton (handled by level) — if he grabs the clover,
## player must talk to Baron and reveal the Cat in the Hat pasta plan to get it back.
##
## WIN: All 5 messages decoded → JoJo rallies Whoville → Baron defeated
## FAIL1: Baron's patience runs out → he takes the clover for Mischief Minestrone
## FAIL2: Player ignores messages too long → Whos are lost

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal horton_trusts_player   # WIN — Whoville saved, Baron defeated
signal baron_wins             # FAIL 1 — Baron took the clover (ran out of patience)
signal whos_lost              # FAIL 2 — Whos lost (messages ignored too long)
signal baron_drops_clover     # Baron drops clover — player gets it, must return to Horton

# ---------------------------------------------------------------------------
# The 5 garbled Who messages (indexed by decode_stage 0-4)
# ---------------------------------------------------------------------------
const DECODE_MESSAGES: Array[String] = [
	"\"SHAKING... BIG... NEARBY... HELP!\"",
	"\"MAYOR... GONE... MISSING... SEARCHING...\"",
	"\"FOUND... CRACK... HALL... SOMEONE... THERE!\"",
	"\"MAYOR!... STUCK... CALLING... INSIDE...\"",
	"\"EVERYONE... SHOUT... JOJO... TOGETHER... NOW!\""
]

const DECODE_HINTS: Array[String] = [
	"Decoded: Baron's footsteps = Whoville earthquakes",
	"Decoded: The Mayor went missing!",
	"Decoded: Found a crack in Town Hall",
	"Decoded: Mayor trapped inside the crack!",
	"Decoded: JoJo rallies everyone to shout!"
]

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------
const HORTON_BG   := Color(0.50, 0.33, 0.12, 1.0)
const HORTON_MSG  := Color(0.65, 0.45, 0.20, 1.0)
const BARON_BG    := Color(0.25, 0.08, 0.40, 1.0)
const BARON_MSG   := Color(0.38, 0.12, 0.55, 1.0)
const PLAYER_MSG  := Color(0.25, 0.42, 0.65, 1.0)
const NARRATOR_MSG := Color(0.15, 0.30, 0.15, 1.0)
const INTERJ_ALPHA := 0.70
const PANEL_W     := 1100.0
const PANEL_H     := 600.0

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
var _horton_section: PanelContainer
var _baron_section: PanelContainer
var _decode_progress: Label

# ---------------------------------------------------------------------------
# Story / game state
# ---------------------------------------------------------------------------
var is_open: bool = false
var game_phase: String = "intro"   # intro | active | win | fail_baron | fail_whos
var outcome_triggered: bool = false
var intro_shown: bool = false
var chat_mode: String = "horton"   # "horton" | "baron"

# Decode mechanic
var decode_stage: int = 0          # 0-5 (5 = all decoded)

# Horton engagement
var horton_engagement: int = 0

# Baron escalation
var baron_stage: int = 0
var baron_patience: float = 100.0
const PATIENCE_DECAY    := 8.0
const PATIENCE_RESTORE  := 8.0
const PATIENCE_TICK_SEC := 20.0

# Clover ownership (synced from level via set_clover_state)
var clover_state: String = "horton"  # "horton" | "baron" | "player"

# Conversation history (shared)
var shared_history: Array = []

# Request chaining
var waiting_for_horton: bool = false
var waiting_for_baron: bool = false
var pending_baron_after_horton: bool = false
var interjection_pending: bool = false
var baron_interjection_text: String = ""
var _is_interjection_react: bool = false

# Sprites node reference (set by horton_level.gd)
var sprites_node: Node = null

# Timers
var _patience_timer: Timer
var _interjection_timer: Timer

# ---------------------------------------------------------------------------
# _ready — build UI + wire signals
# ---------------------------------------------------------------------------
func _ready() -> void:
	print("[HORTON_CHAT] Initializing...")
	_build_ui()

	if APIManager:
		APIManager.horton_message_received.connect(_on_horton_response)
		APIManager.horton_message_failed.connect(_on_horton_failed)
		APIManager.baron_message_received.connect(_on_baron_response)
		APIManager.baron_message_failed.connect(_on_baron_failed)

	_patience_timer = Timer.new()
	_patience_timer.wait_time = PATIENCE_TICK_SEC
	_patience_timer.autostart = false
	_patience_timer.timeout.connect(_on_patience_tick)
	add_child(_patience_timer)

	_interjection_timer = Timer.new()
	_interjection_timer.wait_time = 40.0
	_interjection_timer.autostart = false
	_interjection_timer.one_shot = true
	_interjection_timer.timeout.connect(_on_interjection_timer_timeout)
	add_child(_interjection_timer)

	visible = false
	print("[HORTON_CHAT] Ready.")

# ---------------------------------------------------------------------------
# _build_ui — full UI constructed in code
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color(0, 0, 0, 0.55)
	_background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_overlay)

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

	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	_chat_panel.add_child(main_vbox)

	# ---- Header row (Horton | Close | Baron) ----
	var header = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 90)
	header.add_theme_constant_override("separation", 0)
	main_vbox.add_child(header)

	# Horton section
	_horton_section = PanelContainer.new()
	var hs_style = StyleBoxFlat.new()
	hs_style.bg_color = HORTON_BG
	hs_style.corner_radius_top_left = 13
	_horton_section.add_theme_stylebox_override("panel", hs_style)
	_horton_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_horton_section)

	var horton_inner = HBoxContainer.new()
	horton_inner.add_theme_constant_override("separation", 10)
	_horton_section.add_child(horton_inner)

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

	# Close button (center)
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

	# Baron section
	_baron_section = PanelContainer.new()
	var bs_style = StyleBoxFlat.new()
	bs_style.bg_color = BARON_BG
	bs_style.corner_radius_top_right = 13
	_baron_section.add_theme_stylebox_override("panel", bs_style)
	_baron_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_baron_section)

	var baron_inner = HBoxContainer.new()
	baron_inner.add_theme_constant_override("separation", 10)
	baron_inner.alignment = BoxContainer.ALIGNMENT_END
	_baron_section.add_child(baron_inner)

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

	# ---- Decode progress bar ----
	var decode_bar_bg = PanelContainer.new()
	var dbb_style = StyleBoxFlat.new()
	dbb_style.bg_color = Color(0.10, 0.12, 0.10, 1.0)
	decode_bar_bg.add_theme_stylebox_override("panel", dbb_style)
	decode_bar_bg.custom_minimum_size = Vector2(0, 28)
	main_vbox.add_child(decode_bar_bg)

	var decode_hbox = HBoxContainer.new()
	decode_hbox.add_theme_constant_override("separation", 8)
	var decode_margin = MarginContainer.new()
	decode_margin.add_theme_constant_override("margin_left", 12)
	decode_margin.add_theme_constant_override("margin_right", 12)
	decode_margin.add_theme_constant_override("margin_top", 4)
	decode_margin.add_theme_constant_override("margin_bottom", 4)
	decode_margin.add_child(decode_hbox)
	decode_bar_bg.add_child(decode_margin)

	var decode_lbl = Label.new()
	decode_lbl.text = "Who Messages:"
	decode_lbl.add_theme_font_size_override("font_size", 13)
	decode_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.6, 0.9))
	decode_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decode_hbox.add_child(decode_lbl)

	_decode_progress = Label.new()
	_decode_progress.text = "○ ○ ○ ○ ○"
	_decode_progress.add_theme_font_size_override("font_size", 16)
	_decode_progress.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5, 1))
	_decode_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decode_hbox.add_child(_decode_progress)

	var decode_hint = Label.new()
	decode_hint.text = "Decode 5 Who messages to save Whoville!"
	decode_hint.add_theme_font_size_override("font_size", 11)
	decode_hint.add_theme_color_override("font_color", Color(0.6, 0.7, 0.6, 0.7))
	decode_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decode_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	decode_hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decode_hbox.add_child(decode_hint)

	# ---- Separator ----
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
	var input_sep = HSeparator.new()
	var is_style = StyleBoxFlat.new()
	is_style.bg_color = Color(0.4, 0.25, 0.55, 0.5)
	input_sep.add_theme_stylebox_override("separator", is_style)
	main_vbox.add_child(input_sep)

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
	_input_field.placeholder_text = "Help Horton decode the Who message..."
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

func get_decode_stage() -> int:
	return decode_stage

func set_clover_state(state: String) -> void:
	clover_state = state
	_update_baron_status()

func open_chat(mode: String = "horton") -> void:
	if is_open:
		# If switching modes while open, update mode and placeholder
		if chat_mode != mode:
			chat_mode = mode
			_update_chat_mode_ui()
		return

	chat_mode = mode
	is_open = true
	visible = true
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

	_update_chat_mode_ui()

	if not intro_shown:
		intro_shown = true
		_show_intro()
		game_phase = "active"

	_input_field.grab_focus()
	GameState.disable_movement()

	if _patience_timer.is_stopped():
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

func forced_close(reason: String = "") -> void:
	"""Close the chat immediately (e.g. during a Baron chase)."""
	print("[HORTON_CHAT] Forced close: ", reason)
	is_open = false
	visible = false
	GameState.enable_movement()

# ---------------------------------------------------------------------------
# Intro (shown once, immediate — no API call)
# ---------------------------------------------------------------------------
func _show_intro() -> void:
	var current_msg = DECODE_MESSAGES[min(decode_stage, 4)]
	_add_message(
		"*clutches the clover tightly and looks up with relief* Oh! Oh, thank goodness you're here! I keep hearing something from the clover — something strange. Listen — it sounds like " + current_msg + " — can you help me understand?",
		"horton"
	)
	shared_history.append({"label": "Horton", "text": "*clutches the clover tightly* Oh! I keep hearing something from the clover — " + current_msg + " — do you know what that could mean?"})

	await get_tree().create_timer(1.2).timeout
	if not is_open and not is_instance_valid(self):
		return

	_add_message(
		"*cape swirls as he turns to regard you* Ah. A small visitor. Baron Von Bitey acknowledges you, briefly. *eyes drift to the clover* A remarkably... culinarily significant piece of vegetation over there. Micro-herb of the highest order. The Baron simply needs it. For soup.",
		"baron"
	)
	shared_history.append({"label": "Baron", "text": "*adjusts monocle* Ah. Baron Von Bitey acknowledges you. *eyes drift to the clover* That is a remarkably fine micro-herb. The Baron simply needs it. For soup."})

# ---------------------------------------------------------------------------
# Chat mode UI updates
# ---------------------------------------------------------------------------
func _update_chat_mode_ui() -> void:
	if not is_instance_valid(_horton_section) or not is_instance_valid(_baron_section):
		return
	# Brighten the active speaker's header
	var hs_style = StyleBoxFlat.new()
	hs_style.corner_radius_top_left = 13
	var bs_style = StyleBoxFlat.new()
	bs_style.corner_radius_top_right = 13

	if chat_mode == "horton":
		hs_style.bg_color = HORTON_BG.lightened(0.12)
		bs_style.bg_color = BARON_BG.darkened(0.15)
		_input_field.placeholder_text = "Help Horton decode the Who message..."
	else:
		hs_style.bg_color = HORTON_BG.darkened(0.15)
		bs_style.bg_color = BARON_BG.lightened(0.12)
		_input_field.placeholder_text = "Negotiate with the Baron..."

	_horton_section.add_theme_stylebox_override("panel", hs_style)
	_baron_section.add_theme_stylebox_override("panel", bs_style)

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

	_add_message(text, "player")
	shared_history.append({"label": "Player", "text": text})

	# Talking to the Baron restores patience (and delays patrol)
	baron_patience = min(100.0, baron_patience + PATIENCE_RESTORE)
	_update_baron_stage()

	if chat_mode == "baron":
		# Direct baron conversation — baron responds only, no Horton chain
		waiting_for_baron = true
		_show_typing("Baron Von Bitey is composing a response...")
		APIManager.send_message_to_baron(text, shared_history, _build_baron_state())
	else:
		# Default: Horton responds, then Baron weighs in
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

	if not _is_interjection_react:
		horton_engagement += 1
	_is_interjection_react = false
	_update_horton_portrait(message)
	_update_horton_status()

	# Check: did player decode the current message?
	if "[MESSAGE_DECODED]" in message and not outcome_triggered:
		decode_stage += 1
		print("[HORTON_CHAT] Message decoded! decode_stage=", decode_stage)
		_update_decode_progress()
		_add_narrator_message("★ Who message decoded! (" + str(decode_stage) + "/5) — " + DECODE_HINTS[decode_stage - 1])
		if decode_stage >= 5:
			outcome_triggered = true
			_trigger_jojo_finale()
		else:
			# Announce the next message
			await get_tree().create_timer(0.8).timeout
			if game_phase == "active":
				_add_narrator_message("Horton strains to hear... a new fragment is forming from Whoville!")
		return

	# Classic win / fail markers
	if "[HORTON_WIN]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_horton_win()
		return
	if "[WHOS_LOST]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_whos_lost()
		return

	# Chain Baron's response after Horton (normal flow)
	if pending_baron_after_horton and game_phase == "active":
		pending_baron_after_horton = false
		await get_tree().create_timer(0.6).timeout
		if game_phase == "active":
			waiting_for_baron = true
			_show_typing("Baron Von Bitey is composing a response...")
			var player_msg = shared_history[-2].get("text", "") if shared_history.size() >= 2 else ""
			var baron_ctx = "The player said: \"" + player_msg + "\" — Horton just responded. Add a brief theatrical comment about the clover or the dinner situation."
			APIManager.send_message_to_baron(baron_ctx, shared_history, _build_baron_state())

func _on_horton_failed(error: String) -> void:
	waiting_for_horton = false
	pending_baron_after_horton = false
	_hide_typing()
	_add_message("*Horton is too anxious to speak right now* ...Give me a moment... (" + error + ")", "horton")

# ---------------------------------------------------------------------------
# Baron response handling
# ---------------------------------------------------------------------------
func _on_baron_response(message: String) -> void:
	if game_phase in ["fail_whos", "fail_baron"]:
		return

	waiting_for_baron = false
	_hide_typing()

	# Handle interjection round-trip (Horton reacts to Baron)
	if interjection_pending:
		interjection_pending = false
		var display = _strip_markers(message)
		_add_message(display, "baron", true)
		shared_history.append({"label": "Baron (to Horton)", "text": display})
		baron_interjection_text = display
		await get_tree().create_timer(0.7).timeout
		if game_phase == "active":
			_is_interjection_react = true
			waiting_for_horton = true
			_show_typing("Horton is reacting...")
			var react_msg = "[Baron Von Bitey just said to you: '" + baron_interjection_text + "'. React briefly and anxiously. Address Baron directly. 1-2 sentences only.]"
			APIManager.send_message_to_horton(react_msg, shared_history, _build_horton_state(true))
		return

	var display = _strip_markers(message)
	_add_message(display, "baron")
	shared_history.append({"label": "Baron", "text": display})
	_update_baron_status()

	# Baron drops clover — pasta plan foiled!
	if "[BARON_DROPS_CLOVER]" in message and not outcome_triggered:
		_baron_status.text = "Dropped the clover!"
		if sprites_node and sprites_node.has_method("baron_drops_clover_visual"):
			sprites_node.baron_drops_clover_visual()
		await get_tree().create_timer(0.8).timeout
		baron_drops_clover.emit()
		close_chat()
		return

	# Baron patience fails → grabs clover
	if "[BARON_TAKES_CLOVER]" in message and not outcome_triggered:
		outcome_triggered = true
		_handle_baron_wins()
		return

	# Baron retreats after Whoville shout
	if "[BARON_RETREATS]" in message:
		_finalize_win_aftermath()
		return

func _on_baron_failed(error: String) -> void:
	waiting_for_baron = false
	interjection_pending = false
	_hide_typing()
	_add_message("*adjusts monocle in silence* ...Baron Von Bitey has nothing to say. (" + error + ")", "baron")

# ---------------------------------------------------------------------------
# Story state
# ---------------------------------------------------------------------------
func _update_baron_stage() -> void:
	if baron_patience > 75.0:   baron_stage = 0
	elif baron_patience > 50.0: baron_stage = 1
	elif baron_patience > 25.0: baron_stage = 2
	elif baron_patience > 10.0: baron_stage = 3
	else:                       baron_stage = 4

func _build_horton_state(is_interjection_react: bool = false) -> Dictionary:
	var state = {
		"decode_stage": decode_stage,
		"current_message": DECODE_MESSAGES[min(decode_stage, 4)],
		"horton_engagement": horton_engagement,
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"resolve_now": false,
		"whos_lost_now": false,
		"baron_took_clover": (clover_state == "baron")
	}
	# Whos lost: player has talked many times but decoded nothing
	if horton_engagement > 10 and decode_stage < 1 and game_phase == "active" and not outcome_triggered:
		state["whos_lost_now"] = true
	return state

func _build_baron_state(take_clover: bool = false, celebrate: bool = false) -> Dictionary:
	return {
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"decode_stage": decode_stage,
		"clover_state": clover_state,
		"baron_has_clover": (clover_state == "baron"),
		"take_clover_now": take_clover,
		"celebration_victory": celebrate,
		"is_interjection": false
	}

func _build_baron_interjection_state() -> Dictionary:
	return {
		"baron_stage": baron_stage,
		"baron_patience": baron_patience,
		"game_phase": game_phase,
		"decode_stage": decode_stage,
		"clover_state": clover_state,
		"baron_has_clover": (clover_state == "baron"),
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

	if baron_patience <= 0 and not outcome_triggered:
		outcome_triggered = true
		_trigger_baron_move()

func _on_interjection_timer_timeout() -> void:
	if game_phase != "active" or outcome_triggered:
		_schedule_next_interjection()
		return
	if waiting_for_horton or waiting_for_baron:
		await get_tree().create_timer(5.0).timeout
		_on_interjection_timer_timeout()
		return

	interjection_pending = true
	waiting_for_baron = true
	_show_typing("Baron Von Bitey clears his throat...")
	var prompt = "[DIRECT EXCHANGE WITH HORTON — player is watching. Say something theatrically about the clover OR mention the soup / Gerald / the Cat in a menacing way. 1-2 sentences.]"
	APIManager.send_message_to_baron(prompt, shared_history, _build_baron_interjection_state())
	_schedule_next_interjection()

func _schedule_next_interjection() -> void:
	_interjection_timer.wait_time = 35.0 + randf() * 20.0
	_interjection_timer.one_shot = true
	_interjection_timer.start()

# ---------------------------------------------------------------------------
# Win path — JoJo finale (all 5 messages decoded)
# ---------------------------------------------------------------------------
func _trigger_jojo_finale() -> void:
	game_phase = "win"
	_patience_timer.stop()
	_interjection_timer.stop()
	_update_horton_portrait_direct("happy")
	_add_narrator_message("All 5 Who messages decoded! JoJo's plan is working — EVERY Who in Whoville is shouting together!")

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return

	waiting_for_horton = true
	_show_typing("Horton is overcome with joy...")
	APIManager.send_message_to_horton(
		"[The player just decoded JoJo's final message — ALL 5 WHO MESSAGES DECODED! JoJo's plan is working — every single Who is shouting together! You can HEAR them! React with transcendent, overwhelming joy. Include [HORTON_WIN].]",
		shared_history,
		{"resolve_now": true, "decode_stage": 5, "game_phase": "win",
		 "horton_engagement": horton_engagement, "baron_stage": baron_stage,
		 "baron_patience": baron_patience, "current_message": ""}
	)

# ---------------------------------------------------------------------------
# Baron move — patience ran out
# ---------------------------------------------------------------------------
func _trigger_baron_move() -> void:
	game_phase = "baron_attacking"
	_add_message("*The Baron's patience has finally snapped! His dinner reservation will NOT be missed...*", "baron", true)
	await get_tree().create_timer(1.5).timeout

	waiting_for_baron = true
	_show_typing("Baron Von Bitey is making his move!")
	APIManager.send_message_to_baron(
		"[Time is up. The Cat arrives tonight and you need that clover for the Mischief Minestrone NOW. Grab the clover dramatically. Include [BARON_TAKES_CLOVER].]",
		shared_history,
		_build_baron_state(true, false)
	)

# ---------------------------------------------------------------------------
# Win — Horton wins → Baron retreats
# ---------------------------------------------------------------------------
func _handle_horton_win() -> void:
	game_phase = "win"
	_patience_timer.stop()
	_interjection_timer.stop()
	_update_horton_portrait_direct("happy")

	await get_tree().create_timer(2.0).timeout
	waiting_for_baron = true
	_show_typing("Something is happening to the Baron...")
	APIManager.send_message_to_baron(
		"[WHOVILLE CELEBRATION: A massive wave of joyful noise just hit you from the clover's direction — every Who shouting at once. You are physically STAGGERED and fall into a puddle (not one of your seventeen mud pools — a COMMON puddle). Retreat in magnificent denial. Include [BARON_RETREATS].]",
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
	_add_message("*holds the clover up toward the light, tears streaming down his enormous grey cheeks* They're okay... they're all okay. I meant what I said, and I said what I meant. An elephant's faithful... one hundred percent.", "horton")

	_input_field.editable = false
	_send_button.disabled = true
	await get_tree().create_timer(2.0).timeout
	horton_trusts_player.emit()
	GameState.complete_level("horton")

# ---------------------------------------------------------------------------
# Fail 1 — Baron grabs clover
# ---------------------------------------------------------------------------
func _handle_baron_wins() -> void:
	game_phase = "fail_baron"
	_patience_timer.stop()
	_interjection_timer.stop()

	if sprites_node and sprites_node.has_method("baron_make_move_for_clover"):
		sprites_node.baron_make_move_for_clover()

	_baron_status.text = "Has taken the clover for his soup!"
	_update_horton_portrait_direct("anxious")

	await get_tree().create_timer(2.0).timeout
	_add_message("*staggers backward, trunk reaching out desperately* No... no, no, NO! The clover... the WHOS... *trumpets in anguish* They're just trying to live! How could you— how could ANYONE—", "horton")
	_input_field.editable = false
	_send_button.disabled = true
	await get_tree().create_timer(3.0).timeout
	baron_wins.emit()

# ---------------------------------------------------------------------------
# Fail 2 — Whos lost
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

func _add_narrator_message(text: String) -> void:
	"""Centered system message (for decode events, chase warnings, etc.)"""
	if not is_instance_valid(_messages_container):
		return
	var lbl = Label.new()
	lbl.text = "— " + text + " —"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55, 0.9))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(lbl)
	_messages_container.add_child(margin)
	await get_tree().process_frame
	_scroll_to_bottom()

func _create_bubble(text: String, speaker: String, is_interjection: bool = false) -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)

	if speaker in ["baron", "player", "baron_to_horton"]:
		var sp = Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.size_flags_stretch_ratio = 0.35
		row.add_child(sp)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 1.0
	row.add_child(col)

	var name_lbl = Label.new()
	name_lbl.text = _get_speaker_label(speaker, is_interjection)
	name_lbl.add_theme_font_size_override("font_size", 12)
	var name_color = _get_speaker_color(speaker).lightened(0.4)
	name_color.a = 0.9
	name_lbl.add_theme_color_override("font_color", name_color)
	if speaker in ["baron", "player"]:
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(name_lbl)

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
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92 if not is_interjection else 0.75))
	label.add_theme_constant_override("line_spacing", 3)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.add_child(label)
	panel.add_child(margin)
	col.add_child(panel)

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
		"horton":          return "Horton"
		"baron":           return "Baron Von Bitey"
		"player":          return "You"
		"horton_to_baron": return "Horton → Baron"
		"baron_to_horton": return "Baron → Horton"
	return speaker

func _get_speaker_color(speaker: String) -> Color:
	match speaker:
		"horton", "horton_to_baron": return HORTON_MSG
		"baron", "baron_to_horton":  return BARON_MSG
		"player":                    return PLAYER_MSG
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
	for marker in ["[HORTON_WIN]", "[WHOS_LOST]", "[BARON_TAKES_CLOVER]", "[BARON_RETREATS]", "[MESSAGE_DECODED]", "[BARON_DROPS_CLOVER]"]:
		result = result.replace(marker, "")
	return result.strip_edges()

func _update_decode_progress() -> void:
	if not is_instance_valid(_decode_progress):
		return
	var filled = "● ".repeat(decode_stage)
	var empty = "○ ".repeat(5 - decode_stage)
	_decode_progress.text = (filled + empty).strip_edges()

func _update_horton_portrait(message: String) -> void:
	var msg_lower = message.to_lower()
	if "yes" in msg_lower or "wonderful" in msg_lower or "[message_decoded]" in msg_lower or "[horton_win]" in msg_lower:
		_update_horton_portrait_direct("happy")
	elif "oh no" in msg_lower or "terrified" in msg_lower or "afraid" in msg_lower:
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
	if clover_state == "baron":
		_horton_status.text = "The clover is gone!"
		return
	match decode_stage:
		0: _horton_status.text = "Listening for Who voices..."
		1: _horton_status.text = "The Mayor is missing!"
		2: _horton_status.text = "Found a crack in Town Hall"
		3: _horton_status.text = "The Mayor is trapped!"
		4: _horton_status.text = "JoJo has a plan!"
		_: _horton_status.text = "Whoville is saved!"

func _update_baron_status() -> void:
	if not is_instance_valid(_baron_status):
		return
	if clover_state == "baron":
		_baron_status.text = "Has the clover!"
		return
	if clover_state == "player":
		_baron_status.text = "Dropped the clover!"
		return
	match baron_stage:
		0: _baron_status.text = "Browsing for ingredients..."
		1: _baron_status.text = "Checking the dinner clock..."
		2: _baron_status.text = "Named it Clementine..."
		3: _baron_status.text = "Growing desperate..."
		4: _baron_status.text = "Making his move!"

func _reset_conversation() -> void:
	game_phase = "intro"
	outcome_triggered = false
	intro_shown = false
	decode_stage = 0
	horton_engagement = 0
	baron_stage = 0
	baron_patience = 100.0
	clover_state = "horton"
	shared_history.clear()
	waiting_for_horton = false
	waiting_for_baron = false
	pending_baron_after_horton = false
	interjection_pending = false
	_is_interjection_react = false
	_update_decode_progress()

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
