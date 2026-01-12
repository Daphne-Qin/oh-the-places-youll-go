extends Node

signal dialogue_started(dialogue_id: String)
signal dialogue_ended(dialogue_id: String)

var current_dialogue: Dictionary = {}
var dialogue_history: Array[String] = []

func start_dialogue(dialogue_id: String) -> void:
	"""Start a dialogue sequence with the given ID."""
	if dialogue_id in dialogue_history:
		return
	
	# Disable player movement during dialogue
	GameState.disable_movement()
	dialogue_started.emit(dialogue_id)
	# Dialogue logic will be implemented here
	print("Starting dialogue: ", dialogue_id)

func end_dialogue() -> void:
	"""End the current dialogue sequence."""
	if current_dialogue.is_empty():
		return
	
	dialogue_ended.emit(current_dialogue.get("id", ""))
	current_dialogue.clear()
	# Re-enable player movement after dialogue ends
	GameState.enable_movement()

func get_dialogue_text(dialogue_id: String) -> String:
	"""Retrieve dialogue text from dialogue_data.json."""
	# Will be implemented with API manager integration
	return ""
