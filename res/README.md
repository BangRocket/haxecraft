# Resource Layout

This project stores runtime assets under `res/` in type-specific folders.

## Folders

- `res/sprites/`
Contains sprite sheets and source art files (`.png`, `.aseprite`).

- `res/sounds/`
Contains runtime sound effects (`.wav`).

## Sprite Sheets

The game uses these category sheets at runtime:

- `sprites/sprites_terrain.png`
- `sprites/sprites_items.png`
- `sprites/sprites_ui.png`
- `sprites/sprites_player.png`
- `sprites/sprites_monsters.png`

The original combined sheet is also kept:

- `sprites/sprites.png`

## Path Conventions

- Image loads use `hxd.Res.load("sprites/<file>.png")`.
- Sound loads use `hxd.Res.loader.loadCache("sounds/<file>.wav", hxd.res.Sound)`.
