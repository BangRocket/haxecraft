# Sub-project 3: Inventory + Equipment — Eyes-On Test Guide

Design: `docs/superpowers/specs/2026-05-17-inventory-gathering-crafting-design.md`.

## Launch

```powershell
.\run-server.ps1     # gateway + zone
.\run-client.ps1     # client
```

Log in (`tester` / `hunter2`).

## What to verify

- [ ] On first login the inventory holds a starter kit — Wood Pickaxe,
      Wood Axe, Wood Shovel, Wood Hoe (open with `I`).
- [ ] Walk over a ground item (the scattered wood/stone/ore from SP2). It
      **disappears and is added to your inventory** — no key press needed.
- [ ] Press `I` — the inventory overlay lists every slot: item name and
      count, resources stacked. Press `I` again to close.
- [ ] Press a number key `1`-`9` — that slot becomes the **active item**
      (the `>` marker moves). The active item is what gathering/placing uses.
- [ ] Log out and back in — the inventory is **exactly as you left it**
      (persisted to the database).

## Notes

- Pickup is automatic on walk-over; there is no drop-item action yet.
- "Equipment" is the single active item (the legacy game's held item) —
  there are no separate equipment slots.
