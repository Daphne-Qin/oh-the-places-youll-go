extends Control

## Horton Level Controller
## Manages the three-way interaction: Player ↔ Horton ↔ Baron Von Bitey
## New mechanics: decode messages, Baron chase, clover ownership states

@onready var horton: Area2D = $Node2D/Horton
@onready var player: CharacterBody2D = $Node2D/Player
@onready var baron: Area2D = $Node2D/Baron
@onready var current_music: AudioStreamPlayer = null

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
var chase_timer: Timer
var chase_resolve_timer: Timer
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

	# Start entrances, then begin first chase countdown
	$Node2D.horton_enter()
	await get_tree().create_timer(2.0).timeout
	$Node2D.baron_enter()
	await get_tree().create_timer(6.0).timeout   # give player time to settle
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
	chat_instance.baron_drops_clover.connect(_on_baron_drops_clover)
	print("[LEVEL] Chat interface loaded.")

# ---------------------------------------------------------------------------
# Input — E key interactions
# ---------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and event.keycode == KEY_E):
		return
	if is_chase_active:
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

	# Talk to Baron (only when Baron has the clover — negotiate to get it back)
	elif is_near_baron and clover_state == "baron":
		if chat_instance == null:
			_load_chat_interface()
		await get_tree().process_frame
		chat_instance.show()
		if chat_instance.has_method("open_chat"):
			chat_instance.open_chat("baron")
		print("[LEVEL] Baron chat opened")

# ---------------------------------------------------------------------------
# _process — chase resolution + clover handoff proximity
# ---------------------------------------------------------------------------
func _process(_delta: float) -> void:
	if not player or not horton:
		return

	# During an active chase: did the player reach Horton in time?
	if is_chase_active:
		if player.global_position.distance_to(horton.global_position) < 200.0:
			_resolve_chase(true)
		return

	# Player carrying clover back to Horton
	if clover_state == "player":
		if player.global_position.distance_to(horton.global_position) < 160.0:
			_return_clover_to_horton()

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
	_start_chase()

func _start_chase() -> void:
	is_chase_active = true

	# Force-close chat if open
	if chat_instance and is_instance_valid(chat_instance) and chat_instance.has_method("forced_close"):
		chat_instance.forced_close("chase")

	$InteractionLabel.text = "The Baron is charging at Horton! RUN to help!"
	$Node2D.baron_chase_horton()
	chase_resolve_timer.start()
	print("[LEVEL] Chase started!")

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
		$InteractionLabel.text = "You drove the Baron back! Talk to Horton to continue decoding..."
		_start_next_chase_timer()
	else:
		print("[LEVEL] Chase resolved — Baron grabs the clover!")
		clover_state = "baron"
		if chat_instance and is_instance_valid(chat_instance) and chat_instance.has_method("set_clover_state"):
			chat_instance.set_clover_state("baron")
		$Node2D.baron_grab_clover()
		$InteractionLabel.text = "Baron Von Bitey grabbed the clover! Get close to him and press [E] to negotiate!"

# ---------------------------------------------------------------------------
# Clover handoff — Baron drops clover
# ---------------------------------------------------------------------------
func _on_baron_drops_clover() -> void:
	# Player is already near Baron (they were chatting), so give clover to player
	clover_state = "player"
	if chat_instance and is_instance_valid(chat_instance) and chat_instance.has_method("set_clover_state"):
		chat_instance.set_clover_state("player")
	$Node2D.baron_drops_clover_visual()
	$InteractionLabel.text = "Baron dropped the clover! Bring it back to Horton!"
	print("[LEVEL] Baron dropped the clover — player now holds it.")

func _return_clover_to_horton() -> void:
	clover_state = "horton"
	if chat_instance and is_instance_valid(chat_instance) and chat_instance.has_method("set_clover_state"):
		chat_instance.set_clover_state("horton")
	$Node2D.horton_reclaim_clover()
	$InteractionLabel.text = "Horton has the clover! Continue decoding the Who messages..."
	_start_next_chase_timer()
	print("[LEVEL] Clover returned to Horton.")

# ---------------------------------------------------------------------------
# Interaction label helper
# ---------------------------------------------------------------------------
func _update_interaction_label() -> void:
	if is_chase_active:
		$InteractionLabel.text = "RUN to Horton!"
		return
	match clover_state:
		"horton":
			if is_near_horton:
				$InteractionLabel.text = "Press [E] to talk with Horton and decode the Who messages!"
			else:
				$InteractionLabel.text = "Walk up to Horton the Elephant!"
		"baron":
			if is_near_baron:
				$InteractionLabel.text = "Press [E] to talk to Baron Von Bitey!"
			else:
				$InteractionLabel.text = "Baron Von Bitey has the clover — get close to him!"
		"player":
			$InteractionLabel.text = "Bring the clover back to Horton!"

# ---------------------------------------------------------------------------
# Outcome handlers
# ---------------------------------------------------------------------------
func _on_horton_trusts_player() -> void:
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	print("[HortonLevel] WIN! Whoville saved!")
	if chat_instance:
		await get_tree().create_timer(3.5).timeout
		chat_instance.hide()
	$InteractionLabel.text = "The Whos are saved! An elephant's faithful, one hundred percent. Open the storybook above to continue..."
	level_select.show()

func _on_baron_wins() -> void:
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	print("[HortonLevel] FAIL 1 — Baron took the clover!")
	if chat_instance:
		await get_tree().create_timer(4.0).timeout
		chat_instance.hide()
	$InteractionLabel.text = "Baron Von Bitey has taken the clover for his soup... The Whos are in terrible danger. Try again."

func _on_whos_lost() -> void:
	outcome_triggered = true
	chase_timer.stop()
	chase_resolve_timer.stop()
	print("[HortonLevel] FAIL 2 — The Whos were lost.")
	if chat_instance:
		await get_tree().create_timer(4.0).timeout
		chat_instance.hide()
	$InteractionLabel.text = "The messages went undecoded for too long... The Whos needed your help. Try again."
