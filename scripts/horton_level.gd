extends Control

## Horton Level Controller
## Manages the three-way interaction: Player ↔ Horton ↔ Baron Von Bitey
## New mechanics: decode messages, Baron chase, clover ownership states

@onready var horton: Area2D = $Node2D/Horton
@onready var player: CharacterBody2D = $Node2D/Player
@onready var baron: Area2D = $Node2D/Baron
@onready var current_music: AudioStreamPlayer = null
@onready var interaction_label = $CanvasLayer/InteractionLabel

# Interaction state
var is_near_horton: bool = false
var is_near_baron: bool = false
var chat_instance: Control = null
var level_select: Control = null
var camera: Camera2D = null

# Clover ownership — "horton" | "baron" | "player"
var clover_state: String = "horton"

# Chase state
var is_chase_active: bool = false
var is_chase_buffer: bool = false
var chase_timer: Timer
var chase_resolve_timer: Timer
var chase_buffer_timer: Timer
const CHASE_BASE_INTERVAL := 28.0
const CHASE_MIN_INTERVAL  := 9.0
const CHASE_RESOLVE_TIME  := 8.0   # seconds player has to reach Horton

# Outcome gating
var outcome_triggered: bool = false

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	GameState.enable_movement()

	# Connect Horton area
	if horton:
		horton.body_entered.connect(_on_horton_area_entered)
		horton.body_exited.connect(_on_horton_area_exited)

	# Connect Baron area for proximity detection
	if baron:
		baron.body_entered.connect(_on_baron_area_entered)
		baron.body_exited.connect(_on_baron_area_exited)

	# Camera limits
	camera = $Node2D/Player/Camera2D
	camera.limit_left   = -1280
	camera.limit_right  =  1280
	camera.limit_top    =  0
	camera.limit_bottom =  720

	# Level selector (hidden until win)
	level_select = GameState.load_top_scene("res://scenes/LevelSelector.tscn")
	level_select.hide()

	_switch_music($Music/Default)

	# Chase timer — fires to start a baron chase
	chase_timer = Timer.new()
	chase_timer.one_shot = true
	chase_timer.autostart = false
	chase_timer.timeout.connect(_on_chase_timer_timeout)
	add_child(chase_timer)

	# Resolve timer — fires if player doesn't reach Horton in time
	chase_resolve_timer = Timer.new()
	chase_resolve_timer.wait_time = CHASE_RESOLVE_TIME
	chase_resolve_timer.one_shot = true
	chase_resolve_timer.autostart = false
	chase_resolve_timer.timeout.connect(_on_chase_resolve_timer_timeout)
	add_child(chase_resolve_timer)

	# Resolve timer — fires if player doesn't reach Horton in time
	chase_buffer_timer = Timer.new()
	chase_buffer_timer.wait_time = 2
	chase_buffer_timer.one_shot = true
	chase_buffer_timer.autostart = false
	chase_buffer_timer.timeout.connect(_on_chase_buffer_timer_timeout)
	add_child(chase_buffer_timer)

	# Start entrances, then begin first chase countdown
	$Node2D.horton_enter()
	await get_tree().create_timer(10).timeout
	$Node2D.baron_enter()
	await get_tree().create_timer(5).timeout   # give player time to settle

	# first time
	chase_timer.wait_time = 2
	chase_timer.start()
	_start_next_chase_timer()

# ---------------------------------------------------------------------------
# Music crossfade
# ---------------------------------------------------------------------------
func _switch_music(new_music: AudioStreamPlayer) -> void:
	if new_music == current_music:
		return
	var fade_time = 1.0
	var tween = create_tween()
	if current_music and current_music.playing:
		tween.tween_property(current_music, "volume_db", -40.0, fade_time)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
	if current_music and current_music != new_music:
		current_music.stop()
	current_music = new_music
	current_music.volume_db = 0.0
	current_music.play()

# ---------------------------------------------------------------------------
# Chat interface loading
# ---------------------------------------------------------------------------
func _load_chat_interface() -> void:
	chat_instance = GameState.load_top_scene("res://scenes/HortonChat.tscn")
	chat_instance.hide()
	if chat_instance.has_method("set_sprites_node"):
		chat_instance.set_sprites_node($Node2D)
	chat_instance.horton_trusts_player.connect(_on_horton_trusts_player)
	chat_instance.baron_wins.connect(_on_baron_wins)
	chat_instance.whos_lost.connect(_on_whos_lost)
	print("[LEVEL] Chat interface loaded.")

# ---------------------------------------------------------------------------
# Input — E key interactions
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		return
	if is_chase_active or is_chase_buffer:
		return

	# Talk to Horton (only when Horton has the clover — normal flow)
	if is_near_horton and clover_state == "horton":
		if chat_instance == null:
			_load_chat_interface()
		await get_tree().process_frame
		chat_instance.show()
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat("horton")
		print("[LEVEL] Horton chat opened")

	# Baron has the clover — no more negotiation, level is already lost

# ---------------------------------------------------------------------------
# _process — chase resolution + clover handoff proximity
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not player or not horton:
		return

	# During an active chase: did the player reach Horton in time?
	if is_chase_active:
		if horton.overlaps_body(player):
			_resolve_chase(true)
		return

	pass  # no clover-return mechanic — baron_wins goes straight to Cat level

# ---------------------------------------------------------------------------
# Horton area signals
# ---------------------------------------------------------------------------
func _on_horton_area_entered(body: Node2D) -> void:
	if body == player:
		is_near_horton = true
		_update_interaction_label()

