
.PHONY: build snapshot

script += chromix
script += server

roots = $(addprefix script/, $(script))
src   = $(addsuffix .coffee, $(roots))
jss   = $(addsuffix .js, $(roots))

build: $(jss)
	@true

snapshot: $(jss) $(addsuffix .js, $(addprefix snapshots/, $(script)))
	@true

%.js: %.coffee
	coffee --compile $<

snapshots/%.js: script/%.js
	sed '1 s@^@#!/usr/bin/env node\n@' $< > $@

