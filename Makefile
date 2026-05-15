.PHONY: all shared-test gateway zone server-cli client test server-test worldgen-tmx regenerate-map clean

all: out shared-test gateway zone server-cli client worldgen-tmx

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

regenerate-map: worldgen-tmx
	hl out/worldgen-tmx.hl 1024 1024 res/maps/starter.tmx

test: shared-test
	hl out/shared-test.hl

server-test: out
	cd server && haxe build-server-test.hxml
	hl out/server-test.hl

clean:
	rm -rf out/*.hl
