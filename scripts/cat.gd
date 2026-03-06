extends Area2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	idle()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func move() -> void:
	"""Play the walk animation (used on ready and for patrol)."""
	sprite.sprite_frames.set_animation_speed("walk", 24.0)
	sprite.play("walk")

func idle() -> void:
	"""Play the stand/idle animation."""
	sprite.play("idle")
