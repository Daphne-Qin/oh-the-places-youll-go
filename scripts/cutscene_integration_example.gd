extends Node

## Example: How to integrate the OpeningCutscene into your game
## 
## Option 1: Load as a separate scene before the main level
## Option 2: Add as a child node to your main level scene

# Example usage in a main game manager or level script:

func _ready() -> void:
	# Option 1: Load and play cutscene before transitioning to level
	# await _play_opening_cutscene()
	# get_tree().change_scene_to_file("res://scenes/LoraxLevel.tscn")
	pass

func _play_opening_cutscene() -> void:
	"""Load and play the opening cutscene."""
	var cutscene_scene = load("res://scenes/OpeningCutscene.tscn")
	var cutscene_instance = cutscene_scene.instantiate()
	
	# Add to scene tree
	add_child(cutscene_instance)
	
	# Connect to finished signal
	cutscene_instance.cutscene_finished.connect(_on_cutscene_finished.bind(cutscene_instance))
	
	# Wait for cutscene to finish
	await cutscene_instance.cutscene_finished
	
	# Remove cutscene from scene
	cutscene_instance.queue_free()

func _on_cutscene_finished(cutscene_node: Node) -> void:
	"""Called when the opening cutscene finishes."""
	print("Opening cutscene completed! Transitioning to game...")
	# Transition to main game level here
	# get_tree().change_scene_to_file("res://scenes/LoraxLevel.tscn")
