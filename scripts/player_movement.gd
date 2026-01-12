extends CharacterBody2D

@export var speed: float = 200.0
@export var acceleration: float = 1000.0
@export var friction: float = 1000.0

func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	
	# Get input direction
	input_vector.x = Input.get_axis("ui_left", "ui_right")
	input_vector.y = Input.get_axis("ui_up", "ui_down")
	
	# Normalize diagonal movement
	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		velocity = velocity.move_toward(input_vector * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()
