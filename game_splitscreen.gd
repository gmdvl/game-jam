extends Game

var _game_over: bool = false

@onready var _hearts_p1: Hearts = $InterfaceLayer/HeartsP1
@onready var _hearts_p2: Hearts = $InterfaceLayer/HeartsP2
@onready var _game_over_screen: GameOver = $InterfaceLayer/GameOver


func _ready() -> void:
	GameState.mode = GameState.Mode.SPLIT
	var player_1 := %Player1 as Player
	var player_2 := %Player2 as Player
	var viewport_1 := %Viewport1 as SubViewport
	var viewport_2 := %Viewport2 as SubViewport
	viewport_2.world_2d = viewport_1.world_2d
	player_2.camera.custom_viewport = viewport_2
	player_2.camera.make_current()

	player_1.health_changed.connect(_hearts_p1.set_health)
	player_2.health_changed.connect(_hearts_p2.set_health)
	player_1.died.connect(_on_player_died)
	player_2.died.connect(_on_player_died)


func _on_player_died() -> void:
	if _game_over:
		return
	_game_over = true
	_game_over_screen.show_game_over()
