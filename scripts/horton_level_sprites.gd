extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func horton_enter():
	$Horton.position.x = -400  # start offscreen
	$Horton/AnimatedSprite2D.play("walk")
	var tween = create_tween()
	tween.tween_property($Horton, "position:x", 300, 3)
	tween.finished.connect(func ():
		$Horton/AnimatedSprite2D.stop()
	)