func _on_horton_area_exited(body: Node2D) -> void:
	if body == player:
		is_near_horton = false
		_update_interaction_label()

# ---------------------------------------------------------------------------
# Baron area signals
# ---------------------------------------------------------------------------
func _on_baron_area_entered(body: Node2D) -> void:
	if body == player:
		is_near_baron = true
		_update_interaction_label()

func _on_baron_area_exited(body: Node2D) -> void:
	if body == player:
		is_near_baron = false
		_update_interaction_label()

# ---------------------------------------------------------------------------
# Chase mechanic
# ---------------------------------------------------------------------------
func _start_next_chase_timer() -> void:
	if outcome_triggered:
		return
	var stage = chat_instance.get_decode_stage() if (chat_instance and chat_instance.has_method("get_decode_stage")) else 0
	var interval = max(CHASE_MIN_INTERVAL, CHASE_BASE_INTERVAL - float(stage) * 3.0)
	# give more wait time if they can speak since TTS takes a while
	if GameState.tts_on:
		interval *= 2
	print("[LEVEL] Next baron chase in %.1fs (decode_stage=%d)" % [interval, stage])
	chase_timer.wait_time = interval
	chase_timer.start()

func _on_chase_timer_timeout() -> void:
	if outcome_triggered or is_chase_active:
		return
	if clover_state != "horton":
		# Baron already has the clover — no need to chase
		_start_next_chase_timer()
		return
	# if TTS on, wait for the current speaker
	if GameState.tts_on and chat_instance:
		await get_tree().create_timer(chat_instance.text_to_speech.audio_length).timeout
	_start_chase()

func _start_chase() -> void:
	# Force-close chat if open
	if chat_instance and is_instance_valid(chat_instance) and chat_instance.has_method("forced_close"):
		chat_instance.forced_close("chase")

	interaction_label.text = "The Baron is charging at Horton! RUN to help!"
	is_chase_buffer = true
	$Node2D.baron_chase_horton()
	chase_buffer_timer.start()
	print("[LEVEL] Chase started!")

func _on_chase_buffer_timer_timeout() -> void:
	is_chase_buffer = false
	is_chase_active = true
	chase_resolve_timer.start()

func _on_chase_resolve_timer_timeout() -> void:
	if not is_chase_active:
		return
	_resolve_chase(false)

func _resolve_chase(player_made_it: bool) -> void:
	if not is_chase_active:
		return
	is_chase_active = false
	chase_resolve_timer.stop()

	if player_made_it:
		print("[LEVEL] Chase resolved — player saved Horton!")
		$Node2D.baron_back_off()
		interaction_label.text = "You drove the Baron back! Talk to Horton to continue decoding..."
		_start_next_chase_timer()
	else:
		print("[LEVEL] Chase resolved — Baron grabs the clover!")
		$Node2D.baron_grab_clover()
		# Treat this exactly like the chat-driven baron_wins outcome
		GameState.baron_has_clover = true
		_on_baron_wins()

# ---------------------------------------------------------------------------
# Interaction label helper
# ---------------------------------------------------------------------------
func _update_interaction_label() -> void:
	print("update interaction label")
	if is_chase_active or is_chase_buffer:
		interaction_label.text = "RUN to Horton!"
		return
	match clover_state:
		"horton":
			if is_near_horton:
				interaction_label.text = "Press [E] to talk with Horton and decode the Who messages!"
			else:
				interaction_label.text = "Walk up to Horton the Elephant!"
		"baron":
			interaction_label.text = "Baron Von Bitey grabbed the clover and is heading to the Cat's house!"

# ---------------------------------------------------------------------------
# Outcome handlers
# ---------------------------------------------------------------------------
func _on_horton_trusts_player() -> void:
	GameState.set_can_move(true)
	$Node2D/Horton.idle_happy_clover(15)
	_switch_music($Music/Success)
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	print("[HortonLevel] WIN! Whoville saved!")
	if chat_instance:
		await get_tree().create_timer(3.5).timeout
		chat_instance.hide()
	interaction_label.text = "The Whos are saved! An elephant's faithful, one hundred percent. Open the storybook above to continue..."
	level_select.show()

func _on_baron_wins() -> void:
	if outcome_triggered:
		return
	GameState.set_can_move(true)
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	chase_buffer_timer.stop()
	is_chase_active = false
	is_chase_buffer = false
	GameState.baron_has_clover = true   # ensure set regardless of which path triggered
	GameState.unlock_level("cat")
	print("[HortonLevel] FAIL 1 — Baron took the clover! Routing to Cat (Boring) level.")
	if chat_instance:
		await get_tree().create_timer(3.5).timeout
		chat_instance.hide()
	interaction_label.text = "Baron Von Bitey has taken the clover and is heading straight to the Cat's house. Get there before it's too late — open the storybook above."
	level_select.show()

func _on_whos_lost() -> void:
	if outcome_triggered:
		return
	GameState.set_can_move(true)
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	chase_buffer_timer.stop()
	is_chase_active = false
	GameState.unlock_level("cat")   # Let player continue to Cat level even on this fail
	print("[HortonLevel] FAIL 2 — The Whos were lost.")
	if chat_instance:
		await get_tree().create_timer(4.0).timeout
		chat_instance.hide()
	interaction_label.text = "The messages went undecoded for too long... Hurry to the Cat's house. Open the storybook above."
	level_select.show()
