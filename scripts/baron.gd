extends Area2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	move()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func move():
	$AnimatedSprite2D.play("walk")

func stand():
	$AniamtedSprite2D.play("stand")
