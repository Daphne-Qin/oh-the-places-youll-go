extends Control

## Cat in the Hat Chat UI — 7-Beat Narrative System
## WIN:  consecutive_happy_turns >= 3 AND narrative_beat >= 5 → cat_adventure_begins
## FAIL: (1) boring/overflow, (2) baron arrives first, (3) seed cooked, (4) baron_arrived

# speech to text
@onready var speech_to_text: Node = $SpeechToText

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal cat_adventure_begins   # WIN  — Cat recruits player for the adventure
signal cat_bored_out          # FAIL — all lose states collapse to this; cat_level handles UX

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------
const CAT_BG     := Color(0.45, 0.06, 0.06, 1.0)
const CAT_MSG    := Color(0.60, 0.10, 0.10, 1.0)
const PLAYER_MSG := Color(0.22, 0.38, 0.60, 1.0)
const PANEL_W    := 900.0
const PANEL_H    := 600.0

# ---------------------------------------------------------------------------
# Beat names (indices 0–6)
# ---------------------------------------------------------------------------
const BEAT_NAMES := [
	"An unexpected guest...",
	"What did you bring?",
	"Who are the Whos?",
	"Forest connected.",
	"The Chest...",
	"The chaos argument",
	"The moment of truth"
]

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
var _mic_button: Button
var _cat_status: Label
var _happiness_label: Label
var _chaos_label: Label
var _beat_label: Label

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var is_open: bool = false
var outcome_triggered: bool = false
var intro_shown: bool = false
var conversation_history: Array = []
var waiting_for_cat: bool = false

# Narrative progress
var narrative_beat: int = 0                # 0–6 (story beat index)
var consecutive_happy_turns: int = 0       # turns with happiness_delta > 0 after beat 5
var player_turn_count: int = 0             # total player messages sent

# Cross-level state (from GameState)
var baron_has_clover: bool = false

# Chaos / happiness meters
var happiness: int = 50         # 0–100
var chaos_meter: int = 0        # can go negative
var times_player_bored_you: int = 0
var consecutive_boring: int = 0

# Item flags
var player_has_clover: bool = false
var player_has_seed: bool = false

