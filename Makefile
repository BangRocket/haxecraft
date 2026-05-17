.PHONY: all shared-test gateway zone server-cli client test server-test client-test worldgen-tmx regenerate-map native native-test clean

all: out shared-test gateway zone server-cli client worldgen-tmx

# Native HLC build for Apple Silicon Macs (no `hl` JIT VM available there).
native:
	./build_native.sh

native-test: native
	./bin/shared-test

out:
	@mkdir -p out

shared-test: out
	cd shared && haxe build-shared-test.hxml

gateway: out
	cd server && haxe build-gateway.hxml

zone: out
	cd server && haxe build-zone.hxml

server-cli: out
	cd server && haxe build-server-cli.hxml

client: out
	cd client && haxe build-client.hxml

worldgen-tmx: out
	cd tools/worldgen-tmx && haxe build-worldgen-tmx.hxml

regenerate-map:
	@if command -v hl >/dev/null 2>&1; then \
		$(MAKE) worldgen-tmx && hl out/worldgen-tmx.hl 1024 1024 res/maps/starter.tmx; \
	else \
		./build_native.sh worldgen-tmx && ./bin/worldgen-tmx 1024 1024 res/maps/starter.tmx; \
	fi

test:
	@if command -v hl >/dev/null 2>&1; then \
		$(MAKE) shared-test && hl out/shared-test.hl; \
	else \
		./build_native.sh shared-test && ./bin/shared-test; \
	fi

server-test: out
	cd server && haxe build-server-test.hxml
	hl out/server-test.hl

client-test: out
	cd client && haxe build-client-test.hxml
	hl out/client-test.hl

clean:
	rm -rf out/*.hl
