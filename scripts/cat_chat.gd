extends Control

## Cat in the Hat Chat UI — Dual Path System
## PATH A (baron_has_clover=false): 7-beat deal negotiation, deal_progress 0→3
##   WIN: deal_progress >= 3 → cat_adventure_begins
## PATH B (baron_has_clover=true): Cat ate Baron's soup — dual meter race
##   cat_awakeness 0-100 (player pushes this up) vs baron_persuasion 0-100 (auto-ticks up)
##   WIN: cat_awakeness >= 75 → Cat wakes, tears up job application → cat_adventure_begins
##   LOSE: baron_persuasion >= 100 → Cat signs, hat goes gray → cat_bored_out


# speech to text
@onready var speech_to_text: Node = $SpeechToText
@onready var text_to_speech: Node = $TextToSpeech

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------
signal cat_adventure_begins   # WIN  — Cat recruits player / rejects Baron's job application
signal cat_bored_out          # FAIL — all lose states collapse to this; cat_level handles UX

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------
const CAT_BG     := Color(0.45, 0.06, 0.06, 1.0)
const CAT_MSG    := Color(0.60, 0.10, 0.10, 1.0)
const BARON_MSG  := Color(0.30, 0.08, 0.48, 1.0)
const PLAYER_MSG := Color(0.22, 0.38, 0.60, 1.0)
const PANEL_W    := 900.0
const PANEL_H    := 600.0

# ---------------------------------------------------------------------------
# Beat names (indices 0–6)  — Path A narrative arc
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
# Deal / wakeup stage labels
# ---------------------------------------------------------------------------
const DEAL_STAGES   := ["Skeptical", "Intrigued", "Convinced", "Deal Closed!"]
const WAKEUP_STAGES  := ["...agreeable. Too agreeable.", "Flickering...", "Waking up...", "FULLY AWAKE!"]
const BARON_STAGES   := ["Pitching...", "Cat is nodding...", "Pen in hand...", "DEAL SIGNED"]

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
var _progress_label: Label
var _baron_label: Label
var _beat_label: Label

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------
var is_open: bool = false
var outcome_triggered: bool = false
var intro_shown: bool = false
var conversation_history: Array = []
var waiting_for_cat: bool = false

# Path routing
var is_baron_path: bool = false

# Path A — deal negotiation
var deal_progress: int = 0             # 0→3 (Skeptical→Intrigued→Convinced→Deal Closed)
var narrative_beat: int = 0            # 0–6

# Path B — wakeup mechanic
var cat_wakeup_stage: int = 0          # 0→3 (soup-compliant → fully awake)
var baron_speak_counter: int = 0       # how many Cat turns have elapsed in Path B
var baron_persuasion: int = 0          # 0–100: auto-ticks up; wins at 100
var baron_persuasion_stage: int = 0    # 0–3: lose-arc stage for narration
var last_player_message: String = ""

# Shared tracking
var player_turn_count: int = 0
var consecutive_boring: int = 0
var times_player_bored_you: int = 0
var chaos_meter: int = 0
var happiness: int = 50

