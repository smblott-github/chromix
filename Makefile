
build:
	cake build

auto:
	cake autobuild

snapshot:
	$(MAKE) build
	install -vm 0444 script/server.js script/chromix.js snapshots/
