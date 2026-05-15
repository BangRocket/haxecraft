.PHONY: all shared-test server client test clean

all: out shared-test server client

out:
	@mkdir -p out

shared-test: out
	cd shared && haxe build-shared-test.hxml

server: out
	cd server && haxe build-server.hxml

client: out
	cd client && haxe build-client.hxml

test: shared-test
	hl out/shared-test.hl

clean:
	rm -rf out/*.hl
