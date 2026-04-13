extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	idle()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func walk(speed: float = 24.0) -> void:
	"""Play the walk animation (used on ready and for patrol)."""
	sprite.sprite_frames.set_animation_speed("walk", speed)
	sprite.play("walk")

func idle(speed: float = 10.0) -> void:
	"""Play the stand/idle animation."""
	sprite.sprite_frames.set_animation_speed("walk", speed)
	sprite.play("idle")

func soup_drnk(speed: float = 10.0) -> void:
	"""Plays the soup drink animation exactly once, and stops at the last frame."""
	sprite.sprite_frames.set_animation_speed("soup_drink", speed)
	sprite.sprite_frames.set_animation_loop("soup_drink", false)
	sprite.play("soup_drink")
