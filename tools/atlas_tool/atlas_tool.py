#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "Pillow>=10",
# ]
# ///
"""Atlas builder helpers.

Two subcommands:

    overlay  Burn grid lines + (col,row) labels onto a tilesheet PNG so you
             can read coordinates by eye.
    preview  Render a labeled montage from an atlas JSON so you can verify
             that each named sprite key resolves to the cell you expect.

Both write a sibling output file (default suffix `.labeled.png` or
`.preview.png`) unless `--output` is given.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    sys.stderr.write(
        "PIL/Pillow is required. Install with: pip install --user Pillow\n"
    )
    sys.exit(1)


DEFAULT_TILE = 64
DEFAULT_PORT = 8765
GRID_COLOR = (255, 64, 64, 220)
LABEL_FILL = (255, 255, 255, 255)
LABEL_OUTLINE = (0, 0, 0, 255)
MONTAGE_BG = (32, 32, 40, 255)
MONTAGE_LABEL = (240, 240, 240, 255)
PER_ROW = 6   # sprites per row in preview montage


# Server-rendered HTML for the `name` subcommand. The two `/*__…__*/null`
# tokens get replaced at request time with JSON-serialized config + sprites,
# so the page is self-contained — no follow-up fetch needed on first load.
_HTML_TEMPLATE = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>atlas namer</title>
<style>
  :root {
    --bg: #1c1c22;
    --panel: #26262e;
    --text: #e6e6ea;
    --muted: #9aa0a8;
    --grid: rgba(255, 64, 64, 0.75);
    --named: #40c060;
    --selected: #ffd040;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font: 13px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    display: flex;
    height: 100vh;
    overflow: hidden;
  }
  #canvas-wrap {
    flex: 1;
    overflow: auto;
    padding: 16px;
  }
  #sheet {
    position: relative;
    display: inline-block;
    line-height: 0;
    box-shadow: 0 0 0 1px #000;
  }
  #sheet img {
    display: block;
    image-rendering: pixelated;
  }
  #cells {
    position: absolute;
    inset: 0;
  }
  .cell {
    position: absolute;
    border: 1px solid var(--grid);
    cursor: pointer;
  }
  .cell .label {
    position: absolute;
    top: 1px;
    left: 2px;
    font: bold 9px/1 monospace;
    color: #fff;
    text-shadow:
      -1px -1px 0 #000, 1px -1px 0 #000,
      -1px  1px 0 #000, 1px  1px 0 #000;
    pointer-events: none;
  }
  .cell.named { border: 2px solid var(--named); }
  .cell.selected { border: 3px solid var(--selected); z-index: 2; }
  .cell.named.selected { border: 3px solid var(--selected); }

  #sidebar {
    width: 320px;
    background: var(--panel);
    padding: 14px 16px;
    overflow-y: auto;
    border-left: 1px solid #000;
  }
  #sidebar h2 {
    margin: 0 0 12px 0;
    font-size: 14px;
    font-weight: 600;
  }
  .meta { color: var(--muted); font-size: 11px; margin-bottom: 4px; }
  .meta strong { color: var(--text); }
  #selected-info {
    margin: 16px 0 6px 0;
    font-weight: 600;
  }
  #existing-info {
    color: var(--muted);
    font-size: 12px;
    margin-bottom: 8px;
    min-height: 1.4em;
  }
  input[type=text] {
    width: 100%;
    padding: 8px 10px;
    background: #16161c;
    color: var(--text);
    border: 1px solid #444;
    border-radius: 4px;
    font: inherit;
  }
  input[type=text]:focus {
    outline: none;
    border-color: var(--selected);
  }
  .btn-row { display: flex; gap: 6px; margin-top: 8px; }
  button {
    padding: 7px 11px;
    background: #2f3038;
    color: var(--text);
    border: 1px solid #3a3b44;
    border-radius: 4px;
    font: inherit;
    cursor: pointer;
  }
  button:hover { background: #3a3b44; }
  button.primary { background: #2d5fa3; border-color: #3a72bd; }
  button.primary:hover { background: #3a72bd; }
  button.danger { background: #883b3b; border-color: #a04848; }
  button.danger:hover { background: #a04848; }
  hr { border: none; border-top: 1px solid #3a3b44; margin: 14px 0; }
  #names-list { max-height: calc(100vh - 460px); overflow-y: auto; }
  .name-row {
    padding: 6px 8px;
    cursor: pointer;
    border-radius: 3px;
    display: flex;
    justify-content: space-between;
    font-size: 12px;
  }
  .name-row:hover { background: #34353f; }
  .name-row .coord { color: var(--muted); }
  .name-row.active { background: #3a4555; }
  .hint { color: var(--muted); font-size: 11px; margin-top: 6px; }
</style>
</head>
<body>
  <div id="canvas-wrap">
    <div id="sheet">
      <img src="/image" id="bg">
      <div id="cells"></div>
    </div>
  </div>
  <div id="sidebar">
    <h2>atlas namer</h2>
    <div class="meta">sheet: <strong id="meta-sheet"></strong></div>
    <div class="meta">atlas: <strong id="meta-atlas"></strong></div>
    <div class="meta">png:   <strong id="meta-png"></strong></div>
    <div class="meta">tile:  <strong id="meta-tile"></strong></div>

    <div id="selected-info">no cell selected</div>
    <div id="existing-info"></div>

    <input type="text" id="name-input" placeholder="sprite name (e.g. TS_GRASS_C)" autocomplete="off">
    <div class="btn-row">
      <button id="save-btn" class="primary">Save (Enter)</button>
      <button id="delete-btn" class="danger">Delete at cell</button>
    </div>
    <div class="hint">Right-click a cell to clear its names. Click a list entry to jump to it.</div>

    <hr>
    <h2>named in this sheet</h2>
    <div id="names-list"></div>
  </div>

<script>
"use strict";
const CONFIG = /*__CONFIG__*/null;
let sprites = /*__SPRITES__*/null;
let selected = null;  // {col, row} or null

function namesAt(sheet, col, row) {
  return Object.entries(sprites)
    .filter(([, s]) => s.sheet === sheet && s.col === col && s.row === row)
    .map(([n]) => n);
}

function renderMeta() {
  document.getElementById("meta-sheet").textContent = CONFIG.sheetName;
  document.getElementById("meta-atlas").textContent = CONFIG.atlasName;
  document.getElementById("meta-png").textContent   = CONFIG.pngName;
  document.getElementById("meta-tile").textContent  =
    `${CONFIG.tile}px (${CONFIG.cols}×${CONFIG.rows})`;
  document.getElementById("sheet").style.width  = CONFIG.imageW + "px";
  document.getElementById("sheet").style.height = CONFIG.imageH + "px";
}

function renderGrid() {
  const wrap = document.getElementById("cells");
  wrap.innerHTML = "";
  for (let r = 0; r < CONFIG.rows; r++) {
    for (let c = 0; c < CONFIG.cols; c++) {
      const cell = document.createElement("div");
      cell.className = "cell";
      cell.style.left   = c * CONFIG.tile + "px";
      cell.style.top    = r * CONFIG.tile + "px";
      cell.style.width  = CONFIG.tile + "px";
      cell.style.height = CONFIG.tile + "px";
      cell.dataset.col = c;
      cell.dataset.row = r;
      const label = document.createElement("span");
      label.className = "label";
      label.textContent = `${c},${r}`;
      cell.appendChild(label);
      if (namesAt(CONFIG.sheetName, c, r).length) cell.classList.add("named");
      if (selected && selected.col === c && selected.row === r) cell.classList.add("selected");
      cell.addEventListener("click",       () => selectCell(c, r));
      cell.addEventListener("contextmenu", (e) => { e.preventDefault(); deleteCell(c, r); });
      wrap.appendChild(cell);
    }
  }
}

function renderNamesList() {
  const list = document.getElementById("names-list");
  list.innerHTML = "";
  const entries = Object.entries(sprites)
    .filter(([, s]) => s.sheet === CONFIG.sheetName && "col" in s && "row" in s)
    .sort((a, b) => a[1].row - b[1].row || a[1].col - b[1].col);
  for (const [name, s] of entries) {
    const row = document.createElement("div");
    row.className = "name-row";
    if (selected && selected.col === s.col && selected.row === s.row) row.classList.add("active");
    const n = document.createElement("span");
    n.textContent = name;
    const coord = document.createElement("span");
    coord.className = "coord";
    coord.textContent = `(${s.col}, ${s.row})`;
    row.appendChild(n);
    row.appendChild(coord);
    row.addEventListener("click", () => selectCell(s.col, s.row));
    list.appendChild(row);
  }
}

function renderSelection() {
  if (!selected) {
    document.getElementById("selected-info").textContent = "no cell selected";
    document.getElementById("existing-info").textContent = "";
    return;
  }
  document.getElementById("selected-info").textContent =
    `selected: (${selected.col}, ${selected.row})`;
  const existing = namesAt(CONFIG.sheetName, selected.col, selected.row);
  document.getElementById("existing-info").textContent =
    existing.length ? `existing: ${existing.join(", ")}` : "(no name yet)";
  const input = document.getElementById("name-input");
  input.value = existing[0] || "";
  input.focus();
  input.select();
}

function selectCell(c, r) {
  selected = { col: c, row: r };
  renderGrid();
  renderNamesList();
  renderSelection();
}

async function save() {
  if (!selected) return;
  const name = document.getElementById("name-input").value.trim();
  if (!name) return;
  const r = await fetch("/sprite/save", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name, sheet: CONFIG.sheetName, col: selected.col, row: selected.row }),
  });
  if (!r.ok) { alert("save failed: " + await r.text()); return; }
  sprites = await r.json();
  renderGrid();
  renderNamesList();
  renderSelection();
}

async function deleteCell(col, row) {
  const r = await fetch("/sprite/delete", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ sheet: CONFIG.sheetName, col, row }),
  });
  if (!r.ok) { alert("delete failed: " + await r.text()); return; }
  sprites = await r.json();
  renderGrid();
  renderNamesList();
  renderSelection();
}

document.getElementById("save-btn").addEventListener("click", save);
document.getElementById("delete-btn").addEventListener("click", () => {
  if (selected) deleteCell(selected.col, selected.row);
});
document.getElementById("name-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") save();
});

renderMeta();
renderGrid();
renderNamesList();
</script>
</body>
</html>
"""


