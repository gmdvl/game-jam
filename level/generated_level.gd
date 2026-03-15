## generated_level.gd
## Calls the MarioGAN server via curl — OS.execute("curl") on a background thread.
## Start the server first: python marioGAN_server.py

extends Node2D

# ── Scene references ────────────────────────────────────────────────────────
@onready var tile_map:        TileMapLayer = $TileMapLayer
@onready var entities:        Node2D       = $Entities
@onready var timeout_timer:   Timer        = $TimeoutTimer
@onready var loading_overlay: CanvasLayer  = $LoadingOverlay
@onready var loading_label:   Label        = $LoadingOverlay/LoadingLabel
@onready var dot_timer:       Timer        = $LoadingOverlay/DotTimer
@onready var debug_label:     Label        = $LoadingOverlay/DebugLabel

# ── Preloaded scenes ────────────────────────────────────────────────────────
const ENEMY_SCENE = preload("res://enemy/enemy.tscn")
const COIN_SCENE  = preload("res://level/coin.tscn")

# ── MarioGAN server address ──────────────────────────────────────────────────
const GAN_HOST = "http://localhost:5000"

# ── Tileset source IDs ──────────────────────────────────────────────────────
const SRC_SOLID    = 0
const SRC_PIPE     = 6
const ATLAS_ORIGIN = Vector2i(0, 0)
const TILE_SIZE    = 64

# ── Level dimensions (defaults — overwritten by server response) ─────────────
var _level_width:  int = 60
var _level_height: int = 40

# ── Camera tuning ───────────────────────────────────────────────────────────
# Tiles visible vertically at default zoom — sets the "feel" of the camera.
# Increase for a more zoomed-out view, decrease for closer.
const TARGET_VISIBLE_TILES_Y: float = 10.0
const ZOOM_MIN: float = 0.25   # never zoom out further than this
const ZOOM_MAX: float = 1.0    # never zoom in further than this
const LEVEL_PADDING_TOP: int  = 1  # extra tile of headroom above the level
const LEVEL_PADDING_SIDE: int = 1  # extra tile on each horizontal side

# ── Internal ────────────────────────────────────────────────────────────────
var _dot_count: int  = 0
var _thread:    Thread

# ---------------------------------------------------------------------------
# INIT
# ---------------------------------------------------------------------------

func _ready() -> void:
	GameState.current_level_scene = "res://level/generated_level.tscn"
	dot_timer.timeout.connect(_on_dot_timer)
	timeout_timer.timeout.connect(_on_timeout)
	timeout_timer.start()
	_log("Spawning Python generator…")
	# Run OS.execute on a thread so the game loop never blocks
	_thread = Thread.new()
	_thread.start(_run_python)


func _run_python() -> void:
	# Reuse stored seed when switching modes; generate fresh when advancing
	var seed_val: int = GameState.current_seed if GameState.current_seed >= 0 else randi() % 100000
	GameState.current_seed = seed_val  # store so mode-switch can reload same level
	var url: String   = GAN_HOST + "/generate/" + str(seed_val)
	var output: Array = []

	_log("curl " + url)

	var exit_code: int = OS.execute(
		"curl",
		["-s", "--max-time", "7", url],
		output,
		true
	)

	call_deferred("_on_python_done", exit_code, output, seed_val)


func _on_python_done(exit_code: int, output: Array, seed_val: int) -> void:
	timeout_timer.stop()

	if _thread and _thread.is_started():
		_thread.wait_to_finish()

	_log("curl exited with code %d" % exit_code)

	if exit_code != 0 or output.is_empty():
		_log("ERROR: curl failed (code=%d) — is the server running?" % exit_code)
		_build_fallback_level()
		return

	# curl stdout captured in output
	var raw: String   = "\n".join(output).strip_edges()
	var json          = JSON.new()
	var parse_err     = json.parse(raw)

	if parse_err != OK:
		_log("ERROR: JSON parse failed — raw: " + raw.substr(0, 100))
		_build_fallback_level()
		return

	var data: Dictionary = json.get_data()
	_log("OK — seed=%d enemies visible in map" % seed_val)
	_build_level(data)


# ---------------------------------------------------------------------------
# TIMEOUT (fallback if Python is missing or hangs)
# ---------------------------------------------------------------------------

func _on_timeout() -> void:
	_log("TIMEOUT — Python took too long, using fallback")
	if _thread and _thread.is_started():
		# Can't kill the thread, but fallback renders immediately
		pass
	_build_fallback_level()


# ---------------------------------------------------------------------------
# LOADING ANIMATION
# ---------------------------------------------------------------------------

func _on_dot_timer() -> void:
	_dot_count = (_dot_count + 1) % 4
	if loading_label:
		loading_label.text = "Generating level" + ".".repeat(_dot_count)


func _hide_overlay() -> void:
	if dot_timer:
		dot_timer.stop()
	if loading_overlay:
		loading_overlay.visible = false


# ---------------------------------------------------------------------------
# LEVEL BUILDER
# ---------------------------------------------------------------------------

func _build_level(data: Dictionary) -> void:
	_level_width  = int(data.get("width",  28))
	_level_height = int(data.get("height", 14))
	var grid: Array = data.get("level", [])

	if grid.is_empty():
		_log("ERROR: empty grid")
		_build_fallback_level()
		return

	tile_map.clear()

	for row in range(_level_height):
		for col in range(_level_width):
			var ch: String = grid[row][col] \
					if row < grid.size() and col < grid[row].size() else "-"
			_place_tile(col, row, ch)

	_log("Level built %dx%d" % [_level_width, _level_height])
	_set_camera_limits()
	_reposition_player()
	_hide_overlay()