# Cross-level state (from GameState)
var player_has_seed: bool = false

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	print("[CAT_CHAT] Initializing...")
	_build_ui()
	if APIManager:
		APIManager.cat_message_received.connect(_on_cat_response)
		APIManager.cat_message_failed.connect(_on_cat_failed)
		APIManager.baron_message_received.connect(_on_baron_response)
		APIManager.baron_message_failed.connect(_on_baron_failed)
	GameState.font_size_changed.connect(_on_font_size_changed)
	GameState.scene_switch.connect(_on_scene_switch)
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

	# Progress meter column (right side of header)
	var meters_col = VBoxContainer.new()
	meters_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meters_col.add_theme_constant_override("separation", 4)
	header_hbox.add_child(meters_col)

	_progress_label = Label.new()
	_progress_label.text = "◆ Skeptical → ○ Intrigued → ○ Convinced → ○ Deal"
	_progress_label.add_theme_font_size_override("font_size", 12)
	_progress_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meters_col.add_child(_progress_label)

	_baron_label = Label.new()
	_baron_label.text = ""
	_baron_label.add_theme_font_size_override("font_size", 11)
	_baron_label.add_theme_color_override("font_color", Color(0.8, 0.45, 1.0, 1.0))
	_baron_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_baron_label.visible = false
	meters_col.add_child(_baron_label)

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
	_typing_indicator.add_theme_font_size_override("font_size", GameState.font_size - 3)
	_typing_indicator.add_theme_color_override("font_color", Color(0.9, 0.9, 0.3, 1.0))
	_typing_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_show_typing_indicator("*hat tilts thoughtfully...*")
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

	# speech to text
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
	# make music quieter
	GameState.toggle_background_volume_dim(true)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	await tween.finished

	is_open = true
	GameState.disable_movement()
	is_baron_path = GameState.baron_has_clover
	player_has_seed = GameState.player_has_seed
	_input_field.grab_focus()

	if not intro_shown:
		intro_shown = true
		_show_typing_indicator("*hat tilts thoughtfully...*")
		_update_meters()

		if is_baron_path:
			# PATH B: Baron arrived first, Cat ate the soup, is compliant
			_add_narrator_message("The Cat in the Hat answers the door — but something is wrong. He's very... polite.")
			_request_cat_response("[INTRO] PATH B: You are in your soup-compliant state — calm, agreeable, unnervingly pleasant. The player has just arrived. The Baron is already inside, pitching his Grand Monotony project. Greet the player with excessive politeness. Mention that you're considering the Baron's business proposal. Something feels off about you.")
		else:
			# PATH A: Player arrived before Baron
			_add_narrator_message("The Cat in the Hat appears — hat first, naturally.")
			_request_cat_response("[INTRO] PATH A: The player has arrived at your house. You were expecting Baron Von Bitey for your regular Catastrophic Cookoff — but this is NOT the Baron. Greet them with theatrical suspicion and maximum flair. You are yourself: chaotic, mercurial, bored of ordinary visitors.")

func _toggle_voice() -> void:
	if speech_to_text.is_recording:
		GameState.toggle_stt(false)
		_mic_button.text = "🎙"
		_mic_button.remove_theme_color_override("font_color")
		speech_to_text.stop_recording()
	else:
		GameState.toggle_stt(true)
		_mic_button.text = "⏹"
		_mic_button.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
		speech_to_text.start_recording()

func _enable_stt() -> void:
	_mic_button.disabled = false

func _disable_stt() -> void:
	_mic_button.disabled = true

func _on_text_received(text: String) -> void:
	if _input_field.text != "":
		_input_field.text += " "
	_input_field.text += text

func close_chat() -> void:
	if not is_open:
		return
	if speech_to_text.is_recording:
		_toggle_voice()
	text_to_speech.stop_voice()
	is_open = false

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_property(self, "scale", Vector2(0.92, 0.92), 0.2)
	await tween.finished

	visible = false
	GameState.enable_movement()

	# make music louder
	GameState.toggle_background_volume_dim(false)

# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------
func _on_input_submitted(_text: String) -> void:
	_send_player_message()

func _send_player_message() -> void:
	var text = _input_field.text.strip_edges()
	if text.is_empty() or waiting_for_cat or outcome_triggered:
		return

	# ---- Skip codes ----
	var lower = text.to_lower()
	if lower == "one fish two fish":
		_input_field.text = ""
		if not outcome_triggered:
			outcome_triggered = true
			_lock_input()
			_add_narrator_message("(Skip code accepted — Cat wins! Adventure begins!)")
			await get_tree().create_timer(1.0).timeout
			cat_adventure_begins.emit()
		return
	if lower == "i do not like them sam i am":
		_input_field.text = ""
		if not outcome_triggered:
			outcome_triggered = true
			_lock_input()
			_add_narrator_message("(Skip code accepted — Cat loses! Boring ending...)")
			await get_tree().create_timer(1.0).timeout
			cat_bored_out.emit()
		return

	_input_field.text = ""
	player_turn_count += 1
	last_player_message = text
	_add_message(text, "You", PLAYER_MSG)
	conversation_history.append({"label": "Player", "text": text})
	_request_cat_response(text)

