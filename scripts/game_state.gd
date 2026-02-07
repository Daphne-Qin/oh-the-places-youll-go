extends Control

## Game State Manager (Autoload Singleton)
## Manages global game state variables like player movement control and level progression

# Global flag to control whether the player can move
# Set to false during cutscenes or dialogue
@export var can_move: bool = true

# Signal emitted when movement state changes
signal movement_state_changed(can_move: bool)
var lorax_level: Node

# Level unlock system
signal level_unlocked(level_id: String)
signal level_completed(level_id: String)

# Level definitions: id -> {name, scene_path, unlocked, completed, map_position}
var levels := {
	"lorax": {
		"name": "The Lorax",
		"scene_path": "res://scenes/LoraxLevel.tscn",
		"unlocked": true,  # First level always unlocked
		"completed": false,
		"map_position": Vector2(38, 497),  # Position on the map
		"icon": "res://assets/sprites/levelselect/icon_lorax.png"
	},
	"horton": {
		"name": "Horton Hears a Who",
		"scene_path": "res://scenes/HortonLevel.tscn",
		"unlocked": false,  # Unlocked after completing Lorax
		"completed": false,
		"map_position": Vector2(1050, 553),
		"icon": "res://assets/sprites/levelselect/icon_horton.png"
	}
}

var current_level: String = "lorax"

func set_can_move(value: bool) -> void:
	"""Set whether the player can move and emit signal."""
	if can_move != value:
		can_move = value
		movement_state_changed.emit(can_move)

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
			pass  # Future: unlock next level after Horton

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
		print("[GameState] Navigating to level: ", level_id)
		get_tree().change_scene_to_file(scene_path)
	else:
		print("[GameState] Level is locked: ", level_id)
