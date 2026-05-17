# M0 Foundation — Quickstart

## Prereqs

- Haxe 4.3+
- HashLink 1.16+
- Docker + Docker Compose
- `haxelib install heaps hlsdl hlopenal utest`
- (MySQL accessed via Haxe stdlib `sys.db.Mysql` — no extra haxelib needed)

## Native builds (HashLink/C)

Every target can be compiled to a standalone native binary instead of running
through the `hl` JIT VM. The build scripts detect OS + CPU arch:

```bash
./build_native.sh        # macOS (Intel/ARM) and Linux — builds bin/*
```
```powershell
.\build_native.ps1       # Windows (x64/ARM64) — builds bin\*.exe
```

Both produce `{gateway,zone,server-cli,client,shared-test,server-test,worldgen-tmx}`.

**Apple Silicon Macs (M1/M2/M3) must use this path:** Homebrew's `hashlink`
formula does not install the `hl` JIT VM on ARM (HashLink issue #557). On Intel
Mac, Linux, and Windows the native build is optional — the `hl` JIT works there.

The `run-*.sh` scripts and `make test` / `make regenerate-map` auto-detect a
missing `hl` and fall back to `bin/<target>`, so the commands below work
unchanged. When invoking a binary directly, substitute `./bin/<x>` for
`hl out/<x>.hl`.

## Create an account

```bash
docker compose up -d mysql
./db/apply-migrations.sh
make server-cli                                      # ARM: ./build_native.sh server-cli
hl out/server-cli.hl create-account joshua hunter2   # ARM: ./bin/server-cli create-account joshua hunter2
```

## Run the server

```bash
./run-server.sh
```

Server listens on `127.0.0.1:7777`.

## Run the client

```bash
./run-client.sh
```

A window opens with a login form. Enter the account credentials. On success, "Welcome, <username>" appears.

## Run the test suite

```bash
make test               # shared unit tests
./run-integration.sh    # server + integration tests (requires Docker)
```

## Notes

- MySQL is configured with `mysql_native_password` as the default auth plugin — Haxe's HL MySQL driver speaks the classic protocol and does not support MySQL 8's default `caching_sha2_password`. Changing this requires nuking the volume.
- Plain TCP for M0; **localhost only**. TLS layer goes in before any non-localhost deployment.
- `Std.random` is used for session tokens + password salts — not crypto-grade. Replace with libsodium binding before production.
