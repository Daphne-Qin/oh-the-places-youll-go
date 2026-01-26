extends Node

## Game State Manager (Autoload Singleton)
## Manages global game state variables like player movement control

# Global flag to control whether the player can move
# Set to false during cutscenes or dialogue
@export var can_move: bool = true

# Signal emitted when movement state changes
signal movement_state_changed(can_move: bool)

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
