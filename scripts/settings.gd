extends Control

@onready var tts_checkbox = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/TTSCheckbox
@onready var tts_label = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/TTSLabel

@onready var volume_slider = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/VolumeSlider
@onready var volume_label = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/VolumeLabel

@onready var font_slider = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/FontSlider
@onready var font_label = $CanvasLayer/ColorRect/PanelContainer/VBoxContainer/GridContainer/FontLabel

@onready var settings_menu = $CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	settings_menu.hide()
	tts_checkbox.button_pressed = GameState.tts_on
	volume_slider.value = GameState.background_volume
	font_slider.value = GameState.font_size


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_volume_slider_value_changed(value: int) -> void:
	volume_label.text = str(value)
	GameState.set_background_volume(value)


func _on_tts_checkbox_toggled(toggled_on: bool) -> void:
	tts_label.text = "Yes" if toggled_on else "No"
	GameState.toggle_tts(toggled_on)


func _on_font_slider_value_changed(value: int) -> void:
	font_label.text = str(value)


func _on_close_button_pressed() -> void:
	if settings_menu.visible:
		settings_menu.hide()


func _on_open_button_pressed() -> void:
	if not settings_menu.visible:
		settings_menu.show()
