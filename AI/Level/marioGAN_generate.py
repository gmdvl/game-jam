"""
marioGAN_generate.py
Usage: python marioGAN_generate.py <seed>
Outputs a single JSON object to stdout and exits.
Called directly by Godot via OS.execute() — no server needed.
"""

import sys
import json
import random
import os

# ── Level dimensions — single source of truth ────────────────────────────────
_cfg_path = os.path.join(os.path.dirname(__file__), "level_config.json")
with open(_cfg_path) as _f:
    _cfg = json.load(_f)
LEVEL_WIDTH  = int(_cfg["level_width"])
LEVEL_HEIGHT = int(_cfg["level_height"])
# ─────────────────────────────────────────────────────────────────────────────


def generate(seed):
    rng   = random.Random(seed)
    level = [["-"] * LEVEL_WIDTH for _ in range(LEVEL_HEIGHT)]
    GROUND     = LEVEL_HEIGHT - 2  # bottom solid row
    GROUND_TOP = LEVEL_HEIGHT - 3  # row just above ground (enemy/gap level)
    PIPE_MAX_H = max(2, LEVEL_HEIGHT // 6)  # pipe height scales with level
    PLAT_Y_MIN = max(3, LEVEL_HEIGHT // 5)  # floating platform min row
    PLAT_Y_MAX = GROUND - 3                 # floating platform max row

    # Ground rows 12-13
    for x in range(LEVEL_WIDTH):
        level[GROUND][x] = "X"
        level[GROUND + 1][x] = "X"

    # Ground gaps
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

    # Pipes
    pipe_cols = []
    x = 5
    while x < LEVEL_WIDTH - 6:
        if rng.random() < 0.22:
            pipe_h  = rng.randint(2, PIPE_MAX_H)
            top_row = GROUND - pipe_h
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

    # Floating platforms + coins above them
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

    # Question / brick blocks
    for _ in range(rng.randint(3, 7)):
        bx = rng.randint(2, LEVEL_WIDTH - 3)
        by = rng.randint(7, 10)
        if level[by][bx] == "-":
            level[by][bx] = rng.choice(["?", "?", "S"])

    # Enemies — guaranteed minimum 2
    candidates = [
        x for x in range(5, LEVEL_WIDTH - 3)
        if level[GROUND][x] == "X"
        and level[GROUND_TOP][x] == "-"
        and not any(abs(x - px) <= 2 for px in pipe_cols)
    ]
    rng.shuffle(candidates)
    spawned = []
    for ex in candidates:
        if rng.random() < 0.50 or len(spawned) < 2:
            level[GROUND_TOP][ex] = "E"
            spawned.append(ex)
        if len(spawned) >= 5:
            break

    if not spawned:
        fallback = [x for x in range(4, LEVEL_WIDTH - 3) if level[GROUND][x] == "X"]
        if len(fallback) >= 2:
            for ex in rng.sample(fallback, 2):
                level[GROUND_TOP][ex] = "E"

    # Loose coins
    for _ in range(rng.randint(3, 6)):
        cx = rng.randint(2, LEVEL_WIDTH - 3)
        cy = rng.randint(PLAT_Y_MIN + 1, GROUND - 1)
        if level[cy][cx] == "-":
            level[cy][cx] = "o"

    # Postprocess: only remove floating enemies, never touch ground
    for y in range(LEVEL_HEIGHT - 1):
        for x in range(LEVEL_WIDTH):
            if level[y][x] == "E":
                if level[y + 1][x] not in ("X", "S", "?", "Q", "|"):
                    level[y][x] = "-"

    return level


if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 42
    result = {
        "level":  generate(seed),
        "width":  LEVEL_WIDTH,
        "height": LEVEL_HEIGHT,
        "source": "procedural",
        "seed":   seed,
    }
    # Single compact JSON line to stdout — Godot reads this
    print(json.dumps(result, separators=(",", ":")))
