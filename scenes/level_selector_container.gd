extends Control

# LEGIT THE ONLY REASON THIS EXISTS IS SINCE THE LOCATION OF THE MAP WOULDN'T WORK OTHERWISE AHHH
# idk why it doesn't work in LoraxLevel directly

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$LevelSelector.hide()
	#var lorax_chat = get_node("../LoraxChat") # adjust path!
	#lorax.player_granted_access.connect(_on_player_granted_access)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _on_player_granted_access() -> void:
	$LevelSelector.show()
