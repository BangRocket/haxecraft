.PHONY: all shared-test server client test clean

all: out shared-test server server-cli client

out:
	@mkdir -p out

shared-test: out
	cd shared && haxe build-shared-test.hxml

server: out
	cd server && haxe build-server.hxml

server-cli: out
	cd server && haxe build-server-cli.hxml

client: out
	cd client && haxe build-client.hxml

test: shared-test
	hl out/shared-test.hl

server-test: out
	cd server && haxe build-server-test.hxml
	hl out/server-test.hl

clean:
	rm -rf out/*.hl