# Lose-state trackers
var seed_cooking_temptation: int = 0      # increments when Cat considers cooking the seed

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
# _build_ui
# ---------------------------------------------------------------------------
func _build_ui() -> void:
	_background_overlay = ColorRect.new()
	_background_overlay.color = Color(0, 0, 0, 0.55)
	_background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_background_overlay)

	_chat_panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.04, 0.04, 0.97)
	panel_style.border_color = Color(0.75, 0.10, 0.10, 1.0)
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

	var root_vbox = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 0)
	_chat_panel.add_child(root_vbox)

	# ---- Header ----
	var header = PanelContainer.new()
	var header_style = StyleBoxFlat.new()
	header_style.bg_color = CAT_BG
	header_style.corner_radius_top_left  = 13
	header_style.corner_radius_top_right = 13
	header.add_theme_stylebox_override("panel", header_style)
	header.custom_minimum_size = Vector2(0, 90)
	root_vbox.add_child(header)

	var hm = MarginContainer.new()
	hm.add_theme_constant_override("margin_left", 14)
	hm.add_theme_constant_override("margin_right", 14)
	hm.add_theme_constant_override("margin_top", 8)
	hm.add_theme_constant_override("margin_bottom", 8)
	header.add_child(hm)

	var header_hbox = HBoxContainer.new()
	header_hbox.add_theme_constant_override("separation", 12)
	hm.add_child(header_hbox)

	# Title + status + beat
	var title_col = VBoxContainer.new()
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_hbox.add_child(title_col)

	var title_label = Label.new()
	title_label.text = "The Cat in the Hat"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_col.add_child(title_label)

	_cat_status = Label.new()
	_cat_status.text = "Sizing you up..."
	_cat_status.add_theme_font_size_override("font_size", 13)
	_cat_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75, 1.0))
	title_col.add_child(_cat_status)

	_beat_label = Label.new()
	_beat_label.text = BEAT_NAMES[0]
	_beat_label.add_theme_font_size_override("font_size", 11)
	_beat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0, 0.85))
	title_col.add_child(_beat_label)

	# Meters (happiness + chaos)
	var meters_col = VBoxContainer.new()
	meters_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meters_col.add_theme_constant_override("separation", 4)
	header_hbox.add_child(meters_col)

	_happiness_label = Label.new()
	_happiness_label.text = "♥ Happiness: 50"
	_happiness_label.add_theme_font_size_override("font_size", 13)
	_happiness_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6, 1.0))
	_happiness_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meters_col.add_child(_happiness_label)

	_chaos_label = Label.new()
	_chaos_label.text = "⚡ Chaos: 0"
	_chaos_label.add_theme_font_size_override("font_size", 13)
	_chaos_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1.0))
	_chaos_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meters_col.add_child(_chaos_label)

	var close_btn = Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_btn.pressed.connect(close_chat)
	header_hbox.add_child(close_btn)

	# ---- Scroll area ----
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_scroll_container)

	_messages_container = VBoxContainer.new()
	_messages_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_typing_indicator.text = "*hat tilts thoughtfully*"
	_typing_indicator.add_theme_font_size_override("font_size", 13)
	_typing_indicator.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1.0))
	_typing_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_typing_indicator.visible = false
	_typing_indicator.custom_minimum_size = Vector2(0, 22)
	root_vbox.add_child(_typing_indicator)

	# ---- Input row ----
	var input_sep = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.55, 0.10, 0.10, 0.5)
	input_sep.add_theme_stylebox_override("separator", sep_style)
	root_vbox.add_child(input_sep)

	var input_margin = MarginContainer.new()
	input_margin.add_theme_constant_override("margin_left", 10)
	input_margin.add_theme_constant_override("margin_right", 10)
	input_margin.add_theme_constant_override("margin_top", 6)
	input_margin.add_theme_constant_override("margin_bottom", 8)
	root_vbox.add_child(input_margin)

	var input_row = HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 8)
	input_row.custom_minimum_size = Vector2(0, 44)
	input_margin.add_child(input_row)

	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Say something to the Cat..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 16)
	_input_field.text_submitted.connect(_on_input_submitted)
	input_row.add_child(_input_field)

	_send_button = Button.new()
	_send_button.text = "Send ▶"
	_send_button.custom_minimum_size = Vector2(80, 0)
	_send_button.add_theme_font_size_override("font_size", 15)
	_send_button.pressed.connect(_send_player_message)
	input_row.add_child(_send_button)

	# speech to text stuff
	speech_to_text.received.connect(_on_text_received)
	_mic_button = Button.new()
	_mic_button.text = "🎙"
	_mic_button.custom_minimum_size = Vector2(44, 0)
	_mic_button.add_theme_font_size_override("font_size", 18)
	_mic_button.tooltip_text = "Voice Input"
	_mic_button.pressed.connect(_toggle_voice)
	_send_button.get_parent().add_child(_mic_button)

# ---------------------------------------------------------------------------
# open / close
# ---------------------------------------------------------------------------
func open_chat() -> void:
	show()
	is_open = true
	GameState.disable_movement()
	baron_has_clover = GameState.baron_has_clover
	player_has_seed = GameState.player_has_seed
	_input_field.grab_focus()
	if not intro_shown:
		intro_shown = true
		_add_narrator_message("The Cat in the Hat appears — hat first, naturally.")
		if baron_has_clover:
			_request_cat_response("[INTRO] The player arrives — but not the guest you expected. Also: you just found out someone named Baron Von Bitey is trying to make soup out of a clover that has a tiny civilization on it. Greet the player theatrically but let slip you're already aware of the Baron situation.")
		else:
			_request_cat_response("[INTRO] The player arrives — but not the guest you expected. You were expecting Baron Von Bitey for your regular competitive potluck. This person is NOT the Baron. Greet them with theatrical suspicion and maximum flair.")

func _toggle_voice() -> void:
	if speech_to_text.is_recording:
		_mic_button.text = "🎙"
		_mic_button.remove_theme_color_override("font_color")
		speech_to_text.stop_recording()

	else:
		_mic_button.text = "⏹"
		_mic_button.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		speech_to_text.start_recording()

func _on_text_received(text: String) -> void:
	# add a space if there is already text
	if _input_field.text != "":
		_input_field.text += " "
	# then add on the voice stuff
	_input_field.text += text

