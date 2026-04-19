extends Control

## Game State Manager (Autoload Singleton)
## Manages global game state variables like player movement control and level progression

# Global flag to control whether the player can move
# Set to false during cutscenes or dialogue
@export var can_move: bool = true

# fade overlay
@onready var fade_canvas: CanvasLayer
@onready var fade_overlay: ColorRect

# Signal emitted when movement state changes
signal movement_state_changed(can_move: bool)
var lorax_level: Node
var baron_has_clover: bool = false  # Cross-level: set true when Baron grabs clover in Horton level
var player_has_seed: bool = false   # Cross-level: set true when Lorax gives player the Truffula seed

# default settings
var background_volume = 100
var tts_on = true
var stt_on = false
var font_size = 18

# tts toggle signal
signal tts_toggled(on: bool)

# font size signal
signal font_size_changed(font_size: int)

# Level unlock system
signal level_unlocked(level_id: String)
signal level_completed(level_id: String)
signal scene_switch  # Fired before any scene transition

# Level definitions: id -> {name, scene_path, unlocked, completed, map_position}
var levels := {
	"lorax": {
		"name": "The Lorax",
		"scene_path": "res://scenes/LoraxLevel.tscn",
		"unlocked": true,  # First level always unlocked
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map2.png"),
		"map_position": Vector2(38, 497),  # Position on the map
		"icon": "res://assets/sprites/levelselect/icon_lorax.png"
	},
	"horton": {
		"name": "Horton Hears a Who",
		"scene_path": "res://scenes/HortonLevel.tscn",
		"unlocked": false,  # Unlocked after completing Lorax
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map3.png"),
		"map_position": Vector2(1050, 553),
		"icon": "res://assets/sprites/levelselect/icon_horton.png"
	},
	"cat": {
		"name": "The Cat in the Hat",
		"scene_path": "res://scenes/CatLevel.tscn",
		"unlocked": false,  # Unlocked after completing Horton
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map3.png"),
		"map_position": Vector2(200, 300),
		"icon": ""
	},
	"cat_boring": {
		"name": "The Cat in the Hat",
		"scene_path": "res://scenes/CatLevelBoring.tscn",
		"unlocked": false,  # Unlocked after completing Horton
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map3.png"),
		"map_position": Vector2(200, 300),
		"icon": ""
	},
	"end_success": {
		"name": "The End?",
		"scene_path": "res://scenes/EndSceneSuccess.tscn",
		"unlocked": false,  # Unlocked after completing Horton
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map3.png"),
		"map_position": Vector2(100, 100),
		"icon": ""
	},
	"end_failure": {
		"name": "The End?",
		"scene_path": "res://scenes/EndSceneFailure.tscn",
		"unlocked": false,  # Unlocked after completing Horton
		"completed": false,
		"map_sprite": preload("res://assets/sprites/levelselect/map3.png"),
		"map_position": Vector2(100, 100),
		"icon": ""
	}
}

var current_level: String = "lorax"

func _ready() -> void:
	# setup fade canvas
	fade_canvas = CanvasLayer.new()
	fade_canvas.layer = 5000
	add_child(fade_canvas)
	
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color.BLACK
	fade_overlay.color.a = 0.0
	fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_overlay.z_index = 5000
	fade_canvas.add_child(fade_overlay)
	
	fade_canvas.hide()

func set_can_move(value: bool) -> void:
	"""Set whether the player can move and emit signal."""
	if can_move != value:
		can_move = value
		movement_state_changed.emit(can_move)
		
func set_background_volume(value: int) -> void:
	'''
	Accounts for TTS and STT being on
	'''
	var effective_volume = value / 100.0
	var idx = AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_linear(idx, effective_volume)

func toggle_background_volume_dim(value: bool) -> void:
	if value:
		set_background_volume(min(20, background_volume))
	else:
		set_background_volume(background_volume)

func toggle_tts(value: bool) -> void:
	tts_on = value
	tts_toggled.emit(value)

func toggle_stt(value: bool) -> void:
	stt_on = value
	# mute all audio
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), value)