# ---------------------------------------------------------------------------
# Cat API request
# ---------------------------------------------------------------------------
func _request_cat_response(user_message: String) -> void:
	waiting_for_cat = true
	_input_field.editable = false
	_send_button.disabled = true
	_show_typing_indicator("*hat tilts thoughtfully...*")

	var game_state = {
		"happiness":           happiness,
		"chaos":               chaos_meter,
		"narrative_beat":      narrative_beat,
		"deal_progress":       deal_progress,
		"cat_wakeup_stage":    cat_wakeup_stage,
		"player_turn_count":   player_turn_count,
		"player_has_seed":     player_has_seed,
		"baron_has_clover":    is_baron_path,
		"baron_arriving_soon": false,
		"baron_persuasion":    baron_persuasion,
		"times_player_bored_you": times_player_bored_you
	}
	APIManager.send_message_to_cat(user_message, conversation_history, game_state)

# ---------------------------------------------------------------------------
# Baron API request (Path B only)
# ---------------------------------------------------------------------------
func _request_baron_pitch() -> void:
	var state = {
		"at_cat_house":     true,
		"cat_wakeup_stage": cat_wakeup_stage,
		"player_turn_count": player_turn_count
	}
	# Pass last player message as context so Baron can react to it
	var context = "[AT_CAT_HOUSE] The player just said: \"%s\". Respond as Baron Von Bitey — you are pitching your Grand Monotony plan to the Cat. React to what the player said if relevant." % last_player_message
	APIManager.send_message_to_baron(context, conversation_history, state)

