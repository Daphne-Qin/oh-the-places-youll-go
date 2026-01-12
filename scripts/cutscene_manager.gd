extends Node

signal cutscene_started(cutscene_id: String)
signal cutscene_ended(cutscene_id: String)

var current_cutscene: Dictionary = {}
var cutscene_queue: Array[String] = []
var is_playing: bool = false

func play_cutscene(cutscene_id: String) -> void:
	"""Play a cutscene with the given ID."""
	if is_playing:
		cutscene_queue.append(cutscene_id)
		return
	
	is_playing = true
	cutscene_started.emit(cutscene_id)
	
	# Cutscene logic will be implemented here
	print("Playing cutscene: ", cutscene_id)
	
	# For now, immediately end (replace with actual cutscene logic)
	await get_tree().create_timer(1.0).timeout
	end_cutscene(cutscene_id)

func end_cutscene(cutscene_id: String) -> void:
	"""End the current cutscene."""
	cutscene_ended.emit(cutscene_id)
	current_cutscene.clear()
	is_playing = false
	
	# Play next cutscene in queue if any
	if cutscene_queue.size() > 0:
		var next_id := cutscene_queue.pop_front()
		play_cutscene(next_id)

func skip_cutscene() -> void:
	"""Skip the current cutscene."""
	if is_playing and not current_cutscene.is_empty():
		var cutscene_id: String = current_cutscene.get("id", "")
		end_cutscene(cutscene_id)
