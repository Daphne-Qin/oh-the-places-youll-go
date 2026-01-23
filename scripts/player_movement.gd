extends CharacterBody2D

## Player Movement Script
## Handles 2D side-scrolling movement with smooth acceleration/deceleration
## and sprite flipping based on movement direction.

@export var speed: float = 200.0  # Movement speed in pixels per second
@export var acceleration: float = 1000.0  # How quickly the player reaches max speed
@export var friction: float = 1000.0  # How quickly the player stops when no input

# Track the last direction the player was facing (1 = right, -1 = left)
var facing_direction: int = 1
var screen_size

func _ready() -> void:
	screen_size = get_viewport_rect().size

func _process(delta):
	velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		$AnimatedSprite2D.flip_h = false
		velocity.x += 1
	if Input.is_action_pressed("ui_left"):
		$AnimatedSprite2D.flip_h = true
		velocity.x -= 1
		
	if velocity.length() > 0:
		velocity = velocity.normalized()*speed
		$AnimatedSprite2D.animation = "walk"
		$AnimatedSprite2D.play()
	else:
		$AnimatedSprite2D.stop()
		$AnimatedSprite2D.animation = "stand"
		
	position += velocity * delta
	position = position.clamp(Vector2.ZERO, screen_size)

#func _physics_process(delta: float) -> void:
	## Check if player can move (controlled by global game state)
	## Movement is disabled during cutscenes or dialogue
	#if not GameState.can_move:
		## Apply friction when movement is disabled
		#velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		#move_and_slide()
		#return
	#
	## Get horizontal input (left/right movement only)
	## Input.get_axis returns -1 for left, 1 for right, 0 for no input
	## Works with both arrow keys and WASD (default Godot input map)
	#var horizontal_input: float = Input.get_axis("ui_left", "ui_right")
	#
	## Apply movement with smooth acceleration
	#if horizontal_input != 0.0:
		## Accelerate towards target speed
		#velocity.x = move_toward(velocity.x, horizontal_input * speed, acceleration * delta)
		#
		## Update facing direction and flip sprite
		#var new_facing: int = 1 if horizontal_input > 0 else -1
		#if new_facing != facing_direction:
			#facing_direction = new_facing
			#_flip_sprite()
	#else:
		## No input: apply friction to gradually stop
		#velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	#
	## Apply movement using Godot's built-in physics
	#move_and_slide()