# ---------------------------------------------------------------------------
# Cat response handler
# ---------------------------------------------------------------------------
func _on_cat_response(raw: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	if not GameState.tts_on:
		_hide_typing_indicator()

	# Parse JSON
	var clean_raw = _strip_json_markdown(raw)
	var json = JSON.new()
	var err = json.parse(clean_raw)

	var dialogue: String
	var happiness_delta: int = 0
	var chaos_delta: int = 0
	var next_beat: int = narrative_beat
	var new_deal_progress: int = deal_progress
	var new_wakeup: int = cat_wakeup_stage
	var flags: Dictionary = {}

	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		dialogue = data.get("dialogue", raw)
		happiness_delta = int(data.get("happiness_delta", 0))
		chaos_delta = int(data.get("chaos_delta", 0))
		next_beat = int(data.get("next_beat", narrative_beat))
		new_deal_progress = int(data.get("deal_progress", deal_progress))
		new_wakeup = int(data.get("cat_waking", cat_wakeup_stage))
		flags = data.get("flags", {})
	else:
		dialogue = raw
		if "[CAT_ADVENTURE_BEGINS]" in raw or "[CHEST_UNLOCKED]" in raw:
			dialogue = raw.replace("[CAT_ADVENTURE_BEGINS]", "").replace("[CHEST_UNLOCKED]", "").strip_edges()
			flags["chest_unlocked"] = true
		happiness_delta = 5

	_add_message(dialogue, "Cat", CAT_MSG)
	conversation_history.append({"label": "Cat", "text": dialogue})

	# Apply meter deltas
	happiness = clamp(happiness + happiness_delta, 0, 100)
	chaos_meter += chaos_delta

	# Advance narrative beat (Path A — only forward)
	if next_beat > narrative_beat and next_beat < BEAT_NAMES.size():
		narrative_beat = next_beat

	# Deal progress never goes backward (Path A)
	deal_progress = max(deal_progress, new_deal_progress)

	# Wakeup stage never goes backward (Path B)
	cat_wakeup_stage = max(cat_wakeup_stage, new_wakeup)

	# Track boring streaks
	if happiness_delta < 0 and chaos_delta <= 0:
		consecutive_boring += 1
		times_player_bored_you = consecutive_boring
		# In Path B a boring turn lets the Baron's pitch sink in deeper
		if is_baron_path:
			_advance_baron_persuasion(5)
	else:
		consecutive_boring = 0

	_update_meters()

	# Re-enable input
	_input_field.editable = true
	_send_button.disabled = false

	if outcome_triggered:
		return

	# ----------------------------------------------------------------
	# WIN — Path A: deal closed
	# ----------------------------------------------------------------
	if not is_baron_path:
		if flags.get("chest_unlocked", false) or flags.get("deal_closed", false) or deal_progress >= 3:
			outcome_triggered = true
			_lock_input()
			_add_narrator_message("The Cat has struck a deal! The Chest opens — forest, clover, seed, chaos. Everything connects.")
			await get_tree().create_timer(2.5).timeout
			cat_adventure_begins.emit()
			return

	# ----------------------------------------------------------------
	# WIN — Path B: Cat fully awake, rejects Baron
	# ----------------------------------------------------------------
	if is_baron_path:
		if flags.get("cat_fully_awake", false) or flags.get("baron_rejected", false) or cat_wakeup_stage >= 3:
			outcome_triggered = true
			_lock_input()
			_add_narrator_message("Something shifts in the Cat's eyes. The hat tilts. The real Cat is back.")
			await get_tree().create_timer(2.0).timeout
			_add_narrator_message("He turns to the Baron. 'The job application,' he says, 'is rejected.'")
			await get_tree().create_timer(2.5).timeout
			cat_adventure_begins.emit()
			return

	# ----------------------------------------------------------------
	# LOSE: too boring (Path A only — Path B loss is baron_persuasion)
	# ----------------------------------------------------------------
	if not is_baron_path and (flags.get("bored_out", false) or consecutive_boring >= 5):
		outcome_triggered = true
		_lock_input()
		await get_tree().create_timer(2.0).timeout
		cat_bored_out.emit()
		return

	# ----------------------------------------------------------------
	# LOSE — Path B only: Baron signs the deal (LLM shortcut flag)
	# Treating this as a big persuasion spike — let _advance_baron_persuasion handle narration
	# ----------------------------------------------------------------
	if is_baron_path and flags.get("baron_signed_deal", false):
		_advance_baron_persuasion(100)   # instant max
		return

	# ----------------------------------------------------------------
	# Path B: Baron weighs in after every 2 Cat turns (every turn when waking up)
	# ----------------------------------------------------------------
	if is_baron_path and not waiting_for_cat:
		baron_speak_counter += 1
		var threshold = 1 if cat_wakeup_stage >= 2 else 2
		if baron_speak_counter >= threshold:
			baron_speak_counter = 0
			_request_baron_pitch()

func _on_cat_failed(error: String) -> void:
	waiting_for_cat = false
	_input_field.editable = true
	_send_button.disabled = false
	_hide_typing_indicator()
	print("[CAT_CHAT] API error: ", error)
	if "429" in error:
		_add_narrator_message("(The Cat is pacing and mumbling to himself. Give him a moment, then try again.)")
	else:
		_add_narrator_message("(The Cat appears momentarily distracted by something off-screen. Try again!)")

# ---------------------------------------------------------------------------
# Baron response handler (Path B)
# ---------------------------------------------------------------------------
func _on_baron_response(raw: String) -> void:
	if not is_baron_path or outcome_triggered:
		return

	var clean_raw = _strip_json_markdown(raw)
	var json = JSON.new()
	var err = json.parse(clean_raw)

	var dialogue: String
	if err == OK and json.data is Dictionary:
		var data: Dictionary = json.data
		dialogue = data.get("dialogue", raw)
		# Strip any Horton-specific markers that might bleed through
		dialogue = dialogue.replace("[MESSAGE_DECODED]", "").replace("[BARON_DROPS_CLOVER]", "").strip_edges()
	else:
		dialogue = raw

	if not dialogue.is_empty():
		_add_message(dialogue, "Baron Von Bitey", BARON_MSG)
		conversation_history.append({"label": "Baron", "text": dialogue})
		await get_tree().process_frame
		_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
		# Every time Baron gets an unchallenged pitch in, his persuasion ticks up
		_advance_baron_persuasion(12)

func _on_baron_failed(_error: String) -> void:
	# Baron silence is fine — just skip his turn
	pass

# ---------------------------------------------------------------------------
# UI helpers
# ---------------------------------------------------------------------------
func _lock_input() -> void:
	_input_field.editable = false
	_send_button.disabled = true

func _add_message(text: String, sender: String, bg_color: Color) -> void:
	# if not player, load the voice
	if GameState.tts_on and sender != "You":
		_disable_stt()
		text_to_speech.load_voice('cat', text)
		_show_typing_indicator("*hat tilts thoughtfully...*")
		await text_to_speech.voice_loaded
		_hide_typing_indicator()

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
	sender_label.add_theme_font_size_override("font_size", GameState.font_size - 4)
	sender_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.65))
	if sender == "You":
		sender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(sender_label)

	var msg_label = Label.new()
	msg_label.text = text
	msg_label.add_theme_font_size_override("font_size", GameState.font_size)
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
	lbl.add_theme_font_size_override("font_size", GameState.font_size - 2)
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

