# Sub-project 5: Crafting — Eyes-On Test Guide

Design: `docs/superpowers/specs/2026-05-17-inventory-gathering-crafting-design.md`.
This closes the five-sub-project content arc.

## Launch

```powershell
.\run-server.ps1
.\run-client.ps1
```

Log in (`tester` / `hunter2`).

## What to verify

- [ ] Gather some **wood** (chop trees — see SP4) and walk to the furniture
      camp near spawn (a workbench, furnace, oven, anvil, chest, lantern).
- [ ] Stand next to the **workbench** and press `C` — the crafting menu
      opens, a scrolling list of all 35 recipes. `up`/`down` move the cursor.
- [ ] Select **Wood Sword <- 5 Wood** and press `Enter`. Open `I`: the sword
      is now in your inventory and 5 wood was consumed.
- [ ] Try a recipe you lack the inputs for, or stand away from the
      workbench — `Enter` does nothing (the server rejects it).
- [ ] Craft a furniture item (e.g. **Chest <- 20 Wood**). Make it the active
      item, face an empty tile and press `P` — the chest is **placed into
      the world** and blocks movement.
- [ ] Smelt at the **furnace** (ore + coal -> ingot) and bake at the **oven**
      (wheat -> bread).

## Notes

- Crafting is server-authoritative: it checks you stand next to the matching
  station and hold every input.
- Crafted furniture is placed with `P` onto the faced tile. Placed furniture
  is zone-lifetime (not yet persisted across a zone restart).
- The arc is complete — the MMO world can be walked, gathered, carried, and
  crafted, all server-authoritative and (inventory + tile edits) persistent.
