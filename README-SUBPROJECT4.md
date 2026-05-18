# Sub-project 4: Interactive / Gathering Tiles — Eyes-On Test Guide

Design: `docs/superpowers/specs/2026-05-17-inventory-gathering-crafting-design.md`.

## Launch

```powershell
.\run-server.ps1
.\run-client.ps1
```

Log in (`tester` / `hunter2`). You start with the basic wood tools.

## What to verify

- [ ] Select the **Wood Axe** as active (open `I`, note its slot, press that
      number). Face a tree (walk into it) and press `SPACE` repeatedly — the
      tree **falls after a few hits**, becomes grass, and drops **wood** (and
      sometimes acorns / an apple) as ground items you can pick up.
- [ ] Select the **Wood Pickaxe** and mine **rock** the same way → it becomes
      dirt and drops **stone** / **coal**. Mine an **ore** tile → ore drops.
- [ ] Select the **Wood Hoe**, face a grass tile, `SPACE` → it becomes
      **farmland**.
- [ ] With **Seeds** active (drop from digging grass), `SPACE` on farmland →
      it becomes **wheat**, which **grows through stages** over ~10 s.
- [ ] `SPACE` on grown wheat with a shovel → harvests **wheat** + seeds.
- [ ] Plant an **acorn** on grass → a sapling, which **grows into a tree**.
- [ ] Log the zone out and back in — felled trees / mined rock **stay
      changed** (tile edits are persisted).

## Notes

- A tile is acted on by facing it and pressing `SPACE`; the server checks
  you hold the right tool type. Tool tier scales mining speed.
- There is no stamina — the legacy stamina gating was dropped (the MMO has
  no stamina system).
- Growth advances only near connected players.
