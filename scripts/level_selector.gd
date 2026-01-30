extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$Map.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_open_selector_button_pressed() -> void:
	if $Map.visible:
		$Map.hide()
	else:
		$Map.show()
