
build:
	cake build

auto:
	cake autobuild

snapshot:
	$(MAKE) build
	sed '1 s@^@#!/usr/bin/env node\n@' script/chromix.js > ./snapshots/chromix.js
	sed '1 s@^@#!/usr/bin/env node\n@' script/server.js  > ./snapshots/server.js