func set_font_size(value: int) -> void:
	if font_size != value:
		font_size = value
		font_size_changed.emit(value)

func enable_movement() -> void:
	"""Enable player movement."""
	set_can_move(true)

func disable_movement() -> void:
	"""Disable player movement (e.g., during cutscenes or dialogue)."""
	set_can_move(false)

# Level management functions
func unlock_level(level_id: String) -> void:
	"""Unlock a level by its ID."""
	if levels.has(level_id) and not levels[level_id].unlocked:
		levels[level_id].unlocked = true
		level_unlocked.emit(level_id)
		print("[GameState] Level unlocked: ", level_id)

func complete_level(level_id: String) -> void:
	"""Mark a level as completed."""
	if levels.has(level_id) and not levels[level_id].completed:
		levels[level_id].completed = true
		level_completed.emit(level_id)
		print("[GameState] Level completed: ", level_id)
		# Auto-unlock next levels based on completion
		_handle_level_completion(level_id)

func _handle_level_completion(level_id: String) -> void:
	"""Handle unlocking new levels when a level is completed."""
	match level_id:
		"lorax":
			unlock_level("truffula_forest")  # Passing Lorax riddles unlocks the forest
			unlock_level("horton")  # Also unlock Horton's level
		"horton":
			unlock_level("cat")  # Completing Horton unlocks the Cat in the Hat level

func is_level_unlocked(level_id: String) -> bool:
	"""Check if a level is unlocked."""
	return levels.has(level_id) and levels[level_id].unlocked

func is_level_completed(level_id: String) -> bool:
	"""Check if a level is completed."""
	return levels.has(level_id) and levels[level_id].completed

func get_level_data(level_id: String) -> Dictionary:
	"""Get all data for a level."""
	if levels.has(level_id):
		return levels[level_id]
	return {}

func go_to_level(level_id: String) -> void:
	"""Navigate to a level if it's unlocked."""
	if is_level_unlocked(level_id):
		current_level = level_id
		var scene_path = levels[level_id].scene_path
		# Cat level routes to Boring or Fun version based on Horton outcome
		if level_id == "cat":
			scene_path = "res://scenes/CatLevelBoring.tscn" if baron_has_clover else "res://scenes/CatLevel.tscn"
		print("[GameState] Navigating to level: %s (scene: %s)" % [level_id, scene_path])
		await get_tree().process_frame  # Give listeners one frame to clean up
		transition_to_scene(scene_path)
	else:
		print("[GameState] Level is locked: ", level_id)


func transition_to_scene(scene_path: String) -> void:
	"""Smooth fade transition to another scene."""	
	scene_switch.emit()
	
	var tts_idx = AudioServer.get_bus_index("TTS")
	var tts_vol = AudioServer.get_bus_volume_linear(tts_idx)
	AudioServer.set_bus_volume_linear(tts_idx, 0)
	fade_canvas.show()
	
	# Fade out
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(fade_overlay, "color:a", 1.0, 1.0)
	var music_idx = AudioServer.get_bus_index("Music")
	fade_tween.tween_method(
		func(vol): AudioServer.set_bus_volume_linear(music_idx, vol),
		AudioServer.get_bus_volume_linear(music_idx),
		0.0,
		1.0
	)
	await fade_tween.finished

	# Change scene
	get_tree().change_scene_to_file(scene_path)
	
	# reset fade
	fade_canvas.hide()
	fade_overlay.color.a = 0.0
	set_background_volume(background_volume)
	AudioServer.set_bus_volume_linear(tts_idx, tts_vol)

func load_top_scene(scene_path: String) -> Control:
	'''
	Loads a scene into the level and allow overlay.
	'''
	var scene_resource = load(scene_path)
	var scene = scene_resource.instantiate()
	
	# Add to a CanvasLayer so it's always on top
	var ui_layer = get_node_or_null("UILayer")
	if not ui_layer:
		ui_layer = CanvasLayer.new()
		ui_layer.name = "UILayer"
		ui_layer.layer = 1000
		add_child(ui_layer)
	
	ui_layer.add_child(scene)
	scene.hide()
	
	return scene