# ---------- overlay ----------------------------------------------------------

def cmd_overlay(args: argparse.Namespace) -> int:
    src = Image.open(args.png).convert("RGBA")
    tile = args.tile_size
    if src.width % tile or src.height % tile:
        print(
            f"warning: {args.png} ({src.width}x{src.height}) not divisible by {tile}",
            file=sys.stderr,
        )
    cols = src.width // tile
    rows = src.height // tile
    # Nearest-neighbor upscale so labels remain legible on small (pixel-art)
    # tiles. The visible tile size is `tile * scale`; cols/rows are unchanged.
    scale = max(1, args.scale)
    if scale > 1:
        src = src.resize(
            (src.width * scale, src.height * scale), Image.Resampling.NEAREST
        )
        tile *= scale
    out = src.copy()
    draw = ImageDraw.Draw(out)
    font = _load_font(max(10, tile // 6))

    # Grid lines.
    for c in range(cols + 1):
        x = c * tile
        draw.line([(x, 0), (x, src.height)], fill=GRID_COLOR, width=1)
    for r in range(rows + 1):
        y = r * tile
        draw.line([(0, y), (src.width, y)], fill=GRID_COLOR, width=1)

    # (col, row) label in each cell's top-left, outlined for legibility.
    for c in range(cols):
        for r in range(rows):
            _draw_outlined(draw, c * tile + 2, r * tile + 2, f"{c},{r}", font)

    out_path = args.output or _add_suffix(args.png, ".labeled.png")
    out.save(out_path)
    print(f"wrote {out_path}  ({cols}×{rows} cells of {tile}px)")
    return 0


# ---------- preview ----------------------------------------------------------
# When invoked on haxecraft sheets, use --tile-size 8 --scale 8 (or higher).

def cmd_preview(args: argparse.Namespace) -> int:
    atlas_path = Path(args.atlas)
    if not atlas_path.is_file():
        sys.stderr.write(f"atlas not found: {atlas_path}\n")
        return 1
    data = json.loads(atlas_path.read_text())

    # Atlas image paths in the JSON are relative to the project's `res/`
    # directory (because `hxd.Res.load` resolves there). The atlas JSON itself
    # lives at `res/atlases/<name>.json`, so go up one level.
    res_root = atlas_path.parent.parent

    sheets: dict[str, tuple[Image.Image, int, int, int, int]] = {}
    for atlas in data.get("atlases", []):
        img_path = res_root / atlas["image"]
        if not img_path.is_file():
            sys.stderr.write(f"missing image: {img_path}\n")
            return 1
        img = Image.open(img_path).convert("RGBA")
        for s in atlas["sheets"]:
            sheets[s["name"]] = (
                img,
                s["spriteW"],
                s["spriteH"],
                s.get("x", 0),
                s.get("y", 0),
            )

    sprites = []
    for name, entry in (data.get("sprites") or {}).items():
        if "frames" in entry:
            # Animation: show first frame.
            col, row = entry["frames"][0]
        elif "col" in entry and "row" in entry:
            col, row = entry["col"], entry["row"]
        else:
            continue
        sheet_name = entry["sheet"]
        if sheet_name not in sheets:
            sys.stderr.write(f"unknown sheet '{sheet_name}' for sprite '{name}'\n")
            continue
        img, sw, sh, ox, oy = sheets[sheet_name]
        x = ox + col * sw
        y = oy + row * sh
        if x + sw > img.width or y + sh > img.height:
            sys.stderr.write(
                f"sprite '{name}' at ({col},{row}) on '{sheet_name}' is out of bounds\n"
            )
            continue
        cropped = img.crop((x, y, x + sw, y + sh))
        sprites.append((name, cropped))

    if not sprites:
        sys.stderr.write("no sprites with col/row coordinates found\n")
        return 1

    pad = 8
    label_h = 16
    cell_w = max(s[1].width for s in sprites) + pad * 2
    cell_h = max(s[1].height for s in sprites) + label_h + pad * 2
    rows = (len(sprites) + PER_ROW - 1) // PER_ROW
    montage = Image.new(
        "RGBA", (cell_w * PER_ROW, cell_h * rows), MONTAGE_BG
    )
    draw = ImageDraw.Draw(montage)
    font = _load_font(11)

    for i, (name, sprite) in enumerate(sprites):
        col = i % PER_ROW
        row = i // PER_ROW
        x = col * cell_w + pad
        y = row * cell_h + pad
        montage.paste(sprite, (x, y), sprite)
        draw.text((x, y + sprite.height + 2), name, font=font, fill=MONTAGE_LABEL)

    out_path = args.output or _add_suffix(str(atlas_path), ".preview.png")
    montage.save(out_path)
    print(f"wrote {out_path}  ({len(sprites)} sprites across {rows} rows)")
    return 0


# ---------- name (browser-served) -------------------------------------------

def cmd_name(args: argparse.Namespace) -> int:
    import http.server
    import socketserver
    import webbrowser

    png_path = Path(args.png).resolve()
    atlas_path = Path(args.atlas).resolve()
    tile = args.tile_size

    if not png_path.is_file():
        sys.stderr.write(f"png not found: {png_path}\n")
        return 1
    if not atlas_path.is_file():
        sys.stderr.write(f"atlas not found: {atlas_path}\n")
        return 1

    # Atlas image paths are relative to `res/` (where hxd.Res reads).
    res_root = atlas_path.parent.parent
    rel_png = _try_relative(png_path, res_root)

    atlas = _AtlasDoc(atlas_path)
    sheet_name = args.sheet or atlas.find_sheet_for_image(rel_png)
    if sheet_name is None:
        sys.stderr.write(
            f"no atlas entry references image '{rel_png}'.\n"
            f"add one to {atlas_path} or pass --sheet <existing-name>.\n"
        )
        return 1

    src_img = Image.open(png_path).convert("RGBA")
    cols = src_img.width // tile
    rows = src_img.height // tile
    if cols == 0 or rows == 0:
        sys.stderr.write(
            f"image {png_path} ({src_img.width}x{src_img.height}) too small for tile {tile}\n"
        )
        return 1

    image_bytes = png_path.read_bytes()

    handler_cls = _make_handler(
        atlas=atlas,
        sheet_name=sheet_name,
        image_bytes=image_bytes,
        cols=cols,
        rows=rows,
        tile=tile,
        image_w=src_img.width,
        image_h=src_img.height,
        atlas_name=atlas_path.name,
        png_name=png_path.name,
    )

    try:
        httpd = socketserver.TCPServer(("127.0.0.1", args.port), handler_cls)
    except OSError as e:
        sys.stderr.write(
            f"could not bind 127.0.0.1:{args.port} ({e}). "
            f"pass --port <n> to pick a different port.\n"
        )
        return 1

    url = f"http://127.0.0.1:{args.port}/"
    print(f"atlas namer  →  {url}  (Ctrl-C to stop)")
    if not args.no_open:
        webbrowser.open(url)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print()
    finally:
        httpd.server_close()
    return 0


def _make_handler(
    *,
    atlas: "_AtlasDoc",
    sheet_name: str,
    image_bytes: bytes,
    cols: int,
    rows: int,
    tile: int,
    image_w: int,
    image_h: int,
    atlas_name: str,
    png_name: str,
):
    import http.server

    config = {
        "cols": cols,
        "rows": rows,
        "tile": tile,
        "imageW": image_w,
        "imageH": image_h,
        "sheetName": sheet_name,
        "atlasName": atlas_name,
        "pngName": png_name,
    }

    class Handler(http.server.BaseHTTPRequestHandler):

        def log_message(self, fmt, *args):
            # Quieter — only print errors.
            return

        # ---- GET routing ----
        def do_GET(self):
            if self.path == "/":
                self._send_html()
            elif self.path == "/image":
                self._send_bytes(image_bytes, "image/png")
            elif self.path == "/sprites":
                self._send_json(atlas.sprites)
            else:
                self.send_error(404)

        # ---- POST routing ----
        def do_POST(self):
            length = int(self.headers.get("Content-Length", 0))
            try:
                body = json.loads(self.rfile.read(length))
            except json.JSONDecodeError:
                self.send_error(400, "invalid json body")
                return
            if self.path == "/sprite/save":
                self._handle_save(body)
            elif self.path == "/sprite/delete":
                self._handle_delete(body)
            else:
                self.send_error(404)

        # ---- handlers ----
        def _handle_save(self, body):
            try:
                name = str(body["name"]).strip()
                sheet = str(body["sheet"])
                col = int(body["col"])
                row = int(body["row"])
            except (KeyError, TypeError, ValueError) as e:
                self.send_error(400, f"bad body: {e}")
                return
            if not name:
                self.send_error(400, "name empty")
                return
            atlas.set_sprite(name, sheet, col, row)
            atlas.save()
            self._send_json(atlas.sprites)

        def _handle_delete(self, body):
            try:
                sheet = str(body["sheet"])
                col = int(body["col"])
                row = int(body["row"])
            except (KeyError, TypeError, ValueError) as e:
                self.send_error(400, f"bad body: {e}")
                return
            for name in atlas.names_at(sheet, col, row):
                atlas.remove_sprite(name)
            atlas.save()
            self._send_json(atlas.sprites)

        # ---- helpers ----
        def _send_html(self):
            html = _HTML_TEMPLATE.replace(
                "/*__CONFIG__*/null", json.dumps(config)
            ).replace(
                "/*__SPRITES__*/null", json.dumps(atlas.sprites)
            )
            self._send_bytes(html.encode("utf-8"), "text/html; charset=utf-8")

        def _send_bytes(self, data: bytes, ctype: str):
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Content-Length", str(len(data)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(data)

        def _send_json(self, obj):
            self._send_bytes(json.dumps(obj).encode("utf-8"), "application/json")

    return Handler


def _try_relative(target: Path, root: Path) -> str:
    try:
        return target.relative_to(root).as_posix()
    except ValueError:
        return str(target)


class _AtlasDoc:
    """Load, mutate, and re-save an atlas JSON while preserving indentation."""

    def __init__(self, path: Path):
        self.path = path
        text = path.read_text()
        self._data = json.loads(text)
        # Sniff indentation: tabs if any line starts with tab, else 2 spaces.
        self._indent = "\t" if any(
            line.startswith("\t") for line in text.splitlines()
        ) else 2
        if "sprites" not in self._data:
            self._data["sprites"] = {}

    def find_sheet_for_image(self, rel_image: str) -> str | None:
        for atlas in self._data.get("atlases", []):
            if atlas.get("image") == rel_image and atlas.get("sheets"):
                return atlas["sheets"][0]["name"]
        return None

    @property
    def sprites(self) -> dict:
        return self._data["sprites"]

    def names_at(self, sheet: str, col: int, row: int) -> list[str]:
        out = []
        for name, entry in self._data.get("sprites", {}).items():
            if entry.get("sheet") != sheet:
                continue
            if entry.get("col") == col and entry.get("row") == row:
                out.append(name)
        return out

    def set_sprite(self, name: str, sheet: str, col: int, row: int) -> None:
        self._data["sprites"][name] = {"sheet": sheet, "col": col, "row": row}

    def remove_sprite(self, name: str) -> None:
        self._data["sprites"].pop(name, None)

    def save(self) -> None:
        # Standard json.dumps with indent expands every nested dict — including
        # each sprite entry — onto multiple lines. For sprite entries the leaf
        # shape is stable (sheet/col/row), so collapse them back to one line.
        import re as _re
        text = json.dumps(self._data, indent=self._indent)
        pattern = _re.compile(
            r'\{\s+"sheet": "([^"]+)",\s+"col": (-?\d+),\s+"row": (-?\d+)\s+\}'
        )
        text = pattern.sub(
            lambda m: f'{{ "sheet": "{m.group(1)}", "col": {m.group(2)}, "row": {m.group(3)} }}',
            text,
        )
        self.path.write_text(text + "\n")



# ---------- helpers ----------------------------------------------------------

def _draw_outlined(
    draw: ImageDraw.ImageDraw,
    x: int,
    y: int,
    text: str,
    font: ImageFont.ImageFont,
) -> None:
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0:
                continue
            draw.text((x + dx, y + dy), text, font=font, fill=LABEL_OUTLINE)
    draw.text((x, y), text, font=font, fill=LABEL_FILL)


def _load_font(size: int) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    )
    for path in candidates:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def _add_suffix(path: str, suffix: str) -> str:
    p = Path(path)
    return str(p.with_suffix("")) + suffix


def main(argv: Iterable[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="atlas_tool", description="Tile atlas authoring helpers"
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    overlay = sub.add_parser(
        "overlay", help="Burn grid + (col,row) labels onto a tilesheet PNG"
    )
    overlay.add_argument("png", help="Source PNG")
    overlay.add_argument(
        "--tile-size", type=int, default=DEFAULT_TILE,
        help=f"Cell pixel size (default: {DEFAULT_TILE})",
    )
    overlay.add_argument(
        "--scale", type=int, default=1,
        help="Nearest-neighbor upscale factor for the output (default: 1). "
             "Use e.g. 8 for 8px pixel-art sheets so labels stay legible.",
    )
    overlay.add_argument(
        "--output", help="Output path (default: <input>.labeled.png)"
    )
    overlay.set_defaults(func=cmd_overlay)

    preview = sub.add_parser(
        "preview", help="Render a labeled sprite montage from atlas JSON"
    )
    preview.add_argument("atlas", help="Atlas JSON path")
    preview.add_argument(
        "--output", help="Output path (default: <atlas>.preview.png)"
    )
    preview.set_defaults(func=cmd_preview)

    name = sub.add_parser(
        "name",
        help="Interactive (browser): click a cell, type a name, save to atlas",
    )
    name.add_argument("png", help="Tilesheet PNG to annotate")
    name.add_argument("atlas", help="Atlas JSON to write into")
    name.add_argument(
        "--tile-size", type=int, default=DEFAULT_TILE,
        help=f"Cell pixel size (default: {DEFAULT_TILE})",
    )
    name.add_argument(
        "--sheet", help="Atlas sheet name (default: first sheet referencing this PNG)"
    )
    name.add_argument(
        "--port", type=int, default=DEFAULT_PORT,
        help=f"Local server port (default: {DEFAULT_PORT})",
    )
    name.add_argument(
        "--no-open", action="store_true",
        help="Skip opening the browser; print the URL only",
    )
    name.set_defaults(func=cmd_name)

    args = parser.parse_args(list(argv) if argv is not None else None)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
