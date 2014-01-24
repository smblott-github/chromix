
build:
	cake build

auto:
	cake autobuild

snapshot:
	$(MAKE) build
	install -vm 0444 script/server.js script/chromix.js snapshots/
	markdown ./README.md > ./README.html
	lynx -dump -force_html -assume_charset=utf8 -justify -nomargins -unique_urls ./README.html > README