func close_chat() -> void:
	if not is_open:
		return
	if speech_to_text.is_recording:
		_toggle_voice()
	is_open = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.2)
	await tween.finished
	visible = false
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
	player_turn_count += 1
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

	var baron_arriving_soon = baron_has_clover and player_turn_count >= 7
	var game_state = {
		"happiness":               happiness,
		"chaos":                   chaos_meter,
		"narrative_beat":          narrative_beat,
		"consecutive_happy_turns": consecutive_happy_turns,
		"player_turn_count":       player_turn_count,
		"player_has_clover":       player_has_clover,
		"player_has_seed":         player_has_seed,
		"baron_has_clover":        baron_has_clover,
		"baron_arriving_soon":     baron_arriving_soon,
		"seed_cooking_temptation": seed_cooking_temptation,
		"times_player_bored_you":  times_player_bored_you
	}
	APIManager.send_message_to_cat(user_message, conversation_history, game_state)

# ---------------------------------------------------------------------------
# Response handler
# ---------------------------------------------------------------------------
func _on_cat_response(raw: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	_typing_indicator.visible = false

	# --- Parse JSON ---
	var clean_raw = _strip_json_markdown(raw)
	var json = JSON.new()
	var err = json.parse(clean_raw)

	var dialogue: String
	var happiness_delta: int = 0
	var chaos_delta: int = 0
	var next_beat: int = narrative_beat
	var seed_temptation_delta: int = 0
	var flags: Dictionary = {}

	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		dialogue = data.get("dialogue", raw)
		happiness_delta = int(data.get("happiness_delta", 0))
		chaos_delta = int(data.get("chaos_delta", 0))
		next_beat = int(data.get("next_beat", narrative_beat))
		seed_temptation_delta = int(data.get("seed_temptation_delta", 0))
		flags = data.get("flags", {})
	else:
		# Fallback: treat raw as plain text
		dialogue = raw
		if "[CAT_ADVENTURE_BEGINS]" in raw:
			dialogue = raw.replace("[CAT_ADVENTURE_BEGINS]", "").strip_edges()
			flags["chest_unlocked"] = true
		happiness_delta = 5

	# Display dialogue
	_add_message(dialogue, "Cat", CAT_MSG)
	conversation_history.append({"label": "Cat", "text": dialogue})

	# Apply deltas
	happiness = clamp(happiness + happiness_delta, 0, 100)
	chaos_meter += chaos_delta
	seed_cooking_temptation = clamp(seed_cooking_temptation + seed_temptation_delta, 0, 5)

	# Advance narrative beat (only forward)
	if next_beat > narrative_beat and next_beat < BEAT_NAMES.size():
		narrative_beat = next_beat

	# Track boring / happy streaks
	if happiness_delta < 0 and chaos_delta <= 0:
		consecutive_boring += 1
		times_player_bored_you = consecutive_boring
		consecutive_happy_turns = 0
	elif happiness_delta > 0:
		consecutive_boring = 0
		times_player_bored_you = 0
		if narrative_beat >= 5:
			consecutive_happy_turns += 1
	else:
		consecutive_boring = 0

	_update_meters()

	if outcome_triggered:
		return

	# ----------------------------------------------------------------
	# LOSE STATE 3: seed cooked (temptation maxed)
	# ----------------------------------------------------------------
	if flags.get("seed_cooked", false) or seed_cooking_temptation >= 4:
		outcome_triggered = true
		_lock_input()
		_add_narrator_message("The Cat pops the Truffula seed into a small copper pot. It smells incredible. This is a disaster.")
		await get_tree().create_timer(2.5).timeout
		cat_bored_out.emit()
		return

	# ----------------------------------------------------------------
	# LOSE STATE 4: Baron arrives with clover before player convinces Cat
	# ----------------------------------------------------------------
	if flags.get("baron_arrived", false) or (baron_has_clover and player_turn_count >= 10):
		outcome_triggered = true
		_lock_input()
		_add_narrator_message("The doorbell rings. It rings with tremendous aristocratic authority. Baron Von Bitey has arrived — with the clover, and a very large soup pot.")
		await get_tree().create_timer(2.5).timeout
		cat_bored_out.emit()
		return

	# ----------------------------------------------------------------
	# LOSE STATE 1: too boring
	# ----------------------------------------------------------------
	if flags.get("bored_out", false) or consecutive_boring >= 5:
		outcome_triggered = true
		_lock_input()
		await get_tree().create_timer(2.5).timeout
		cat_bored_out.emit()
		return

	# ----------------------------------------------------------------
	# WIN: chest unlocked OR maintained happiness for 3 turns after beat 5
	# ----------------------------------------------------------------
	if flags.get("chest_unlocked", false) or flags.get("true_chaos_path", false) \
	   or (consecutive_happy_turns >= 3 and narrative_beat >= 5):
		outcome_triggered = true
		_lock_input()
		_add_narrator_message("The Cat has judged you worthy of the greatest chaos! The adventure begins!")
		await get_tree().create_timer(2.5).timeout
		cat_adventure_begins.emit()
		return

	# Drawing mode easter egg
	if flags.get("drawing_mode", false):
		_add_narrator_message("(The Cat demands a drawing. Use your imagination — describe it in words!)")

func _on_cat_failed(error: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	_typing_indicator.visible = false
	print("[CAT_CHAT] API error: ", error)
	if "429" in error:
		_add_narrator_message("(The Cat is pacing and mumbling to himself. Give him a moment, then try again.)")
	else:
		_add_narrator_message("(The Cat appears momentarily distracted by something off-screen. Try again!)")

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _lock_input() -> void:
	_input_field.editable = false
	_send_button.disabled = true

func _add_message(text: String, sender: String, bg_color: Color) -> void:
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(8)
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var sender_label = Label.new()
	sender_label.text = sender
	sender_label.add_theme_font_size_override("font_size", 11)
	sender_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	if sender == "You":
		sender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(sender_label)

	var msg_label = Label.new()
	msg_label.text = text
	msg_label.add_theme_font_size_override("font_size", 15)
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if sender == "You":
		msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(msg_label)

	_messages_container.add_child(panel)
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)

func _add_narrator_message(text: String) -> void:
	var lbl = Label.new()
	lbl.text = "— " + text + " —"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.90, 0.55, 0.9))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(lbl)
	_messages_container.add_child(margin)
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)

