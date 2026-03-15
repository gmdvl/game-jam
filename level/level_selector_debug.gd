# level_select_debug.gd
extends Control

var levels: Array[String] = [
	"res://levels/level_1.tscn",
	"res://levels/level_2.tscn",
    "res://levels/level_3.tscn"
]

func _ready() -> void:
	for path in levels:
		var btn: Button = Button.new()
		btn.text = path.get_file()
		btn.pressed.connect(func() -> void: get_tree().change_scene_to_file(path))
		$VBoxContainer.add_child(btn)

# Function to call from other scripts to open the level selector
func open_level_selector() -> void:
	get_tree().change_scene_to_file("res://level/level_selector_debug.tscn")
