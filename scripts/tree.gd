extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	animate_sway()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func animate_sway():
	$AnimatedSprite2D.speed_scale = 0.5
	$AnimatedSprite2D.play("sway")

func animate_cut():
	$AnimatedSprite2D.speed_scale = 0.5
	$AnimatedSprite2D.play("cut")