func _update_meters() -> void:
	# Happiness
	_happiness_label.text = "♥ Happiness: %d" % happiness
	if happiness <= 30:
		_happiness_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
	elif happiness >= 80:
		_happiness_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	else:
		_happiness_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6, 1.0))

	# Chaos — grey when negative, green when high
	_chaos_label.text = "⚡ Chaos: %d" % chaos_meter
	if chaos_meter < 0:
		_chaos_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	elif chaos_meter >= 60:
		_chaos_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))
	else:
		_chaos_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1.0))

	# Beat progress
	var beat_idx = clamp(narrative_beat, 0, BEAT_NAMES.size() - 1)
	_beat_label.text = "Beat %d/6 — %s" % [narrative_beat, BEAT_NAMES[beat_idx]]
	if narrative_beat >= 5:
		_beat_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 0.9))
	else:
		_beat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0, 0.85))

	# Win progress indicator (after beat 5)
	if narrative_beat >= 5 and consecutive_happy_turns > 0:
		_cat_status.text = "Keep going! (%d/3)" % consecutive_happy_turns
		_cat_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	elif happiness <= 30:
		_cat_status.text = "Bored. Dangerously."
		_cat_status.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
	elif happiness <= 60:
		_cat_status.text = "Testing you..."
		_cat_status.add_theme_color_override("font_color", Color(1.0, 0.75, 0.75, 1.0))
	elif happiness <= 80:
		_cat_status.text = "Actually entertained!"
		_cat_status.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5, 1.0))
	elif happiness < 100:
		_cat_status.text = "CHAOTICALLY DELIGHTED"
		_cat_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	else:
		_cat_status.text = "OVERFLOW IMMINENT"
		_cat_status.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0, 1.0))

func _strip_json_markdown(text: String) -> String:
	var s = text.strip_edges()
	if s.begins_with("```"):
		s = s.trim_prefix("```json").trim_prefix("```")
		var end = s.rfind("```")
		if end != -1:
			s = s.substr(0, end)
	return s.strip_edges()
