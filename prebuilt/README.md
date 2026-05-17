# prebuilt/

Platform-specific HashLink native libraries (`.hdll`), kept per-OS so the
macOS and Windows builds don't clobber each other.

```
prebuilt/
  macos/    ssl.hdll  stbtt.hdll   (Mach-O)
  windows/  ssl.hdll  stbtt.hdll   (PE32+ DLL)
```

`hl` loads `.hdll` files from the current working directory, so the right
OS's copies must be placed in the repo root before running. That copy is
done by `tools/sync-hdll.ps1` (Windows) / `tools/sync-hdll.sh` (macOS),
which the `run-*` scripts invoke automatically. The deployed root copies
(`/ssl.hdll`, `/stbtt.hdll`) are git-ignored; the canonical copies here are
tracked.

## Provenance

- `ssl.hdll` — taken from the HashLink release for each platform.
- `stbtt.hdll` — custom binding built from `tools/hl-stbtt/`. Rebuild the
  Windows copy with `tools/hl-stbtt/build-windows.ps1`, which writes
  straight to `prebuilt/windows/`.