func _place_tile(col: int, row: int, ch: String) -> void:
	var cell := Vector2i(col, row)
	match ch:
		"X", "S":
			tile_map.set_cell(cell, SRC_SOLID, ATLAS_ORIGIN)
		"?", "Q":
			tile_map.set_cell(cell, SRC_SOLID, ATLAS_ORIGIN, 7)
		"<", ">", "|":
			tile_map.set_cell(cell, SRC_PIPE, ATLAS_ORIGIN)
		"E":
			_spawn_enemy(col, row)
		"o":
			_spawn_coin(col, row)


# ---------------------------------------------------------------------------
# ENTITY SPAWNERS
# ---------------------------------------------------------------------------

func _spawn_enemy(col: int, row: int) -> void:
	var enemy: Node = ENEMY_SCENE.instantiate()
	enemy.position  = Vector2(col * TILE_SIZE + TILE_SIZE * 0.5,
	                          row * TILE_SIZE + TILE_SIZE * 0.5)
	entities.add_child(enemy)
	if enemy.has_signal("enemy_died"):
		enemy.enemy_died.connect(_on_enemy_died)


func _spawn_coin(col: int, row: int) -> void:
	var coin: Node = COIN_SCENE.instantiate()
	coin.position  = Vector2(col * TILE_SIZE + TILE_SIZE * 0.5,
	                         row * TILE_SIZE + TILE_SIZE * 0.5)
	entities.add_child(coin)


# ---------------------------------------------------------------------------
# NEXT-LEVEL LOGIC
# ---------------------------------------------------------------------------

func _on_enemy_died() -> void:
	await get_tree().process_frame
	var remaining: int = get_tree().get_nodes_in_group("enemies").size()
	_log("Enemy died — %d remaining" % remaining)
	if remaining == 0:
		_go_to_next_level()


func _go_to_next_level() -> void:
	_log("All enemies defeated — loading next generated level")
	GameState.go_to_next_generated_level()


# ---------------------------------------------------------------------------
# CAMERA / PLAYER HELPERS
# ---------------------------------------------------------------------------

func _set_camera_limits() -> void:
	# Pixel dimensions of the full level
	var px_w: int = _level_width  * TILE_SIZE
	var px_h: int = _level_height * TILE_SIZE

	# Camera bounds — add padding so the player isn't flush against the edge
	var lim_left:   int = -LEVEL_PADDING_SIDE * TILE_SIZE
	var lim_right:  int = px_w + LEVEL_PADDING_SIDE * TILE_SIZE
	var lim_top:    int = -LEVEL_PADDING_TOP * TILE_SIZE
	var lim_bottom: int = px_h + TILE_SIZE   # one tile below the floor

	# Zoom: scale so TARGET_VISIBLE_TILES_Y tiles fit in the viewport height.
	# get_viewport().size is in physical pixels; divide by stretch scale to get
	# the logical viewport size the Camera2D works in.
	var vp_size: Vector2   = get_viewport().get_visible_rect().size
	var zoom_h: float      = vp_size.y / (TARGET_VISIBLE_TILES_Y * TILE_SIZE)
	var zoom_clamped: float = clampf(zoom_h, ZOOM_MIN, ZOOM_MAX)
	var zoom_vec: Vector2  = Vector2(zoom_clamped, zoom_clamped)

	for player in get_tree().get_nodes_in_group("players"):
		var cam: Camera2D = player.get_node_or_null(^"Camera")
		if cam:
			cam.limit_left   = lim_left
			cam.limit_top    = lim_top
			cam.limit_right  = lim_right
			cam.limit_bottom = lim_bottom
			cam.zoom         = zoom_vec

	_log("Camera: limits=(%d,%d,%d,%d) zoom=%.3f for level %dx%d tiles" % [
		lim_left, lim_top, lim_right, lim_bottom,
		zoom_clamped, _level_width, _level_height])


func _reposition_player() -> void:
	var start_row: int = _level_height - 3
	var base_y: float  = start_row * TILE_SIZE
	var idx: int       = 0
	for player in get_tree().get_nodes_in_group("players"):
		# Offset each player slightly so they don't stack on top of each other
		var spawn := Vector2(TILE_SIZE * 1.5 + idx * TILE_SIZE, base_y)
		player.position        = spawn
		player._spawn_position = spawn
		idx += 1


# ---------------------------------------------------------------------------
# FALLBACK LEVEL
# ---------------------------------------------------------------------------

func _build_fallback_level() -> void:
	_log("Building procedural fallback level")
	var fallback_grid: Array = []
	var ground_row: int = _level_height - 2
	var enemy_col_a: int = _level_width / 4
	var enemy_col_b: int = (_level_width * 3) / 4
	var qblock_col: int  = _level_width / 2
	for row in range(_level_height):
		var line: Array = []
		for col in range(_level_width):
			if row >= ground_row:
				line.append("X")
			elif row == ground_row - 1 and col == enemy_col_a:
				line.append("E")
			elif row == ground_row - 1 and col == enemy_col_b:
				line.append("E")
			elif row == ground_row - 4 and col == qblock_col:
				line.append("?")
			else:
				line.append("-")
		fallback_grid.append(line)
	_build_level({"level": fallback_grid, "width": _level_width, "height": _level_height})
	_hide_overlay()


# ---------------------------------------------------------------------------
# LOGGING
# ---------------------------------------------------------------------------

func _log(msg: String) -> void:
	print("[MarioGAN] ", msg)
	if debug_label:
		debug_label.text = msg
