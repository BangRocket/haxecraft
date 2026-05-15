.PHONY: all shared-test gateway zone server-cli client test server-test clean

all: out shared-test gateway zone server-cli client

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

test: shared-test
	hl out/shared-test.hl

server-test: out
	cd server && haxe build-server-test.hxml
	hl out/server-test.hl

clean:
	rm -rf out/*.hl
