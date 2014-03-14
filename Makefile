
.PHONY: build snapshot install

script += chromix
script += server

roots = $(addprefix script/, $(script))
src   = $(addsuffix .coffee, $(roots))
jss   = $(addsuffix .js, $(roots))

# ###########################################################
# Figure out the name of the node/nodejs executable...

pnode = $(shell which node)

ifeq (,$(pnode))
pnode = $(shell which nodejs)
endif

ifeq (,$(pnode))
pnode = node
endif

node = $(notdir $(pnode))

# ###########################################################
# Targets...

build: $(jss)
	@true

snapshot: $(jss) $(addsuffix .js, $(addprefix snapshots/, $(script)))
	@true

install:
	$(MAKE) snapshot
	sudo npm install -g .

%.js: %.coffee
	coffee --compile $<

snapshots/%.js: script/%.js
	sed '1 s@^@#!/usr/bin/env $(node)\n@' $< > $@

show_node:
	@echo $(node)

