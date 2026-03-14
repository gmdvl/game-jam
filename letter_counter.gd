extends Label

const TARGET_WORD := "GIANT JAM"

var collected_letters: Array[String] = []

func _ready() -> void:
	update_display()

func collect_letter(letter: String) -> void:
	collected_letters.append(letter)
	update_display()

func update_display() -> void:
	var remaining := collected_letters.duplicate()
	var display := ""

	for char in TARGET_WORD:
		if char == " ":
			display += "  "
		elif char in remaining:
			display += char + " "
			remaining.erase(char)
		else:
			display += "_ "

	text = display.strip_edges()

func _on_player_letter_collected(letter: String) -> void:
	collect_letter(letter)