# ---------------------------------------------------------------------------
# Baron persuasion meter (Path B only)
# ---------------------------------------------------------------------------
func _advance_baron_persuasion(amount: int) -> void:
	if not is_baron_path or outcome_triggered:
		return

	baron_persuasion = min(baron_persuasion + amount, 100)
	_update_meters()

	# Stage thresholds: 0→1 at 25, 1→2 at 60, 2→3 at 100
	var new_stage: int
	if baron_persuasion >= 100:
		new_stage = 3
	elif baron_persuasion >= 60:
		new_stage = 2
	elif baron_persuasion >= 25:
		new_stage = 1
	else:
		new_stage = 0

	if new_stage > baron_persuasion_stage:
		baron_persuasion_stage = new_stage
		match baron_persuasion_stage:
			1:
				_add_narrator_message("The Cat begins finishing the Baron's sentences — but in the Baron's voice, not his own.")
			2:
				_add_narrator_message("The Baron slides the job application across the table. The Cat picks up the pen.")
			3:
				# Loss — Cat signs
				if not outcome_triggered:
					outcome_triggered = true
					_lock_input()
					_add_narrator_message("The Cat signs. The hat droops. The stripes go gray.")
					await get_tree().create_timer(1.0).timeout
					_add_narrator_message("\"And that was the day chaos got a corporate sponsor.\"")
					await get_tree().create_timer(2.5).timeout
					cat_bored_out.emit()

