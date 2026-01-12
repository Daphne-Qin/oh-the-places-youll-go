extends Node2D

## Opening Cutscene Manager
## Manages the opening cutscene where the Cat in the Hat chops down a tree

# Node references
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var cat: Node2D = $Cat
@onready var tree: Node2D = $Tree
@onready var tree_sprite: Sprite2D = $Tree/Sprite2D
@onready var particles: GPUParticles2D = $Tree/Particles2D
@onready var text_overlay: Label = $TextOverlay
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var background_music: AudioStreamPlayer = $BackgroundMusic

# Sound effect resource (will be loaded from assets)
var chop_sound: AudioStream

# Cutscene state
var is_playing: bool = false
var can_skip: bool = true

signal cutscene_finished()

func _ready() -> void:
	# Hide text overlay initially
	text_overlay.visible = false
	text_overlay.text = "Find the Lorax to save the forest!"
	
	# Hide particles initially
	particles.emitting = false
	
	# Load chop sound if available
	_load_sounds()
	
	# Start the cutscene automatically when scene loads
	start_cutscene()

func _input(event: InputEvent) -> void:
	# Allow skipping with Space or Enter
	if is_playing and can_skip:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
			skip_cutscene()

func start_cutscene() -> void:
	"""Start the opening cutscene sequence."""
	is_playing = true
	
	# Disable player movement
	GameState.disable_movement()
	
	# Reset positions
	_reset_positions()
	
	# Play the cutscene sequence
	await _play_sequence()

func _reset_positions() -> void:
	"""Reset all character positions to starting state."""
	# Cat starts off-screen to the right
	cat.position = Vector2(1400, 500)
	
	# Tree is in the center
	tree.position = Vector2(640, 500)
	tree.rotation_degrees = 0
	
	# Hide text overlay
	text_overlay.visible = false
	text_overlay.modulate.a = 0.0

func _play_sequence() -> void:
	"""Play the complete cutscene sequence using AnimationPlayer."""
	# Create animation tracks programmatically if not already set up
	_setup_animation_tracks()
	
	# Play the complete sequence animation
	animation_player.play("cutscene_sequence")
	
	# Wait for animation to finish
	await animation_player.animation_finished
	
	# End cutscene
	_end_cutscene()

func _setup_animation_tracks() -> void:
	"""Set up AnimationPlayer tracks programmatically."""
	if animation_player.has_animation("cutscene_sequence"):
		return  # Already set up
	
	var animation = Animation.new()
	animation.length = 11.5  # Total duration: 3 + 2 + 1.5 + 2 + 3 = 11.5 seconds
	
	# Track 1: Cat walks in (0-3 seconds)
	var cat_walk_track = animation.add_track(Animation.TYPE_POSITION_2D)
	animation.track_set_path(cat_walk_track, NodePath("Cat"))
	animation.track_insert_key(cat_walk_track, 0.0, Vector2(1400, 500))
	animation.track_insert_key(cat_walk_track, 3.0, Vector2(740, 500))
	
	# Track 2: Cat chops (3-5 seconds) - back and forth motion
	var cat_chop_track = animation.add_track(Animation.TYPE_POSITION_2D)
	animation.track_set_path(cat_chop_track, NodePath("Cat"))
	var chop_start = 3.0
	for i in range(4):  # 4 chops
		var chop_time = chop_start + (i * 0.5)
		animation.track_insert_key(cat_chop_track, chop_time, Vector2(740, 500))
		animation.track_insert_key(cat_chop_track, chop_time + 0.2, Vector2(720, 500))
		animation.track_insert_key(cat_chop_track, chop_time + 0.4, Vector2(740, 500))
	
	# Track 3: Tree falls (5-6.5 seconds) - rotation
	var tree_rotation_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(tree_rotation_track, NodePath("Tree:rotation_degrees"))
	animation.track_insert_key(tree_rotation_track, 5.0, 0.0)
	animation.track_insert_key(tree_rotation_track, 6.5, 90.0)
	
	# Track 4: Tree position (5-6.5 seconds) - falls down
	var tree_pos_track = animation.add_track(Animation.TYPE_POSITION_2D)
	animation.track_set_path(tree_pos_track, NodePath("Tree"))
	animation.track_insert_key(tree_pos_track, 5.0, Vector2(640, 500))
	animation.track_insert_key(tree_pos_track, 6.5, Vector2(640, 550))
	
	# Track 5: Cat runs off (6.5-8.5 seconds)
	var cat_run_track = animation.add_track(Animation.TYPE_POSITION_2D)
	animation.track_set_path(cat_run_track, NodePath("Cat"))
	animation.track_insert_key(cat_run_track, 6.5, Vector2(740, 500))
	animation.track_insert_key(cat_run_track, 8.5, Vector2(1400, 500))
	
	# Track 6: Text overlay fade in/out (8.5-11.5 seconds)
	var text_alpha_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(text_alpha_track, NodePath("TextOverlay:modulate:a"))
	animation.track_insert_key(text_alpha_track, 8.5, 0.0)
	animation.track_insert_key(text_alpha_track, 9.0, 1.0)
	animation.track_insert_key(text_alpha_track, 11.0, 1.0)
	animation.track_insert_key(text_alpha_track, 11.5, 0.0)
	
	# Add method call tracks for sound and particles
	var sound_track = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(sound_track, NodePath("."))
	animation.track_insert_key(sound_track, 3.0, {"method": "_play_chop_sound"})
	
	var particles_track = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(particles_track, NodePath("Tree/Particles2D"))
	animation.track_insert_key(particles_track, 5.0, {"method": "set_emitting", "args": [true]})
	animation.track_insert_key(particles_track, 6.5, {"method": "set_emitting", "args": [false]})
	
	var text_visible_track = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(text_visible_track, NodePath("TextOverlay:visible"))
	animation.track_insert_key(text_visible_track, 8.5, true)
	animation.track_insert_key(text_visible_track, 11.5, false)
	
	animation_player.add_animation("cutscene_sequence", animation)

func _play_chop_sound() -> void:
	"""Play chop sound effect (called by AnimationPlayer)."""
	if chop_sound:
		audio_player.stream = chop_sound
		audio_player.play()

func skip_cutscene() -> void:
	"""Skip the current cutscene."""
	if not is_playing:
		return
	
	# Stop AnimationPlayer
	if animation_player.is_playing():
		animation_player.stop()
	
	# Stop particles
	particles.emitting = false
	
	# Hide text
	text_overlay.visible = false
	
	# Fast-forward to end state
	cat.position = Vector2(1400, 500)
	tree.rotation_degrees = 90.0
	tree.position = Vector2(640, 550)
	
	# End cutscene immediately
	_end_cutscene()

func _end_cutscene() -> void:
	"""End the cutscene and enable player control."""
	is_playing = false
	
	# Re-enable player movement
	GameState.enable_movement()
	
	# Start background music
	if background_music.stream:
		background_music.play()
	
	# Emit signal
	cutscene_finished.emit()
	
	print("Opening cutscene finished")

func _load_sounds() -> void:
	"""Load sound effects from assets folder."""
	# Try to load chop sound
	var chop_path = "res://assets/audio/sfx/chop.ogg"
	if ResourceLoader.exists(chop_path):
		chop_sound = load(chop_path)
	else:
		print("Warning: Chop sound not found at ", chop_path)
	
	# Try to load background music
	var music_path = "res://assets/audio/music/background.ogg"
	if ResourceLoader.exists(music_path):
		background_music.stream = load(music_path)
	else:
		print("Warning: Background music not found at ", music_path)
