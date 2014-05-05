
include $(HOME)/.gnumake.mk

.PHONY: build install

target += index.html

build: $(target)
	@true

srv = smblott.org
www = public_html/chromix/

install:
	$(MAKE) build
	rsync -av $(target) $(srv):$(www)

