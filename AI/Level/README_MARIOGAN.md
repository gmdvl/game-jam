# MarioGAN Level Generator — Setup Guide

## Overview

When the player defeats all enemies in a level, Godot fires an HTTP request
to the local MarioGAN Python server. The server generates a fresh 14×28 tile
layout and returns it as JSON. Godot parses the response, places tiles via
`TileMapLayer.set_cell()`, and spawns enemies/coins as scene instances.

```
Godot (level.gd)
  └─ all enemies dead
       └─ change_scene_to → generated_level.tscn
            └─ generated_level.gd _ready()
                 └─ HTTPRequest → http://localhost:5000/generate/<seed>
                      └─ Python marioGAN_server.py
                           ├─ DCGAN model (if PyTorch installed)
                           └─ Procedural fallback (always available)
```

---

## Quick Start

### 1 — Install Python dependencies

```bash
cd game-jam/
pip install flask numpy
# Optional: enables the neural GAN mode
# pip install torch
```

### 2 — Run the server

```bash
python marioGAN_server.py
# → http://localhost:5000
```

### 3 — Open the Godot project

Open `game-jam/project.godot` in Godot 4.  
Play the game, defeat all enemies → Godot contacts the server and loads a
procedurally/GAN-generated level.

---

## API Reference

| Endpoint              | Description                              |
|-----------------------|------------------------------------------|
| `GET /generate`       | Random level (seed = current timestamp)  |
| `GET /generate/<int>` | Deterministic level from integer seed    |
| `GET /health`         | Server status + active model name        |

### Response format

```json
{
  "level": [
    ["-", "-", "X", "E", ...],   // row 0  (top)
    ...
    ["X", "X", "X", "X", ...]    // row 13 (bottom)
  ],
  "width":  28,
  "height": 14,
  "source": "procedural",
  "seed":   42,
  "tile_key": {
    "-": "air",
    "X": "solid_block",
    "S": "used_block",
    "?": "question_block_coin",
    "Q": "question_block_empty",
    "E": "enemy_spawn",
    "o": "coin",
    "<": "pipe_top_left",
    ">": "pipe_top_right",
    "|": "pipe_body"
  }
}
```

---

## Neural GAN Mode (optional)

The server ships with a full **DCGAN architecture** matching the MarioGAN
paper (Volz et al. 2018):

- Latent space: 32-dimensional standard normal
- Generator: 5 transposed-conv layers → (10, 14, 28) log-softmax output
- 10 tile classes matching the MarioGAN dataset character set

To use pretrained weights, place `marioGAN_weights.pth` next to
`marioGAN_server.py`. The server will load them automatically.

Without weights or PyTorch, the server falls back to the procedural
generator seamlessly — the Godot side never knows the difference.

---

## File Map

```
game-jam/
├── marioGAN_server.py              ← Python server (run this)
├── requirements.txt
├── marioGAN_weights.pth            ← (optional) pretrained GAN weights
└── game-jam/                       ← Godot 4 project
    └── level/
        ├── level.gd                ← modified: redirects to generated_level
        ├── generated_level.gd      ← new: HTTP fetch + tile builder
        └── generated_level.tscn    ← new: scene loaded after every level
```
