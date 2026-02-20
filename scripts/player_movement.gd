extends CharacterBody2D

## Player Movement Script
## Handles 2D side-scrolling movement with smooth acceleration/deceleration
## and sprite flipping based on movement direction.

@export var speed: float = 200.0  # Movement speed in pixels per second
@export var acceleration: float = 1000.0  # How quickly the player reaches max speed
@export var friction: float = 1000.0  # How quickly the player stops when no input

var can_move = true

# Track the last direction the player was facing (1 = right, -1 = left)
var facing_direction: int = 1
var screen_size

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Connect to GameState signal
	can_move = GameState.can_move  # initialize from global state
	GameState.movement_state_changed.connect(_on_movement_state_changed)
	
func _on_movement_state_changed(value: bool) -> void:
	"""Update local movement flag when GameState changes"""
	can_move = value

func _physics_process(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if can_move:
		if Input.is_action_pressed("move_right"):
			$AnimatedSprite2D.flip_h = false
			velocity.x += 1
		if Input.is_action_pressed("move_left"):
			$AnimatedSprite2D.flip_h = true
			velocity.x -= 1
		
	if velocity.length() > 0:
		velocity = velocity.normalized()*speed
		$AnimatedSprite2D.play("walk")
	else:
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.animation = "stand"
		
	move_and_slide()