func _update_meters() -> void:
	if is_baron_path:
		# PATH B — show Cat wakeup stage
		var stage_idx = clamp(cat_wakeup_stage, 0, WAKEUP_STAGES.size() - 1)
		_progress_label.text = "Cat: %s" % WAKEUP_STAGES[stage_idx]
		match cat_wakeup_stage:
			0:
				_progress_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			1:
				_progress_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
			2:
				_progress_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.1, 1.0))
			3:
				_progress_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))

		# Baron persuasion bar — ▓ filled, ░ empty
		var filled := int(baron_persuasion / 10)
		var bar := "▓".repeat(filled) + "░".repeat(10 - filled)
		var b_stage_idx = clamp(baron_persuasion_stage, 0, BARON_STAGES.size() - 1)
		_baron_label.text = "Baron: %s  %d%%  %s" % [bar, baron_persuasion, BARON_STAGES[b_stage_idx]]
		_baron_label.visible = true
		match baron_persuasion_stage:
			0:
				_baron_label.add_theme_color_override("font_color", Color(0.7, 0.5, 0.9, 1.0))
			1:
				_baron_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.2, 1.0))
			2:
				_baron_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
			3:
				_baron_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))

		# Status line
		match cat_wakeup_stage:
			0:
				_cat_status.text = "Suspiciously pleasant..."
				_cat_status.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
			1:
				_cat_status.text = "Something stirs..."
				_cat_status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
			2:
				_cat_status.text = "The hat is tilting!"
				_cat_status.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1, 1.0))
			3:
				_cat_status.text = "HE'S BACK!"
				_cat_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))

		# Beat label repurposed for wakeup hint
		_beat_label.text = "Baron is pitching inside — wake the Cat up!"
		_beat_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 0.85))

	else:
		# PATH A — show deal progress bar
		var stages = ["◆ Skeptical", "○ Intrigued", "○ Convinced", "○ Deal"]
		for i in range(min(deal_progress + 1, stages.size())):
			stages[i] = stages[i].replace("○", "◆")
		_progress_label.text = " → ".join(stages)
		match deal_progress:
			0:
				_progress_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4, 1.0))
			1:
				_progress_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
			2:
				_progress_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 1.0))
			3:
				_progress_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3, 1.0))

		# Status line
		if deal_progress >= 2:
			_cat_status.text = "Make the argument that matters."
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
		else:
			_cat_status.text = "CHAOTICALLY DELIGHTED"
			_cat_status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))

		# Beat label
		var beat_idx = clamp(narrative_beat, 0, BEAT_NAMES.size() - 1)
		_beat_label.text = "Beat %d/6 — %s" % [narrative_beat, BEAT_NAMES[beat_idx]]
		if narrative_beat >= 5:
			_beat_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5, 0.9))
		else:
			_beat_label.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0, 0.85))

func _show_typing_indicator(msg: String) -> void:
	"""Show typing indicator."""
	_typing_indicator.visible = true
	_typing_indicator.text = msg
	
	# Animate typing dots
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(_typing_indicator, "modulate:a", 0.5, 0.5)
	tween.tween_property(_typing_indicator, "modulate:a", 1.0, 0.5)

func _hide_typing_indicator() -> void:
	"""Hide typing indicator."""
	var tween = create_tween()
	tween.tween_property(_typing_indicator, "modulate:a", 0.0, 0.2)
	await tween.finished
	_typing_indicator.visible = false
	_typing_indicator.modulate.a = 1.0

func _strip_json_markdown(text: String) -> String:
	var s = text.strip_edges()
	if s.begins_with("```"):
		s = s.trim_prefix("```json").trim_prefix("```")
		var end = s.rfind("```")
		if end != -1:
			s = s.substr(0, end)
	return s.strip_edges()

func _on_text_to_speech_voice_loaded() -> void:
	text_to_speech.play_voice()
	await get_tree().create_timer(text_to_speech.audio_length).timeout
	_enable_stt()

func _on_font_size_changed(font_size: int) -> void:
	"""Update font size on all existing message bubbles."""
	if not _messages_container:
		return
	for child in _messages_container.get_children():
		# Narrator messages: MarginContainer > Label
		if child is MarginContainer:
			var lbl = child.get_child(0)
			if lbl is Label:
				lbl.add_theme_font_size_override("font_size", font_size)
		# Chat bubbles: PanelContainer > VBoxContainer > [sender Label, message Label]
		elif child is PanelContainer:
			var vbox = child.get_child(0)
			if vbox is VBoxContainer:
				for i in vbox.get_child_count():
					var lbl = vbox.get_child(i)
					if lbl is Label:
						# Keep sender label smaller (relative to base size)
						var adjusted = font_size - 4 if i == 0 else font_size
						lbl.add_theme_font_size_override("font_size", adjusted)
	_typing_indicator.add_theme_font_size_override("font_size", GameState.font_size - 3)

func _exit_tree() -> void:
	text_to_speech.stop_voice()

func _on_scene_switch():
	text_to_speech.stop_voice()
