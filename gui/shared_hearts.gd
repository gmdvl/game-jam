class_name SharedHearts
extends HBoxContainer

const FULL: String = "❤"
const EMPTY: String = "♡"

var _labels: Array[Label] = []

func _ready() -> void:
	for i in 5:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.text = FULL
		add_child(lbl)
		_labels.append(lbl)

func set_health(new_health: int) -> void:
	for i in _labels.size():
		_labels[i].text = FULL if i < new_health else EMPTY
