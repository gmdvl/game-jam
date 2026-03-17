extends Control

@onready var start_button := $CenterContainer/VBoxContainer/StartButton as Button

func _ready() -> void:
	start_button.grab_focus()

func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://game_singleplayer.tscn")
