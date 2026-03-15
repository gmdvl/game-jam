"""
MarioGAN Server
===============
Flask server — procedural generator with seeded variety.
Endpoints:
  GET /generate          -> random level (time-based seed)
  GET /generate/<seed>   -> deterministic level from integer seed
  GET /health            -> server status
"""

from flask import Flask, jsonify
import random
import time
import json
import os

app = Flask(__name__)

# ── Level dimensions — single source of truth ────────────────────────────────
_cfg_path = os.path.join(os.path.dirname(__file__), "level_config.json")
with open(_cfg_path) as _f:
    _cfg = json.load(_f)
LEVEL_WIDTH  = int(_cfg["level_width"])
LEVEL_HEIGHT = int(_cfg["level_height"])
# ─────────────────────────────────────────────────────────────────────────────

TILE_CHARS   = ["-", "X", "S", "?", "Q", "E", "o", "<", ">", "|"]

# ---------------------------------------------------------------------------
# PROCEDURAL GENERATOR
# ---------------------------------------------------------------------------

def _generate_procedural(seed):
    rng   = random.Random(seed)
    level = [["-"] * LEVEL_WIDTH for _ in range(LEVEL_HEIGHT)]
    GROUND     = LEVEL_HEIGHT - 2  # bottom solid row
    GROUND_TOP = LEVEL_HEIGHT - 3  # row just above ground (enemy/gap level)
    PIPE_MAX_H = max(2, LEVEL_HEIGHT // 6)  # pipe height scales with level
    PLAT_Y_MIN = max(3, LEVEL_HEIGHT // 5)  # floating platform min row
    PLAT_Y_MAX = GROUND - 3                 # floating platform max row

    # ── Solid ground on rows 12-13 ──────────────────────────────────────────
    for x in range(LEVEL_WIDTH):
        level[GROUND][x] = "X"
        level[GROUND + 1][x] = "X"

    # ── Ground gaps (created BEFORE postprocess so they are preserved) ──────
    # Leave first 4 and last 3 cols always solid as safe zones
    x = 4
    while x < LEVEL_WIDTH - 5:
        if rng.random() < 0.22:
            gap_len = rng.randint(2, 3)
            for gx in range(gap_len):
                cx = x + gx
                if 4 <= cx < LEVEL_WIDTH - 3:
                    level[GROUND][cx] = "-"
                    level[GROUND + 1][cx] = "-"
            x += gap_len + rng.randint(4, 6)
        else:
            x += 1

    # ── Pipes ───────────────────────────────────────────────────────────────
    pipe_cols = []
    x = 5
    while x < LEVEL_WIDTH - 6:
        if rng.random() < 0.22:
            pipe_h  = rng.randint(2, PIPE_MAX_H)
            top_row = GROUND - pipe_h
            # Only place on solid ground and with room for both cols
            if level[GROUND][x] == "X" and level[GROUND][x + 1] == "X":
                level[top_row][x]     = "<"
                level[top_row][x + 1] = ">"
                for py in range(top_row + 1, GROUND):
                    level[py][x]     = "|"
                    level[py][x + 1] = "|"
                pipe_cols.append(x)
                x += 5
            else:
                x += 1
        else:
            x += 1

    # ── Floating platforms ──────────────────────────────────────────────────
    x = 2
    while x < LEVEL_WIDTH - 4:
        if rng.random() < 0.30:
            plat_len = rng.randint(2, 5)
            plat_y   = rng.randint(PLAT_Y_MIN, PLAT_Y_MAX)
            placed   = 0
            for px in range(plat_len):
                cx = x + px
                if cx < LEVEL_WIDTH and level[plat_y][cx] == "-":
                    level[plat_y][cx] = "X"
                    placed += 1
            # Coins above platform
            if placed > 0 and rng.random() < 0.6:
                coin_count = rng.randint(1, min(placed, 3))
                coin_start = x + rng.randint(0, max(0, placed - coin_count))
                for ci in range(coin_count):
                    ccx = coin_start + ci
                    if ccx < LEVEL_WIDTH and level[plat_y - 1][ccx] == "-":
                        level[plat_y - 1][ccx] = "o"
            x += plat_len + rng.randint(1, 3)
        else:
            x += 1

    # ── Question / brick blocks ─────────────────────────────────────────────
    for _ in range(rng.randint(3, 7)):
        bx = rng.randint(2, LEVEL_WIDTH - 3)
        by = rng.randint(7, 10)
        if level[by][bx] == "-":
            level[by][bx] = rng.choice(["?", "?", "S"])

    # ── Enemies — GUARANTEED at least 2 ────────────────────────────────────
    enemy_candidates = [
        x for x in range(5, LEVEL_WIDTH - 3)
        if level[GROUND][x] == "X"
        and level[GROUND_TOP][x] == "-"
        and not any(abs(x - px) <= 2 for px in pipe_cols)
    ]

    # Shuffle and pick enemies: 50% chance per candidate, minimum 2
    rng.shuffle(enemy_candidates)
    spawned = []
    for ex in enemy_candidates:
        if rng.random() < 0.50 or len(spawned) < 2:
            level[GROUND_TOP][ex] = "E"
            spawned.append(ex)
        if len(spawned) >= 5:   # cap at 5 enemies
            break

    # If no valid candidates at all, force 2 enemies on solid ground
    if len(spawned) == 0:
        fallback_xs = [x for x in range(4, LEVEL_WIDTH - 3) if level[GROUND][x] == "X"]
        if len(fallback_xs) >= 2:
            for ex in rng.sample(fallback_xs, 2):
                level[GROUND_TOP][ex] = "E"

    # ── Loose coins ─────────────────────────────────────────────────────────
    for _ in range(rng.randint(3, 6)):
        cx = rng.randint(2, LEVEL_WIDTH - 3)
        cy = rng.randint(PLAT_Y_MIN + 1, GROUND - 1)
        if level[cy][cx] == "-":
            level[cy][cx] = "o"

    # ── Postprocess: only fix enemy placement, NEVER touch ground rows ──────
    for y in range(LEVEL_HEIGHT - 1):
        for x in range(LEVEL_WIDTH):
            if level[y][x] == "E":
                below = level[y + 1][x]
                if below not in ("X", "S", "?", "Q", "|"):
                    level[y][x] = "-"

    print(f"[GEN] seed={seed} enemies={[c for c in range(LEVEL_WIDTH) if level[GROUND_TOP][c]=='E']} "
          f"gaps={[c for c in range(LEVEL_WIDTH) if level[GROUND][c]=='-']} "
          f"pipes={pipe_cols}")

    return level


def generate_level(seed):
    grid = _generate_procedural(seed)
    return {
        "level":  grid,
        "width":  LEVEL_WIDTH,
        "height": LEVEL_HEIGHT,
        "source": "procedural",
        "seed":   seed,
        "tile_key": {
            "-": "air",        "X": "solid_block",
            "S": "used_block", "?": "question_block_coin",
            "Q": "question_block_empty", "E": "enemy_spawn",
            "o": "coin",       "<": "pipe_top_left",
            ">": "pipe_top_right", "|": "pipe_body",
        }
    }


# ---------------------------------------------------------------------------
# FLASK ROUTES
# ---------------------------------------------------------------------------

@app.after_request
def add_cors(response):
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route("/generate", methods=["GET"])
def route_generate():
    seed = int(time.time() * 1000) % (2 ** 31)
    return jsonify(generate_level(seed))


@app.route("/generate/<int:seed>", methods=["GET"])
def route_generate_seed(seed):
    return jsonify(generate_level(seed))


@app.route("/health", methods=["GET"])
def route_health():
    return jsonify({"status": "ok", "model": "procedural",
                    "output_size": f"{LEVEL_HEIGHT}x{LEVEL_WIDTH}"})


# ---------------------------------------------------------------------------

if __name__ == "__main__":
    print("=" * 50)
    print("  MarioGAN Server — procedural mode")
    print("  GET /generate/<seed>")
    print("  GET /health")
    print("=" * 50)
    app.run(host="0.0.0.0", port=5000, debug=False)
