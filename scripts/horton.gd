extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func walk_clover(speed: float = 20.0):
	$AnimatedSprite2D.sprite_frames.set_animation_speed("walk_clover", speed)
	$AnimatedSprite2D.play("walk_clover")

func walk_noclover(speed: float = 20.0):
	$AnimatedSprite2D.sprite_frames.set_animation_speed("walk_noclover", speed)
	$AnimatedSprite2D.play("walk_noclover")

func idle_anxious_noclover(speed: float = 20.0):
	$AnimatedSprite2D.sprite_frames.set_animation_speed("idle_anxious_noclover", speed)
	$AnimatedSprite2D.play("idle_anxious_noclover")

func idle_anxious_clover(speed: float = 20.0):
	$AnimatedSprite2D.sprite_frames.set_animation_speed("idle_anxious_clover", speed)
	$AnimatedSprite2D.play("idle_anxious_clover")

func idle_happy_clover(speed: float = 20.0):
	$AnimatedSprite2D.sprite_frames.set_animation_speed("idle_happy_clover", speed)
	$AnimatedSprite2D.play("idle_happy_clover")

func flip_h(value: bool):
	$AnimatedSprite2D.flip_h = value
