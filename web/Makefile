
include $(HOME)/.gnumake.mk

.PHONY: build install

target += index.html
target += favicon.ico

build: $(target)
	@true

srv = smblott.computing.dcu.ie
www = /home/www/smblott.org/chromix/

install:
	$(MAKE) build
	rsync -av $(target) $(srv):$(www)

