extends CharacterBody2D

## Player Movement Script
## Handles 2D side-scrolling movement with smooth acceleration/deceleration
## and sprite flipping based on movement direction.

@export var speed: float = 200.0  # Movement speed in pixels per second
@export var acceleration: float = 1000.0  # How quickly the player reaches max speed
@export var friction: float = 1000.0  # How quickly the player stops when no input

# Reference to the sprite node for flipping
@onready var sprite: Sprite2D = $Sprite2D

# Track the last direction the player was facing (1 = right, -1 = left)
var facing_direction: int = 1

func _ready() -> void:
	# Automatically find the Sprite2D node if it exists
	if not sprite:
		sprite = get_node_or_null("Sprite2D")
		if not sprite:
			print("Warning: No Sprite2D node found. Sprite flipping will not work.")

func _physics_process(delta: float) -> void:
	# Check if player can move (controlled by global game state)
	# Movement is disabled during cutscenes or dialogue
	if not GameState.can_move:
		# Apply friction when movement is disabled
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		move_and_slide()
		return
	
	# Get horizontal input (left/right movement only)
	# Input.get_axis returns -1 for left, 1 for right, 0 for no input
	# Works with both arrow keys and WASD (default Godot input map)
	var horizontal_input: float = Input.get_axis("ui_left", "ui_right")
	
	# Apply movement with smooth acceleration
	if horizontal_input != 0.0:
		# Accelerate towards target speed
		velocity.x = move_toward(velocity.x, horizontal_input * speed, acceleration * delta)
		
		# Update facing direction and flip sprite
		var new_facing: int = 1 if horizontal_input > 0 else -1
		if new_facing != facing_direction:
			facing_direction = new_facing
			_flip_sprite()
	else:
		# No input: apply friction to gradually stop
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	
	# Apply movement using Godot's built-in physics
	move_and_slide()

func _flip_sprite() -> void:
	# Flip the sprite horizontally based on facing direction
	if sprite:
		sprite.flip_h = (facing_direction == -1)
