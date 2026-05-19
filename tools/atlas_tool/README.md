# atlas_tool

Three helpers for authoring `res/atlases/*.json`:

- `overlay` — burn red grid lines + `(col,row)` labels onto a tilesheet PNG so you can read coordinates by eye.
- `preview` — render a labeled montage of every named sprite in an atlas JSON, to verify each key resolves to the cell you expect.
- `name` — serves a local web page: click a cell in your browser, type a name, save to the atlas JSON.

## Requires

Python 3.9+ and [Pillow](https://pillow.readthedocs.io/).

The script declares Pillow as a PEP-723 dependency, so [`uv`](https://docs.astral.sh/uv/) handles the setup automatically — nothing to install. If you'd rather use system Python, `pip install --user Pillow` works too.

The `name` subcommand uses an embedded HTTP server + your default web browser — no Tkinter, no native GUI deps.

## Usage

Replace `uv run` with `python3` if you're not using uv.

```bash
# Grid overlay (default tile size 64; output beside source as *.labeled.png).
uv run tools/atlas_tool/atlas_tool.py overlay \
  res/sprites/sprites_terrain.png

# haxecraft uses 8×8 pixel-art sheets — labels won't fit at native resolution,
# so upscale with --scale (nearest-neighbor) before drawing the labels.
uv run tools/atlas_tool/atlas_tool.py overlay \
  res/sprites/sprites_terrain.png --tile-size 8 --scale 8

# Custom output path:
uv run tools/atlas_tool/atlas_tool.py overlay \
  some_image.png --output /tmp/labeled.png

# Preview every named sprite in an atlas JSON.
uv run tools/atlas_tool/atlas_tool.py preview res/atlases/terrain.json
# Writes res/atlases/terrain.preview.png with each sprite labeled.

# Interactive sprite naming (browser-based):
uv run tools/atlas_tool/atlas_tool.py name \
  res/sprites/sprites_terrain.png \
  res/atlases/terrain.json
```

## haxecraft note

haxecraft currently registers sprites via
`client/src/client/render/SpriteCatalog.hx` (Haxe constants feeding
`SpriteRegistry`), not via the JSON manifests that `preview` and `name`
operate on. The `overlay` subcommand is the immediately useful one — run it on
a sprite sheet to read off `(col, row)` coordinates while editing the catalog.

`preview` and `name` become useful if/when haxecraft switches to JSON-driven
atlases via `AtlasLoader.loadManifest` (the code path exists but isn't wired
in). Authoring an atlas JSON for one sheet then running `preview` is a quick
way to validate it before flipping registration to `AtlasLoader`.

## `name` behavior

Running the command starts a tiny HTTP server on `127.0.0.1:8765` (override with `--port N`) and opens your browser to it. The server holds the atlas open and persists every save/delete to disk immediately.

- The tilesheet displays on the left with a red grid and `(col,row)` labels per cell. Existing named cells get a green outline; the currently selected cell gets a yellow outline.
- Click a cell to select. Existing names at that cell (if any) appear in the sidebar; the first pre-fills the entry.
- Type a sprite name and press Enter (or click "Save"). The atlas JSON is rewritten immediately, with sprite entries kept on one line.
- Right-click a cell (or click "Delete at cell") removes all named sprites pointing there.
- Click a name in the right-pane list to jump to its cell.
- Stop the server with Ctrl-C in the terminal that started it.

The tool auto-detects which atlas sheet to write into based on the PNG you opened (first sheet whose atlas entry references that image). Use `--sheet <name>` to override if your atlas has multiple sheets backed by the same image. Use `--no-open` to skip the auto-browser-open (useful in headless or scripted contexts).

## How `preview` resolves image paths

Atlas JSON image paths are relative to the project's `res/` directory (where `hxd.Res` looks). The tool assumes the atlas JSON lives at `res/atlases/<name>.json` and resolves `image` paths against `res/`. If your atlas lives elsewhere, the tool will not find its images.

## Limitations

- Only renders sprites with `col`/`row` (or `frames`, in which case the first frame is shown). Composites and palette-tinted entries are skipped.
- Doesn't validate the atlas JSON beyond what's needed to render. A separate validator would be a small follow-up.
